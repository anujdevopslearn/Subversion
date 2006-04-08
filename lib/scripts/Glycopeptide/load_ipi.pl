#!/usr/local/bin/perl -w

###############################################################################
#
# Description : Script will parse the peptide data from Paul L into tables
#
###############################################################################
our $VERSION = '1.00';


###############################################################################
# Generic SBEAMS setup for all the needed modules and objects
###############################################################################
use strict;
use File::Basename;
use Data::Dumper;

use Getopt::Long;
use FindBin;
use Cwd;

use lib "$FindBin::Bin/../../perl";

# Unbuffer STDOUT
$|++;

use vars (qw($DBRPEFIX));

#### Set up SBEAMS core module
use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
my $sbeams = new SBEAMS::Connection;

use SBEAMS::Glycopeptide::Tables;
use SBEAMS::Glycopeptide::Glyco_peptide_load;


my $program = $FindBin::Script;
my %args;

#### Process options
unless (GetOptions(\%args, "verbose:i", "release:s", "file:s", 
                           "testonly", "overwrite" )) {
  printUsage('Failed to fetch options');
}

printUsage('Missing required parameter "file"') unless $args{file};
$args{release} ||= $args{file};

{ # Main
  
  # Try to determine which module we want to affect
  my $module = $sbeams->getSBEAMS_SUBDIR();
  my $work_group = 'unknown';
  if ($module eq 'Glycopeptide') {
	$work_group = "Glycopeptide_admin";
	my $db = $DBPREFIX{$module};
 	print "Database '$db'\n" if ($args{verbose});
  } else {
    printUsage( "Unknown module: $module" );
  }
  print "$DBPREFIX{$module}\n" if $args{verbose};
	
  # Authenticate() or exit
  my $username = $sbeams->Authenticate(work_group => $work_group) ||
  printUsage('Authentication failed');

 	load_file();
} # end main



sub load_file {
	
  # The meat...
  my $glyco_o = SBEAMS::Glycopeptide::Glyco_peptide_load->new(sbeams => $sbeams,
                                                      verbose => $args{verbose},
                                                              sbeams => $sbeams,
                                                      release => $args{release},
                                                           file => $args{file});
  # and potatoes.
	$glyco_o->process_data_file(load_peptides => 0);
	
	if ($glyco_o->anno_error){
		print "*" x 75 .  "\n\n";
		print "Errors are below\n";
		print $glyco_o->anno_error;
	}else{
		print "No Errors reported\n";	
	}
	
 
}

sub printUsage {
  my $msg = shift || '';
my $usage = <<EOU;
$msg

$program is used load ipi data. 

Usage: $program --file [OPTIONS]
Options:
    --verbose <num>    Set verbosity level.  Default is 0
    --file <file path> file path to the file to upload
    --testonly         Information in the database is not altered
    --release          Version of the IPI database

 
$program -f <path to file> -v 2.28
EOU
  print "\n$usage\n";
  exit;
}




