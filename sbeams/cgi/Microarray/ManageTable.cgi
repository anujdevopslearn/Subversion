#!/usr/local/bin/perl

###############################################################################
# Program     : ManageTable.cgi
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This CGI program that allows users to
#               manage the contents of a table.
#               This means viewing, inserting, updating,
#               and deleting records.
#
# SBEAMS is Copyright (C) 2000-2003 by Eric Deutsch
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################


###############################################################################
# Set up all needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;

use lib "$FindBin::Bin/../../lib/perl";
use vars qw ($sbeams $sbeamsMOD $q $dbh $current_contact_id $current_username
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
             $current_work_group_id $current_work_group_name
             $current_project_id $current_project_name
             $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
             $PK_COLUMN_NAME @MENU_OPTIONS);
use DBI;
use CGI;
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TableInfo;
$q = new CGI;
$sbeams = new SBEAMS::Connection;

use SBEAMS::Microarray;
use SBEAMS::Microarray::Settings;
use SBEAMS::Microarray::Tables;
use SBEAMS::Microarray::TableInfo;
$sbeamsMOD = new SBEAMS::Microarray;

$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);

require 'ManageTable.pllib';



###############################################################################
# Set program name and usage banner for command like use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS] key=value kay=value ...
Options:
  --verbose n         Set verbosity level.  default is 0
  --quiet             Set flag to print nothing at all except errors
  --debug n           Set debug flag

 e.g.:  $PROG_NAME [OPTIONS] [keyword=value],...

EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s")) {
  print "$USAGE";
  exit;
}

$VERBOSE = $OPTIONS{"verbose"} || 0;
$QUIET = $OPTIONS{"quiet"} || 0;
$DEBUG = $OPTIONS{"debug"} || 0;
if ($DEBUG) {
  print "Options settings:\n";
  print "  VERBOSE = $VERBOSE\n";
  print "  QUIET = $QUIET\n";
  print "  DEBUG = $DEBUG\n";
}



###############################################################################
# Set Global Variables and execute main()
###############################################################################
# Set maximum post (file upload) to 30 MB
$CGI::POST_MAX = 1024 * 30000;
main();
exit(0);



###############################################################################
# Main Program:
#
# Call $sbeams->InterfaceEntry with pointer to the subroutine to execute if
# the authentication succeeds.
###############################################################################
sub main {

  #### Do the SBEAMS authentication and exit if a username is not returned
  exit unless ($current_username = $sbeams->Authenticate(
    #connect_read_only=>1,
    #allow_anonymous_access=>1,
    #permitted_work_groups_ref=>['Proteomics_user','Proteomics_admin'],
  ));

  #### Read in the default input parameters
  my %parameters;
  my $n_params_found = $sbeams->parse_input_parameters(
    q=>$q,parameters_ref=>\%parameters);
  #$sbeams->printDebuggingInfo($q);

  #### Process generic "state" parameters before we start
  $sbeams->processStandardParameters(parameters_ref=>\%parameters);


  $TABLE_NAME = $parameters{'TABLE_NAME'}
    || croak "TABLE_NAME not specified."; 

  croak "This TABLE_NAME=$TABLE_NAME cannot be managed by this program."
    unless ($sbeamsMOD->returnTableInfo($TABLE_NAME,
      "ManageTableAllowed"))[0] eq "YES";

  ($CATEGORY) = $sbeamsMOD->returnTableInfo($TABLE_NAME,"CATEGORY");
  ($PROGRAM_FILE_NAME) = $sbeamsMOD->returnTableInfo($TABLE_NAME,
    "PROGRAM_FILE_NAME");
  ($DB_TABLE_NAME) = $sbeamsMOD->returnTableInfo($TABLE_NAME,"DB_TABLE_NAME");
  ($PK_COLUMN_NAME) = $sbeamsMOD->returnTableInfo($TABLE_NAME,
    "PK_COLUMN_NAME");
  @MENU_OPTIONS = $sbeamsMOD->returnTableInfo($TABLE_NAME,"MENU_OPTIONS");


  #### Decide what action to take based on information so far
  if ($parameters{"GetFile"} && $parameters{"$PK_COLUMN_NAME"}) {
    getFile(); return;
  }
  $sbeamsMOD->printPageHeader();
  if      ($parameters{action} eq 'VIEWRESULTSET') { printOptions();
  } elsif ($parameters{action} eq 'REFRESH') { printEntryForm();
  } elsif ($parameters{action}) { processEntryForm();
  } elsif ($q->param('apply_action_hidden')) { printEntryForm();
  } elsif ($q->param('ShowEntryForm')) { printEntryForm();
  } elsif ($parameters{"$PK_COLUMN_NAME"}) { printEntryForm();
  } else { printOptions(); }

  $sbeamsMOD->printPageFooter();


} # end main



###############################################################################
# preFormHook
#
# This is a hook to do some processing before all the lines of data entry
# form have been displayed based on the current table name.  This might be
# used to set some defaults or something.
###############################################################################
sub preFormHook {
  my %args = @_;

  my $query_parameters_ref = $args{'parameters_ref'};


  #### If table XXXX
  if ($TABLE_NAME eq "XXXX") {
    $query_parameters_ref->{YYYY} = 'XXXX'
      unless ($query_parameters_ref->{YYYY});
  }


  #### Otherwise, no special processing, so just return undef
  return;

} # end preFormHook



###############################################################################
# postFormHook
#
# This is a hook to do some processing after all the lines of data entry
# form have been displayed but before the table has been closed based on
# the current table name.
###############################################################################
sub postFormHook {
  my %args = @_;

  my $query_parameters_ref = $args{'parameters_ref'};
  my %parameters = %{$query_parameters_ref};


  #### If table XXXX
  if ($TABLE_NAME eq "XXXX") {
    return "An error of some sort $parameters{something} invalid";
  }


  if ($TABLE_NAME eq "labeling" && 
      $parameters{array_request_sample_id} gt "") {

    my $sql_query = qq~
       SELECT DISTINCT extinction_coeff_at_max,correction_260,
              Ebase,MWbase
         FROM $TB_DYE D
         LEFT JOIN $TB_LABELING_METHOD LM ON ( D.dye_id = LM.dye_id )
         LEFT JOIN $TB_ARRAY_REQUEST_SAMPLE ARS ON
              ( LM.labeling_method_id = ARS.labeling_method_id )
        WHERE array_request_sample_id IN ($parameters{array_request_sample_id})
    ~;

    my @rows = $sbeams->selectSeveralColumns($sql_query);
    my ($Edye,$CFdye,$Ebase,$MWbase) = 0;
    if (@rows) {
      ($Edye,$CFdye,$Ebase,$MWbase) = @{$rows[0]};
    }

    if (scalar @rows > 1) {
      print "<TR><TD><B><font color=red><BLINK>WARNING</BLINK>:</font>".
        "</B></TD>";
      print "    <TD><B><font color=red>SAMPLES USING MORE THAN ONE TYPE OF ".
        "DYE SELECTED????<BR>CALCULATION BELOW MAY BE WRONG!</font>".
        "</B></TD></TR>\n";
    }


    my $A260 = $parameters{absorbance_260}*$parameters{dilution_factor};
    my $Adye = $parameters{absorbance_lambda};
    my $volume = $parameters{volume};
    my $Abase = $A260 - ($Adye * $CFdye);

    print "<TR><TD><B><font color=green>Edye:</font></B></TD>";
    print "    <TD>$Edye</TD>\n";
    print "    <TD BGCOLOR=\"E0E0E0\">Extinction coefficient for dye</TD></TR>\n";

    print "<TR><TD><B><font color=green>CFdye:</font></B></TD>";
    print "    <TD>$CFdye</TD>\n";
    print "    <TD BGCOLOR=\"E0E0E0\">Absorbance at 260 nm correction factor for dye</TD></TR>\n";

    print "<TR><TD><B><font color=green>Ebase:</font></B></TD>";
    print "    <TD>$Ebase</TD>\n";
    print "    <TD BGCOLOR=\"E0E0E0\">Extinction coefficient for a base</TD></TR>\n";

    print "<TR><TD><B><font color=green>MWbase:</font></B></TD>";
    print "    <TD>$MWbase</TD>\n";
    print "    <TD BGCOLOR=\"E0E0E0\">Molecular weight for a base in g/mol</TD></TR>\n";

    if ($Adye==0 || $Ebase==0 || $Edye==0) {
      print qq~
        <TR><TD></TD><TD><font color=green><B>
        Insufficient data to calculate values.  Please enter measurements
        above and press
        <INPUT TYPE="submit" NAME="apply_action" VALUE="REFRESH"></font></TD></TR>\n
      ~;
      return;
    }

    my $NucAcid = ($Abase * $MWbase) / $Ebase;
    my $basedye = ($Abase * $Edye) / ($Adye * $Ebase);
    my $TotNucAcid = $NucAcid * $volume;
    my $pmoldyeul = $Adye/($Edye*1e-6);
    my $totpmoldye = $pmoldyeul * $volume;


    print "<TR><TD><B><font color=green>Abase:</font></B></TD>";
    print "    <TD>",sprintf("%10.4f",$Abase),"</TD>\n";
    print "    <TD BGCOLOR=\"E0E0E0\">Absorbance at 260 after using CFdye</TD></TR>\n";

    print "<TR><TD><B><font color=green>[nucleic acid](ug/ul):</font></B></TD>";
    print "    <TD>",sprintf("%10.6f",$NucAcid),"</TD></TR>\n";
    print "<TR><TD><B><font color=green>base:dye:</font></B></TD>";
    print "    <TD>",sprintf("%10.1f",$basedye),"</TD></TR>\n";
    print "<TR><TD><B><font color=green>total nucleic acid (ug):</font></B></TD>";
    print "    <TD>",sprintf("%10.2f",$TotNucAcid),"</TD>\n";
    print "    <TD BGCOLOR=\"E0E0E0\">in units of micrograms (ug)</TD></TR>\n";

    print "<TR><TD><B><font color=green>pmol dye/ul:</font></B></TD>";
    print "    <TD>",sprintf("%10.2f",$pmoldyeul),"</TD></TR>\n";
    print "<TR><TD><B><font color=green>total pmol dye:</font></B></TD>";
    print "    <TD>",sprintf("%10.1f",$totpmoldye),"</TD></TR>\n";

  }


  if ($TABLE_NAME eq "array_scan") {
  
    if ($parameters{stage_location} gt "") {
      if ( -d "$parameters{stage_location}/Images" ) {
        print "<TR><TD><B><font color=green>Status:</font></B></TD>";
        print "    <TD>Images/ subdirectory verified</TD></TR>\n";
      } else {
        print "<TR><TD><B><font color=red>WARNING:</font></B></TD>";
        print "    <TD><B><font color=red>Images/ subdirectory not ".
          "found</font></B></TD></TR>\n";
      }
    }
  }


  if ($TABLE_NAME eq "array_quantitation") {
  
    if ($parameters{stage_location} gt "") {
      if ( -e "$parameters{stage_location}" ) {
        print "<TR><TD><B><font color=green>Status:</font></B></TD>";
        print "    <TD>Existence of data file verified</TD></TR>\n";
      } else {
        print "<TR><TD><B><font color=red>WARNING:</font></B></TD>";
        print "    <TD><B><font color=red>Data file does not exist at ".
          "STAGE location</font></B></TD></TR>\n";
      }
    }
  }


  if ($TABLE_NAME eq "array_layout") {
  
    if ($parameters{source_filename} gt "") {
      if ( -e "$parameters{source_filename}" ) {
        print "<TR><TD><B><font color=green>Status:</font></B></TD>";
        print "    <TD>Existence of data file verified</TD></TR>\n";
      } else {
        print "<TR><TD><B><font color=red>WARNING:</font></B></TD>";
        print "    <TD><B><font color=red>Data file does not exist at ".
          "specified location</font></B></TD></TR>\n";
      }
    }
  }


  #### Otherwise, no special processing, so just return undef
  return;

} # end postFormHook



###############################################################################
# preUpdateDataCheck
#
# For certain tables, there are additional checks that should be made before
# an INSERT or UPDATE is performed.
###############################################################################
sub preUpdateDataCheck {
  my %args = @_;

  my $query_parameters_ref = $args{'parameters_ref'};
  my %parameters = %{$query_parameters_ref};


  #### If table XXXX
  if ($TABLE_NAME eq "XXXX") {
    return "An error of some sort $parameters{something} invalid";
  }


  if ($TABLE_NAME eq "array_scanDISABLED") {
      unless ( ($parameters{stage_location} gt "") &&
             ( -d "$parameters{stage_location}/Images" ) ) {
      return "The specified scanned data location does not exist (looking ".
        "for an 'Images/' subdirectory in '$parameters{stage_location}')";
    }
  }


  if ($TABLE_NAME eq "array_quantitation") {
      unless ( ($parameters{stage_location} gt "") &&
             ( -e "$parameters{stage_location}" ) ) {
      return "The specified quantitation data file does not exist (looking ".
        "for file '$parameters{stage_location}')";
    }
  }


  if ($TABLE_NAME eq "array_layout") {
      unless ( ($parameters{source_filename} gt "") &&
             ( -e "$parameters{source_filename}" ) ) {
      return "The specified layout key file does not exist (looking for ".
        "file '$parameters{source_filename}')";
    }
  }


  #### Otherwise, no special processing, so just return empty string
  return '';

} # end preUpdateDataCheck


