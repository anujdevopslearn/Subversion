#!/usr/local/bin/perl

###############################################################################
# Program     : Display_Oligo_Detailed.cgi
# Author      : Patrick Mar <pmar@systemsbiology.org>
#
# Description : Prints a more detailed description of a particular oligo. 
#               Allows updating of oligo fields.  
###############################################################################

###############################################################################
# Set up all needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;

use lib qw (../../lib/perl);
use vars qw ($sbeams $sbeamsMOD $q $current_contact_id $current_username
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
             $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
             @MENU_OPTIONS);


use DBI;
use CGI::Carp qw(fatalsToBrowser croak);
use POSIX;

use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::Oligo;
use SBEAMS::Oligo::Settings;
use SBEAMS::Oligo::Tables;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::Oligo;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);


#use CGI;
#$q = new CGI;


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
exit(0);



###############################################################################
# Main Program:
#
# Call $sbeams->Authenticate() and exit if it fails or continue if it works.
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
  #$sbeams->printDebuggingInfo($q);     #Undo comment for debug mode
  my $apply_action = $parameters{'action'} || $parameters{'apply_action'};

  #### Process generic "state" parameters before we start
  $sbeams->processStandardParameters(
    parameters_ref=>\%parameters);


  #### Decide what action to take based on information so far
  if ($parameters{action} eq "???") {
    # Some action
  }elsif ($apply_action eq "EDIT") {                    #Make the changes
    $sbeamsMOD->printPageHeader();
    handle_request(ref_parameters=>\%parameters,
				 );
	$sbeamsMOD->printPageFooter();
  }else {
    $sbeamsMOD->printPageHeader();                     #Go to entry form
	print_entry_form(ref_parameters=>\%parameters);
    $sbeamsMOD->printPageFooter();
  }




} # end main


###############################################################################
# Print Entry Form
###############################################################################
sub print_entry_form {
  my %args = @_;
  my $SUB_NAME = "handle_request";

  #### Process the arguments list
  my $ref_parameters = $args{'ref_parameters'}
    || die "ref_parameters not passed";
  my %parameters = %{$ref_parameters};


  #start the form
  #the statement shown defaults to POST method, and action equal to this script
  print $q->start_form;  

  #print the form elements
  my $gene = $parameters{Gene};
           ###ugly hack: gene is actually oligo name at this point, need to reconvert
           $gene =~ s/(\w+)\..*/$1/g;
  my $oligo_type = $parameters{Oligo_type};
  my $oligo_sequence = $parameters{Oligo_Sequence};
  
  #pass gene and oligo_type to the edit form so that updates can be executed for this oligo
  print qq~                                                                       
          <INPUT TYPE="hidden" NAME="gene" VALUE="$gene"> 
          <INPUT TYPE="hidden" NAME="oligo_type" VALUE="$oligo_type"> 
          ~;

  ####Extract and Display more detailed info about selected oligo
  my $gc_percent = calc_gc(sequence=>$oligo_sequence); 
  my $restr_enzyme = get_restriction_enzyme(sequence=>$oligo_sequence);

  my $sql = qq~
            SELECT OA.in_stock, OG.melting_temp, SO.start_coordinate, SO.stop_coordinate, OA.comments, OA.date_created, SO.date_modified, OG.sequence_length, OA.GC_content, OA.primer_dimer, OA.secondary_structure, OA.location
            FROM $TBOG_SELECTED_OLIGO SO
            LEFT JOIN $TBOG_OLIGO OG ON (OG.oligo_id=SO.oligo_id)
            LEFT JOIN $TBOG_OLIGO_ANNOTATION OA ON (OA.oligo_id=OG.oligo_id)
            LEFT JOIN $TBOG_OLIGO_TYPE OT ON (SO.oligo_type_id=OT.oligo_type_id)
            LEFT JOIN $TBOG_BIOSEQUENCE BS ON (BS.biosequence_id=SO.biosequence_id)                           
            WHERE BS.biosequence_name='$gene' AND OT.oligo_type_name='$oligo_type'
	        ~;

  my @rows = $sbeams->selectSeveralColumns($sql);

  my  $in_stock;
  my  $melting_temp;
  my  $start_coordinate; 
  my  $stop_coordinate;
  my  $comments;
  my  $date_created; 
  my  $last_modified;
  my  $length;
  my  $GC_content;
  my  $primer_dimer;
  my  $secondary_structure;
  my  $location;

  foreach my $row (@rows) {
    my ($a, $b, $c, $d, $e, $f, $g, $h, $i, $j, $k, $l) = @{$row};
    $in_stock = $a;
    $melting_temp = $b;
    $start_coordinate = $c;
    $stop_coordinate = $d;
    $comments = $e;
    $date_created = $f;
    $last_modified = $g;
	$length = $h;
	$GC_content = $i;
	$primer_dimer = $j;
	$secondary_structure = $k;
	$location = $l;
  }

  
  

 
  ####print simple table displaying oligo info
  print qq~
	<TABLE> <TR> <TD>ASSOCIATED GENE:</TD> <TD>$gene</TD> </TR>
            <TR> <TD>PRIMER TYPE:</TD> <TD>$oligo_type</TD> </TR>
            <TR> <TD>SEQUENCE:</TD> <TD>$oligo_sequence</TD> </TR>
            <TR> <TD>IN STOCK:</TD> <TD>$in_stock</TD> </TR>
            <TR> <TD>MELTING TEMP:</TD> <TD>$melting_temp</TD> </TR>
			<TR> <TD>CUT SITE:</TD> <TD>$restr_enzyme</TD> </TR>
            <TR> <TD>START COORDINATE:</TD> <TD>$start_coordinate</TD> </TR>
            <TR> <TD>STOP COORDINATE:</TD> <TD>$stop_coordinate</TD> </TR>
			<TR> <TD>SEQUENCE LENGTH:</TD> <TD>$length</TD> </TR>
            <TR> <TD>GC PERCENTAGE:</TD> <TD>$GC_content</TD> </TR>
			<TR> <TD>PRIMER DIMER:</TD> <TD>$primer_dimer</TD> </TR>
			<TR> <TD>SECONDARY STRUCTURE:</TD> <TD>$secondary_structure</TD> </TR>
			<TR> <TD>LOCATION:</TD> <TD>$location</TD> </TR>
            <TR> <TD>COMMENTS:</TD> <TD>$comments</TD> </TR>
            <TR> <TD>DATE CREATED:</TD> <TD>$date_created</TD> </TR>
			<TR> <TD>LAST MODIFIED:</TD> <TD>$last_modified</TD> </TR>
    </TABLE> ~;

  print "<br>";
  
  
  ####USER INTERFACE section for editing oligo (Commented out for now but don't delete!)
  print
	"In Stock: ",
	$q->popup_menu(-name=>'in_stock',
				   -values=>['N','Y'],
				   -default=>[$in_stock],
				   -override=>1),
	$q->p,
	"Location: ", $q->textfield(-name=>'location'),
	$q->p, 
	"Comments: ", $q->textarea(-name=>'comments'),
	$q->p,
	$q->submit(-name=>"action", value=>"EDIT");

  ####Back button
  print qq~
	<BR><A HREF="http://db.systemsbiology.net/dev5/sbeams/cgi/Oligo/Search_Oligo.cgi">Back</A><BR><BR>  
    ~;
  
  # end of the form
  print $q->end_form,
      $q->hr; 

  return;

} # end print_entry_form


####################################################################################
# Handle Request
####################################################################################
sub handle_request {
  my %args = @_;
  my $SUB_NAME = "handle_request";

  #### Process the arguments list
  my $ref_parameters = $args{'ref_parameters'}
    || die "ref_parameters not passed";
  my %parameters = %{$ref_parameters};

  ## Assign parameters that were passed in to local vars
  my $gene = $parameters{'gene'};
  my $oligo_type = $parameters{'oligo_type'};

  ## Useful Variables
  my $apply_action = $parameters{'action'} || $parameters{'apply_action'};
  my %resultset = ();
  my $resultset_ref = \%resultset;
  my %max_widths;
  my %rs_params = $sbeams->parseResultSetParams(q=>$q);
  my $base_url = "$CGI_BASE_DIR/Oligo/Search_Oligo.cgi";

  ## Edited Variables
  my $in_stock = $parameters{in_stock};
  my $location = $parameters{location};
  my $comments = $parameters{comments};

  ## Output Stuff
  print "The following have been updated:\n";

  ## SQL updates

  #table joins (same for all updates)
  my $table_joins = qq~
	                   FROM $TBOG_SELECTED_OLIGO SO
					   LEFT JOIN $TBOG_OLIGO OG ON (OG.oligo_id=SO.oligo_id)
					   LEFT JOIN $TBOG_OLIGO_ANNOTATION OA ON (OA.oligo_id=OG.oligo_id)
					   LEFT JOIN $TBOG_OLIGO_TYPE OT ON (SO.oligo_type_id=OT.oligo_type_id)
					   LEFT JOIN $TBOG_BIOSEQUENCE BS ON (BS.biosequence_id=SO.biosequence_id)
					   WHERE BS.biosequence_name='$gene' AND OT.oligo_type_name='$oligo_type'
					   ~;

 
  #Update whether In_stock
  if ($in_stock){
	my $sql_stock = qq~
	  UPDATE OA
      SET OA.in_stock = '$in_stock'
      $table_joins
    ~;        
    
    $sbeams->executeSQL($sql_stock);
	print $q->p, "In stock: Set to $in_stock", $q->p;
	
  }

  #Update location
  if ($location){
	my $sql_location = qq~
	  UPDATE OA
	  SET OA.location = '$location'
	  $table_joins
	  ~;
	$sbeams->executeSQL($sql_location);
	print "Location: Set to $location", $q->p;
  }
  
  #Update comments
  if ($comments){
	my $sql_comments = qq~
	  UPDATE OA
      SET OA.comments = '$comments'
      $table_joins
    ~;        
    
    $sbeams->executeSQL($sql_comments);
	print "Comments:  Added: $comments", $q->p;
	
  }
 
  ####Update date_modified fields in Oligo Annot. and Selected Oligo tables
  my $sql_SOmodified = qq~
	UPDATE SO
	SET SO.date_modified = CURRENT_TIMESTAMP
	$table_joins
	~;
  $sbeams->executeSQL($sql_SOmodified);

  my $sql_OAmodified = qq~
	UPDATE OA
	SET OA.date_modified = CURRENT_TIMESTAMP
	$table_joins
	~;
  $sbeams->executeSQL($sql_OAmodified);


  ####Back button
  print qq~
	<BR><A HREF="http://db.systemsbiology.net/dev5/sbeams/cgi/Oligo/Search_Oligo.cgi">Back</A><BR><BR>  
    ~;
   

  return;

} # end handle_request


##########################################################################################
#calc_gc - takes a sequence and calculates the percentage that g,c 
#########################################################################################
sub calc_gc {

  my %args = @_;
  my $SUB_NAME = "calc_gc";

  my $seq = $args{'sequence'};
  my @array = split(//,$seq);

  my $total = 0;
  my $gc = 0;

  $seq = lc $seq;
  
  foreach my $character (@array) {
	if($character eq "g" || $character eq "c") {
	  $gc = $gc + 1;       #increase count for each 'g' or 'c' found
    }
    $total = $total + 1;
  }
  
  
  if ($total == 0) {
    return 0.0;           #to avoid dividing by zero
  }else{
    return $gc / $total;  #return percentage of oligo sequence that 'g' and 'c' make up   
  }
}


#############################################################################################
#get_restriction_enzyme - returns the type of restriction enzyme that cuts along the cut site
#############################################################################################
sub get_restriction_enzyme {
  my %args = @_;
  my $SUB_NAME = "get_restriction_enzyme";
  
  my $seq = $args{'sequence'};
  my $cut_site;
  if($seq =~ /.*GGATCC.*/){        #if BamHI
	$cut_site = "BamHI";
  }elsif($seq =~ /.*GAATTC.*/){    #if EcoRI
	$cut_site = "EcoRI";
  }elsif($seq =~ /.*AAGCTT.*/){     #if HindIII
	$cut_site = "HindIII";
  }elsif($seq =~ /.*CCATGG.*/){    #if NcoI
	$cut_site = "NcoI";
  }elsif($seq =~ /.*CATATG.*/){    #if NdeI
	$cut_site = "NdeI";
  }elsif($seq =~ /.*GCTAGC.*/){    #if NheI
	$cut_site = "NheI";
  }else{
	$cut_site = "None Found";
  }

  return $cut_site;
}



