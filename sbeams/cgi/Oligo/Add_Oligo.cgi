#!/usr/local/bin/perl 


###############################################################################
# Set up all needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;

use lib qw (../../lib/perl);
use vars qw ($sbeams $sbeamsMOD $q $q1 $current_contact_id $current_username
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
             $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME $project_id
             $search_tool_id $gene_set_tag $chromosome_set_tag @MENU_OPTIONS);
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
  #$sbeams->printDebuggingInfo($q);


  #### Process generic "state" parameters before we start
  $sbeams->processStandardParameters(
    parameters_ref=>\%parameters);


  #### Decide what action to take based on information so far
  if ($parameters{action} eq "???") {
    # Some action
  }else {
    $sbeamsMOD->printPageHeader();
    print_javascript();
    handle_request(ref_parameters=>\%parameters,
                   user=>$current_username);
    $sbeamsMOD->printPageFooter();
  }


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
# Handle Request
###############################################################################
sub handle_request {
  my %args = @_;
  my $SUB = "handle_request";
  my $current_username = $args{user} || 
	die "[BUG-$SUB]: username not passed\n";
  my $sql;
  my @rows;
  

  #### Process the arguments list
  my $ref_parameters = $args{'ref_parameters'}
    || die "ref_parameters not passed";
  my %parameters = %{$ref_parameters};


  print "<H1> Add New Oligo </H1>";
  
  
  # start the form
  # the statement shown defaults to POST method, and action equal to this script
  print $q->start_form;  
  
  # print the form elements
  print
    "Enter gene name: ",$q->textfield(-name=>'gene'),
    $q->p,
    "Enter sequence: ",$q->textarea(-name=>'sequence'),
    $q->p,
    "Select organism: ",
    $q->popup_menu(-name=>'organism',
	               -values=>['halobacterium-nrc1','haloarcula marismortui']),
    $q->p,
    "Select oligo set type: ",
    $q->p,
    $q->popup_menu(-name=>'set_type',
                   -values=>['Gene Expression', 'Gene Knockout']),
	$q->p,
	"Select oligo type extension: ",
	$q->p,
	$q->popup_menu(-name=>'type_extension',
				   -values=>['a','b','c','d','e','f','g','h','for','rev']),
                                                              
    $q->p,
    $q->submit(-name=>"Add Oligo");

  # end of the form
    print $q->end_form,
    $q->hr; 
        

  if ($q->request_method() eq "POST" ) {
    my $gene = $parameters{gene};
    my $sequence = $parameters{sequence};
    my $organism = $parameters{organism};
    my $set_type = $parameters{set_type};
	my $type_extension = $parameters{type_extension};

    ####error check for haloarcula marismortui and knockouts: invalid choice
	if($organism eq "haloarcula marismortui" && $set_type eq "Gene Knockout"){
	  print "No knockouts for haloarcula marismortui available", $q->p;
	}else{

	  ####get project_id, chromosome set_tag, gene set_tag
	  if($organism eq "halobacterium-nrc1"){
		$project_id = 425;
		$chromosome_set_tag = "halobacterium_genome";
		$gene_set_tag = "halobacterium_orfs";
	  }else{
		$project_id = 424;    ##must be haloarcula marismortui
		$chromosome_set_tag = "haloarcula_genome";
		$gene_set_tag = "haloarcula_orfs";
	  }

	  ####more error checking
	  if($set_type eq "Gene Expression" && ($type_extension ne "for" || $type_extension ne "rev")){
		print "Invalid type extension selected for Gene Expression.", $q->p;
	  }elsif($set_type eq "Gene Knockout" && ($type_extension eq "for" || $type_extension eq "rev")){
		print "Invalid type extension selected for Gene Knockout", $q->p;
	  }else{
	  
		####search tool id
		my $search_tool_id = 5;   #5 is the default search tool id for 
		                          #user-defined oligos


        ####search for vng synonym of common name
		if($organism eq 'halobacterium-nrc1'){
		  open(A, "halobacterium.txt") || die "Could not open halobacterium.txt";
		}elsif($organism eq 'haloarcula marismortui'){
		  open(A, "haloarcula.txt") || die "Could not open haloarcula.txt";
		}else{
		  open(A, "halobacterium.txt") || die "Could not open halobacterium.txt"; #default = nrc-1
		}
		while(<A>){
		  my @temp = split;
		  if($gene eq $temp[1]){  #if a common name was entered
			$gene = $temp[0];     #assign $gene to the equivalent canonical name
		  }
		}  
		close(A);

		$gene = lc $gene;

		####get TM, SS
        my $tm;
        my $ss;
	    my $tm_command = "melttemp -OLI=" . $sequence . " -OUT=gene.melt -Default";
        my $ss_command = "primepair -OLIGOSF=" . $sequence . " -OLIGOSR=" . $sequence . " -OUT=gene.primepair -Default";

		$tm_command = "ssh -l gcgbot -i /net/dblocal/www/html/dev5/sbeams/cgi/Oligo/gcg-key2 ouzo \"uptime; cd /local/scratch/pmar; $tm_command; scp gene.melt /net/dblocal/www/html/dev5/sbeams/cgi/Oligo/gene.melt\"";

		system("$tm_command | /dev/null");
		open(MELT, "<gene.melt") || die "cannot open gene.melt\n";
		my(@lines) = <MELT>;
		my $melt_file = "";
		foreach my $line (@lines) {
		  $melt_file = $melt_file . $line;
		}
		close(MELT);
		if($melt_file =~ /oligo Tm\s\(degrees Celsius\):\s+(\d+)\.(\d+)/){
		  $tm = $1 . "." . $2;
	    }else{
		  $tm = "undefined";
		}

		$ss_command = "ssh -l gcgbot -i /net/dblocal/www/html/dev5/sbeams/cgi/Oligo/gcg-key2 ouzo \"uptime; cd /local/scratch/pmar; $ss_command; scp gene.primepair /net/dblocal/www/html/dev5/sbeams/cgi/Oligo/gene.primepair\"";
	
		system("$ss_command | /dev/null");		
		open(PRIMEPAIR, "<gene.primepair") || die "cannot open gene.primepair\n";
		my (@lines) = <PRIMEPAIR>;
		my $primepair_file = "";
		foreach my $line (@lines) {
		  $primepair_file = $primepair_file . $line;
		}
		close(PRIMEPAIR);

		if($primepair_file =~ /primer self-annealing:\s+(\d+)/){
		  if($1 ne "0"){
			$ss = 'Y';    #primer does fold back onto itself
		  }else{
			$ss = 'N';    #primer is good to go
		  }
		}else{
		  $ss = 'U';      #secondary structure unknown 
		}

        system("rm ./gene.melt; rm ./gene.primepair");
	   

		####create a new oligo_file
		open(OLIGO, ">temp_oligo_file");
		my $outputdata = ">" . $gene . "." . $type_extension . " 0 0 TM=$tm SS=$ss\n";
		$outputdata = $outputdata . $sequence;
		print OLIGO $outputdata;
		close(OLIGO);
		
		####use load_oligo.pl to load the newly created oligo into the db
		my $command_line = "/net/dblocal/www/html/dev5/sbeams/lib/scripts/Oligo/load_oligo.pl --search_tool_id " . $search_tool_id . " --gene_set_tag " .  $gene_set_tag . " --chromosome_set_tag " . $chromosome_set_tag . " --oligo_file ./temp_oligo_file --project_id 425";
		system("$command_line | /dev/null");

		####Allow user to view if oligo has been added.
		my @gene_arr = ($gene);
		print qq~ 
		  New Oligo Submitted to Database.  Note: Will only be added if valid.  View added Oligo:
          <A HREF="http://db.systemsbiology.net/dev5/sbeams/cgi/Oligo/Search_Oligo.cgi?apply_action=QUERY&organism=$organism&set_type=$set_type&genes=@gene_arr">Oligo Search</A><BR><BR>  
        ~;
	  }
	}
  }

  
  ####Back button
  print qq~
	<BR><A HREF="http://db.systemsbiology.net/dev5/sbeams/cgi/Oligo/Oligo_Interface.cgi">Back</A><BR><BR>   ~;
  return;

} # end handle_request


