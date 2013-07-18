package SBEAMS::PeptideAtlas::SpectralCounting;

###############################################################################
# Class       : SBEAMS::PeptideAtlas::SpectralCounting
# Author      : Terry Farrah <tfarrah@systemsbiology.org>
#
=head1 SBEAMS::PeptideAtlas::SpectralCounting

=head2 SYNOPSIS

  SBEAMS::PeptideAtlas::SpectralCounting

=head2 DESCRIPTION

This is part of the SBEAMS::PeptideAtlas module which handles
things related to spectral counting

=cut
#
###############################################################################

use strict;
use POSIX;  #for floor()
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
require Exporter;
@ISA = qw();
$VERSION = q[$Id$];
@EXPORT_OK = qw();

#use SBEAMS::Connection;
#use SBEAMS::Connection::Tables;
#use SBEAMS::Connection::Settings;
#use SBEAMS::PeptideAtlas::Tables;
#use SBEAMS::PeptideAtlas::AtlasBuild;


###############################################################################
# Global variables
###############################################################################
use vars qw($VERBOSE $TESTONLY $sbeams);
our @EXPORT = qw(
 countPepsInProt
 hasGlycoSite
 get_estimated_abundance
);


###############################################################################
# countPepsInProt
###############################################################################
sub countPepsInProt
{
  my %args = @_;
  my $seq = $args{'seq'};
  my $glyco_only = $args{'glyco_only'} || 0;
  my $nxt_only = $args{'nxt_only'} || 0;
  my $min_len = $args{'min_len'} || 7;
  my $npeps = 0;

  my $pepseq = "";
  my $first_aa_in_pep_to_Cterm = "";
  my $aa_to_Cterm = "";
  my $aa = "";
  my $Nterm_aa_is_in_pepseq = 0;

  # chop off anything after any asterisk. (PAB appended peptides July 2013)
  $seq =~ s/\*.*//;

  # process sequence from C-term to N-term (backwards)
  while ($seq || $Nterm_aa_is_in_pepseq ) {
    $aa = uc(chop($seq)) if (!$Nterm_aa_is_in_pepseq);

    # If position is K/R and not followed by P, cleave and process
    # $pepseq, the peptide we've been building backwards
    if ( $Nterm_aa_is_in_pepseq  ||
        (($aa eq 'K' || $aa eq 'R' ) && $aa_to_Cterm ne 'P')) {

      # count this pep, if appropriate
      if (length($pepseq) >= $min_len &&
         ( !$glyco_only ||
          ( $glyco_only && !$nxt_only &&
            hasGlycoSite(seq=>$pepseq, next_aa=>$first_aa_in_pep_to_Cterm )) ||
          ( $glyco_only && $nxt_only &&
            hasGlycoSite(
              seq=>$pepseq,
              next_aa=>$first_aa_in_pep_to_Cterm,
              nxt_only=>1,
           )) 
         )) {
        $npeps++;
      }
      last if ($Nterm_aa_is_in_pepseq);

      # Save the first aa in this pep, and initialize the next pep to
      # Nterm
      $first_aa_in_pep_to_Cterm = substr($pepseq, 0, 1);
      $pepseq = $aa;

    # We are not cleaving here. Add this aa to the pep.
    } else {
      $pepseq = $aa . $pepseq;
    }
    $Nterm_aa_is_in_pepseq = 1 if (length($seq) == 0);

    # Save the amino acid we added to the pep
    $aa_to_Cterm = $aa;
  }
  return $npeps;
}


###############################################################################
# hasGlycoSite
###############################################################################
sub hasGlycoSite
{
  my %args = @_;
  my $seq = $args{'seq'};
  my $next_aa = $args{'next_aa'};
  my $nxt_only = $args{'nxt_only'} || 0;
  my $has_site = 0;

  $seq .= $next_aa;
  $seq = uc($seq);
  if ($nxt_only) {
    $has_site = ($seq =~ m/N[^P]T/);
  } else {
    $has_site = ($seq =~ m/N[^P][ST]/);
  }
  return $has_site;
}


###############################################################################
# get_estimated_abundance 
###############################################################################

sub get_estimated_abundance {

  my %args = @_;
  my $prot_name = $args{prot_name} ||
    die "get_estimated_abundance: prot_name required";
  my $PSM_count = $args{PSM_count} ||
    die "get_estimated_abundance: PSM_count required for $prot_name";
  my $total_PSMs = $args{total_PSMs} || 0;
  my $sequence = $args{sequence} ||
    die "get_estimated_abundance: sequence required for $prot_name";
  my $glyco_atlas = $args{glyco_atlas} || 0;
  my $non_glyco_atlas = !$glyco_atlas;
  my $abundance_conversion_slope = $args{abundance_conversion_slope} || 0;
  my $abundance_conversion_yint = $args{abundance_conversion_yint} || 0;
  my $uncertainties_href = $args{uncertainties_href};

  my $do_estimate_abundance = ($abundance_conversion_slope &&
                               $abundance_conversion_yint       );

  my $min_PSMs = 4;

  my $n_observable_peps = countPepsInProt(
    seq=>$sequence,
    glyco_only=>0,
  );
  my $n_observable_glycopeps = countPepsInProt(
    seq=>$sequence,
    glyco_only=>1,
  );
  my $n_observable_nxtpeps = countPepsInProt(
    seq=>$sequence,
    glyco_only=>1,
    nxt_only=>1,
  );
  my $n_observable_nxsonly_peps =
    $n_observable_glycopeps - $n_observable_nxtpeps;

  # NXS peps are less frequently glycosylated; adjust for this
  # Zielinska et al., Cell 2010, Mann group, find in mouse
  # glycosylated NXT:NXS is 1.4. In Human Plasma Glyco Atlas, it's 1.6.
  # Effect: does not significantly improve correlation with values in
  # non-glyco atlas (Aug 2010). Don't use.

#  my $adj_observable_glycopeps =
#    $n_observable_nxtpeps + ($n_observable_nxsonly_peps / 1.6);
  my $adj_observable_glycopeps = $n_observable_glycopeps;

  #print "$prot_name: $n_observable_peps peps, $n_observable_glycopeps glycopeps, $n_observable_nxtpeps nxt, $n_observable_nxsonly_peps nxs, $adj_observable_glycopeps adj glycopeps\n";
  my $is_glycoprotein = ( $n_observable_glycopeps > 0 );

  ### Create a log-scale adjustment factor based on # of
  ### observable peptides.
  my $adjusted_PSM_count = adjust_PSM_count (
     PSM_count => $PSM_count,
     n_observable_peps => $n_observable_peps,
     n_observable_glycopeps => $adj_observable_glycopeps,
     glyco_atlas => $glyco_atlas,
  );
  
  ### Calculate # PSMs per 100K total PSMs using adjusted_PSM_count
  my $norm_PSMs_per_100K = 0;
  $norm_PSMs_per_100K = ($adjusted_PSM_count / $total_PSMs) *
	100000 if $total_PSMs;

  my $format;
  if ($norm_PSMs_per_100K >= 0.003) {
    $format = "%.3f";
  } elsif ($norm_PSMs_per_100K >= 0.0003) {
    $format = "%.4f";
  } elsif ($norm_PSMs_per_100K >= 0.00003) {
    $format = "%.5f";
  } elsif ($norm_PSMs_per_100K >= 0.000003) {
    $format = "%.6f";
  } else {         # $norm_PSMs_per_100K is zero or < 0.000003
    $format = "%.3f";
  }
  my $formatted_norm_PSMs_per_100K = sprintf($format, $norm_PSMs_per_100K);
  $formatted_norm_PSMs_per_100K = "" if ($norm_PSMs_per_100K == 0);

  my $formatted_estimated_ng_per_ml = "";
  my $abundance_uncertainty = "";

  if ( $do_estimate_abundance &&
       ( $non_glyco_atlas || ($glyco_atlas && $is_glycoprotein) )
     ) {

    my $estimated_ng_per_ml;

    ### Estimate protein molecular weight to get from fmol to ng
    ### Small incorrectness: molecular weights of indistinguishables are
    ### sometimes quite different. Not correct to use MW of first prot
    ### in list.

    ### Schulz/Schirmer in table 1-1 say 108.7 is the weighted mean aa wt.
    ### A bit kludgey, but this whole abundance estimation is kludgey.
    $sequence =~ s/\*.*//;   # remove anything after any asterisk  July 2013
    my $protMW = length($sequence) * 108.7;
    ### If we couldn't get the seq somehow, set protMW to an avg. value
    if ( $protMW == 0 ) {
      $protMW = 30000;
      print "WARNING: couldn't find seq for $prot_name; using MW=30,000\n";
    }
    my $debug = 0;

    if ( $PSM_count >= $min_PSMs  ) {

      my $log_adjusted_PSM_count = log($adjusted_PSM_count) / log(10);
      my $log_estimated_fmol_per_ml =
	    ( $log_adjusted_PSM_count * $abundance_conversion_slope )
		+ $abundance_conversion_yint;
      my $estimated_fmol_per_ml = 10 ** $log_estimated_fmol_per_ml;
      my $estimated_fg_per_ml = $estimated_fmol_per_ml * $protMW;
      $estimated_ng_per_ml = $estimated_fg_per_ml / 1.0e+06;

      print "prot:$prot_name MW:$protMW PSMs:$PSM_count npeps:$n_observable_peps nglycopeps:$n_observable_glycopeps NXTpeps: $n_observable_nxtpeps NXS-onlypeps: $n_observable_nxsonly_peps adj nglycpeps: $adj_observable_glycopeps adj count:$adjusted_PSM_count log adj count:$log_adjusted_PSM_count log fmol/ml:$log_estimated_fmol_per_ml fmol/ml:$estimated_fmol_per_ml fg/ml:$estimated_fg_per_ml ng/ml:$estimated_ng_per_ml\n" if ($debug);

      if ($uncertainties_href) {
        my $index = floor($log_adjusted_PSM_count);
        #print "index $index log adj PSM count $log_adjusted_PSM_count\n";
        $abundance_uncertainty = "$uncertainties_href->{$index}x";
      } else {
	### Hard-coded stuff for 2009/10 plasma atlas
	if ($non_glyco_atlas) {
	  if ($log_adjusted_PSM_count      > 5.0) {
	    $abundance_uncertainty = "6x";
	  } elsif ($log_adjusted_PSM_count > 4.0) {
	    $abundance_uncertainty = "7x";
	  } elsif ($log_adjusted_PSM_count > 3.0) {
	    $abundance_uncertainty = "9x";
	  } elsif ($log_adjusted_PSM_count > 2.0) {
	    $abundance_uncertainty = "12x";
	  } elsif ($log_adjusted_PSM_count > 1.0) {
	    $abundance_uncertainty = "15x";
	  } else {
	    $abundance_uncertainty = "19x";
	  }
	} elsif ($glyco_atlas) {
	  if ($log_adjusted_PSM_count      > 3.0) {
	    $abundance_uncertainty = "5x";
	  } elsif ($log_adjusted_PSM_count > 2.0) {
	    $abundance_uncertainty = "7x";
	  } elsif ($log_adjusted_PSM_count > 1.0) {
	    $abundance_uncertainty = "11x";
	  } else {
	    $abundance_uncertainty = "17x";
	  }
	}
      }

    } else {
      $estimated_ng_per_ml = 0;
      $abundance_uncertainty = "";
    }

    $formatted_estimated_ng_per_ml = sprintf("%.1e", $estimated_ng_per_ml);
    $formatted_estimated_ng_per_ml = "" if ($estimated_ng_per_ml == 0);

  }
  return ($formatted_estimated_ng_per_ml, $abundance_uncertainty,
           $formatted_norm_PSMs_per_100K);
}


###############################################################################
# adjust_PSM_count: normalize the PSM count for a protein according to
#       how many observable (tryptic) peptides it has.
###############################################################################
sub adjust_PSM_count {
  my %args = @_;
  my $PSM_count = $args{PSM_count};
  my $n_observable_peps = $args{n_observable_peps};
  my $avg_peps_per_prot = $args{avg_peps_per_prot} || 25;
  my $avg_glycopeps_per_prot = $args{avg_glycopeps_per_prot} || 1;
  my $n_observable_glycopeps = $args{n_observable_glycopeps} || 0;
  my $glyco_atlas = $args{glyco_atlas} || 0;
  my $PSM_adjustment_factor;

  if ($n_observable_peps > 0) {
    ### only about half the PSMs in the human plasma glyco atlas
    ### are glycopeptides, so the adjustment factor considers
    ### both all-peptide and glycopeptide counts.
    if ($glyco_atlas) {
      $PSM_adjustment_factor =
	(  ( $n_observable_glycopeps/$avg_glycopeps_per_prot ) +
	   ( $n_observable_peps/$avg_peps_per_prot ) ) / 2;
    } else {
      $PSM_adjustment_factor =
	$n_observable_peps/$avg_peps_per_prot;
    }
  ### if there are no theoretical tryptic peptides, but
  ### some (non-tryptic) pep is observed anyway, set as though
  ### there is one observable pep
  } else {
    $PSM_adjustment_factor = 1/$avg_peps_per_prot;
  }
  my $adjusted_PSM_count = $PSM_count / $PSM_adjustment_factor;
  return $adjusted_PSM_count;
}


###############################################################################
=head1 BUGS

Please send bug reports to SBEAMS-devel@lists.sourceforge.net

=head1 AUTHOR

Terry Farrah (tfarrah@systemsbiology.org)

=head1 SEE ALSO

perl(1).

=cut
###############################################################################
1;

__END__
###############################################################################
###############################################################################
###############################################################################
