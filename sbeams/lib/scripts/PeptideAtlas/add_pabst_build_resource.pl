#!/usr/local/bin/perl 

###############################################################################
# Program     : load_RTcatalog_scores.pl
# Author      : zsun <zsun@systemsbiology.org>
# 
#
# Description : This script load the database for RTcatalog values
#
###############################################################################

use strict;
use Getopt::Long;
use File::Basename;
use FindBin;
use Data::Dumper;

#### Set up SBEAMS modules
use lib "$FindBin::Bin/../../perl";
use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;

use vars qw ($sbeams $atlas $q $current_username );

# don't buffer output
$|++;

## Globals
$sbeams = new SBEAMS::Connection;
$atlas = new SBEAMS::PeptideAtlas;
$atlas->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);

# Known resource types spectral_lib elution_set chromatogram_set
my %resources = ( spectral_lib => { table => $TBAT_CONSENSUS_LIBRARY, key => 'consensus_library_id', name => 'consensus_library_name' },
                  elution_set => { table => $TBAT_ELUTION_TIME_TYPE, key => 'elution_time_type_id', name => 'elution_time_type' },
                  pabst_build => { table => $TBAT_PABST_BUILD, key => 'pabst_build_id', name => 'build_name' },
                  instrument_type => { table => $TBAT_INSTRUMENT_TYPE, key => 'instrument_type_id', name => 'instrument_type_name' },
                  qtof_ce_set => { table => $TBAT_CONSENSUS_LIBRARY, key => 'consensus_library_id', name => 'count(*) cnt' },
                  chromatogram_set => { table => $TBAT_CHROMATOGRAM_SOURCE_FILE, key => 'source_file_set', name => 'count(*) AS cnt' } );

## Process options
my $opts = get_opts();

main();
exit(0);


###############################################################################
# Main Program:
#
# Call $sbeams->Authenticate() and exit if it fails or continue if it works.
###############################################################################
sub main {

  #### Do the SBEAMS authentication and exit if a username is not returned
  $current_username = $sbeams->Authenticate( work_group=>'PeptideAtlas_admin' ) || exit;

  if ( $opts->{list} ) {
    list_resource();
    exit;
  }

  if ( $opts->{resource_type} &&
       $opts->{resource_id} &&
       $opts->{pabst_build_id} &&
       $opts->{instrument_type}  ) {

    insert_resource();

  } else {
    my $args = Dumper( $opts );
    usage( "Nothing to do with:\n $args" );
  }



} # end fillTable


sub insert_resource {

  my %rowdata = ( pabst_build_id => $opts->{pabst_build_id},
                  resource_type => $opts->{resource_type},
                  resource_id => $opts->{resource_id},
                  instrument_type_id => $opts->{instrument_type},
                );

  print "Adding:\n";
  list_resource();
  list_resource( resource => 'pabst_build', resource_id => $opts->{pabst_build_id}, suppress => 1 );
  list_resource( resource => 'instrument_type', resource_id => $opts->{instrument_type}, suppress => 1 );

  $sbeams->updateOrInsertRow( insert => 1,
                          table_name => $TBAT_PABST_BUILD_RESOURCE,
                         rowdata_ref => \%rowdata,
                         verbose     => $opts->{verbose},
                         testonly    => $opts->{testonly} );
}

sub list_resource {

  my %args = @_;
  my $type = $args{resource} || $opts->{resource_type};
  my $id = $args{resource_id} || $opts->{resource_id};

  my $r = $resources{$type} || die;

  my $organism = ( $opts->{organism_id} ) ? " AND organism_id = $opts->{organism_id} " : '';
  my $resource = ( $opts->{resource_id} ) ? " AND $r->{key} = $id " : '';

  my $group = '';
  if ( $r->{name} =~ /count.*cnt/i ) {
    $group = "GROUP BY $r->{key}";
  }

  my $sql = qq~
  SELECT $r->{name}, $r->{key}
  FROM $r->{table}
  WHERE 1 = 1
  $organism
  $resource
  $group
  ~;

  unless( $args{suppress} ) {
    print "$opts->{resource_type}: $r->{table}\n";
    print join( "\t", $r->{key}, $r->{name} ) . "\n";
  }
  my $sth = $sbeams->get_statement_handle( $sql );
  while( my $row = $sth->fetchrow_arrayref() ) {
    print "$row->[1]:\t$row->[0]\n";
  }
}


sub usage {
  my $msg = shift || '';
  my $program = basename( $0 );
  print <<"  EOU";
  $msg

  Usage: $program [opts]

   $program --source_file chromat_info_file --instrument_name 'QTrap5500 --load' 

  Options:
    --verbose n            Set verbosity level.  default is 0
    --quiet                Set flag to print nothing at all except errors
    --debug n              Set debug flag
    --help                 print this usage and exit.
    --delete               Delete paths of this type
    --organism_id          Organism_id of data
    --instrument_type      QTOF,QQQ,QTrap5500,QTrap4000,TSQ,IonTrap - used for 
                           delete, provided in input file for load               
    --resource_type        Type of resource to be linked
    --resource_id          ID of resource to be linked

  EOU
  exit;
}

sub get_opts {

  my %opts;
  GetOptions( \%opts,"verbose:s", "quiet", 'pabst_build_id=i',
              "instrument_type=i", 'resource_type=s', 'resource_id=i',
              'help', 'organism_id=i', 'list' ) || usage( "Error processing options" );

  $opts{verbose} ||= 0;
  
  if ( $opts{help} ) {
    print Dumper( %opts );
  }
  
  my @mia;
  for my $req ( qw(  resource_type ) ) {
    push @mia, $req unless defined $opts{$req};
  }
  if ( @mia ) {
    my $mia_str = join( ',', @mia );
    usage( "missing required arguement(s) $mia_str" );
  }
  
  if($opts{"help"}){
   usage();
  }

  unless ( $resources{$opts{resource_type}} ) {
    my $resources = join( ',', keys( %resources ) );
    usage( "Unknown resource type: $opts{resource_type}.  Acceptable values are $resources\n" );  
  }


  return \%opts;

}
  
  
__DATA__
  my %args = @_;


  if ( $opts{'delete'} ) {
    print STDERR "Beginning delete of $instrument ( $instr_id ) entries in 5 seconds\n";
    sleep 5;
    for my $aa ( 'A'..'Z' ) {
      print "Deleting $aa...\n";
      my $delsql = "DELETE FROM $TBAT_CHROMATOGRAM_SOURCE_FILE WHERE instrument_type_id = $instr_id AND peptide_ion LIKE '$aa%'";
      $sbeams->do( $delsql );
    }
    exit 1;
  }

  my $source_set_sql = qq~
  SELECT MAX( source_file_set )
  FROM $TBAT_CHROMATOGRAM_SOURCE_FILE
  ~;
  my @sets = $sbeams->selectrow_array( $source_set_sql ); # || die "Unable to find source sets";

  my $source_set = $sets[0] || 0;
  $source_set++;


  my %rowdata = ( instrument_type_id => $instr_id,
                  peptide_ion => $cols[0],
                  modified_sequence => $cols[1],
                  charge => $cols[2],
                  mzML_path => $cols[3],
                  scan_number => $cols[4],
                );

#    die Dumper( %rowdata );

     $sbeams->updateOrInsertRow( insert => 1,
                             table_name => $TBAT_CHROMATOGRAM_SOURCE_FILE,
                            rowdata_ref => \%rowdata,
                            verbose     => $opts{verbose},
                            testonly    => $opts{testonly} );

    $counter++;
    print "$counter." if($counter%100 == 0);
  }
  print "$counter rows update or inserted\n";
