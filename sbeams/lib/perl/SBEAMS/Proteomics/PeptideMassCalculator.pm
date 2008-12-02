package SBEAMS::Proteomics::PeptideMassCalculator;

###############################################################################
# Program     : SBEAMS::Proteomics::PeptideMassCalculator
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id: XMLUtilities.pm 4246 2006-01-11 09:12:10Z edeutsch $
#
# Description : This is part of the SBEAMS::Proteomics module which
#               provides an interface to InsilicoSpectro for calculating
#               peptide masses
#
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################


use strict;
use SBEAMS::Connection::Settings qw(:default );
use InSilicoSpectro::InSilico::MassCalculator 'setMassType','getMass';

use vars qw ( $H $O %supported_modifications );


###############################################################################
# Constructor
###############################################################################
sub new {
  my $this = shift;
  my $class = ref($this) || $this;
  my $self = {};
  bless $self, $class;

  #### Initialize InsilicoSpectro.
  my $config_file = $CONFIG_SETTING{INSILICOSPECTRO_CONFIG};
  $config_file ||= '/tools/lib/perl5/site_perl/5.8.0/InSilicoSpectro/config/insilicodef.xml';

  InSilicoSpectro::InSilico::MassCalculator::init( $config_file );

  #### Get some constants
  $H = getMass('el_H');
  $O = getMass('el_O');

  #### Define supported modifications
  %supported_modifications = (
    'monoisotopic' => {
      'n[145]' => 144.102063,   # ABI iTRAQ (UniMod)
      'C[143]' => 39.994915,    # Pyro-carbamidonmethyl (Unimod)
      'C[148]' => 45.987721,    # Beta-methylthiolation (UniMod)
      'C[160]' => 57.021464,    # Carbamidomethyl (UniMod)Cys_CAM
      'C[161]' => 58.005479,    # Search ERROR?? Maybe not, maybe Carboxymethyl?? Latin Square?
      'C[174]' => 71.037114,    # Propionamide (Acrylamide adduct) used initially by IPAS (UniMod)
      'C[177]' => 74.055944,    # Propionamide:2H(3) (Acrylamide_heavy) used initially by IPAS (UniMod)
      'C[303]' => 200.0,        # ? ABI cl-ICAT light from Bernd HuBCellRaft data
      'C[312]' => 209.0,        # ? ABI cl-ICAT heavy from Bernd HuBCellRaft data
      'C[245]' => 142.0,        # ? light from jwatts HumanTCellJCaM2.5 data
      'C[251]' => 148.0,        # ? heavy from jwatts HumanTCellJCaM2.5 data
      'C[330]' => 227.126991,   # ABI cl-ICAT light (UniMod)
      'C[339]' => 236.157185,   # ABI cl-ICAT heavy (Unimod)
      'C[517]' => 414.193691,   # Glycopeptide capture ?? (UniMod)
      'C[545]' => 442.224991,   # ABI old ICAT light (UniMod)
      'C[553]' => 450.275205,   # ABI old ICAT heavy (UniMod)
      'E[111]' => -18.010565,   # Pyro-glu from E (UniMod)
      'K[272]' => 144.102063,   # ABI iTRAQ (UniMod)
      'K[136]' => 8.014199,     # Silac label (UniMod)
      'M[147]' => 15.994915,    # Oxidation (UniMod)
      'N[115]' => 0.984016,     # Glyc-Asn (UniMod)
      'R[166]' => 10.008269,    # Silac (UniMod)
      'Q[111]' => -17.026549,   # Pyro-glu from Q (UniMod)
      'S[167]' => 79.966331,    # Phosphorylation (UniMod)
      'S[166]' => 79.966331,    # Phosphorylation (UniMod)
      'T[181]' => 79.966331,    # Phosphorylation (UniMod)
      'Y[243]' => 79.966331,    # Phosphorylation (UniMod)
    },
    'average' => {
      'n[145]' => 144.1544,     # ABI iTRAQ (UniMod)
      'C[143]' => 40.0208,      # Pyro-carbamidonmethyl (Unimod)
      'C[148]' => 46.0916,      # Beta-methylthiolation (UniMod)
      'C[160]' => 57.0513,      # Cys_CAM (UniMod)
      'C[161]' => 58.0361,      # Search ERROR?? Maybe not, maybe Carboxymethyl?? Latin Square?
      'C[174]' => 71.0779,      # Propionamide (Acrylamide adduct) used initially by IPAS (UniMod)
      'C[177]' => 74.0964,      # Propionamide:2H(3) (Acrylamide_heavy) used initially by IPAS (UniMod)
      'C[303]' => 200.0,        # ? ABI cl-ICAT light from Bernd HuBCellRaft data
      'C[312]' => 209.0,        # ? ABI cl-ICAT heavy from Bernd HuBCellRaft data
      'C[245]' => 142.0,        # ? light from jwatts HumanTCellJCaM2.5 data
      'C[251]' => 148.0,        # ? heavy from jwatts HumanTCellJCaM2.5 data
      'C[330]' => 227.2603,   # ABI cl-ICAT light (UniMod)
      'C[339]' => 236.1942,   # ABI cl-ICAT heavy (Unimod)
      'C[517]' => 414.5196,   # Glycopeptide capture ?? (Unimod)
      'C[545]' => 442.5728,   # ABI old ICAT light (UniMod)
      'C[553]' => 450.6221,   # ABI old ICAT heavy (UniMod)
      'E[111]' => -18.0153,   # Pyro-glu from E (UniMod)
      'K[272]' => 144.1544,   # ABI iTRAQ (UniMod)
      'K[136]' => 7.9427,     # Silac label (UniMod)
      'M[147]' => 15.9848,    # Oxidation (UniMod)
      'N[115]' => 0.9848,     # Glyc-Asn (UniMod)
      'R[166]' => 9.9296,     # Silac (UniMod)
      'Q[111]' => -17.0305,   # Pyro-glu from Q (UniMod)
      'S[167]' => 79.9799,    # Phosphorylation (UniMod)
      'S[166]' => 79.9799,    # Phosphorylation (UniMod)
      'T[181]' => 79.9799,    # Phosphorylation (UniMod)
      'Y[243]' => 79.9799,    # Phosphorylation (UniMod)
    },
  );

  $self->{supported_modifications} = \%supported_modifications;


  return($self);
}


###############################################################################
# getPeptideMass
###############################################################################
sub getPeptideMass {
  my $self = shift;
  my %args = @_;


  #### Decode the argument list
  my $sequence = $args{'sequence'} || '';
  my $VERBOSE = $args{'verbose'} || '';
  my $mass_type = $args{'mass_type'} || 'monoisotopic';
  my $charge = $args{'charge'};

  #### Set mass type
  if ($mass_type eq 'monoisotopic') {
    setMassType(0);
  } elsif ($mass_type eq 'average') {
    setMassType(1);
  } else {
    print STDERR "ERROR: Unrecognized mass_type '$mass_type'\n";
    return(undef);
  }

  #### Handle all the mass modifications
  my $cumulative_mass_diff = 0;
  while ($sequence =~ /\[/) {
    if ($sequence =~ /([A-Znc]\[\d+\])/) {
      my $mod = $1;
      my $aa = substr($mod,0,1);
      my $mass_diff = $supported_modifications{$mass_type}->{$mod};
      if (defined($mass_diff)) {
	$cumulative_mass_diff += $mass_diff;
	$sequence =~ s/[A-Znc]\[\d+\]/$aa/;
      } else {
	print STDERR "ERROR: Mass modification $mod is not supported yet\n";
	return(undef);
      }
    } else {
      print STDERR "ERROR: Unresolved mass modification in '$sequence'\n";
      return(undef);
    }
  }

  #### Remove n-term and c-term notation
  $sequence =~ s/[nc]//g;

  #### Fail if imprecise AA's are present
  return(undef) if ($sequence =~ /[BZX]/);

  #### Calculate the neutral peptide mass using InSilicoSpectro
  my @modif = ();
  my $mass = InSilicoSpectro::InSilico::MassCalculator::getPeptideMass(
    pept=>$sequence,
    modif=>\@modif
  );

  #### Add modifications
  $mass += $cumulative_mass_diff;

  #### Convert to m/z if charge was supplied
  if (defined($charge) && $charge > 0 && $charge <= 10) {
    $mass = ($mass+$charge*$H)/$charge;
  }

  return($mass);

} # end getPeptideMass



###############################################################################

1;

__END__
###############################################################################
###############################################################################
###############################################################################

=head1 NAME

SBEAMS::Proteomics::PeptideMassCalculator - Calculates a peptide's
  monoisotopic or average mass given a sequence and optionally charge

=head1 SYNOPSIS

    use SBEAMS::Proteomics::PeptideMassCalculator;
    my $calculator = new SBEAMS::Proteomics::PeptideMassCalculator;
    my $mz = $calculator->getPeptideMass(
      sequence => 'QC[160]TIPADFK',
      mass_type => 'monoisotopic',
      charge => 2,
    );

=head1 DESCRIPTION

    This module is a wrapper for InSilicoSpectro to more simply calculate
    masses for peptides including modifications, charge states, etc.

=head1 METHODS

=item B<getPeptideMass( <input params> )>

    Returns the mass given parameters:

      sequence  => String containing sequence
      mass_type => String containting either monoisotopic or average
      charge    => Charge state for which to calculate m/z.  If no or 0
                   charge is provided, then the neutral mass is returned.

=head1 AUTHOR

Eric Deutsch <edeutsch@systemsbiology.org>

=head1 SEE ALSO

perl(1).

=cuz
