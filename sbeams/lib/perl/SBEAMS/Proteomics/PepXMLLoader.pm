package SBEAMS::Proteomics::PepXMLLoader;

###############################################################################
# Program     : SBEAMS::Proteomics::PepXMLLoader
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id: XMLUtilities.pm 4246 2006-01-11 09:12:10Z edeutsch $
#
# Description : This is part of the SBEAMS::Proteomics module which
#               provides functions for loading spectrum searches from pepXML
#
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################


use strict;
use XML::Xerces;


###############################################################################
# Constructor
###############################################################################
sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;
    return($self);
}



#### main package continues below after PepXMLContentHandler package

###############################################################################
# PepXMLContentHandler Content Handler
# PepXMLContentHandler package: SAX parser callback routines
#
# This MyContentHandler package defines all the content handling callback
# subroutines used the SAX parser
###############################################################################
package PepXMLContentHandler;
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

  #### Make a hash to of the attributes
  my %attrs = $attrs->to_hash();

  #### Convert all the values from hashref to single value
  while (my ($aa1,$aa2) = each (%attrs)) {
    $attrs{$aa1} = $attrs{$aa1}->{value};
  }


  #### If we find the database name, store it
  if ($localname eq 'search_database') {
    my $local_path = $attrs{local_path}
      || die("ERROR: No local_path attribute for this search_database");

    if ($self->{search_database_path}) {
      if ($self->{search_database_path} ne $local_path) {
	die("ERROR: Conflict in database path! ".
	    "'$self->{search_database_path}' != '$local_path");
      }

    } else {
      $self->{search_database_path} = $local_path;
      print "  \ndatabase=$local_path\n";

      my $search_batch_id = &main::addSearchBatchEntry(
        experiment_id=>$self->{experiment_id},
        search_database=>$self->{search_database_path},
        search_directory=>$self->{search_directory},
        fraction_directory=>$self->{search_directory},
       );
      $self->{search_batch_id} = $search_batch_id;
    }

  }


  #### If this is the start of a search_result, remember the name
  if ($localname eq 'spectrum_query') {
    my $spectrum = $attrs{spectrum}
      || die("ERROR: No spectrum attribute for this spectrum_query");
    $self->{current_search_result}->{spectrum} = $attrs{spectrum};
    $self->{current_search_result}->{start_scan} = $attrs{start_scan};
    $self->{current_search_result}->{end_scan} = $attrs{end_scan};
    $self->{current_search_result}->{precursor_neutral_mass} = $attrs{precursor_neutral_mass};
    $self->{current_search_result}->{assumed_charge} = $attrs{assumed_charge};
  }


  #### If this is the start of a search_hit, store info
  if ($localname eq 'search_hit') {
    $self->{current_search_hit}->{hit_rank} = $attrs{hit_rank};
    $self->{current_search_hit}->{peptide} = $attrs{peptide};
    $self->{current_search_hit}->{peptide_prev_aa} = $attrs{peptide_prev_aa};
    $self->{current_search_hit}->{peptide_next_aa} = $attrs{peptide_next_aa};
    $self->{current_search_hit}->{protein} = $attrs{protein};
    $self->{current_search_hit}->{num_tot_proteins} = $attrs{num_tot_proteins};
    $self->{current_search_hit}->{num_matched_ions} = $attrs{num_matched_ions};
    $self->{current_search_hit}->{tot_num_ions} = $attrs{tot_num_ions};
    $self->{current_search_hit}->{calc_neutral_pep_mass} = $attrs{calc_neutral_pep_mass};
    $self->{current_search_hit}->{massdiff} = $attrs{massdiff};
  }


  #### If this is the start of a modification info, store it
  if ($localname eq 'mod_aminoacid_mass') {
    $self->{current_search_hit}->{modifications}->{$attrs{position}} = $attrs{mass};
    #print "**Found mod: pos=$attrs{position}  mass=$attrs{mass}\n";
  }


  #### If this is a engine-specific parameter, store it
  if ($localname eq 'search_score') {
    $self->{current_search_hit}->{$attrs{name}} = $attrs{value};
  }


  #### If this is the peptideprophet_result, store the probability
  if ($localname eq 'peptideprophet_result') {
    my $probability = $attrs{probability};
    unless (defined($probability)) {
      die("ERROR: No probability attribute for peptideprophet_result: ".
          join(",",%attrs));
    }
    #print "  \nprobability=$probability\n";

    $self->{current_search_hit}->{probability} = $attrs{probability};

    #### Increase the counters and print some progress info
    $self->{counter}++;
    print $self->{counter}."..." if ($self->{counter} % 100 == 0);
  }

}



###############################################################################
# end_element
###############################################################################
sub end_element {
  my ($self,$uri,$localname,$qname) = @_;


  #### If this is the end of a search_hit, store info
  if ($localname eq 'search_hit') {

    #### Determine the msrun
    my $msrun;
    if ($self->{current_search_result}->{spectrum} =~ /^(.+)\.\d+\.\d+\.\d$/) {
      $msrun = $1;
    } else {
      die("ERROR: Unable to parse msrun name from $self->{current_search_result}");
    }

    #### See if the msrun is there already
    unless ($self->{msruns}->{$msrun}) {
      my $result = &main::getMsrunId(
        experiment_id => $self->{experiment_id},
        fraction_tag => $msrun,
      );
      if ($result) {
        $self->{msruns}->{$msrun} = $result;
      }
    }


    #### If the msrun hasn't yet been registered, do so
    unless ($self->{msruns}->{$msrun}) {
      my $fraction_id = &main::addMsrunEntry(
        experiment_id => $self->{experiment_id},
        fraction_tag => $msrun,
      );
      $self->{msruns}->{$msrun} = $fraction_id;
    }
    my $fraction_id = $self->{msruns}->{$msrun};

    #### Add MS/MS spectrum entry if it doesn't yet exist
    my $file = $self->{search_directory}.'/'.
      $msrun.'/'.$self->{current_search_result}->{spectrum}.'.dta';
    my $msms_spectrum_id = &main::addMsmsSpectrumEntry(
      $file,$fraction_id);
    unless ($msms_spectrum_id) {
      die "ERROR: Did not receive msms_spectrum_id\n";
    }

    #### Create a data hash analogous to what readOutFile() returns
    my %data = $self->createDataHash();


    #### Insert the search
    my $search_id = &main::addSearchEntry($data{parameters},
      $self->{search_batch_id},$msms_spectrum_id);


    #### Insert the search_hit
    if ($search_id > 0) {
      my $search_hit_id = &main::addSearchHitEntry($data{matches},$search_id);
    } else {
      die("ERROR: search_id not returned");
    }

    $self->{current_search_hit} = undef;
  }


  #### If this is the end of a search_result, clear the cache
  if ($localname eq 'spectrum_query') {
    $self->{current_search_result} = undef;
  }


}


###############################################################################
# createDataHash
###############################################################################
sub createDataHash {
  my $self = shift;
  my %args = @_;

  my %data;

  $data{parameters}->{file_root} = $self->{current_search_result}->{spectrum};
  $data{parameters}->{search_batch_id} = $self->{search_batch_id};
  $data{parameters}->{msms_spectrum_id} = $self->{msms_spectrum_id};
  $data{parameters}->{start_scan} = $self->{current_search_result}->{start_scan};
  $data{parameters}->{end_scan} = $self->{current_search_result}->{end_scan};
  $data{parameters}->{sample_mass_plus_H} = $self->{current_search_result}->{precursor_neutral_mass};
  $data{parameters}->{assumed_charge} = $self->{current_search_result}->{assumed_charge};

  #### Fake data to preserve NON NULL
  $data{parameters}->{total_intensity} = 0;
  $data{parameters}->{matched_peptides} = 0;
  $data{parameters}->{lowest_prelim_score} = 0;
  $data{parameters}->{search_date} = '2000-01-01';
  $data{parameters}->{search_elapsed_min} = 0;
  $data{parameters}->{search_host} = 'none';


  #### Create the modified peptide string
  my $peptide_sequence = $self->{current_search_hit}->{peptide};
  my $modified_peptide = '';
  my $modifications = $self->{current_search_hit}->{modifications};
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


  my $hit_index = $self->{current_search_hit}->{hit_rank};
  $data{matches}->[0]->{hit_index} = $self->{current_search_hit}->{hit_rank};
  $data{matches}->[0]->{hit_mass_plus_H} = $self->{current_search_hit}->{calc_neutral_pep_mass};
  $data{matches}->[0]->{mass_delta} = $self->{current_search_hit}->{massdiff};
  $data{matches}->[0]->{mass_delta} =~ s/\+\-//;
  $data{matches}->[0]->{identified_ions} = $self->{current_search_hit}->{num_matched_ions};
  $data{matches}->[0]->{total_ions} = $self->{current_search_hit}->{tot_num_ions};
  $data{matches}->[0]->{reference} = $self->{current_search_hit}->{protein};
  $data{matches}->[0]->{additional_proteins} = $self->{current_search_hit}->{num_tot_proteins};
  $data{matches}->[0]->{peptide} = $self->{current_search_hit}->{peptide};
  $data{matches}->[0]->{peptide_string} =
    $self->{current_search_hit}->{peptide_prev_aa}.'.'.
    $modified_peptide.'.'.
    $self->{current_search_hit}->{peptide_next_aa};

  #### SEQUEST Scores
  if ($self->{current_search_hit}->{xcorr}) {
    $data{matches}->[0]->{cross_corr_rank} = $self->{current_search_hit}->{hit_rank};
    $data{matches}->[0]->{prelim_score_rank} = $self->{current_search_hit}->{sprank};
    $data{matches}->[0]->{cross_corr} = $self->{current_search_hit}->{xcorr};
    $data{matches}->[0]->{norm_corr_delta} = $self->{current_search_hit}->{deltacn};
    $data{matches}->[0]->{prelim_score} = $self->{current_search_hit}->{spscore};

  #### MASCOT Scores - fudged
  } elsif ($self->{current_search_hit}->{ionscore}) {
    $data{matches}->[0]->{cross_corr_rank} = $self->{current_search_hit}->{hit_rank};
    $data{matches}->[0]->{prelim_score_rank} = 0;
    $data{matches}->[0]->{cross_corr} = $self->{current_search_hit}->{ionscore};
    $data{matches}->[0]->{norm_corr_delta} = 0;
    $data{matches}->[0]->{prelim_score} = $self->{current_search_hit}->{identityscore};

  #### Tandem-K Scores - fudged
  } elsif ($self->{current_search_hit}->{expect}) {
    $data{matches}->[0]->{cross_corr_rank} = 0;
    $data{matches}->[0]->{prelim_score_rank} = 0;
    $data{matches}->[0]->{cross_corr} = $self->{current_search_hit}->{expect};
    $data{matches}->[0]->{norm_corr_delta} = 0;
    $data{matches}->[0]->{prelim_score} = $self->{current_search_hit}->{hyperscore};
  }

  return %data;
}


###############################################################################
# continuation of main package
package SBEAMS::Proteomics::PepXMLLoader;

###############################################################################
# loadExperimentFromPepXMLFile
###############################################################################
sub loadExperimentFromPepXMLFile {
  my $self = shift;
  my %args = @_;


  #### Decode the argument list
  my $source_file = $args{'source_file'} || '';
  my $VERBOSE = $args{'verbose'} || '';
  my $experiment_id = $args{'experiment_id'} ||
    die("ERROR: experiment_id not passed");
  my $search_directory = $args{'search_directory'} ||
    die("ERROR: search_directory not passed");

  my $validate = $args{validate} || 'never';
  my $namespace = $args{namespaces} || 0;
  my $schema = $args{schema} || 0;


  #### Check to make sure the file exists
  unless (-f $source_file) {
    die "File '$source_file' does not exist!\n";
  }


  if (uc($validate) eq 'ALWAYS') {
    $validate = $XML::Xerces::SAX2XMLReader::Val_Always;
  } elsif (uc($validate) eq 'NEVER') {
    $validate = $XML::Xerces::SAX2XMLReader::Val_Never;
  } elsif (uc($validate) eq 'AUTO') {
    $validate = $XML::Xerces::SAX2XMLReader::Val_Auto;
  } else {
    die("Unknown value for validate: $validate\n");
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

  my $CONTENT_HANDLER = PepXMLContentHandler->new();
  $parser->setContentHandler($CONTENT_HANDLER);

  $CONTENT_HANDLER->setVerbosity($VERBOSE);
  $CONTENT_HANDLER->{counter} = 0;
  $CONTENT_HANDLER->{experiment_id} = $experiment_id;
  $CONTENT_HANDLER->{search_directory} = $search_directory;


  #### Process the whole document
  print "INFO: Loading...\n" if ($VERBOSE);
  $parser->parse (XML::Xerces::LocalFileInputSource->new($source_file));


  #### Write out information about the objects we've loaded if verbose
  if ($VERBOSE) {
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

      if ($key eq "files") {
        while (($key2,$value2) = each %{$CONTENT_HANDLER->{$key}}) {
          print "  $key2 = $value2\n";
        }
      }

    } # end while

  } # end if

  print "\n\n" if ($VERBOSE);

  return($CONTENT_HANDLER);

} # end loadMSRunFromPepXMLFile



###############################################################################

1;

__END__
###############################################################################
###############################################################################
###############################################################################

=head1 NAME

SBEAMS::Proteomics::PepXMLLoader - Loads experimental data from
  a pepXML file instead of from .out files

=head1 SYNOPSIS

  Used as part of this system

    use SBEAMS::Connection;
    use SBEAMS::Proteomics::PepXMLLoader;


=head1 DESCRIPTION

    This module is inherited by the SBEAMS::Proteomics module,
    although it can be used on its own.  Its main function
    is to encapsulate XML-specific functionality.

=head1 METHODS

=item B<loadMSRunFromPepXMLFile()>

    Load experimental data from pepXML for each msrun (not the interact
    file).

=head1 AUTHOR

Eric Deutsch <edeutsch@systemsbiology.org>

=head1 SEE ALSO

perl(1).

=cut
