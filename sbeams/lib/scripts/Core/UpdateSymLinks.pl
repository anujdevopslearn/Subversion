#!/usr/local/bin/perl

###############################################################################
# Program     : UpdateSymLinks.pl
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This script checks and possibly fixes the symbolic links
#               within the SBEAMS directory structure
#
# SBEAMS is Copyright (C) 2000-2002 by Eric Deutsch
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################


###############################################################################
# Generic SBEAMS script setup
###############################################################################
use strict;
use Getopt::Long;
use FindBin;

use lib qw (../perl ../../perl);
use vars qw ($sbeams
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
             $TESTONLY
             $current_contact_id $current_username
             $current_work_group_id $current_work_group_name
             $current_project_id $current_project_name);


#### Set up SBEAMS package
use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TableInfo;
$sbeams = new SBEAMS::Connection;


#### Set program name and usage banner
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS] parameters
Options:
  --verbose n         Set verbosity level.  default is 0
  --quiet             Set flag to print nothing at all except errors
  --debug n           Set debug flag
  --testonly          Set to not actually make any changes

 e.g.:  $PROG_NAME --testonly

EOU


#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
  )) {
  print "$USAGE";
  exit;
}
$VERBOSE = $OPTIONS{"verbose"} || 0;
$QUIET = $OPTIONS{"quiet"} || 0;
$DEBUG = $OPTIONS{"debug"} || 0;
$TESTONLY = $OPTIONS{"testonly"} || 0;
if ($DEBUG) {
  print "Options settings:\n";
  print "  VERBOSE = $VERBOSE\n";
  print "  QUIET = $QUIET\n";
  print "  DEBUG = $DEBUG\n";
  print "  TESTONLY = $TESTONLY\n";
}



###############################################################################
# Set Global Variables and execute main()
###############################################################################
main();
exit 0;



###############################################################################
# Main Program:
#
# Call $sbeams->Authenticate() and exit if it fails or continue if it works.
###############################################################################
sub main {

  #### Do the SBEAMS authentication and exit if a username is not returned
  #exit unless ($current_username =
  #  $sbeams->Authenticate(work_group=>'Developer'
  #));

  $sbeams->guessMode();


  $sbeams->printPageHeader() unless ($QUIET);
  handleRequest();
  $sbeams->printPageFooter() unless ($QUIET);


} # end main


###############################################################################
# handleRequest
###############################################################################
sub handleRequest {
  my %args = @_;


  #### Define standard variables
  my ($i,$element,$element_value,$key,$value,$line,$result,$sql);


  #### Set the command-line options


  #### If there are any parameters left, complain and print usage
  if ($ARGV[0]){
    print "ERROR: Unresolved parameter '$ARGV[0]'.\n";
    print "$USAGE";
    exit;
  }


  #### Print out the header
  #unless ($QUIET) {
  #  $sbeams->printUserContext();
  #  print "\n";
  #}


  #### Define the links or directories to check
  my @entities_to_check = (
    {entity=>'tmp',ref_location=>'',flags=>{sym_to_main=>1,real_ok=>1}},
    {entity=>'data',ref_location=>'',flags=>{sym_to_main=>1,real_ok=>1}},
    {entity=>'doc/includes',ref_location=>'../../../includes',flags=>{sym_to_main=>0,real_ok=>0}},
    {entity=>'lib/scripts/Biosap/load_biosequence_set.pl',ref_location=>'../share/load_biosequence_set.pl',flags=>{sym_to_main=>0,real_ok=>0}},
    {entity=>'lib/scripts/Microarray/load_biosequence_set.pl',ref_location=>'../share/load_biosequence_set.pl',flags=>{sym_to_main=>0,real_ok=>0}},
    {entity=>'lib/scripts/Proteomics/load_biosequence_set.pl',ref_location=>'../share/load_biosequence_set.pl',flags=>{sym_to_main=>0,real_ok=>0}},
    {entity=>'lib/scripts/SNP/load_biosequence_set.pl',ref_location=>'../share/load_biosequence_set.pl',flags=>{sym_to_main=>0,real_ok=>0}},
     {entity=>'lib/scripts/ProteinStructure/load_biosequence_set.pl',ref_location=>'../share/load_biosequence_set.pl',flags=>{sym_to_main=>0,real_ok=>0}},
 );


  #### Loop over all files
  foreach my $entity_ref ( @entities_to_check ) {
    my $entity = $entity_ref->{entity};
    my $ref_location = $entity_ref->{ref_location};
    my $flags = $entity_ref->{flags};

    my $abs_entity = "$PHYSICAL_BASE_DIR/$entity";
    print "\n";


    #### Count the number of levels removed by counting /'s
    my $n_levels = $entity =~ tr/\//\//;

    #### If it's supposed to be a symlink to the main area, define ref_location
    if ($flags->{sym_to_main} && !($ref_location)) {
      $ref_location = '../' x ($n_levels+2) . 'sbeams/' . $entity;
    }


    #### Check to see if the entity exists
    if (-e $abs_entity) {
      print "Entity '$entity' exists.\n";

      #### Find out what it is
      my $is_a_symlink = (-l $abs_entity);
      my $is_a_directory = (-d $abs_entity);

      my $link_location = '';
      if ($is_a_symlink) {
        $link_location = readlink($abs_entity);
        print "  Is a link to '$link_location'\n";
      }


      if ($ref_location) {
        if ($ref_location eq $link_location) {
          print "  As it should be\n";
	} else {
          if (!($is_a_symlink) && $is_a_directory && $flags->{real_ok}) {
            print "  But is a real directory and that's okay.\n";
          } else {
            print "  WARNING: Supposed to be a link to '$ref_location'\n";
	    print "    rm $abs_entity\n";
	    print "    ln -s $ref_location $abs_entity\n";
          }
        }
      }




    #### If it does NOT exist
    } else {
      print "Entity '$entity' does not exist!\n";

      if ($ref_location) {
        print "  WARNING: Should create a link to '$ref_location'\n";
	print "    ln -s $ref_location $abs_entity\n";
      } else {
        print "  WARNING: Not sure what to do about it\n";
      }

    }

  }


} # end handleRequest
