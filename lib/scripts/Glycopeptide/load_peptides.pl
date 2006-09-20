#!/usr/local/bin/perl -w

# Description : load (specifically formatted) ipi db file into 
# unipep tables.  Split out from monolithic ipi_data/peptides file

use strict;
use File::Basename;
use Data::Dumper;
use Getopt::Long;
use FindBin;
use Cwd;

use lib "$FindBin::Bin/../../perl";

use vars (qw($DBRPEFIX));

#### Set up SBEAMS core module
use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::Glycopeptide::Tables;
use SBEAMS::Glycopeptide::Glyco_peptide_load;

# Unbuffer STDOUT
$|++;

# Global express...
my $sbeams = new SBEAMS::Connection;
my $program = basename( $0 ); 
my %opts;


{ # Main
  
  my $work_group = "Glycopeptide_admin";
  my $db = lc($DBPREFIX{Glycopeptide});
	
  # Authenticate() or exit
  my $username = $sbeams->Authenticate(work_group => $work_group) ||
  printUsage('Authentication failed');

  process_options();
 	load_file();
} # end main



sub load_file {
  my $glyco_o = SBEAMS::Glycopeptide::Glyco_peptide_load->new( %opts ) || die "No object";
	$glyco_o->insert_peptides( %opts );
	print $glyco_o->anno_error() . "\n";
}

sub print_usage {
  my $msg = shift || '';
  my $usage = <<EOU;
$msg

$program is used load ipi db into Unipep/Glycopeptide tables. 

Usage: $program -p peptide_file -r ipi_version [ -f file_format -v ]
Options:
    -v, --verbose             Print verbose output.
    -p, --peptide_file path   File path to the file to upload
    -t, --testonly            Information in the database is not altered
    -r, --release             Version of the IPI database, must match db version exactly
    -s, --sample              Sample from which data is derived.

EOU
  print "\n$usage\n";
  exit;
}

sub process_options {

  unless (GetOptions( \%opts, "verbose", "release:s", "testonly", 
                      "sample=s", "format:s", "peptide_file:s" )) {
    printUsage('Failed to fetch options');
  }
#  for my $o ( keys ( %opts ) ) { print "opt: $o => $opts{$o}\n"; }

  my $err;
  for my $opt ( qw( peptide_file release sample ) ) {
    $err = ( $err ) ? $err . ', ' . $opt : $opt if !defined $opts{$opt};
  }
  print_usage( "Missing required parameter(s): $err " ) if $err;

  # Check ipi provided with values in database.
  my $match = 0;
  my $msg = "Unknown version specified, valid versions include:\n";
  my $sql = "SELECT ipi_version_name, ipi_version_id FROM $TBGP_IPI_VERSION order by ipi_version_name ASC";
  while ( my $row = $sbeams->selectSeveralColumnsRow( sql => $sql ) ) {
    if ( $opts{release} eq $row->[0] ) {
      $match++;
      $opts{ipi_version_id} = $row->[1];
    }
    $msg .= "$row->[0]\n";
  }
  print_usage( $msg ) unless $match;

  # Check sample provided with values in database.
  $match = 0;
  my $msg = "Unknown sample specified, known samples include:\n";
  $sql = "SELECT sample_name, sample_id FROM $TBGP_UNIPEP_SAMPLE order by sample_name ASC";
  while ( my $row = $sbeams->selectSeveralColumnsRow( sql => $sql ) ) {
    if ( $opts{sample} eq $row->[0] ) {
      $match++;
      $opts{sample_id} = $row->[1];
    }
    $msg .= "$row->[0]\n";
  }
  print_usage( $msg ) unless $match;
  $opts{format} ||= 'interact-tsv';
}

