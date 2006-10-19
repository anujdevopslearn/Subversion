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

  #### Initialize InsilicoSpectro. This is still a hard-coded location
  #### Should be changed to be relative to module location.  How?
  InSilicoSpectro::InSilico::MassCalculator::init('/tools/lib/perl5/site_perl/5.8.0/InSilicoSpectro/config/insilicodef.xml');

  #### Get some constants
  $H = getMass('el_H');
  $O = getMass('el_O');

  #### Define supported modifications
  %supported_modifications = (
    'monoisotopic' => {
      'C[160]' => 57.021464,    # Carbamidomethyl (UniMod)Cys_CAM
      'C[161]' => 58.005479,    # Search ERROR?? Maybe not, maybe Carboxymethyl?? Latin Square?
      'C[330]' => 227.126991,   # ABI cl-ICAT light (UniMod)
      'C[339]' => 236.157185,   # ABI cl-ICAT heavy (Unimod)
      'C[517]' => 414.193691,   # Glycopeptide capture ?? (UniMod)
      'C[545]' => 442.224991,   # ABI old ICAT light (UniMod)
      'C[553]' => 450.275205,   # ABI old ICAT heavy (UniMod)
      'K[272]' => 144.10206,    # ABI iTRAQ (UniMod)
      'M[147]' => 15.994915,    # Oxidation (UniMod)
      'N[115]' => 0.984016,     # Glyc-Asn (UniMod)
    },
    'average' => {
      'C[160]' => 57.0513,    # Cys_CAM (UniMod)
      'C[161]' => 58.0361,    # Search ERROR?? Maybe not, maybe Carboxymethyl?? Latin Square?
      'C[330]' => 227.2603,   # ABI cl-ICAT light (UniMod)
      'C[339]' => 236.1942,   # ABI cl-ICAT heavy (Unimod)
      'C[517]' => 414.5196,   # Glycopeptide capture ?? (Unimod)
      'C[545]' => 442.5728,   # ABI old ICAT light (UniMod)
      'C[553]' => 450.6221,   # ABI old ICAT heavy (UniMod)
      'K[272]' => 144.1544,   # ABI iTRAQ (UniMod)
      'M[147]' => 15.9848,    # Oxidation (UniMod)
      'N[115]' => 0.9848,     # Glyc-Asn (UniMod)
    },
  );




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
    if ($sequence =~ /([A-Z]\[\d+\])/) {
      my $mod = $1;
      my $aa = substr($mod,0,1);
      my $mass_diff = $supported_modifications{$mass_type}->{$mod};
      if (defined($mass_diff)) {
	$cumulative_mass_diff += $mass_diff;
	$sequence =~ s/[A-Z]\[\d+\]/$aa/;
      } else {
	print STDERR "ERROR: Mass modification $mod is not supported yet\n";
	return(undef);
      }
    } else {
      print STDERR "ERROR: Unresolved mass modification in '$sequence'\n";
      return(undef);
    }
  }

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

=cut
