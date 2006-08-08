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
my %args;

#### Process options
unless (GetOptions(\%args, "verbose:i", "release:s", "file:s", 
                   "testonly", 'organism:s', 'comment:s' )) {
  printUsage('Failed to fetch options');
}

my $missing;
for my $opt ( qw( file organism release ) ) {
  $missing = ( $missing ) ? $missing . ', ' . $opt : $opt unless defined $args{$opt};
}
printUsage( "Missing required parameter(s): $missing " ) if $missing;


{ # Main
  
  my $work_group = "Glycopeptide_admin";
  my $db = lc($DBPREFIX{Glycopeptide});
  $db =~ s/\.dbo\.//g;
  print "Database '$db'\n" if ($args{verbose});

  # Safety catch
  die( "Wrong db target: $db" ) unless $db eq 'glycopeptide';
	
  # Authenticate() or exit
  my $username = $sbeams->Authenticate(work_group => $work_group) ||
  printUsage('Authentication failed');

 	load_file();
} # end main



sub load_file {
	
  # The meat...
  my $glyco_o = SBEAMS::Glycopeptide::Glyco_peptide_load->new(sbeams => $sbeams, %args);
  # and potatoes.
	$glyco_o->insert_ipi_db( %args );
	
	print $glyco_o->anno_error();

}

sub printUsage {
  my $msg = shift || '';
my $usage = <<EOU;
$msg

$program is used load ipi db into Unipep/Glycopeptide tables. 

Usage: $program -f ipi_file -r ipi_version -o organism [-v level -t -d -c 'comment here' ]
Options:
    -v, --verbose <num>    Set verbosity level.  Default is 0
    -f, --file <file path> file path to the file to upload
    -t, --testonly         Information in the database is not altered
    -r, --release          Version of the IPI database
    -d, --default          Specify this as the default version for organism 
    -o, --organism         Common name (i.e. Mouse or Human) for organism
    -c, --comment          comment

EOU
  print "\n$usage\n";
  exit;
}




