#!/usr/local/bin/perl -w

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# Program     : CreateBiosapRun.cgi
# Author      : Michael Johnson <mjohnson@systemsbiology.org>
# $Id$
#
# Description : This CGI program allows users to generate biosap
#               parameter files in unique directories (under a 
#               directory), based on input they provide through
#               a web interface.
#
# SBEAMS is Copyright (C) 2000-2003 by Eric Deutsch
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
#-----------------------------------------------------------------------

###############################################################################
# Set up all needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;

use POSIX qw(strftime);
use POSIX qw(:sys_wait_h);

use lib qw (../../lib/perl);
use vars qw ($q $tm $tm_rng $o_conc $s_conc $blast_lib $same_as_lib
	     $mn_len $mx_len $mx_selfcomp $init_offset $step $dist 
	     $ftrs $featurama_lib $dirstr $pol_at $pol_gc $win_sz 
	     $win_at $win_gc $action $comments $PROG_NAME $dbh 
	     $sbeams $sbeamsMOD $current_username $USAGE %OPTIONS $VERBOSE
	     $QUIET $DEBUG);
use DBI;
use CGI;
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::Biosap;
use SBEAMS::Biosap::Settings;
use SBEAMS::Biosap::Tables;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::Biosap;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);

$q = new CGI;

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
$QUIET   = $OPTIONS{"quiet"} || 0;
$DEBUG   = $OPTIONS{"debug"} || 0;
if ($DEBUG) {
  print "Options settings:\n";
  print "  VERBOSE = $VERBOSE\n";
  print "  QUIET = $QUIET\n";
  print "  DEBUG = $DEBUG\n";
}


###############################################################################
# Set Global Variables and execute main()
###############################################################################
main();
$CGI::POST_MAX = 1024 * 10000; #Max file upload size is 10MB
exit(0);

###############################################################################
# Main Program:
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


  #### Decide what action to take based on information so far
  $sbeamsMOD->printPageHeader();

  if ($parameters{action} eq "Submit to BioSap") {
    process_request(ref_parameters=>\%parameters,
										testonly=>0);
  }elsif ($parameters{action} eq "Test Run Featurama") {
    process_request(ref_parameters=>\%parameters,
										testonly=>1);
  }else {
    print_javascript();
    create_request_form(ref_parameters=>\%parameters);
  }

  $sbeamsMOD->printPageFooter();

} # end main

###############################################################################
# print_javascript 
##############################################################################
sub print_javascript {

print qq~
<SCRIPT LANGUAGE="Javascript">
<!--

//-->
</SCRIPT>
~;
return 1;
}

###############################################################################
# Process Request
###############################################################################
sub process_request {
  my %args = @_;
  my $SUB_NAME = "process_request";

  #### Process the arguments list
  my $ref_parameters = $args{'ref_parameters'}
    || die "ERROR[$SUB_NAME]: ref_parameters not passed";
  my $testonly = $args{'testonly'};

  #### If the parameters are okay, then create the necessary files
  my ($ok, $ref_parameters) = verify_parameters(ref_parameters=>$ref_parameters);

  if ($ok == 1) {
    my $output_dir = make_output_dir (testonly=>$testonly);
    write_parameters_files(ref_parameters=>$ref_parameters,
			   output_dir=>$output_dir);

    if ($testonly==1){run_featurama(output_dir=>$output_dir);}
		else {				
    print qq~
	You have successfully subbmitted a job to BIOSAP<BR>
  Your job will be processed in the order received.  You can
	see the log file of your job by clicking on the link below:<BR><BR>

	Well, theres no link yet, but paste this into a unix window:<BR><BR>

	cd $output_dir<BR>
	if ( -e $output_dir ) tail -f blast.out<BR>

	<BR><BR><BR>
    ~;
    }
  }

  create_request_form(ref_parameters=>$ref_parameters);

  return;

} # end process_request


###############################################################################
# run_featurama
###############################################################################
sub run_featurama {
  my %args = @_;
  my $SUB_NAME = "run_featurama";

  #### Process the argument list
  my $output_dir = $args{'output_dir'}
  || die "ERROR[$SUB_NAME]: output_dir not passed!\n";

  #### Define standard variables
  my $featurama_location = "/net/db/projects/BioSap/src/biosap/featurama/src";
  my $featurama_params = "$output_dir/featurama.params";
  my ($start_hour,$start_min,$start_sec) = ((localtime)[2],(localtime)[1],(localtime)[0]);

  $| = 1;
  print "<PRE>\n";
  system "$featurama_location/featurama $featurama_params 2>&1" 
      || croak "Couldn't run featurama : $!";
  print "<PRE>\n";
  system "/bin/rm -fr $output_dir"
      || croak "Couldn't formatdb: $!";

  my ($finish_hour,$finish_min,$finish_sec) = ((localtime)[2],(localtime)[1],(localtime)[0]);

  print qq ~
    <TABLE WIDTH="750" BORDER="0" BORDERCOLOR="#FFFFFF" CELLPADDING="7" CELLSPACING="0" BGCOLOR="#FFCCCC">
    <TR>
      <TD>
      <FONT FACE="Helvetica" SIZE="3" COLOR="#000000">
      <U>Featurama Test Run is Done !</U><BR>
      Started at $start_hour:$start_min:$start_sec<BR>
      Completed at $finish_hour:$finish_min:$finish_sec<BR>
      </FONT>
      </TD>
    </TR>
    </TABLE>
    ~;
}
###############################################################################
# write_parameters_files
###############################################################################
sub write_parameters_files {
  my %args = @_;
  my $SUB_NAME = "write_parameters_files";

  #### Process the arguments list
  my $ref_parameters = $args{'ref_parameters'}
  || die "ref_parameters not passed\n";
  my %parameters = %{$ref_parameters};
  my $output_dir = $args{'output_dir'}
  || die "output_dir not passed\n";
  my ($sql,@rows);

  #### write Comments file
  open (COMMENTS, ">$output_dir/comments")
      || croak "ERROR[$SUB_NAME]: could not create comments file\n";
  if ($parameters{'comments'}) {
    print (COMMENTS $parameters{'comments'});
  }else {
    print (COMMENTS "No comments were submitted\n");
  }
  close (COMMENTS);
  

  #### write Featurama parameters file
  open (FEATURAMA, ">$output_dir/featurama.params")
	|| croak "ERROR[$SUB_NAME]: could not create featurama parameters file\n";
	my $user = $sbeams->getCurrent_username();
  my $featurama_params =  "user_name=$user\n";

  my $bs_id = $parameters{'featuramalib'};
  $sql = qq~
      SELECT set_path
        FROM $TBBS_BIOSEQUENCE_SET
       WHERE biosequence_set_id = '$bs_id'
         AND record_status != 'D'
	 ~;
  @rows = $sbeams->selectOneColumn($sql);
  my $biosequence_set = $rows[0];

  $featurama_params .=  qq~gene_library=$biosequence_set
output_directory=$output_dir
melting_temp=$parameters{'meltTemp'}
melting_temp_range=$parameters{'meltTempRange'}
minimum_length=$parameters{'minLen'}
maximum_length=$parameters{'maxLen'}
maximum_selfcomp=$parameters{'maxSelfComp'}
step_size=$parameters{'stepSize'}
maximum_3prime_distance=$parameters{'max3PrimeDist'}
initial_3prime_offset=$parameters{'initOffset'}
maximum_features=$parameters{'maxReporters'}
maximum_polyAT_length=$parameters{'maxPolyAT'}
maximum_polyGC_length=$parameters{'maxPolyGC'}
content_window_size=$parameters{'windowSize'}
maximum_windowAT_content=$parameters{'maxATinWindow'}
maximum_windowGC_content=$parameters{'maxGCinWindow'}
oligo_concentration_mMol=$parameters{'oligoConc'}
salt_concentration_mMol=$parameters{'saltConc'}~;
#	print "<pre>$featurama_params</pre>";
  print FEATURAMA $featurama_params;
  close(FEATURAMA) || print "<FONT COLOR=\"red\">WARNING[$SUB_NAME]: featurama params file did not close nicely!</FONT><BR>";
  print "File ".$output_dir."/featurama.params created.<BR>";
  
  #### write BLAST parameters file
  open (BLAST, ">$output_dir/blast.params")
      || croak "ERROR[$SUB_NAME]: could not create BLAST parameters file\n";
  my $blast_lib = $parameters{'blastlib'};
  $sql = qq~
      SELECT set_path
        FROM $TBBS_BIOSEQUENCE_SET
       WHERE biosequence_set_id = '$blast_lib'
         AND record_status != 'D'
	 ~;
  my @blast_lib_id = $sbeams->selectOneColumn($sql);

  print BLAST qq~blast_library=$blast_lib_id[0]
expect_value=1
~;
  close (BLAST) || print "<FONT COLOR=\"red\">WARNING[$SUB_NAME]: blast params file did not close nicely!</FONT><BR>";
  print "File ".$output_dir."/blast.params created.<BR>";
  
  return;

} # end write_parameters_files

###############################################################################
# make_output_dir
###############################################################################
sub make_output_dir {
  my %args = @_;
  my $SUB_NAME = "make_output_dir";

  #### Process the arguments list
  my $testonly = $args{'testonly'};
  my $unique_dir = 0;
#	my $output_dir = "/net/techdev/biosap_ext"; # for MySQL site
  my $output_dir = "/net/techdev/biosap/"; # for ISB-internal site
  ($testonly == 1) ? ($output_dir .= "tmp/") : ($output_dir .= "data/");

  #### Create an output directory.  Make sure it's unique
  for (my $i=0; $i<10 && $unique_dir==0; $i++) {
    my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time);
    $output_dir .= strftime("%Y%m%d.%H%M%S",$sec,$min,$hour,$mday,$mon,$year);
    if (-e $output_dir) {
      print "WARNING[$SUB_NAME]: ".$output_dir." is not unique. This is attempt ".
	  ($i+1)." of 10<BR>\n";
      sleep 5;
    }else {
      $unique_dir = 1;
      mkdir ($output_dir) || croak "ERROR[$SUB_NAME]: directory ".
	  $output_dir."could not be created.\n".$!;
      chmod (0777, $output_dir) || croak "ERROR[$SUB_NAME]: could not change".
	  "permissions for directory ".$output_dir."\n";
      print "Directory ".$output_dir." created successfully<BR>";
    }
  }
  return $output_dir;

} # end process_request

###############################################################################
# Create Request Form
###############################################################################
sub create_request_form {
  my %args = @_;
  my $SUB_NAME = "create_request_form";

  #### Process the arguments list
  my $ref_parameters = $args{'ref_parameters'}
    || die "ref_parameters not passed";
  my %parameters = %{$ref_parameters};
  my ($sql, @rows);
  my $html;
  my $o_conc=0.00025; #hard-coded default Oligo concentration
  my $s_conc=50; #hard-coded default salt concentration

  #--------------- print_form_head ---------------#
  $html = qq~
<CENTER>
<FORM NAME="biosapForm" METHOD="POST">
<TABLE WIDTH="750" BORDER="0" CELLPADDING="7" CELLSPACING="0" BGCOLOR="#D0DDDA">
<TR>
  <TD>
  <FONT FACE="HELVETICA" SIZE="3" COLOR="#000000">
  ~;
  print $html;

  #------------ print_search_bs_sets -------------#
  $html = qq~
  <H3> BioSequence Files:</H3>
  <TABLE CELLPADDING="5">
  <TR>
    <TD>
    <B>Featurama Library:</B>&nbsp (used in Featurama search)
    </TD>
    <TD>
    <SELECT NAME="featuramalib" size=1>
    ~;

  $sql = qq~
      SELECT biosequence_set_id,set_name
        FROM $TBBS_BIOSEQUENCE_SET
       WHERE record_status != 'D'
	 ~;
  @rows = $sbeams->selectSeveralColumns($sql);

  foreach my $row_ref (@rows) {
    my ($featurama_bs_id, $featurama_set_name) = @{$row_ref};
    if ($featurama_bs_id eq $parameters{'featuramalib'}) {
      $html .= qq~
      <OPTION SELECTED VALUE="$featurama_bs_id">$featurama_set_name
      ~;
    }else {
      $html .= qq~
      <OPTION VALUE="$featurama_bs_id">$featurama_set_name
      ~;
    }
  }

  $html .= qq~
    </SELECT>
    </TD>
  </TR>
    <TD>
    <B>BLAST Library:</B>&nbsp (used in BLAST search)
    </TD>
    <TD>
    <SELECT NAME="blastlib" SIZE="1">
    ~;

  foreach my $row_ref (@rows) {
		my ($blast_bs_id, $blast_set_name) = @{$row_ref};
    if ($blast_bs_id eq $parameters{'blastlib'}) {
      $html .= qq~
      <OPTION SELECTED VALUE="$blast_bs_id">$blast_set_name
      ~;
    }else {
      $html .= qq~
      <OPTION VALUE="$blast_bs_id">$blast_set_name
      ~;
    }
  }

  $html .= qq~
    </SELECT>
    </TD>
  </TR>
  <TR>
   <TD COLSPAN="2">
   <BR>
   <B>Sanity Check:</B>
   <BR>
   Are the sequences for which you want features the same as the BLAST Library you\'ve select?&nbsp;
    <SELECT NAME="same_as_lib" SIZE=1>
				~;
	if ($parameters{'featuramalib'} == $parameters{'blastlib'}) {
		$html .= qq~
      <OPTION VALUE="Yes" SELECTED>Yes
      <OPTION VALUE="No">No
			~;
	}else {
		$html .= qq~
      <OPTION VALUE="Yes">Yes
      <OPTION VALUE="No" SELECTED>No
			~;					
  }
	$html .= qq~
    </SELECT>
    </TD>
  </TR>
  </TABLE>
  ~;
  
  print $html;

  #----------- print_search_parameters -----------#

  $html = qq~
  <BR><HR>
  <H3>Search Parameters:</H3>
  <TABLE BORDER="0" CELLPADDING="5">
  <TR>
    <TD>
    <B>Oligo Concentration</B> (mMol):
    </TD>
    <TD ALIGN="right">
    <INPUT TYPE="text" SIZE="9" NAME="oligoConc" VALUE="$o_conc">
    </TD>
    <TD ALIGN="right">
    <B> Salt Conc.</B> (mMol):
    </TD>
    <TD>
    <INPUT TYPE="text"SIZE="5" NAME="saltConc" VALUE="$s_conc">
    </TD>
  </TR>
  <TR>
    <TD>
    <B>Tm</B> (0-100):<INPUT TYPE="text" SIZE="5" NAME="meltTemp" VALUE="$parameters{'meltTemp'}">
    </TD>
    <TD>
    <B>+/-</B> (0-50):<INPUT TYPE="text" SIZE="5" NAME="meltTempRange" VALUE="$parameters{'meltTempRange'}">
    </TD>
    <TD ALIGN="right">
    <B> Step Size</B> (0-100,000):
    </TD>
    <TD>
    <INPUT TYPE="text" SIZE="5" NAME="stepSize" VALUE="$parameters{'stepSize'}">
    </TD>
  </TR>
  <TR>
    <TD>
    <B>Min. Reporter Length</B> (2-100):
    </TD>
    <TD>
    <INPUT TYPE="text" SIZE="5" NAME="minLen" VALUE="$parameters{'minLen'}">
    </TD>
    <TD ALIGN="right">
    <B> Max. Reporter Length</B> (Min. Length-100):
    </TD>
    <TD>
    <INPUT TYPE="text" SIZE="5" NAME="maxLen" VALUE="$parameters{'maxLen'}">
    </TD>
  </TR>
  <TR>
    <TD>
    <B>Max. 3\' Distance</B> (2-100,000):
    </TD>
    <TD>
    <INPUT TYPE="text" SIZE="5" NAME="max3PrimeDist" VALUE="$parameters{'max3PrimeDist'}">
    </TD>
    <TD ALIGN="right">
    <B> Max. Reporters per Gene</B> (1-1000):
    </TD>
    <TD> <INPUT TYPE="text" SIZE="5" NAME="maxReporters" VALUE="$parameters{'maxReporters'}"
    </TD>
  </TR>
  <TR>
    <TD>
    <B>Initial 3\' Offset</B> (0-100,000):
    </TD>
    <TD>
    <INPUT TYPE="text" SIZE="5" NAME="initOffset" VALUE="$parameters{'initOffset'}">
    </TD>
    <TD>
    <B>Max. Self-Comp Score</B> (0-Min. Length):
    </TD>
    <TD>
    <INPUT TYPE="text" SIZE="5" NAME="maxSelfComp" VALUE="$parameters{'maxSelfComp'}">
    </TD>
  </TR>
  </TABLE>
      ~;
  print $html;

  #----------- print_searh_heuristics -----------#
  $html = qq~
  <BR>
  <HR>
  <H3>Content Heuristics:</H3>
  <TABLE CELLPADDING="5">
  <TR>
    <TD>
    <B>Max. Poly A/T Length</B> (2-Max. Length):
    </TD>
    <TD>
    <INPUT TYPE="text" SIZE="5" NAME="maxPolyAT" VALUE="$parameters{'maxPolyAT'}">
    </TD>
    <TD ALIGN="right">
    <B>Max. Poly G/C Length</B> (2-Max. Length):
    </TD>
    <TD>
    <INPUT TYPE="text" SIZE="5" NAME="maxPolyGC" VALUE="$parameters{'maxPolyGC'}">
    </TD>
  </TR>
  <TR>
    <TD>
    <B>Heuristic Window Size</B> (2-Min. Length):
    </TD>
    <TD COLSPAN="2">
    <INPUT TYPE="text" SIZE="5" NAME="windowSize" VALUE="$parameters{'windowSize'}">
    </TD>
  </TR>
  <TR>
    <TD>
    <B>Max. A/T in Window</B> (1-WindowSize):
    </TD>
    <TD>
    <INPUT TYPE="text" SIZE="5" NAME="maxATinWindow" VALUE="$parameters{'maxATinWindow'}">
    </TD>
    <TD ALIGN="right">
    <B>Max. G/C in Window</B> (1-WindowSize):
    </TD>
    <TD>
    <INPUT TYPE="text" SIZE="5" NAME="maxGCinWindow" VALUE="$parameters{'maxGCinWindow'}">
    </TD>
  </TR>
  </TABLE>
  ~;
  print $html;

  #------------ print_search_comments -----------#
  $html = qq~
  <BR>
  <HR>
  <H3>Comments:</H3>
  <TEXTAREA NAME="comments" COLS="80" ROWS="5">$parameters{'comments'}</TEXTAREA>
  <BR>
  <BR>
  <HR>
  ~;
  print $html;

  #-------------- print_form_foot ---------------#
  $html = qq~
  <INPUT TYPE="submit" NAME="action" VALUE=\"Submit to BioSap\">
  <INPUT TYPE="submit" NAME="action" VALUE=\"Test Run Featurama\">
  <INPUT TYPE="button" NAME="resetForm" VALUE="Reset Form" onClick="javascript:document.biosapForm.reset()">
  </TD>
</TR>
</TABLE>
</FORM>
  ~;

  print $html;
  return;

} # end create_request_form



###############################################################################
# verify_parameters
###############################################################################
sub verify_parameters {
  my %args = @_;
  my $SUB_NAME = "verify_parameters";

  #### Process teh arguments list
  my $ref_parameters = $args{'ref_parameters'}
  || die "ERROR[$SUB_NAME]:ref_parameters not passed!\n";
  my %parameters = %{$ref_parameters};
  my $ok = 1;
  my $same_as_lib = $parameters{'same_as_lib'};
  
  # Featurama Lib and BLAST Lib are the same AND not suppose to be
  if (($parameters{'featuramalib'} eq $parameters{'blastlib'}) &&
      ($parameters{'same_as_lib'} eq "No")){
    print "<FONT COLOR=\"red\">ERROR: Library files are the same.</FONT><BR>\n";
    $ok=0;
  }

  # Featurama Lib and BLAST Lib are not the same and supposed to be
  if (($parameters{'featuramalib'} ne $parameters{'blastlib'}) &&
      ($parameters{'same_as_lib'} eq "Yes")) {
    print "<FONT COLOR=\"red\">ERROR: Library files are not the same.</FONT><BR>\n";
    $ok=0;
  }

  # Tm
  my $tm = $parameters{'meltTemp'};
  if ($tm > 100 || $tm < 0 || 
      (length($tm)==0 && !($tm=~/^[+-]?0*[.?0|0.?]0*[[eE]+[+-]?\d*[.?\d|\d.?]\d*]*/))) {
    print "<FONT COLOR=\"red\">ERROR: Tm is not valid</FONT><BR>\n";
    $parameters{'meltTemp'} = "";
    $ok=0;
  }

  # Tm range
  my $tm_range = $parameters{'meltTempRange'};
  if ($tm_range > 50 || $tm_range < 0 ||
      ($tm_range==0 && !($tm =~/^[+-]?0*[.?0|0.?]0*[[eE]+[+-]?\d*[.?\d|\d.?]\d*]*/))) {
    print "<FONT COLOR=\"red\">ERROR: Tm range is not valid</FONT><BR>\n";
    $parameters{'meltTempRange'} = "";
    $ok=0;
  }

  # Oligo Concentration
  if ($parameters{'oligoConc'} <= 0) {
    print "<FONT COLOR=\"red\">ERROR: Oligo. Conc. is not valid</FONT><BR>\n";
    $parameters{'oligoConc'} = "";
    $ok=0;
  }

  # Salt Concentration
  if ($parameters{'saltConc'} <= 0) {
    print "<FONT COLOR=\"red\">ERROR: Salt Conc. is not valid</FONT><BR>\n";
    $parameters{'saltConc'} = "";
    $ok=0;
  }

  # Minimum Length
  my $min_len = $parameters{'minLen'};
  if ($min_len > 100 || $min_len < 1 || !($min_len =~ /^[+-]?\d+$/)) {
    print "<FONT COLOR=\"red\">ERROR: Min Length is not valid</FONT><BR>\n";
    $parameters{'minLen'} = "";
    $ok=0;
  }

  # Maximum Length
  my $max_len = $parameters{'maxLen'};
  if ($max_len > 100 || $max_len < $min_len || 
      $max_len == 0 || !($max_len =~ /^[+-]?\d+$/)) {
    print "<FONT COLOR=\"red\">ERROR: Max Length is not valid</FONT><BR>";
    $parameters{'maxLen'} = "";
    $ok=0;
  }

  # Self Complementarity
  my $self_comp = $parameters{'maxSelfComp'};
  if ($self_comp>$min_len || $self_comp < 0 || !($max_len =~ /^[+-]?\d+$/)) {
    print "<FONT COLOR=\"red\">ERROR: Max Self-Comp is not valid</FONT><BR>\n";
    $parameters{'maxSelfComp'}="";
    $ok=0;
  }

  # Step Size
  my $step = $parameters{'stepSize'};
  if ($step > 100000 || $step < 0 || !($step =~ /^[+-]?\d+$/)) {
    print "<FONT COLOR=\"red\">ERROR: Step size is not valid</FONT><BR>\n";
    $parameters{'stepSize'}="";
    $ok=0;
  }

  # Max 3' Distance
  my $dist = $parameters{'max3PrimeDist'};
  if ($dist > 100000 || $dist < 2 || !($dist =~ /^[+-]?\d+$/)) {
    print "<FONT COLOR=\"red\">ERROR: Max 3' distance is not valid</FONT><BR>\n";
    $parameters{'max3PrimeDist'} = "";
    $ok=0;
  }

  # Initial 3' Offest
  my $offset = $parameters{'initOffset'};
  if ($offset > 100000 || $offset < 0 || !($offset =~ /^[+-]?\d+$/)) {
    print "<FONT COLOR=\"red\">ERROR: Initial 3' offest is not valid</FONT><BR>\n";
    $parameters{'initOffest'} = "";
    $ok=0;
  }
  
  # Maximum Features
  my $features = $parameters{'maxReporters'};
  if ($features > 1000 || $features < 1 || !($features =~ /^[+-]?\d+$/)) {
    print "<FONT COLOR=\"red\">ERROR: Maximum features is not valid</FONT><BR>\n";
    $parameters{'maxReporters'} = "";
    $ok=0;
  }

  # Maximum Poly AT
  my $p_AT = $parameters{'maxPolyAT'};
  if ($p_AT > $max_len || $p_AT < 2 || !($p_AT =~ /^[+-]?\d+$/)) {
    print "<FONT COLOR=\"red\">ERROR:Maximum Poly-AT is not valid</FONT><BR>\n";
    $parameters{'maxPolyAt'} = "";
    $ok=0;
  }

  # Maximum Poly GC
  my $p_GC = $parameters{'maxPolyGC'};
  if ($p_GC > $max_len || $p_GC < 2 || !($p_GC =~ /^[+-]?\d+$/)) {
    print "<FONT COLOR=\"red\">ERROR:Maximu Poly-GC is not valid</FONT><BR>\n"  ;
    $parameters{'maxPolyGC'} = "";
    $ok=0;
  }

  # Window Size
  my $win = $parameters{'windowSize'};
  if ($win > $min_len || $win < 2 || !($win =~ /^[+-]?\d+$/)) {
    print "<FONT COLOR=\"red\">ERROR: Window size is not valid</FONT><BR>";
    $parameters{'windowSize'}="";
    $ok=0;
  }

  # Max AT in Window
  my $win_at = $parameters{'maxATinWindow'};
  if ($win_at > $win || $win_at < 1 || !($win_at =~ /^[+-]?\d+$/)) {
    print "<FONT COLOR=\"red\">ERROR: Max AT content in window is not valid</FONT><BR>";
    $parameters{'maxATinWindow'}="";
    $ok=0;
  }

  # Max GC in Window
  my $win_gc = $parameters{'maxGCinWindow'};
  if ($win_gc > $win || $win_gc < 1 || !($win_gc =~ /^[+-]?\d+$/)) {
    print "<FONT COLOR=\"red\">ERROR: Max GC content in window is not valid</FONT><BR>";
    $parameters{'maxGCinWindow'}="";
    $ok=0;
  }

  # Comments
  my $comments = $parameters{'comments'};
  if ($comments) {
    $comments =~ s/<(.*?)/$1/g;
  }

  return $ok, \%parameters;
}
