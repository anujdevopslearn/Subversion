#!/usr/local/bin/perl -w
#!/local/bin/perl -w

use Getopt::Long;
use FindBin qw( $Bin );
use lib ( "$Bin/../../perl" );
use SBEAMS::Connection;
use SBEAMS::BEDB::Tables;
use SBEAMS::BioLink::Tables;
use SBEAMS::Biosap::Tables;
use SBEAMS::Connection::Tables;
use SBEAMS::Cytometry::Tables;
use SBEAMS::Genotyping::Tables;
use SBEAMS::Immunostain::Tables;
use SBEAMS::Inkjet::Tables;
use SBEAMS::Interactions::Tables;
use SBEAMS::Microarray::Tables;
use SBEAMS::Ontology::Tables;
use SBEAMS::PeptideAtlas::Tables;
use SBEAMS::PhenoArray::Tables;
use SBEAMS::ProteinStructure::Tables;
use SBEAMS::Proteomics::Tables;
use SBEAMS::SNP::Tables;
use SBEAMS::Tools::Tables;
use SBEAMS::Oligo::Tables;

use strict;

main();
exit 0;

sub main {

  # Make connection
  my $sbeams = new SBEAMS::Connection;
  $sbeams->Authenticate() || die "Insufficient priviliges";
  my $dbh = $sbeams->getDBHandle() || die( "Unable to get database handle" );

  # Fetch passed options
  my %args = checkOpts();

  my $tref = readTableFile( \%args );
  my $cref = readColumnFile( \%args );

  my $status = checkSql( $tref, $cref, $dbh, $args{verbose} );

}  # End main

sub checkSql {
  my ( $tref, $cref, $dbh, $verbose ) = @_;
  my %sql;
  foreach my $table ( keys( %$tref ) ) {
    my $cols = join( ", ", keys( %{$cref->{$table}} ) );
    $sql{$table} = ( $cols ) ? "SELECT $cols FROM $tref->{$table}\n" : '';
  }
  $dbh->{RaiseError} = 1;
  my $problems = 0;
  my $ok = 0;
  for ( keys( %sql ) ) { 
  open ERRS, ">>/tmp/errorfile" || die "couldn't open file";
  my $err = '';
    eval {
      my $sth = $dbh->prepare( $sql{$_} );
      $sth->execute();
      $err = $dbh->errstr();
    };
    if ( $@ ) {
      print ERRS "$@\n";
      print ERRS "$sql{$_}\n\n";
      print "NOT OK on $_\n";
      print STDERR "Error: $@\n" if $verbose;
      $problems++;
    } else { 
#print "OK on table $_\n";
      $ok++;
    }
  }
  print ERRS "\n\n";
  print "Saw $problems tables with errors\n";
  print "Saw $ok tables without errors\n";
  return $problems;
}

sub readTableFile {

  my $argref = shift || die "Failed to pass arguement reference";

  open( TAB, "$argref->{table}") || 
                           die ( "Cannot open table file $argref->{table}" );
  my @expected_theads = ( qw(table_name Category table_group 
                             manage_table_allowed db_table_name PK_column_name
                             multi_insert_column table_url manage_tables
                             next_step ) );
  
  my $tline = <TAB>;
  chomp( $tline );
  $tline =~ s/[\r\n]//g;  # WTF
  my @theads = split("\t",$tline, -1);
  die "Incorrect number of entries in column file" if scalar( @theads ) != 10;
  my $index = 0;
  for ( @theads ) { 
    print ">$_<\n" if $argref->{verbose};
    $_ = $1 if ( /^\"(.*)\"$/ );
    die ( "Unknown table heading $_" ) unless $_ eq $expected_theads[$index++];
  }
  my %table; # Hash keyed on table_name points at db_column_name
  while( my $line = <TAB> ) {
    $line =~ s/[\r\n]//g;  # WTF
    next if $line =~ /^\s*$/;
    my @guts = split("\t",$line, -1);
    $guts[0] =~ s/\"//g;
    $guts[4] =~ s/\"//g;
    $table{$guts[0]} = getTableSchema( @guts[0,4] ) unless $guts[2] eq 'QUERY';
  }
#for( keys( %table ) ) {print "$_ => $table{$_}\n" if $argref->{verbose}; }
  return \%table;

} # End readColumnFile


sub readColumnFile {

  my $argref = shift || die "Failed to pass arguement reference";

  open( COL, "$argref->{column}") ||
                          die ("Can't open column file $argref->{column}");
  my @expected_cheads = ('table_name','column_index','column_name',
      'column_title','datatype','scale','precision','nullable',
      'default_value','is_auto_inc','fk_table','fk_column_name',
      'is_required','input_type','input_length','onChange','is_data_column',
      'is_display_column','is_key_field','column_text','optionlist_query',
      'url');
  
  my $cline = <COL>;
  chomp( $cline );
  $cline =~ s/[\r\n]//g;  # WTF
  my @cheads = split("\t",$cline, -1);
  die "Incorrect number of entries in column file" if scalar( @cheads ) != 22;
  my $index = 0;
  for ( @cheads ) {
    $_ = $1 if ( /^\"(.*)\"$/ );
    die "Unknown column heading $_" unless $_ eq $expected_cheads[$index++];
  }
  my %column; # hash of hashrefs where column name keys to datatype
  while( my $line = <COL> ) {
    $line =~ s/[\r\n]//g;  # WTF
    next if $line =~ /^\s*$/;
    my @guts = split("\t", $line, -1);
    $guts[0] =~ s/\"//g;
    $guts[2] =~ s/\"//g;
    $guts[4] =~ s/\"//g;
    $column{$guts[0]} ||= {};
    $column{$guts[0]}->{$guts[2]} = $guts[4];
  }
  return \%column;

} # End readColumnFile




  sub checkOpts {
    my %args;
    GetOptions( \%args,"verbose", "table=s", "column=s", "dsn:s" );
    foreach ( qw( table column ) ) {
      if ( !$args{$_} ) {
        print STDERR "Missing required parameter $_\n";
        printUsage();
        exit;
        }
      if ( ! -e $args{$_} ) {
        print STDERR "Specified $_ file non-existant\n";
        printUsage();
        exit;
      }
    }
    return %args;
  }
    


sub printUsage {
  print <<"  EOU";
  Usage: $0 -t tablefile -c columnfile -d DBIconnectString
  Options:
    --verbose, -v           Set verbose messaging
    --table, -t  xxx        Set the name of table property file
    --column, -c xxx        Set the name of column property file
    --dsn, -d               DBI connect string
    
  EOU

}

sub getTableSchema {
  my $table = shift; # table name
  my $dbtable = shift; # db table name
  $dbtable =~ s/\"//g;

  my $realname = eval "\"$dbtable\"";

  if ( $realname ) { # Defined in imported symbols.
    return $realname;
  } else {
    print STDERR "Unable to find db table <$dbtable> for table <$table>\n";
  }

## Legacy guess work below!  

  my $prefix = substr( $table, 0, 3 ); 
  my $strip = $table;
  if ( $prefix =~ /[A-Z][A-Z]_/ ) {
    $strip =~ s/$prefix//;
  }
   
  my $linker = '.dbo.'; # linker
  return 'PeptideAtlas' . $linker . $strip if $prefix eq 'AT_';
  return 'BioLink' . $linker . $strip if $prefix eq 'BL_';
  return 'Proteomics' . $linker . $strip if $prefix eq 'PR_';
  return 'Microarray' . $linker . $strip if $prefix eq 'MA_';
  return 'BioSequence' . $linker . $strip if $prefix eq 'BS_';
  return 'InkJet' . $linker . $strip if $prefix eq 'IJ_';
  return 'SNP' . $linker . $strip if $prefix eq 'SN_';
  return 'BioSequence' . $linker . $strip if $prefix eq 'BS_';
  return 'Cytometry' . $linker . $strip if $prefix eq 'CY_';
  return 'Genotyping' . $linker . $strip if $prefix eq 'GT_';
  return 'Immunostain' . $linker . $strip if $prefix eq 'IS_';
  return 'Interactions' . $linker . $strip if $prefix eq 'IN_';
  return 'Oligo' . $linker . $strip if $prefix eq 'OG_';
  return 'Phenoarray' . $linker . $strip if $prefix eq 'PH_';
  return 'Interactions' . $linker . $strip if $prefix eq 'IN_';
  return 'ProteinStructure' . $linker . $strip if $prefix eq 'PS_';
  return 'UESC' . $linker . $strip if $prefix eq 'PH_';
  return 'sbeams' . $linker . $table;
 }
