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
#   Grab all data for all SRM experiments from JSON file, filter out those
#     for which we don't have permission, and return a JSON hash
###############################################################################

sub srm_experiments_2_json {
  my $self = shift || die ("self not passed");
  my %args = @_;
  my $VERBOSE = $args{'verbose'};
  my $QUIET = $args{'quiet'};
  my $TESTONLY = $args{'testonly'};
  my $DEBUG = $args{'debug'};

  my $json_href;
  my $content_href;

  my $sbeams = $self->getSBEAMS();
  my $accessible_projects = join (",",
    $sbeams->getAccessibleProjects());
  my $json = new JSON;
  $json = $json->pretty([1]);  # print json objects with indentation, etc.

  # Read the json object from a cache file into a hash. If not there, create.
  # This filename shouldn't be hardcoded ...
  my $json_filename_all = "$PHYSICAL_BASE_DIR/tmp/PASSEL_experiments_all.json";
  $self->srm_experiments_2_json_all() if (! -e $json_filename_all);
  open (JSONFILE, "$json_filename_all") ||
    die "Can't open $json_filename_all for reading\n";
  $json_href = $json->decode(join(" ",<JSONFILE>));
  close JSONFILE;

  # Filter to retain only those experiments for which we have permission
  filterForAccessibleProjects(
    json_href => $json_href,
    accessible_projects => $accessible_projects,
    verbose => $VERBOSE,
    quiet => $QUIET,
    testonly => $TESTONLY,
    debug => $DEBUG,
  );

  return ($json_href);
}

sub filterForAccessibleProjects {
  my %args = @_;
  my $json_href = $args{'json_href'};
  my $VERBOSE = $args{'verbose'};
  my $QUIET = $args{'quiet'};
  my $TESTONLY = $args{'testonly'};
  my $DEBUG = $args{'debug'};

  my $accessible_projects = $args{'accessible_projects'};
  print "accessible_projects = $accessible_projects\n" if $DEBUG;
  my @accessible_projects = split ("," , $accessible_projects);
  # make a hash out of the list of accessible projects
  my %ap = map { $_ => 1 } @accessible_projects;
  for my $key (sort {$a<=>$b} keys %ap) {
  #test to see if conversion to hash is successful
    print "|$key| |$ap{$key}|\n" if $DEBUG;
    if ( ! defined $ap{$key }) {
      print "ap hash  not defined for $key\n" if $DEBUG; 
    }
  }
  my $n_projects = scalar keys %ap;
  print "$n_projects projects\n" if $DEBUG;

  my $n_expts = scalar @{$json_href->{MS_QueryResponse}{samples}};
  print "before filtering, n_expts = $n_expts\n" if $DEBUG;

  for (my $i=0; $i<$n_expts; $i++) {
     my $project_id =
       $json_href->{MS_QueryResponse}{samples}->[$i]->{'peptideatlas_project_id'};
     print "project_id = |$project_id|\n" if $DEBUG;
     if ( ! defined $ap{$project_id }) {
       print "ap hash  not defined for $project_id -- deleting expt $i!\n" if $DEBUG;
       splice (@{$json_href->{MS_QueryResponse}{samples}}, $i, 1);
       $n_expts--;
       $i--;
     }
  }
  my $n_expts = scalar @{$json_href->{MS_QueryResponse}{samples}};
  print "after filtering, n_expts = $n_expts\n" if $DEBUG;
}



###############################################################################
# srm_experiments_2_json_all
#   Get all data for all SRM experiments, store in a hash,
#    and write in a .json data file.
###############################################################################

sub srm_experiments_2_json_all {
  my $self = shift || die ("self not passed");
  my %args = @_;
  my $VERBOSE = $args{'verbose'};
  my $QUIET = $args{'quiet'};
  my $TESTONLY = $args{'testonly'};
  my $DEBUG = $args{'debug'};

  my $json_href;
  my $content_href;

  my $sbeams = $self->getSBEAMS();

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
     COUNT (distinct SELT.SEL_transition_id) as n_transitions,
     SELE.project_id,
     SELE.heavy_label,
     SELE.mprophet_analysis,
     SELE.PX_identifier 
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
   WHERE SELE.record_status != 'D'
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
     O.organism_name,
     SELE.project_id,
     SELE.heavy_label,
     SELE.mprophet_analysis,
     SELE.PX_identifier
  ORDER BY O.organism_name,SELE.experiment_title
  ~;

#--------------------------------------------------
#      COUNT (distinct SELPIP.protein_accession) as n_prots,
# 
#    join $TBAT_SEL_PEPTIDE_ION_PROTEIN SELPIP
#      on SELPIP.SEL_peptide_ion_id = SELPI.SEL_peptide_ion_id
#-------------------------------------------------- 

  print "$sql" if ($VERBOSE > 1);
  print "Querying database; takes minutes\n" if ($VERBOSE);
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
     $n_transitions, $project_id, $spikein, $mprophet,$px_identifier ) = @{$row};
   my $acc = $SEL_experiment_id;

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
      "Found publication $publication_id!\n" if ($VERBOSE);
    } else {
      print "No publications found!\n" if ($VERBOSE);
    }


    my $cite = '';
    $cite  = "$title, $journal_name ${volume_number}:$issue_number pp$page_numbers, $published_year"
        if ($title && $journal_name && $published_year);;
    # store all the fields in a data object
    # still need to gather: dates, taxonomy, counts, public, link

    my %data;
    $data{"sampletag"} = $sample_tag;
    $data{"acc"} = "$SEL_experiment_id";
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
    $data{"mprophet"} = "$mprophet",
    $data{"spikein"} = "$spikein",
    $data{"counts"}{"runs"} = "$n_runs",
    $data{"counts"}{"peps"} = "$n_peps",
    $data{"counts"}{"ions"} = "$n_ions",
    $data{"counts"}{"prots"} = "$n_prots",
    $data{"counts"}{"transition_groups"} = "$n_transition_groups",
    $data{"counts"}{"transitions"} = "$n_transitions",
    $data{"px_identifier"} = "$px_identifier",
    $data{"peptideatlas_project_id"} = "$project_id",

    # push onto json data structure
    
    push @{$json_href->{MS_QueryResponse}{samples}}, {%data};
    $count++;
    %data = ();
  }

  my $json_filename = "$PHYSICAL_BASE_DIR/tmp/PASSEL_experiments_all.json";
  open (JSONFILE, ">$json_filename") ||
    die "Can't open $json_filename for writing\n";
  my $json = new JSON;
  $json = $json->pretty([1]);
#  print JSONFILE  header('application/json');
  print "Writing to $json_filename\n" if ($VERBOSE);
  print JSONFILE  $json->encode($json_href);
  close JSONFILE;
}
