#!/usr/local/bin/perl -w

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# Program     : BiosapForm.cgi
# Author      : David Shteynberg <dshteyn@systemsbiology.org>
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

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# Script specific stuff
#
use strict;
use POSIX qw(strftime);
use POSIX qw(:sys_wait_h);
use lib qw (../../lib/perl);
use vars qw ($q $tm $tm_rng $o_conc $s_conc $blast_lib $same_as_lib
	     $mn_len $mx_len $mx_selfcomp $init_offset $step $dist 
	     $ftrs $featurama_lib $dirstr $pol_at $pol_gc $win_sz 
	     $win_at $win_gc $action $comments $PROGRAM_FILE_NAME $dbh 
	     $sbeams $sbeamsBS $current_username);
use DBI;
use CGI;
use CGI::Carp qw(fatalsToBrowser croak);


use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TableInfo;

use SBEAMS::Biosap;
use SBEAMS::Biosap::Settings;
use SBEAMS::Biosap::Tables;
use SBEAMS::Biosap::TableInfo;

$sbeams = new SBEAMS::Connection;
$sbeamsBS = new SBEAMS::Biosap;
$sbeamsBS->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);
$q = new CGI;
#$q->use_named_parameters(1);
$o_conc=0.00025;
$s_conc=50;
#
#-----------------------------------------------------------------------


#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# Globals
#
main();
$CGI::POST_MAX = 1024 * 10000;  #Max post (file upload) set at 10MB.
#
#-----------------------------------------------------------------------


###############################################################################
# Main Program:
###############################################################################
sub main {

    #### Do the SBEAMS authentication and exit if a username is not returned
    exit unless ($current_username = $sbeams->Authenticate());


    #### Deutsch added these in to reduce speing of warnings during
    #### Printform().  But still not enough.  Rewrite this to the all
    #### parameters are processed properly.  Fix rats nest below, too.
    $blast_lib = $q->param('blastlib') || "";
    $featurama_lib = $q->param('featuramalib') || "";


#    print
#	$q->header(-type=>'text/html'),
#	$q->start_html(-title=>'BioSap', 
#		       -bgcolor=>'#336699',
#		       -text=>'#000000',
#		       -link=>'#669966',
#		       -vlink=>'#000000');

    $action = $q->param('action');
    $dbh = $sbeams->getDBHandle();

    $sbeamsBS->printPageHeader();
#TODO: Clean this up !!!
    print "<center>",
	"<table width=\"750\" border=\"0\" bordercolor=\"#FFFFFF\" cellpadding=\"7\" cellspacing=\"0\" bgcolor=\"#D0DDDA\">",
	"<tr><td>",
	"<font face=\"Helvetica\" size=\"3\" color=\"#000000\">";
    if ($action eq "Clear") {
	printForm();
    }
    elsif ($action eq "Submit to BioSap")
    {
	if (processParams()) {
	    createRun();
	    print "Your search has been submitted to BioSap. ",
	          "Please write down the name of the directory displayed above ",
	          "for your search reference.<br>";
	}
	else {
	    printForm();
	}
	
    }
    elsif ($action eq "Test Run Featurama")
    {
	if (processParams()) {
	    print "</td></tr></table>";
            $sbeams->printPageFooter("CloseTables");
	    createRun(1); #create a run in a temp folder
	    #print "</td></tr></table>";
	    runFeaturama();
	    #print "<table width=\"750\" border=\"0\" bordercolor=\"#FFFFFF\" cellpadding=\"7\" cellspacing=\"0\" bgcolor=\"#D0DDDA\">",
	    #      "<tr><td>",
	    #      "<font face=\"Helvetica\" size=\"3\" color=\"#000000\">";
	}
	 
	printForm();
    }
    else {
	printForm();
    }
    print "</font></td></tr></table></center>",
          $q->end_html;
    $sbeamsBS->printPageFooter();
}

sub runFeaturama {
    #print "<table width=\"750\" border=\"0\" bordercolor=\"#FFFFFF\" cellpadding=\"7\" cellspacing=\"0\" bgcolor=\"#D0DDDA\">",
#	  "<tr><td>",
#          "<font face=\"Helvetica\" size=\"3\" color=\"#000000\">",
          print "Please wait for Featurama to finish ...  <br>";
   
    $| = 1;
    #print "/net/techdev/featurama/bin/featurama $dirstr/featurama.params<br>";
    print "<PRE>\n";
    system "/net/techdev/featurama/bin/featurama $dirstr/featurama.params 2>&1" || croak "Couldn't run featurama: $!";
    print "</PRE>\n";

    #open(FEATURAMA, 
#	 "/net/techdev/featurama/bin/featurama $dirstr/featurama.params 2>&1|") 
#	 || croak "Can't run program: $!\n";
    
    #print "</font></td></tr></table>";

    #while(<FEATURAMA>) {
#	print "<table width=\"750\" border=\"0\" bordercolor=\"#FFFFFF\" cellpadding=\"0\" cellspacing=\"0\" bgcolor=\"#D0DDDA\">",
#	      "<tr><td>",
##              "<font face=\"Helvetica\" size=\"2\" color=\"#000000\">";
#	print "$_ <br>";
#	print "</font></td></tr></table>";
#    }
   

   # close(FEATURAMA);
    
    #remove the temporary files
    system "/bin/rm", "-r","-f", "$dirstr" || croak "Couldn't formatdb: $!";
    print "<table width=\"750\" border=\"0\" bordercolor=\"#FFFFFF\" cellpadding=\"7\" cellspacing=\"0\" bgcolor=\"#D0DDDA\">",
	      "<tr><td>",
              "<font face=\"Helvetica\" size=\"3\" color=\"#000000\">";
    print "<br>Featurama Test Run is Done !<br><hr>";
    print "</font></td></tr></table>";
#    my $i;
#    my @output;
#    @output = `/net/techdev/featurama/bin/featurama $dirstr/featurama.params`;
    
#    foreach $i (@output) {
#	print "$i <br>";
#    }

}

sub createRun {
    my $testrun = $_[0];
    my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time);
    #TODO: make these parameters
    if ($testrun == 1) {
	$dirstr = "/net/techdev/biosap/tmp/" .
	    strftime("%Y%m%d.%H%M%S",$sec,$min,$hour,$mday,$mon,$year);
    }
    else  {
	$dirstr = "/net/techdev/biosap/data/" .
	    strftime("%Y%m%d.%H%M%S",$sec,$min,$hour,$mday,$mon,$year);
    }
    my $buffer;
    while (-e $dirstr) {
	sleep 5;
	($sec,$min,$hour,$mday,$mon,$year) = localtime(time);

	#TODO: make these parameters
	if ($testrun == 1) {
	    $dirstr = "/net/techdev/biosap/tmp/" .
		strftime("%Y%m%d.%H%M%S",$sec,$min,$hour,$mday,$mon,$year);
	}
	else  {
	    $dirstr = "/net/techdev/biosap/data/" .
		strftime("%Y%m%d.%H%M%S",$sec,$min,$hour,$mday,$mon,$year);
	}
    }
    mkdir ($dirstr) || croak "Couldn't Make directory ".$dirstr." " . $!;
    chmod (0777, $dirstr) || croak "Couldn't change directory permissions ".$dirstr." " . $!;
    
    print "Directory " . $dirstr . " created.<br>";
    
#THIS script no longer uploads the files    
# if ($uploaded_file) {
#     open(TARGET, ">$dirstr/$uploaded_file") || croak "Couldn't create target file $dirstr/$uploaded_file: $!";
	#while(<$uploaded_file>) {
	#    print (TARGET $_);
	#}
#     while (read($uploaded_file, $buffer, 1024)) {
#	    print TARGET $buffer;
#	}
#
#
#	close(TARGET) || croak "Couldn't create target file $!";
#	print "Target file $dirstr/$uploaded_file uploaded. <br>";
#
#
#
#	system "/usr/local/genome/blast/formatdb", "-p","F", "-o", "T", 
#	    "-i", "$dirstr/$uploaded_file" || croak "Couldn't formatdb: $!";
#	print "Uploaded file has been formatted. <br>";
#    } 
    
    if ($comments) {
	open (SINK, ">$dirstr/comments")  || croak "Couldn't create file $dirstr/comments $!";
	print (SINK $comments);
	close (SINK);
    }

    open (SINK,  ">$dirstr/featurama.params") || croak "Couldn't create file $dirstr/featurama.params $!";
    
   
    #print (SINK "user_name=".$ENV{'REMOTE_USER'}."\n");
    print (SINK "user_name=$current_username\n");

    #TODO: What happens if multiple libs have same name ???
    my $sql_query = qq~
	SELECT set_path
	  FROM  biosap.dbo.biosequence_set
	 WHERE set_name='$featurama_lib'
	   AND record_status != 'D'~;
    my ($gene_library) = $sbeams->selectOneColumn($sql_query);
    print (SINK "gene_library=$gene_library\n");


    my $sth;# = $dbh->prepare("$sql_query") || croak $dbh->errstr;
    my $rv;#  = $sth->execute || croak $dbh->errstr;
    my @row;# = $sth->fetchrow_array;
    #print (SINK "gene_library=$row[0]\n");
    

    print (SINK "output_directory=".$dirstr."\n");
    print (SINK "melting_temp=".$tm."\n");
    print (SINK "melting_temp_range=".$tm_rng."\n");
    print (SINK "minimum_length=".$mn_len."\n");
    print (SINK "maximum_length=".$mx_len."\n");
    print (SINK "maximum_selfcomp=".$mx_selfcomp."\n");
    print (SINK "step_size=".$step."\n");
    print (SINK "maximum_3prime_distance=".$dist."\n");
    print (SINK "initial_3prime_offset=".$init_offset."\n"); #TODO: change this later !!!
    print (SINK "maximum_features=".$ftrs."\n");
    print (SINK "maximum_polyAT_length=".$pol_at."\n");
    print (SINK "maximum_polyGC_length=".$pol_gc."\n");
    print (SINK "content_window_size=".$win_sz."\n");
    print (SINK "maximum_windowAT_content=".$win_at."\n");
    print (SINK "maximum_windowGC_content=".$win_gc."\n");
    print (SINK "oligo_concentration_mMol=".$o_conc."\n");
    print (SINK "salt_concentration_mMol=".$s_conc."\n");
    close (SINK) || croak "Couldn't create file featurama.params ".$dirstr." " . $!;
    print "File ". $dirstr."/featurama.params created. <br>";
    open (SINK,  ">".$dirstr."/blast.params") || croak "Couldn't create file blast.params ".$dirstr." " . $!;
    $sql_query = qq~
	    SELECT set_path
	      FROM  biosap.dbo.biosequence_set
	     WHERE set_name='$blast_lib'
	       AND record_status != 'D'~;
    $sth = $dbh->prepare("$sql_query") || croak $dbh->errstr;
    $rv  = $sth->execute || croak $dbh->errstr;
    @row = $sth->fetchrow_array;
    
    print (SINK "blast_library=$row[0]\n");
    print (SINK "expect_value=1\n");
    close (SINK) || croak "Couldn't create file blast.params ".$dirstr." " . $!;
    print "File ". $dirstr."/blast.params created. <br><br>";
}

sub processParams {
    my $ok=1;
    $same_as_lib = $q->param('same_as_lib');
    $blast_lib = $q->param('blastlib') || "";
    $featurama_lib = $q->param('featuramalib') || "";
    #$search_filename =~ m/^.*(\\|\/)(.*)/; # strip the remote path and keep filename
   # $search_filename = $2;

    if (($featurama_lib eq $blast_lib) && ($same_as_lib eq "No")) {
	print "<font color=red>ERROR: Library files specified are the same. </font><br>";
	$ok=0;
    }
    elsif (($featurama_lib ne $blast_lib) && ($same_as_lib eq "Yes")) {
	print "<font color=red>ERROR: Library files specifies are not the same. </font><br>";
	$ok=0;
    }
   
    $tm = $q->param('meltTemp');
    if ($tm > 100 || $tm < 0 || length($tm)==0 ||
	($tm == 0 &&
	 !($tm =~/^[+-]?0*[.?0|0.?]0*[[eE]+[+-]?\d*[.?\d|\d.?]\d*]*/))) {
	print "<font color=red>ERROR: Tm is not valid</font><br>";
	$tm="";
	$ok=0;
    }
    $tm_rng = $q->param('meltTempRange');
    if ($tm_rng > 50 || $tm_rng < 0 || 
	($tm_rng == 0 &&
	 !($tm =~/^[+-]?0*[.?0|0.?]0*[[eE]+[+-]?\d*[.?\d|\d.?]\d*]*/))) {
	print "<font color=red>ERROR: Tm range is not valid</font><br>";
	$tm_rng="";
	$ok=0;
    } 
    $o_conc=$q->param('oligoConc');
    if ($o_conc <= 0) {
	print "<font color=red>ERROR: Oligo Conc. is not valid</font><br>";
	$o_conc="";
	$ok=0;
    }
    $s_conc=$q->param('saltConc');
    if ($s_conc <= 0) {
	print "<font color=red>ERROR: Salt Conc. is not valid</font><br>";
	$s_conc="";
	$ok=0;
    }
    $mn_len=$q->param('minLen');
    if ($mn_len > 100 || $mn_len < 2 || !($mn_len =~ /^[+-]?\d+$/)) {
	print "<font color=red>ERROR: Min Length is not valid</font><br>";
	$mn_len="";
	$ok=0;
    }
    $mx_len=$q->param('maxLen');
    if ($mx_len > 100 || $mx_len < $mn_len || $mx_len == 0  || 
	!($mx_len =~ /^[+-]?\d+$/)) {
	print "<font color=red>ERROR: Max Length is not valid</font><br>";
	$mx_len="";
	$ok=0;
    } 
    $mx_selfcomp=$q->param('maxSelfComp');
    if ($mx_selfcomp > $mn_len || $mx_selfcomp < 0 || 
	!($mx_len =~ /^[+-]?\d+$/)) {
	print "<font color=red>ERROR: Max Self-Comp is not valid</font><br>";
	$mx_selfcomp="";
	$ok=0;
    } 
    $step=$q->param('stepSize');
    if ($step > 100000 || $step < 0 || !($step =~ /^[+-]?\d+$/)) {
	print "<font color=red>ERROR: Step size is not valid</font><br>";
	$step="";
	$ok=0;
    }
    $dist=$q->param('max3PrimeDist');
    if ($dist > 100000 || $dist < 2 || !($dist =~ /^[+-]?\d+$/)) {
	print "<font color=red>ERROR: Max 3' distance is not valid</font><br>";
	$dist="";
	$ok=0;
    }
    $init_offset=$q->param('initOffset');
    if ($dist > 100000 || $dist < 0 || !($dist =~ /^[+-]?\d+$/)) {
	print "<font color=red>ERROR: Initial 3' offset is not valid</font><br>";
	$dist="";
	$ok=0;
    }

    $ftrs=$q->param('maxFeatures');
    if ($ftrs > 100000 || $ftrs < 1 || !($ftrs =~ /^[+-]?\d+$/)) {
	print "<font color=red>ERROR: Maximum features to find is not valid</font> (must be 1-100000)<br>";
	$ftrs="";
	$ok=0;
    }
    $pol_at=$q->param('maxPolyAT');
    if ($pol_at > $mx_len || $pol_at < 2 || !($pol_at =~ /^[+-]?\d+$/)) {
	print "<font color=red>ERROR: Maximum poly-AT is not valid</font><br>";
	$pol_at="";
	$ok=0;
    }

    $pol_gc=$q->param('maxPolyGC');
    if ($pol_gc > $mx_len || $pol_gc < 2 || !($pol_gc =~ /^[+-]?\d+$/)) {
	print "<font color=red>ERROR: Maximum poly-GC is not valid</font><br>";
	$pol_gc="";
	$ok=0;
    }   
    $win_sz=$q->param('windowSize');
    if ($win_sz > $mn_len || $win_sz < 2 || !($win_sz =~ /^[+-]?\d+$/)) {
	print "<font color=red>ERROR: Window size is not valid</font><br>";
	$win_sz="";
	$ok=0;
    }
    $win_at=$q->param('maxATinWindow');
    if ($win_at > $win_sz || $win_at < 1 || !($win_at =~ /^[+-]?\d+$/)) {
	print "<font color=red>ERROR: Max AT content in window is not valid</font><br>";
	$win_at="";
	$ok=0;
    }
    $win_gc=$q->param('maxGCinWindow');
    if ($win_gc > $win_sz || $win_gc < 1 || !($win_gc =~ /^[+-]?\d+$/)) {
    	print "<font color=red>ERROR: Max GC content in window is not valid</font><br>";
	$win_gc="";
	$ok=0;
    }
    
    
    $comments=$q->param('comments');
    if ($comments) {
	$comments =~ s/<(.*?)>/$1/g;
    }

#TODO: are we going to allow e-value specification
#    if ($q->param('E-value')< 0 ||
#	!$q->param('E-value')) {
#	print "<font color=red>ERROR: E-value is not valid</font><br>";
#	$q->param_fetch('E-value')->[1]="";
#    $ok=0;
 
    return $ok;
}

sub printForm {
    my $sql_query = "SELECT set_name FROM biosap.dbo.biosequence_set WHERE record_status != 'D'";
    my $sth = $dbh->prepare("$sql_query") || croak $dbh->errstr;
    my $rv  = $sth->execute || croak $dbh->errstr;
    my @libs;
    print
	$q->startform(-method=>'POST'),
#	$q->startform(-action=>'http://db.systemsbiology.net/dev5/sbeams/cgi/Biosap/BiosapForm.cgi',
#		      -method=>'POST', -enctype=>'multipart/form-data'),
	"<h3>BioSequence Files:</h3>",
	"<table cellpadding=5>",
	"<tr>",
	"<td><b>Featurama Library:</b>&nbsp ",
	"(used in Featurama search)</td>",
	"<td>",
	"<select name=featuramalib size=1>";
    my $i = 0;
    while (my @row = $sth->fetchrow_array) {
	print "<option";

	if ($featurama_lib eq $row[0]) {
	    print " SELECTED>";
	}
	else {
	    print ">";
	}
	print "$row[0]";
	$libs[$i] = $row[0];
	$i++;
    }

    print "</select></td></tr>",
        "<td><b>BLAST Library:</b>&nbsp ",
	"(used in BLAST search)</td>",
	"<td>",
	"<select name=blastlib size=1>";
    
    foreach $_ (@libs) {
	print "<option";
	if ($blast_lib eq $_) {
	    print " SELECTED>";
	}
	else {
	    print ">";
	}
	print "$_";
    }

    print "</select></td></tr>",
	"<tr><td colspan=2>",
	"<br><b>Sanity Check:</b><br>Are the sequences for which you want features",
        " the same as the BLAST Library you've selected? &nbsp;",
	$q->popup_menu(-name=>'same_as_lib',-size=>1,
                        -values=>['Yes', 'No']),
	"</td></tr>",
	"</table>",
	"<br><hr>",
	"<h3>Search Parameters:</h3>",
	"<table border=0 cellpadding=5>", 
	"<tr>",
        "<td><b>Oligo Conc.</b> (mMol):</td>",
        "<td align=right>",
	"<input type=text size=9 name=oligoConc value=$o_conc></td>",
	"<td align=right><b> Salt Conc.</b> (mMol):</td>",
	"<td><input type=text size=5 name=saltConc value=$s_conc></td></tr>",
	"<tr>",
	"<td><b>Tm</b> (0-100):",
	"<input type=text size=5 name=meltTemp value=$tm></td>",
 	"<td><b>+/-</b> (0-50):",
	"<input type=text size=5 name=meltTempRange value=$tm_rng></td>",
	"<td align=right><b> Step Size</b> (0-100,000):</td>",
	"<td><input type=text size=5 name=stepSize value=$step></td></tr>",
	"<tr>",
	"<td><b>Min. Feature Length</b> (2-100):</td>",
	"<td> <input type=text size=5 name=minLen value=$mn_len></td>",
	"<td align=right><b> Max. Feature Length</b> (Min. Length-100):</td>",
	"<td> <input type=text size=5 name=maxLen value=$mx_len></td></tr>",
        "<tr>",
	"<td><b>Max. 3' Distance</b> (2-100,000):</td>",
	"<td> <input type=text size=5 name=max3PrimeDist value=$dist></td>",
	"<td align=right><b> Max. Features per Gene</b> (1-100,000):</td>",
	"<td> <input type=text size=5 name=maxFeatures value=$ftrs></td></tr>",
        "<tr>",
	"<td><b>Initial 3' Offset</b> (0-100,000):</td>",
	"<td> <input type=text size=5 name=initOffset value=$init_offset></td>",
        "<td><b>Max. Self-Comp Score</b> (0-Min. Length):</td>",
	"<td> <input type=text size=5 name=maxSelfComp value=$mx_selfcomp></td>",
	"</table>",
	"<br>",	
	"<hr>",
	"<h3>Content Heuristics:</h3>",
	"<table cellpadding=5>",
	"<tr>",
	"<td><b>Max. Poly A/T Length</b> (2-Max. Length):</td>",
	"<td><input type=text size=5 name=maxPolyAT value=$pol_at></td>",
	"<td align=right><b>Max. Poly G/C Length</b> (2-Max. Length):</td>",
	"<td><input type=text size=5 name=maxPolyGC value=$pol_gc></td></tr>",
	"<tr>",   
	"<td><b>Heuristic Window Size</b> (2-Min. Length):</td>",
	"<td colspan=2>",
	"<input type=text size=5 name=windowSize value=$win_sz></td></tr>",
	"<tr>",
        "<td><b>Max. A/T in Window</b> (1-WindowSize):</td>",
	"<td><input type=text size=5 name=maxATinWindow value=$win_at></td>",
	"<td align=right><b>Max. G/C in Window</b> (1-WindowSize):</td>",
	"<td> <input type=text size=5 name=maxGCinWindow value=$win_gc></td></tr>",
	"</table>",
	"<br><hr>",
	"<h3>Comments:</h3>",
	"<textarea name=comments cols=80 rows=5>$comments</textarea>",
        "<br><br><hr>",
	"<input type=submit name=action value=\"Submit to BioSap\">",
	"<input type=submit name=action value=\"Test Run Featurama\">",
	"<input type=submit name=action value=\"Clear\">",
	$q->endform();
}






















