#!/usr/local/bin/perl 

###############################################################################
# Program     : load_uniprot_db.pl
#
# Description : Load the consensus library (msp or spectrast) into the consensus 
#               spectrum tables.
###############################################################################

use strict;
use Getopt::Long;
use Compress::Zlib;
use FindBin;
use Cwd qw( abs_path );
        use Data::Dumper;

use lib "$FindBin::Bin/../../perl";
use vars qw ($sbeams $sbeamsMOD $q $current_username 
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $TESTONLY
         );
$|++;


#### Set up SBEAMS core module
use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;
use SBEAMS::Proteomics::Tables;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::PeptideAtlas;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);


###############################################################################
# Set program name and usage banner for command like use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS]
Options:
  --verbose n            Set verbosity level.  default is 0
  --quiet                Set flag to print nothing at all except errors
  --debug n              Set debug flag
  --help                 Print usage statement and exit
  --load                 load the library
  --test                 test only, don't write records
  --path                 path to library file
  --biosequence_set_id   tie to biosequence set
  --is_nextprot  
  --nextprot_update      nextprot_accession_file
  
  --update
  --purge 

 e.g.: ./$PROG_NAME --path /uniprot.dat --load
EOU


#### Process options
my %opts;
unless (GetOptions(\%opts,"verbose:s","quiet","debug:s","test", 'help',
                   "load", "path:s", 'nextprot_update:s', 'is_nextprot:s','update' , 'purge', 
                   "biosequence_set_id:i") ) {
    print "\n$USAGE\n";
    exit;
  }

$VERBOSE = $opts{"verbose"} || 0;

$QUIET = $opts{"quiet"} || 0;

$DEBUG = $opts{"debug"} || 0;

$TESTONLY = $opts{"test"} || 0;

if ( $opts{help} ) {
    print "\n$USAGE\n";
    exit(0);
}

$opts{is_nextprot} ||= 'N';

if ( $opts{'load'} || $opts{'test'} || $opts{'update'}|| $opts{'purge'}) {
    unless ($opts{path} && $opts{biosequence_set_id}) {
        print "\n$USAGE\n";
        print "Need --path \n";
        exit(0);
    }
    if ( $opts{nextprot_update} ) {
      update_np_accessions();
      exit;
    }

    main();
}

    my %all_acc;

exit(0);


sub main 
{
    #### Do the SBEAMS authentication and exit if a username is not returned
    exit unless (
        $current_username = $sbeams->Authenticate(work_group=>'PeptideAtlas_admin')
    );

    ## make sure file exists
    my $file_path = abs_path( $opts{path} );
    my $biosequence_set_id = $opts{biosequence_set_id} ; 

    unless (-e $file_path) {
      print "File does not exist: $file_path\n";
      exit(0);
    }
    if ($opts{'purge'}){
       print "purge record with path $file_path\n";
       purge_entry($file_path, $biosequence_set_id);  
    }else{
      load_db( $file_path,$biosequence_set_id );
    }
} # end handleRequest
sub purge_entry {
   my $path = shift;
   my $biosequence_set_id = shift;
   my $sql = qq~
      SELECT UNIPROT_DB_ID
      FROM $TBAT_UNIPROT_DB
      WHERE FILE_PATH='$path'
      AND biosequence_set_id=$biosequence_set_id
    
   ~;
  my @result = $sbeams->selectOneColumn($sql);
  if (@result == 1){
    my $uniprot_db_id = $result[0];
    $sql = qq~
			 DELETE  
			 FROM $TBAT_UNIPROT_DB_ENTRY
			 WHERE uniprot_db_id = $uniprot_db_id
     ~;

    print "delete all accession entry for uniprot_db_id $uniprot_db_id\n";
    $sbeams->executeSQL($sql);
  }elsif(@result > 1){
    print "ERROR: more than one record for $path\n";
    print join(",", @result) ."\n";
  }else{
    print "no id found for path $path\n";
  }
 
}


sub load_db {
   my $path = shift;
   my $biosequence_set_id = shift;
   my $md5sum = system( "md5sum $path" );
   my $commit_interval = 25;

    # Test file open *before* inserting library record
    open(INFILE, "<$path") || die "ERROR: Unable to open for reading $path";

    my $uniprot_db_id;
    if ( $opts{'update'}){
       my $sql = qq~
           SELECT UNIPROT_DB_ID
           FROM $TBAT_UNIPROT_DB
           WHERE FILE_PATH='$path' 
           AND biosequence_set_id=$biosequence_set_id
       ~;
       my @result = $sbeams->selectOneColumn($sql);
       if (@result > 1){
         die "ERROR: more than one record for $path\n";
       }else{
          $uniprot_db_id = $result[0];
       }
    }else{
       $uniprot_db_id = insert_db( file_path => $path,
                                   biosequence_set_id => $biosequence_set_id,
                                   md5sum => $md5sum ) if ( $opts{load} );
    }
    my $count = 0;
#    $sbeams->initiate_transaction();
    my %entry = ( entry_offset => 0,
                  entry_accession => [],
                  entry_name => '' );
    my $idx = 0;
    while (my $line = <INFILE>) {
      chomp($line);
      if ( $line =~ /^ID\s+/ ) {
        $line =~ /^ID\s+(\S+)/;
        $entry{entry_name} = $1;
        $entry{entry_offset} = $idx;
        print "$line $idx\n";
      }
      if ( $line =~ /^GN\s+/ ) {
        $line =~ /^GN\s+Name=(\S+);*/;
        $entry{gene_symbol} = $1;
      }
      if ( $line =~ /^AC(.*)$/ ) {
        my $acc_str = $1;
        $acc_str =~ s/\s//g;
        $entry{entry_accession} ||= [];
        my @acc_list = split( /;/, $acc_str );

        for my $acc ( @acc_list ) {
          push @{$entry{entry_accession}}, $acc;
        }
      }


      if ( $line =~ /^\/\// ) {
        $count++;
        my $curr_idx = tell( INFILE );
        my $size = $curr_idx - $idx;
        $idx = $curr_idx;
        $entry{record_size} = $size;
         
        if ($opts{'update'}){
           update_db_entry( uniprot_db_id => $uniprot_db_id,
                            %entry);
 

        }elsif($opts{load}){
           my $entry_ids = insert_db_entry( uniprot_db_id => $uniprot_db_id, 
                                                          %entry
                                       );
        }
        $entry{entry_accession} = '';
        $entry{entry_name} = '';
      }

    }
#   $sbeams->commit_transaction();

    print "Read $count entries in library\n";
    close(INFILE) or die "ERROR: Unable to close $path";

}

sub insert_db {
  my %rowdata = ( is_nextprot => $opts{is_nextprot}, @_ );
  my $current_contact_id = $sbeams->getCurrent_contact_id;
  my $current_work_group_id = $sbeams->getCurrent_work_group_id;
  my %tmp =(date_created       =>  'CURRENT_TIMESTAMP',
            created_by_id      =>  $current_contact_id,
            date_modified      =>  'CURRENT_TIMESTAMP',
            modified_by_id     =>  $current_contact_id,
            owner_group_id     =>  $current_work_group_id,
            record_status      =>  'N');
  %rowdata = (%rowdata, %tmp);
  
  ## create a consensus_library record:
  my $uniprot_db_id = $sbeams->updateOrInsertRow(
        table_name=>$TBAT_UNIPROT_DB,
        insert=>1,
        rowdata_ref=>\%rowdata,
        PK => 'uniprot_db_id',
        return_PK=>1,
        verbose=>$VERBOSE,
        testonly=>$TESTONLY );

  return $uniprot_db_id;
}
sub update_db_entry{
  my %entry = @_;
  my $uniprot_db_id = $entry{uniprot_db_id};
  for my $key ( qw( entry_offset entry_accession entry_name ) ) {
    die Dumper( %entry ) unless defined $entry{$key};
  }
  my $sql = qq~
           SELECT  entry_accession,UNIPROT_DB_ENTRY_ID
           FROM $TBAT_UNIPROT_DB_ENTRY
           WHERE uniprot_db_id = $uniprot_db_id
       ~;
 
  my %db_entries = $sbeams->selectTwoColumnHash($sql);
  foreach my $accession(@{$entry{entry_accession}}){
     if (defined $db_entries{$accession}){
       print "$accession updating, entry_offset $entry{entry_offset}\n";
       my $id = $db_entries{$accession};
       my %rowdata =  ( %entry, entry_accession => $accession);
       my $msg = $sbeams->updateOrInsertRow(
          table_name=>$TBAT_UNIPROT_DB_ENTRY,
          update=>1,
          rowdata_ref=>\%rowdata,
          PK => 'uniprot_db_entry_id',
          PK_value => $id,
          verbose=>$VERBOSE,
          testonly=>$TESTONLY );
     }else{
       print "$accession not found, inserting\n"; 
       my %rowdata =  ( %entry, entry_accession => $accession);
       my $msg = $sbeams->updateOrInsertRow(
          table_name=>$TBAT_UNIPROT_DB_ENTRY,
          insert=>1,
          rowdata_ref=>\%rowdata,
          PK => 'uniprot_db_entry_id',
          retrun_PK => 1,
          verbose=>$VERBOSE,
          testonly=>$TESTONLY );
     }
  } 
}
sub insert_db_entry {
  my %entry = @_;

  for my $key ( qw( entry_offset entry_accession entry_name ) ) {
    die Dumper( %entry ) unless defined $entry{$key};
  }

  my @entry_ids;
  my $is_primary = 1;
  for my $acc ( @{$entry{entry_accession}} ) {
    my %rowdata =  ( %entry, entry_accession => $acc, is_primary => $is_primary );
    $is_primary = 0;
    
    my $entry_id = $sbeams->updateOrInsertRow(
          table_name=>$TBAT_UNIPROT_DB_ENTRY,
          insert=>1,
          rowdata_ref=>\%rowdata,
          PK => 'uniprot_db_entry_id',
          return_PK=>1,
          verbose=>$VERBOSE,
          testonly=>$TESTONLY );
    push @entry_ids, $entry_id;
  }

  return \@entry_ids;
}

sub update_np_accessions {

  my $clean_sql = "UPDATE $TBAT_UNIPROT_DB_ENTRY SET nextprot_id = NULL";
  $sbeams->do( $clean_sql );

  my $update_sql = "UPDATE $TBAT_UNIPROT_DB_ENTRY SET nextprot_id = entry_accession WHERE entry_accession = ?"; 
  my $dbh = $sbeams->getDBHandle();
  my $sth = $dbh->prepare( $update_sql );

  open FIL, $opts{path};
  while( my $id = <FIL> ) {
    chomp $id;
    $id =~ s/^NX_//;
    $sth->execute( $id );
  }
}
