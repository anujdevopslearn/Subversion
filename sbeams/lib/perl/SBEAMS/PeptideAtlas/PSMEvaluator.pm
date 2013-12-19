package SBEAMS::PeptideAtlas::PSMEvaluator;

###############################################################################
# Class       : SBEAMS::PeptideAtlas::PSMEvaluator
# Author      : Terry Farrah <terry.farrah@systemsbiology.org>
#
=head1 SBEAMS::PeptideAtlas::PSMEvaluator

=head2 SYNOPSIS

  SBEAMS::PeptideAtlas::PSMEvaluator

=head2 DESCRIPTION

This is part of the SBEAMS::PeptideAtlas module which implements
the heuristic PSM evaluator.

=cut
#
###############################################################################

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
require Exporter;
@ISA = qw();
$VERSION = q[$Id$];
@EXPORT_OK = qw();

use SBEAMS::Connection;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::Settings;
use SBEAMS::PeptideAtlas::Tables;


###############################################################################
# Global variables
###############################################################################
use vars qw($VERBOSE $TESTONLY $sbeams);


###############################################################################
# Constructor
###############################################################################
sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;
    $VERBOSE = 0;
    $TESTONLY = 0;
    return($self);
} # end new


###############################################################################
# setSBEAMS: Receive the main SBEAMS object
###############################################################################
sub setSBEAMS {
    my $self = shift;
    $sbeams = shift;
    return($sbeams);
} # end setSBEAMS



###############################################################################
# getSBEAMS: Provide the main SBEAMS object
###############################################################################
sub getSBEAMS {
    my $self = shift;
    return $sbeams || SBEAMS::Connection->new();
} # end getSBEAMS



###############################################################################
# setTESTONLY: Set the current test mode
###############################################################################
sub setTESTONLY {
    my $self = shift;
    $TESTONLY = shift;
    return($TESTONLY);
} # end setTESTONLY



###############################################################################
# setVERBOSE: Set the verbosity level
###############################################################################
sub setVERBOSE {
    my $self = shift;
    $VERBOSE = shift;
    return($TESTONLY);
} # end setVERBOSE



###############################################################################
# get_annotated_peaks_from_speclib --
###############################################################################
sub get_annotated_peaks_from_speclib {
  my $METHOD = 'get_annotated_peaks_from_speclib';
  my $self = shift || die ("self not passed");
  my %args = @_;
  my @annotated_peaks;

  my $data_location = $args{'data_location'} ||
    die "Need data_location.";
  my $spectrum_name = $args{'spectrum_name'} ||
    die "Need spectrum_name.";

  # Remove trailing charge
  $spectrum_name =~ s/\.\d{1,2}$//;

  my $speclib = "${data_location}/RAW.sptxt";
  my $specidx = "${data_location}/RAW.specidx";

  # Use index file to get positon of desired spectrum. Seek to that position.
  if (! -e $specidx) {
    print "$specidx not found.<br>\n";
    return ();
  }
  my $index = `grep -m1 $spectrum_name $specidx`;
  if (!$index) {
    print "Specname $spectrum_name not found in $specidx.<br>\n";
    return ();
  }
  chomp $index;
  $index =~ /\s(.*)$/;
  my $pos = $1;
  open (my $infh, $speclib) || print "Can't open $speclib.<br>\n";
  seek $infh, $pos, 0;

  my $npeaks;
  # Skip to Comment line and check for match to spectrum name.
  while (my $line = <$infh>) {
    chomp $line;
    if ($line =~ /^Comment:.*RawSpectrum=(.*?) /) {
      if ($1 eq $spectrum_name) {
	$line = <$infh>;
	chomp $line;
	$line =~ /^NumPeaks: (\d+)/;
	$npeaks = $1;
	# Get mz, intens, and annotation_list for each peak
	for (my $i=0; $i<$npeaks; $i++) {
	  $line = <$infh>;
	  chomp $line;
	  $line =~ /^(\d+\.\d+)\s+(\d+\.\d+)\s+(\S+)/;
	  my $mz = $1;
	  my $intensity = $2;
	  my $annotations = $3;
	  $annotated_peaks[$i]->{mz} = $mz;
	  $annotated_peaks[$i]->{intensity} = $intensity;
	  $annotated_peaks[$i]->{annotation_string} = $annotations;
	  # parse the annotations
	  my @annotations = split (",", $annotations);
	  for my $ann (@annotations) {
	    my ($ion, $diff) = split ("/", $ann);
	    $annotated_peaks[$i]->{'annotations'}->{$ion} = $diff;
	  }
	}
	last;
      }
    }
  }
  if (!$npeaks) {
    print "Could not find $spectrum_name in $speclib at byte $pos.<br>\n";
  }
  

  return @annotated_peaks;
}





###############################################################################
# evaluate_PSM_heuristically --
###############################################################################
sub evaluate_PSM_heuristically {
  my $METHOD = 'evaluate_PSM_heuristically';
  my $self = shift || die ("self not passed");
  my %args = @_;

  my $annotated_peaks_aref = $args{annotated_peaks_aref};
  my $sorted_product_ions_aref = $args{sorted_product_ions_aref};
  my $modified_sequence = $args{modified_sequence};
  my $charge = $args{charge};
  my $DEBUG = 0;

  # Find precursor peak according to spectrast
  my $precursor_mz;
  my $precursor_annotation_regex = sprintf "^p\\\^%d\\\/", $charge;
  #print "Regex = |$precursor_annotation_regex|<br>\n";
  for my $peak (@{$annotated_peaks_aref}) {
    if ($peak->{'annotation_string'} =~ /${precursor_annotation_regex}/) {
      $precursor_mz = $peak->{'mz'};
    }
  }
  # Get maximum intensity and normalize all intensities so max=1
  my $max_intens = 0;
  my $max_mz;
  my $max_label;
  my $npeaks = scalar @{$annotated_peaks_aref};
  my $precursor_mz_buffer = 5/$charge;
  if ($precursor_mz) {
    print "Precursor mz = $precursor_mz Precursor mz buffer = $precursor_mz_buffer<br>\n" if $DEBUG;
  } else {
    print "Precursor peak not found in spectrast file.<br>\n" if $DEBUG;
  }
  for my $peak (@{$annotated_peaks_aref}) {
    if ($peak->{'intensity'} > $max_intens) {
      # skip precursor and unannotated peaks
      # also skip any peaks really close to the precursor
      if ($peak->{'annotation_string'} !~ /^\[?[p\?]/) {
	if (($peak->{'mz'} < $precursor_mz - $precursor_mz_buffer) ||
	    ($peak->{'mz'} > $precursor_mz + $precursor_mz_buffer)) {
	  $max_intens = $peak->{'intensity'};
	  $max_mz = $peak->{'mz'};
	  $max_label = $peak->{'annotation_string'};
	}
      }
    }
  }
  print "Max intensity = $max_intens at $max_mz for ion $max_label<br>\n" if $DEBUG;
  for my $peak (@{$annotated_peaks_aref}) {
    $peak->{'norm_intens'} = $peak->{'intensity'}/$max_intens;
  }

  # Are there any prolines in this peptide?
  my $n_prolines = ($modified_sequence =~ tr/P//);

  my $proline_peak_score;
  my $total_proline_peak_intensity;
  my $n_proline_peaks_over_0_10;
  my $n_proline_peaks_over_0_50;
  my $n_possible_proline_peaks;
  #my $n_expected_proline_peaks;
  my @expected_proline_ions = ();
#--------------------------------------------------
#   my $lower_mz = 250;
#   my $upper_mz = 1800;
#-------------------------------------------------- 
  my ($good1, $good2, $bad1, $bad2, $eval1, $eval2);
  # Allow just one very strong proline peak for a single proline.
  # For two, require some other, possibly weak, peak(s).
  # For >two, require a bit more.
  my @proline_score_thresholds = (2.9, 3.3, 4.5);
  my $score_threshold;
  if ($n_prolines) {
    # Check for cleavage N-terminal to prolines
    # Which expected fragments are for XP (and not PP)
    # (and have an mz between 250 and 1800?)
    for my $ion_href (@{$sorted_product_ions_aref}) {
      my $dipeptide = $ion_href->{'bond'};
      if (($dipeptide =~ /P$/i) &&
          ($dipeptide !~ /^PP$/i)) {
	#--------------------------------------------------
	#   if (($ion_href->{'mz'} >= $lower_mz) &&
	#       ($ion_href->{'mz'} <= $upper_mz)) {
	#-------------------------------------------------- 
	  push (@expected_proline_ions, $ion_href);
	  #print "Dipeptide $dipeptide has expected fragment $ion_href->{'label_st'}!<br>\n" if $DEBUG;
	#--------------------------------------------------
	# } else {
	#   print "Dipeptide $dipeptide ion $ion_href->{'label_st'} $ion_href->{'mz'} is outside the sweet mz range of $lower_mz to $upper_mz.<br>\n" if $DEBUG;
	# }
	#-------------------------------------------------- 
      } else {
	#print "$dipeptide is not XP.<br>\n" if $DEBUG;
      }
    }
    $n_possible_proline_peaks = scalar @expected_proline_ions;
    if ($n_possible_proline_peaks) {
      print "=>Looking for these $n_possible_proline_peaks proline peaks: \n" if $DEBUG;
      for my $ion_href (@expected_proline_ions) {
	print "$ion_href->{'label_st'}&nbsp;&nbsp;&nbsp;&nbsp;" if
	$DEBUG;
      }
      print "<br><br>\n" if $DEBUG;
      # Check the intensities of all of these and calculate some metrics.
      $n_proline_peaks_over_0_10 = 0;
      $n_proline_peaks_over_0_50 = 0;
      $total_proline_peak_intensity = 0;
      for my $ion_href (@expected_proline_ions) {
	my $series = $ion_href->{'series'};
	my $ordinal = $ion_href->{'ordinal'};
	my $charge = $ion_href->{'charge'};
	my $label = $ion_href->{'label_st'};
	my $bond = $ion_href->{'bond'};
	my $mz = $ion_href->{'mz'};
	# Find the corresponding peak(s), if any. Slow, linear search for now!
	# Isotopes are included in search (trailing lower-case i in label).
	# Note the intensity of the most intense peak.
	printf "Looking for max relative intensity for <b>$label ($bond)</b> at mz %0.4f<br>\n", $mz if $DEBUG;
	my $max_intens = 0;
	for my $peak (@{$annotated_peaks_aref}) {
	  my $label_regex = $label;
	  $label_regex =~ s/\^/\\\^/g;
	  $label_regex = "^${label_regex}i?\$";
	  for my $ann (keys %{$peak->{'annotations'}}) {
	    if ($ann =~ /${label_regex}/) {
	      my $intensity = $peak->{'norm_intens'};
	      if ($intensity > $max_intens) {
		$max_intens = $intensity;
	      }
	      my $massdiff = $peak->{'annotations'}->{$ann};
	      #printf "&nbsp;&nbsp;&nbsp;&nbsp;rel. intensity %0.4f, annotation string $peak->{'annotation_string'}<br>\n", $intensity if $DEBUG;
	      printf "&nbsp;&nbsp;&nbsp;&nbsp;$peak->{'annotation_string'} is rel intens %0.4f... &nbsp;&nbsp;\n", $intensity if $DEBUG;
	    }
	  }
	}
	if ($max_intens) {
	  $ion_href->{'rel_intens'} = $max_intens;
	  print "<br>\n" if $DEBUG;
	  printf "=>Max relative intensity is <b>%0.3f</b><br><br>\n", $max_intens if $DEBUG;
	} else {
	  print "No peaks found.<br><br>\n" if $DEBUG;
	}
	$n_proline_peaks_over_0_10++ if $max_intens > 0.10;
	$n_proline_peaks_over_0_50++ if $max_intens > 0.50;
	$total_proline_peak_intensity += $max_intens;
      }
      # Proline score should be based on:
      # Number of expected proline fragments with intensity > 0.10
      # Number of expected proline fragments with intensity > 0.50
      # Total proline fragment intensity
      # Calculated only if prolines exists in peptide
      $proline_peak_score = $total_proline_peak_intensity +
	$n_proline_peaks_over_0_10 +
	$n_proline_peaks_over_0_50;
      if ($n_prolines == 1) {
	$score_threshold = $proline_score_thresholds[0];
      } elsif ($n_prolines == 2) {
	$score_threshold = $proline_score_thresholds[1];
      } else {
	$score_threshold = $proline_score_thresholds[2];
      }
      $good1 = $proline_peak_score > $score_threshold;
      $eval1 = $good1 ? "GOOD" : "No Call";
    }
  }


  my $evaluation = "";

  $evaluation = "&nbsp;&nbsp;&nbsp;&nbsp;$n_prolines prolines.";
  if ($n_prolines) {
    $evaluation .= "&nbsp;&nbsp;&nbsp;&nbsp;$n_possible_proline_peaks possible observed y or b peaks\n";
    if ($n_possible_proline_peaks) {
      $evaluation .= sprintf "&nbsp;&nbsp;&nbsp;&nbsp;Sum proline peak intensities is %0.3f<br>\n",
      $total_proline_peak_intensity;
      $evaluation .= sprintf "&nbsp;&nbsp;&nbsp;&nbsp;<b>%d</b> w/ rel intens > 0.10<br>\n",
      $n_proline_peaks_over_0_10;
      for my $ion_href (@expected_proline_ions) {
	$evaluation .= sprintf "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<b>$ion_href->{'label_st'}</b> (mz %0.3f, rel intens %0.3f)<br>", $ion_href->{'mz'}, $ion_href->{'rel_intens'} if ($ion_href->{'rel_intens'} > 0.10 && $ion_href->{'rel_intens'} <= 0.50);
      }
      $evaluation .= sprintf "&nbsp;&nbsp;&nbsp;&nbsp;<b>%d</b> w/ rel intens > 0.50<br>\n",
      $n_proline_peaks_over_0_50;
      for my $ion_href (@expected_proline_ions) {
	$evaluation .= sprintf "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<b>$ion_href->{'label_st'}</b> (mz %0.3f, rel intens %0.3f)<br>", $ion_href->{'mz'}, $ion_href->{'rel_intens'} if ($ion_href->{'rel_intens'} > 0.50);
      }
      $evaluation .= sprintf "Proline peak score (sum of 3) is %0.2f:&nbsp;&nbsp;<b>$eval1</b> (threshold for $n_prolines prolines is $score_threshold)<br>\n",
      $proline_peak_score;
    } else {
     $evaluation .= "<br>\n";
    }
  } else {
   $evaluation .= "<br>\n";
  }

  return $evaluation;

}

###############################################################################
=head1 BUGS

Please send bug reports to SBEAMS-devel@lists.sourceforge.net

=head1 AUTHOR

Terry Farrah (terry.farrah@systemsbiology.org)

=head1 SEE ALSO

perl(1).

=cut
###############################################################################
1;

__END__
###############################################################################
###############################################################################
###############################################################################
