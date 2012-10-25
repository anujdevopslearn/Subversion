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

my @datasetTypes = ( 'MSMS' => 'MS/MS dataset',
		     'SRM' => 'SRM dataset',
		     'MS1' => 'MS1 dataset',
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
    push(@{$response->{errors}},"Dataset Tag must be an alphanumeric string with length more than 5 up to 20");
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





###############################################################################
1;
