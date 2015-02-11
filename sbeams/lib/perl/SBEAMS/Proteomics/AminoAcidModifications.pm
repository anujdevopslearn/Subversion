package SBEAMS::Proteomics::AminoAcidModifications;

###############################################################################
# Program     : SBEAMS::Proteomics::AminoAcidModifications
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
#
# Description : This is part of the SBEAMS::Proteomics module which
#               stores relevant modification information keyed by
#               the simplified TPP C[160] notation.
#
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################


use strict;
use warnings;

use vars qw ( %supported_modifications );


###############################################################################
# Constructor
###############################################################################
sub new {
  my $this = shift;
  my $class = ref($this) || $this;
  my $self = {};
  bless $self, $class;

  #### Define supported modifications
  %supported_modifications = (
    'monoisotopic' => {
      'n[29]'  => 28.031300,    # di-Methylation  (Unimod)
      'n[33]'  => 32.056407,    # DiMethyl-CHD2   (Unimod)
      'n[37]'  => 36.07567,     # Dimethyl-Heavy  (Unimod)
      'n[43]'  => 42.010565,    # Acetylation     (Unimod)
      'n[44]'  => 43.005814,    # Carbamylation   (Unimod)
      'n[145]' => 144.102063,   # ABI iTRAQ (UniMod)
      'n[230]' => 229.162932,   # 6 plex
      'n[305]' => 304.199040,   # 8 plex

      'A[85]'  => 14.01565,     # Methylation (Unimod) This may be a red herring
      'C[143]' => 39.994915,    # Pyro-carbamidonmethyl (Unimod)
      'C[148]' => 45.987721,    # Beta-methylthiolation (UniMod)
      'C[160]' => 57.021464,    # Carbamidomethyl (UniMod)Cys_CAM
      'C[161]' => 58.005479,    # Search ERROR?? Maybe not, maybe Carboxymethyl?? Latin Square?
      'C[174]' => 71.037114,    # Propionamide (Acrylamide adduct) used initially by IPAS (UniMod)
      'C[177]' => 74.055944,    # Propionamide:2H(3) (Acrylamide_heavy) used initially by IPAS (UniMod)
      'C[208]' =>	105.057849,   # S-pyridylethylation 
      'C[303]' => 200.0,        # ? ABI cl-ICAT light from Bernd HuBCellRaft data
      'C[312]' => 209.0,        # ? ABI cl-ICAT heavy from Bernd HuBCellRaft data
      'C[245]' => 142.0,        # ? light from jwatts HumanTCellJCaM2.5 data
      'C[251]' => 148.0,        # ? heavy from jwatts HumanTCellJCaM2.5 data
      'C[330]' => 227.126991,   # ABI cl-ICAT light (UniMod)
      'C[339]' => 236.157185,   # ABI cl-ICAT heavy (Unimod)
      'C[517]' => 414.193691,   # Glycopeptide capture ?? (UniMod)
      'C[545]' => 442.224991,   # ABI old ICAT light (UniMod)
      'C[546]' => 442.224991,   # ABI old ICAT light (UniMod)
      'C[553]' => 450.275205,   # ABI old ICAT heavy (UniMod)
      'C[554]' => 450.275205,   # ABI old ICAT heavy (UniMod)
      'E[111]' => -18.010565,   # Pyro-glu from E (UniMod)
      'F[157]' => 10.027228,    # 13C(9)15N(1) Silac label (Unimod)
      'I[119]' => 6.020129,     # 13C(6) Silac label (Unimod)
      'L[116]' =>	3.018830 ,    #	D3_Label 
      'L[123]' => 10.062767,    # D10_Label 

      'K[132]' => 4.02511,	    # D4_Label
      'K[272]' => 144.102063,   # ABI iTRAQ (UniMod)
      'K[156]' => 28.031300,    # di-Methylation  (Unimod)
      'K[300]' => 172.133363,   # ABI iTRAQ + di-Methylation
      'K[160]' => 32.056407,    # DiMethyl-CHD2   (Unimod)
      'K[164]' => 36.07567,     # DiMethyl-Heavy   (Unimod)
      'K[134]' =>	6.020129,     # Silac label (UniMod)
      'K[136]' => 8.014199,     # Silac label (UniMod)
      'K[273]' => 145.01975,    # Carboxyamidomethylated cleaved DSP-crosslinker
      'K[357]' => 229.162932,   # 6 plex
      'K[432]' => 304.199040,   # 8 plex
      'K[467]' => 339.161662,   #	NHS-LC-Biotin 

      'L[119]' => 6.020129,     # 13C(6) Silac label (Unimod)
      'L[120]' => 7.017164,     # 13C(6)15N(1) Silac label (Unimod)
      'M[147]' => 15.994915,    # Oxidation (UniMod)
      'M[163]' =>	31.989829,    #	Dioxidation (UniMod) 
      'N[115]' => 0.984016,     # Glyc-Asn (UniMod)
      'R[166]' => 10.008269,    # Silac (UniMod)
      'R[162]' =>	6.020129,     # 13C(6) Silac label 
      'Q[111]' => -17.026549,   # Pyro-glu from Q (UniMod)
      'S[167]' => 79.966331,    # Phosphorylation (UniMod)
      'S[166]' => 79.966331,    # Phosphorylation (UniMod)
      'T[181]' => 79.966331,    # Phosphorylation (UniMod)
      'V[104]' => 5.016774,     # 13C(5) Silac label (Unimod)
      'V[105]' => 6.013809,     # 13C(5)15N(1) Silac label (Unimod)
      'Y[243]' => 79.966331,    # Phosphorylation (UniMod)
      'Y[307]' => 144.1059,     # 4 plex
			},
    'average' => {
      'n[29]'  => 28.0532,      # di-Methylation (Unimod)
      'n[33]'  => 32.0778,      # DiMethyl-CHD2  (Unimod)
      'n[37]'  => 36.0754,      # Dimethyl-Heavy (Unimod)
      'n[43]'  => 42.0367,      # Acetylation    (Unimod)
      'n[44]'  => 43.0247,      # Carbamylation  (Unimod)
      'n[145]' => 144.1544,     # ABI iTRAQ (UniMod)
      'n[230]' => 229.2634,     # 6 plex
      'n[305]' => 304.3081,     # 8 plex
      'C[143]' => 40.0208,      # Pyro-carbamidonmethyl (Unimod)
      'C[148]' => 46.0916,      # Beta-methylthiolation (UniMod)
      'C[160]' => 57.0513,      # Cys_CAM (UniMod)
      'C[161]' => 58.0361,      # Search ERROR?? Maybe not, maybe Carboxymethyl?? Latin Square?
      'C[174]' => 71.0779,      # Propionamide (Acrylamide adduct) used initially by IPAS (UniMod)
      'C[177]' => 74.0964,      # Propionamide:2H(3) (Acrylamide_heavy) used initially by IPAS (UniMod)
      'C[208]' => 105.1372,     # S-pyridylethylation
      'C[303]' => 200.0,        # ? ABI cl-ICAT light from Bernd HuBCellRaft data
      'C[312]' => 209.0,        # ? ABI cl-ICAT heavy from Bernd HuBCellRaft data
      'C[245]' => 142.0,        # ? light from jwatts HumanTCellJCaM2.5 data
      'C[251]' => 148.0,        # ? heavy from jwatts HumanTCellJCaM2.5 data
      'C[330]' => 227.2603,   # ABI cl-ICAT light (UniMod)
      'C[339]' => 236.1942,   # ABI cl-ICAT heavy (Unimod)
      'C[517]' => 414.5196,   # Glycopeptide capture ?? (Unimod)
      'C[545]' => 442.5728,   # ABI old ICAT light (UniMod)
      'C[546]' => 442.5728,   # ABI old ICAT light (UniMod)
      'C[553]' => 450.6221,   # ABI old ICAT heavy (UniMod)
      'C[554]' => 450.6221,   # ABI old ICAT heavy (UniMod)
      'E[111]' => -18.0153,   # Pyro-glu from E (UniMod)
      'F[157]' => 9.9273,     # 13C(9)15N(1) Silac label (Unimod)
      'I[119]' => 5.9559,     # 13C(6) Silac label (Unimod)
      'L[116]' => 3.0185,     # D3_Label
      'L[123]' => 10.0617,    # D10_Label
      'K[132]' => 4.02467,    # D4_Label
      'K[272]' => 144.1544,   # ABI iTRAQ (UniMod)
      'K[273]' => 145.1796,   # Carboxyamidomethylated cleaved DSP-crosslinker
      'K[467]' => 339.4530,   # NHS-LC-Biotin
      'L[119]' => 5.9559,     # 13C(6) Silac label (Unimod)
      'L[120]' => 6.9493,     # 13C(6)15N(1) Silac label (Unimod)
      'K[134]' =>	5.9559,     # Silac label (UniMod)
      'K[136]' => 7.9427,     # Silac label (UniMod)
      'K[156]' => 28.0532,    # di-Methylation (Unimod)
      'K[300]' => 172.2076,   # ABI iTRAQ + di-Methylation
      'K[160]' => 32.0778,    # DiMethyl-CHD2  (Unimod)
      'K[164]' => 36.0754,    # DiMethyl-Heavy  (Unimod)
      'K[357]' => 229.2634,   # 6 plex
      'K[432]' => 304.3081,   # 8 plex
      'M[147]' => 15.9848,    # Oxidation (UniMod)
      'M[163]' =>	31.9988,    #	Dioxidation (UniMod) 
      'N[115]' => 0.9848,     # Glyc-Asn (UniMod)
      'R[166]' => 9.9296,     # Silac (UniMod)
      'R[162]' =>	5.9559,     # 13C(6) Silac label
      'Q[111]' => -17.0305,   # Pyro-glu from Q (UniMod)
      'S[167]' => 79.9799,    # Phosphorylation (UniMod)
      'S[166]' => 79.9799,    # Phosphorylation (UniMod)
      'T[181]' => 79.9799,    # Phosphorylation (UniMod)
      'V[104]' => 4.9633,     # 13C(5) Silac label (Unimod)
      'V[105]' => 5.9567,     # 13C(5)15N(1) Silac label (Unimod)
      'Y[243]' => 79.9799,    # Phosphorylation (UniMod)
      'Y[307]' =>	144.1680,   # 4plex
    },
  );

  $self->{supported_modifications} = \%supported_modifications;


  return($self);
}



###############################################################################

1;

__END__
###############################################################################
###############################################################################
###############################################################################

=head1 NAME

SBEAMS::Proteomics::AminoAcidModifications - Simple container for
  amino acid masses

=head1 SYNOPSIS

    use SBEAMS::Proteomics::AminoAcidModifications;
    my $aminoAcids = new SBEAMS::Proteomics::AminoAcidModifications;
    my $C160modificationMass =
      $aminoAcids->{supported_modifications}->{monoisotopic}->{'C[160]'};

=head1 DESCRIPTION

    This module is a simple container for amino acid mass modifications.

=head1 METHODS

=head1 AUTHOR

Eric Deutsch <edeutsch@systemsbiology.org>

=head1 SEE ALSO

perl(1).

=cuz
