#!/usr/local/bin/perl -w

###############################################################################
# Program     : load_serume_peptide_data.pl
# Author      : Pat Moss <pmoss@systemsbiology.org>
#
# Description : Script will parse the peptide data from Paul L into tables
#
###############################################################################
our $VERSION = '1.00';

=head1 NAME
parsing script

head2 WARNING


=head2 EXPORT

Nothing


=head1 SEE ALSO


=head1 AUTHOR

Pat Moss, E<lt>pmoss@localdomainE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2004 by Pat Moss

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.3 or,
at your option, any later version of Perl 5 you may have available.


=cut

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
use vars qw ($sbeams $q $sbeams_affy $sbeams_affy_groups
             $PROG_NAME $USAGE %OPTIONS 
			 $VERBOSE $QUIET $DEBUG 
			 $DATABASE $TESTONLY $PROJECT_ID 
			 $CURRENT_USERNAME 
			$FILE
	    );

# Unbuffer STDOUT
$|++;


#### Set up SBEAMS core module
use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::Glycopeptide::Tables;

use SBEAMS::Glycopeptide::Glyco_peptide_load;




$sbeams = new SBEAMS::Connection;

#$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);


###############################################################################
# Set program name and usage banner for command like use
###############################################################################
$PROG_NAME = $FindBin::Script;


$USAGE = <<EOU;
$PROG_NAME is used load glyco_peptide data. 


Usage: $PROG_NAME --file [OPTIONS]
Options:
    --verbose <num>    Set verbosity level.  Default is 0
    --quiet            Set flag to print nothing at all except errors
    --debug n          Set debug flag    
    --file <file path> file path to the file to upload
    --testonly         Information in the database is not altered

 
  
Examples;
1) ./$PROG_NAME --file <path to file>
EOU

		
		
#### Process options
unless (GetOptions(\%OPTIONS,
		   "verbose:i",
		   "quiet",
		   "debug:i",
		   "file:s",
		   "testonly",
		   )) {
  printUSAGE();
 
}

#Setup a few global variables
$VERBOSE    = $OPTIONS{verbose} || 0;
$QUIET      = $OPTIONS{quiet};
$DEBUG      = $OPTIONS{debug};
$TESTONLY   = $OPTIONS{testonly};
$FILE = $OPTIONS{file};


printUsage( 'Specified file does not exist' ) unless -e $FILE;

if ($DEBUG) {
  print "Options settings:\n";
  print "  VERBOSE = $VERBOSE\n";
  print "  QUIET = $QUIET\n";
  print "  DEBUG = $DEBUG\n";
  print "  FILE = $FILE\n";
 
}


###############################################################################
# Set Global Variables and execute main()
###############################################################################
main();
exit(0);


###############################################################################
# Main Program:
#
# Call $sbeams->Authenticate() and exit if it fails or continue if it works.
###############################################################################
sub main {
  
  # Try to determine which module we want to affect
  my $module = $sbeams->getSBEAMS_SUBDIR();
  my $work_group = 'unknown';
  if ($module eq 'Glycopeptide') {
	$work_group = "Glycopeptide_admin";
	$DATABASE = $DBPREFIX{$module};
 	print "DATABASE '$DATABASE'\n" if ($DEBUG);
  } else {
    printUsage( "Unknown module: $module" );
  }
  print "$DBPREFIX{$module}\n" if $VERBOSE;

  # Authenticate() or exit
  $CURRENT_USERNAME = $sbeams->Authenticate(work_group => $work_group) ||
  printUsage('Authentication failed');
	
 	load_file();
} # end main



sub load_file {
	my %args = @_;
	
  # The meat...
	my $glyco_o = new SBEAMS::Glycopeptide::Glyco_peptide_load(sbeams => $sbeams,
														   verbose => $VERBOSE,
														   debug =>$DEBUG,
														   test_only =>$TESTONLY,
														   file =>$FILE,);
  # and potatoes.
	$glyco_o->process_data_file();
	
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
  print "\n$msg\n\n$USAGE\n";
  exit;
}




