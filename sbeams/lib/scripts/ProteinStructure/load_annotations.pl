#!/usr/local/bin/perl -w

###############################################################################
# Program     : load_annotations.pl
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This script loads custom annotation information into the
#               protein structure database
#
###############################################################################


###############################################################################
# Generic SBEAMS setup for all the needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;

use lib qw (../perl ../../perl);
use vars qw ($sbeams $sbeamsMOD $q $current_username
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $TESTONLY
            );


#### Set up SBEAMS core module
use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
$sbeams = SBEAMS::Connection->new();

use SBEAMS::ProteinStructure;
use SBEAMS::ProteinStructure::Settings;
use SBEAMS::ProteinStructure::Tables;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::ProteinStructure;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);

use CGI;
$q = CGI->new();


###############################################################################
# Set program name and usage banner for command like use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS]
Options:
  --verbose n         Set verbosity level.  default is 0
  --quiet             Set flag to print nothing at all except errors
  --debug n           Set debug flag
  --testonly          If set, rows in the database are not changed or added
  --delete_existing   Delete the existing data before trying to load
  --domain_match_type Update the data with information in the file
  --source_file       Name of the source file from which data are loaded
  --source_type       Type of source file from which to load.
                      Current these are: NgAnnot

 e.g.:  $PROG_NAME --update --source_file inputfile.txt --source_type NgAnnot

EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
        "delete_existing","update_existing","biosequence_set_id:i",
        "domain_match_type:s","source_type:s","source_file:s",
  )) {
  print "$USAGE";
  exit;
}

$VERBOSE = $OPTIONS{"verbose"} || 0;
$QUIET = $OPTIONS{"quiet"} || 0;
$DEBUG = $OPTIONS{"debug"} || 0;
$TESTONLY = $OPTIONS{"testonly"} || 0;
if ($DEBUG) {
  print "Options settings:\n";
  print "  VERBOSE = $VERBOSE\n";
  print "  QUIET = $QUIET\n";
  print "  DEBUG = $DEBUG\n";
  print "  DBVERSION = $DBVERSION\n";
  print "  TESTONLY = $TESTONLY\n";
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
    work_group=>'ProteinStructure_admin',
  ));


  $sbeams->printPageHeader() unless ($QUIET);
  handleRequest();
  $sbeams->printPageFooter() unless ($QUIET);


} # end main



###############################################################################
# handleRequest
###############################################################################
sub handleRequest {
  my %args = @_;

  #### Set the command-line options
  my $delete_existing = $OPTIONS{"delete_existing"} || 0;
  my $update_existing = $OPTIONS{"update_existing"} || 0;

  my $source_file = $OPTIONS{"source_file"} || '';
  my $source_type = $OPTIONS{"source_type"} || '';
  my $domain_match_type = $OPTIONS{"domain_match_type"} || '';
  my $biosequence_set_id = $OPTIONS{"biosequence_set_id"} || '';

  #### Verify required parameters
  unless ($source_type && $source_file) {
    print "ERROR: You must specify a source_type and source_file\n\n";
    print "$USAGE";
    exit;
  }
  unless ($biosequence_set_id) {
    print "ERROR: You must specify a biosequence_set_id\n\n";
    print "$USAGE";
    exit;
  }


  #### If there are any parameters left, complain and print usage
  if ($ARGV[0]){
    print "ERROR: Unresolved command line parameter '$ARGV[0]'.\n";
    print "$USAGE";
    exit;
  }

  #### Print out the header
  unless ($QUIET) {
    $sbeams->printUserContext();
    print "\n";
  }

  #### Verify the source_file
  unless ( -e "$source_file" ) {
    print "ERROR: Unable to access source_file '$source_file'\n\n";
    return;
  }


  #### Verify the source_type and set match_source and match_type
  my $domain_match_source_id = 0;
  my $domain_match_type_id = 0;
  if ($source_type eq 'NgAnnot') {
    $domain_match_source_id = 4;
    $domain_match_type_id = 7;
  } else {
    print "ERROR: Unrecognized source type '$source_type'\n\n";
    return;
  }


  #### define a data has to preload all data into
  my %data;


  #### Open the source file
  unless (open(INFILE,"$source_file")) {
    print "ERROR: Unable to open for reading source_file '$source_file'\n\n";
    return;
  }


  #### If this is NgAnnot format:
  if ($source_type eq 'NgAnnot') {
    my $line;
    while ($line = <INFILE>) {
      $line =~ s/[\r\n]//g;

      my @columns = split(/\t/,$line);
      my ($biosequence_name,$chromosome,$biosequence_length,
	  $start_position,$end_position,$gene_symbol,$annotation) =
	@columns;

      #### Verify ORF name
      if (length($biosequence_name) != 9) {
  	print "  ERROR: biosequence_name '$biosequence_name' out of bounds.\n";
	next;
      }

      #### Verify the number of columns
      if (scalar(@columns) != 7) {
	print "ERROR: Insufficient columns for:\n  $line\n";
	next;
      }

      #### See if this is useful annotation
      if ($gene_symbol =~ /^\s*CHP$/i || $gene_symbol =~ /^HP$/i) {
	next if ($annotation eq '-' ||
		 $annotation =~ /^conserve[d]* hypo\w+cal/i ||
		 $annotation =~ /^hypothetical protein/i
        );
	print "ERROR: $gene_symbol suggests ignore, but annotation not?\n  ".
	  "$line\n";
      }
      if ($annotation eq '-') {
	next if ($gene_symbol eq '-');
	print "ERROR: $annotation suggests ignore, but gene_symbol not?\n  ".
	  "$line\n";
      }

      if (exists($data{$biosequence_name})) {
	print "ERROR: Duplicate biosequence_name '$biosequence_name'\n";
	next;
      }

      #### Strip enclosing "" marks
      if ($annotation =~ /^\"(.+)\"$/) {
	$annotation = $1;
      }
      if ($gene_symbol =~ /^\"(.+)\"$/) {
	$gene_symbol = $1;
      }

      #### Strip out EC information
      my $full_gene_name = $annotation;
      my ($EC_number,$comment);
      if ($annotation =~ /(.+)\s*\(EC ([\d\.\-]+)\)\s*(.*)/) {
	$full_gene_name = $1;
	$EC_number = $2;
	my $tmp = $3;
	$comment = "VNg Comment: $tmp" if ($tmp =~ /\S/);
      }

      #### NULL the -'s
      $full_gene_name = undef if ($annotation eq '-');
      $gene_symbol = undef if ($gene_symbol eq '-');


      #### Store the data in our hash
      $data{$biosequence_name} = {
        chromosome => $chromosome,
        biosequence_length => $biosequence_length,
        start_position => $start_position,
        end_position => $end_position,
        gene_symbol => $gene_symbol,
        full_gene_name => $full_gene_name,
        annotation => $annotation,
        EC_number => $EC_number,
        comment => $comment,
      };

    }
  }


  #### Get all the biosequence_id's
  my $sql = qq~
    SELECT biosequence_name,biosequence_id
      FROM $TBPS_BIOSEQUENCE
     WHERE biosequence_set_id = '$biosequence_set_id'
  ~;
  my %biosequence_ids = $sbeams->selectTwoColumnHash($sql);


  #### Get all the biosequence_annotation_id's
  $sql = qq~
    SELECT BSA.biosequence_id,BSA.biosequence_annotation_id
      FROM $TBPS_BIOSEQUENCE_ANNOTATION BSA
      JOIN $TBPS_BIOSEQUENCE BS ON ( BSA.biosequence_id = BS.biosequence_id )
     WHERE BS.biosequence_set_id = '$biosequence_set_id'
  ~;
  my %biosequence_annotation_ids = $sbeams->selectTwoColumnHash($sql);


  #### Store the information
  my $counter = 0;
  foreach my $element (keys %data) {

    #### Verify that we can get a biosequence_id
    unless (exists($biosequence_ids{$element})) {
      print "ERROR: biosequence_name '$element' does not exist in the ".
	"database!\n";
      next;
    }

    #### Check to see if there's already an annotation record
    if (exists($biosequence_annotation_ids{$biosequence_ids{$element}})) {
      print "WARNING: There already exists an annotation for '$element'\n";

    } else {
      #### INSERT the annotation record
      my %rowdata;
      $rowdata{biosequence_id} = $biosequence_ids{$element};
      $rowdata{gene_symbol} = $data{$element}->{gene_symbol}
  	if (defined($data{$element}->{gene_symbol}));
      $rowdata{full_gene_name} = $data{$element}->{full_gene_name}
  	if (defined($data{$element}->{full_gene_name}));
      $rowdata{EC_numbers} = $data{$element}->{EC_number}
  	if (defined($data{$element}->{EC_number}));
      $rowdata{comment} = $data{$element}->{comment}
  	if (defined($data{$element}->{comment}));

      my $result = $sbeams->updateOrInsertRow(
  	insert=>1,
  	table_name=>$TBPS_BIOSEQUENCE_ANNOTATION,
  	rowdata_ref=>\%rowdata,
  	verbose=>$VERBOSE,
  	testonly=>$TESTONLY,
      );
    }


    #### See if there's a domain match record
    $sql = qq~
      SELECT domain_match_id
	FROM $TBPS_DOMAIN_MATCH
       WHERE domain_match_type_id = '$domain_match_type_id'
         AND biosequence_id = '$biosequence_ids{$element}'
    ~;
    my @domain_match_ids = $sbeams->selectOneColumn($sql);

    if (@domain_match_ids) {
      $sql = "DELETE $TBPS_DOMAIN_MATCH WHERE domain_match_id IN ( ".
	join(',',@domain_match_ids)." )";
      $sbeams->executeSQL($sql);
    }


    #### INSERT the domain_match record
    my %rowdata = ();
    $rowdata{biosequence_id} = $biosequence_ids{$element};
    $rowdata{match_name} = $data{$element}->{gene_symbol}
      if (defined($data{$element}->{gene_symbol}));
    $rowdata{match_annotation} = $data{$element}->{annotation}
      if (defined($data{$element}->{annotation}));
    $rowdata{domain_match_source_id} = $domain_match_source_id;
    $rowdata{domain_match_type_id} = $domain_match_type_id;

    my $result = $sbeams->updateOrInsertRow(
      insert=>1,
      table_name=>$TBPS_DOMAIN_MATCH,
      rowdata_ref=>\%rowdata,
      verbose=>$VERBOSE,
      testonly=>$TESTONLY,
    );


    #### INSERT the DOMAIN data
    if (defined($data{$element}->{EC_number}) && defined($data{$element}->{gene_symbol})) {

      #### See if there's a domain record
      $sql = qq~
  	SELECT domain_id
  	  FROM $TBPS_DOMAIN
  	 WHERE domain_match_type_id = '$domain_match_type_id'
           AND domain_name = '$data{$element}->{gene_symbol}'
      ~;
      my ($domain_id) = $sbeams->selectOneColumn($sql);

      my $insert = 1;
      my $update = 0;
      if ($domain_id) {
  	$update = 1;
	$insert = 0;
      }

      %rowdata = ();
      $rowdata{domain_match_type_id} = $domain_match_type_id;
      $rowdata{domain_name} = $data{$element}->{gene_symbol};
      $rowdata{EC_numbers} = $data{$element}->{EC_number};

      $result = $sbeams->updateOrInsertRow(
  	insert=>$insert,
        update=>$update,
  	table_name=>$TBPS_DOMAIN,
  	rowdata_ref=>\%rowdata,
        PK=>'domain_id',
        PK_value=>$domain_id,
  	verbose=>$VERBOSE,
  	testonly=>$TESTONLY,
      );
    }


    #### Update row counter information
    $counter++;
    print "$counter..." if ($counter % 100 == 0);
  }


  print "\n";


} # end handleRequest
