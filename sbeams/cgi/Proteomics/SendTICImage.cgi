#!/usr/local/bin/perl

###############################################################################
# Program     : SendTICImage.cgi
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This CGI program sends the requested TIC spectrum
#               for a provided fraction
#
###############################################################################


###############################################################################
# Basic SBEAMS setup
###############################################################################
use strict;
use lib qw (../../lib/perl);
use vars qw ($q $sbeams $sbeamsPROT
             $current_contact_id $current_username );
use CGI;
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::Proteomics;
use SBEAMS::Proteomics::Settings;
use SBEAMS::Proteomics::Tables;

$q = new CGI;
$sbeams = new SBEAMS::Connection;
$sbeamsPROT = new SBEAMS::Proteomics;
$sbeamsPROT->setSBEAMS($sbeams);


###############################################################################
# Define global variables if any and execute main()
###############################################################################
main();


###############################################################################
# Main Program:
#
# If $sbeams->Authenticate() succeeds, print header, process the CGI request,
# print the footer, and end.
###############################################################################
sub main {

    #### Do the SBEAMS authentication and exit if a username is not returned
    exit unless ($current_username = $sbeams->Authenticate());

    #### Print the header, figure and do what the user want, and print footer
    #$sbeamsPROT->printPageHeader();
    processRequests();
    #$sbeamsPROT->printPageFooter();

} # end main


###############################################################################
# Process Requests
#
# Test for specific form variables and process the request
# based on what the user wants to do.
###############################################################################
sub processRequests {
    $current_username = $sbeams->getCurrent_username;
    $current_contact_id = $sbeams->getCurrent_contact_id;


    # Enable for debugging
    if (0==1) {
      print "Content-type: text/html\n\n";
      my ($ee,$ff);
      foreach $ee (keys %ENV) {
        print "$ee =$ENV{$ee}=<BR>\n";
      }
      foreach $ee ( $q->param ) {
        $ff = $q->param($ee);
        print "$ee =$ff=<BR>\n";
      }
    }


    #### Only one view available for this program
    printEntryForm();


} # end processRequests



###############################################################################
# Print Entry Form
###############################################################################
sub printEntryForm {

  #### Define some general variables
  my ($i,$element,$key,$value,$sql);


  #### Define the parameters that can be passed by CGI
  my @possible_parameters = qw ( fraction_id );
  my %parameters;


  #### Read in all the passed parameters into %parameters hash
  foreach $element (@possible_parameters) {
    $parameters{$element}=$q->param($element);
  }
  my $apply_action  = $q->param('apply_action');


  #### Resolve the keys from the command line if any
  my ($key,$value);
  foreach $element (@ARGV) {
    if ( ($key,$value) = split("=",$element) ) {
      $parameters{$key} = $value;
    } else {
      print "ERROR: Unable to parse '$element'\n";
      return;
    }
  }


  #### verify that needed parameters were passed
  unless ($parameters{fraction_id}) {
    print "ERROR: not all needed parameters were passed.  This should never ".
      "happen!  Please report this error.<BR>\n";
    return;
  }


  #### Find the corresponding information for this fraction_id
  $sql = qq~
	SELECT fraction_tag,data_location
	  FROM $TBPR_FRACTION F
	  JOIN $TBPR_SEARCH_BATCH SB ON ( F.experiment_id = SB.experiment_id )
	 WHERE fraction_id = '$parameters{fraction_id}'
  ~;

  my %fractions = $sbeams->selectTwoColumnHash($sql);
  unless (%fractions) {
    print "ERROR: Unable to find any fractions for fraction_id".
      " = '$parameters{fraction_id}'.  This really should never ".
      "happen!  Please report the problem.<BR>\n";
    return;
  }


  #### Send the data
  print "Content-type: image/png\n\n";
  while ( ($key,$value) = each %fractions ) {
    my $filename = "$value/../$key.png";
    unless ($filename =~ /^\//) {
      $filename = $RAW_DATA_DIR{Proteomics}."/$filename";
    }
    my $buffer;
    open(DATA, $filename)
      || croak "Couldn't open $filename: $!";
    while (read(DATA, $buffer, 1024)) {
        print $buffer;
    }
    last;
  }



} # end printEntryForm


