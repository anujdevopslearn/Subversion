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
#
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
# 
#   ->{groupcache}                    protXML start/end element (group);
#     ->{proteins}                             info stored permanently in (a)
#       ->{$protein_name}
# 	    ->{probability}
# 	    ->{confidence}
# 	    ->{unique_stripped_peptides}
# 	    ->{subsuming_protein_entry}
#           ->{apportioned_PSM_count}
# 
# 
# Persistant containers
# ---------------------
# 
# d)->{pep_identification_list}      list of array references. each array:
# 		   spectrum, pep accession, pepseq, prev aa, next aa,
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
#         ->{apportioned_PSM_count}
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

use strict;
use POSIX;  #for floor()
use Getopt::Long;
use XML::Xerces;
use FindBin;
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
use SBEAMS::PeptideAtlas::Tables;
use SBEAMS::PeptideAtlas::ProtInfo;
use SBEAMS::PeptideAtlas;

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
  --FDR_threshold     FDR threshold to accept. Default 0.0001.
  --P_threshold       Probability threshold (e.g. 0.9) instead of FDR thresh.
  --output_file       Filename to which to write the peptides
  --master_ProteinProphet_file       Filename for a master ProteinProphet
                      run that should be used instead of individual ones.
  --slope_for_abundance   Slope for protein abundance calculation
  --yint_for_abundance    Y-intercept for protein abundance calculation
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
  --splib_filter      Filter out spectra not in spectral library
                      DATA_FILES/${build_version}_all_Q2.sptxt


 e.g.:  $PROG_NAME --verbose 2 --source YeastInputExperiments.tsv

EOU

# Removed from usage, because nonfunctional.
# --search_batch_ids  Comma-separated list of SBEAMS-Proteomics seach_batch_ids

#### If no parameters are given, print usage information
unless ($ARGV[0]){
  print "$USAGE";
  exit;
}


#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
  "validate=s","namespaces","schemas",
  "source_file:s","search_batch_ids:s","P_threshold:f","FDR_threshold:f",
  "output_file:s","master_ProteinProphet_file:s",
  "slope_for_abundance:f","yint_for_abundance:f","per_expt_pipeline",
  "biosequence_set_id:s", "best_probs_from_protxml", "min_indep:f",
  "APD_only", "protlist_only", "splib_filter",
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

my $PEP_PROB_CUTOFF = 0.5;


#### Process options
my $source_file = $OPTIONS{source_file} || '';
my $APDTsvFileName = $OPTIONS{output_file} || '';
my $search_batch_ids = $OPTIONS{search_batch_ids} || '';
my $bssid = $OPTIONS{biosequence_set_id} || "10" ; #yeast is default
my $APD_only = $OPTIONS{APD_only} || 0;
my $protlist_only = $OPTIONS{protlist_only} || 0;
my $validate = $OPTIONS{validate} || 'never';
my $namespace = $OPTIONS{namespaces} || 0;
my $schema = $OPTIONS{schemas} || 0;
my $best_probs_from_protxml = $OPTIONS{best_probs_from_protxml} || 0;
my $splib_filter = $OPTIONS{splib_filter} || 0;


#### Fetch the biosequence data for writing into APD file
####  and for estimating protein abundances.
if ( defined $bssid ) {
  my $sql = qq~
     SELECT biosequence_id,biosequence_name,biosequence_gene_name,
            biosequence_accession,biosequence_desc,biosequence_seq
       FROM $TBAT_BIOSEQUENCE
      WHERE biosequence_set_id = $bssid
  ~;
  print "Fetching all biosequence data...\n";
  print "$sql";
  my @rows = $sbeams->selectSeveralColumns($sql);
  foreach my $row (@rows) {
    # Hash each biosequence_id to its row
    $biosequence_attributes{$row->[1]} = $row;
    #print "$row->[1]\n";
  }
  print "  Loaded ".scalar(@rows)." biosequences.\n";

  #### Just in case the table is empty, put in a bogus hash entry
  #### to prevent triggering a reload attempt
  $biosequence_attributes{' '} = ' ';
} else {
  print "WARNING: no biosequence_set provided; gene info won't be
written to APD file and protein abundances will not be estimated.\n";
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
  }

  #### If this is the search_hit, then store some attributes
  #### Note that this whole logic will break if there's more than one
  #### search_hit, which shouldn't be true so far
  if ($localname eq 'search_hit') {
    die("ERROR: Multiple search_hits not yet supported!")
      if (exists($self->{pepcache}->{peptide}));
    $self->{pepcache}->{peptide} = $attrs{peptide};
    $self->{pepcache}->{peptide_prev_aa} = $attrs{peptide_prev_aa};
    $self->{pepcache}->{peptide_next_aa} = $attrs{peptide_next_aa};
    $self->{pepcache}->{protein_name} = [$attrs{protein}];
    $self->{pepcache}->{massdiff} = $attrs{massdiff};
  }

  #### If this is an alternative protein, push the protein name
  #### onto the current peptide's list of protein names
  if ($localname eq 'alternative_protein') {
    if ($attrs{protein}) {
      push (@{$self->{pepcache}->{protein_name}}, $attrs{protein});
    }
  }


  #### If this is the mass mod info, then store some attributes
  if ($localname eq 'modification_info') {
    if ($attrs{mod_nterm_mass}) {
      $self->{pepcache}->{modifications}->{0} = $attrs{mod_nterm_mass};
    }
    if ($attrs{mod_cterm_mass}) {
      my $pos = length($self->{pepcache}->{peptide})+1;
      $self->{pepcache}->{modifications}->{$pos} = $attrs{mod_cterm_mass};
    }
  }


  #### If this is the mass mod info, then store some attributes
  if ($localname eq 'mod_aminoacid_mass') {
    $self->{pepcache}->{modifications}->{$attrs{position}} = $attrs{mass};
  }


  #### If this is the search score info, then store some attributes
  if ($localname eq 'search_score') {
    $self->{pepcache}->{scores}->{$attrs{name}} = $attrs{value};
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

  #### Push information about this element onto the stack
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
    $self->{protcache}->{total_number_peptides} = $attrs{total_number_peptides};
    $self->{protcache}->{probability} = $attrs{probability};
    $self->{protcache}->{confidence} = $attrs{confidence};
    $self->{protcache}->{subsuming_protein_entry} =
                $attrs{subsuming_protein_entry};
    # initialize cumulative count of PSMs from participating peptides
    $self->{protcache}->{apportioned_PSM_count} = 0;
  }


  #### If this is an indistinguishable protein, record it in the cache
  #### for the current protein
  if ($localname eq 'indistinguishable_protein') {
    my $protein_name = $attrs{protein_name} || die("No protein_name");
    $self->{protcache}->{indist_prots}->{$protein_name} = 1;
  }

  #### If this is the modification info, then store some attributes
  ####  TMF 06/23/09: I don't think these attributes ever happen.
  if ($localname eq 'modification_info') {
    if ($attrs{mod_nterm_mass}) {
      $self->{pepcache}->{modifications}->{0} = $attrs{mod_nterm_mass};
    }
    if ($attrs{mod_cterm_mass}) {
      my $pos = length($self->{pepcache}->{peptide})+1;
      $self->{pepcache}->{modifications}->{$pos} = $attrs{mod_cterm_mass};
    }
  }


  #### If this is the mass mod info, then store some attributes
  ####  TMF 06/23/09: I don't think this tag ever happens.
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

    ### Compute a couple secondary attributes
    $self->{pepcache}->{apportioned_observations} =
          $attrs{weight} * $attrs{n_instances};
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
	    \@indis);
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


  #### If this peptide has an indistinguishable twin, record it
  ####  TMF 06/23/09: discovered  that, often, indistinguishable_peptides have an embedded
  ####    mod with charge stored in an attribute. We were leaving the
  ####    embedded mod but not pre-pending the charge, giving us a
  ####    partially stripped peptide. The rest of this program expects
  ####    either stripped or unstripped peptides, so now we prepend the charge.

  if ($localname eq 'indistinguishable_peptide') {
    my $peptide_sequence = $attrs{peptide_sequence} || die("No sequence");
    # TMF 06/23/09: prepend the charge.
    if ($attrs{charge}) {
      $peptide_sequence = $attrs{charge} . "-" . $peptide_sequence;
    }
    $self->{pepcache}->{indistinguishable_peptides}->{$peptide_sequence} = 1;
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
             $self->{pepcache}->{protein_name});
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

    my $charge = $self->{pepcache}->{charge};
    my $modifications = $self->{pepcache}->{modifications};
    my $pep_key = storePepInfoFromProtXML( $self, $peptide_sequence,
         $charge, $modifications, $get_best_pep_probs);
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
      ####  (this list does not include indistinguishables)
      my $this_protein = $self->{protein_name};
      if (! defined $self->{ProteinProphet_prot_data}->{pep_prot_hash}->
	       {$peptide_sequence}) {
	@{$self->{ProteinProphet_prot_data}->{pep_prot_hash}->
	       {$peptide_sequence}} = ($this_protein);
      } else {
	push(@{$self->{ProteinProphet_prot_data}->{pep_prot_hash}->
	       {$peptide_sequence}}, $this_protein);
      }
      #### add this peptide's expected_apportioned_observations
      #### to apportioned_PSM_count for this protein
      $self->{protcache}->{apportioned_PSM_count}
          += $self->{pepcache}->{expected_apportioned_observations};
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
      $self->{groupcache}->{proteins}->{$protein_name}->{total_number_peptides}
             = $self->{protcache}->{total_number_peptides};
      $self->{groupcache}->{proteins}->{$protein_name}->
	                                   {subsuming_protein_entry} =
             $self->{protcache}->{subsuming_protein_entry};
      $self->{groupcache}->{proteins}->{$protein_name}->
                                           {apportioned_PSM_count} =
             $self->{protcache}->{apportioned_PSM_count};

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
      $modified_peptide .= 'n['.int($modifications->{$i}).']';
    }
    for ($i=1; $i<=length($peptide_sequence); $i++) {
      my $aa = substr($peptide_sequence,$i-1,1);
      if ($modifications->{$i}) {
        $aa .= '['.int($modifications->{$i}).']';
      }
      $modified_peptide .= $aa;
    }
    if ($modifications->{$i}) {
      $modified_peptide .= 'c['.int($modifications->{$i}).']';
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
# For a given <peptide> tag in a protXML file, store the protein ID of highest
# probability among all <protein> tags containing that pep_key.
# This will always assign the same protein to a particular peptide,
# and should give us a fairly minimal and high-quality set of protein
# identifications for the PAidentlist, allowing it to
# be used as input to Mayu.

sub assignProteinID {
  my $self = shift;
  my $pep_key = shift;

  # Other data (peptide string, charge, prob) should already be stored.
  if ( !defined $self->{ProteinProphet_pep_data}->{$pep_key} ) {
    print "ERROR: no data yet stored for $pep_key in assignProteinID.\n";
  }

  # create hash ref, if necessary, and define a nickname for it
  if (!defined $self->{ProteinProphet_pep_protID_data}->{$pep_key}) {;
    $self->{ProteinProphet_pep_protID_data}->{$pep_key} = {};
  }
  my $pepProtInfo = $self->{ProteinProphet_pep_protID_data}->{$pep_key};

  # first time we've tried to assign a protein to this peptide
  if (!defined $pepProtInfo->{protein_probability} ) {
    $pepProtInfo->{protein_probability} = $self->{protein_probability};
    $pepProtInfo->{protein_group_probability} =
			      $self->{protein_group_probability};
    $pepProtInfo->{protein_name} = $self->{protein_name};
  # we've already made an assignment to this pep. Is this one better?
  } else {
    if ( ( $self->{protein_probability} >
	     $pepProtInfo->{protein_probability} )) {
        $pepProtInfo->{protein_probability} = $self->{protein_probability};
        $pepProtInfo->{protein_group_probability} =
                                        $self->{protein_group_probability};
        $pepProtInfo->{protein_name} = $self->{protein_name};
    }
  }
}




###############################################################################
###############################################################################
###############################################################################
# continuation of main package
###############################################################################
package main;


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

  my $CONTENT_HANDLER = MyContentHandler->new();
  $parser->setContentHandler($CONTENT_HANDLER);

  $CONTENT_HANDLER->setVerbosity($VERBOSE);
  $CONTENT_HANDLER->{counter} = 0;
  $CONTENT_HANDLER->{P_threshold} = $P_threshold;
  $CONTENT_HANDLER->{FDR_threshold} = $FDR_threshold;
  $CONTENT_HANDLER->{OPTIONS} = \%OPTIONS;

  my %decoy_corrections;
  my $sorted_identlist_file = "DATA_FILES/PeptideAtlasInput_sorted.PAidentlist";
  my @column_names = qw ( search_batch_id spectrum_query peptide_accession
    peptide_sequence preceding_residue modified_peptide_sequence
    following_residue charge probability massdiff protein_name
    protXML_nsp_adjusted_probability
    protXML_n_adjusted_observations protXML_n_sibling_peptides );

  unless ($APD_only) {

  #### Array of documents to process in order
  my @documents;

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

  #### If a source file containing the list of search_batch_ids was provided,
  #### read it and find the corresponding documents
  if ($source_file && !$protlist_only) {
    my @search_batch_ids;
    open(SOURCE_FILE,$source_file)
      || die("ERROR: Unable to open $source_file");
    while (my $line = <SOURCE_FILE>) {
      chomp($line);
      next if ($line =~ /^\s*#/);
      next if ($line =~ /^\s*$/);
      my ($search_batch_id,$path) = split(/\s+/,$line);
      my $filepath = $path;

      # Modified to use library method, found in SearchBatch.pm.  New file
      # names should be added there; the preferred list below is considered
      # first before default names, allows caller to determine priority.
      if ($filepath !~ /\.xml/) {
          my @preferred = ( 
                        'interact-combined.pep.xml',   #iProphet output
                        'interact-ipro.pep.xml',       #iProphet output
                        'interact-prob.pep.xml',
                        'interact-prob.xml',
                        'interact.pep.xml',
                        'interact.xml',
                        'interact-specall.xml',
                        'interact-spec.xml',
                        'interact-spec.pep.xml' );

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
      print "Will read $pepXML_document->{filepath}\n";

      push(@search_batch_ids,$search_batch_id);
    }
    $search_batch_ids = join(',',@search_batch_ids);
  }

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
      print "Will get best initial probs from pepXML files.\n";
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
	  pep_identification_list => $CONTENT_HANDLER->{pep_identification_list},
	);

      #### Otherwise read the pepXML
      } else {

	print "INFO: Reading $filepath; saving records with prob >= $PEP_PROB_CUTOFF...\n"
	   unless ($QUIET);
	$CONTENT_HANDLER->{document_type} = $document->{document_type};
	$parser->parse (XML::Xerces::LocalFileInputSource->new($filepath));
	print "\n";

	#### Write out the template cache file
	writePepIdentificationListTemplateFile(
	  output_file => "${identlist_file}-template",
	  pep_identification_list => $CONTENT_HANDLER->{pep_identification_list},
	);
      }

      #### Loop through all search_hits, saving the best probability
      #### seen for each peptide in a hash.
      if (!$best_probs_from_protxml) {
	saveBestProbPerPep(
	    best_prob_per_pep => $CONTENT_HANDLER->{best_prob_per_pep},
	    pep_identification_list => $CONTENT_HANDLER->{pep_identification_list},
	  );
      }
    }
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

###############################################################################
# print_protein_info
###############################################################################
  # why doesn't it work for this to be at the end of this file?
  # 07/13/09: becaues $CONTENT_HANDLER is defined within scope of
  #   main()
  # this sub only works for master ProtPro file, bec. only when reading that
  #  file do we save all this protein info.
  sub print_protein_info {

    # the use of CONTENT_HANDLER below gives a warning: value will not
    # stay shared. Sounds dangerous.
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

  #### Development: see if the protein info got stored.
  #print_protein_info();

  #### Second pass: read ProteinProphet file(s), read each cache file again,
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
	close(DECOY_FILE);
      } else {
	#print "WARNING: No decoy correction\n";
      }

      #### Read the peptide identlist template file,
      #### then write the final peptide identlist file
      my $identlist_file = $filepath;
      $identlist_file =~ s/\.xml$/.PAidentlist/;

      if ( -e "${identlist_file}-template") {
	readIdentificationListTemplateFile(
	  input_file => "${identlist_file}-template",
	  pep_identification_list => $CONTENT_HANDLER->{pep_identification_list},
	  );
      } else {
	die("ERROR: ${identlist_file}-template not found\n");
      }

      writePepIdentificationListFile(
	output_file => $identlist_file,
	pep_identification_list => $CONTENT_HANDLER->{pep_identification_list},
	ProteinProphet_pep_data => $CONTENT_HANDLER->{ProteinProphet_pep_data},
	ProteinProphet_pep_protID_data =>
	     $CONTENT_HANDLER->{ProteinProphet_pep_protID_data},
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
    my $combined_identlist_file = "DATA_FILES/PeptideAtlasInput_concat.PAidentlist";
    open(OUTFILE,">$combined_identlist_file") ||
      die("ERROR: Unable to open for write '$combined_identlist_file'");
    close(OUTFILE);

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

    #### Read sorted, combined file and hash protein identifiers to
    #### peptide arrays (unnecessary) and, for each pep seen, get prots
    #### from pep->protlist hash and add to atlas_prot_list.
    my %pephash;
    my %prothash;
    # list of all (non-identical) proteins in the atlas
    $CONTENT_HANDLER->{ProteinProphet_prot_data}->{atlas_prot_list} = {};
    print "INFO: Reading master list into protein->peptide hash.\n";
    open (IDENTLISTFILE, $sorted_identlist_file) ||
      die("ERROR: Unable to open for reading '$sorted_identlist_file'");
    my %peps_not_found = ();
    while (my $line = <IDENTLISTFILE>) {
      chomp ($line);
      my @fields = split(" ", $line);
      my $protid = $fields[10];
      my $pepseq = $fields[3];

      # Hash protein identifiers to peptide arrays.
      # Only necessary if we're going to do something with the
      # identifiers.
      if (defined $pephash{$protid}) {
	push (@{$pephash{$protid}}, $pepseq);
      } else {
	$pephash{$protid} = [$pepseq];
      }

      # The below may be undefined if it's an indistinguishable peptide.
      # No harm -- its prots should be stored under its twin.
      if (defined $CONTENT_HANDLER->{ProteinProphet_prot_data}->
	 {pep_prot_hash}->{$pepseq} ) {
	my @pep_protlist = @{$CONTENT_HANDLER->{ProteinProphet_prot_data}->
	   {pep_prot_hash}->{$pepseq}};
	for my $protid2 (@pep_protlist) {
            $CONTENT_HANDLER->{ProteinProphet_prot_data}->{atlas_prot_list}->
	       {$protid2} = 1;
	}
      } else {
	$peps_not_found{$pepseq} = 1;
      }

      # activate the following to check whether each peptide sequence
      #  was assigned the same protID in each instance.
      # If it was, there should be no warnings.
      if (0) {
      if ( defined $prothash{$pepseq}) {
	if ( $prothash{$pepseq} ne $protid ) {
	  print "WARNING: $pepseq mapped to both $prothash{$pepseq} and $protid\n";
	}
      } else {
	$prothash{$pepseq} = ($protid);
      }
      }
    }

    my @peps_not_found = keys %peps_not_found;
    if (scalar(@peps_not_found) > 0) {
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
    #### Must do this by group. Within each group, find those that
    #### are in this build. Then, select highest prob for canonical.
    #### Label others possibly_distinguished or subsumed according to their
    #### prob.

    my $pep_protid_count = 0;

    #my @protein_list = keys(%pephash);
    my @group_list = keys(%{$CONTENT_HANDLER->{ProteinProphet_group_data}});
    for my $group_num (@group_list) {

      my $proteins_href = $CONTENT_HANDLER->{ProteinProphet_group_data}->
		   {$group_num}->{proteins};
      my @protein_list = ();

      # Collect those proteins in this group that are going to be in this
      # atlas build -- those that the atlas peptides map to.
      # 08/13/09: now we can use all the prots, because protXML
      # contains only prots that contain atlas peps. Can change this
      # code.
      for my $group_prot ( keys(%{$proteins_href})) {
	if (defined $CONTENT_HANDLER->{ProteinProphet_prot_data}->
	       {atlas_prot_list}->{$group_prot}) {
	  push (@protein_list, $group_prot);
	}
      }

      my $nproteins = scalar(@protein_list);
      my $highest_prob = -1.0;
      my $highest_nobs = -1;
      my $highest_prob_prot;

      # If any proteins in this group will be in atlas ...
      if ( $nproteins > 0 ) {
	# ... determine each protein's presence_level.

        if (0) {   #Any high-prob prots in this group not included in atlas?
	for my $group_prot ( keys(%{$proteins_href})) {
	  my $prob = $proteins_href->{$group_prot}->{probability};
	  print "$group_prot P=$prob ";
	  if (defined $CONTENT_HANDLER->{ProteinProphet_prot_data}->
		 {atlas_prot_list}->{$group_prot}) {
	    print "IN ATLAS!";
	  } elsif ($prob > 0.2) {
	    print "HIGH PROB, NOT IN ATLAS";
	  }
	  print "\n";
	}
        }

	# A subset of the atlas proteins in a group is canonical,
        # defined as such:
	# - subset includes prot of highest prob. (PSM count is
	#     tie-breaker.)
	# - all members of subset are independent of each other
	# - each non-member of the subset is non-independent of at
	#    least one member of the subset.
	# Find this subset

	# first, find the highest prob / PSM count protein
	foreach my $protein (@protein_list) {
	  my $prot_href = $proteins_href->{$protein};
	  #print " $protein ";
	  # Just for yucks, see if this protein is in the list of 
	  # proteins that peptides are identified to in PAidentlist
	  if (defined $pephash{$protein}) {
	    $pep_protid_count++;
	    #print "YES! ";
	  } else {
	    #print "NO. ";
	  }
	  my $this_prob = $prot_href->{probability};
	 # my $this_nobs = $prot_href->{total_number_peptides};
	  my $this_nobs = $prot_href->{apportioned_PSM_count};
	  if (($this_prob > $highest_prob) ||
              (($this_prob == $highest_prob) &&
               ($this_nobs > $highest_nobs))) {
	    $highest_prob_prot = $protein;
	    $highest_prob = $this_prob;
            $highest_nobs = $this_nobs;
	  }
	}
	#print "\n";

	# Now, find all the other canonicals and label them.
	my @canonical_set = ($highest_prob_prot);
        my @remaining_proteins = @protein_list;
 	my $found = remove_string_from_array($highest_prob_prot, \@remaining_proteins);
 	if (! $found) {
 	  print "BUG: $highest_prob_prot not found in @protein_list\n";
 	}
 	my $done = 0;
 	my $found_canonical;
 	while (! $done ) {
 	  $found_canonical = 0;
 	  for my $prot (@remaining_proteins) {
 	    if (is_independent_from_set($prot, \@canonical_set,
 		     $proteins_href)) {
 	      push (@canonical_set, $prot);
 	      my $found = remove_string_from_array($prot, \@remaining_proteins);
 	      if (! $found) {
 		print "BUG: $highest_prob_prot not found in @protein_list\n";
 	      }
 	      $found_canonical = 1;
 	      last;
 	    }
 	  }
 	  $done = ! $found_canonical;
 	}
	my $n_canonicals = scalar(@canonical_set);
	my $n_others = scalar(@remaining_proteins);
#	print "Group $group_num: $n_canonicals canonicals, $n_others others,".
#	       " $nproteins total\n";
	if (0 && $n_canonicals > 2) {
	  print "Canonicals:\n   ";
	  for my $prot (@canonical_set) {
	    print "$prot ";
	  }
	  print "\n";
	}
	for my $prot (@canonical_set) {
	  $proteins_href->{$prot}->{presence_level} = "canonical";
	  $proteins_href->{$prot}->{represented_by} = $highest_prob_prot;
          $proteins_href->{$prot}->{subsumed_by} = '';
	}

	# Now, label the non-canonicals.
	foreach my $protein (@remaining_proteins) {
	  my $prot_href = $proteins_href->{$protein};
	  my $this_prob = $prot_href->{probability};
          my $is_subsumed = defined $prot_href->{subsuming_protein_entry};
	  $prot_href->{represented_by} = $highest_prob_prot;
	  if ( $is_subsumed ) {
	    $prot_href->{presence_level} = "subsumed";
            my $subsuming_proteins = $prot_href->{subsuming_protein_entry};
            my @subsuming_proteins = split(/ /,$subsuming_proteins);
	    my %matches = ();
            if ($subsuming_proteins ne "") {
              for my $subsuming_prot (@subsuming_proteins) {
                # map to preferred protID
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
	  } else {
	    $prot_href->{presence_level} = "possibly_distinguished";
	    $prot_href->{subsumed_by} = '';
	  }
	}

        # Run through possibly_distinguished proteins and see if any
        # are NTT-subsumed.
        
        # Create hashes of all canonical, possibly_distinguished
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
        # For each possibly_distinguished
        for my $protein (keys %possibly_dist_hash) {
          # check that it's still in the poss_dist list
          if (! defined $possibly_dist_hash{$protein}) {
            next;
          }
          # Gather all canonicals, poss_dist with exact same pep set.
          my @prots_with_same_peps = ($protein);
          sub same_pep_set {
	    my %args = @_;
            my $protein1 = $args{'protein1'};
            my $protein2 = $args{'protein2'};
            # I don't understand why I need to pass this in.
            my $proteins_href = $args{'proteins_href'};
	    my $prot_href1 = $proteins_href->{$protein1};
	    my $prot_href2 = $proteins_href->{$protein2};
            my $peps1 = join('+', @{$prot_href1->{unique_stripped_peptides}});
            my $peps2 = join('+', @{$prot_href2->{unique_stripped_peptides}});
            return ($peps1 eq $peps2);
          }
          for my $protein2 (keys %canonical_plus_possibly_dist_hash) {
            if ($protein eq $protein2) {
              next;
            }
            if (same_pep_set
                 (proteins_href => $proteins_href,
                  protein1 => $protein, protein2 => $protein2)) {
              
	      my $prot_href = $proteins_href->{$protein};
	      my $prot_href2 = $proteins_href->{$protein2};
              #print "$protein ($prot_href->{presence_level}, $prot_href2->{probability}) $protein2 ($prot_href2->{presence_level}, $prot_href2->{probability}) same pep set in group $group_num\n";
              push (@prots_with_same_peps, $protein2);
            }
          }
          # If any, set aside the one with highest prob.
          # In the case of a tie, set aside the one labelled canonical.
          if ( scalar (@prots_with_same_peps) > 1 ) {
            my $highest_prob = -1;
            my $highest_prob_prot;
            for my $protein3 (@prots_with_same_peps) {
	      my $prot_href3 = $proteins_href->{$protein3};
              my $this_prob = $prot_href3->{probability};
              if (($this_prob > $highest_prob) ||
                  ($this_prob == $highest_prob &&
                   $prot_href3->{presence_level} eq "canonical"))  {
                $highest_prob_prot = $protein3;
                $highest_prob = $this_prob;
              }
            }
            #print "highest prob prot $highest_prob_prot $highest_prob\n";
            remove_string_from_array($highest_prob_prot,
                                     \@prots_with_same_peps);
              
	    # None of the others should be canonical. (If it is, # warn.)
            # Label them ntt-subsumed and remove from
            # possibly_distinguished hash.
            for my $protein3 (@prots_with_same_peps) {
	      my $prot_href = $proteins_href->{$protein3};
              if ($prot_href->{presence_level} eq "canonical") {
                print "WARNING: $protein3 is canonical, yet is not the highest prob protein among those with same peps! Probably from a very large protein group with multiple canonicals. It will be marked ntt-subsumed.\n";
              }
	      $prot_href->{presence_level} = "ntt-subsumed";
	      $prot_href->{subsumed_by} = $highest_prob_prot;
              # Give the protein counts for the ntt-subsumed protein
              # to its subsumed_by protein.
              $proteins_href->{$highest_prob_prot}->{apportioned_PSM_count}
                += $prot_href->{apportioned_PSM_count};
              $prot_href->{apportioned_PSM_count} = 0;
	      undef $possibly_dist_hash{$protein3};
            }
          }
        }
      }
    }

    # This number should (and did, in a test) match the number of unique
    # entries in field 11 of the combined PAidentlist file.
    print "$pep_protid_count protein IDs counted in peptide identlist.\n";

    #### Write the protein identlist and relationship files.
    #### This is info on any protein that any atlas peptide maps to.
    my $prot_identlist_file = "DATA_FILES/PeptideAtlasInput.PAprotlist";
    writeProtIdentificationListFile(
      output_file => $prot_identlist_file,
      ProteinProphet_prot_data => $CONTENT_HANDLER->{ProteinProphet_prot_data},
	# hashes protID to group. Group contains all protein info.
      ProteinProphet_group_data =>
		 $CONTENT_HANDLER->{ProteinProphet_group_data},
    );
  }

  } # end unless $APD_only

  unless ($protlist_only) {

    #### Open APD format TSV file for writing
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
      if ($prev_peptide_sequence && $peptide_sequence ne $prev_peptide_sequence) {
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
	$prev_peptide_sequence = $peptide_sequence;
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

  print "  - read $n_peptides peptides from spectral library\n";

  return($peptides);

} # end readSpectralLibraryPeptides 



###############################################################################
# writePepIdentificationListFile
###############################################################################
sub writePepIdentificationListFile {
  my %args = @_;
  my $output_file = $args{'output_file'} || die("No output file provided");
  my $pep_identification_list = $args{'pep_identification_list'}
    || die("No output pep_identification_list provided");
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
  my @column_names = qw ( search_batch_id spectrum_query peptide_accession
    peptide_sequence preceding_residue modified_peptide_sequence
    following_residue charge probability massdiff protein_name
    protXML_nsp_adjusted_probability
    protXML_n_adjusted_observations protXML_n_sibling_peptides );

  print OUTFILE join("\t",@column_names)."\n";

  print "  - filtering ".scalar(@{$pep_identification_list})." peptides and writing to identification list file\n";

  my %consensus_lib = ( found => [], missing => [] );

  #print "ProteinProphet data:\n";
  #while ((my $pep, my $info) = each ( %{$ProteinProphet_pep_data} )) {
    #print "  $pep $info->{nsp_adjusted_probability}\n";
  #}

  foreach my $identification ( @{$pep_identification_list} ) {

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
#    } elsif ($ProteinProphet_pep_data->{$modified_peptide}) {
#      $pep_key = $modified_peptide;
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
        $initial_probability = $best_prob_per_pep->{$pep_key} - .001;
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
        $identification->[10] = $ProteinProphet_pep_protID_data->
           {$pep_key}->{protein_name};
      } elsif ($ProteinProphet_pep_protID_data->{$peptide_sequence}->{protein_name}){
        $identification->[10] = $ProteinProphet_pep_protID_data->
           {$peptide_sequence}->{protein_name};
      } else {
        $peps_without_protxml_protid{$pep_key} = 1;
      }
      $adjusted_probability = $info->{nsp_adjusted_probability};
      $n_adjusted_observations = $info->{n_adjusted_observations};
      $n_sibling_peptides = $info->{n_sibling_peptides};
      push(@{$identification},$adjusted_probability,$n_adjusted_observations,$n_sibling_peptides);
      if ($initial_probability) {
	$probability_adjustment_factor = $adjusted_probability / $initial_probability;
      }
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

        ### tmf debugging 12/08
        if ($diff_is_great)
           { print "Final adj prob = $probability: REJECTED!!!\n"; }

      } else {
   print "WARNING: No adjusted probability for $charge-$modified_peptide\n";
      }
    }
  }

  #### Sort identification list by probability.
  sub by_decreasing_probability { - ( $a->[8] <=> $b->[8] ); }
  my @sorted_id_list =
     (sort by_decreasing_probability @{$pep_identification_list});

  #### Truncate per-experiment by FDR threshold, if desired.
  if ($FDR_threshold) {
    my $counter = 0;
    my $prob_sum = 0.0;
    my $fdr;
    my $prob_cutoff;
    my $probability;
    my $last_probability = 1;;
    my $last_protid = "";
    foreach my $identification ( @sorted_id_list ) {
      $counter++;
      $probability = $identification->[8];
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
	  $#sorted_id_list = $counter-1;
	  last;
        }
      }
      $last_probability = $probability;
      $last_protid = $identification->[10];
    }
  }

  $pep_identification_list = \@sorted_id_list;

  #### Print.
  my $counter = 0;
  foreach my $identification ( @{$pep_identification_list} ) {
    my $probability = $identification->[8];
    ### warns that can't compare strings with >= but can't find
    ###  function to explicitly convert to float
    if (($P_threshold && $probability >= $P_threshold) ||
        $FDR_threshold) {
      print OUTFILE join("\t",@{$identification})."\n";
      $counter++;
      print "$counter... " if ($counter % 1000 == 0);
    }
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

  open (OUTFILE, ">$output_file");
  print "Opening output file $output_file.\n";

  # Write header line
    print OUTFILE
"protein_group_number,biosequence_names,probability,confidence,n_observations,n_distinct_peptides,level_name,represented_by_biosequence_name,subsumed_by_biosequence_names,estimated_ng_per_ml,abundance_uncertainty\n";

  # For each protein in the atlas

  my $abundance_conversion_slope = $OPTIONS{slope_for_abundance};
  my $abundance_conversion_yint = $OPTIONS{yint_for_abundance};
  my $calculate_abundances = 0;
  if ( defined $abundance_conversion_slope &&
       defined $abundance_conversion_yint ) {
    $calculate_abundances = 1;
  } else {
    print "Slope and/or y-intercept for protein abundance calculation not provided; protein abundances will not be calculated.\n";
  }
  my $group_num;
  for my $prot_name (keys %{$ProteinProphet_prot_data->{atlas_prot_list}}) {
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
    my $apportioned_PSM_count = $prot_href->{apportioned_PSM_count};
    my $formatted_apportioned_PSM_count =
         sprintf( "%0.1f", $apportioned_PSM_count);
    my $biosequence_attributes =
        getBiosequenceAttributes(biosequence_name => $prot_name);

    ### Abundance estimation
    
    my $formatted_estimated_abundance;
    my $abundance_uncertainty;
    if ( $calculate_abundances ) {
      my $estimated_abundance;
      if ( ! defined $biosequence_attributes ) {
	#print "No biosequence_attributes for $prot_name.\n";
	$formatted_estimated_abundance = "";
	$abundance_uncertainty = "";
      } else {
	### Small problem: molecular weights of indistinguishables are
	### sometimes quite different. Not correct to use MW of first prot
	### in list.
	my $sequence = $biosequence_attributes->[5];
	### Schulz/Schirmer in table 1-1 say 108.7 is the weighted mean aa wt.
	### A bit kludgey, but this whole abundance estimation is kludgey.
	my $protMW = length($sequence) * 108.7;
	### If we couldn't get the seq somehow, set protMW to an avg. value
	if ( $protMW == 0 ) {
	  $protMW = 30000;
	  print "WARNING: couldn't find seq for $prot_name; using MW=30,000\n";
	}
	### Hard-coded for plasma atlas.
	#my $abundance_conversion_slope = 1.0807;
	#my $abundance_conversion_yint = 1.813;
	### corrCounts = alog10( totalCounts*protMW/1000/1000 ) * 1.09 + 1.84
	### multiplying by protMW converts from moles (fmol/ml) to grams (fg/ml).
	### dividing by 1,000,000 converts from fg/ml to ng/ml.
	if ( $apportioned_PSM_count > 0  ) {
	  $estimated_abundance =
	     10 **
	       ((((log ($apportioned_PSM_count * $protMW)
			 / log (10)) - 6 ) *
		     $abundance_conversion_slope ) +
		   $abundance_conversion_yint);
          ## TEMPORARY hard-coded stuff for HUPO 2009  tmf
          if ($estimated_abundance > 2000000) {
	    $abundance_uncertainty = "4x";
          } elsif ($estimated_abundance > 100000) {
	    $abundance_uncertainty = "7x";
          } elsif ($estimated_abundance > 10000) {
	    $abundance_uncertainty = "25x";
          } elsif ($estimated_abundance > 1000) {
	    $abundance_uncertainty = "12x";
          } else {
	    $abundance_uncertainty = "15x";
          }
         
	} else {
	  $estimated_abundance = 0;
          $abundance_uncertainty = "";
	}
	$formatted_estimated_abundance = sprintf("%.1e", $estimated_abundance);
      }
    } else {
      $formatted_estimated_abundance = "";
      $abundance_uncertainty = "";
    }
    print OUTFILE ",$prot_href->{probability},".
	 "$prot_href->{confidence},".
         ### total_number_peptides is an integer and is calc.  differently
         #"$prot_href->{total_number_peptides},".
         "$formatted_apportioned_PSM_count,".
         "$n_distinct_peptides,".
         "$prot_href->{presence_level},".
         "$prot_href->{represented_by},".
         "$prot_href->{subsumed_by},".
         "$formatted_estimated_abundance,".
         "$abundance_uncertainty\n";
  }
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


  #### If we haven't loaded the peptide accessions hash yet, do it now
  unless (%peptide_accessions) {
    #my $sql = qq~
    #   SELECT peptide_sequence,peptide_accession
    #     FROM $TBAT_PEPTIDE P
    #~;
    my $sql = qq~
       SELECT peptide,peptide_identifier_str
         FROM $TBAPD_PEPTIDE_IDENTIFIER
    ~;
    print "Fetching all peptide accessions...\n";
    %peptide_accessions = $sbeams->selectTwoColumnHash($sql);
    print "  Loaded ".scalar(keys(%peptide_accessions))." peptides.\n";
    #### Just in case the table is empty, put in a bogus hash entry
    #### to prevent triggering a reload attempt
    $peptide_accessions{' '} = ' ';
  }


  #my $peptide_accession = $peptide_accessions{$sequence};
  #if ($peptide_accession !~ /PAp/) {
  #  die("ERROR: peptide_accession is $peptide_accession");
  #}

  return $peptide_accessions{$sequence} if ($peptide_accessions{$sequence});


  #### FIXME: The following is code stolen from
  #### $SBEAMS/lib/script/Proteomics/update_peptide_summary.pl
  #### This should be unified into one piece of code eventually

  my $peptide = $sequence;

  #### See if we already have an identifier for this peptide
  my $sql = qq~
    SELECT peptide_identifier_str
      FROM $TBAPD_PEPTIDE_IDENTIFIER
     WHERE peptide = '$peptide'
  ~;
  my @peptides = $sbeams->selectOneColumn($sql);

  #### If more than one comes back, this violates UNIQUEness!!
  if (scalar(@peptides) > 1) {
    die("ERROR: More than one peptide returned for $sql");
  }

  #### If we get exactly one back, then return it
  if (scalar(@peptides) == 1) {
    #### Put this new one in the hash for the next lookup
    $peptide_accessions{$sequence} = $peptides[0];
    return $peptides[0];
  }


  #### Else, we need to add it
  #### Create a hash for the peptide row
  my %rowdata;
  $rowdata{peptide} = $peptide;
  $rowdata{peptide_identifier_str} = 'tmp';

  #### Do the next two statements as a transaction
  $sbeams->initiate_transaction();

  #### Insert the data into the database
  my $peptide_identifier_id = $sbeams->insert_update_row(
    insert=>1,
    table_name=>$TBAPD_PEPTIDE_IDENTIFIER,
    rowdata_ref=>\%rowdata,
    PK=>"peptide_identifier_id",
    PK_value => 0,
    return_PK => 1,
    verbose=>$VERBOSE,
    testonly=>$TESTONLY,
  );

  unless ($peptide_identifier_id > 0) {
    die("Unable to insert modified_peptide for $peptide");
  }


  #### Now that the database furnished the PK value, create
  #### a string according to our rules and UPDATE the record
  my $template = "PAp00000000";
  my $identifier = substr($template,0,length($template) -
    length($peptide_identifier_id)).$peptide_identifier_id;
  $rowdata{peptide_identifier_str} = $identifier;


  #### UPDATE the record
  my $result = $sbeams->insert_update_row(
    update=>1,
    table_name=>$TBAPD_PEPTIDE_IDENTIFIER,
    rowdata_ref=>\%rowdata,
    PK=>"peptide_identifier_id",
    PK_value =>$peptide_identifier_id ,
    return_PK => 1,
    verbose=>$VERBOSE,
    testonly=>$TESTONLY,
  );

  #### Commit the INSERT+UPDATE pair
  $sbeams->commit_transaction();

  #### Put this new one in the hash for the next lookup
  $peptide_accessions{$sequence} = $identifier;

  return($identifier);

} # end getPeptideAccession


###############################################################################
# getBiosequenceAttributes
###############################################################################
sub getBiosequenceAttributes {
  my %args = @_;
  my $biosequence_name = $args{'biosequence_name'};


  #### If we haven't loaded the biosequence attributes hash yet, do it now
  #### 3/31: moved this to top of script. Delete when well tested.
#   unless (1 && %biosequence_attributes) {
#     my $sql = qq~
#        SELECT biosequence_id,biosequence_name,biosequence_gene_name,
#               biosequence_accession,biosequence_desc,biosequence_seq
#          FROM $TBAT_BIOSEQUENCE
#         WHERE biosequence_set_id = $bssid
#     ~;
#     print "Fetching all biosequence accessions...\n";
#     print "$sql";
#     my @rows = $sbeams->selectSeveralColumns($sql);
#     foreach my $row (@rows) {
#       $biosequence_attributes{$row->[1]} = $row;
#     }
#     print "  Loaded ".scalar(@rows)." biosequences.\n";
#     #### Just in case the table is empty, put in a bogus hash entry
#     #### to prevent triggering a reload attempt
#     $biosequence_attributes{' '} = ' ';
#   }
 

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
      $gene_name = $biosequence_attributes->[2];
      $description = $biosequence_attributes->[4];
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


    #### Now store information for this modification of the peptide
    my $modified_sequence = $row->[$columns->{modified_peptide_sequence}];
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
      if ($value  && $value ne "")
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

  return(1);

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
    following_residue charge probability massdiff protein_name );

  print OUTFILE join("\t",@column_names)."\n";

  print "  - writing ".scalar(@{$pep_identification_list})." peptides\n";

  my $counter = 0;
  foreach my $identification ( @{$pep_identification_list} ) {
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
  my $pep_identification_list = $args{'pep_identification_list'}
    || die("No output pep_identification_list provided");

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
    push(@{$pep_identification_list},\@columns);
    $counter++;
    print "$counter... " if ($counter % 1000 == 0);
  }

  print "\n";
  close(INFILE);

  print "  - read ".scalar(@{$pep_identification_list})." peptides from identification list template file\n";

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
# Here, we consider all peptides in protXML, even low prob ones.
# We "should" (?) consider only peps in the Atlas, right?
# Will that give us more canonicals, or fewer?
# For now, we'll stick with the method we've got.
sub is_independent {
  my $indep_fraction = $OPTIONS{min_indep} || 0.2;
  my $threshold = 1.0 - $indep_fraction;
  my $protein1 = shift(@_);
  my $protein2 = shift(@_);
  my $proteins_href = shift(@_);

  my $highly_overlapping = 1;
  my $hitcount = 0;
  my $pepcount = 0;

  # get the list of peptides for each protein from the protXML data
  my @peplist1 = @{$proteins_href->{$protein1}-> {unique_stripped_peptides}};
  my @peplist2 = @{$proteins_href->{$protein2}-> {unique_stripped_peptides}};

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
  if ($pepcount < 3) {return (0);}
  # if overlap below threshold, count how many prot2 peps are in prot1
  if ($hitcount / $pepcount < $threshold) {
    #print "$protein2 has few ($hitcount) of the same $pepcount peps as $protein1\n";
    $hitcount = 0;
    $pepcount = 0;
    foreach my $pep2 (@peplist2) {
      $pepcount++;
      for my $pep1 (@peplist1) {
	if ($pep2 eq $pep1) {
	  $hitcount++;
	  next;
	}
      }
    }
    if ($pepcount < 3) {return(0);}
    # if overlap below threshold, the two prots are independent.
    if ($hitcount / $pepcount < $threshold) {
      #print "$protein1 has few ($hitcount) of the same $pepcount peps as $protein2\n";
      $highly_overlapping = 0;
    }
  }
  return (! $highly_overlapping);
}
