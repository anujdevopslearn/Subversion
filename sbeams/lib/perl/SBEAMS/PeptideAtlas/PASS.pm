package SBEAMS::PeptideAtlas::PASS;

###############################################################################
# Class       : SBEAMS::PeptideAtlas::PASS
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
#
=head1 SBEAMS::PeptideAtlas::PASS

=head2 SYNOPSIS

  SBEAMS::PeptideAtlas::PASS

=head2 DESCRIPTION

This is part of SBEAMS::PeptideAtlas which handles the interface
with PASS, the PeptideAtlas Submission System

=cut
#
###############################################################################

use strict;
$|++;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
require Exporter;
@ISA = qw();
$VERSION = q[$Id$];
@EXPORT_OK = qw();

use SBEAMS::Connection qw($q $log);
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::Settings;
use SBEAMS::Proteomics::Tables;
use SBEAMS::PeptideAtlas::Tables;
use CGI qw(:standard);

my $sbeams;
our $summary;

my @datasetTypes = ( 'MSMS' => 'MS/MS dataset',
		     'SRM' => 'SRM dataset',
		     'MS1' => 'MS1 dataset',
                     'SWATH' => 'SWATH MS dataset',
                     'XlinkMS' => 'Cross-linking MS dataset',
		     'QC' => 'Ongoing QC dataset',
		     'Other' => 'Other',
		     );


###############################################################################
# Constructor
###############################################################################
sub new {
  my $this = shift;
  my $class = ref($this) || $this;
  my $self = {};
  bless $self, $class;
  $sbeams = $self->getSBEAMS();
  return($self);
} # end new


###############################################################################
# getSBEAMS: Provide the main SBEAMS object
#   Copied from AtlasBuild.pm
###############################################################################
sub getSBEAMS {
  my $self = shift;
  return $sbeams || SBEAMS::Connection->new();
} # end getSBEAMS


#######################################################################
# displayErrors
#######################################################################
sub displayErrors {
  my $self = shift;
  my %args = @_;
  my $SUB_NAME = 'displayErrors';

  #### Decode the argument list
  my $errors = $args{'errors'};

  if (defined($errors) && $errors =~ /ARRAY/) {
    print "<HR>\n";
    print "<TABLE cellpadding=\"5\"><TR><TD bgcolor=\"#ff9999\">";
    foreach my $error ( @{$errors} ) {
      print "<LI>$error\n";
    }
    print "</TD></TR></TABLE>\n";
  }

}


#######################################################################
# validateDatasetAnnotations
#######################################################################
sub validateDatasetAnnotations {
  my $self = shift;
  my %args = @_;
  my $SUB_NAME = 'validateDatasetAnnotations';

  #### Decode the argument list
  my $formParameters = $args{'formParameters'} || die "[$SUB_NAME] ERROR: formParameters not passed";

  my $response;
  my $test;
  $response->{result} = 'Success';

  $test = $formParameters->{datasetType};
  my $result = 0;
  for (my $i=0; $i < scalar(@datasetTypes); $i+=2) {
    my ($key,$label) = @datasetTypes[$i..$i+1];
    $result = 1 if ($test eq $key);
  }
  unless ($result) {
    $response->{result} = 'Failed';
    push(@{$response->{errors}},"Dataset type is not a legal option");
  }


  $test = $formParameters->{datasetTag};
  unless (defined($test) && $test =~ /^[A-Za-z0-9\_\-]+$/ && length($test) > 5 && length($test) <= 20) {
    $response->{result} = 'Failed';
    push(@{$response->{errors}},"Dataset Tag must be an alphanumeric string with length more than 5 up to 20 (no spaces or strange characaters)");
  }

  $test = $formParameters->{datasetTitle};
  unless (defined($test) && length($test) > 20 && length($test) <= 200) {
    $response->{result} = 'Failed';
    push(@{$response->{errors}},"Dataset Title must be a string with length more than 20 up to 200");
  }

  $test = $formParameters->{publicReleaseDate};
  unless (defined($test) && $test =~ /^(\d\d\d\d)\-(\d\d)\-(\d\d)$/ && $1>=2000 && $2>0 && $2<=12 && $3>0 && $3<=31) {
    unless (defined($test) && $test =~ /^(\d\d\d\d)\-(\d\d)\-(\d\d) (\d\d):(\d\d):(\d\d)$/ && $1>=2000 && $2>0 && $2<=12 && $3>0 && $3<=31 && $4>=0 && $4<24 && $5>=0 && $5<60 && $6>=0 && $6<60) {
      $response->{result} = 'Failed';
      push(@{$response->{errors}},"Public release data must be a valid date of the form YYYY-MM-DD like 2011-10-25 (followed by optional HH:MM:SS)");
    }
  }

  $test = $formParameters->{contributors};
  unless (defined($test) && length($test) > 6 && length($test) <= 10000) {
    $response->{result} = 'Failed';
    push(@{$response->{errors}},"Contributors must be a string with length more than 6 up to 10000");
  }

  $test = $formParameters->{publication};
  unless (defined($test) && length($test) > 5 && length($test) <= 1000) {
    $response->{result} = 'Failed';
    push(@{$response->{errors}},"Publication must be a string with length more than 5 up to 1000");
  }

  $test = $formParameters->{instruments};
  unless (defined($test) && length($test) > 5 && length($test) <= 1000) {
    $response->{result} = 'Failed';
    push(@{$response->{errors}},"Instruments must be a string with length more than 5 up to 1000");
  }

  $test = $formParameters->{species};
  unless (defined($test) && length($test) > 3 && length($test) <= 1000) {
    $response->{result} = 'Failed';
    push(@{$response->{errors}},"Species must be a string with length more than 3 up to 1000");
  }

  $test = $formParameters->{massModifications};
  unless (defined($test) && length($test) > 3 && length($test) <= 1000) {
    $response->{result} = 'Failed';
    push(@{$response->{errors}},"Mass modifications must be a string with length more than 3 up to 1000");
  }

  #### Email Eric about the submission problem
  if (defined $response->{errors}) {
    my (@toRecipients,@ccRecipients,@bccRecipients);
    @toRecipients = (
      'Eric Deutsch','eric.deutsch@systemsbiology.org',
    );
    @ccRecipients = ();
    @bccRecipients = ();
    my $adminMessage = qq~A new PASS submission has been having difficulty:\n
  Submitter: $formParameters->{firstName} $formParameters->{lastName} <$formParameters->{emailAddress}>
  ~;
    $adminMessage .= join("\n",@{$response->{errors}});
    SBEAMS::Connection::Utilities::sendEmail(
      toRecipients=>\@toRecipients,
      ccRecipients=>\@ccRecipients,
      bccRecipients=>\@bccRecipients,
      subject=>"PeptideAtlas dataset submission difficulty",
      message=>"$adminMessage\n\n",
    );
  }

  return $response;

}


#######################################################################
# getPASSSummary
#######################################################################
sub getPASSSummary {
  my $self = shift;
  my %args = @_;
  my $SUB_NAME = 'getPASSSummary';

  my $response;
  $response->{result} = 'Success';

  my $sql = qq~
    SELECT datasetIdentifier,submitter_id,datasetType,datasetPassword,datasetTag,datasetTitle,publicReleaseDate,finalizedDate
      FROM $TBAT_PASS_DATASET
     ORDER BY datasetIdentifier
  ~;
  my @rows = $sbeams->selectSeveralColumns($sql);
  if (@rows) {
    $summary->{nDatasets} = scalar(@rows);
    my ($datasetIdentifier,$submitter_id,$datasetType,$datasetPassword,$datasetTag,$datasetTitle,$publicReleaseDate,$finalizedDate) = 
      @{$rows[0]};
    $summary->{datasetRows} = \@rows;

    categorizeDatasets();

  } else {
    $response->{result} = 'Failed';
    push(@{$response->{errors}},"ERROR: Query<PRE>\n$sql</PRE> failed to return any rows.<BR>");
    $summary->{nDatasets} = 0;
  }

  $summary->{result} = $response->{result};
  $summary->{errors} = $response->{errors};
  return $summary;
}


#######################################################################
# showPASSSummaryHTML
#######################################################################
sub showPASSSummaryHTML {
  my $self = shift;
  my %args = @_;
  my $SUB_NAME = 'showPASSSummaryHTML';

  my $response;
  $response->{result} = 'Success';

  our %categories;

  if ($summary->{nDatasets} < 1) {
    $response->{result} = 'Failed';
    push(@{$response->{errors}},"ERROR: There are no datasets in the repository to display.<BR>");
    return $response;
  }


  print "<H3>Public Test Datasets (should not happen)</H3>\n";
  my $buffer = '';
  print "<TABLE>\n";
  my $counter = 0;
  foreach my $datasetIdentifier ( sort(keys(%{$summary->{categorizedDatasets}->{isPublic}->{datasets}})) ) {
    my $row = $summary->{datasets}->{$datasetIdentifier};
    if ($summary->{categorizedDatasets}->{isTest}->{datasets}->{$datasetIdentifier}) {
      $buffer .= "<TR><TD><A HREF=\"$CGI_BASE_DIR/PeptideAtlas/PASS_View?datasetIdentifier=$row->[0]\">$row->[0]</A></TD><TD>$row->[5]</TD></TR>\n";
      $counter++;
    }
  }
  $buffer .= "</TABLE>\n";
  if ($counter) {
    print $buffer;
  } else {
    print "<TR><TD>none</TD></TR></TABLE>\n";
  }


  print "<H3>Non public Test Datasets</H3>\n";
  my $buffer = '';
  print "<TABLE>\n";
  my $counter = 0;
  foreach my $datasetIdentifier ( sort(keys(%{$summary->{categorizedDatasets}->{notPublic}->{datasets}})) ) {
    my $row = $summary->{datasets}->{$datasetIdentifier};
    if ($summary->{categorizedDatasets}->{isTest}->{datasets}->{$datasetIdentifier}) {
      $buffer .= "<TR><TD><A HREF=\"$CGI_BASE_DIR/PeptideAtlas/PASS_View?identifier=$row->[0]\">$row->[0]</A></TD><TD>$row->[5]</TD></TR>\n";
      $counter++;
    }
  }
  $buffer .= "</TABLE>\n";
  if ($counter) {
    print $buffer;
  } else {
    print "<TR><TD>none</TD></TR></TABLE>\n";
  }


  print "<H3>Public Datasets that are Finalized</H3>\n";
  my $buffer = '';
  print "<TABLE>\n";
  my $counter = 0;
  foreach my $datasetIdentifier ( sort(keys(%{$summary->{categorizedDatasets}->{isPublic}->{datasets}})) ) {
    my $row = $summary->{datasets}->{$datasetIdentifier};
    unless ($summary->{categorizedDatasets}->{isTest}->{datasets}->{$datasetIdentifier}) {
      if ($summary->{categorizedDatasets}->{isFinalized}->{datasets}->{$datasetIdentifier}) {
	$buffer .= "<TR><TD><A HREF=\"$CGI_BASE_DIR/PeptideAtlas/PASS_View?identifier=$row->[0]\">$row->[0]</A></TD><TD>$row->[5]</TD></TR>\n";
	$counter++;
      }
    }
  }
  $buffer .= "</TABLE>\n";
  if ($counter) {
    print $buffer;
  } else {
    print "<TR><TD>none</TD></TR></TABLE>\n";
  }


  print "<H3>Public Datasets that are not Finalized</H3>\n";
  my $buffer = '';
  print "<TABLE>\n";
  my $counter = 0;
  foreach my $datasetIdentifier ( sort(keys(%{$summary->{categorizedDatasets}->{isPublic}->{datasets}})) ) {
    my $row = $summary->{datasets}->{$datasetIdentifier};
    unless ($summary->{categorizedDatasets}->{isTest}->{datasets}->{$datasetIdentifier}) {
      if ($summary->{categorizedDatasets}->{notFinalized}->{datasets}->{$datasetIdentifier}) {
	$buffer .= "<TR><TD><A HREF=\"$CGI_BASE_DIR/PeptideAtlas/PASS_View?identifier=$row->[0]\">$row->[0]</A></TD><TD>$row->[5]</TD></TR>\n";
	$counter++;
	$summary->{tasks}->{$datasetIdentifier}->{datasetIdentifier} = $datasetIdentifier;
	$summary->{tasks}->{$datasetIdentifier}->{taskName} = 'remindToFinalizePublicDataset';
      }
    }
  }
  $buffer .= "</TABLE>\n";
  if ($counter) {
    print $buffer;
  } else {
    print "<TR><TD>none</TD></TR></TABLE>\n";
  }


  print "<H3>Not Yet Public Datasets that are Finalized</H3>\n";
  my $buffer = '';
  print "<TABLE>\n";
  my $counter = 0;
  foreach my $datasetIdentifier ( sort(keys(%{$summary->{categorizedDatasets}->{notPublic}->{datasets}})) ) {
    my $row = $summary->{datasets}->{$datasetIdentifier};
    unless ($summary->{categorizedDatasets}->{isTest}->{datasets}->{$datasetIdentifier}) {
      if ($summary->{categorizedDatasets}->{isFinalized}->{datasets}->{$datasetIdentifier}) {
	$buffer .= "<TR><TD><A HREF=\"$CGI_BASE_DIR/PeptideAtlas/PASS_View?identifier=$row->[0]\">$row->[0]</A></TD><TD>$row->[5]</TD></TR>\n";
	$counter++;
      }
    }
  }
  $buffer .= "</TABLE>\n";
  if ($counter) {
    print $buffer;
  } else {
    print "<TR><TD>none</TD></TR></TABLE>\n";
  }


  print "<H3>Not Yet Public Datasets that are not Finalized</H3>\n";
  my $buffer = '';
  print "<TABLE>\n";
  my $counter = 0;
  foreach my $datasetIdentifier ( sort(keys(%{$summary->{categorizedDatasets}->{notPublic}->{datasets}})) ) {
    my $row = $summary->{datasets}->{$datasetIdentifier};
    unless ($summary->{categorizedDatasets}->{isTest}->{datasets}->{$datasetIdentifier}) {
      if ($summary->{categorizedDatasets}->{notFinalized}->{datasets}->{$datasetIdentifier}) {
	$buffer .= "<TR><TD><A HREF=\"$CGI_BASE_DIR/PeptideAtlas/PASS_View?identifier=$row->[0]\">$row->[0]</A></TD><TD>$row->[5]</TD></TR>\n";
	$counter++;
      }
    }
  }
  $buffer .= "</TABLE>\n";
  if ($counter) {
    print $buffer;
  } else {
    print "<TR><TD>none</TD></TR></TABLE>\n";
  }


  print "<H3>Datasets with no public release information (should not happen)</H3>\n";
  my $buffer = '';
  print "<TABLE>\n";
  my $counter = 0;
  foreach my $datasetIdentifier ( sort(keys(%{$summary->{categorizedDatasets}->{noPublic}->{datasets}})) ) {
    my $row = $summary->{datasets}->{$datasetIdentifier};
    $buffer .= "<TR><TD><A HREF=\"$CGI_BASE_DIR/PeptideAtlas/PASS_View?identifier=$row->[0]\">$row->[0]</A></TD><TD>$row->[5]</TD></TR>\n";
    $counter++;
  }
  $buffer .= "</TABLE>\n";
  if ($counter) {
    print $buffer;
  } else {
    print "<TR><TD>none</TD></TR></TABLE>\n";
  }


  print "<H3>Datasets with finalized date in the future (should not happen)</H3>\n";
  my $buffer = '';
  print "<TABLE>\n";
  my $counter = 0;
  foreach my $datasetIdentifier ( sort(keys(%{$summary->{categorizedDatasets}->{futureFinalized}->{datasets}})) ) {
    my $row = $summary->{datasets}->{$datasetIdentifier};
    $buffer .= "<TR><TD><A HREF=\"$CGI_BASE_DIR/PeptideAtlas/PASS_View?identifier=$row->[0]\">$row->[0]</A></TD><TD>$row->[5]</TD></TR>\n";
    $counter++;
  }
  $buffer .= "</TABLE>\n";
  if ($counter) {
    print $buffer;
  } else {
    print "<TR><TD>none</TD></TR></TABLE>\n";
  }


  print "<HR>\n";
  print "<H3>Task Queue</H3>\n";
  my $buffer = '';
  print "<TABLE>\n";
  my $counter = 0;
  foreach my $task ( keys(%{$summary->{tasks}}) ) {
    my $datasetIdentifier = $summary->{tasks}->{$task}->{datasetIdentifier};
    my $taskName = $summary->{tasks}->{$task}->{taskName};
    my $row = $summary->{datasets}->{$datasetIdentifier};
    $buffer .= "<TR><TD>$datasetIdentifier</TD><TD>$taskName</TD></TR>\n";
    $self->initiateTask(
      datasetIdentifier => $datasetIdentifier,
      taskName => $taskName,
    );
    $counter++;
  }
  $buffer .= "</TABLE>\n";
  if ($counter) {
    print $buffer;
  } else {
    print "<TR><TD>none</TD></TR></TABLE>\n";
  }

  return $response;
}


#######################################################################
# categorizeDatasets
#######################################################################
sub categorizeDatasets {
  my $self = shift;
  my %args = @_;
  my $SUB_NAME = 'categorizeDatasets';

  my $response;
  $response->{result} = 'Success';

  if ($summary->{nDatasets} < 1) {
    $response->{result} = 'Failed';
    push(@{$response->{errors}},"ERROR: There are no datasets in the repository to categorize.<BR>");
    return $response;
  }

  #### Get current date
  my ($date) = `date '+%F'`;
  chomp($date);
  $summary->{currentDateTime} = $date;

  #### Define our categories
  our %categories = (
    isPublic => 'Public Datasets',
    notPublic => 'Not public Datasets',
    noPublic => 'Datasets with no public release date',
  );
  foreach my $category ( keys(%categories) ) {
    $summary->{categorizedDatasets}->{$category}->{name} = $categories{$category};
  }

  #### Known test datasets
  my %testDatasets = (
    PASS00001 => 1,
    PASS00002 => 1,
    PASS00003 => 1,
    PASS00028 => 1,
    PASS00029 => 1,
    PASS00039 => 1,
    PASS00040 => 1,
    PASS00049 => 1,
    PASS00052 => 1,
    PASS00381 => 1,
		      );


  #### Iterate through all datasets and categorize them
  foreach my $row ( @{$summary->{datasetRows}} ) {
    my ($datasetIdentifier,$submitter_id,$datasetType,$datasetPassword,
        $datasetTag,$datasetTitle,$publicReleaseDate,$finalizedDate) = @{$row};
    $summary->{datasets}->{$datasetIdentifier} = $row;

    #### Label the public datasets
    if ($publicReleaseDate) {
      if (substr($date,0,10) ge substr($publicReleaseDate,0,10)) {
	$summary->{categorizedDatasets}->{isPublic}->{datasets}->{$datasetIdentifier} = 1;
	$summary->{categorizedDatasets}->{isPublic}->{count}++;
      } else {
	$summary->{categorizedDatasets}->{notPublic}->{datasets}->{$datasetIdentifier} = 1;
	$summary->{categorizedDatasets}->{notPublic}->{count}++;
      }
    } else {
      $summary->{categorizedDatasets}->{noPublic}->{datasets}->{$datasetIdentifier} = 1;
      $summary->{categorizedDatasets}->{noPublic}->{count}++;
    }

    #### Label the finalized datasets
    if ($finalizedDate) {
      if (substr($date,0,10) ge substr($finalizedDate,0,10)) {
	$summary->{categorizedDatasets}->{isFinalized}->{datasets}->{$datasetIdentifier} = 1;
	$summary->{categorizedDatasets}->{isFinalized}->{count}++;
      } else {
	$summary->{categorizedDatasets}->{futureFinalized}->{datasets}->{$datasetIdentifier} = 1;
	$summary->{categorizedDatasets}->{futureFinalized}->{count}++;
      }
    } else {
      $summary->{categorizedDatasets}->{notFinalized}->{datasets}->{$datasetIdentifier} = 1;
      $summary->{categorizedDatasets}->{notFinalized}->{count}++;
    }

    #### Label the test datasets
    if ($testDatasets{$datasetIdentifier}) {
      $summary->{categorizedDatasets}->{isTest}->{datasets}->{$datasetIdentifier} = 1;
      $summary->{categorizedDatasets}->{isTest}->{count}++;
    }

  }

  return $response;
}



#######################################################################
# initiateTask
#######################################################################
sub initiateTask {
  my $self = shift;
  my %args = @_;
  my $SUB_NAME = 'initiateTask';

  my $response;
  $response->{result} = 'Success';

  our $summary;

  #### Decode the argument list
  my $datasetIdentifier = $args{'datasetIdentifier'} || die "[$SUB_NAME] ERROR: datasetIdentifier not passed";
  my $taskName = $args{'taskName'} || die "[$SUB_NAME] ERROR: taskName not passed";

  my ($datasetIdentifier,$submitter_id,$datasetType,$datasetPassword,
      $datasetTag,$datasetTitle,$publicReleaseDate,$finalizedDate) = @{$summary->{datasets}->{$datasetIdentifier}};

  my $submitter = $self->getSubmitterInfo(submitter_id=>$submitter_id);
  unless ($submitter->{firstName} && $submitter->{lastName}) {
    print "ERROR: Did not find firstName and LastName\n";
    return $response;
  }

  my $reminderMessage = qq~
Dear $submitter->{firstName},\n\nThank you again for submitting your dataset to PeptideAtlas. Your efforts to make your proteomics data publicly available are much appreciated.\n\nWhile reviewing datasets, I found that your dataset $datasetIdentifier has not been finalized, even though it is publicly accessible.\n\nWould you take a moment to go to:\nhttp://www.peptideatlas.org/PASS/$datasetIdentifier\nand click the FINALIZE button to finalize your dataset?\n\nOr alternatively, if you find that you can improve the annotations first, please do that and then finalize.\n\nThank you for your time.\n\nThe PeptideAtlas Agent\non behalf of the PeptideAtlas Team\n
~;

  print "<HR><PRE>$reminderMessage</PRE><HR>\n";

  return $response;
}


#######################################################################
# getSubmitterInfo
#######################################################################
sub getSubmitterInfo {
  my $self = shift;
  my %args = @_;
  my $SUB_NAME = 'getSubmitterInfo';

  #### Decode the argument list
  my $submitter_id = $args{'submitter_id'} || die "[$SUB_NAME] ERROR: submitter_id not passed";

  my $response;
  $response->{result} = 'Success';

  my @columns = qw( submitter_id firstName lastName emailAddress password emailReminders emailPasswords );
  my $columns = join(',',@columns);

  my $sql = qq~
    SELECT $columns
      FROM $TBAT_PASS_SUBMITTER
     WHERE submitter_id = '$submitter_id'
  ~;
  my @rows = $sbeams->selectSeveralColumns($sql);
  if (@rows) {
    for (my $i=0; $i<scalar(@{$rows[0]}); $i++) {
      $response->{$columns[$i]} = $rows[0]->[$i];
    }
  }

  return $response;
}


#######################################################################
# emailPasswordReminder
#######################################################################
sub emailPasswordReminder {
  my $self = shift;
  my %args = @_;
  my $SUB_NAME = 'emailPasswordReminder';

  #### Decode the argument list
  my $emailAddress = $args{'emailAddress'} || die "[$SUB_NAME] ERROR: emailAddress not passed";

  my $response;
  $response->{result} = 'UNKNOWN ERROR';

  #### Ensure that the email address seems valid
  unless ( $emailAddress =~ /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}$/i ) {
    $response->{result} = 'ERROR';
    push(@{$response->{errors}},"ERROR: The email address '$emailAddress' does not appear to be valid according to current rules.");
    return $response;
  }

  #### Prepare a query to get information about the submitter
  my @columns = qw( submitter_id firstName lastName emailAddress password emailReminders emailPasswords );
  my $columns = join(',',@columns);
  my $sql = qq~
    SELECT $columns
      FROM $TBAT_PASS_SUBMITTER
     WHERE emailAddress = '$emailAddress'
  ~;

  #### Execute the query
  my @rows = $sbeams->selectSeveralColumns($sql);

  #### If no rows returned
  unless (@rows) {
    $response->{result} = 'ERROR';
    push(@{$response->{errors}},"ERROR: No records found for email address '$emailAddress'.");
    return $response;
  }

  #### If too many rows returned
  if (scalar(@rows) > 1) {
    $response->{result} = 'ERROR';
    push(@{$response->{errors}},"ERROR: Multiple records found for email address '$emailAddress'.");
    return $response;
  }

  #### Create a hash out of the result
  my %submitter;
  for (my $i=0; $i<scalar(@columns); $i++) {
    $submitter{$columns[$i]} = $rows[0]->[$i];
  }

  #### Prepare an email
  my $reminderMessage = qq~
Dear $submitter{firstName},

Thank you again for submitting your dataset to PeptideAtlas. A request was received for a password reminder. If this was not you, you may wish to report this to PeptideAtlas at http://www.peptideatlas.org/feedback.php. If it was you, then you may go to a PASS page such as the dataset viewer:

https://db.systemsbiology.net/sbeams/cgi/PeptideAtlas/PASS_View

and enter your email address and password there. Or, if you were trying to submit a dataset, return to:

https://db.systemsbiology.net/sbeams/cgi/PeptideAtlas/PASS_Submit

and enter your email address and password there. Your password is:

$submitter{password}

Thank you for your time.

The PeptideAtlas Agent
on behalf of the PeptideAtlas Team

~;

  #### Send the email
  my (@toRecipients,@ccRecipients,@bccRecipients);
  @toRecipients = (
    "$submitter{firstName} $submitter{lastName}",$submitter{emailAddress},
  );
  @ccRecipients = ();
  @bccRecipients = (
    'Eric Deutsch','eric.deutsch@systemsbiology.org',
  );

  SBEAMS::Connection::Utilities::sendEmail(
    toRecipients=>\@toRecipients,
    ccRecipients=>\@ccRecipients,
    bccRecipients=>\@bccRecipients,
    subject=>"PeptideAtlas PASS password reminder",
    message=>$reminderMessage,
  );

  $response->{result} = 'SUCCESS';

  return $response;
}



###############################################################################
1;
