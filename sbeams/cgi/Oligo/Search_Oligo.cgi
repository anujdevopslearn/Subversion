#!/usr/local/bin/perl 


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
    handle_request(ref_parameters=>\%parameters);
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
  my $SUB_NAME = "handle_request";

  #### Process the arguments list
  my $ref_parameters = $args{'ref_parameters'}
    || die "ref_parameters not passed";
  my %parameters = %{$ref_parameters};


  print "<H1> Oligo Search</H1>";

   # start the form
# the statement shown defaults to POST method, and action equal to this script
print $q->start_form;  

# print the form elements
print
    "Gene: ",$q->textfield(-name=>'gene'),
    $q->p,
    "Organism: ",
    $q->popup_menu(-name=>'organism',
	               -values=>['halobacterium-nrc1','haloarcula marismortui']),
    $q->p,
    "Select all oligo set type to search: ",
    $q->p,
    $q->popup_menu(-name=>'set_type',
                   -values=>['Gene Expression', 'Gene Knockout']),
    
    $q->p,
    $q->submit(-name=>"Search");

# end of the form
print $q->end_form,
      $q->hr; 

  
# IF this cgi was invoked because of a POST (i.e., the user hit the submit button)

if ($q->request_method() eq "POST" ) {
   
  my $organism = $parameters{organism};
  my $set_type = $parameters{set_type};

    ####Since no knockout oligos are available for haloarcule, need to prevent such queries####
    if ($organism eq 'haloarcula marismortui' && $set_type eq 'Gene Knockout') { 
        print "No data available for haloarcula marismortui knockout oligos" . "\n";
    }else{
	    my $gene = $parameters{gene};
		
        ####Decide whether to search knockouts or expression
        my $set_type_search;    #The part of the sql query below that depends on set type value
        if ($set_type eq 'Gene Expression') {
		  $set_type_search = "(OT.oligo_type_name='halo_exp_for' OR OT.oligo_type_name='halo_exp_rev')";      
        }elsif($set_type eq 'Gene Knockout'){
          $set_type_search = "(OT.oligo_type_name='halo_ko_a' OR OT.oligo_type_name='halo_ko_b' OR OT.oligo_type_name='halo_ko_c' OR OT.oligo_type_name='halo_ko_d' OR OT.oligo_type_name='halo_ko_e')";
        }else{
          print "Error: Invalid oligo type selected. ";
        }

      
       ####SQL query command
  	    my $sql = qq~ SELECT BS.biosequence_name AS 'Gene', OT.oligo_type_name AS 'Oligo type', OG.feature_sequence AS 'Oligo Sequence'
                      FROM $TBOG_SELECTED_OLIGO SO
                      LEFT JOIN $TBOG_BIOSEQUENCE BS ON (BS.biosequence_id=SO.biosequence_id)
                      LEFT JOIN $TBOG_OLIGO_TYPE OT ON (SO.oligo_type_id=OT.oligo_type_id)
                      LEFT JOIN $TBOG_OLIGO OG ON (OG.oligo_id=SO.oligo_id)
                      WHERE BS.biosequence_name='$gene' AND $set_type_search
					  ~;
       
       ####Print results of search if at least one oligo record was found, otherwise, notify user

		my @rows = $sbeams->selectSeveralColumns($sql);
        if ( scalar(@rows) >= 1 ) {
	        print $sbeams->displayQueryResult(sql_query=>$sql);
        }else{
	       print "Sorry.  No $set_type oligos were found for $gene";
        }


    
    }
}



  return;

} # end handle_request



