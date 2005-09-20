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
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
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
use Spreadsheet::ParseExcel::Simple;
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TableInfo;

$sbeams = new SBEAMS::Connection;

use SBEAMS::Genotyping;
use SBEAMS::Genotyping::Settings;
use SBEAMS::Genotyping::Tables;
use SBEAMS::Genotyping::TableInfo;
$sbeamsMOD = new SBEAMS::Genotyping;

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
  } elsif ($parameters{action} eq 'SAVE TEMPLATE') { saveTemplate();
  } elsif ($parameters{action} eq 'SET FIELDS TO THIS TEMPLATE') {
    printEntryForm();
  } elsif ($parameters{action} eq 'DELETE THIS TEMPLATE') {
    deleteTemplate(
      selected_template => $parameters{selected_template},
      program_file_name => $PROGRAM_FILE_NAME,
    );
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

  #### If table GT_experiment
  if ($TABLE_NAME eq "GT_experiment") {
    $query_parameters_ref->{want_validation} = 'Y'
      unless ($query_parameters_ref->{want_validation});
    $query_parameters_ref->{want_pooling} = 'N'
      unless ($query_parameters_ref->{want_pooling});
    $query_parameters_ref->{want_typing} = 'Y'
      unless ($query_parameters_ref->{want_typing});
    $query_parameters_ref->{is_multiplexing_allowed} = 'Y'
      unless ($query_parameters_ref->{is_multiplexing_allowed});
    $query_parameters_ref->{dna_type} = 'Genomic'
     unless ($query_parameters_ref->{dna_type});
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


  if ( $parameters{project_id} ) { # General mechanism for tables w/ project_id

    my $errstr = checkProjectPermission( param_ref => $query_parameters_ref,
                                         tname => $TABLE_NAME,
                                         dbtname => $DB_TABLE_NAME );
    return ( $errstr ) if $errstr;

  } elsif ($TABLE_NAME eq "XXXX") {

    return "An error of some sort $parameters{something} invalid";

  }

  #### Otherwise, no special processing, so just return empty string
  return '';

} # end preUpdateDataCheck


###############################################################################
# postUpdateOrInsertHook
#
# This is a hook to do some processing after the record has been updated
# or inserted.
###############################################################################
sub postUpdateOrInsertHook {
  my %args = @_;

  my $query_parameters_ref = $args{'parameters_ref'};
  my %parameters = %{$query_parameters_ref};
  my $pk_value = $args{'pk_value'};

  foreach my $key (keys %parameters) {
    print "$key: $parameters{$key}\n";
  }


  #### If table XXXX
  if ($TABLE_NAME eq "XXXX") {
    return "An error of some sort $parameters{something} invalid";
  }


  #### If table GT_experiment
  if ($TABLE_NAME eq "GT_experiment") {

    #### Add or update a status record

    #### Is there already a status record?
    my $sql = qq~
      SELECT experiment_status_id FROM $TBGT_EXPERIMENT_STATUS
      WHERE experiment_id = '$pk_value'
    ~;
    my @rows = $sbeams->selectOneColumn($sql);

    my $experiment_status_id;
    my $do_insert = 0;
    my $do_update = 0;
    my %rowdata;

    if (scalar(@rows) > 1) {
      die("ERROR: Too many experiment status records!");
    } elsif (scalar(@rows) == 1) {
      $experiment_status_id = $rows[0];
      $do_update = 1;
      #### Actually, nothing to do, no auto update of record at this time
    } else {
      $do_insert = 1;
      $rowdata{experiment_id} = $pk_value;
      if ($parameters{'samples_file'} || $parameters{'assays_file'}) {
        $rowdata{file_formats_approved} = 'Pending';
      }
      $rowdata{experiment_status_state_id} = 1;
      $rowdata{initial_request_date} = 'CURRENT_TIMESTAMP';
      $sbeams->insert_update_row(
        insert=>$do_insert,
        table_name=>$TBGT_EXPERIMENT_STATUS,
        rowdata_ref=>\%rowdata,
        PK=>'experiment_status_id',
	add_audit_parameters=>1,
      );
    }


    #### Send an email to Marta
    my $mailprog = "/usr/lib/sendmail";
    my $recipient_name = "Genotyping_admin Contact";
    my $recipient = "kdeutsch\@systemsbiology.org";
    my $cc_name = "SBEAMS";
    my $cc = "edeutsch\@systemsbiology.org";

    my $apply_action = $q->param('apply_action') || $parameters{'action'};
    my $subdir = $sbeams->getSBEAMS_SUBDIR();

    my $sql = qq~
      SELECT UL.username+' - '+P.name FROM $TB_PROJECT P
   LEFT JOIN $TB_USER_LOGIN UL ON ( P.PI_contact_id=UL.contact_id )
       WHERE P.project_id = '$parameters{'project_id'}'
    ~;
    my @rows = $sbeams->selectOneColumn($sql);
    my $proj_name = $rows[0];

    $sql = qq~
      SELECT last_name+', '+first_name+' ('+organization+')'
        FROM $TB_CONTACT C
        JOIN $TB_ORGANIZATION O ON ( C.organization_id = O.organization_id )
       WHERE contact_id = '$parameters{'contact_id'}'
    ~;
    @rows = $sbeams->selectOneColumn($sql);
    my $contact_name = $rows[0];

    open (MAIL, "|$mailprog $recipient,$cc") || croak "Can't open $mailprog!\n";
    print MAIL "From: SBEAMS-Genotyping <kdeutsch\@systemsbiology.org>\n";
    print MAIL "To: $recipient_name <$recipient>\n";
#    print MAIL "Cc: $cc_name <$cc>\n";
    print MAIL "Reply-to: $current_username <${current_username}\@systemsbiology.org>\n";
    print MAIL "Subject: Genotyping request submission\n\n";
    print MAIL "An $apply_action of a genotyping request was just executed in SBEAMS by ${current_username}.\n\n";
    print MAIL "Project: $proj_name\n";
    print MAIL "Contact: $contact_name\n";
    print MAIL "Experiment Name: $parameters{'experiment_name'}\n";
    print MAIL "Samples File: $parameters{'samples_file'}\n";
    print MAIL "Assays File: $parameters{'assays_file'}\n\n";

    print MAIL "To see the request view this link:\n\n";
    print MAIL "$SERVER_BASE_DIR$CGI_BASE_DIR/${subdir}/ManageTable.cgi?TABLE_NAME=GT_experiment&experiment_id=$parameters{'experiment_id'}\n\n";
    close (MAIL);

    print "<BR><BR>An email was just sent to the Genotyping_admin Group informing them of your request.<BR>\n";


    #### Process the Samples file
    if ($parameters{'samples_file'}) {
      my $samples_file = "GT_experiment/".
	"$query_parameters_ref->{experiment_id}".
	  "_samples_file.dat";
      processSamples(
        samples=>$samples_file,
	parameters_ref=>$query_parameters_ref
      );
    }

    #### Process the Assays file
    if ($parameters{'assays_file'}) {
      my $assay_file = "GT_experiment/".
        "$query_parameters_ref->{experiment_id}".
        "_assays_file.dat";
      processAssays(
        assays=>$assay_file,
        parameters_ref=>$query_parameters_ref
      );
    }

    return;

  } # end if $TABLE_NAME='GT_experiment'

  #### Otherwise, no special processing, so just return undef
  return;

} # end postUpdateOrInsertHook


###############################################################################
# processSamples
#
# Locate, parse, and load the Sample Excel file
###############################################################################
sub processSamples {
  my %args = @_;

  my $query_parameters_ref = $args{'parameters_ref'};
  my %parameters = %{$query_parameters_ref};

  #### Get the predicted location of the samples file
  my $samples = $args{'samples'};


  #### Read in the samples excel file and create hash out of its contents
  my $xls = Spreadsheet::ParseExcel::Simple->read("$UPLOAD_DIR/$samples");
  die "Count not parse plate file $UPLOAD_DIR/$samples $!\n" unless $xls;

  my $sheet_number = 0;
  my (@well_data, @sample_data, @conc_data, @vol_data, @stock_data);
  my (@dilution_data, @data_rows);
  my $plate_code;

  #### Define the well position array
  my @let = qw (A B C D E F G H);
  for (my $letter = 0; $letter <= 7; $letter++) {
    for (my $i = 1; $i <= 12; $i++) {
      push @well_data, "$let[$letter]"."$i";
    }
  }

  foreach my $sheet ($xls->sheets) {

    #### All sample information should be on the first sheet
    if ($sheet_number > 1) {
      print "Too many pages in this sample file\n";
      exit;
    }

    #### Read in each set of 96 well plates
    while ($sheet->has_data) {
      my @row = $sheet->next_row;
      if (defined $row[1]) {
        if ($row[1] ne '') {
          $plate_code = $row[1];

          #### Read in rows A->H (absolute rows 2 -> 9)
          for (my $row_num = 2; $row_num <= 9; $row_num++) {
            @row = $sheet->next_row;
            push @sample_data, @row[4 .. 15];
            push @conc_data, @row[18 .. 29];
            push @vol_data, @row[32 .. 43];
            push @stock_data, @row[46 .. 57];
            push @dilution_data, @row[60 .. 71];
          }
         #### Create the data_rows array of all information
         for (my $i = 0; $i <= 95; $i++) {
           my @tmp_row;
           push (@tmp_row,$plate_code,$well_data[$i],$sample_data[$i],
                 $conc_data[$i],$vol_data[$i],$stock_data[$i],
                 $dilution_data[$i]);
	   push (@data_rows,\@tmp_row);
         }

          @sample_data=();
          @conc_data=();
          @vol_data=();
          @stock_data=();
          @dilution_data=();
        }
      }
    }
    $sheet_number ++;
  }

  #### Store the results to the sample table
  my @child_data_columns = qw(plate_id well_position sample_name
    dna_concentration initial_well_volume stock_dna_solvent dna_dilution_solvent);
  updateChildTable(
    parent_table_name => $TABLE_NAME,
    parent_pk_column_name => $PK_COLUMN_NAME,
    parent_pk_value => $parameters{$PK_COLUMN_NAME},
    child_table_name => 'GT_sample',
    child_pk_column_name => 'sample_id',
    child_data_columns => \@child_data_columns,
    child_data_values => \@data_rows,
  );

} # end processSamples

###############################################################################
# processAssays
#
# Locate, parse, and load the Assays file
###############################################################################
sub processAssays {
  my %args = @_;

  my $query_parameters_ref = $args{'parameters_ref'};
  my %parameters = %{$query_parameters_ref};

  #### Get the predicted location of the samples file
  my $assay_file = $args{'assays'};

  #### Read in the requested assay file and create hash out of its contents
  open (ASSAYFILE,"$UPLOAD_DIR/$assay_file") ||
    die "Cannot open $UPLOAD_DIR/$assay_file";

  my $row_index = 1;
  my @data_rows = ();
  my @columns = ();
  while (<ASSAYFILE>) {
    #### Ignore if it's the column header line
    next if $_ =~ /^Name/;

    #### Strip leading and trailing space
    $_ =~ s/^\s+//;
    $_ =~ s/\s+$//;


    #### Separate the columns
    @columns = split(/\t/,$_);

    #### If there are 2 columns, save the values
    if (scalar(@columns) == 2) {
      push(@data_rows,\@columns);

    #### Else complain about a bad number of columns
    } else {
      print "Skipping assays file row $row_index with ".
        "incorrect number of columns: '$_'<BR>\n";
    }

    #### Increment the row counter
    $row_index++;

  } # end while <ASSAYFILE>

  #### Store the results to the requested_genotyping_assay table
  my @child_data_columns = qw(requested_assay_name requested_assay_sequence);
  updateChildTable(
    parent_table_name => $TABLE_NAME,
    parent_pk_column_name => $PK_COLUMN_NAME,
    parent_pk_value => $parameters{$PK_COLUMN_NAME},
    child_table_name => 'GT_requested_genotyping_assay',
    child_pk_column_name => 'requested_genotyping_assay_id',
    child_data_columns => \@child_data_columns,
    child_data_values => \@data_rows,
  );

} # end processAssays
