#!/usr/local/bin/perl -w
###############################################################################
# Program     : createPipelineInput.pl
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This script builds the input files needed for the PeptideAtlas
#               pipeline from a list of input samples and directories
#
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################
use strict;
use POSIX;  #for floor()
use Getopt::Long;
use XML::Xerces;
use FindBin;
use Fcntl qw/:seek/;
use Devel::Size qw(size total_size);
use Data::Dumper;
use lib "$FindBin::Bin/../../perl";

use vars qw ($sbeams $sbeamsMOD $q
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $TESTONLY
             $DATABASE $current_contact_id $current_username
            );

use vars qw (%peptide_accessions %biosequence_attributes);

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
#use SBEAMS::Connection::TableInfo;

use SBEAMS::Proteomics::Tables;
use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Tables;
use SBEAMS::PeptideAtlas::ProtInfo;
use SBEAMS::PeptideAtlas::SpectralCounting;
use SBEAMS::PeptideAtlas::Peptide;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::PeptideAtlas;
$sbeamsMOD->setSBEAMS( $sbeams );
$| = 1; #flush output on every print


###############################################################################
# Read and validate command line args
###############################################################################
my $VERSION = q[$Id$ ];
$PROG_NAME = $FindBin::Script;
my $build_version = $ENV{VERSION};

my $USAGE = <<EOU;
USAGE: $PROG_NAME [OPTIONS] source_file
Options:
  --verbose n         Set verbosity level.  default is 0
  --quiet             Set flag to print nothing at all except errors
                      This masks the printing of progress information
  --debug n           Set debug level.  default is 0
  --testonly          If set, nothing is actually inserted into the database,
                      but we just go through all the motions.  Use --verbose
                      to see all the SQL statements that would occur

  --validate=XXXXX    XML validation scheme [always | never | auto]
  --namespaces        Enable namespace processing. Defaults to off.
  --schemas           Enable schema processing. Defaults to off.

  --source_file       Input file containing the sample and directory listing
  --build_dir         Name of build directory; used to name output files
                         (not yet implemented)
  --FDR_threshold     FDR threshold to accept. Default 0.0001.
  --P_threshold       Probability threshold (e.g. 0.9) instead of FDR thresh.
  --output_file       Filename to which to write the peptides
  --master_ProteinProphet_file       Filename for a master ProteinProphet
                      run that should be used instead of individual ones.
  --glyco_atlas       All expts are glycocapture. For abundance estimation.
  --per_expt_pipeline Adjust probabilities according to individual
                      protXMLs; use master for prot ID assignment only
  --biosequence_set_id   Database id of the biosequence_set from which to
                         load sequence attributes.
  --best_probs_from_protxml   Get best initial probs from ProteinProphet file,
                      not from pepXML files. Use when not combining expts.
                      using iProphet; correct and faster.
  --min_indep         Minimum fraction pep uniqueness for prot independence
                      Defaults to 0.2
  --APD_only          PAidentlist files already exist; just create APD files
  --protlist_only     PAidentlist files already exist; just create protlist
  --apportion_PSMs    apportion PSMs to prots according to ProtPro pep probs.
                      Default: off (instead, count all PMSs mapping to prot).
  --splib_filter      Filter out spectra not in spectral library
                      DATA_FILES/\${build_version}_all_Q2.sptxt


 e.g.:  $PROG_NAME --verbose 2 --source YeastInputExperiments.tsv

EOU

# Removed from usage, because nonfunctional.
# --search_batch_ids  Comma-separated list of SBEAMS-Proteomics seach_batch_ids
#  --slope_for_abundance   Slope for protein abundance calculation
#  --yint_for_abundance    Y-intercept for protein abundance calculation

#### If no parameters are given, print usage information
unless ($ARGV[0]){
  print "$USAGE";
  exit;
}


#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
  "validate=s","namespaces","schemas","build_dir:s",
  "source_file=s","search_batch_ids:s","P_threshold=f","FDR_threshold=f",
  "output_file=s","master_ProteinProphet_file=s",
#  "slope_for_abundance=f","yint_for_abundance=f",
  "per_expt_pipeline",
  "glyco_atlas",
  "biosequence_set_id=s", "best_probs_from_protxml", "min_indep=f",
  "APD_only", "protlist_only", "apportion_PSMs", "splib_filter",
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
  print "  TESTONLY = $TESTONLY\n";
}

my $PEP_PROB_CUTOFF = $OPTIONS{P_threshold} || 0.5;;

my $source_file = $OPTIONS{source_file} || '';
my $build_dir = $OPTIONS{build_dir} || '';
my $APDTsvFileName = $OPTIONS{output_file} || '';
my $search_batch_ids = $OPTIONS{search_batch_ids} || '';
my $bssid = $OPTIONS{biosequence_set_id};
my $APD_only = $OPTIONS{APD_only} || 0;
my $protlist_only = $OPTIONS{protlist_only} || 0;
my $apportion_PSMs = $OPTIONS{apportin_PSMs} || 0;
my $validate = $OPTIONS{validate} || 'never';
my $namespace = $OPTIONS{namespaces} || 0;
my $schema = $OPTIONS{schemas} || 0;
my $best_probs_from_protxml = $OPTIONS{best_probs_from_protxml} || 0;
my $splib_filter = $OPTIONS{splib_filter} || 0;
my $peptide_str = new SBEAMS::PeptideAtlas::Peptide;

my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset,
  $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
my $year = -100 + $yearOffset;
my $date_string = sprintf("%02d%s%02d", $dayOfMonth, $months[$month], $year);

my $organism_id;
my $swiss_prot_href;

#### Fetch the biosequence data for writing into APD file
####  and for estimating protein abundances.
if ( defined $bssid ) {
  my $sql = qq~
     SELECT organism_id
       FROM $TBAT_BIOSEQUENCE_SET
      WHERE biosequence_set_id = $bssid
  ~;
  ($organism_id) = $sbeams->selectOneColumn($sql);
  print "Organism_id = $organism_id\n";

  $sql = qq~
     SELECT biosequence_id,biosequence_name,biosequence_gene_name,
	    biosequence_accession,biosequence_desc,biosequence_seq,
            dbxref_id
       FROM $TBAT_BIOSEQUENCE
      WHERE biosequence_set_id = $bssid
  ~;
  print "Fetching all biosequence data...\n";
  print "$sql";
  my @rows = $sbeams->selectSeveralColumns($sql);
  foreach my $row (@rows) {
    # Hash each biosequence_name to its row
    my $biosequence_name = $row->[1];
    $biosequence_attributes{$biosequence_name} = $row;
    #print "$row->[1]\n";
    # Populate a special hash of Swiss-Prot biosequence_names,
    # which have a dbxref_id of 1.
    my $dbxref_id = $row->[6];
    $swiss_prot_href->{$biosequence_name} = 1
       if ((defined $dbxref_id) && ($dbxref_id eq '1'));
  }
  print "  Loaded ".scalar(@rows)." biosequences.\n";

  

  #### Just in case the table is empty, put in a bogus hash entry
  #### to prevent triggering a reload attempt
  $biosequence_attributes{' '} = ' ';
} else {
  print "WARNING: No biosequence_set provided! Gene info won't be ".
        "written to APD file, protein abundances will not be estimated, ".
        "and protein identifiers will be chosen according to rules for human.\n";
}

my $effective_organism_id = 2;  # default is human
if ( defined $organism_id ) {
  $effective_organism_id = $organism_id;
}
  
my $preferred_patterns_aref = 
  SBEAMS::PeptideAtlas::ProtInfo::read_protid_preferences(
    organism_id=>$effective_organism_id,
);

my $n_patterns = scalar @{$preferred_patterns_aref};

if ( $n_patterns == 0 ) {
print "WARNING: No protein identifier patterns found ".
      "for organism $effective_organism_id! ".
      "Human protein identifier preferences will be utilized.\n";
} else {
  print "$n_patterns protid patterns read.\n";
}


unless ($protlist_only || $APD_only) {
  #### Make sure either --source_file or --search_batch_ids was specified
  unless ($source_file || $search_batch_ids) {
    print "ERROR: You must specify either --source_file or --search_batch_ids\n";
    print "$USAGE";
    exit 0;
  }


  #### If source_file was specified, verify it
  if ($source_file) {

    #### Check to make sure the file exists
    unless (-f $source_file) {
      die "File '$source_file' does not exist!\n";
    }

  }

#  unless ($build_dir) {
#    print "ERROR: You must specify --build_dir\n";
#    print "$USAGE";
#    exit 0;
#  }
#  #### If a path was given, just take the last element
#  if ($build_dir =~ /.*\/(.+)/ ) {
#    $build_dir = $1;
#  }
#
#  print "Will use $build_dir and $date_string in output filenames.\n";
}

if (uc($validate) eq 'ALWAYS') {
  $validate = $XML::Xerces::SAX2XMLReader::Val_Always;
} elsif (uc($validate) eq 'NEVER') {
  $validate = $XML::Xerces::SAX2XMLReader::Val_Never;
} elsif (uc($validate) eq 'AUTO') {
  $validate = $XML::Xerces::SAX2XMLReader::Val_Auto;
} else {
  die("Unknown value for -v: $validate\n$USAGE");
}


#### main package continues below after MyContentHandler package



###############################################################################
###############################################################################
###############################################################################
# MyContentHandler package: SAX parser callback routines
#
# This MyContentHandler package defines all the content handling callback
# subroutines used the SAX parser
###############################################################################
package MyContentHandler;
use strict;
use Date::Manip;
use vars qw(@ISA $VERBOSE);
@ISA = qw(XML::Xerces::PerlContentHandler);
$VERBOSE = 0;


###############################################################################
# new
###############################################################################
sub new {
  my $class = shift;
  my $self = $class->SUPER::new();
  $self->object_stack([]);
  $self->unhandled({});
  return $self;
}


###############################################################################
# object_stack
###############################################################################
sub object_stack {
  my $self = shift;
  if (scalar @_) {
    $self->{OBJ_STACK} = shift;
  }
  return $self->{OBJ_STACK};
}


###############################################################################
# setVerbosity
###############################################################################
sub setVerbosity {
  my $self = shift;
  if (scalar @_) {
    $VERBOSE = shift;
  }
}


###############################################################################
# unhandled
###############################################################################
sub unhandled {
  my $self = shift;
  if (scalar @_) {
    $self->{UNHANDLED} = shift;
  }
  return $self->{UNHANDLED};
}


###############################################################################
# start_element
###############################################################################
sub start_element {
  my ($self,$uri,$localname,$qname,$attrs) = @_;

  if ($self->{document_type} eq 'pepXML') {
    pepXML_start_element(@_);
  } elsif ($self->{document_type} eq 'protXML') {
    protXML_start_element(@_);
  } else {
    die("ERROR: Unknown document_type '$self->{document_type}'");
  }

  return(1);
}


###############################################################################
# pepXML_start_element
###############################################################################
sub pepXML_start_element {
  my ($self,$uri,$localname,$qname,$attrs) = @_;


  #### Make a hash to of the attributes
  my %attrs = $attrs->to_hash();

  #### Convert all the values from hashref to single value
  while (my ($aa1,$aa2) = each (%attrs)) {
    $attrs{$aa1} = $attrs{$aa1}->{value};
  }

  #### If this is a spectrum, then store some attributes
  if ($localname eq 'spectrum_query') {
    $self->{pepcache}->{spectrum} = $attrs{spectrum};
    $self->{pepcache}->{charge} = $attrs{assumed_charge};
    $self->{pepcache}->{precursor_intensity} = $attrs{precursor_intensity} || '';
    $self->{pepcache}->{total_ion_current} = $attrs{total_ion_current} || '';
    $self->{pepcache}->{signal_to_noise} = $attrs{signal_to_noise} || '';
    $self->{pepcache}->{retention_time_sec} = $attrs{retention_time_sec} || '';
  }

  #### If this is the search_hit, then store some attributes
  #### Note that this whole logic will break if there's more than one
  #### search_hit, which shouldn't be true so far
  #
  #### myrimatch has more than one top 1 search hit. (201606)
  if ($localname eq 'search_hit' ){
    if (not exists $self->{pepcache}->{peptide} ){
      $self->{pepcache}->{peptide} = $attrs{peptide};
      $self->{pepcache}->{peptide_prev_aa} = $attrs{peptide_prev_aa};
      $self->{pepcache}->{peptide_next_aa} = $attrs{peptide_next_aa};
      $self->{pepcache}->{protein_name} = [$attrs{protein}];
      $self->{pepcache}->{massdiff} = $attrs{massdiff};
    }else{
      goto FOO;
    }
  }

  #### If this is an alternative protein, push the protein name
  #### onto the current peptide's list of protein names
  if ($localname eq 'alternative_protein') {
    if (not exists $self->{pepcache}->{scores}->{probability} ){
      if ($attrs{protein}) {
        push (@{$self->{pepcache}->{protein_name}}, $attrs{protein});
      }
    }else{
      goto FOO;
    }
  }


  #### If this is the mass mod info, then store some attributes
  if ($localname eq 'modification_info') {
    if (not exists $self->{pepcache}->{scores}->{probability} ){
			if ($attrs{mod_nterm_mass}) {
				$self->{pepcache}->{modifications}->{0} = $attrs{mod_nterm_mass};
			}
			if ($attrs{mod_cterm_mass}) {
				my $pos = length($self->{pepcache}->{peptide})+1;
				$self->{pepcache}->{modifications}->{$pos} = $attrs{mod_cterm_mass};
			}
    }else{
      goto FOO
    }
  }


  #### If this is the mass mod info, then store some attributes
  if ($localname eq 'mod_aminoacid_mass') {
    if (not exists $self->{pepcache}->{scores}->{probability} ){
     $self->{pepcache}->{modifications}->{$attrs{position}} = $attrs{mass};
    }else{
      goto FOO
    }
  }


  #### If this is the search score info, then store some attributes
  if ($localname eq 'search_score') {
    if (not exists $self->{pepcache}->{scores}->{probability} ){
     $self->{pepcache}->{scores}->{$attrs{name}} = $attrs{value};
    }else{
      goto FOO
    }
  }


  #### If this is the Peptide Prophet derived values, store some attributes
  if ($localname eq 'parameter') {
    $self->{pepcache}->{scores}->{$attrs{name}} = $attrs{value};
  }

  #### If this is the peptideProphet probability score, store some attributes
  if ($localname eq 'peptideprophet_result') {
    $self->{pepcache}->{scores}->{probability} = $attrs{probability};
  }

  ### If this is the iProphet probability score, store the probability
  ### Since iProphet tag comes after peptideProphet tag, this will
  ### supercede the peptideProphet probability. But this is kludgy
  ### and wrong -- shouldn't rely on order of tags.
  if ($localname eq 'interprophet_result') {
    $self->{pepcache}->{scores}->{probability} = $attrs{probability};
  }
  ### ptm result. only parse PTMProphet_STY result.
  if ($localname eq 'ptmprophet_result'){
    #prior="0.285714" ptm="PTMProphet_STY79.9663"
    #ptm_peptide="AY(0.000)VY(0.000)ADWVEHAT(0.026)S(0.026)EIEPGT(0.961)T(0.493)T(0.493)VLR">
    if ($attrs{ptm} =~ /79\.9/){
      $self->{pepcache}->{ptm_peptide} = $attrs{ptm_peptide};
    }
  }

  #### Push information about this element onto the stack
  FOO:
  my $tmp;
  $tmp->{name} = $localname;
  push(@{$self->object_stack},$tmp);


} # end pepXML_start_element



###############################################################################
# protXML_start_element
###############################################################################
sub protXML_start_element {
  my ($self,$uri,$localname,$qname,$attrs) = @_;

  #### Make a hash to of the attributes
  my %attrs = $attrs->to_hash();

  #### Convert all the values from hashref to single value
  while (my ($aa1,$aa2) = each (%attrs)) {
    $attrs{$aa1} = $attrs{$aa1}->{value};
  }

  #### If this is a protein group, then store its number and probability
  if ($localname eq 'protein_group') {
    $self->{protein_group_number} = $attrs{group_number};
    $self->{protein_group_probability} = $attrs{probability};
  }

  #### If this is a protein, then store its name, probability, and
  ####  peptides in protcache -- will be copied to group cache in
  ####  end_element.
  if ($localname eq 'protein') {
    my $protein_name = $attrs{protein_name};
    $self->{protein_name} = $protein_name;
    $self->{protein_probability} = $attrs{probability};
    $self->{protein_confidence} = $attrs{confidence};
    my @peps = split(/\+/, $attrs{unique_stripped_peptides});
    $self->{protcache}->{unique_stripped_peptides} = \@peps;
    $self->{protcache}->{npeps} = scalar @peps;
    $self->{protcache}->{total_number_peptides} = $attrs{total_number_peptides};
    $self->{protcache}->{probability} = $attrs{probability};
    $self->{protcache}->{confidence} = $attrs{confidence};
    $self->{protcache}->{subsuming_protein_entry} =
                $attrs{subsuming_protein_entry};
    # initialize cumulative count of PSMs and enzymatic termini
    # from participating peptides
    $self->{protcache}->{PSM_count} = 0;
    $self->{protcache}->{total_enzymatic_termini} = 0;
  }


  #### If this is an indistinguishable protein, record it in the cache
  #### for the current protein
  if ($localname eq 'indistinguishable_protein') {
    my $protein_name = $attrs{protein_name} || die("No protein_name");
    $self->{protcache}->{indist_prots}->{$protein_name} = 1;
  }
  ## store information for indistinguishable_peptide
  if ($localname eq 'indistinguishable_peptide') {
    my $peptide_sequence = $attrs{peptide_sequence} || die("No sequence");
    $self->{pepcache}->{indistinguishable_peptides}->{peptide_sequence} = $peptide_sequence ;
    $self->{pepcache}->{indistinguishable_peptides}->{charge} = $attrs{charge};
  }
  if ($localname eq 'modification_info') {
    if ($attrs{mod_nterm_mass}) {
      $self->{pepcache}->{modifications}->{0} = $attrs{mod_nterm_mass};
    }
    if ($attrs{mod_cterm_mass}) {
      my $pos = length($self->{pepcache}->{peptide})+1;
      $self->{pepcache}->{modifications}->{$pos} = $attrs{mod_cterm_mass};
    }
  }
  if ($localname eq 'mod_aminoacid_mass') {
    $self->{pepcache}->{modifications}->{$attrs{position}} = $attrs{mass};
  }

  #### If this is a peptide, store some peptide attributes
  ####  TMF 06/23/09: I don't think the attribute charge ever happens here,
  ####    although I do see it in indistinguishable peptides.
  ####    (Talking here about peps, not prots!)
  if ($localname eq 'peptide') {
    my $peptide_sequence = $attrs{peptide_sequence} || die("No sequence");
    $self->{pepcache}->{peptide} = $attrs{peptide_sequence};
    $self->{pepcache}->{charge} = $attrs{charge};
    $self->{pepcache}->{initial_probability} = $attrs{initial_probability};
    $self->{pepcache}->{nsp_adjusted_probability} = $attrs{nsp_adjusted_probability};
    $self->{pepcache}->{n_sibling_peptides} = $attrs{n_sibling_peptides};
    $self->{pepcache}->{n_instances} = $attrs{n_instances};
    $self->{pepcache}->{weight} = $attrs{weight};
    $self->{pepcache}->{n_enzymatic_termini} = $attrs{n_enzymatic_termini};

    ### Compute a couple secondary attributes
    $self->{pepcache}->{apportioned_observations} = $attrs{weight} * $attrs{n_instances};
    $self->{pepcache}->{expected_apportioned_observations} =
          $self->{pepcache}->{apportioned_observations} *
          $attrs{nsp_adjusted_probability};
      

    #### At this point we have all the info on the current protein and its
    #### indistinguishables, so process that if we haven't already.
    #### (remind me again why we don't do this in end_element?)
    unless (defined $self->{protcache}->{indistinguishables_processed}) { 
      # If there are any indistinguishables, see if they include a protID
      # that is more preferred than $self->{protein_name}.
      my @indis = keys(%{$self->{protcache}->{indist_prots}});
      my $original_protein_name = $self->{protein_name};
 
      my $preferred_protein_name = $original_protein_name;
      # Add self to list of indistinguishables for complete list
      # of protein IDs that are indistinguishable from one another
      push (@indis, $original_protein_name);

      if (scalar @indis > 1) {
	# Select the preferred protID of all, and if different from
	# original, do some swapping.
	$preferred_protein_name = 
	  SBEAMS::PeptideAtlas::ProtInfo::get_preferred_protid_from_list(
	    protid_list_ref=>\@indis,
	    preferred_patterns_aref => $preferred_patterns_aref,
	    swiss_prot_href => $swiss_prot_href,
        );
        if ($preferred_protein_name ne $original_protein_name) {
					delete($self->{protcache}->{indist_prots}->{$preferred_protein_name});
					$self->{protcache}->{indist_prots}->{$original_protein_name} = 1;
					$self->{protein_name} = $preferred_protein_name;
        }
      } 

      # Using a hash, map all protIDs to the preferred one
      for my $protID (@indis) {
	$self->{ProteinProphet_prot_data}->{preferred_protID_hash}->
	  {$protID} = $preferred_protein_name;
      }

      # Note that we've processed the protein info.
      $self->{protcache}->{indistinguishables_processed} = 1;
    }
  }

  #### Push information about this element onto the stack
  my $tmp;
  $tmp->{name} = $localname;
  push(@{$self->object_stack},$tmp);


  #### Increase the counters and print some progress info
  #$self->{counter}++;
  #print $self->{counter}."..." if ($self->{counter} % 100 == 0);

} # end protXML_start_element



###############################################################################
# end_element
###############################################################################
sub end_element {
  my ($self,$uri,$localname,$qname) = @_;

  if ($self->{document_type} eq 'pepXML') {
    pepXML_end_element(@_);
  } elsif ($self->{document_type} eq 'protXML') {
      protXML_end_element(@_);
  } else {
    die("ERROR: Unknown document_type '$self->{document_type}'");
  }

  return(1);
}



###############################################################################
# pepXML_end_element
###############################################################################
sub pepXML_end_element {
  my ($self,$uri,$localname,$qname) = @_;

  #### If this is the end of the spectrum_query, store the information if it
  #### passes the threshold
  if ($localname eq 'spectrum_query') {
    my $peptide_sequence = $self->{pepcache}->{peptide};

    my $probability;
    if ($peptide_sequence) {
      $probability = $self->{pepcache}->{scores}->{probability};
    } else {
      print "WARNING: No search result for this query!\n";
      $probability = -1;
    }

    #### If this PSM has a probability > 0.5, store it.
    #### This should get all or nearly all the PSMs we want
    #### for a ProteinProphet-adjusted probability threshold
    #### of 0.9 or FDR threshold of 0.0001. Bizarrely low prob.
    #### thresholds or high FDR thresholds will not get good
    #### results, though.
    if ( $probability >= $PEP_PROB_CUTOFF) {

      #### Create the modified peptide string
      my $prepend_charge = 0;
      my $charge = $self->{pepcache}->{charge};

      if ($self->{pepcache}->{ptm_peptide}){
        my @ss1 =  split(/\)/, $self->{pepcache}->{ptm_peptide});
        my $pos = 0;
        foreach my $s (@ss1){
          if ($s =~ /(.*)\(([\d\.]+)/){
            $pos += length($1);
            if ($self->{pepcache}->{modifications}{$pos}){
               $self->{pepcache}->{modifications}{$pos} .= "($2)";
             }else{
               $self->{pepcache}->{modifications}{$pos} = "($2)";
             }
          }else{
            $pos += length($1);
          }
        }
      }
      $peptide_sequence =~ s/[\r\n]//g;

      my $modified_peptide = modified_peptide_string($self, $peptide_sequence, $charge,
          $self->{pepcache}->{modifications}, $prepend_charge);
      
      my $peptide_accession = &main::getPeptideAccession(
        sequence => $peptide_sequence,
      );
      
      #### Select a protein_name to store.
      #my $protein_name = pop(@{$self->{pepcache}->{protein_name}});

      my $protein_name ='';
      $protein_name = 
      SBEAMS::PeptideAtlas::ProtInfo::get_preferred_protid_from_list(
        protid_list_ref=>$self->{pepcache}->{protein_name},
				preferred_patterns_aref => $preferred_patterns_aref,
				swiss_prot_href => $swiss_prot_href,
      );

      #### Store the information for this peptide into an array for caching
      push(@{ $self->{pep_identification_list} },
          [$self->{search_batch_id},
					 $self->{pepcache}->{spectrum},
					 $peptide_accession,
					 $peptide_sequence,
					 $self->{pepcache}->{peptide_prev_aa},
					 $modified_peptide,
					 $self->{pepcache}->{peptide_next_aa},
					 $charge,
           $probability,
           $self->{pepcache}->{massdiff},
           #need to store protein_name in case no protXML info
           #$self->{pepcache}->{protein_name},
           $protein_name,
           $self->{pepcache}->{precursor_intensity},
           $self->{pepcache}->{total_ion_current},
           $self->{pepcache}->{signal_to_noise},
           $self->{pepcache}->{retention_time_sec},
					]
      );
    }


    #### Clear out the cache
    delete($self->{pepcache});

    #### Increase the counters and print some progress info
    $self->{counter}++;
    print "$self->{counter}..." if ($self->{counter} % 1000 == 0);

  }


  #### If there's an object on the stack consider popping it off
  if (scalar @{$self->object_stack()}){

    #### If the top object on the stack is the correct one, pop it off
    #### else die bitterly

    if ($self->object_stack->[-1]->{name} eq "$localname") {
      pop(@{$self->object_stack});
    } else {
      die("STACK ERROR: Wanted to pop off an element of type '$localname'".
        " but instead we found '".$self->object_stack->[-1]->{name}."'!");
    }

  } else {
    die("STACK ERROR: Wanted to pop off an element of type '$localname'".
        " but instead we found the stack empty!");
  }

}


###############################################################################
# protXML_end_element
###############################################################################
sub protXML_end_element {
  my ($self,$uri,$localname,$qname) = @_;

  #### Figure out what kind of info we want to store from this protXML.
  my $this_is_master = ($self->{protxml_type} eq 'master');
  my $have_master = $self->{OPTIONS}->{master_ProteinProphet_file};
  my $per_expt = $self->{OPTIONS}->{per_expt_pipeline} || !$have_master;
  my $get_best_pep_probs = (!$per_expt || !$this_is_master) ;
  my $assign_protids = ($this_is_master || !$have_master);
  my $store_info_for_presence_level = $this_is_master;

  ## store indistinguishable_peptide
  if ($localname eq 'indistinguishable_peptide'){
    my $peptide = $self->{pepcache}->{indistinguishable_peptides}->{peptide_sequence};
    my $c = $self->{pepcache}->{indistinguishable_peptides}->{charge};
    my $modified_pep = modified_peptide_string($self, $peptide, $c,
          $self->{pepcache}->{modifications}, 1);
    $self->{pepcache}->{indistinguishable_peptides}->{$modified_pep} = 1;
    $self->{pepcache}->{modifications} = {};
  }


  #### If this is a peptide, then store its info in a protXML info cache
  ####  Each <peptide> is enclosed within a <protein>.
  if ($localname eq 'peptide') {
    my $peptide_sequence = $self->{pepcache}->{peptide}
      || die("ERROR: No peptide sequence in the cache!");

    # Store this peptide's Protein Prophet probs so that it's available to
    #   modify this peptide's PeptideProphet or iProphet probability.
    # Most peptide info, including string, charge, and prob,
    #  have been stored in ProteinProphet_pep_data.
    # Protein identification and protein probabilities are here 
    #  stored in ProteinProphet_pep_protID_data.
    # Peptide, including charge and modifications, stored in $pep_key.

  my $debug = 0;

    my $charge = $self->{pepcache}->{charge};
    my $modifications = $self->{pepcache}->{modifications};
    # store info on this pep in $self->{ProteinProphet_pep_data}->{$pep_key}
    my $pep_key = storePepInfoFromProtXML( $self, $peptide_sequence,
         $charge, $modifications, $get_best_pep_probs);
  #$debug = 1 if ($pep_key eq "YALLPHLYTLFHQAHVAGETVARPLFLEFPK");
    if ($debug) {
      print "looking at $pep_key, a pep presumably in the <protein> record for $self->{protein_name}\n";
    }
    if ( $assign_protids ) {
      assignProteinID($self, $pep_key);
    }

    #### If there are indistinguishable peptides, store their info, too
    #### Indistinguishable peptides were stored unstripped (with charge & mod),
    #### so no need to pass charge/mod.
    foreach my $indis_peptide (
       keys(%{$self->{pepcache}->{indistinguishable_peptides}}) ) {
       my $pep_key = storePepInfoFromProtXML( $self, $indis_peptide, "", {},
             $get_best_pep_probs);
       if ( $assign_protids ) {
	     assignProteinID($self, $pep_key);
       }
    }

    if ( $store_info_for_presence_level) {
      #### add current protein to global list of proteins this pep maps to
      ####  (this list does not include indistinguishable proteins)
      my $this_protein = $self->{protein_name};
      if (! defined $self->{ProteinProphet_prot_data}->{pep_prot_hash}->
	       {$peptide_sequence}) {
	@{$self->{ProteinProphet_prot_data}->{pep_prot_hash}->
	       {$peptide_sequence}} = ($this_protein);
      } else {
	push(@{$self->{ProteinProphet_prot_data}->{pep_prot_hash}->
	       {$peptide_sequence}}, $this_protein);
      }
      #### add this peptide's observations to PSM_count for this protein
      my $PSMs;
      if ($apportion_PSMs) {
        $PSMs = $self->{pepcache}->{expected_apportioned_observations};
      } else {
        $PSMs = $self->{pepcache}->{n_instances};
      }
      $self->{protcache}->{PSM_count} += $PSMs;

      #### add to the running tally of enzymatic termini in this prot
      $self->{protcache}->{total_enzymatic_termini} +=
	 $self->{pepcache}->{n_enzymatic_termini};
    }

    #### clear out the peptide cache
    delete($self->{pepcache});

    #### increase the counters and print some progress info
    $self->{protcounter}++;
    print "." if ($self->{protcounter} % 100 == 0);
  }

  #### if this is a protein, then store its info in its group
  if ($localname eq 'protein') {
    if ($store_info_for_presence_level) {

      my $protein_name = $self->{protein_name};
      # store the (non-preferred) indistinguishable proteins,
      #  unique stripped peptides, probability, confidence, and
      #  subsuming protein entry in the group cache, in a hash
      # keyed by the preferred protein.
      $self->{groupcache}->{proteins}->{$protein_name}->{indist_prots} =
             $self->{protcache}->{indist_prots};
      $self->{groupcache}->{proteins}->{$protein_name}->
	                                   {unique_stripped_peptides} = 
             $self->{protcache}-> {unique_stripped_peptides};
      $self->{groupcache}->{proteins}->{$protein_name}->{probability} =
             $self->{protcache}->{probability};
      $self->{groupcache}->{proteins}->{$protein_name}->{confidence} =
             $self->{protcache}->{confidence};
      $self->{groupcache}->{proteins}->{$protein_name}->{npeps}
             = $self->{protcache}->{npeps};
      $self->{groupcache}->{proteins}->{$protein_name}->{total_number_peptides}
             = $self->{protcache}->{total_number_peptides};
      $self->{groupcache}->{proteins}->{$protein_name}->
	                                   {subsuming_protein_entry} =
             $self->{protcache}->{subsuming_protein_entry};
      $self->{groupcache}->{proteins}->{$protein_name}->{PSM_count} =
             $self->{protcache}->{PSM_count};
      $self->{groupcache}->{proteins}->{$protein_name}->
                                            {total_enzymatic_termini} =
             $self->{protcache}->{total_enzymatic_termini};

      # Store the group number for this protein in a persistent hash.
      $self->{ProteinProphet_prot_data}->{group_hash}->{$protein_name} =
	$self->{protein_group_number};
    }

    #### Clear out the protein cache
    delete($self->{protcache});
  }

  #### If this is a protein group, then store its info
  if ($localname eq 'protein_group') {
    if ($store_info_for_presence_level) {

      # Store the group probability
      $self->{groupcache}->{probability} = $self->{protein_group_probability};

      # Store all the collected info on this group in a persistent hash.
      my $group_num = $self->{protein_group_number};
      $self->{ProteinProphet_group_data}->{$group_num} = $self->{groupcache};
    }

    #### Clear out the protein group cache
    delete($self->{groupcache});
  }

  #### If there's an object on the stack consider popping it off
  if (scalar @{$self->object_stack()}){

    #### If the top object on the stack is the correct one, pop it off
    #### else die bitterly
    if ($self->object_stack->[-1]->{name} eq "$localname") {
      pop(@{$self->object_stack});
    } else {
      die("STACK ERROR: Wanted to pop off an element of type '$localname'".
        " but instead we found '".$self->object_stack->[-1]->{name}."'!");
    }

  } else {
    die("STACK ERROR: Wanted to pop off an element of type '$localname'".
        " but instead we found the stack empty!");
  }

}


###############################################################################
# storePepInfoFromProtXML
###############################################################################
# For a given <peptide> tag in a protXML file, store the
# ProteinProphet info on the modified peptide (pep_key) in a hash.
# There may be multiple <peptide> tags per pep_key, each stored
#  within a different <protein> tag.
# So, if requested, store the best probability among all <peptide>
# tags associated with each pep_key.

sub storePepInfoFromProtXML {
  my $self = shift;
  my $peptide_sequence = shift;
  my $charge = shift;
  my $modifications = shift;
  my $get_best_pep_probs = shift;

  my $initial_probability = $self->{pepcache}->{initial_probability};
  my $adjusted_probability = $self->{pepcache}->{nsp_adjusted_probability};

  #### Create the modified peptide string
  my $prepend_charge = 1;
  my $pep_key =  modified_peptide_string($self, $peptide_sequence, $charge,
       $modifications, $prepend_charge);

  #### INFO: as of 12/18/08, iProphet or ProteinProphet drops mod and
  #### charge info, so at this point $pep_key eq $peptide_sequence.
  #### 06/23/09: I don't know where I got this idea from. Some, if not all,
  #### indistinguishable peptides have charge and mod info.

  # create shorthand for this hash ref
  my $pepProtInfo = $self->{ProteinProphet_pep_data}->{$pep_key};

  # create new hash entry if doesn't yet exist
  if ( !defined $pepProtInfo ) {
    $pepProtInfo = {
      search_batch_id => $self->{search_batch_id},
      charge => $charge,
      initial_probability => $initial_probability,
      nsp_adjusted_probability => $adjusted_probability,
      n_adjusted_observations => $self->{pepcache}->{n_instances},
      n_sibling_peptides => $self->{pepcache}->{n_sibling_peptides},
    };
    $self->{ProteinProphet_pep_data}->{$pep_key} = $pepProtInfo;

  # if it already exists, but new init_prob is better
  # (or if init_prob is same but adjusted_prob is better), replace
  } elsif ($get_best_pep_probs) {
    if ( ( $initial_probability > $pepProtInfo->{initial_probability}) ||
          (( $initial_probability == $pepProtInfo->{initial_probability}) &&
           ( $adjusted_probability > $pepProtInfo->{nsp_adjusted_probability}))
       ) {
      $pepProtInfo->{search_batch_id} = $self->{search_batch_id};
      $pepProtInfo->{charge} = $charge;
      $pepProtInfo->{initial_probability} = $initial_probability;
      $pepProtInfo->{nsp_adjusted_probability} = $adjusted_probability;
      $pepProtInfo->{n_adjusted_observations} =
                               $self->{pepcache}->{n_instances};
      $pepProtInfo->{n_sibling_peptides} =
                               $self->{pepcache}->{n_sibling_peptides};
    }
  }

  return ($pep_key);
}


###############################################################################
# modified_peptide_string
###############################################################################
#### Create a single string from pep seq, charge, and mods
#### This string will be a key for storing pepXML and protXML info.
sub modified_peptide_string {
  my $self = shift;
  my $peptide_sequence = shift;
  my $charge = shift;
  my $modifications = shift;
  my $prepend_charge = shift;

  my $modified_peptide = '';
  my $pep_key = '';
  if ($modifications) {
    my $i = 0;
    if ($modifications->{$i}) {
      #$modified_peptide .= 'n['.int($modifications->{$i}).']';
      $modified_peptide .= 'n['. sprintf("%.0f", $modifications->{$i}) .']';
    }
	 for ($i=1; $i<=length($peptide_sequence); $i++) {
		 my $aa = substr($peptide_sequence,$i-1,1);
		 if ($modifications->{$i}) {
			if ($modifications->{$i} =~ /([\d\.]+)\((.*)/){
				#$aa .= '['.int($1).']('.$2;
        $aa .= '['. sprintf("%.0f", $1) .']('.$2;
			}elsif($modifications->{$i} =~ /^\((.*)\)$/){
				 $aa .= "($1)";
			}else{
				#$aa .= '['.int($modifications->{$i}).']';
        $aa .= '['. sprintf("%.0f", $modifications->{$i}) .']';
			}
		 }
		 $modified_peptide .= $aa;
    }
    if ($modifications->{$i}) {
      print $modifications->{$i} ."\n";

      #$modified_peptide .= 'c['.int($modifications->{$i}).']';
      $modified_peptide .= 'c['. sprintf("%.0f", $modifications->{$i}) .']';
    }
  } else {
    $modified_peptide = $peptide_sequence;
  }


  # If there is a charge, and if desired, prepend charge to peptide string
  if ($charge && $prepend_charge) {
    $pep_key = sprintf("%s-%s", $charge, $modified_peptide);
  } else {
    $pep_key = $modified_peptide;
  }
  return ($pep_key);
}


###############################################################################
# assignProteinID
###############################################################################
# For a given <peptide> tag in a protXML file, store the protein ID 
# that is most likely to actually have been observed among all
# <protein> tags containing that pep_key (includes mods and charge).
# This will always assign the same protein to a particular peptide,
# and should give us a fairly minimal and high-quality set of protein
# identifications for the PAidentlist, allowing it to
# be used as input to Mayu.

sub assignProteinID {
  my $self = shift;
  my $pep_key = shift;
  my $debug = 0;
  #$debug = 1 if ($pep_key eq "YALLPHLYTLFHQAHVAGETVARPLFLEFPK");

  # Other data (peptide string, charge, prob) should already be stored.
  if ( !defined $self->{ProteinProphet_pep_data}->{$pep_key} ) {
    print "ERROR: no data yet stored for $pep_key in assignProteinID.\n";
  }

  # create hash ref, if necessary, and define a nickname for it
  if (!defined $self->{ProteinProphet_pep_protID_data}->{$pep_key}) {;
    $self->{ProteinProphet_pep_protID_data}->{$pep_key} = {};
  }
  my $pepProtInfo = $self->{ProteinProphet_pep_protID_data}->{$pep_key};
  # define a couple of anonymous subroutines
  my $new_prot_is_better_than_best_so_far_sub = sub {
    return ( 
      SBEAMS::PeptideAtlas::ProtInfo::more_likely_protein_identification (
        preferred_patterns_aref=>$preferred_patterns_aref,
	swiss_prot_href => $swiss_prot_href,
	protid1=>$pepProtInfo->{protein_name},
	protid2=>$self->{protein_name},
	prob1=>$pepProtInfo->{protein_probability},
	prob2=>$self->{protein_probability},
        # 02/08/10: disabled below, because unsure whether info in
        # {protcache} is current at this point
#	npeps1=>$pepProtInfo->{protcache}->{npeps},
#	npeps2=>$self->{protcache}->{npeps},
#	# PSM_count, enz_termini will always be zero; haven't been counted yet
      ) eq $self->{protein_name} ) ;
  };

  my $make_new_prot_best_so_far_sub = sub {
    $pepProtInfo->{protein_name} = $self->{protein_name};
    $pepProtInfo->{protein_group_probability} =
		    $self->{protcache}->{protein_group_probability};
    $pepProtInfo->{protein_probability} = $self->{protein_probability};
#    $pepProtInfo->{npeps} = $self->{protcache}->{npeps};
  };

  # first time we've tried to assign a protein to this peptide
  if (!defined $pepProtInfo->{protein_name} ) {
    $make_new_prot_best_so_far_sub->();
    print "Assigning $pepProtInfo->{protein_name} P=$pepProtInfo->{protein_probability} as best prot for $pep_key\n" if ($debug);
  # we've already made an assignment to this pep. Is this one better?
  } else {
    if ( $new_prot_is_better_than_best_so_far_sub->() ) {
      print "Replacing $pepProtInfo->{protein_name} P=$pepProtInfo->{protein_probability} with $self->{protein_name} P=$self->{protein_probability} as best prot for $pep_key\n" if ($debug);
      $make_new_prot_best_so_far_sub->();
    } else {
      print "Not replacing $pepProtInfo->{protein_name} P=$pepProtInfo->{protein_probability} with $self->{protein_name} P=$self->{protein_probability} as best prot for $pep_key\n" if ($debug);
    }
  }
}


###############################################################################
###############################################################################
###############################################################################
# continuation of main package
###############################################################################
package main;

my $CONTENT_HANDLER;

#### Do the SBEAMS authentication and exit if a username is not returned
exit unless ($current_username =
    $sbeams->Authenticate(work_group=>'PeptideAtlas_admin'));


#### Print the header, do what the program does, and print footer
$sbeams->printPageHeader();
main();
$sbeams->printPageFooter();

###############################################################################
# Main part of the script
###############################################################################
sub main {

  #### Print out the header
  unless ($QUIET) {
    $sbeams->printUserContext();
    print "\n";
  }

  #### Process additional input parameters
  my $P_threshold = $OPTIONS{P_threshold} || '';
  my $FDR_threshold = $OPTIONS{FDR_threshold} || '';
  unless ($protlist_only || $APD_only) {
    if ( $FDR_threshold && $P_threshold) {
      print "Only one of --P_threshold and --FDR_threshold may be specified.\n";
      exit;
    } elsif (!$FDR_threshold && !$P_threshold) {
      $FDR_threshold = '0.0001';
      print "Using default FDR threshold $FDR_threshold.\n";
      #$P_threshold = '0.9';
      #print "Using default P threshold $P_threshold.\n";
    } else {
      print "P_threshold=$P_threshold  FDR_threshold=$FDR_threshold\n";
    }
  }

  unless ($protlist_only) {
    ## check that --output_file was passed and that the directory of output_file exists
    my $check_dir = $OPTIONS{output_file} || die "need output file path: --output_file";
    $check_dir =~ s/(.+)\/(.*)$/$1/gi;
    if (-d $check_dir)
    {
      print "Checked: The output directory ($check_dir) exists\n";
    } else
    {
      print "ERROR: The output directory ($check_dir) does not exist($!)\n";
      exit;
    }
  }


  #### Set up the Xerces parser
  my $parser = XML::Xerces::XMLReaderFactory::createXMLReader();

  $parser->setFeature("http://xml.org/sax/features/namespaces", $namespace);

  if ($validate eq $XML::Xerces::SAX2XMLReader::Val_Auto) {
    $parser->setFeature("http://xml.org/sax/features/validation", 1);
    $parser->setFeature("http://apache.org/xml/features/validation/dynamic",1);

  } elsif ($validate eq $XML::Xerces::SAX2XMLReader::Val_Never) {
    $parser->setFeature("http://xml.org/sax/features/validation", 0);

  } elsif ($validate eq $XML::Xerces::SAX2XMLReader::Val_Always) {
    $parser->setFeature("http://xml.org/sax/features/validation", 1);
    $parser->setFeature("http://apache.org/xml/features/validation/dynamic",0);
  }

  $parser->setFeature("http://apache.org/xml/features/validation/schema",
    $schema);


  #### Create the error handler and content handler
  my $error_handler = XML::Xerces::PerlErrorHandler->new();
  $parser->setErrorHandler($error_handler);

  $CONTENT_HANDLER = MyContentHandler->new();

  $parser->setContentHandler($CONTENT_HANDLER);

  $CONTENT_HANDLER->setVerbosity($VERBOSE);
  $CONTENT_HANDLER->{counter} = 0;
  $CONTENT_HANDLER->{P_threshold} = $P_threshold;
  $CONTENT_HANDLER->{FDR_threshold} = $FDR_threshold;
  $CONTENT_HANDLER->{OPTIONS} = \%OPTIONS;

  my %decoy_corrections;
  my $combined_identlist_file = "DATA_FILES/PeptideAtlasInput_concat.PAidentlist";
  my $sorted_identlist_file = "DATA_FILES/PeptideAtlasInput_sorted.PAidentlist";
  my @column_names = qw ( search_batch_id
                          spectrum_query
                          peptide_accession
                          peptide_sequence
                          preceding_residue
                          modified_peptide_sequence
                          following_residue
                          charge
                          probability
                          massdiff
                          protein_name
                          protXML_nsp_adjusted_probability
                          protXML_n_adjusted_observations
                          protXML_n_sibling_peptides
                          precursor_intensity
                          total_ion_current
                          signal_to_noise );

  unless ($APD_only) {
    #### If a list of search_batch_ids was provided, find the corresponding
    #### documents
    if ($search_batch_ids && 0) {
      my @search_batch_ids = split(/,/,$search_batch_ids);
      foreach my $search_batch_id (@search_batch_ids) {
				my $ProteinProphet_file = guess_source_file(
					search_batch_id => $search_batch_id,
				);
				if ($ProteinProphet_file) {
					#$documents{$ProteinProphet_file}->{search_batch_id} = $search_batch_id;
				} else {
					die("ERROR: Unable to determine document for search_batch_id ".
							"$search_batch_id");
				}
      }
    }
  }

  #### Array of documents to process in order
  my @documents;

  #### If a source file containing the list of search_batch_ids was provided,
  #### read it and find the corresponding documents
  if ($source_file && !$protlist_only) {
    my @search_batch_ids;
    open(SOURCE_FILE,$source_file)
      || die("ERROR: Unable to open $source_file");
    while (my $line = <SOURCE_FILE>) {
      chomp($line);
      next if ($line =~ /^\s*#/);   #comment
      next if ($line =~ /^\s*$/);   #empty line
      my ($search_batch_id,$path) = split(/\s+/,$line);
      my $filepath = $path;

      # Modified to use library method, found in SearchBatch.pm.  New file
      # names should be added there; the preferred list below is considered
      # first before default names, allows caller to determine priority.
      if ($filepath !~ /\.xml/) {
          my @preferred = ( 
                        'interact-ipro-ptm.pep.xml',   # ptm prophet output
                        'interact-ipro.pep.xml',       #iProphet output
                         );

        $filepath = $sbeamsMOD->findPepXMLFile( preferred_names => \@preferred,
				                                        search_path => $filepath );

	      unless ( $filepath ) {
          print "ERROR: Unable to auto-detect an interact file in $path\n";
          next;
        }
      }



      unless ( -e $filepath ) {
        print "ERROR: Specified interact file '$filepath' does not exist!\n";
        next;
      }


      my ($pepXML_document);

      $pepXML_document->{filepath} = $filepath;
      $pepXML_document->{search_batch_id} = $search_batch_id;
      $pepXML_document->{document_type} = 'pepXML';
      push(@documents,$pepXML_document);
      print "Will use $pepXML_document->{filepath} or its template file\n";

      push(@search_batch_ids,$search_batch_id);
    }
    $search_batch_ids = join(',',@search_batch_ids);
  }

  unless ($APD_only) {

    #### If $splib_filter specified, read the SpectraST library
    my $spectral_peptides;

    if ($splib_filter && !$protlist_only) {
      print "Will filter peptides not in ${build_version}_all_Q2.sptxt.\n";
      $spectral_peptides = readSpectralLibraryPeptides(
	input_file => "DATA_FILES/${build_version}_all_Q2.sptxt",
      );
    }

    #### Loop over all input files converting pepXML to identlist format
    #### unless it has already been done
    my @identlist_files;

    #### First pass: read or create cache files,
    ####  saving best probabilities for each stripped and unstripped peptide
    if ($protlist_only) {
      print "Will create protlist file only, using existing PAidentlist files.\n";
    } else {

      if ($best_probs_from_protxml) {
				print "Will get best initial probs from protXML file[s].\n";
      } else {
				print "Will get best initial probs from pepXML files or their templates.\n";
				$CONTENT_HANDLER->{best_prob_per_pep} = {};
      }

      print "First pass over pepXML files/caches: saving best prob for each pep.\n";
      foreach my $document ( @documents ) {
				my $filepath = $document->{filepath};
				$CONTENT_HANDLER->{search_batch_id} = $document->{search_batch_id};
				$CONTENT_HANDLER->{document_type} = $document->{document_type};
				$CONTENT_HANDLER->{pep_identification_list} = [];

				#### Determine the identlist file path and name
				my $identlist_file = $filepath;
				$identlist_file =~ s/\.xml$/.PAidentlist/;
				push(@identlist_files,$identlist_file);

				#### If the identlist template file already exists, read that instead of pepXML
				if ( -e "${identlist_file}-template") {
					readIdentificationListTemplateFile(
						input_file => "${identlist_file}-template",
            best_probs_from_protxml => $best_probs_from_protxml,
            best_prob_per_pep => $CONTENT_HANDLER->{best_prob_per_pep},
					);

				#### Otherwise read the pepXML
				} else {
          undef $CONTENT_HANDLER->{best_prob_per_pep};
          $CONTENT_HANDLER->{best_prob_per_pep} = {};
					print "INFO: Reading $filepath; saving records with prob >= $PEP_PROB_CUTOFF...\n"
					 unless ($QUIET);
					$CONTENT_HANDLER->{document_type} = $document->{document_type};
					$parser->parse (XML::Xerces::LocalFileInputSource->new($filepath));
					print "\n";

					#### Write out the template cache file
					writePepIdentificationListTemplateFile(
            pep_identification_list => $CONTENT_HANDLER->{pep_identification_list},
						output_file => "${identlist_file}-template",
							best_probs_from_protxml => $best_probs_from_protxml,
							best_prob_per_pep => $CONTENT_HANDLER->{best_prob_per_pep},
					);
					if (!$best_probs_from_protxml) {
						saveBestProbPerPep(
							best_prob_per_pep => $CONTENT_HANDLER->{best_prob_per_pep},
							pep_identification_list => $CONTENT_HANDLER->{pep_identification_list},
						);
					}

				}
				#print "best_prob_per_pep: " , scalar keys %{$CONTENT_HANDLER->{best_prob_per_pep}};
				#print "\n";
			}## end First pass
		} # end unless $protlist_only

    #### Development/debugging: print the best prob for each pep
    if (!$best_probs_from_protxml && 0) {
      showBestProbPerPep(
				best_prob_per_pep => $CONTENT_HANDLER->{best_prob_per_pep},
			);
    }


    #### If a master ProteinProphet file was specified, process it.
    my $proteinProphet_filepath = $OPTIONS{master_ProteinProphet_file};
    if ($proteinProphet_filepath) {

      $CONTENT_HANDLER->{ProteinProphet_pep_data} = {};
      # check for existence of file; print informational messages
      unless (-e $proteinProphet_filepath) {
				die("ERROR: Specified master ProteinProphet file not found '$proteinProphet_filepath'\n");
      }
      print "INFO: Reading master ProteinProphet file $proteinProphet_filepath...\n" unless ($QUIET);
      if (!$QUIET && !$protlist_only) {
				if ($OPTIONS{per_expt_pipeline}) {
					print "      Will use only to assign protein ".
					"identifications to peptides;\n           individual protxml".
					" files will be used to adjust probabilities.\n";
				} else {
					print "      Will use instead of individual protXML files".
					" to update probabilities.\n";
				}
      }

      $CONTENT_HANDLER->{document_type} = 'protXML';
      $CONTENT_HANDLER->{protxml_type} = 'master';
      $parser->parse (XML::Xerces::LocalFileInputSource->new($proteinProphet_filepath));
      print "\n";

    }

    #### Development: see if the protein info got stored.
    #print_protein_info();

    #### Second pass: read individual ProteinProphet file(s) if there
    ####  is no master, read each cache file again,
    ####  then write out all the peptides and probabilities including
    ####  ProteinProphet information

    unless ($protlist_only) {

     print "Second pass over caches: write final peptide identlist files.\n";

      my $first_loop = 1;

      foreach my $document ( @documents ) {
				my $filepath = $document->{filepath};

				$CONTENT_HANDLER->{search_batch_id} = $document->{search_batch_id};
				$CONTENT_HANDLER->{document_type} = $document->{document_type};
				$CONTENT_HANDLER->{pep_identification_list} = [];

				#### If no master, or if per-experiment pipeline,
				#### we'll read one ProteinProphet file per pepXML file
				if (!$OPTIONS{master_ProteinProphet_file} ||
					 $OPTIONS{per_expt_pipeline}) {
					$CONTENT_HANDLER->{ProteinProphet_pep_data} = {};
					$proteinProphet_filepath = $filepath;
					$proteinProphet_filepath =~ s/\.pep.xml/.prot.xml/;

					unless (-e $proteinProphet_filepath) {
					#### Hard coded funny business for Novartis
						if ($proteinProphet_filepath =~ /Novartis/) {
							if ($proteinProphet_filepath =~ /interact-prob_\d/) {
								$proteinProphet_filepath =~ s/prob_\d/prob_all/;
							}
						}
					}
					#### Hard coded correction for filename convention introduced
					#### early 2009: iProphet output is interact-ipro.prot.xml,
					#### but ProtPro output is interact-prob.prot.xml.
					unless (-e $proteinProphet_filepath) {
						if ($proteinProphet_filepath =~ /ipro.prot.xml/) {
							$proteinProphet_filepath =~ s/ipro.prot.xml/prob.prot.xml/;
						}
					}
					unless (-e $proteinProphet_filepath) {
							print "ERROR: ProteinProphet file $proteinProphet_filepath ".
								"not found.\n";
							$proteinProphet_filepath = undef;
					}

					if ($proteinProphet_filepath) {
						print "INFO: Reading $proteinProphet_filepath...\n" unless ($QUIET);
						$CONTENT_HANDLER->{document_type} = 'protXML';
						$CONTENT_HANDLER->{protxml_type} = 'expt';
						$parser->parse (XML::Xerces::LocalFileInputSource->new($proteinProphet_filepath));
						print "\n";
					}
				}


				#### Development: check the hash mapping protein names to group numbers.
				####  Hmm, this may belong after reading the master ProtPro file, not here!
				my $prot_href = $CONTENT_HANDLER->{ProteinProphet_prot_data}->{group_hash};
				my @protein_list = keys(%{$prot_href});
				foreach my $prot_name (sort @protein_list) {
					#print "$prot_name $prot_href->{$prot_name}\n";
				}

				#### Check to see if there's a decoy correction coefficient
				#### This is very fudgy. This code should be off in SVN and only
				#### enabled for testing
				my $decoy_file = $filepath;
				$decoy_file =~ s/\.xml$/.decoy.txt/;
				if ( -e $decoy_file && 0) {  #### && 0 means this is disabled!!
					open(DECOYFILE,$decoy_file);
					while (my $line = <DECOYFILE>) {
						chomp($line);
						my @columns = split("\t",$line);
						if ($columns[0] == 3) {
							my $decoy_correction = ( $columns[1] + $columns[2] ) / 2.0;
							print "INFO: Decoy correction = $decoy_correction\n";
							$decoy_corrections{$document->{search_batch_id}} = $decoy_correction;
						}
					}
					close(DECOYFILE);
				} else {
					#print "WARNING: No decoy correction\n";
				}

				#### Read the peptide identlist template file,
				#### then write the final peptide identlist file
        #### TMF add $version, $date to filename
				my $identlist_file = $filepath;
				$identlist_file =~ s/\.xml$/.PAidentlist/;

        #### TMF allow date at end of filename; get file with most
        ####  recent date.
				if ( -e "${identlist_file}-template") {
          #readIdentificationListTemplateFile(
          #  input_file => "${identlist_file}-template",
          #  best_probs_from_protxml => $best_probs_from_protxml,
          #  best_prob_per_pep => $CONTENT_HANDLER->{best_prob_per_pep},
          #);

				} else {
					die("ERROR: ${identlist_file}-template not found\n");
				}
				writePepIdentificationListFile(
					output_file => $identlist_file,
          input_file => "${identlist_file}-template",
					#pep_identification_list=> $CONTENT_HANDLER->{pep_identification_list},
					ProteinProphet_pep_data=> $CONTENT_HANDLER->{ProteinProphet_pep_data},
					ProteinProphet_pep_protID_data => $CONTENT_HANDLER->{ProteinProphet_pep_protID_data},
					spectral_library_data => $spectral_peptides,
					P_threshold => $P_threshold,
					FDR_threshold => $FDR_threshold,
					best_prob_per_pep => $CONTENT_HANDLER->{best_prob_per_pep},
				);
				$first_loop = 0;
      } #end second pass over peptide caches

      #### TEST: list hash of peps to proteins
      if (0) {
				my @peplist = keys(%{$CONTENT_HANDLER->{ProteinProphet_prot_data}->
				{pep_prot_hash}});
				for my $pep (@peplist) {
					print "$pep ";
					my @protid_list = @{$CONTENT_HANDLER->{ProteinProphet_prot_data}->
						{pep_prot_hash}->{$pep}};
					for my $protid ( @protid_list) {
						print "$protid ";
					}
				  print "\n";
				}
      }
	 


      #### Create a combined identlist file
      open(OUTFILE,">$combined_identlist_file") ||
	die("ERROR: Unable to open for write '$combined_identlist_file'");
      close(OUTFILE);

      #### TMF Write header to combined identlist file
      ####  Date, $VERSION, 

      #### Loop over all cache files and add to combined identlist file
      foreach my $identlist_file ( @identlist_files ) {
	print "INFO: Adding to master list: '$identlist_file'\n";
	system("grep -v '^search_batch_id' $identlist_file >> $combined_identlist_file");
      }


      #### If we have decoy corrections, apply them and write out a new file
      if (%decoy_corrections) {
	my $output_file = $combined_identlist_file;
	$output_file =~ s/concat/concor/;
	apply_decoy_corrections(
	  input_file => $combined_identlist_file,
	  output_file => $output_file,
	  decoy_corrections => \%decoy_corrections,
	);
      }


      #### Create a copy of the combined file sorted by peptide.
      print "INFO: Creating copy of master list sorted by peptide\n";
      system("sort -k 3,3 -k 2,2 $combined_identlist_file > $sorted_identlist_file");
      #print "Created!\n";
      #exit;

      #### Get the columns headings
      open(INFILE,$identlist_files[0]) ||
	die("ERROR: Unable to open for read '$identlist_files[0]'");
      my $header = <INFILE> ||
	die("ERROR: Unable to read header from '$identlist_files[0]'");
      close(INFILE);
      chomp($header);
      @column_names = split("\t",$header);

    } # end unless $protlist_only

    #### TEST: list hash of peps to proteins
    if (0) {
      my @peplist = keys(%{$CONTENT_HANDLER->{ProteinProphet_prot_data}->
	    {pep_prot_hash}});
      for my $pep (@peplist) {
	print "$pep ";
	my @protid_list = @{$CONTENT_HANDLER->{ProteinProphet_prot_data}->
	    {pep_prot_hash}->{$pep}};
	for my $protid ( @protid_list) {
	  print "$protid ";
	}
	print "\n";
      }
    }
	 
    #### If a master ProteinProphet file was provided, we can print lists
    #### of protein identifications, along with presence_levels, for Atlas.

    if ($OPTIONS{master_ProteinProphet_file}) {

      #### For each peptide seen in protXML, get prots
      #### from pep->protlist hash and add them to atlas_prot_list,
      #### the list of all (non-identical) proteins in the atlas.
      $CONTENT_HANDLER->{ProteinProphet_prot_data}->{atlas_prot_list} = {};
      print "INFO: Creating protein list.\n";
      my %peps_not_found = ();
      my @peplist = keys 
         %{$CONTENT_HANDLER->{ProteinProphet_prot_data}->{pep_prot_hash}};
      my $npeps = scalar @peplist;

       for my $pepseq (@peplist) {

				# The below may be undefined if it's an indistinguishable peptide.
				# No harm -- its prots should be stored under its twin.
				if (defined $CONTENT_HANDLER->{ProteinProphet_prot_data}->
					 {pep_prot_hash}->{$pepseq} ) {
					my @pep_protlist = @{$CONTENT_HANDLER->{ProteinProphet_prot_data}->
						 {pep_prot_hash}->{$pepseq}};
								# add each protein that this pep maps to to the atlas prot list
					for my $protid (@pep_protlist) {
						$CONTENT_HANDLER->{ProteinProphet_prot_data}->{atlas_prot_list}->
							 {$protid} = 1;
					}
				} else {
								#03/18/10: we should never get here anymore, because we are
								# getting the peps from the protXML directly.
					$peps_not_found{$pepseq} = 1;
				}
      }

      my @peps_not_found = keys %peps_not_found;
      if (scalar(@peps_not_found) > 0) {
				#03/18/10: we should never get here anymore, because we are
				# getting the peps from the protXML directly.
				print "\nWARNING: No proteins will be stored in PAprotlist for the ";
				print "following\ncombined PAidentlist peptides, because they were ";
				print "not found in the\nmaster protXML file. ";
				print "If few, and all contain L or I,\nthey are probably ";
				print "indistinguishable and the prots are stored\nunder their twins. ";
				print "Otherwise, probably your master protXML was created from\n";
				print "different pepXML files than your PAidentlist was,\n";
				print "and your PAprotlist will be incomplete.\n";
				for my $pep (@peps_not_found) {
					print "$pep\n";
				}
      }

      my $num_atlas_prots = scalar(keys(%{$CONTENT_HANDLER->
	      {ProteinProphet_prot_data}->{atlas_prot_list}}));
      print "$num_atlas_prots distinguishable proteins will be included in this atlas.\n";


      #### Label proteins according to presence level.
      #### Must do this by group. Within each group,
      ####  select highest prob for canonical.
      #### Label others possibly_distinguished or subsumed according to their
      #### prob.

      my @group_list = keys(%{$CONTENT_HANDLER->{ProteinProphet_group_data}});
      for my $group_num (@group_list) {

				my $proteins_href = $CONTENT_HANDLER->{ProteinProphet_group_data}->
							 {$group_num}->{proteins};
				my @protein_list = keys %{$proteins_href};

				my $nproteins = scalar(@protein_list);
				my $highest_prob = -1.0;
				my $highest_nobs = -1;
				my $highest_enz_termini = -1;
				my $prot_group_rep = "";

				# If any proteins in this group will be in atlas ...
				if ( $nproteins > 0 ) {
					# ... determine each protein's presence_level.

					# First, find the highest prob / PSM count protein
					foreach my $protein (@protein_list) {
						my $prot_href = $proteins_href->{$protein};

            # Make this protein the newest $prot_group_rep
            # if it has a higher prob, or same prob but more PSMs,
            # or same prob/PSMs but more enz termini.
						my $most_likely = 
						SBEAMS::PeptideAtlas::ProtInfo::more_likely_protein_identification(
							preferred_patterns_aref=>$preferred_patterns_aref,
							swiss_prot_href => $swiss_prot_href,
							protid1=>$prot_group_rep,
							protid2=>$protein,
							prob1=>$highest_prob,
							prob2=>$prot_href->{probability},
							nobs1=>$highest_nobs,
							nobs2=>$prot_href->{PSM_count},
							enz_termini1=>$highest_enz_termini,
							enz_termini2=>$prot_href->{total_enzymatic_termini},
									);
									if ($most_likely eq $protein) {
							$prot_group_rep = $protein;
							$highest_prob = $prot_href->{probability};
							$highest_nobs = $prot_href->{PSM_count};
							$highest_enz_termini = $prot_href->{total_enzymatic_termini};
						}
					}

          #Next, label subsumed all proteins declared subsumed in protXML

          my @remaining_proteins;
					foreach my $protein (@protein_list) {
						my $prot_href = $proteins_href->{$protein};
						my $is_subsumed = defined $prot_href->{subsuming_protein_entry};
						$prot_href->{represented_by} = $prot_group_rep;
						if ( $is_subsumed ) {
							$prot_href->{presence_level} = "subsumed";
										# create a comma separated list of subsuming proteins
										# using preferred protIDs
							my $subsuming_proteins = $prot_href->{subsuming_protein_entry};
							my @subsuming_proteins = split(/ /,$subsuming_proteins);
							my %matches = ();
							if ($subsuming_proteins ne "") {
					for my $subsuming_prot (@subsuming_proteins) {
						my $preferred_protID = $CONTENT_HANDLER->
								 {ProteinProphet_prot_data}->
								 {preferred_protID_hash}->{$subsuming_prot};
						if (defined $preferred_protID) {
							$subsuming_prot = $preferred_protID;
						} else {
							print "WARNING: subsuming prot for $protein, ".
								"$subsuming_prot, doesn't have preferred protID ".
								" stored in hash.\n";
						}
						my @match = grep /^$subsuming_prot$/, @protein_list;
						if (scalar(@match) > 0) {
							$matches{$subsuming_prot} = 1;
						}
					}
					my $nmatches = scalar(keys %matches);
					my $nsubsuming = scalar(@subsuming_proteins);
					if ( $nmatches > 0 ) {
						$prot_href->{subsumed_by} = join(' ',keys %matches);
					} else {
						print "WARNING: $protein has peptides in this build, but ".
						 "none of its subsuming_protein_entries do: ".
						 "$subsuming_proteins\n";
						$prot_href->{subsumed_by} = '';
					}
	      } else {
					print "WARNING: $protein has empty subsuming_protein_entries ".
								 "attribute.\n";
					$prot_href->{subsumed_by} = '';
							}
						} elsif ($protein ne $prot_group_rep) {
										# create a list of proteins yet to be labeled
										push (@remaining_proteins, $protein);
						}
					}


					# A subset of the atlas proteins in a group is canonical,
					# defined as follows:
					# - subset includes protein_group_representative (found above)
					# - all members of subset are independent of each other
					# - each non-member of the subset is non-independent of at
					#    least one member of the subset.
					# Find one such subset

					my @canonical_set = ($prot_group_rep);

					# Sort remaining proteins by probability so we will favor
					# high prob proteins for canonicals
					sub protids_by_decreasing_probability {
						my $a_info = get_protinfo_href ($a);
						my $b_info = get_protinfo_href ($b);
						- ( $a_info->{probability} <=> $b_info->{probability} );
					}

					@remaining_proteins =
	     (sort protids_by_decreasing_probability @remaining_proteins);

				my @remaining_proteins_copy = @remaining_proteins;

				# Find canonicals and remove from list
				for my $prot (@remaining_proteins_copy) {
					# if this prot is independent from all canonicals in set
					# so far, add it to the set.
					if (is_independent_from_set($prot, \@canonical_set,
						 $proteins_href)) {
						push (@canonical_set, $prot);
						my $found = remove_string_from_array($prot, \@remaining_proteins);
						if (! $found) {
				print "BUG: $prot not found in @remaining_proteins\n";
						}
					}
				}

				@remaining_proteins_copy = @remaining_proteins;

				# For each non-canonical, check to see whether it has same peptide
				# set to any canonical, but better ntt or probability.
				# If so, swap in.
				for my $prot (@remaining_proteins_copy) {

					sub prot1_is_better_than_prot2 {
						my $prot1 = shift;
						my $prot2 = shift;
						my $protinfo1 = get_protinfo_href ($prot1);
						my $protinfo2 = get_protinfo_href ($prot2);
						return
						( SBEAMS::PeptideAtlas::ProtInfo::more_likely_protein_identification(
					preferred_patterns_aref=>$preferred_patterns_aref,
					swiss_prot_href => $swiss_prot_href,
						protid1=>$prot1,
						protid2=>$prot2,
						prob1=>$protinfo1->{probability},
						prob2=>$protinfo2->{probability},
						npeps1=>$protinfo1->{npeps},
						npeps2=>$protinfo2->{npeps},
						nobs1=>$protinfo1->{PSM_count},
						nobs2=>$protinfo2->{PSM_count},
						enz_termini1=>$protinfo1->{total_enzymatic_termini},
						enz_termini2=>$protinfo2->{total_enzymatic_termini},
					) eq $prot1 );
						};

						sub replace_in_list {
							my $prot1 = shift; # we want this in the list
							my $prot2 = shift; # we want to remove this from list
							my $list_aref = shift;
							remove_string_from_array ( $prot2, $list_aref );
							push  (@{$list_aref}, $prot1);
						}

						for my $prot2 (@canonical_set) {
	      if ( same_pep_set($prot, $prot2) ) {
					if ( prot1_is_better_than_prot2($prot, $prot2) ) {
						replace_in_list($prot, $prot2, \@canonical_set);
						# add the one being replaced back into the list
						remove_string_from_array ( $prot, \@remaining_proteins );
						push ( @remaining_proteins, $prot2 );
					}
	      }
	    }
	  }

	  my $n_canonicals = scalar(@canonical_set);
	  my $n_others = scalar(@remaining_proteins);
	  if (0 && $n_canonicals > 2) {
	    print "Canonicals:\n   ";
	    for my $prot (@canonical_set) {
	      print "$prot ";
	    }
	    print "\n";
	  }
	  for my $prot (@canonical_set) {
	    $proteins_href->{$prot}->{presence_level} = "canonical";
	    $proteins_href->{$prot}->{represented_by} = $prot_group_rep;
	    $proteins_href->{$prot}->{subsumed_by} = '';
	  }


	  # Label all remaining proteins possibly_distinguished
	  foreach my $protein (@remaining_proteins) {
	    my $prot_href = $proteins_href->{$protein};
	    $prot_href->{presence_level} = "possibly_distinguished";
	    $prot_href->{subsumed_by} = '';
	  }

	  ### Run through possibly_distinguished proteins and see if any
	  ### are NTT-subsumed.
	  
	  ### First, define a subroutine to tell whether a
	  ### protein's peps are a proper subset of another protein's peps.
	  sub prot1_peps_proper_subset_prot2_peps {
	    my %args = @_;
	    my $protein1 = $args{'protein1'};
	    my $protein2 = $args{'protein2'};
	    my $prot_href1 = get_protinfo_href ( $protein1 );
	    my $prot_href2 = get_protinfo_href ( $protein2 );
	    my %peps1 = ();
	    my %peps2 = ();
            my $npeps1 = 0;
            my $npeps2 = 0;
	    for my $pep ( @{$prot_href1->{unique_stripped_peptides}} ) {
              $npeps1++;
	      $peps1{$pep} = 1;
	    }
	    for my $pep ( @{$prot_href2->{unique_stripped_peptides}} ) {
              $npeps2++;
	      $peps2{$pep} = 1;
	    }
            return ( 0 ) if ($npeps1 == $npeps2);  #can't be proper subset
	    for my $pep ( keys %peps1 ) {
	      if ( ! defined $peps2{$pep} ) {
		return ( 0 );
	      }
	    }
	    return ( 1 );
	  }


	  ### Create hashes of all canonical, possibly_distinguished
	  my %canonical_plus_possibly_dist_hash = ();
	  my %possibly_dist_hash = ();
	  for my $protein (@protein_list) {
	    my $prot_href = $proteins_href->{$protein};
	    if ($prot_href->{presence_level} eq "canonical") {
	      $canonical_plus_possibly_dist_hash{$protein} = 1;
	    } elsif ($prot_href->{presence_level} eq "possibly_distinguished") {
	      $canonical_plus_possibly_dist_hash{$protein} = 1;
	      $possibly_dist_hash{$protein} = 1;
	    }
	  }


	  # For each possibly_distinguished ...
	  for my $protein (keys %possibly_dist_hash) {

	    # Check that it's still in the poss_dist list
            # (hasn't been assigned ntt-subsumed)
	    if (! defined $possibly_dist_hash{$protein}) {
	      next;
	    }

            # First, find all canonicals, poss_dist with exact same
            # pep set, select one to keep its current label, and label
            # all the rest (likely only 0 or 1) ntt-subsumed.

	    # Gather all canonicals, poss_dist with exact same pep set.
	    my @prots_with_same_peps = ($protein);
	    for my $protein2 (keys %canonical_plus_possibly_dist_hash) {
	      if ($protein eq $protein2) {
		next;
	      }
	      if (same_pep_set ($protein, $protein2)) {
		
		my $prot_href = $proteins_href->{$protein};
		my $prot_href2 = $proteins_href->{$protein2};
		#print "$protein ($prot_href->{presence_level}, $prot_href2->{probability}) $protein2 ($prot_href2->{presence_level}, $prot_href2->{probability}) same pep set in group $group_num\n";
		push (@prots_with_same_peps, $protein2);
	      }
	    }

	    # If any, set aside the one with the best properties
            # (properties that make it most likely to have been observed).
	    if ( scalar (@prots_with_same_peps) > 1 ) {
	      my $most_likely__prot = $protein;
	      for my $protein3 (@prots_with_same_peps) {
                my $prot_href3 = get_protinfo_href($protein3);
                my $most_likely__href = get_protinfo_href($most_likely__prot);
		my $most_likely = 
	  SBEAMS::PeptideAtlas::ProtInfo::more_likely_protein_identification(
		  preferred_patterns_aref=>$preferred_patterns_aref,
		  swiss_prot_href => $swiss_prot_href,
		  protid1=>$protein3,
		  protid2=>$most_likely__prot,
		  prob1=>$prot_href3->{probability},
		  prob2=>$most_likely__href->{probability},
		  npeps1=>$prot_href3->{npeps},
		  npeps2=>$most_likely__href->{npeps},
		  nobs1=>$prot_href3->{PSM_count},
		  nobs2=>$most_likely__href->{PSM_count},
		  enz_termini1=>$prot_href3->{total_enzymatic_termini},
		  enz_termini2=>$most_likely__href->{total_enzymatic_termini},
                );
                $most_likely__prot = $most_likely;
	      }
	      remove_string_from_array($most_likely__prot,
                                       \@prots_with_same_peps);
		
	      # None of the others should be canonical. (If it is, warn.)
	      # Label them ntt-subsumed and remove from
	      # possibly_distinguished hash.
	      for my $protein3 (@prots_with_same_peps) {
		my $prot_href = $proteins_href->{$protein3};
		if ($prot_href->{presence_level} eq "canonical") {
		  print "WARNING: $protein3 is canonical, yet was not selected as having best prob, nobs, ntt from among prots with the same peps! It will be marked ntt-subsumed.\n";
		}
		$prot_href->{presence_level} = "ntt-subsumed";
		$prot_href->{subsumed_by} = $most_likely__prot;
		# Give the protein counts for the ntt-subsumed protein
		# to its subsumed_by protein.
		if ($apportion_PSMs) {
		  $proteins_href->{$most_likely__prot}->{PSM_count}
		    += $prot_href->{PSM_count};
		  $prot_href->{PSM_count} = 0;
		}
		undef $possibly_dist_hash{$protein3};
	      }
	    } else {

	      # If none with exact same set, look for canonicals,
	      # poss-dist whose peps are a superset of this protein's peps.
              # If any, label this one ntt-subsumed relative to
              # the one with the superset.
	      my @prots_with_same_peps = ($protein);
	      for my $protein2 (keys %canonical_plus_possibly_dist_hash) {
		if ($protein eq $protein2) {
		  next;
		}
		if (prot1_peps_proper_subset_prot2_peps
		     ( protein1 => $protein, protein2 => $protein2)) {
		  
		  my $prot_href1 = $proteins_href->{$protein};
		  my $prot_href2 = $proteins_href->{$protein2};
		  $prot_href1->{presence_level} = "ntt-subsumed";
		  $prot_href1->{subsumed_by} = $protein2;
		  # Give the protein counts for the ntt-subsumed protein
		  # to its subsumed_by protein.
		  if ($apportion_PSMs) {
		    $prot_href2->{PSM_count} += $prot_href1->{PSM_count};
		    $prot_href1->{PSM_count} = 0;
		  }
		  undef $possibly_dist_hash{$protein};
		}
	      }
	    }
	  }
	}
      }

      # Calculate covering list
      print "INFO: Creating covering protein set.\n";
      $CONTENT_HANDLER->{covering_proteins} = {};
      my $covering_set_href = $CONTENT_HANDLER->{covering_proteins};

       for my $pepseq (@peplist) {

        my $covering_prot = "";
        my $this_pep_already_has_a_prot_in_the_covering_list = 0;
	# The below may be undefined if it's an indistinguishable peptide.
	# No harm -- its prots should be stored under its twin.
	if (defined $CONTENT_HANDLER->{ProteinProphet_prot_data}->
	   {pep_prot_hash}->{$pepseq} ) {
	  my @pep_protlist = @{$CONTENT_HANDLER->{ProteinProphet_prot_data}->
	     {pep_prot_hash}->{$pepseq}};
          # for each protein that this pep maps to
	  for my $protid (@pep_protlist) {
	    # see if it is in the covering list.
	    if ( defined $covering_set_href->{$protid} ) {
	      $this_pep_already_has_a_prot_in_the_covering_list = 1;
              $covering_prot = $protid;
	    }
	  }
          # If this pep is not yet represented in the covering list,
          # select the most likely mapped-to protein and add it to the list.
          if ( ! $this_pep_already_has_a_prot_in_the_covering_list) {
	    my $most_likely_id = $pep_protlist[0];
	    for my $protid (@pep_protlist) {
	      my $most_likely_id_info = get_protinfo_href ( $most_likely_id );
	      my $protid_info = get_protinfo_href ( $protid );
              $most_likely_id =
	SBEAMS::PeptideAtlas::ProtInfo::more_likely_protein_identification(
		preferred_patterns_aref=>$preferred_patterns_aref,
		swiss_prot_href => $swiss_prot_href,
		protid1=>$most_likely_id,
		protid2=>$protid,
		prob1=>$most_likely_id_info->{probability},
		prob2=>$protid_info->{probability},
		npeps1=>$most_likely_id_info->{npeps},
		npeps2=>$protid_info->{npeps},
		nobs1=>$most_likely_id_info->{PSM_count},
		nobs2=>$protid_info->{PSM_count},
		enz_termini1=>$most_likely_id_info->{total_enzymatic_termini},
		enz_termini2=>$protid_info->{total_enzymatic_termini},
		presence_level1=>$most_likely_id_info->{presence_level},
		presence_level2=>$protid_info->{presence_level},
              );
            }
	    $covering_prot = $most_likely_id;
            $covering_set_href->{$covering_prot} = 1;
          }

	  # If needed, rearrange the list of prots this pep maps to
          # so that the covering protein is first. This is a way of
          # storing the covering protein for each peptide.
          if ($pep_protlist[0] ne $covering_prot) {
            #print "= $pep_protlist[0]\n";
	    my $found =
               remove_string_from_array($covering_prot, \@pep_protlist);
	    print "ERROR: covering prot $covering_prot not in protlist ".
                  "for $pepseq\n" if (! $found );
	    unshift (@pep_protlist, $covering_prot) ;
            #print "  $pep_protlist[0]\n";
	    @{$CONTENT_HANDLER->{ProteinProphet_prot_data}->
	           {pep_prot_hash}->{$pepseq}} = @pep_protlist;
          }

	}
      }

      my $n_covering_prots = scalar keys %{$covering_set_href};
      print "$n_covering_prots protein IDs in covering list.\n";

      #### Write the protein list file.
      #### This is info on any protein that any atlas peptide maps to.
      my $prot_identlist_file = "DATA_FILES/PeptideAtlasInput.PAprotlist";
      writeProtIdentificationListFile(
	output_file => $prot_identlist_file,
	ProteinProphet_prot_data => $CONTENT_HANDLER->{ProteinProphet_prot_data},
	  # hashes protID to group. Group contains all protein info.
	ProteinProphet_group_data =>
		   $CONTENT_HANDLER->{ProteinProphet_group_data},
      );

      #### Re-write PAidentlist files using only covering list
      #### proteins.
      my $temp_file = "temp.PAidentlist";
      my %PAidentlist_prots;
      my $n_PSMs;
      # for each of the two files
      ## get chimera_level
      open (IN, "<$combined_identlist_file");
      my %chimera_level =();
      my $flag =0;
			while (my $line =<IN>){
				chomp $line;
				my @columns = split("\t", $line);
				my $spectrum_name = $columns[1];
				my $id = $columns[0];
				$spectrum_name =~ /^(.*\.\d+)\.\d+\.\d+$/;
				$id = "$id-$1";
				$chimera_level{"$id"}  = '';
				if ($spectrum_name =~ /^([^\.]+?)((\_rs)+)(\.\d+)\.\d+\.\d+/){
					my $root = $1;
					my $rs = $2;
					my $scan = $4;
					$root = $root.$scan;
					my @n = $rs=~ /\_rs/g;
					$chimera_level{"$id"} = 1 + scalar @n;
          $flag =1;
				}
			}
			foreach my $spec (keys %chimera_level){
				if ($spec =~ /\_rs\./){
					$spec =~ /^([^\.]+)((\_rs)+)(\.\d+)$/;
					$spec = $1.$4;
					if (defined $chimera_level{$spec}){
						$chimera_level{$spec} = 1;
					}
				}else{
           if ($flag){
             $chimera_level{$spec} = 0;
           }
        }
			}
			
        

      for my $file ( $combined_identlist_file, $sorted_identlist_file ) {
				if ( -e $file ) {
					open (IDENTLISTFILE, $file) ||
						die("ERROR: Unable to open for reading '$file'");
					open (OUTFILE, ">$temp_file") ||
						die("ERROR: Unable to open for writing '$temp_file'");
					print "Writing new protids for $file\n";
					$n_PSMs = 0;
					# copy header line
					my $line = <IDENTLISTFILE>;
					print OUTFILE $line;
					while ($line = <IDENTLISTFILE>) {
						chomp ($line);
						my @fields = split("\t", $line);
						my $pepseq = $fields[3];
						my $identlist_protid = $fields[10];
						my $spectrum_name = $fields[1];
						my $id = $fields[0];
						$spectrum_name =~ /^(.*\.\d+)\.\d+\.\d+$/;
						$id = "$id-$1";
						#if (scalar @fields == 11 ){
					  #	push @fields, ("", "", "");
						#}elsif(scalar @fields == 12){
						#	push @fields, ("", "");
						#}
						push @fields, $chimera_level{$id};

						# Replace field 11 (index 10) if this peptide (or one
						# indistinguishable from it) is in our hash.
						my $pep_protlist_aref = $CONTENT_HANDLER->{ProteinProphet_prot_data}->
							 {pep_prot_hash}->{$pepseq};
						if (! defined $pep_protlist_aref ) {
							my @indis = get_leu_ile_indistinguishables($pepseq);
							for my $indis (@indis) {
					$pep_protlist_aref = $CONTENT_HANDLER->
						 {ProteinProphet_prot_data}->{pep_prot_hash}->{$indis};
					if ( defined $pep_protlist_aref ) {
						last;
					}
	      }
	    }
	    if ( defined $pep_protlist_aref ) {
	      my @pep_protlist = @{$pep_protlist_aref};
	      my $covering_prot = $pep_protlist[0];
	      $PAidentlist_prots{$covering_prot} = 1;
	      if ($identlist_protid ne $covering_prot) {
		$fields[10] = $covering_prot;
	      }
	    } else {
	      $peps_not_found{$pepseq} = 1;
	    }
	    # re-write line into temp file
	    print OUTFILE join("\t",@fields)."\n";
	    $n_PSMs++;
	  }
	  # copy new file into old name
	  system ("mv $temp_file $file");
	} else {
          print "WARNING: $file doesn't exist; can't update its protids.\n";
        }
      }

      my @peps_not_found_list = keys %peps_not_found;
      if (scalar(@peps_not_found_list) > 0) {
	print "\nWARNING: No proteins will be stored in PAprotlist for the ";
	print "following\ncombined PAidentlist peptides, because they were ";
	print "somehow not found in the\nmaster protXML file. ";
	print "Their protIDs in the PAidentlist file will be assigned\n";
	print "according to the individual protXMLs. Either there is a\n";
	print "bug somewhere, or your master protXML was created from\n";
	print "different pepXML files than your PAidentlist was.\n";
	for my $pep (@peps_not_found_list) {
	  print "$pep\n";
	}
      }

      # Check to see that covering list proteins, gleaned from
      # protXML, are all or mostly assigned to peps in PAidentlist.
      my %covering_prots_not_assigned_to_peps_in_PAidentlist;
      for my $prot (keys %{$covering_set_href}) {
	unless (defined $PAidentlist_prots{$prot}) {
	  $covering_prots_not_assigned_to_peps_in_PAidentlist{$prot} = 1;
	}
      }
      my $n_prots_not_assigned =
	scalar keys %covering_prots_not_assigned_to_peps_in_PAidentlist;
      my $n_prots_assigned =
	scalar keys %PAidentlist_prots;
      print "$n_prots_assigned covering proteins assigned to peps in PAidentlist ($n_PSMs lines).\n";
      print "$n_prots_not_assigned covering proteins not assigned to peps in PAidentlist, listed below.\n";
      print " (If many, you probably didn't use filtered pepXMLs when creating your master protXML.)\n";
      for my $prot (keys %covering_prots_not_assigned_to_peps_in_PAidentlist) {
	print "$prot ";
      }
      print "\n";
    }

  } # end unless $APD_only

  unless ($protlist_only || ! $APD_only ){ 

    #### Open APD format tsv file for writing
    my $output_tsv_file = $OPTIONS{output_file} || 'PeptideAtlasInput.tsv';
    openAPDFormatFile(
      output_file => $output_tsv_file,
    );


    #### Open PeptideAtlas APD XML format file for writing
    my $output_PAxml_file = $output_tsv_file;
    $output_PAxml_file =~ s/\.tsv$//i;
    $output_PAxml_file .= '.PAxml';
    openPAxmlFile(
      output_file => $output_PAxml_file,
      P_threshold => $CONTENT_HANDLER->{P_threshold},
      FDR_threshold => $CONTENT_HANDLER->{FDR_threshold},
    );


    #### If we have decoy corrections, apply them and write out a new file
    if (%decoy_corrections) {
      my $output_file = $sorted_identlist_file;
      $output_file =~ s/sorted/srtcor/;
      apply_decoy_corrections(
				input_file => $sorted_identlist_file,
				output_file => $output_file,
				decoy_corrections => \%decoy_corrections,
      );
      $sorted_identlist_file = $output_file;
    }


    #### Open the combined, sorted peptide identlist file
    open(INFILE,$sorted_identlist_file) ||
      die("ERROR: Unable to open for reading '$sorted_identlist_file'");


    #### Loop through all rows, grouping by peptide sequence, writing
    #### out information for each group of peptide sequence
    my $prev_peptide_sequence = '';
    my $pre_peptide_accesion ='';
    my $done = 0;
    my @rows;
    while (! $done) {
      my $line = <INFILE>;
      my @columns;
      my $peptide_sequence = 'xxx';

      #### Unless we're at the end of the file
      if ($line) {
				chomp($line);
				@columns = split("\t",$line);
				$peptide_sequence = $columns[3];
        
      }

      #### If we're encountering the new peptide, process and write the previous
      if ($prev_peptide_sequence &&
          $peptide_sequence ne $prev_peptide_sequence) {
          $pre_peptide_accesion =~ /PAp0+(\d+)/;
          #my $n = $1;
          #if ($n > 8352023){ 
          #print "$pre_peptide_accesion $n\n";
         	my $peptide_summary = coalesceIdentifications(
	        rows => \@rows,
	        column_names => \@column_names,
          );
          writeToAPDFormatFile(
    	    peptide_summary => $peptide_summary,
          );
          writeToPAxmlFile(
        	  peptide_summary => $peptide_summary,
        	);
         #}
        	$prev_peptide_sequence = $peptide_sequence;
          $pre_peptide_accesion =  $columns[2];
        	@rows = ();
      }

      #### If there is no peptide sequence, the we're at the end of the file
      if ($peptide_sequence eq 'xxx') {
	last;
      }

      push(@rows,\@columns);

      #### Needed for the very first row
      unless ($prev_peptide_sequence) {
				$prev_peptide_sequence = $peptide_sequence;
				$pre_peptide_accesion = $columns[2];

      }

    }


    #### Close files
    closeAPDFormatFile();
    closePAxmlFile();
  } # end unless $protlist_only


  #### Write out information about the objects we've loaded if verbose
  if ($VERBOSE) {
    showContentHandlerContents(
      content_handler => $CONTENT_HANDLER,
    );
  }

  print "\n\n" unless ($QUIET);

} # end main



###############################################################################
###############################################################################
###############################################################################
###############################################################################

###############################################################################
# readSpectralLibraryPeptides
###############################################################################
sub readSpectralLibraryPeptides {
  my %args = @_;
  my $input_file = $args{'input_file'} || die("No input file provided");

  #### Return if library not available
  if ( ! -e $input_file ) {
    print "WARNING: Spectral library '$input_file' not found!\n";
    return;
  }

  print "Reading consensus spectral library file '$input_file'...\n";

  #### Open library file
  open(INFILE,$input_file)
    || die("ERROR: Unable to open '$input_file'");


  #### Verify that the head is as we expect
  my $line;
  while ($line = <INFILE>) {
    if ($line =~ /^\#\#\# ===/) {
      last;
    }
    if ($line !~ /^\#\#\#/) {
      die("ERROR: Unexpected format reading spectral library '$input_file'");
    }
  }

  my $peptides;
  my $n_peptides;
  my ($peptide_sequence,$probability);
  my $counter;

  #### Read file minimally, skimming out the peptide information
  while ($line = <INFILE>) {
    chomp($line);
    if ($line =~ /^Name: ([^\/]+\/\d)/) {
      $peptide_sequence = $1;
    }
    if ($line =~ /^Comment: .+ Prob=([\d\.]+)/) {
      $probability = $1;
    }
    if ($line =~ /^NumPeaks/) {
      if ($peptides->{$peptide_sequence}) {
	if ($probability > $peptides->{$peptide_sequence}) {
	  $peptides->{$peptide_sequence} = $probability;
	  #print "$peptide_sequence = $probability\n";
	}
      } else {
	$peptides->{$peptide_sequence} = $probability;
	#print "$peptide_sequence = $probability\n";
	$n_peptides++;
      }
    }

    if ( $VERBOSE ) {
      $counter++;
      print "$counter... " if ($counter % 1000 == 0);
    }

  }

  close(INFILE);

  print "  - read $n_peptides PSMs from spectral library\n";

  return($peptides);

} # end readSpectralLibraryPeptides 



###############################################################################
# writePepIdentificationListFile
###############################################################################
sub writePepIdentificationListFile {
  my %args = @_;
  my $output_file = $args{'output_file'} || die("No output file provided");
  my $input_file = $args{'input_file'} || die("No input file provided");
  my $ProteinProphet_pep_data = $args{'ProteinProphet_pep_data'}
    || die("No ProteinProphet_pep_data provided");
  my $ProteinProphet_pep_protID_data = $args{'ProteinProphet_pep_protID_data'}
    || die("No ProteinProphet_pep_protID_data provided");
  my $spectral_library_data = $args{'spectral_library_data'};
  my $P_threshold = $args{'P_threshold'};
  my $FDR_threshold = $args{'FDR_threshold'};
  my $best_prob_per_pep;
  # if best_probs_from_protxml is set, this arg is undefined
  ($best_prob_per_pep = $args{'best_prob_per_pep'})
    || print "INFO: writePepIdentificationListFile will get best prob ".
             "per pep from protXML info\n";
  my %peps_without_protxml_protid;

  my $protID_protxml;
  if ($OPTIONS{master_ProteinProphet_file}) {
    $protID_protxml = "master protXML"
  } else {
    $protID_protxml = "individual protXMLs"
  }

  print "Writing output combined cache file '$output_file'...\n";
  #### Open and write header
  open(OUTFILE,">$output_file")
    || die("ERROR: Unable to open '$output_file' for write");

  #### Write out the column names
  my @column_names = qw ( search_batch_id 
                          spectrum_query 
                          peptide_accession
                          peptide_sequence 
                          preceding_residue 
                          modified_peptide_sequence
                          following_residue 
                          charge 
                          probability 
                          massdiff 
                          protein_name
                          protXML_nsp_adjusted_probability
                          protXML_n_adjusted_observations 
                          protXML_n_sibling_peptides
                          precursor_intensity  
                          total_ion_current 
                          signal_to_noise
                          retention_time_sec );

  print OUTFILE join("\t",@column_names)."\n";


  my %consensus_lib = ( found => [], missing => [] );

  # debugging
  if (0) {
    print "ProteinProphet peptide data:\n";
    while ((my $pep, my $info) = each ( %{$ProteinProphet_pep_data} )) {
      print "  $pep $info->{nsp_adjusted_probability}\n";
    }
  }
  open (INFILE, "<$input_file") or die "cannot open $input_file\n";
  my $line = <INFILE>;
  my $idx = 0;
  my @prob_array = ();
  use DB_File ;
  my @extra_cols_array ;
  tie @extra_cols_array, "DB_File", "text", O_RDWR|O_CREAT, 0640, $DB_RECNO;
  while (my $line = <INFILE>){
    chomp $line;
    my @columns = split(/\t/,$line, -1);
    my $identification = \@columns; 
    my $charge = $identification->[7];
    my $peptide_sequence = $identification->[3];
    my $modified_peptide = $identification->[5];
    my $spectrast_formatted_sequence = $modified_peptide . '/' . $charge;
    #### Grab the ProteinProphet information
    my $initial_probability;
    my $adjusted_probability = '';
    my $n_adjusted_observations = '';
    my $n_sibling_peptides = '';
    my $probability_adjustment_factor;
    my $pep_key = '';
    my $diff_is_great=0;
    my $protinfo_protxml;
    if ($OPTIONS{master_ProteinProphet_file} && !$OPTIONS{per_expt_pipeline}) {
      $protinfo_protxml = "master protXML"
    } else {
      $protinfo_protxml = "individual protXMLs"
    }

    if ($ProteinProphet_pep_data->{"${charge}-$modified_peptide"}) {
      $pep_key = "${charge}-$modified_peptide";
    } elsif ($ProteinProphet_pep_data->{$peptide_sequence}) {
      $pep_key = $peptide_sequence;
    } else {
      print "WARNING: Did not find info in $protinfo_protxml for keys ".
				"$peptide_sequence  or '${charge}-$modified_peptide'".
        " (prot=$identification->[10], P=$identification->[8])\n";
    }

    # If ProteinProphet info was found, adjust the probability accordingly.
    if ($pep_key) {
      my $info = $ProteinProphet_pep_data->{$pep_key};
      if ($best_prob_per_pep) {
        # subtract .001 since DS does this in ProteinProphet
        if (defined $best_prob_per_pep->{$pep_key}){
          $initial_probability = $best_prob_per_pep->{$pep_key} - .001;
        }else{
          $initial_probability = -0.001;
        }
        # debugging: check whether probs from pepXML match
        # init_probs from protXML. In a small fraction of cases,
        # they don't, and I don't know why. TMF 02/09.
        if (0) {
          my $diff = $initial_probability-$info->{initial_probability};
          $diff_is_great = ($diff > .0011 || $diff < -.0011);
          if ($diff_is_great) {  # 12/31/08 tmf debugging
            printf "init_prob diff %7.5f protXML: %7.5f pepXML: %7.5f %s\n",
               $diff,
               $info->{initial_probability},
               $initial_probability,
               $pep_key;
          }
        }
      } else {
        $initial_probability = $info->{initial_probability};
      }
      if ($ProteinProphet_pep_protID_data->{$pep_key}->{protein_name}){
        $identification->[10] = $ProteinProphet_pep_protID_data->{$pep_key}->{protein_name};
      } elsif ($ProteinProphet_pep_protID_data->{$peptide_sequence}->{protein_name}){
        $identification->[10] = $ProteinProphet_pep_protID_data->{$peptide_sequence}->{protein_name};
      } else {
        $peps_without_protxml_protid{$pep_key} = 1;
      }
      $adjusted_probability = $info->{nsp_adjusted_probability};
      $n_adjusted_observations = $info->{n_adjusted_observations};
      $n_sibling_peptides = $info->{n_sibling_peptides};
      #push(@{$identification},$adjusted_probability,$n_adjusted_observations,$n_sibling_peptides);
      $extra_cols_array[$idx] = "$identification->[8],$identification->[9],$identification->[10],".
                                "$adjusted_probability,$n_adjusted_observations,$n_sibling_peptides".
                                ",$identification->[11],$identification->[12],$identification->[13],$identification->[14]";
      if ($initial_probability) {
				$probability_adjustment_factor = $adjusted_probability / $initial_probability;
      }
    }else{
      $extra_cols_array[$idx] = "$identification->[8],$identification->[9],$identification->[10],,,".
                                ",$identification->[11],$identification->[12],$identification->[13],$identification->[14]";
    }
    #### If there is spectral library information, look at that
    #print "spectral_library_data = $spectral_library_data\n";
    #print "spectrast_formatted_sequence = $spectrast_formatted_sequence\n";
    if ($spectral_library_data && $spectrast_formatted_sequence) {
      if ($spectral_library_data->{$spectrast_formatted_sequence}) {
        #print "$peptide_sequence\t$initial_probability\t$spectral_library_data->{$peptide_sequence}\n";
				# This adds a 15th column, which gums up the works during the load
				#	    $identification->[14] = $spectral_library_data->{$spectrast_formatted_sequence};
				push @{$consensus_lib{found}}, $spectrast_formatted_sequence;
      } else {
        # print "$peptide_sequence\t$initial_probability\t($spectrast_formatted_sequence)\t not in lib \n";
				push @{$consensus_lib{missing}}, $spectrast_formatted_sequence;
        #### If it's not in the library, kill it
        #### (tmf: maybe should kill some more sure way)
        $initial_probability = 0.5;
      }
    }

    #### If we are operating with a master_ProteinProphet_file, then
    #### try a radical thing. Multiply the PepPro and ProPro probability.
    #### This probably really isn't correct, but maybe it'll be close.
    #### (Eric's radical idea disabled by 2009.)
    if ($OPTIONS{master_ProteinProphet_file} &&
          !$OPTIONS{per_expt_pipeline}) {
      my $probability = $identification->[8];
      my $adjusted_probability = $identification->[11];
      if ($adjusted_probability && $probability_adjustment_factor) {
				#### Depresses probabilities too much
				#$probability = $probability * $adjusted_probability;
				#### If the adjusted probability is 1.0, then give probabilities a big boost
				#if ($adjusted_probability > 0.9999) {
				#  $probability = 1.0 - ( ( 1.0 - $probability ) / 3.0 );
				#  #### Although don't let it be less the adjustment to the top one
				#  if ( $probability < $probability * $probability_adjustment_factor) {
				#    $probability = $probability * $probability_adjustment_factor;
				#  }
				##### Else just apply the adjustment factor given to the top one
				#} else {
				#  $probability = $probability * $probability_adjustment_factor;
				#}
				#### Apply the adjustment factor given to the top one
				$probability = $probability * $probability_adjustment_factor;
				#### Newer ProteinProphet downgrades initial_probability 1.000 to 0.999
				#### to help adjustment code. Because of this, sometimes probabilities
				#### here can drift slightly over 1.000. Don't allow that.
				$probability = 1 if ($probability > 1);
				$identification->[8] = $probability;
        $extra_cols_array[$idx] = "$identification->[8],$identification->[9],$identification->[10],".
                                    "$identification->[11],$identification->[12],$identification->[13],$identification->[14]"; 
				### tmf debugging 12/08
				if ($diff_is_great)
					 { print "Final adj prob = $probability: REJECTED!!!\n"; }
			} else {
				 $extra_cols_array[$idx] = "$identification->[8],$identification->[9],$identification->[10],".
											"$identification->[11],$identification->[12],$identification->[13],$identification->[14]";
				 print "WARNING: No adjusted probability for $charge-$modified_peptide\n";
			}
    }
    push @prob_array, [($identification->[8], $idx)];
    $idx++;
  }

  print "  - filtering $idx PSMs and writing to identification list file\n";
  #### Sort identification list by probability.
  sub by_decreasing_probability { - ( $a->[0] <=> $b->[0] ); }
  my @sorted_prob_array =
     (sort by_decreasing_probability @prob_array);

  #### Truncate per-experiment by FDR threshold, if desired.
  if ($FDR_threshold) {
    my $counter = 0;
    my $prob_sum = 0.0;
    my $fdr;
    my $prob_cutoff;
    my $probability;
    my $last_probability = 1;;
    my $last_protid = "";
    foreach my $identification ( @sorted_prob_array ) {
      $counter++;
      $probability = $identification->[0];

      ## 2013-07-19
      ## force prob_cutoff >= 0.9
      if( $probability < 0.9){
        $fdr = 1 - ($prob_sum /($counter -1));
        $prob_cutoff = $last_probability; 
        $counter--;
      }

      # If we exceed the FDR threshold, note the probability of the
      # last PSM. Then let in any additional PSMs with exact same
      # probability.
      if ( ! defined $prob_cutoff ) {
				$prob_sum += $probability;
				$fdr = 1 - ($prob_sum / $counter);
			  if ( $fdr > $FDR_threshold) {
					$prob_cutoff = $last_probability;
				}
      }
      # If we've already reached the FDR threshold, then we have a
      # probability cutoff. See if we've gone past it.
      if ( defined $prob_cutoff ) {
        if ( $probability < $prob_cutoff ) {
					printf("Identification list truncated just after record #%d,".
                 " prob %0.10f, protein %s, FDR %0.10f\n",
              $counter-1, $prob_cutoff, $last_protid, $fdr);
					# truncate the list after the previous entry
					$#sorted_prob_array = $counter-1;
					last;
        }
      }
      $last_probability = $probability;
      $last_protid = $identification->[0];
    }
  }

  my %selected_rows = ();
  foreach my $row (@sorted_prob_array){
    my ($prob, $idx) = @$row;
    $selected_rows{$idx} = 1; 
  }

  seek INFILE, 0, SEEK_SET;
  #### Print.
  my $counter = 0;
  $idx = 0;
  $line = <INFILE>;
  while ($line = <INFILE>){
    chomp $line;
    my @columns = split("\t", $line);
    if($extra_cols_array[$idx]){
      #splice(@columns,$#columns-6,7);
      splice(@columns, 8, $#columns);
      push @columns, split(",", $extra_cols_array[$idx],-1);
    }else{
      print "WARINING: only 7 columns\n";
    }
    my $probability = $columns[8];
    ### warns that can't compare strings with >= but can't find
    #    ###  function to explicitly convert to float
            next if($columns[3] =~ /[JUZBOX]/);
    
    if (($P_threshold && $probability >= $P_threshold) || ($FDR_threshold && defined $selected_rows{$idx} )) {
      print OUTFILE join("\t", @columns);
      print OUTFILE "\n"; 
      $counter++;
      print "$counter... " if ($counter % 1000 == 0);
    }
    $idx++;
  }


  print "\n  - wrote $counter peptides to identification list file.\n";

  # List those peptides for which the protein ID from the pepXML is printed
  #  due to that peptide not being found in the protXML for some reason.
  my @peps_without_protxml_protid = keys %peps_without_protxml_protid;
  my $npeps = scalar(@peps_without_protxml_protid);
  if ($npeps) {
    print "No protID collected from $protID_protxml for the following peptides\n";
    print "  (both unstripped and stripped versions were checked).\n";
    print "ProtID from pepXML was used; may result in more unique protIDs\n";
    print "  and thus underestimated Mayu protein FDR.\n";
    for my $pep_key (@peps_without_protxml_protid) {
      print "  $pep_key\n";
    }
  }

  if ( $splib_filter ) {
    print "Filtered vs. consensus library, found " . scalar( @{$consensus_lib{found}} ) . ',  ' .  scalar( @{$consensus_lib{missing}} ) . " were missing\n";
  }
  print "\n";
  untie @extra_cols_array;
  unlink "text";
  close(OUTFILE);

  return(1);

} # end writePepIdentificationListFile

###############################################################################
# writeProtIdentificationListFile
###############################################################################

sub writeProtIdentificationListFile {
  my %args = @_;
  my $output_file = $args{'output_file'}
    || die("No protlist file provided");
  my $ProteinProphet_prot_data = $args{'ProteinProphet_prot_data'}
    || die("No ProteinProphet_prot_data provided");
  my $ProteinProphet_group_data = $args{'ProteinProphet_group_data'}
    || die("No ProteinProphet_group_data provided");

  my $glyco_atlas = $OPTIONS{"glyco_atlas"};
  my $non_glyco_atlas = ! $glyco_atlas;

  open (OUTFILE, ">$output_file");
  print "Opening output file $output_file.\n";

  # Write header line
    print OUTFILE
"protein_group_number,biosequence_names,probability,confidence,n_observations,n_distinct_peptides,level_name,represented_by_biosequence_name,subsumed_by_biosequence_names,estimated_ng_per_ml,abundance_uncertainty,covering\n";

  my $group_num;
  my @prot_name_list = keys %{$ProteinProphet_prot_data->{atlas_prot_list}};

  # For each protein in the atlas
  for my $prot_name (@prot_name_list) {

    # ... look up its group number in ProteinProphet_prot_data.
    $group_num = $ProteinProphet_prot_data->{group_hash}->{$prot_name};
    # Then look up its info in ProteinProphet_group_data and print it.
    my $prot_href = $ProteinProphet_group_data->{$group_num}->{proteins}
        ->{$prot_name};

    # print, in one line, info about this protein and its indistinguishables
    # to the protlist file
    print OUTFILE "$group_num,$prot_name";
    my @indis_list = keys(%{$prot_href->{indist_prots}});
    foreach my $indis (@indis_list) {
      print OUTFILE " $indis";
    }
    my $n_distinct_peptides = scalar(@{$prot_href->{unique_stripped_peptides}});
    my $PSM_count = $prot_href->{PSM_count};
    my $formatted_PSM_count =
         sprintf( "%0.1f", $PSM_count);
    my $biosequence_attributes =
        getBiosequenceAttributes(biosequence_name => $prot_name);

    my ($formatted_estimated_ng_per_ml, $abundance_uncertainty) = ("", "");

    my $is_prot_group_rep = ($prot_name eq $prot_href->{represented_by});

    my $covering;
    if (in_covering_set(prot=>$prot_name)) {
      $covering = 1;
    } else {
      $covering = 0;
    }

    print OUTFILE ",$prot_href->{probability},".
	 "$prot_href->{confidence},".
         ### total_number_peptides is an integer and is calc.  differently
         #"$prot_href->{total_number_peptides},".
         "$formatted_PSM_count,".
         "$n_distinct_peptides,".
         "$prot_href->{presence_level},".
         "$prot_href->{represented_by},".
         "$prot_href->{subsumed_by},".
         "$formatted_estimated_ng_per_ml,".
         "$abundance_uncertainty,".
         "$covering\n";
  }

  # sort file by protein group number
  my $tmp_file = "writeProtIdentificationListFile.tmp";
  system "sort -n $output_file > $tmp_file";
  system "/bin/mv $tmp_file $output_file";

} # end writeProtIdentificationListFile


###############################################################################
# guess_source_file
###############################################################################
sub guess_source_file {
  my %args = @_;
  my $search_batch_id = $args{'search_batch_id'};

  my ($sql,@biosequence_set_ids);

  #### If a search_batch_id was provided
  unless (defined($search_batch_id) && $search_batch_id > 0) {
    return;
  }


  #### Query to find the biosequence_set_id for this tag
  $sql = qq~
    SELECT data_location
      FROM $TBPR_SEARCH_BATCH
     WHERE search_batch_id = '$search_batch_id'
  ~;
  print "$sql\n" if ($VERBOSE);

  my ($data_location) = $sbeams->selectOneColumn($sql);

  #$data_location = "/sbeams/archive/$data_location";

  if ($data_location) {
      if (-e "$data_location/interact-prob-prot.xml") {
          return "$data_location/interact-prob-prot.xml";

      } elsif (-e "$data_location/interact-prot.xml") {
          return "$data_location/interact-prot.xml";

      } else {
	die("ERROR: Unable to find a ProteinProphet file for $data_location");
      }
  }

  return;

} # end guess_source_file



###############################################################################
# getPeptideAccession
###############################################################################
sub getPeptideAccession {
  my %args = @_;
  my $sequence = $args{'sequence'};
  $sequence =~ /^(\w).*$/;
  my $filrstLetter = $1;
  my $peptide_accession = $peptide_str->getPeptideAccession(seq => $sequence);
  if ($peptide_accession){
      return $peptide_accession;
  }
  if( $peptide_str->{_apd_id_list} && $peptide_str->{_apd_id_list}->{$filrstLetter}{$sequence}){
    $peptide_accession  = $peptide_str->{_apd_id_list}->{$filrstLetter}{$sequence}; 
    return $peptide_accession;
  }
  #print "new peptide: $sequence\t";
  $peptide_str->addAPDIdentity (seq => $sequence);
  $peptide_accession = $peptide_str->{_apd_id_list}->{$filrstLetter}{$sequence};
  #print "$peptide_accession\n";
  return $peptide_accession; 
} # end getPeptideAccession


###############################################################################
# getBiosequenceAttributes
###############################################################################
sub getBiosequenceAttributes {
  my %args = @_;
  my $biosequence_name = $args{'biosequence_name'};

  return $biosequence_attributes{$biosequence_name};

} # end getBiosequenceAttributes



###############################################################################
# openAPDFormatFile
###############################################################################
sub openAPDFormatFile {
  my %args = @_;
  my $output_file = $args{'output_file'} || die("No output file provided");

  print "Opening output file '$output_file'...\n";

  our $TSVOUTFILE;
  open(TSVOUTFILE,">$output_file")
    || die("ERROR: Unable to open '$output_file' for write");
  $TSVOUTFILE = *TSVOUTFILE;

  print TSVOUTFILE "peptide_identifier_str\tbiosequence_gene_name\tbiosequence_accession\treference\tpeptide\tn_peptides\tmaximum_probability\tn_experiments\tobserved_experiment_list\tbiosequence_desc\tsearched_experiment_list\n";

  return 1;

} # end openAPDFormatFile



###############################################################################
# writeToAPDFormatFile
###############################################################################
sub writeToAPDFormatFile {
  my %args = @_;
  my $peptide_summary = $args{'peptide_summary'}
    || die("No peptide_summary provided");

  our $TSVOUTFILE;

  while (my ($peptide_sequence,$attributes) =
            each %{$peptide_summary}) {

    my $n_experiments = scalar(keys(%{$attributes->{search_batch_ids}}));

    my $peptide_accession = getPeptideAccession(
      sequence => $peptide_sequence,
    );
    my $protein_name = $attributes->{protein_name};

    my $biosequence_attributes;
    my ($gene_name,$description) = ('','');
    if ($biosequence_attributes = getBiosequenceAttributes(
      biosequence_name => $protein_name,
							  )
       ) {
      $gene_name = $biosequence_attributes->[2]
        if ( defined $biosequence_attributes->[2] );
      $description = $biosequence_attributes->[4]
        if ( defined $biosequence_attributes->[4] );
    }

    print $TSVOUTFILE "$peptide_accession\t$gene_name\t$protein_name\t$protein_name\t$peptide_sequence\t".
      $attributes->{n_instances}."\t  ".
      $attributes->{best_probability}."\t$n_experiments\t".
      join(",",keys(%{$attributes->{search_batch_ids}}))."\t".
      "\"$description\"\t\"$search_batch_ids\"\n";

  }

  return(1);

} # end writeToAPDFormatFile



###############################################################################
# closeAPDFormatFile
###############################################################################
sub closeAPDFormatFile {
  my %args = @_;

  our $TSVOUTFILE;

  close($TSVOUTFILE);

  return(1);

} # end closeAPDFormatFile



###############################################################################
# writeAPDFormatFile - deprecated
###############################################################################
sub writeAPDFormatFile {
  my %args = @_;
  my $output_file = $args{'output_file'} || die("No output file provided");
  my $peptides = $args{'peptide_hash'} || die("No output peptide_hash provided");

  print "Writing output file '$output_file'...\n";

  open(OUTFILE,">$output_file")
    || die("ERROR: Unable to open '$output_file' for write");

  print OUTFILE "peptide_identifier_str\tbiosequence_gene_name\tbiosequence_accession\treference\tpeptide\tn_peptides\tmaximum_probability\tn_experiments\tobserved_experiment_list\tbiosequence_desc\tsearched_experiment_list\n";

  while (my ($peptide_sequence,$attributes) =
            each %{$peptides}) {

    my $n_experiments = scalar(keys(%{$attributes->{search_batch_ids}}));

    my $peptide_accession = getPeptideAccession(
      sequence => $peptide_sequence,
    );
    my $protein_name = $attributes->{protein_name};

    my $biosequence_attributes;
    my ($gene_name,$description) = ('','');
    if ($biosequence_attributes = getBiosequenceAttributes(
      biosequence_name => $protein_name,
							  )
       ) {
      $gene_name = $biosequence_attributes->[2];
      $description = $biosequence_attributes->[4];
    }

    print OUTFILE "$peptide_accession\t$gene_name\t$protein_name\t$protein_name\t$peptide_sequence\t".
      $attributes->{n_instances}."\t  ".
      $attributes->{best_probability}."\t$n_experiments\t".
      join(",",keys(%{$attributes->{search_batch_ids}}))."\t".
      "\"$description\"\t\"$search_batch_ids\"\n";

  }

  close(OUTFILE);

  return(1);

} # end writeAPDFormatFile



###############################################################################
# showContentHandlerContents
###############################################################################
sub showContentHandlerContents {
  my %args = @_;
  my $CONTENT_HANDLER = $args{'content_handler'}
    || die("No CONTENT_HANDLER provided");

  print "\n-------------------------------------------------\n";
  my ($key,$value);
  my ($key2,$value2);

  print "CONTENT_HANDLER:\n";
  while (($key,$value) = each %{$CONTENT_HANDLER}) {
    print "CONTENT_HANDLER->{$key} = $value:\n";
  }

  print "\n";
  while (($key,$value) = each %{$CONTENT_HANDLER}) {
    print "CONTENT_HANDLER->{$key}\n";

    if ($key eq "UNHANDLED") {
      while (($key2,$value2) = each %{$CONTENT_HANDLER->{$key}}) {
        print "  $key2 = $value2\n";
      }

    } elsif ($key eq "OBJ_STACK") {
      foreach $key2 (@{$CONTENT_HANDLER->{$key}}) {
        print "  $key2\n";
      }

    } elsif ($key eq "peptides" || $key eq "all_spectra") {
      my $tmpcnt = 0;
      while (($key2,$value2) = each %{$CONTENT_HANDLER->{$key}}) {
        print "  $key2 = $value2\n";
        $tmpcnt++;
        if ($tmpcnt > 20) {
          print "  etc...\n";
          last;
        }
      }

    } else {
      if (ref($CONTENT_HANDLER->{$key} eq "ARRAY")) {
        foreach $key2 (@{$CONTENT_HANDLER->{$key}}) {
          print "  $key2\n";
        }
      }
    }

  } # end while


  #print Dumper($CONTENT_HANDLER->{peptides});


} # end showContentHandlerContents



###############################################################################
# apply_decoy_corrections
###############################################################################
sub apply_decoy_corrections {
  my %args = @_;
  my $input_file = $args{'input_file'} || die("No input_file provided");
  my $output_file = $args{'output_file'} || die("No output_file provided");
  my $decoy_corrections = $args{'decoy_corrections'} || die("No decoy_corrections provided");

  #### Open the combined, sorted identlist file
  open(INFILE,$input_file) ||
    die("ERROR: Unable to open for read '$input_file'");
  open(OUTFILE,">$output_file") ||
    die("ERROR: Unable to open for write '$output_file'");

  while (my $line = <INFILE>) {
    my @columns;
    chomp($line);
    @columns = split("\t",$line);
    my $search_batch_id = $columns[0];
    my $probability = $columns[8];
    my $decoy_correction = $decoy_corrections->{$search_batch_id};
    if ($decoy_correction) {
      $probability = 1-((1-$probability)/$decoy_correction);
      $columns[8] = sprintf("%.4f",$probability);
    } else {
      print "WARNING: No decoy correction available for searcb_batch_id '$search_batch_id'\n";
    }
    print OUTFILE join("\t",@columns)."\n";
  }

  close(INFILE);
  close(OUTFILE);

} # end apply_decoy_corrections



###############################################################################
# coalesceIdentifications
###############################################################################
sub coalesceIdentifications {
  my %args = @_;
  my $rows = $args{'rows'} || die("No rows provided");
  my $column_names = $args{'column_names'} || die("No column_names provided");
  my $decoy_corrections = $args{'decoy_corrections'};
  use Data::Dumper;

  my $summary;

  #### Make a hash of the column names
  my $columns;
  for (my $index=0; $index<scalar(@{$column_names}); $index++) {
    my $curr_name = $column_names->[$index];
    $columns->{$curr_name} = $index;

    # Hack
    my $trimmed_name = $curr_name;
    $trimmed_name =~ s/^protXML_//;
    if ( $trimmed_name ne $curr_name ) {
      $columns->{$trimmed_name} = $index;
    }
  }
  #print Dumper( [$columns] );

  ## get enzyme ids 
  my $sql = qq~
    SELECT SB.SEARCH_BATCH_ID, 
           PE.PROTEASE_ID 
    FROM $TBPR_SEARCH_BATCH SB
    JOIN $TBPR_PROTEOMICS_EXPERIMENT PE ON (PE.EXPERIMENT_ID = SB.EXPERIMENT_ID) 
    ORDER BY SB.SEARCH_BATCH_ID DESC
  ~;
  my %sb_enzyme_id = $sbeams->selectTwoColumnHash($sql);

  #### Loop over each row, organizing the information
  foreach my $row ( @{$rows} ) {
    my $peptide_sequence = $row->[$columns->{peptide_sequence}];
    $summary->{$peptide_sequence}->{peptide_sequence} = $peptide_sequence;
    my $info = $summary->{$peptide_sequence};
    $info->{peptide_accession} = $row->[$columns->{peptide_accession}];
    $info->{peptide_sequence} = $peptide_sequence;
    $info->{preceding_residue} = $row->[$columns->{preceding_residue}];
    $info->{following_residue} = $row->[$columns->{following_residue}];
    if (!defined($info->{best_probability}) ||
    	$info->{best_probability} < $row->[$columns->{probability}]) {
      $info->{best_probability} = $row->[$columns->{probability}];
    }
    $info->{n_instances}++;
    $info->{protein_name} = $row->[$columns->{protein_name}];

    #### Record that this peptide was seen in this search_batch
    my $search_batch_id = $row->[$columns->{search_batch_id}];
    $info->{search_batch_ids}->{$search_batch_id}++;

    ## if enzyme is missing, leave empty, when display will assume it is trypsin
    my $enzyme = '';
    $enzyme = $sb_enzyme_id{$search_batch_id} if ( $sb_enzyme_id{$search_batch_id});
    $info->{enzyme_ids}{$enzyme} = 1;
 

    #### Now store information for this modification of the peptide
    my $modified_sequence = $row->[$columns->{modified_peptide_sequence}];
    $modified_sequence =~ s/\([\d\.]+\)//g;
    my $charge = $row->[$columns->{charge}];
    $info->{modifications}->{$modified_sequence}->{$charge}->{n_instances}++;
    my $modinfo = $info->{modifications}->{$modified_sequence}->{$charge};
    if (!defined($modinfo->{best_probability}) ||
					$modinfo->{best_probability} < $row->[$columns->{probability}]) {
      $modinfo->{best_probability} = $row->[$columns->{probability}];
    }

    if (exists($modinfo->{search_batch_ids}->{$search_batch_id})) {
      #### Already counted information for this search batch
    } else {
      if (exists($modinfo->{best_adjusted_probability})) {
        if ($row->[$columns->{adjusted_probability}] > $modinfo->{best_adjusted_probability}) {
          $modinfo->{best_adjusted_probability} = $row->[$columns->{adjusted_probability}];
        }
      }

      for my $key ( qw( n_adjusted_observations n_sibling_peptides ) ) {
        $row->[$columns->{$key}] ||= 0;
      }

      $modinfo->{n_adjusted_observations} += $row->[$columns->{n_adjusted_observations}];
      $modinfo->{n_sibling_peptides} += $row->[$columns->{n_sibling_peptides}];

      #### Since this is a new mod instance, update the overall peptide info, too
      if (exists($info->{best_adjusted_probability})) {
        if ($row->[$columns->{adjusted_probability}] > $info->{best_adjusted_probability}) {
          $info->{best_adjusted_probability} = $row->[$columns->{adjusted_probability}];
        }
      }
      $info->{n_adjusted_observations} += $row->[$columns->{n_adjusted_observations}];
      #### FIXME This below is not the best way to calculate n_sibling_peptides.
      #### because if a peptides is seen in two different charge states, the
      #### n_sibling_peptides will be approximately twice what is fair.
      #### n_sibling_peptides will often be inflated, but it's not clear how to do this best
      $info->{n_sibling_peptides} += $row->[$columns->{n_sibling_peptides}];
    }
    $modinfo->{search_batch_ids}->{$search_batch_id}++;

  }

  #print Dumper( [$summary] );
  #exit;

  return $summary;
}


###############################################################################
# openPAxmlFile
###############################################################################
sub openPAxmlFile {
  my %args = @_;
  my $output_file = $args{'output_file'} || die("No output file provided");
  my $P_threshold = $args{'P_threshold'};
  my $FDR_threshold = $args{'FDR_threshold'};


  print "Opening output file '$output_file'...\n";


  #### Open and write header
  our $PAXMLOUTFILE;
  open(PAXMLOUTFILE,">$output_file")
    || die("ERROR: Unable to open '$output_file' for write");
  print PAXMLOUTFILE qq~<?xml version="1.0" encoding="UTF-8"?>\n~;
  $PAXMLOUTFILE = *PAXMLOUTFILE;

  #### Write out parent build element
  print PAXMLOUTFILE encodeXMLEntity(
    entity_name => 'atlas_build',
    indent => 0,
    entity_type => 'open',
    attributes => {
      probability_threshold => $P_threshold,
      FDR_threshold => $FDR_threshold,
    },
  );

  return 1;
}


###############################################################################
# writeToPAxmlFile
###############################################################################
sub writeToPAxmlFile {
  my %args = @_;
  my $peptide_summary = $args{'peptide_summary'}
    || die("No peptide_summary provided");

  our $PAXMLOUTFILE;


  #### Loop over all peptides and write out as XML
  while (my ($peptide_sequence,$attributes) = each %{$peptide_summary}) {
    my $enzyme_ids = join(", ", keys %{$attributes->{enzyme_ids}});
    $enzyme_ids =~ s/^,\s+//;
    $enzyme_ids =~ s/, $//;
    $enzyme_ids =~ s/,\s+,/,/g;

    my $buffer = encodeXMLEntity(
      entity_name => 'peptide_instance',
      indent => 4,
      entity_type => 'open',
      attributes => {
        original_protein_name => $attributes->{protein_name},
        peptide_accession => $attributes->{peptide_accession},
        peptide_sequence => $peptide_sequence,
        peptide_prev_aa => $attributes->{preceding_residue},
        peptide_next_aa => $attributes->{following_residue},
        best_probability => $attributes->{best_probability},
        n_observations => $attributes->{n_instances},
        search_batch_ids => join(",",keys(%{$attributes->{search_batch_ids}})),
        enzyme_ids => join(",", keys %{$attributes->{enzyme_ids}}),
        best_adjusted_probability => $attributes->{best_adjusted_probability},
        n_adjusted_observations => $attributes->{n_adjusted_observations},
        n_sibling_peptides => $attributes->{n_sibling_peptides},
      },
    );
    print $PAXMLOUTFILE $buffer;


    #### Diagnostic dump
    #if ($peptide_sequence eq 'SENLVSCVDKNLR') {
    #  use Data::Dumper;
    #  print "\n-----\n".Dumper([$ProPro_peptides->{$peptide_sequence}])."\n-----\n";
    #}


    #### Loop over all the observed modifications and write out
    while (my ($mod_peptide_sequence,$mod_attributes) =
      each %{$attributes->{modifications}}) {

      while (my ($mod_charge,$charge_attributes) = each %{$mod_attributes}) {
        my $buffer = encodeXMLEntity(
          entity_name => 'modified_peptide_instance',
          indent => 8,
          entity_type => 'openclose',
          attributes => {
            peptide_string => $mod_peptide_sequence,
            charge_state => $mod_charge,
            best_probability => $charge_attributes->{best_probability},
            n_observations => $charge_attributes->{n_instances},
            search_batch_ids =>
              join(",",keys(%{$charge_attributes->{search_batch_ids}})),
            best_adjusted_probability => $charge_attributes->{best_adjusted_probability},
            n_adjusted_observations => $charge_attributes->{n_adjusted_observations},
            n_sibling_peptides => $charge_attributes->{n_sibling_peptides},
          },
        );
        print $PAXMLOUTFILE $buffer;

      }

    }


    #### Close peptide_instance tag
    $buffer = encodeXMLEntity(
      entity_name => 'peptide_instance',
      indent => 4,
      entity_type => 'close',
    );
    print $PAXMLOUTFILE $buffer;

  }


  return(1);

} # end writeToPAxmlFile



###############################################################################
# closePAxmlFile
###############################################################################
sub closePAxmlFile {
  my %args = @_;

  #### Open and write header
  our $PAXMLOUTFILE;

  #### Close parent build element
  my $buffer = encodeXMLEntity(
    entity_name => 'atlas_build',
    indent => 0,
    entity_type => 'close',
  );
  print $PAXMLOUTFILE $buffer;


  close($PAXMLOUTFILE);

  return(1);

} # end closePAxmlFile



###############################################################################
# writePAxmlFile - deprecated
###############################################################################
sub writePAxmlFile {
  my %args = @_;
  my $output_file = $args{'output_file'} || die("No output file provided");
  my $peptides = $args{'peptide_hash'}
    || die("No output peptide_hash provided");
  my $ProPro_peptides = $args{'ProPro_peptide_hash'}
    || die("No output ProPro_peptide_hash provided");
  my $P_threshold = $args{'P_threshold'};
  my $FDR_threshold = $args{'FDR_threshold'};


  print "Writing output file '$output_file'...\n";


  #### Open and write header
  open(OUTFILE,">$output_file")
    || die("ERROR: Unable to open '$output_file' for write");
  print OUTFILE qq~<?xml version="1.0" encoding="UTF-8"?>\n~;


  #### Write out parent build element
  print OUTFILE encodeXMLEntity(
    entity_name => 'atlas_build',
    indent => 0,
    entity_type => 'open',
    attributes => {
      probability_threshold => $P_threshold,
      probability_threshold => $FDR_threshold,
    },
  );


  #### Loop over all peptides and write out as XML
  while (my ($peptide_sequence,$attributes) = each %{$peptides}) {

    my $ProteinProphet_info = $ProPro_peptides->{$peptide_sequence};
    my $best_initial_probability = $ProteinProphet_info->{best_initial_probability};
    my $best_adjusted_probability = $ProteinProphet_info->{best_adjusted_probability};
    my $n_adjusted_observations = $ProteinProphet_info->{n_instances};
    my $n_sibling_peptides = $ProteinProphet_info->{n_sibling_peptides};

    print OUTFILE encodeXMLEntity(
      entity_name => 'peptide_instance',
      indent => 4,
      entity_type => 'open',
      attributes => {
        original_protein_name => $attributes->{protein_name},
        peptide_accession => $attributes->{peptide_accession},
        peptide_sequence => $peptide_sequence,
        peptide_prev_aa => $attributes->{peptide_prev_aa},
        peptide_next_aa => $attributes->{peptide_next_aa},
        best_probability => $attributes->{best_probability},
        n_observations => $attributes->{n_instances},
        search_batch_ids => join(",",keys(%{$attributes->{search_batch_ids}})),
        best_adjusted_probability => $best_adjusted_probability,
        #best_initial_probability => $best_initial_probability,
        n_adjusted_observations => $n_adjusted_observations,
        n_sibling_peptides => $n_sibling_peptides,
      },
    );


    #### Diagnostic dump
    #if ($peptide_sequence eq 'SENLVSCVDKNLR') {
    #  use Data::Dumper;
    #  print "\n-----\n".Dumper([$ProPro_peptides->{$peptide_sequence}])."\n-----\n";
    #}


    #### Loop over all the observed modifications and write out
    while (my ($mod_peptide_sequence,$mod_attributes) =
      each %{$attributes->{modifications}}) {

      while (my ($mod_charge,$charge_attributes) = each %{$mod_attributes}) {

	my $ProteinProphet_info = $ProPro_peptides->{$peptide_sequence}->
          {modifications}->{$mod_peptide_sequence}->{$mod_charge};
	my $best_initial_probability = $ProteinProphet_info->{best_initial_probability};
	my $best_adjusted_probability = $ProteinProphet_info->{best_adjusted_probability};
	my $n_adjusted_observations = $ProteinProphet_info->{n_instances};
        my $n_sibling_peptides = $ProteinProphet_info->{n_sibling_peptides};

        print OUTFILE encodeXMLEntity(
          entity_name => 'modified_peptide_instance',
          indent => 8,
          entity_type => 'openclose',
          attributes => {
            peptide_string => $mod_peptide_sequence,
            charge_state => $mod_charge,
            best_probability => $charge_attributes->{best_probability},
            n_observations => $charge_attributes->{n_instances},
            search_batch_ids =>
              join(",",keys(%{$charge_attributes->{search_batch_ids}})),
            best_adjusted_probability => $best_adjusted_probability,
            #best_initial_probability => $best_initial_probability,
            n_adjusted_observations => $n_adjusted_observations,
            n_sibling_peptides => $n_sibling_peptides,
          },
        );

      }

    }


    #### Close peptide_instance tag
    print OUTFILE encodeXMLEntity(
      entity_name => 'peptide_instance',
      indent => 4,
      entity_type => 'close',
    );

  }


  #### Close parent build element
  print OUTFILE encodeXMLEntity(
    entity_name => 'atlas_build',
    indent => 0,
    entity_type => 'close',
  );


  close(OUTFILE);

  return(1);

} # end writePAxmlFile



###############################################################################
# encodeXMLEntity
###############################################################################
sub encodeXMLEntity {
  my %args = @_;
  my $entity_name = $args{'entity_name'} || die("No entity_name provided");
  my $indent = $args{'indent'} || 0;
  my $entity_type = $args{'entity_type'} || 'openclose';
  my $attributes = $args{'attributes'} || '';

  #### Define a string from which to get padding
  my $padstring = '                                                       ';
  my $compact = 0;

  #### Define a stack to make user we are nesting correctly
  our @xml_entity_stack;

  #### Close tag
  if ($entity_type eq 'close') {

    #### Verify that the correct item was on top of the stack
    my $top_entity = pop(@xml_entity_stack);
    if ($top_entity ne $entity_name) {
      die("ERROR forming XML: Was told to close <$entity_name>, but ".
	  "<$top_entity> was on top of the stack!");
    }
    return substr($padstring,0,$indent)."</$entity_name>\n";
  }

  #### Else this is an open tag
  my $buffer = substr($padstring,0,$indent)."<$entity_name";


  #### encode the attribute values if any
  if ($attributes) {

    while (my ($name,$value) = each %{$attributes}) {
      if (defined $value  && $value ne "")
      {
        if ($compact) {
  	$buffer .= qq~ $name="$value"~;
        } else {
  	$buffer .= "\n".substr($padstring,0,$indent+8).qq~$name="$value"~;
        }
      }
    }

  }

  #### If an open and close tag, write the trailing /
  if ($entity_type eq 'openclose') {
    $buffer .= "/";

  #### Otherwise push the entity on our stack
  } else {
    push(@xml_entity_stack,$entity_name);
  }


  $buffer .= ">\n";

  return($buffer);

} # end encodeXMLEntity



###############################################################################
# writePeptideListFile - deprecated
###############################################################################
sub writePeptideListFile {
  my %args = @_;
  my $output_file = $args{'output_file'} || die("No output file provided");
  my $peptide_list = $args{'peptide_list'}
    || die("No output peptide_list provided");


  print "Writing output file '$output_file'...\n";


  #### Open and write header
  open(OUTFILE,">$output_file")
    || die("ERROR: Unable to open '$output_file' for write");

  my @score_columns = qw ( xcorr deltacn deltacnstar spscore sprank
			   fval ntt nmc massd icat );

  print OUTFILE "search_batch_id\tsequence\tmodified_sequence\tcharge\tprobability\t".
    "protein_name\tspectrum_query\t".join("\t",@score_columns)."\n";

  print "  - writing ".scalar(@{$peptide_list})." peptides\n";
  foreach my $peptide ( @{$peptide_list} ) {
    print OUTFILE "$peptide->[0]\t$peptide->[1]\t$peptide->[2]\t".
      "$peptide->[3]\t$peptide->[4]\t$peptide->[5]\t$peptide->[6]";
    foreach my $column (@score_columns) {
      print OUTFILE "\t".$peptide->[7]->{$column};
    }
    print OUTFILE "\n";
    print '.';
  }

  print "\n";
  close(OUTFILE);

  return;

} # end writePeptideListFile



###############################################################################
# writePepIdentificationListTemplateFile
###############################################################################
sub writePepIdentificationListTemplateFile {
  my %args = @_;
  my $output_file = $args{'output_file'} || die("No output file provided");
  my $pep_identification_list = $args{'pep_identification_list'}
    || die("No output pep_identification_list provided");

  print "Writing output cache template file '$output_file'...\n";

  #### Open and write header
  open(OUTFILE,">$output_file")
    || die("ERROR: Unable to open '$output_file' for write");

  #### Write out the column names
  my @column_names = qw ( search_batch_id spectrum_query peptide_accession
    peptide_sequence preceding_residue modified_peptide_sequence
    following_residue charge probability massdiff protein_name 
    precursor_intensity total_ion_current signal_to_noise retention_time_sec);

  print OUTFILE join("\t",@column_names)."\n";

  print "  - writing ".scalar(@{$pep_identification_list})." peptides\n";

  my $counter = 0;
  foreach my $identification ( @{$pep_identification_list} ) {
    next if ($identification->[3] =~ /[JUZBOX]/);
    print OUTFILE join("\t",@{$identification})."\n";
    $counter++;
    print "$counter... " if ($counter % 1000 == 0);
  }

  print "\n";
  close(OUTFILE);

  return(1);

} # end writePepIdentificationListTemplateFile



###############################################################################
# readIdentificationListTemplateFile
###############################################################################
sub readIdentificationListTemplateFile {
  my %args = @_;
  my $input_file = $args{'input_file'} || die("No input file provided");
  my $best_prob_per_pep = $args{'best_prob_per_pep'}
    || die("No best_prob_per_pep hash provided");
  my $best_probs_from_protxml = $args{best_probs_from_protxml} || 0;

  print "Reading cache template file '$input_file'...\n";

  #### Open and write header
  open(INFILE,$input_file)
    || die("ERROR: Unable to open '$input_file'");

  my $counter = 0;
  my $line;
  $line = <INFILE>; # throw away header line
  while ($line = <INFILE>) {
    chomp($line);
    my @columns = split(/\t/,$line);
		my @ids = ();
		push @ids,\@columns;
		if (!$best_probs_from_protxml) {
			saveBestProbPerPep(
					best_prob_per_pep => $best_prob_per_pep,
					pep_identification_list => \@ids,
				);
		}

    $counter++;
    print "$counter... " if ($counter % 1000 == 0);
  }

  print "\n";
  close(INFILE);
  print "  - read ". $counter ." PSMs from identification list template file\n";

  return(1);

} # end readIdentificationListTemplateFile


###############################################################################
# saveBestProbPerPep
###############################################################################
sub saveBestProbPerPep{
  my %args = @_;
  my $best_prob_per_pep = $args{'best_prob_per_pep'}
    || die("No best_prob_per_pep hash provided");
  my $pep_identification_list = $args{'pep_identification_list'}
    || die("No pep_identification_list provided");
  #printf "Size of best_prob_per_pep: %d\n",
      #scalar(keys(%{$best_prob_per_pep}));

  foreach my $identification ( @{$pep_identification_list} ) {
    my $prob = $identification->[8];
    if ($prob eq "probability") {
      next;
    }
    ### save probability under all three versions of the peptide
    ### since we may see any of them in the protXML.
    my $stripped_pep = $identification->[3];
    my $modified_pep = $identification->[5];
    # concatenate charge, hyphen, and modified peptide to create unstripped
    my $unstripped_pep = "$identification->[7]-$modified_pep";
    # stripped peptide (no charge, no mods)
    if (exists($best_prob_per_pep->{$stripped_pep})) {
      if ( $prob > $best_prob_per_pep->{$stripped_pep} ) {
        $best_prob_per_pep->{$stripped_pep} = $prob;
      }
    } else {
      $best_prob_per_pep->{$stripped_pep} = $prob;
    }
    # modified peptide
    if ($modified_pep ne $stripped_pep) {
      if (exists($best_prob_per_pep->{$modified_pep})) {
        if ( $prob > $best_prob_per_pep->{$modified_pep} ) {
          $best_prob_per_pep->{$modified_pep} = $prob;
        }
      } else {
        $best_prob_per_pep->{$modified_pep} = $prob;
      }
    }
    # unstripped peptide (with charge and mods)
    if (($unstripped_pep ne $stripped_pep) && ($unstripped_pep ne $modified_pep)) {
      if (exists($best_prob_per_pep->{$unstripped_pep})) {
        if ( $prob > $best_prob_per_pep->{$unstripped_pep} ) {
          $best_prob_per_pep->{$unstripped_pep} = $prob;
        }
      } else {
        $best_prob_per_pep->{$unstripped_pep} = $prob;
      }
    }
  }
}

###############################################################################
# showBestProbPerPep (for development/debugging)
###############################################################################
sub showBestProbPerPep{
  my %args = @_;
  my $best_prob_per_pep = $args{'best_prob_per_pep'}
    || die("No best_prob_per_pep hash provided");
  print"\nBest probability per peptide:\n";
  foreach my $pep (sort ( keys %{$best_prob_per_pep} )) {
    my $best_prob = $best_prob_per_pep->{$pep};
    print "$pep: $best_prob\n";
  }
}


###############################################################################
# remove_string_from_array
###############################################################################
# Remove from a list the first instance of a string.
# Return 1 if successful, 0 if string was not found.
sub remove_string_from_array {
  my $prot = shift(@_);
  my $list_ref = shift(@_);
  my $found = 0;
  my $list_len = scalar(@{$list_ref});
  for (my $i=0; $i<$list_len; $i++) {
    if ($prot eq $list_ref->[$i]) {
       splice(@{$list_ref},$i,1);
       $found = 1;
       last;
    }
  }
  return ($found);
}

###############################################################################
# is_independent_from_set
###############################################################################
sub is_independent_from_set {
  my $prot1 = shift(@_);
  my @canonical_set = @{shift(@_)};
  my $proteins_href = shift(@_);
  for my $prot2 (@canonical_set) {
    if (! is_independent($prot1, $prot2, $proteins_href)) {
      return (0);
    }
  }
  return (1);
}

###############################################################################
# is_independent
###############################################################################
# if, for any pair A & B, 20% of A's peptides are not in B,
# and 20% of B's peptides are not in A, A and B are independent.
# We consider all peptides in protXML, which is correct if the protXML
# is built to include only atlas peps -- as it is as of Fall 2009.
sub is_independent {
  my $indep_fraction = $OPTIONS{min_indep} || 0.2;
  my $threshold = 1.0 - $indep_fraction;
  my $protein1 = shift(@_);
  my $protein2 = shift(@_);
  my $proteins_href = shift(@_);

  my $highly_overlapping = 1;
  my $hitcount = 0;
  my $pepcount = 0;
  my $hitcount2 = 0;
  my $pepcount2 = 0;
  my ( $fraction, $fraction2 );

  # get the list of peptides for each protein from the protXML data
  my @peplist1 = @{$proteins_href->{$protein1}->{unique_stripped_peptides}};
  my @peplist2 = @{$proteins_href->{$protein2}->{unique_stripped_peptides}};

  # count how many prot1 peptides are in prot2
  foreach my $pep1 (@peplist1) {
    $pepcount++;
    for my $pep2 (@peplist2) {
      if ($pep1 eq $pep2) {
	$hitcount++;
	next;
      }
    } 
  }
  # if either protein has only 1 or 2 peps, call them not independent.
  # 08/13/10 tmf: I don't get this.
  if ($pepcount < 3) {return (0);}
  $fraction = $hitcount / $pepcount;
  if ($fraction < $threshold) {
    #print "$protein2 has few ($hitcount) of the same $pepcount peps as $protein1\n";
  }
  # count how many prot2 peps are in prot1
  foreach my $pep2 (@peplist2) {
    $pepcount2++;
    for my $pep1 (@peplist1) {
      if ($pep2 eq $pep1) {
	$hitcount2++;
	next;
      }
    }
  }
  if ($pepcount2 < 3) {return(0);}
  # if overlap below threshold, the two prots are independent.
  $fraction2 = $hitcount2 / $pepcount2 ;
  if (( $fraction < $threshold ) && ( $fraction2 < $threshold)) {
    #print "$protein1 has few ($hitcount) of the same $pepcount peps as $protein2\n";
    $highly_overlapping = 0;
  }
  if ( $highly_overlapping ) {    # if we found a possibly_distinguished
    my $a = int(100*(1-$fraction));
    my $diff_a = $pepcount - $hitcount;
    my $b = int(100*(1-$fraction2));
    my $diff_b = $pepcount2 - $hitcount2;
#    if ( ($a >= 1) && ($a <= 20) && ($diff_a > 2) &&
#         ($b >= 1) && ($b <= 20) && ($diff_b > 2) ) {
#      print "$protein1: $hitcount / $pepcount   $a\%\n";
#      print "$protein2: $hitcount2 / $pepcount2   $b\%\n\n";
#    }
  }
  return (! $highly_overlapping);
}


###############################################################################
# in_covering_set
###############################################################################
sub in_covering_set {
  my %args = @_;
  my $prot = $args{'prot'};
  return (defined $CONTENT_HANDLER->{covering_proteins}->{$prot});
}


###############################################################################
# get_protinfo_href
###############################################################################
sub get_protinfo_href {
  my $protid = shift;
  my $groupnum = $CONTENT_HANDLER->
	 {ProteinProphet_prot_data}->
	 {group_hash}->{$protid};
  print STDERR "ERROR in get_protinfo_href: groupnum undefined for $protid \n"
    if (! defined $groupnum );
  my $protinfo_href = $CONTENT_HANDLER->
      {ProteinProphet_group_data}->{$groupnum}->
      {proteins}->{$protid};
  print STDERR "ERROR in get_protinfo_href: no href found for $protid \n"
    if (! defined $protinfo_href );
  return $protinfo_href;
}

###############################################################################
# same_pep_set
###############################################################################
sub same_pep_set {
  my $prot1 = shift;
  my $prot2 = shift;
  my $protinfo1 = get_protinfo_href ($prot1);
  my $protinfo2 = get_protinfo_href ($prot2);
  my @peps1 = @{$protinfo1->{unique_stripped_peptides}};
  my @peps2 = @{$protinfo2->{unique_stripped_peptides}};
  my $pepstring1 = join("+", @peps1);
  my $pepstring2 = join("+", @peps2);
  return ($pepstring1 eq $pepstring2);
}

###############################################################################
# get_leu_ile_indistinguishables($pepseq);
###############################################################################
sub get_leu_ile_indistinguishables {

  my $pepseq = shift;

  if ( (length $pepseq) == 0 ) {
    my @peplist = ("");
    my $peplist_aref = \@peplist;
    return ( $peplist_aref );
  }
  my $c = chop $pepseq;
  my $peplist_aref = get_leu_ile_indistinguishables ( $pepseq );
  my @peplist = @{$peplist_aref};
  my @new_peplist = ();
  if ($c eq "L" || $c eq "I") {
    for my $pep (@peplist) {
      push (@new_peplist, $pep."L");
      push (@new_peplist, $pep."I");
    }
  } else {
    for my $pep (@peplist) {
      push (@new_peplist, $pep.$c);
    }
  }
  #my $n = scalar @new_peplist;
  #print "$pepseq $n\n";
  $peplist_aref = \@new_peplist;
  return $peplist_aref;
} 
    
###############################################################################
# print_protein_info
###############################################################################
# this sub only works for master ProtPro file, bec. only when reading that
#  file do we save all this protein info.
sub print_protein_info {

  my $prot_group_href = $CONTENT_HANDLER->{ProteinProphet_group_data};
  my @group_number_list = keys(%{$prot_group_href});
  foreach my $group_num (@group_number_list) {
    my $group = $prot_group_href->{$group_num};
    print "Protein group $group_num P=$group->{probability}\n";
    my @protein_list = keys(%{$group->{proteins}});
    if (@protein_list ) {
      foreach my $protein (@protein_list) {
	my $prot_href = $group->{proteins}->{$protein};
	print "   $protein P=$prot_href->{probability} ".
	      "C=$prot_href->{confidence}\n";
	my @indis_list = keys(%{$prot_href->{indist_prots}});
	if ( @indis_list ) {
	  print "    indistinguishable:\n";
	  foreach my $indis_protein (@indis_list) {
	      print "      $indis_protein\n";
	  }
	}
      }
    }
  }
}


###############################################################################
# get_PAidentlist_template_file
###############################################################################
# return the latest PAidentlist template file
sub get_PAidentlist_template_file {

  my %args = @_;
  my $basename = $args{basename};

  my @files = glob("$basename*");
  my $latest_file = $files[0];
  my $latest_date_string = "";
  for my $file (@files) {
    $file =~ /$basename-(.*)/;
    my $date_string = $1;
    if ( later_date( $date_string, $latest_date_string ) ) {
      $latest_file = $file;
      $latest_date_string = $date_string;
    }
  }
  return ($latest_file);
}

sub later_date {
  $a = shift;
  $b = shift;

  if ( !$b ) {
    return 1;
  } elsif ( !$a ) {
    return 0;
  }
    
  if ($a eq $b) {
    return 0;
  }

  my ($a_date, $a_month, $a_year) = $a =~ /(..)(...)(..)/;
  my ($b_date, $b_month, $b_year) = $b =~ /(..)(...)(..)/;


  if ($a_year > $b_year) {
    return 1;
  } elsif ($b_year > $a_year) {
    return 0;
  }

  my %months = ("Jan", 1, "Feb", 2, "Mar", 3, "Apr", 4, "May", 5,
                "Jun", 6, "Jul", 7, "Aug", 8, "Sep", 9, "Oct", 10,
                "Nov", 11, "Dec", 12); 
  if (! defined $months{$a_month} ) {
    return 0;
  } elsif (! defined $months{$b_month} ) {
    return 1;
  }

  if ($months{$a_month} > $months{$b_month}) {
    return 1;
  } elsif ($months{$b_month} > $months{$a_month}) {
    return 0;
  }

  if ($a_date > $b_date) {
    return 1;
  } elsif ($b_date > $a_date) {
    return 0;
  }
}
__DATA__
# Data structures,  May 1, 2009, TMF
# 
# $biosequence_attributes{$biosequence_id}: row from biosequence table
# 
# $CONTENT_HANDLER: a container for info gleaned from parser and used in main
#   my $CONTENT_HANDLER = MyContentHandler->new();
#   $parser->setContentHandler($CONTENT_HANDLER);
# 
#   The next ~100 lines describe contents of $CONTENT_HANDLER:
# 
#   ->{counter}
#   ->{best_prob_per_pep}
#   ->{search_batch_id}
#   ->{document_type}               pepXML, protXML, ...
#   ->{protxml_type}                master or expt
#   ->{OPTIONS}                     command line options
#   ->{P_threshold}
#   ->{FDR_threshold}
# 
# Temporary containers used during parsing
# ----------------------------------------
# 
#   ->{object_stack}                 array ref. Holds stuff during parse.
# 
# pepXML parsing
#   ->{pepcache}                    info stored permanently in (d)
#     ->{spectrum}
#     ->{charge}                    
#     ->{peptide}
#     ->{peptide_prev_aa}
#     ->{peptide_next_aa}
#     ->{protein_name}
#     ->{massdiff}
#     ->{modifications}            
#       ->{$pos}
#     ->{scores}
#       ->{probability}
#       ->{$score_type}
# 
# protXML parsing
#   ->{pepcache}                      info stored permanently in (c)
#     ->{modifications}
#     ->{peptide}
#     ->{charge}
#     ->{initial_probability}
#     ->{nsp_adjusted_probability}
#     ->{n_sibling_peptides}
#     ->{n_instances}
#     ->{indistinguishable_peptides}
#       ->{$peptide_sequence}         set to 1 for each indistinguishable seq
#     ->{weight}
#     ->{apportioned_observations}             computed from others
#     ->{expected_apportioned_observations}   computed from others
# 
#   ->{protein_group_number}          info stored permanently in (b)
#   ->{protein_group_probability}
#   ->{protein_name}
#   ->{protein_number}
#   ->{protein_probability}
# 
#   ->{protcache}                     protXML start/end element (prot);
#     ->{indist_prots}                             info moved to groupcache
#       ->{$protein_name}             set to 1 for each indist_prot name
#     ->{unique_stripped_peptides}
#     ->{npeps}
#     ->{total_number_peptides}
#     ->{probability}
#     ->{confidence}
#     ->{subsuming_protein_entry}
#     ->{PSM_count}
#     ->{total_enzymatic_termini}
# 
#   ->{groupcache}                    protXML start/end element (group);
#     ->{proteins}                             info stored permanently in (a)
#       ->{$protein_name}
# 	    ->{probability}
# 	    ->{confidence}
# 	    ->{unique_stripped_peptides}
# 	    ->{subsuming_protein_entry}
#           ->{PSM_count}
#           ->{npeps}
#           ->{total_enzymatic_termini}
# 
# 
# Persistant containers
# ---------------------
# 
# d)->{pep_identification_list}      list of array references. each array:
#      search batch ID, spectrum, pep accession, pepseq, prev aa, next aa,
# 		   modified pep, charge, proability, massdiff, prot name.
# 
#   ->{best_prob_per_pep}
#     ->{pep_key}
# 
# 
# c)->{ProteinProphet_pep_data}          reset to {} for each expt protPro file.
#          Used for:
#            [prob] peptide probabilities
#            [pid]  peptide protein ID assignment
#     ->{$pep_key}                      
#       ->{search_batch_id}              (maybe unused)
#       ->{charge}                       (maybe unused)
#       ->{initial_probability}          [prob]
#       ->{nsp_adjusted_probability}     [prob]
#       ->{n_sibling_peptides}           [prob]
#       ->{n_adjusted_observations}      [prob]
#        ----
#       ->{protein_name}                 determined by [pid]. Used to write
#                                             peptide identlist!
#       ->{protein_probability}          [pid], but used only w/in storePepInfoFromProtXML!
#       ->{protein_group_probability}    [pid], but used only w/in storePepInfoFromProtXML!
# 
# 
#   ->{ProteinProphet_group_data}     used to determine prot ident list
# a)  ->{$group_num} 
#       ->{proteins}
# 	->{$protein_name}
# 	  ->{probability}
# 	  ->{confidence}
# 	  ->{unique_stripped_peptides}
#         ->{subsuming_protein_entry}
#         ->{presence_level}
#         ->{represented_by}   #highest prob prot in group
#         ->{PSM_count}
#         ->{npeps}
#         ->{total_enzymatic_termini}
# 
#   ->{ProteinProphet_prot_data}      used to determine prot ident list
#     ->{group_hash}
# b)    ->{$protein_name}             prot_name -> group_num
#     ->{atlas_prot_list}             
#       ->{$protid}                   set to 1 if protein is in this atlas
#     ->{pep_prot_hash}
#       ->{$pepseq}                   pepseq -> array of protein IDs
#     ->{preferred_protID_hash}
#       ->{$protid}                   protXML protID -> preferred protID
# 
# End $CONTENT_HANDLER description
##############################################################################

