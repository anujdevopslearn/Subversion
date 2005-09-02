#!/usr/local/bin/perl

##############################################################################
# Program  	: Display_Oligo_Detailed.cgi
# Authors	: Patrick Mar <pmar@systemsbiology.org>,
#             Michael Johnson <mjohnson@systemsbiology.org>
#
# Other contributors : Eric Deutsch <edeutsch@systemsbiology.org>
# 
# Description : Displays more detailed information about 
#
#               
#
# Last modified : 9/2/05
###############################################################################

###############################################################################
# Set up all needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;

use lib qw (../../lib/perl);
use vars qw ($sbeams $sbeamsMOD $cg $current_contact_id $current_username
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
             $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
             @MENU_OPTIONS);


use DBI;
use CGI::Carp qw(fatalsToBrowser croak);
use POSIX;

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::Oligo;
use SBEAMS::Oligo::Settings;
use SBEAMS::Oligo::Tables;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::Oligo;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);


use CGI;
$cg = new CGI;


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

## Process options
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

  ## Do the SBEAMS authentication and exit if a username is not returned
  exit unless ($current_username = $sbeams->Authenticate());

  ## Read in the default input parameters
  my %parameters;
  my $n_params_found = $sbeams->parse_input_parameters(
    q=>$cg,parameters_ref=>\%parameters);

  #$sbeams->printDebuggingInfo($cg);     #Undo comment for debug mode

  my $apply_action = $parameters{'action'} || $parameters{'apply_action'};

  ## Process generic "state" parameters before we start
  $sbeams->processStandardParameters(
    parameters_ref=>\%parameters);


  ## Decide what action to take based on information so far
  if ($parameters{action} eq "???") {
    # Some action
  }elsif ($apply_action eq "EDIT") {                    #Make the changes
    $sbeamsMOD->printPageHeader();
    handle_request(ref_parameters=>\%parameters,);
	$sbeamsMOD->printPageFooter();
  }else {
    $sbeamsMOD->printPageHeader();                     #Go to entry form
	print_entry_form(ref_parameters=>\%parameters);
    $sbeamsMOD->printPageFooter();
  }
} # end main


###############################################################################
# print_entry_form - Print the form
###############################################################################
sub print_entry_form {
  my %args = @_;
  my $SUB_NAME = "handle_request";

  ## Process the arguments list
  my $ref_parameters = $args{'ref_parameters'}
    || die "ref_parameters not passed";
  my %parameters = %{$ref_parameters};


  ## Start the form
  ## The statement shown defaults to POST method, and action equal to this script
  print $cg->start_form;  

  ## Print the form elements
  my $gene = $parameters{Gene};
           ###ugly hack: gene is actually oligo name at this point, need to reconvert
           $gene =~ s/(\w+)\..*/$1/g;
  my $oligo_type = $parameters{Oligo_type};
  my $oligo_sequence = $parameters{Oligo_Sequence};
  
  ## Pass gene and oligo_type to the edit form so that updates can be executed for this oligo
  print qq~                                                                       
          <INPUT TYPE="hidden" NAME="gene" VALUE="$gene"> 
          <INPUT TYPE="hidden" NAME="oligo_type" VALUE="$oligo_type"> 
          ~;

  ## Extract and display more detailed info about selected oligo
  my $gc_percent = calc_gc(sequence=>$oligo_sequence);

  ## Include any restriction enzymes that may be involved 
  my $restr_enzyme = get_restriction_enzyme(sequence=>$oligo_sequence);

  my $sql = qq~
            SELECT OA.in_stock, OG.melting_temp, SO.start_coordinate, SO.stop_coordinate, SO.comments, OA.date_created, SO.date_modified, OG.sequence_length, OA.GC_content, OA.primer_dimer, OA.secondary_structure, OA.location, OG.oligo_id
            FROM $TBOG_SELECTED_OLIGO SO
            LEFT JOIN $TBOG_OLIGO OG ON (OG.oligo_id=SO.oligo_id)
            LEFT JOIN $TBOG_OLIGO_ANNOTATION OA ON (OA.oligo_id=OG.oligo_id)
            LEFT JOIN $TBOG_OLIGO_TYPE OT ON (SO.oligo_type_id=OT.oligo_type_id)
            LEFT JOIN $TBOG_BIOSEQUENCE BS ON (BS.biosequence_id=SO.biosequence_id)                           
            WHERE BS.biosequence_name='$gene' AND OT.oligo_type_name='$oligo_type'
	        ~;

  ## Declare the items we are retrieving 
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
  my  $oligo_id;

  foreach my $row (@rows) {
    my ($a, $b, $c, $d, $e, $f, $g, $h, $i, $j, $k, $l, $m) = @{$row};
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
    $oligo_id = $m;
  }
 
  ## Print simple table displaying oligo info
  print qq~
	<TABLE> <TR> <TD>OLIGO ID:</TD> <TD> $oligo_id</TD></TR>
	        <TR> <TD>ASSOCIATED GENE:</TD> <TD>$gene</TD> </TR>
            <TR> <TD>PRIMER TYPE:</TD> <TD>$oligo_type</TD> </TR>
            <TR> <TD>SEQUENCE:</TD> <TD>$oligo_sequence</TD> </TR>
            <TR> <TD>IN STOCK:</TD> <TD>$in_stock</TD> </TR>
            <TR> <TD>MELTING TEMP:</TD> <TD>$melting_temp</TD> </TR>
			<TR> <TD>CUT SITE:</TD> <TD>$restr_enzyme</TD> </TR>
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
  
  
  ## Display the UI section for editing oligo
  ## Only sequence, in stock (Y/N), location (associated with a person), and comments 
  ## can be changed.  Everything else must remain constant.
  
  print
	"In Stock: ";
  if($in_stock eq 'N'){
	print
	  $cg->popup_menu(-name=>'in_stock',
				   -values=>['N','Y'],
					  -default=>[$in_stock],
					  -override=>1);
  }else{
	print
	  $cg->popup_menu(-name=>'in_stock',
					  -values=>['Y','N'],
					  -default=>[$in_stock],
					  -override=>1);
  }
  
  print
	$cg->p,
	"Edit Sequence: ", 
	$cg->textfield(-name=>'sequence', -default=>$oligo_sequence), $cg->p;
  
  print
	$cg->p,
	"Location: ",
	"(K) Deep, (P) Minh, (S) Amy, (W) Kenia, (V) Madhavi, (F) Marc, (B) Nitin, (Z) Alok, (M) Patrick, (G) General, (N) Not Applicable", $cg->p, 
	$cg->textfield(-name=>'location'),
	$cg->p, 
	"Comments: ", $cg->textarea(-name=>'comments'),
	$cg->p,
	$cg->submit(-name=>"action", value=>"EDIT");
  
  ## Back button
  print qq~
	<BR><BR><A HREF="$CGI_BASE_DIR/Oligo/Search_Oligo.cgi">Search New Oligo</A><BR><BR>Use back button to return to search results.<BR>  
    ~;
  
  ## End of the form
  print $cg->end_form,
  $cg->hr; 
  
  return;
  
} # end print_entry_form


####################################################################################
# Handle Request - Called when the user edits the oligo and submits the changes
# This method updates the database fields appropriately. 
####################################################################################
sub handle_request {
  my %args = @_;
  my $SUB_NAME = "handle_request";

  ## Process the arguments list
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
  my %rs_params = $sbeams->parseResultSetParams(q=>$cg);
  my $base_url = "$CGI_BASE_DIR/Oligo/Search_Oligo.cgi";

  ## Edited Variables
  my $in_stock = $parameters{in_stock};
  my $location = $parameters{location};
  my $comments = $parameters{comments};
  my $sequence = $parameters{sequence};

  ## Output Stuff
  print "The following have been updated:\n";

  ## SQL updates

  ## table joins (same for all updates)
  my $table_joins = qq~
	                   FROM $TBOG_SELECTED_OLIGO SO
					   LEFT JOIN $TBOG_OLIGO OG ON (OG.oligo_id=SO.oligo_id)
					   LEFT JOIN $TBOG_OLIGO_ANNOTATION OA ON (OA.oligo_id=OG.oligo_id)
					   LEFT JOIN $TBOG_OLIGO_TYPE OT ON (SO.oligo_type_id=OT.oligo_type_id)
					   LEFT JOIN $TBOG_BIOSEQUENCE BS ON (BS.biosequence_id=SO.biosequence_id)
					   WHERE BS.biosequence_name='$gene' AND OT.oligo_type_name='$oligo_type'
					   ~;

 
  ## Update whether In_stock
  if ($in_stock){
	my $sql_stock = qq~
	  UPDATE OA
      SET OA.in_stock = '$in_stock'
      $table_joins
    ~;        
    
    $sbeams->executeSQL($sql_stock);
	print $cg->p, "In stock: Set to $in_stock", $cg->p;
	
  }
  
  ## Update sequence
  if ($sequence){
	my $sql_sequence = qq~
	  UPDATE OG
	  SET OG.feature_sequence = '$sequence'
	  $table_joins
	  ~;
	$sbeams->executeSQL($sql_sequence);
    ## Update sequence length
	my $new_length = length $sequence;
	my $sql_length = qq~
	  UPDATE OG
	  SET OG.sequence_length = $new_length
	  $table_joins
	  ~;
	$sbeams->executeSQL($sql_length);
	  
	print "Sequence: Set to $sequence", $cg->p;
  }

  ## Update location
  if ($location){
	my $sql_location = qq~
	  UPDATE OA
	  SET OA.location = '$location'
	  $table_joins
	  ~;
	$sbeams->executeSQL($sql_location);
	print "Location: Set to $location", $cg->p;
  }
  
  ## Update comments
  if ($comments){
	my $sql_comments = qq~
	  UPDATE SO
      SET SO.comments = '$comments'
      $table_joins
    ~;        
    
    $sbeams->executeSQL($sql_comments);
	print "Comments:  Added: $comments", $cg->p;
	
  }
 
  ## Update date_modified fields in Oligo Annot. and Selected Oligo tables
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


  ## Back button
  print qq~
	<BR><A HREF="$CGI_BASE_DIR/Oligo/Search_Oligo.cgi">Search New Oligo</A><BR><BR>  
    ~;
   

  return;

} # end handle_request


##########################################################################################
# calc_gc - Takes a sequence and calculates the percentage that g,c 
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
# get_restriction_enzyme - Returns the type of restriction enzyme that cuts along the cut site
# Not all oligos have these.  If they exist, they will be a sequence of (usually 6) bps in 
# capitals.  Add any additional enzymes to the elsif conditionals below.
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



