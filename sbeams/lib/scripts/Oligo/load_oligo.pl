#!/usr/local/bin/perl -w


##########################################################################################################
# Program  	: load_oligo.pl
# Authors	: Patrick Mar <pmar@systemsbiology.org>, Michael Johnson <mjohnson@systemsbiology.org>
#
# Other contributors : Eric Deutsch <edeutsch@systemsbiology.org>
# 
# Description	: Populates the following tables in the Oligo database -
#		  oligo_parameter_set, oligo_search, selected_oligo, oligo, oligo_annotation, oligo_set,
#                 oligo_oligo_set
#
# Last modified : 8/16/04
##########################################################################################################


##########################################################################################################
# Generic SBEAMS setup
##########################################################################################################
use strict;
use Getopt::Long;
use FindBin;

use lib "$FindBin::Bin/../../perl";

use vars qw ($sbeams $cgi $module $work_group $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE $TESTONLY
             $PROG_NAME
             $current_contact_id $current_username $sql);

####Setup SBEAMS core module####
use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
$sbeams = SBEAMS::Connection->new();

use CGI;
$cgi = CGI->new();


##########################################################################################################
# Command line stuff
##########################################################################################################
$USAGE = <<EOU;
Usage: load_oligo.pl [OPTIONS]
Options:
  --verbose n 		Set verbosity level. default is 0
  --quiet               Set flag to print nothing at all except errors
  --debug n             Set debug flag
  --testonly            If set, rows in the database are not changed or added
  --set_tag             The set_tag of a biosequence set.  Note that an entire fasta file
                        of oligo sequences (e.g.: haloarcula expression oligos) are initially
                        treated as a biosequence_set for loading purposes
  --delete_existing    Delete the existing biosequences for this set before
                       loading.  Normally, if there are existing biosequences,
                       the load is blocked.
  --update_existing    Update the existing biosequence set with information
                       in the file
  --datetime n             Uses default time stamp if user doesn't specify
  --user n            
  --project_id n         

  ####These 'options' are required.  They must be set.####
  --search_tool n      The search tool that was used to create this oligo set
  --set_type n         The type of oligo, e.g.: knockout, expression, etc.
  --bioseq_set n       The biosequence set this set of oligos belong to (genome, ORF set)
 
 e.g.:  $PROG_NAME --quiet

EOU

####Process options####
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly","delete_existing","update_existing",
        "datetime:s","user=s","project_id:s","search_tool:s","set_type:s","bioseq_set:s", "set_tag:s")){
          print "$USAGE";
          exit;
}

$VERBOSE = $OPTIONS{"verbose"} || 0;
$QUIET = $OPTIONS{"quiet"} || 0;
$DEBUG = $OPTIONS{"debug"} || 0;
$TESTONLY = $OPTIONS{"testonly"} || 0;
if($DEBUG) {
    print "Options settings:\n";
    print "  VERBOSE = $VERBOSE\n";
    print "  QUIET = $QUIET\n";
    print "  DEBUG = $DEBUG\n";
    print "  TESTONLY = $TESTONLY\n";
}

my $delete_existing = $OPTIONS{"delete_existing"} || '';
my $update_existing = $OPTIONS{"update_existing"} || '';
my $set_tag = $OPTIONS{"set_tag"} || '';

####If user doesn't specify datetime, use database timestamp####
my $datetime = $OPTIONS{"datetime"} || "CURRENT_TIMESTAMP";

####Try to authenticate, exit if a username is not returned####
exit unless ($current_username = $sbeams->Authenticate(work_group=>$work_group));

####If user doesn't specify username, get default####
my $user = $OPTIONS{"user"} || $current_username;

####If user doesn't specify project_id, use current project_id####
my $project_id = $OPTIONS{"project_id"} || $sbeams->getCurrent_project_id();

####required arguments####
my $search_tool = $OPTIONS{"search_tool"};
my $set_type = $OPTIONS{"set_type"};
my $bioseq_set = $OPTIONS{"bioseq_set"} || '';

####Create hashes that match set_types and search_tool names to their respective ids in the DB####
my %search_tool_ids = ( "create_halobacterium_ko.pl" => '1',
                      	"create_haloarcula_expr.pl" => '2',
                        "create_halobacterium_expr.pl" => '3'     );
my %set_type_ids = (  	"knockout" => '1',
			"expression" => '2'			); 	
                     

####Need to do command line error checking here####



##########################################################################################################
# Set Global Variables and execute main()
##########################################################################################################
main();
exit(0);


##########################################################################################################
# Main:
# 
# Call $sbeams->Authenticate() and exit if it fails or continue if it works
##########################################################################################################
sub main{
    $module = 'Oligo';
    $work_group = "Oligo_admin";
    $DATABASE = $DBPREFIX{$module};
    
    ####Try to authenticate, exit if a username is not returned####
    exit unless ($current_username = $sbeams->Authenticate(work_group=>$work_group));

    $sbeams->printPageHeader();

    ####Populate oligo_search table####
    my %rowdata = (  	'project_id' => $project_id,
       			'search_tool_id' => $search_tool_ids{$search_tool},
			'search_id_code' => time(),
 			'search_username' => $user,
			'search_date' => $datetime,
                        'comments' => "None"		);
    my $rowdata_ref = \%rowdata; 
    my $array_request_id = $sbeams->updateOrInsertRow(
	table_name => "${DATABASE}oligo_search",
        rowdata_ref => $rowdata_ref,
        insert => 1,
        return_PK => 1,
        add_audit_parameters => 1, 
        testonly => $TESTONLY, 
        verbose => $VERBOSE );
    undef %rowdata;


    ####Populate oligo_parameter_set####
  
    
    $sbeams->printPageFooter();
} #end main







