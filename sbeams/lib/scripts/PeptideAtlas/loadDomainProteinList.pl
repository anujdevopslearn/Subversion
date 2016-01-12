#!/usr/local/bin/perl 

###############################################################################
# Program     :
# Author      : 
#
# Description : 
#
###############################################################################

use strict;
use Getopt::Long;
use File::Basename;
use Cwd qw( abs_path );
use Data::Dumper;
use FindBin;
use Spreadsheet::Read;
use Spreadsheet::ParseXLSX;
use Spreadsheet::ParseExcel;


#### Set up SBEAMS modules
use lib "$FindBin::Bin/../../perl";
use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;

use vars qw ( $PROG_NAME $USAGE $QUIET $VERBOSE $DEBUG $TESTONLY );

# don't buffer output
$|++;

## Globals
my $sbeams = new SBEAMS::Connection;
my $atlas = new SBEAMS::PeptideAtlas;
$atlas->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);
$PROG_NAME = basename( $0 );
## Set up environment


my $opts = get_options();

# Legacy
$VERBOSE = $opts->{"verbose"} || 0;
$QUIET = $opts->{"quiet"} || 0;
$DEBUG = $opts->{"debug"} || 0;
$TESTONLY = $opts->{"testonly"} || 0;
if ($DEBUG) {
  print "Options settings:\n";
  print "  VERBOSE = $VERBOSE\n";
  print "  QUIET = $QUIET\n";
}


main();

exit(0);


###############################################################################
# Main Program:
#
# Call $sbeams->Authenticate() and exit if it fails or continue if it works.
###############################################################################
sub main {

  #### Do the SBEAMS authentication and exit if a username is not returned
  my $current_username = $sbeams->Authenticate( work_group=>'PeptideAtlas_admin' ) || exit;

  if ( $opts->{domain_list_id} ) {
    check_list( $opts->{domain_list_id} );
  }

  if ( $opts->{mode} =~ /new/i ) {

    my $list_data = parse_list( $opts->{list_file} );

    print STDERR "insert list record\n";
    create_list($list_data);

    print "Fill table\n";
    fill_table($list_data);
  } elsif ( $opts->{mode} =~ /tsv_old/ ) {
    fill_table_tsv();
  } elsif ( $opts->{mode} =~ /update/ ) {
    update_list();
  } else {
    print STDERR "Unknown mode $opts->{mode}\n";
    exit;
  }

    
  return;

} # end main

sub parse_list {
  my $file = shift || die;
  my $book = ReadData( $file );


  # First read the List info sheet
  my %list;
  if ( $book->[1]->{label} ne 'ListInformation' ) {
    if ( $opts->{force} ) {
      print STDERR "Allowing Mis-labeled info sheet $book->[1]->{label}";
    } else {
      die "Mis-labeled info sheet $book->[1]->{label}";
    }
  }
  for ( my $idx = $book->[1]->{minrow}; $idx <= $book->[1]->{maxrow}; $idx++ ) {
    my @row = Spreadsheet::Read::row( $book->[1], $idx );

    next if $row[0] eq 'Field';
    next if $row[0] =~ /Please fill in/;
    $list{$row[0]} = $row[1];
  }


  if ( $book->[2]->{label} ne 'ListProteins' ) {
    if ( $opts->{force} ) {
      print STDERR "Allowing Mis-labeled info sheet $book->[1]->{label}";
    } else {
      die "Mis-labeled info sheet $book->[1]->{label}";
    }
  }

  my @list_proteins;
  my @keys;
  for ( my $idx = $book->[2]->{minrow}; $idx <= $book->[2]->{maxrow}; $idx++ ) {
    my @row = Spreadsheet::Read::row( $book->[2], $idx );
    if ( $row[0] eq 'uniprot_accession' && !scalar( @keys ) ) {
      @keys = @row;
      next;
    }
    next if $row[0] =~ /Uniprot accession/;
    my %prot;
    last if !$row[0];
    for ( my $idx = 0; $idx <= $#keys; $idx++ ) {
      $prot{$keys[$idx]} = $row[$idx];
    }
    push @list_proteins, \%prot;
  }
  return ( { list_info => \%list, list_proteins => \@list_proteins } );
}

sub show_lists {
  my $sql = qq~
  SELECT protein_list_id, title 
  FROM $TBAT_DOMAIN_PROTEIN_LIST
  WHERE record_status = 'N'
  ORDER BY protein_list_id ASC
  ~;

  my $sth = $sbeams->get_statement_handle( $sql );
  while ( my @row = $sth->fetchrow_array ) {
    print join( "\t", @row ) . "\n";
  }
  exit;
}

sub check_list {

  my $list_id = shift;

  my $sql = "SELECT title FROM $TBAT_DOMAIN_PROTEIN_LIST WHERE protein_list_id = $list_id";
  my $result = $sbeams->selectrow_arrayref( $sql );
  if ( $result->[0] ) {
    print "Found domain list: $result->[0]\n";
  } else {
    print "Unable to find domain list with ID $list_id, try --show option\n";
    exit;
  }

}




sub update_list {

  my $list_id = shift || $opts->{domain_list_id};
  die "No list_id " unless $list_id;

  my $files_dir = $UPLOAD_DIR . '/AT_domain_protein_list';

  # For now we will just add a primary or secondary file.
  my $list_file = "$files_dir/${list_id}_original_file.dat";
  if ( $opts->{list_file} ) {
    my $new_filename = basename( $opts->{list_file} );

    print "Adding or updating list file with $new_filename\n";

    if ( -e $list_file ) {
      print "File $list_file exists\n";
      my $version = time();

      my $sql = qq~
      SELECT original_file FROM $TBAT_DOMAIN_PROTEIN_LIST 
      WHERE protein_list_id = $list_id
      ~;
      my $row = $sbeams->selectrow_arrayref( $sql );
      $row->[0] ||= 'unknown';

      my $new_name = "$list_file.$version.$row->[0]";

      `mv $list_file $new_name`;

      if ( -e $list_file ) {
        print STDERR "Unknown error renaming file $list_file\n";
        exit;
      } elsif ( -e $new_name ) {

        `cp $opts->{list_file} $list_file`;

        my $sql = qq~
        UPDATE $TBAT_DOMAIN_PROTEIN_LIST 
        SET original_file = '$opts->{list_file}' 
        WHERE protein_list_id = $list_id
        ~;
        $sbeams->do( $sql );

      } else {
        print STDERR "Unknown error renaming file $list_file\n";
      }

    } else {
      print "no existing file for $list_id, creating new\n";
      `cp $opts->{list_file} $list_file`;
      my $sql = qq~
      UPDATE $TBAT_DOMAIN_PROTEIN_LIST 
      SET original_file = '$opts->{list_file}' 
      WHERE protein_list_id = $list_id
      ~;
      $sbeams->do( $sql );
    }
  }

  if ( $opts->{aux_files} ) {
    for my $file ( @{$opts->{aux_files}} ) {
      if ( ! -e $file ) {
        print STDERR "No file found for $file, skipping\n";
        next;
      }

      my $base_name = basename( $file );
      my $abs_name = abs_path( $file );
      my $sql = qq~
      INSERT INTO $TBAT_DOMAIN_LIST_RESOURCE 
      ( protein_list_id, name, type, description ) VALUES
      ( $list_id, '$base_name', 'File', 'Aux file $abs_name' )
      ~;
      $sbeams->do( $sql );
      my $fetch_sql = qq~
      SELECT MAX( list_resource_id ) FROM
      $TBAT_DOMAIN_LIST_RESOURCE 
      WHERE protein_list_id = $list_id
      AND type = 'File'
      AND name = '$base_name'
      ~;

      my ( $id ) = $sbeams->selectrow_array( $fetch_sql );
      my $aux_file = "$UPLOAD_DIR/AT_domain_list_resource/${id}_name.dat";
      `cp $file $aux_file`;
      `chmod a+r $aux_file`;
      print STDERR "ID is $id for $base_name\n";
    }
  }

  if ( $opts->{add_proteins} && $opts->{list_file} ) {
    my $list_data = parse_list( $opts->{list_file} );

    print "Fill table\n";

    $list_data->{list_id} = $list_id;

    fill_table($list_data);
  
  }

  exit;

}

sub delete_list {
  my $list_id = shift;

  my $sql = "SELECT COUNT(*) FROM $TBAT_DOMAIN_PROTEIN_LIST WHERE protein_list_id = $list_id";
  my $result = $sbeams->selectrow_arrayref( $sql );
  if ( $result->[0] ) {
    my $sql = "SELECT COUNT(*) FROM $TBAT_DOMAIN_LIST_PROTEIN WHERE protein_list_id = $list_id";
    my $result = $sbeams->selectrow_arrayref( $sql );
    if ( $result->[0] ) {
      if ( !$opts->{force} ) {
        usage( "This domain protein list already has data, use --force option to purge and load new records" );
      } else {
        $sbeams->do( "DELETE FROM $TBAT_DOMAIN_LIST_PROTEIN WHERE protein_list_id = $list_id" );
        return 1;
      }
    } else {
      return 1;
    }
  } else {
    usage( "You must first load the list data via the ManageTable interface" );
  }

}

sub create_list {
  my $list_data =  shift || die;
  my $list_info = $list_data->{list_info};
  $list_info->{Title} = $list_info->{'List Title'};
  $list_info->{pubmed_id} = $list_info->{'Pubmed ID'};
  $list_info->{Abstract} =~ s/[^[:ascii:]]//g;
  $list_info->{image_path} = $list_info->{image};
  $list_info->{n_proteins} = scalar( @{$list_data->{list_proteins}} );

  for my $element ( 'List Name', 'Pubmed ID', 'image', 'List Title' ) {
    delete( $list_info->{$element} );
  }
  $list_info->{owner_contact_id} = $opts->{contact_id} || $sbeams->getCurrent_contact_id();
  $list_info->{project_id} = $opts->{project_id};

  my $id = $sbeams->updateOrInsertRow( insert => 1,
                                  table_name  => $TBAT_DOMAIN_PROTEIN_LIST,
                                  rowdata_ref => $list_info,
                                    return_PK => 1,
                                      verbose => $VERBOSE,
                                  testonly    => $TESTONLY );

  $list_data->{list_id} = $id;

  update_list($id);


}

sub fill_table {

  my $list_data = shift || die;
  my $list_proteins = $list_data->{list_proteins};
  my $list_id = $list_data->{list_id};

 
  for my $prot ( @{$list_proteins} ) {
    $prot->{priority} = ( $prot->{'popularity rank'} < 1 ) ? 1 :
                        ( $prot->{'popularity rank'} > 5 ) ? 5 : $prot->{'popularity rank'};
    $prot->{protein_full_name} = $prot->{protein_name};
    $prot->{protein_symbol} ||= '';
    $prot->{gene_symbol} ||= '';
    $prot->{original_name} ||= '';
    $prot->{original_accession} ||= '';
    $prot->{protein_list_id} = $list_id;
    for my $element ( 'popularity rank', 'protein_name', 'citations' ) {
      delete( $prot->{$element} );
    }

    $sbeams->updateOrInsertRow( insert => 1,
                           table_name  => $TBAT_DOMAIN_LIST_PROTEIN,
                           rowdata_ref => $prot, 
                               verbose => $VERBOSE,
                              testonly => $TESTONLY );


  }

} # end fillTable


##################

sub fill_table_tsv {

  my %valid = ( original_name => 1,
                original_accession  => 1,
                uniprot_accession  => 1,
                protein_symbol  => 1,
                gene_symbol  => 1,
                protein_full_name  => 1,
                priority  => 1,
                comment  => 1,
              );



  open LIST, $opts->{list_file} || die;
  my %headings;
  my $cnt;
  my %keep_fields;
  while ( my $line = <LIST> ) {
    chomp $line;
    my @line = split( /\t/, $line );
    unless ( $cnt++ ) {
      my $idx = 0;
      for my $heading ( @line ) {
        my $lc_head = lc( $heading );
        if ( $valid{$lc_head} ) {
          $keep_fields{$lc_head} = $idx;
        }
        $idx++;
      }
      next;
    }
    my %rowdata;
    for my $key ( keys( %keep_fields ) ) {
      $rowdata{$key} = $line[$keep_fields{$key}];
    }
    $rowdata{protein_list_id} = $opts->{domain_list_id};

    for my $id ( keys( %valid ) ) {
      $rowdata{$id} = '' if !defined $rowdata{$id};
      if ( $id eq 'protein_full_name' && length( $rowdata{$id} ) > 255 ) {
        $rowdata{$id} = substr( $rowdata{$id}, 0, 255 );
      }
    }
    if ( !$rowdata{uniprot_accession} ) {
      print STDERR "Skipping $line, no uniprot accession\n";
      next;
    }

    $sbeams->updateOrInsertRow( insert => 1,
                           table_name  => $TBAT_DOMAIN_LIST_PROTEIN,
                           rowdata_ref => \%rowdata,
                               verbose => $VERBOSE,
                           testonly    => $TESTONLY );


  }

} # end fill_table

sub usage {
  my $msg = shift || '';
#'list_file:s', 'domain_list_id:i', 'help', 'force' ) || usage( "Error processing options" );

  print <<"  EOU";

  $msg


  Usage: $PROG_NAME [opts]
  Options:

    --list_file            Name of primary file 
    --aux_file             Name of auxilary file(s) 
    --domain_list_id       ID of domain_list, required for update operations
    --mode                 main purpose of a given script run.  One of:
                              new - add new list, requires list_file, project_id
                              update - update existing record, requires id 
                              delete - delete existing list, requires id
    --show_lists           Output list names and ids, helpful for update mode
    --contact_id           contact_id of list owner 
    --verbose n            Set verbosity level.  default is 0
    --quiet                Set flag to print nothing at all except errors
    --debug n              Set debug flag
    --testonly             If set, rows in the database are not changed or added
    --help                 print this usage and exit.

   e.g.: $PROG_NAME --list listfile --domain domain_id

  EOU
  exit;
}


# Process options
sub get_options {

  my %opts = ( aux_files => [] );
  GetOptions( \%opts,"verbose:s","quiet","debug:s","testonly", 'list_file:s', 
              'domain_list_id:i', 'help', 'force', 'mode=s', 'project_id:i', 
              "aux_files=s@", "show_lists", "contact_id=i", 'add_proteins' ) 
              || usage( "Error processing options" );
  
  # Check params
  if ( $opts{help} ) {
    usage();
  } elsif ( $opts{show_lists} ) {
    show_lists();
  } elsif ( !$opts{mode} ) {
    usage( "Missing required parameter 'mode'" );
  } elsif ( $opts{mode} eq 'new' ) {
    unless ( $opts{project_id} && $opts{list_file} ) {
      usage( "'new' mode requires project_id and list_file" );
    }
  } elsif ( $opts{mode} eq 'update' ) {
    unless ( $opts{domain_list_id} ) {
      usage( "'update' mode requires domain_list_id" );
    } 
  } elsif ( $opts{mode} eq 'delete' ) {
    unless ( $opts{domain_list_id} ) {
      usage( "'delete' mode requires domain_list_id" );
    } 
    usage( "'delete' mode not yet enabled'" );
  } else {
    usage( "unknown mode '$opts{mode}'" );
  }
  return \%opts;

}


__DATA__
