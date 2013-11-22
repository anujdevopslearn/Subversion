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
use Data::Dumper;
use lib "$FindBin::Bin/../../lib/perl";
use vars qw ($sbeams $sbeamsMOD $q $dbh $current_contact_id $current_username
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
             $current_work_group_id $current_work_group_name
             $current_project_id $current_project_name
             $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
             $PK_COLUMN_NAME @MENU_OPTIONS);
use DBI;
#use CGI;
use CGI::Carp qw(fatalsToBrowser croak);

use SBEAMS::Connection qw($q $log);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TableInfo;
#$q = new CGI;
$sbeams = new SBEAMS::Connection;

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Tables;
use SBEAMS::PeptideAtlas::TableInfo;

use SBEAMS::Proteomics;
use SBEAMS::Proteomics::Settings;
use SBEAMS::Proteomics::Tables;
use SBEAMS::Proteomics::TableInfo;
$sbeamsMOD = new SBEAMS::Proteomics;

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
    permitted_work_groups_ref=>['Proteomics_user','Proteomics_admin',
      'Proteomics_readonly','Admin'],
    #connect_read_only=>1,
    #allow_anonymous_access=>1,
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
	

  #### For search_hit_annotations, set the source to be "by hand" unless
  #### there's already a value
  if ($TABLE_NAME eq "PR_search_hit_annotation") {
    $query_parameters_ref->{annotation_source_id} = 1
      unless ($query_parameters_ref->{annotation_source_id});
  }


  #### For gradient_programs, set a default table header
  if ($TABLE_NAME eq "PR_gradient_program") {
    $query_parameters_ref->{gradient_program_table} =
      "Time  Buf A %  Buf B %  Flow mL/min\n".
      "----  -------  -------  -----------\n"
      unless ($query_parameters_ref->{gradient_program_table});
  }


  #### If this is publication and there is a PubMedID and there is
  #### not a title, try to fetch the data from PubMed
  if ($TABLE_NAME eq "PR_publication") {
    if ($query_parameters_ref->{pubmed_ID} &&
        !$query_parameters_ref->{publication_name}) {
      use SBEAMS::Connection::PubMedFetcher;
      my $PubMedFetcher = new SBEAMS::Connection::PubMedFetcher;
      my $pubmed_info = $PubMedFetcher->getArticleInfo(
        PubMedID=>$query_parameters_ref->{pubmed_ID});
      if ($pubmed_info) {
        my %keymap = (
		      MedlineTA=>'journal_name',
		      AuthorList=>'author_list',
		      Volume=>'volume_number',
		      Issue=>'issue_number',
		      AbstractText=>'abstract',
		      ArticleTitle=>'title',
		      PublishedYear=>'published_year',
		      MedlinePgn=>'page_numbers',
		      PublicationName=>'publication_name',
		     );
        while (my ($key,$value) = each %{$pubmed_info}) {
          #print "$key=$value=<BR>\n";
	  if ($keymap{$key}) {
            $query_parameters_ref->{$keymap{$key}} = $value;
	    #print "Mapped to $keymap{$key}<BR>\n";
	  }
        }
      }
    }
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


  #### If table PR_gradient_program
  if ($TABLE_NAME eq "PR_gradient_program") {
    my $gradient_program_id = $parameters{gradient_program_id} || return;
    my $sql = qq~
	SELECT * FROM $TBPR_GRADIENT_DELTA
	 WHERE gradient_program_id = '$gradient_program_id'
	 ORDER BY gradient_delta_time
    ~;
    print "<BR><TR><TD COLSPAN=3>\n";
    $sbeams->displayQueryResult(sql_query=>$sql);
    print "</TD></TR><BR><BR>\n";

    return;
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

  # Define a few variables for project permission checking
  my $errstr = '';  # Error string accumulator
  my @stdparams = ( action => $parameters{action},
                     tname => $TABLE_NAME );

  if ( $parameters{project_id} ) { # General mechanism for tables w/ project_id
    my $errstr = checkProjectPermission( param_ref => $query_parameters_ref,
                                         tname => $TABLE_NAME,
                                         dbtname => $DB_TABLE_NAME );
    return ( $errstr ) if $errstr;
    
  } elsif ( $TABLE_NAME eq "PR_proteomics_experiment" ) {

    if ( !$parameters{project_id} ) { # Must have an project_id
      $errstr = 'Error: project_id not defined'
    } else {
      $errstr = checkPermission( fkey => 'project_id',
                                 fval => $parameters{project_id},
                                 pval => $parameters{experiment_id},
                                 @stdparams );
    }

  } elsif ( $TABLE_NAME eq 'PR_biosequence_set' ) {

    if ( !$parameters{project_id} ) { # Must have an project_id
      $errstr = 'Error: project_id not defined'
    } else {
      $errstr = checkPermission( fkey => 'project_id',
                                 fval => $parameters{project_id},
                                 pval => $parameters{biosequence_set_id},
                                 @stdparams );
    }

  } elsif ( $TABLE_NAME eq 'PR_gradient_program' ) {

    if ( !$parameters{project_id} ) { # Must have an project_id
      $errstr = 'Error: project_id not defined'
    } else {
      $errstr = checkPermission( fkey => 'project_id',
                                 fval => $parameters{project_id},
                                 pval => $parameters{gradient_program_id},
                                 @stdparams );
    }


  } elsif ( $TABLE_NAME eq 'APD_peptide_summary' ) {

    if ( !$parameters{project_id} ) { # Must have an project_id
      $errstr = 'Error: project_id not defined'
    } else {
      $errstr = checkPermission( fkey => 'project_id',
                                 fval => $parameters{project_id},
                                 pval => $parameters{peptide_summary_id},
                                 @stdparams );
    }

  } elsif ( $TABLE_NAME eq 'PR_fraction' ) {

    if ( !$parameters{experiment_id} ) { # Must have an experiment_id
      $errstr = 'Error: project_id not defined'
    } else {
      $errstr = checkPermission( fkey => 'proteomics_experiment_id',
                                 fval => $parameters{experiment_id},
                                 pval => $parameters{fraction_id},
                                 @stdparams );
    }


  } elsif ( $TABLE_NAME eq 'PR_search_batch' ) {

    if ( !$parameters{experiment_id} ) { # Must have an experiment_id
      $errstr = 'Error: project_id not defined'
    } else {
      $errstr = checkPermission( fkey => 'proteomics_experiment_id',
                                 fval => $parameters{experiment_id},
                                 pval => $parameters{search_batch_id},
                                 @stdparams );
    }

  } elsif ( $TABLE_NAME eq 'PR_search_hit_annotation' ) {

    if ( !$parameters{search_hit_id} ) { # Must have an search hit id
      $errstr = 'Error: Experiment id not defined';
    } else {
      $errstr = checkPermission( fkey => 'search_hit_id',
                                 fval => $parameters{search_hit_id},
                                 pval => $parameters{search_hit_annotation_id},
                                 @stdparams );
    }

  }elsif ( $TABLE_NAME eq 'PR_proteomics_sample' ) {

    if ( !$parameters{project_id} ) { # Must have an project_id
      $errstr = 'Error: project_id not defined'
    } else {
    
      $errstr = checkPermission( fkey => 'project_id',
                                 fval => $parameters{project_id},
                                 pval => $parameters{proteomics_sample_id},
                                 @stdparams );
       
    } 
  
  
  }elsif ($TABLE_NAME eq "XXXX") {
    
    return "An error of some sort $parameters{something} invalid";

  } else {

    #### Otherwise, no special processing, so just return empty string
    return '';
  }

  return $errstr;

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


  #### If table XXXX
  if ($TABLE_NAME eq "XXXX") {
    return "An error of some sort $parameters{something} invalid";
  }


  #### If table PR_gradient_program
  if ($TABLE_NAME eq "PR_gradient_program") {
    #return unless ($parameters{gradient_program_table});
    my @rows = split(/[\r\n]+/,$parameters{gradient_program_table});
    my $row_index = 1;
    my @data_rows = ();

    #### Loop over all the data rows
    foreach my $row (@rows) {
      #### Ignore if all spaces or empty
      next if ($row =~ /^\s*$/);

      #### If it contains all numbers, that's good
      if ($row =~ /^[\d\s\.e]+$/) {
	#### Strip leading and trailing space
	$row =~ s/^\s+//;
	$row =~ s/\s+$//;

	#### Separate the columns
	my @columns = split(/\s+/,$row);

	#### If there are three or four columns, save the values
	if (scalar(@columns) == 3 || scalar(@columns == 4)) {
	  push(@data_rows,\@columns);

	#### Else complain about a bad number of columns
	} else {
	  print "Skipping Gradient Program Deltas row $row_index with ".
	    "incorrect number of columns: '$row'<BR>\n";
	}

      #### Else tell the user that we're skipping a non-numerical row
      #### (either a header line or perhaps a bad line
      } else {
	print "Skipping non-numerical Gradient Program Deltas row ".
	  "$row_index: '$row'<BR>\n"
	  unless ($row =~ /^Time  Buf A/ || $row =~ /^----  -----/);
      }

      #### Increment the row counter
      $row_index++;

    } # end foreach $row


    #### Store the results to the deltas table
    my @child_data_columns = qw(gradient_delta_time buffer_A_setting_percent
      buffer_B_setting_percent flow_rate);
    updateChildTable(
      parent_table_name => $TABLE_NAME,
      parent_pk_column_name => $PK_COLUMN_NAME,
      parent_pk_value => $parameters{$PK_COLUMN_NAME},
      child_table_name => 'PR_gradient_delta',
      child_pk_column_name => 'gradient_delta_id',
      child_data_columns => \@child_data_columns,
      child_data_values => \@data_rows,
    );


    return;

  } # end if $TABLE_NAME
 


  #### Otherwise, no special processing, so just return undef
  return;

} # end postUpdateOrInsertHook



