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
#use InSilicoSpectro::InSilico::MassCalculator 'setMassType','getMass';
use InSilicoSpectro::InSilico::MassCalculator;
use SBEAMS::Proteomics::AminoAcidModifications;
use SBEAMS::Proteomics::Sequence::Peptide; 

#use vars qw ( $H $O %supported_modifications @InSilicoConfig );
use vars qw ( %supported_modifications @InSilicoConfig );

@InSilicoConfig= @{$CONFIG_SETTING{INSILICOSPECTRO_CONFIG}};
###############################################################################
# Constructor
###############################################################################
sub new {
  my $this = shift;
  my $class = ref($this) || $this;
  my $self = {};
  bless $self, $class;
  #### Initialize InsilicoSpectro.
  my $config_file;
 
	for my $name (@InSilicoConfig){# ( @{$CONFIG_SETTING{INSILICOSPECTRO_CONFIG}} ) {
		if ( -e $name ) {
      $config_file = $name;
			last;
		} else {
      my $abs_path = "$PHYSICAL_BASE_DIR/$name";
		  if ( -e $abs_path ) {
        $config_file = $abs_path;
	  		last;
      }
    }
	}
	die ( "Unable to find config file " ) unless $config_file;

  InSilicoSpectro::InSilico::MassCalculator::init( $config_file );

#--------------------------------------------------
#   #### Get some constants
#   $H = getMass('el_H');
#   $O = getMass('el_O');
#-------------------------------------------------- 

  my $AAmodifications = new SBEAMS::Proteomics::AminoAcidModifications;
  %supported_modifications = %{$AAmodifications->{supported_modifications}};

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
  if ($sequence =~ /\[/ && $sequence !~ /\[\d+\]/){ 
    my $peptide = SBEAMS::Proteomics::Sequence::Peptide->new( sequenceString => $sequence );
    $sequence = $peptide->{deltaMassSequenceString};
    $sequence = "n$sequence" if ($sequence =~ /^\[/);
    $sequence =~ s/\]-/]/g;
    $sequence =~ s/-\[/[/g; 

  } 
  while ($sequence =~ /\[/) {
    if ($sequence =~ /([A-Znc]\[\d+\])/) {
      my $mod = $1;
      my $aa = substr($mod,0,1);
      my $mass_diff = $supported_modifications{$mass_type}->{$mod};
      if (not defined ($mass_diff)){
          ## try other mass type
          if ($mass_type eq 'monoisotopic'){
             $mass_type = 'average';
          }else{
             $mass_type = 'monoisotopic';
          }
          $mass_diff = $supported_modifications{$mass_type}->{$mod};
      }
      
      if (defined($mass_diff)) {
	        $cumulative_mass_diff += $mass_diff;
	        $sequence =~ s/[A-Znc]\[\d+\]/$aa/;
      } else {
	        print STDERR "ERROR: Mass modification $sequence $mod is not supported yet\n";
	        return(undef);
      }
    }elsif($sequence =~ /([A-Znc])\[([\+\-])([\d+\.]+)\]/){
       my $aa = $1;
       my $sign = $2;
       my $val = $3;
       if ($sign eq '+'){
         $cumulative_mass_diff += $val;
       }elsif ($sign eq '-'){
         $cumulative_mass_diff -= $val;
       }else{
         die "ERROR: sign in modification, $sign, not supported\n";
       }
       $sequence =~ s/[A-Znc][\[\+\-\d\.\]]+/$aa/;

    }else {
      print STDERR "ERROR: Unresolved mass modification in '$sequence'\n";
      return(undef);
    }
  }

  #### Remove n-term and c-term notation
  $sequence =~ s/[nc]//g;
  #### Fail if imprecise AA's are present
  return(undef) if ($sequence =~ /[BZXU]/);

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
    my $proton_mass = 1.00727646688;  #from Jimmy Eng, 08July2011 to E Deutsch
    $mass = ($mass+$charge*$proton_mass)/$charge;
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
