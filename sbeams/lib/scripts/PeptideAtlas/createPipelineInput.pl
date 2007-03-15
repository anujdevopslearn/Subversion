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
use SBEAMS::Connection::TableInfo;

use SBEAMS::Proteomics::Tables;
use SBEAMS::PeptideAtlas::Tables;

$sbeams = new SBEAMS::Connection;


###############################################################################
# Read and validate command line args
###############################################################################
my $VERSION = q[$Id$ ];
$PROG_NAME = $FindBin::Script;

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
  --search_batch_ids  Comma-separated list of SBEAMS-Proteomics seach_batch_ids
  --P_threshold       Probability threshold to accept (e.g. 0.9)
  --output_file       Filename to which to write the peptides

 e.g.:  $PROG_NAME --verbose 2 --source YeastInputExperiments.tsv

EOU


#### If no parameters are given, print usage information
unless ($ARGV[0]){
  print "$USAGE";
  exit;
}


#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
  "validate=s","namespaces","schemas",
  "source_file:s","search_batch_ids:s","P_threshold:f","output_file:s",
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


#### Get the search_batch_id parameter
my $source_file = $OPTIONS{source_file} || '';
my $APDTsvFileName = $OPTIONS{output_file} || '';
my $search_batch_ids = $OPTIONS{search_batch_ids} || '';


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


#### Process parser options
my $validate = $OPTIONS{validate} || 'auto';
my $namespace = $OPTIONS{namespaces} || 0;
my $schema = $OPTIONS{schemas} || 0;


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
#    $self->{pepcache}->{spectrum_and_mass_uniq} = $attrs{spectrum}.
#      '-'.$attrs{precursor_neutral_mass}.'-'.$attrs{index};
    $self->{pepcache}->{spectrum_and_mass_uniq} = $attrs{spectrum}.
      '-'.$attrs{precursor_neutral_mass};
    #### Fudged for SpectraST problem
    #$self->{pepcache}->{spectrum_and_mass_uniq} = $attrs{spectrum};
    #print "$attrs{index}..";
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
    $self->{pepcache}->{protein_name} = $attrs{protein};
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


  #### If this is the probability score, store some attributes
  if ($localname eq 'peptideprophet_result') {
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

  #### If this is a protein, then store its name
  if ($localname eq 'protein') {
    $self->{protein_name} = $attrs{protein_name};
  }


  #### If this is the mass mod info, then store some attributes
  if ($localname eq 'mod_aminoacid_mass') {
    $self->{pepcache}->{modifications}->{$attrs{position}} = $attrs{mass};
  }


  #### If this is a pepetide, then store some attributes
  if ($localname eq 'peptide') {
    my $peptide_sequence = $attrs{peptide_sequence} || die("No sequence");
    $self->{pepcache}->{peptide} = $attrs{peptide_sequence};
    $self->{pepcache}->{charge} = $attrs{charge};
    $self->{pepcache}->{initial_probability} = $attrs{initial_probability};
    $self->{pepcache}->{nsp_adjusted_probability} = $attrs{nsp_adjusted_probability};
    $self->{pepcache}->{n_sibling_peptides} = $attrs{n_sibling_peptides};
    $self->{pepcache}->{n_instances} = $attrs{n_instances};
  }


  #### Push information about this element onto the stack
  my $tmp;
  $tmp->{name} = $localname;
  push(@{$self->object_stack},$tmp);


  #### Increase the counters and print some progress info
  $self->{counter}++;
  print $self->{counter}."..." if ($self->{counter} % 100 == 0);

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
      #die("ERROR: No peptide sequence in the cache!");
      print "WARNING: No search result for this query!\n";
      $probability = -1;
    }

    #### If this peptide passes the threshold, store it
    if ($probability >= $self->{P_threshold}) {

      #### Create the modified peptide string
      my $modified_peptide = '';
      my $modifications = $self->{pepcache}->{modifications};
      if ($modifications) {
	for (my $i=1; $i<=length($peptide_sequence); $i++) {
	  my $aa = substr($peptide_sequence,$i-1,1);
	  if ($modifications->{$i}) {
	    $aa .= '['.int($modifications->{$i}).']';
	  }
	  $modified_peptide .= $aa;
	}
      } else {
	$modified_peptide = $peptide_sequence;
      }

      my $charge = $self->{pepcache}->{charge};

      #### Extract the spectrum uniqifier and make sure we haven't
      #### already seen it
      my $spectrum = $self->{pepcache}->{spectrum_and_mass_uniq};
      #$spectrum =~ s/\.\d$//;
      #print "INFO: Processing spectrum $spectrum\n";
      my $other_search_info;
      if (exists($self->{all_spectra}->{$spectrum})) {
	if ($self->{all_spectra}->{$spectrum} =~ /HASH/) {
	  $other_search_info = $self->{all_spectra}->{$spectrum};
          #print "      - other_search_info = $other_search_info\n";
	} else {
	  print "WARNING: A spectrum with tag '$spectrum' has already been. ".
	    "loaded. Maybe this just a naming problem, or maybe two ".
            "different ".
	    "search_batches on the same spectra.  I'm not smart enough ".
	    "to deal with the gracefully yet. More code required.";
	}

      }


      #### Store the information for this query_spectrum in case we
      #### need it again when there's a re-search of this spectrum
      my $query_spectrum_result = 1;
      if (1) {
	$query_spectrum_result = $self->{pepcache};
      }
      $self->{all_spectra}->{$spectrum} = $query_spectrum_result;


      #### If we've already seen this peptide
      if ($self->{peptides}->{$peptide_sequence}) {
	my $info = $self->{peptides}->{$peptide_sequence};
	$info->{best_probability} = $probability
	  if ($info->{best_probability} < $probability);
	$info->{n_instances}++ unless ($other_search_info);
	$info->{search_batch_ids}->{$self->{search_batch_id}}++;

      #### Else this is a new peptide
      } else {
	my $info;
	$info->{best_probability} = $probability;
	$info->{n_instances} = 1;
	$info->{search_batch_ids}->{$self->{search_batch_id}} = 1;
	$info->{protein_name} = $self->{pepcache}->{protein_name};
	$info->{peptide_prev_aa} = $self->{pepcache}->{peptide_prev_aa};
	$info->{peptide_next_aa} = $self->{pepcache}->{peptide_next_aa};

	my $peptide_accession = &main::getPeptideAccession(
          sequence => $peptide_sequence,
        );
	$info->{peptide_accession} = $peptide_accession;

	$self->{peptides}->{$peptide_sequence} = $info;
      }


      #### Store the modification information
      my $info = $self->{peptides}->{$peptide_sequence};
      my $modinfo = $info->{modifications}->{$modified_peptide}->{$charge};
      #print "      - Modified sequence and charge: $modified_peptide/$charge\n";

      if (defined($modinfo) && defined($modinfo->{best_probability})) {
	if ($modinfo->{best_probability} < $probability) {
	  $modinfo->{best_probability} = $probability;
	}
      } else {
	$modinfo->{best_probability} = $probability;
      }

      #### Unless we already had search info on this spectrum, incr counters
      #$other_search_info = $modinfo->{search_batch_ids}->{$self->{search_batch_id}};

      #### This is no good. It triggers on any previous same peptide!
      #my $has_previous_entry = $modinfo->{n_instances};

      my $has_previous_entry = undef;

      #print "      - has_previous_entry = $has_previous_entry\n";
      unless ($other_search_info || $has_previous_entry) {
	$modinfo->{n_instances}++;
	$modinfo->{search_batch_ids}->{$self->{search_batch_id}}++;
      }

      $info->{modifications}->{$modified_peptide}->{$charge} = $modinfo;


      #### Store the peptide in a master full list to calculate stats
      #unless ($other_search_info || $has_previous_entry) {
      #if (0 == 1) {
      unless ($has_previous_entry) {
        #print "Added $modified_peptide/$charge\n";
	push(@{ $self->{peptide_list} },
          [$self->{search_batch_id},
	   $peptide_sequence,
	   $modified_peptide,
	   $charge,
           $probability,
           $self->{pepcache}->{protein_name},
	   $self->{pepcache}->{spectrum},
           $self->{pepcache}->{scores},
	  ]);
      }
    }

    #### Clear out the cache
    delete($self->{pepcache});

    #### Increase the counters and print some progress info
    $self->{counter}++;
    #print $self->{counter}."..." if ($self->{counter} % 100 == 0);
    print "." if ($self->{counter} % 1000 == 0);

  }


  #### If there's an object on the stack consider popping it off
  if (scalar @{$self->object_stack()}){

    #### If the top object on the stack is the correct one, pop it off
    #### else die bitterly    my $peptide_sequence = $attrs{peptide_sequence} || die("No sequence");

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

  #### If this is a pepetide, then update the number of peptides
  if ($localname eq 'peptide') {
    my $peptide_sequence = $self->{pepcache}->{peptide}
      || die("ERROR: No peptide sequence in the cache!");

    my $initial_probability = $self->{pepcache}->{initial_probability};

    #### If this peptide passes the threshold, store it
    if ($initial_probability >= $self->{P_threshold}) {

      #### Create the modified peptide string
      my $modified_peptide = '';
      my $modifications = $self->{pepcache}->{modifications};
      if ($modifications) {
	for (my $i=1; $i<=length($peptide_sequence); $i++) {
	  my $aa = substr($peptide_sequence,$i-1,1);
	  if ($modifications->{$i}) {
	    $aa .= '['.int($modifications->{$i}).']';
	  }
	  $modified_peptide .= $aa;
	}
      } else {
	$modified_peptide = $peptide_sequence;
      }

      my $charge = $self->{pepcache}->{charge};


      #### If we've already seen this peptide
      if ($self->{ProPro_peptides}->{$peptide_sequence}) {
	my $info = $self->{ProPro_peptides}->{$peptide_sequence};
	$info->{best_intitial_probability} = $initial_probability
	  if ($info->{best_initial_probability} < $initial_probability);

	#### Assume that if we've already seen this search_batch_id for this
	#### peptide, then this is probably additional search_engine data
	#### and we shouldn't just add in the results blindly.
	#### This is isn't really correct, but I don't know what else to do
	if (exists($info->{search_batch_ids}->{$self->{search_batch_id}})) {
	  if ($info->{n_instances} < $self->{pepcache}->{n_instances}) {
	    $info->{n_instances} = $self->{pepcache}->{n_instances};
	  } else {
	    $info->{n_instances} += int($self->{pepcache}->{n_instances}/2);
	  }

	  if ($info->{n_sibling_peptides} < $self->{pepcache}->{n_sibling_peptides}) {
	    $info->{n_sibling_peptides} = $self->{pepcache}->{n_sibling_peptides};
	  } else {
	    $info->{n_sibling_peptides} += int($self->{pepcache}->{n_sibling_peptides}/2);
	  }
	  $info->{search_batch_ids}->{$self->{search_batch_id}}++;

	#### Otherwise add in the result
	} else {
	  $info->{n_instances} += $self->{pepcache}->{n_instances};
	  $info->{n_sibling_peptides} += $self->{pepcache}->{n_sibling_peptides};
	  $info->{search_batch_ids}->{$self->{search_batch_id}}++;
	}

      #### Else this is a new peptide
      } else {
	my $info;
	$info->{best_initial_probability} = $initial_probability;
	$info->{best_adjusted_probability} = $self->{pepcache}->{nsp_adjusted_probability};
	$info->{n_instances} = $self->{pepcache}->{n_instances};
	$info->{n_sibling_peptides} = $self->{pepcache}->{n_sibling_peptides};
	$info->{search_batch_ids}->{$self->{search_batch_id}} = 1;
	$info->{protein_name} = $self->{pepcache}->{protein_name};

	$self->{ProPro_peptides}->{$peptide_sequence} = $info;
      }

      #### Store the modification information
      my $info = $self->{ProPro_peptides}->{$peptide_sequence};
      my $modinfo = $info->{modifications}->{$modified_peptide}->{$charge};

      if (defined($modinfo) && defined($modinfo->{best_initial_probability})) {
	if ($modinfo->{best_initial_probability} < $initial_probability) {
	  $modinfo->{best_initial_probability} = $initial_probability;
	}
      } else {
	$modinfo->{best_initial_probability} = $initial_probability;
      }

      if (defined($modinfo) && defined($modinfo->{best_adjusted_probability})) {
	if ($modinfo->{best_adjusted_probability} < $self->{pepcache}->{nsp_adjusted_probability}) {
	  $modinfo->{best_adjusted_probability} = $self->{pepcache}->{nsp_adjusted_probability};
	}
      } else {
	$modinfo->{best_adjusted_probability} = $self->{pepcache}->{nsp_adjusted_probability};
      }



      #### Assume that if we've already seen this search_batch_id for this
      #### peptide, then this is probably additional search_engine data
      #### and we shouldn't just add in the results blindly.
      #### This is isn't really correct, but I don't know what else to do
      if (exists($modinfo->{search_batch_ids}->{$self->{search_batch_id}})) {
	  if ($modinfo->{n_instances} < $self->{pepcache}->{n_instances}) {
	    $modinfo->{n_instances} = $self->{pepcache}->{n_instances};
	  } else {
	    $modinfo->{n_instances} += int($self->{pepcache}->{n_instances}/2);
	  }

	  if ($modinfo->{n_sibling_peptides} < $self->{pepcache}->{n_sibling_peptides}) {
	    $modinfo->{n_sibling_peptides} = $self->{pepcache}->{n_sibling_peptides};
	  } else {
	    $modinfo->{n_sibling_peptides} += int($self->{pepcache}->{n_sibling_peptides}/2);
	  }
	  $modinfo->{search_batch_ids}->{$self->{search_batch_id}}++;

	#### Otherwise add in the result
	} else {
	  $modinfo->{n_instances} += $self->{pepcache}->{n_instances};
	  $modinfo->{search_batch_ids}->{$self->{search_batch_id}}++;
	  $modinfo->{n_sibling_peptides} += $self->{pepcache}->{n_sibling_peptides};
	}

      $info->{modifications}->{$modified_peptide}->{$charge} = $modinfo;

    }

    #### Clear out the cache
    delete($self->{pepcache});

    #### Increase the counters and print some progress info
    $self->{counter}++;
    #print $self->{counter}."..." if ($self->{counter} % 100 == 0);
    print "." if ($self->{counter} % 1000 == 0);

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
  my $P_threshold = $OPTIONS{P_threshold};
  $P_threshold = '0.9' unless (defined($P_threshold));

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
  if ($source_file) {
    my @search_batch_ids;
    open(SOURCE_FILE,$source_file)
      || die("ERROR: Unable to open $source_file");
    while (my $line = <SOURCE_FILE>) {
      chomp($line);
      next if ($line =~ /^\s*#/);
      next if ($line =~ /^\s*$/);
      my ($search_batch_id,$path) = split(/\t/,$line);
      my $filepath = $path;
      if ($filepath !~ /\.xml/) {
	$filepath = $path."/interact-prob.xml";
	if (! -e $filepath) {
	  $filepath = $path."/interact.xml";
	  if (! -e $filepath) {
	    $filepath = $path."/interact-specall.xml";
	    if (! -e $filepath) {
	      print "ERROR: Unable to find interact file in $path\n";
	      next;
	    }
	  }
	}
      }
      my ($pepXML_document,$protXML_document);

      $pepXML_document->{filepath} = $filepath;
      $pepXML_document->{search_batch_id} = $search_batch_id;
      $pepXML_document->{document_type} = 'pepXML';
      push(@documents,$pepXML_document);
      print "Will read $pepXML_document->{filepath}\n";

      $protXML_document->{filepath} = $filepath;
      $protXML_document->{filepath} =~ s/\.xml/-prot.xml/;
      $protXML_document->{search_batch_id} = $search_batch_id;
      $protXML_document->{document_type} = 'protXML';

      unless (-e $protXML_document->{filepath}) {
	#### Hard coded funny business for Novartis
	if ($filepath =~ /Novartis/) {
	  if ($filepath =~ /interact-prob_2/) {
	    $protXML_document->{filepath} =~ s/prob_2/prob_all/;
	  } else {
	    $protXML_document = undef;
	  }
	} else {
	  print "ERROR: No ProteinProphet file found for\n  $filepath\n";
	  $protXML_document = undef;
	}
      }

      if (defined($protXML_document)) {
	push(@documents,$protXML_document);
        print "Will read $protXML_document->{filepath}\n";
      }

      push(@search_batch_ids,$search_batch_id);
    }
    $search_batch_ids = join(',',@search_batch_ids);
  }

  #### Loops over all input files
  foreach my $document ( @documents ) {
    my $filepath = $document->{filepath};
    $CONTENT_HANDLER->{search_batch_id} = $document->{search_batch_id};
    $CONTENT_HANDLER->{document_type} = $document->{document_type};

    #### Process the whole document
    print "INFO: Loading $filepath...\n" unless ($QUIET);
    $parser->parse (XML::Xerces::LocalFileInputSource->new($filepath));

    print "\n";
  }

  #### Write out all the read-in data in a TSV format as written by
  #### a BrowseAPD query
  my $output_file = $OPTIONS{output_file} || 'PeptideAtlasInput.tsv';
  writeAPDFormatFile(
    output_file => $output_file,
    peptide_hash => $CONTENT_HANDLER->{peptides},
  );

  #### Write out all the read-in data in a PeptideAtlas XML format
  my $file_root = $output_file;
  $file_root =~ s/\.tsv$//i;
  $output_file = $file_root.'.PAxml';
  writePAxmlFile(
    output_file => $output_file,
    peptide_hash => $CONTENT_HANDLER->{peptides},
    ProPro_peptide_hash => $CONTENT_HANDLER->{ProPro_peptides},
    P_threshold => $CONTENT_HANDLER->{P_threshold},
  );

  #### Write out all the peptides and probabilities for statistical analysis
  $output_file = $file_root.'.peplist';
  writePeptideListFile(
    output_file => $output_file,
    peptide_list => $CONTENT_HANDLER->{peptide_list},
  );

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
  unless (%biosequence_attributes) {
    my $sql = qq~
       SELECT biosequence_id,biosequence_name,biosequence_gene_name,
              biosequence_accession,biosequence_desc
         FROM $TBAT_BIOSEQUENCE
        WHERE biosequence_set_id = 10
    ~;
    print "Fetching all biosequence accessions...\n";
    my @rows = $sbeams->selectSeveralColumns($sql);
    foreach my $row (@rows) {
      $biosequence_attributes{$row->[1]} = $row;
    }
    print "  Loaded ".scalar(@rows)." biosequences.\n";
    #### Just in case the table is empty, put in a bogus hash entry
    #### to prevent triggering a reload attempt
    $biosequence_attributes{' '} = ' ';
  }


  return $biosequence_attributes{$biosequence_name};

} # end getBiosequenceAttributes



###############################################################################
# writeAPDFormatFile
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
      if (ref($CONTENT_HANDLER->{$key})) {
        foreach $key2 (@{$CONTENT_HANDLER->{$key}}) {
          print "  $key2\n";
        }
      }
    }

  } # end while


  #print Dumper($CONTENT_HANDLER->{peptides});


} # end showContentHandlerContents



###############################################################################
# writePAxmlFile
###############################################################################
sub writePAxmlFile {
  my %args = @_;
  my $output_file = $args{'output_file'} || die("No output file provided");
  my $peptides = $args{'peptide_hash'}
    || die("No output peptide_hash provided");
  my $ProPro_peptides = $args{'ProPro_peptide_hash'}
    || die("No output ProPro_peptide_hash provided");
  my $P_threshold = $args{'P_threshold'}
    || die("No output P_threshold provided");


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
# writePeptideListFile
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
