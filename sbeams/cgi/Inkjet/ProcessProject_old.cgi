#!/usr/local/bin/perl 

###############################################################################
# Program     : ProcessProject.cgi
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This CGI program that allows users to submit a processing
#		job to process a set of experiments in a project.
#
###############################################################################


###############################################################################
# Get the script set up with everything it will need
###############################################################################
use strict;
use lib qw (../../lib/perl);
use vars qw ($q $sbeams $sbeamsIJ $dbh $current_contact_id $current_username
             $current_work_group_id $current_work_group_name
             $current_project_id $current_project_name
             $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
             $PK_COLUMN_NAME @MENU_OPTIONS);
use DBI;
use CGI;
use CGI::Carp qw(fatalsToBrowser croak);
use POSIX;

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::Inkjet;
use SBEAMS::Inkjet::Settings;
use SBEAMS::Inkjet::Tables;

use lib "/net/arrays/Pipeline/tools/lib";
require "QuantitationFile.pl";

$q = new CGI;
$sbeams = new SBEAMS::Connection;
$sbeamsIJ = new SBEAMS::Inkjet;
$sbeamsIJ->setSBEAMS($sbeams);


###############################################################################
# Global Variables
###############################################################################
main();


###############################################################################
# Main Program:
#
# Call $sbeams->InterfaceEntry with pointer to the subroutine to execute if
# the authentication succeeds.
###############################################################################
sub main { 

    #### Do the SBEAMS authentication and exit if a username is not returned
    exit unless ($current_username = $sbeams->Authenticate());

    #### Print the header, do what the program does, and print footer
    $sbeamsIJ->printPageHeader();
    processRequests();
    $sbeamsIJ->printPageFooter();


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
    $current_work_group_id = $sbeams->getCurrent_work_group_id;
    $current_work_group_name = $sbeams->getCurrent_work_group_name;
    $current_project_id = $sbeams->getCurrent_project_id;
    $current_project_name = $sbeams->getCurrent_project_name;
    $dbh = $sbeams->getDBHandle();


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


    #### Decide where to go based on form values
    if ($q->param('PROCESS')) { submitJob();
    } else { printEntryForm();
    }


} # end processRequests



###############################################################################
# Print Entry Form
###############################################################################
sub printEntryForm {

    my %parameters;
    my $element;
    my $sql_query;
    my (%url_cols,%hidden_cols);

    my $CATEGORY="Process Experiments";


    my $apply_action  = $q->param('apply_action');
    $parameters{project_id} = $q->param('project_id');


    # If we're coming to this page for the first time, and there is a
    # default project set, then automatically select that one and GO!
    if ( ($parameters{project_id} eq "") && ($current_project_id > 0) ) {
      $parameters{project_id} = $current_project_id;
      $apply_action = "QUERY";
    }


    $sbeams->printUserContext();
    print qq!
        <H2>$CATEGORY</H2>
        $LINESEPARATOR
        <FORM METHOD="post">
        <TABLE>
    !;


    # ---------------------------
    # Query to obtain column information about the table being managed
    $sql_query = qq~
	SELECT project_id,username+' - '+name
	  FROM $TB_PROJECT P
	  LEFT JOIN $TB_USER_LOGIN UL ON ( P.PI_contact_id=UL.contact_id )
	  LEFT JOIN $TB_USER_WORK_GROUP UWG
	       ON ( P.PI_contact_id=UWG.contact_id )
	 WHERE P.record_status != 'D'
	   AND UWG.work_group_id = 13
	 ORDER BY username,name
    ~;
    my $optionlist = $sbeams->buildOptionList(
           $sql_query,$parameters{project_id});


    print qq!
          <TR><TD><B>Project:</B></TD>
          <TD><SELECT NAME="project_id">
          <OPTION VALUE=""></OPTION>
          $optionlist</SELECT></TD>
          <TD BGCOLOR="E0E0E0">Select the Project Name</TD>
          </TD></TR>
    !;


    # ---------------------------
    # Show the QUERY, REFRESH, and Reset buttons
    print qq!
	<TR><TD COLSPAN=2>
	&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
	<INPUT TYPE="submit" NAME="apply_action" VALUE="QUERY">
	&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
	<INPUT TYPE="submit" NAME="apply_action" VALUE="REFRESH">
	&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
	<INPUT TYPE="reset"  VALUE="Reset">
         </TR></TABLE>
         </FORM>
    !;


    $sbeams->printPageFooter("CloseTables");
    print "<BR><HR SIZE=5 NOSHADE><BR>\n";

    # --------------------------------------------------
    if ($parameters{project_id} > 0) {
      $sql_query = qq~
SELECT	A.array_id,A.array_name,
	ARSM1.name AS 'Sample1Name',D1.dye_name AS 'sample1_dye',
	ARSM2.name AS 'Sample2Name',D2.dye_name AS 'sample2_dye',
	AQ.array_quantitation_id,AQ.data_flag AS 'quan_flag',
	AQ.stage_location,AL.source_filename AS 'key_file'
  FROM $TBIJ_ARRAY_REQUEST AR
  LEFT JOIN $TBIJ_ARRAY_REQUEST_SLIDE ARSL ON ( AR.array_request_id = ARSL.array_request_id )
  LEFT JOIN $TBIJ_ARRAY_REQUEST_SAMPLE ARSM1 ON ( ARSL.array_request_slide_id = ARSM1.array_request_slide_id AND ARSM1.sample_index=0)
  LEFT JOIN $TBIJ_LABELING_METHOD LM1 ON ( ARSM1.labeling_method_id = LM1.labeling_method_id )
  LEFT JOIN $TBIJ_DYE D1 ON ( LM1.dye_id = D1.dye_id )
  LEFT JOIN $TBIJ_ARRAY_REQUEST_SAMPLE ARSM2 ON ( ARSL.array_request_slide_id = ARSM2.array_request_slide_id AND ARSM2.sample_index=1)
  LEFT JOIN $TBIJ_LABELING_METHOD LM2 ON ( ARSM2.labeling_method_id = LM2.labeling_method_id )
  LEFT JOIN $TBIJ_DYE D2 ON ( LM2.dye_id = D2.dye_id )
  LEFT JOIN $TBIJ_ARRAY A ON ( A.array_request_slide_id = ARSL.array_request_slide_id )
  LEFT JOIN $TBIJ_ARRAY_LAYOUT AL ON ( A.layout_id = AL.layout_id )
  LEFT JOIN $TBIJ_ARRAY_SCAN ASCAN ON ( A.array_id = ASCAN.array_id )
  LEFT JOIN $TBIJ_ARRAY_QUANTITATION AQ ON ( ASCAN.array_scan_id = AQ.array_scan_id )
 WHERE AR.project_id=$parameters{project_id}
   AND AQ.array_quantitation_id IS NOT NULL
   AND AR.record_status != 'D'
   AND A.record_status != 'D'
   AND ASCAN.record_status != 'D'
   AND AQ.record_status != 'D'
 ORDER BY A.array_name
     ~;

      my $base_url = "$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=";
      %url_cols = ('array_name' => "${base_url}array&array_id=%0V",
                   'quan_flag' => "${base_url}array_quantitation&array_quantitation_id=%6V", 
      );

      %hidden_cols = ('array_id' => 1,
                      'array_quantitation_id' => 1,
      );


    } else {
      $apply_action="BAD SELECTION";
    }


    if ($apply_action eq "QUERY") {
      $sbeams->displayQueryResult(sql_query=>$sql_query,
          url_cols_ref=>\%url_cols,hidden_cols_ref=>\%hidden_cols);


      print qq~
	<BR><HR SIZE=5 NOSHADE><BR>
	<FORM METHOD="post">
      ~;


      my $sth = $dbh->prepare("$sql_query") or croak $dbh->errstr;
      my $rv  = $sth->execute or croak $dbh->errstr;

      my @rows;
      my @row;
      while (@row = $sth->fetchrow_array) {
        my @temprow = @row;
        push(@rows,\@temprow);
      }

      $sth->finish;


      my @group_names;
      my %group_names_hash;
      my @slide_group_names;
      my @slide_rowrefs;
      my @slide_directions;


      foreach $element (@rows) {
        my $sample1name = $$element[2];
	$sample1name =~ s/ /_/g;
        my $sample2name = $$element[4];
	$sample2name =~ s/ /_/g;
        my $forcondition = "${sample1name}_vs_${sample2name}";
        my $revcondition = "${sample2name}_vs_${sample1name}";
        my $thiscondition;
        my $direction = "";

        if (defined($group_names_hash{$forcondition})) {
          $direction = "f";
          $thiscondition = $forcondition;
        }

        if (defined($group_names_hash{$revcondition})) {
          $direction = "r";
          $thiscondition = $revcondition;
        }

        unless ($direction) {
          $direction = "f";
          $thiscondition = $forcondition;
          push(@group_names,$thiscondition);
          $group_names_hash{$thiscondition}=$thiscondition;
        }

        push(@slide_group_names,$thiscondition);
        push(@slide_rowrefs,$element);
        push(@slide_directions,$direction);

      }


      my $group;
      my $error_flag = 0;
      my ($quantitation_file,$qf_status);
      my (@ERRORS,@command_file);
      my (@results,@parts);

      foreach $group (@group_names) {
        my $row_counter=0;
        my $first_flag=1;
        my $channel_direction = "";
        foreach $element (@slide_group_names) {

          if ($element eq $group) {

            if ($first_flag) {
              my $cmd_line = "$group ${$slide_rowrefs[$row_counter]}[9] EXP";
              push (@command_file,$cmd_line);
              print qq~
		<B><FONT COLOR="#A050A0">$group</FONT> <FONT COLOR="#0000A0">${$slide_rowrefs[$row_counter]}[9]</FONT> EXP</B><BR>\n
              ~;
              $first_flag=0;
            }

            #### Verify that the data file is okay
            $quantitation_file = ${slide_rowrefs[$row_counter]}[8];
            my $sample1_dye = ${slide_rowrefs[$row_counter]}[3];
            my $sample2_dye = ${slide_rowrefs[$row_counter]}[5];
            $qf_status = "";

            #### If the data file is okay
            if ( -e $quantitation_file ) {
              $qf_status = "&nbsp;&nbsp;&nbsp;&nbsp;--- ".
                           "<FONT COLOR=green>File exists</FONT>";
              #### Run a parse program on it to see which channel is which dye
              #@results = `../lib/perl/SBEAMS/scripts/parseQAheader.pl --verify "$quantitation_file"`;
              my %quantitation_data = readQuantitationFile(inputfilename=>"$quantitation_file",
                headeronly=>1);

              unless ($quantitation_data{success}) {
                $qf_status = "&nbsp;&nbsp;&nbsp;&nbsp;--- ".
                             "<FONT COLOR=red>$quantitation_data{error_msg}</FONT>";
              } else {
                print "According to sample names, direction should ".
                      "be $slide_directions[$row_counter]<BR>\n";

                #### Pull out the channel information
                my @channels = @{$quantitation_data{channels}};
                my $channel;

		#### If we have no channel information, brazenly assume that
		#### channel 1 contains the shorter number_part dye
		#print "channels = ",join(",",@channels),"<BR>\n";
		unless (@channels) {
		  print "WARNING: Quantitation file has no channel information! (typical of Dapple) ".
		    "Guessing that channel 0 is the lower numbered bye!<BR>";
		  if ($sample1_dye lt $sample2_dye) {
                    $channel_direction = "f";
		    print "<font color=red>WARNING: Guessing channel direction should be forward.  Verify!!</font><BR>\n";
		  } else {
                    $channel_direction = "r";
		    print "<font color=red>WARNING: Guessing channel direction should be reverse.  Verify!!</font><BR>\n";
		  }
		}

                #### Loop over each channel
                foreach $channel (@channels) {
                  @parts = ($channel->{channel_label},$channel->{fluorophor});
                  #print "$parts[0] = $parts[1]<BR>\n";
                  $parts[1] =~ /(\d+)/;
                  my $number_part = $1;
                  my $match_flag = 0;


                  if ($sample1_dye =~ /$number_part/) {
                    $match_flag = 1;
                    if ($parts[0] eq "ch1") {
                      $channel_direction = "f";
                    }
                    if ($parts[0] eq "ch2") {
                      $channel_direction = "r";
                    }
                    print "channel $parts[0] in quant file matches sample 1 dye, ".
                          "implying direction $channel_direction<BR>\n";
                  }

                  if ($sample2_dye =~ /$number_part/) {
                    if ($match_flag) { print "Whoah!  Double match!<BR>\n"; }
                    $match_flag = 2;
                    if ($parts[0] eq "ch1") {
                      $channel_direction = "r";
                    }
                    if ($parts[0] eq "ch2") {
                      $channel_direction = "f";
                    }
                    print "channel $parts[0] in quant file matches sample 2 dye, ".
                          "implying direction $channel_direction<BR>\n";
                  }

                  #print "deciding on direction $slide_directions[$row_counter]<BR>\n";

                  unless ($match_flag) {
                    print "Unable to match file name '$parts[1]' with ".
                        "either dye.<BR>\n";
                  }

                } # endforeach


                if ($channel_direction eq "r") {
                  print "So, flip the initially thought direction.<BR>\n";
                  $slide_directions[$row_counter] =~ tr/fr/rf/;
                } else {
                  #keep direction the same
                }


                $qf_status = "&nbsp;&nbsp;&nbsp;&nbsp;--- ".
                             "<FONT COLOR=green>File verified</FONT>";

              } # endelse


            #### If the data file is not found
            } else {
              $error_flag++;
              $qf_status = "&nbsp;&nbsp;&nbsp;&nbsp;--- ".
                           "<FONT COLOR=red>FILE MISSING</FONT>";
              push(@ERRORS,"Unable to find file $quantitation_file");
            }

            #### Print out the quantitation file row
            my $cmd_line = "$quantitation_file ".
                  $slide_directions[$row_counter];
            push (@command_file,$cmd_line);
            print "$quantitation_file ".
                  "<FONT COLOR=red>$slide_directions[$row_counter]</FONT> ".
                  "$qf_status<BR>\n";

          }

          $row_counter++;

        }

      }

      print qq~
	<BR><BR>
	Okay, here is the command file that has been generated based on the
	available information.  Each section begins with a 3 column row
	containing the derived label (output filename for the .sig file),
	the key file to be used, and the word EXP.  Within each section are
	two column rows which indicate the quantitation file and a f or r
	flag indicating "forward" or "reverse" (i.e. should channel 1 be
	the numerator [f] or should channel 2 be the numerator [r]).<BR><BR>


	<TEXTAREA NAME="command_file" ROWS=15 COLS=80>~;
      print join("\n",@command_file);
      print qq~
</TEXTAREA><BR>
	<INPUT TYPE="hidden" NAME="project_id" VALUE="$parameters{project_id}">
	<INPUT TYPE="submit" NAME="PROCESS" VALUE="PROCESS">
	</FORM><BR><BR>
      ~;


    } else {
      print "<H4>Select parameters above and press QUERY\n";
    }


} # end printEntryForm


###############################################################################
# submit Job
###############################################################################
sub submitJob {

    my $command_file_content = $q->param('command_file');
    my $project_id = $q->param('project_id');

    my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time);
    my $timestr = strftime("%Y%m%d.%H%M%S",$sec,$min,$hour,$mday,$mon,$year);

    my $plan_filename = "job$timestr.plan";
    my $control_filename = "job$timestr.control";
    my $log_filename = "job$timestr.log";

    my $queue_dir = "/net/arrays/Pipeline/queue";


    #### Verify that the plan file does not already exist
    if ( -e $plan_filename ) {
      print qq~
	Wow, the job filename '$plan_filename' already exists!<BR>
	Please go back and click PROCESS again.  If this happens twice
	in a row, something is very wrong.  Contact edeutsch.<BR>\n
      ~;
      return;
    }


    #### Write the plan file
    print "Writing processing plan file '$plan_filename'<BR>\n";
    open(PLANFILE,">$queue_dir/$plan_filename") ||
      croak("Unable to write to file '$queue_dir/$plan_filename'");
    print PLANFILE $command_file_content;
    close(PLANFILE);


    #### Write the control file
    print "Writing job control file '$control_filename'<BR>\n";
    open(CONTROLFILE,">$queue_dir/$control_filename") ||
      croak("Unable to write to file '$queue_dir/$control_filename'");
    print CONTROLFILE "submitted_by=$current_username\n";
    print CONTROLFILE "project_id=$project_id\n";
    print CONTROLFILE "status=SUBMITTED\n";
    close(CONTROLFILE);


    print "Done!<BR><BR>\n";

    print qq~
	The plan and job control files have been successfully written to the
	queue.  Your job will be processed in the order received.  You can
	see the log file of your job by clicking on the link below:<BR><BR>

        Well, there's no link yet, but paste this into a unix window:<BR><BR>

	cd /net/arrays/Pipeline/output/project_id/$project_id<BR>
	if ( -e $log_filename ) tail -f $log_filename<BR>

	<BR><BR><BR>
    ~;


}













