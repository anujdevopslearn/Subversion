package SBEAMS::PeptideAtlas::PASSEL;

###############################################################################
# Class       : SBEAMS::PeptideAtlas::PASSEL
# Author      : Terry Farrah # <tfarrah@systemsbiology.org>
#
=head1 SBEAMS::PeptideAtlas::PASSEL

=head2 SYNOPSIS

  SBEAMS::PeptideAtlas::PASSEL

=head2 DESCRIPTION

This is part of SBEAMS::PeptideAtlas which handles the interface
with PASSEL, the PeptideAtlas SRM Experiment Library

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
use JSON;

my $sbeams = SBEAMS::Connection->new();

###############################################################################
# Constructor -- copied from AtlasBuild.pm
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



###############################################################################
# srm_experiments_2_json
#   Get all data for all SRM experiments, store in a hash,
#    and write in a .json data file.
###############################################################################

sub srm_experiments_2_json {
  my $self = shift || die ("self not passed");
  my %args = @_;

  my $json_href;
  my $content_href;

  my $sbeams = $self->getSBEAMS();
  my $accessible_projects = join (",",
    $sbeams->getAccessibleProjects());

  my $sql = qq~
   SELECT
     SELE.experiment_title,
     SELE.datasetIdentifier,
     SELE.data_path,
     CAST(SELE.comment AS varchar(4000)) as comment,
     count (distinct SELR.SEL_run_id) as n_runs,
     S.sample_tag,
     S.sample_title,
     S.sample_date,
     IT.instrument_name,
     S.sample_publication_ids,
     CAST(S.sample_description AS varchar(4000)) as sample_description,
     CAST(S.data_contributors AS varchar(4000)) as data_contributors,
     SELE.SEL_experiment_id,
     O.organism_name,
     COUNT (distinct SELTG.experiment_protein_name) as n_prots,
     COUNT (distinct SELPI.stripped_peptide_sequence) as n_peps,
     COUNT (distinct SELTG.SEL_peptide_ion_id) as n_ions,
     COUNT (distinct SELTG.SEL_transition_group_id) as n_transition_groups,
     COUNT (distinct SELT.SEL_transition_id) as n_transitions
   from $TBAT_SEL_EXPERIMENT SELE
   join $TBAT_SAMPLE S
     on S.sample_id = SELE.sample_id
   left join $TB_ORGANISM O
     on O.organism_id = S.organism_id
   left join $TBPR_INSTRUMENT IT
     on IT.instrument_id = S.instrument_model_id
   join $TBAT_SEL_RUN SELR
     on SELR.SEL_experiment_id = SELE.SEL_experiment_id
   join $TBAT_SEL_TRANSITION_GROUP SELTG
     on SELTG.SEL_run_id = SELR.SEL_run_id
   join $TBAT_SEL_TRANSITION SELT
     on SELT.SEL_transition_group_id = SELTG.SEL_transition_group_id
   join $TBAT_SEL_PEPTIDE_ION SELPI
     on SELPI.SEL_peptide_ion_id = SELTG.SEL_peptide_ion_id
   WHERE SELE.project_id in ( $accessible_projects )
   GROUP BY
     SELE.experiment_title,
     SELE.datasetIdentifier,
     SELE.data_path,
     CAST(SELE.comment AS varchar(4000)),
     S.sample_tag,
     S.sample_title,
     S.sample_date,
     IT.instrument_name,
     S.sample_publication_ids,
     CAST(S.sample_description AS varchar(4000)),
     CAST(S.data_contributors AS varchar(4000)),
     SELE.SEL_experiment_id,
     O.organism_name
  ORDER BY O.organism_name,SELE.experiment_title
  ~;

  my @rows = $sbeams->selectSeveralColumns($sql);

  # create .json header
  $json_href ->{"MS_QueryResponse" }{"userinfo"}{"name"} = "Anonymous";
  $json_href ->{"MS_QueryResponse" }{"userinfo"}{"id"} = 0;
  $json_href ->{"MS_QueryResponse" }{"userinfo"}{"role"} = "anonymous";

  # store data for each experiment
  my $count=0;
  for my $row (@rows) {
    my ( $experiment_title, $datasetIdentifier,
     $data_path, $comment, $n_runs, $sample_tag, $sample_title,
     $sample_date, $instrument_name, $sample_publication_ids, $sample_description,
     $data_contributors,$SEL_experiment_id,$organism_name,
     $n_prots, $n_peps, $n_ions, $n_transition_groups,
     $n_transitions ) = @{$row};

    # TODO: get all publications, if multiple. For now we just get the first.
    my @pub_ids = split(",", $sample_publication_ids);
    my $publication_id = $pub_ids[0];
    my $sql = qq~
      SELECT
      pubmed_id,
      publication_name,
      title,
      author_list,
      journal_name,
      published_year,
      volume_number,
      issue_number,
      page_numbers,
      abstract
      FROM $TBAT_PUBLICATION PUB
      WHERE PUB.publication_id = '$publication_id'
      ;
    ~;

    my @rows = $sbeams->selectSeveralColumns($sql);

    my $nrows = scalar @rows;
    my ( $pubmed_id, $publication_name, $title, $author_list, $journal_name,
	 $published_year, $volume_number, $issue_number, $page_numbers,
	 $abstract );
    if ($nrows) {
      my $first_pub_aref = $rows[0];
      ( $pubmed_id, $publication_name, $title, $author_list, $journal_name,
	   $published_year, $volume_number, $issue_number, $page_numbers,
	   $abstract ) = @{$first_pub_aref};
      #print "<p>Found publication $publication_id!</p>\n";
    } else {
      #print "<p>No publications found!</p>\n";
    }


    my $cite = '';
    $cite  = "$title, $journal_name ${volume_number}:$issue_number pp$page_numbers, $published_year"
        if ($title && $journal_name && $published_year);;
    # store all the fields in a data object
    # still need to gather: dates, taxonomy, counts, public, link

    my %data;
    $data{"sampletag"} = $sample_tag;
    $data{"taxonomy"} = $organism_name;
    $data{"summary"} = "";
    $data{"contributors"} = "$data_contributors",
    $data{"experiment_title"} = "$experiment_title",
    $data{"datasetIdentifier"} = "$datasetIdentifier",
    $data{"SEL_experiment_id"} = "$SEL_experiment_id",
    $data{"data_path"} = "$data_path",
    $data{"comment"} = "$comment",
    $data{"sample_date"} = "$sample_date",
    $data{"instrumentation"} = "$instrument_name",
    $data{"public"} = "",
    $data{"description"} = "$sample_description",
    $data{"publication"}{"link"} = "";
    $data{"publication"}{"ids"} =  [ "$pubmed_id" ],
    $data{"publication"}{"author"} =  "$author_list",
    $data{"publication"}{"cite"} =  "$cite",
    $data{"title"} = "$sample_title",
    $data{"publication_name"} = "$publication_name",
    $data{"abstract"} = "$abstract",
    $data{"counts"}{"runs"} = "$n_runs",
    $data{"counts"}{"peps"} = "$n_peps",
    $data{"counts"}{"ions"} = "$n_ions",
    $data{"counts"}{"prots"} = "$n_prots",
    $data{"counts"}{"transition_groups"} = "$n_transition_groups",
    $data{"counts"}{"transitions"} = "$n_transitions",

    # push onto json data structure
    
    push @{$json_href->{MS_QueryResponse}{samples}}, {%data};
    $count++;
    %data = ();
  }

  my $json_filename = "$PHYSICAL_BASE_DIR/tmp/PASSEL_experiments.json";
  print "<!--Trying to write to $json_filename-->\n";
  open (TEST, ">$json_filename") ||
  print "<!--Can't open $json_filename for writing-->\n";
  my $json = new JSON;
  $json = $json->pretty([1]);
#  print TEST  header('application/json');
  print TEST  $json->encode($json_href);
  close TEST;

}
