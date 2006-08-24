package Hydro;

use 5.006;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

## NOTE: Adopting some params from HydroProfiler.pl
##       (Author: Ian Forsythe, Canadian Bioinformatics Help Desk 16 August 2004)

## hydrophobicity parameters:
## Kyte-Doolittle et al. 1982
## Eisenberg et al. 1984 
## Guo et al. 1986
## hydrophilicity parameters:
## Hopp & Woods 1981

## Is it okay to use the parameters above, with a locked window-size = sequence length?
## the rest of the protein is gone, so window size is only useful for big peptides, correct?
## I can make an assumption:  for sequence length < 19, window size = sequence length
##                            for all else, window size = 19


# This allows declaration	use Hydro ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);
our $VERSION = '0.01';


# Preloaded methods go here.

#######################################################################
#  calcHydrophobicityG -- calculate hydrophobicity using Guo params.
#
#  Reference: Guo D., Mant C.T., Taneja A.K., Parker J.M.R. and 
#  Hodges R.S.: J. Chromatogr. 359, 499 (1986) 
#  "Prediction of peptide retention times in reversed-phase high-performance 
#  liquid chromatography I. Determination of retention coefficients of 
#  amino acid residues of model synthetic peptides" ??
#
#  Taking coefficients from Krohin et al. 2004, Table II
#
#  @param sequence  peptide sequence
#  @return mean hydrophobicity
#######################################################################
sub calcHydrophobicityG
{

    my %args = @_;

    my $TEST = $args{'test'} || "";

    my $sequence = $args{'sequence'} || ""; 

    ## chomp sequence, and remove trailing "*" if present:
    chomp($sequence);

    $sequence =~ s/^(.*)\*$/$1/g;


    my %hash = (
          'W',    8.8,
          'F',    8.1,
          'L',    8.1,
          'I',    7.4,
          'M',    5.5,
          'V',    5.0,
          'Y',    4.5,
          'A',    2.0,
          'T',    0.6,
          'P',    2.0,
          'E',    1.1,
          'Z',    1.1,
          'D',    0.2,
          'B',    0.2,
          'C',    2.6,
          'S',   -0.2,
          'Q',    0.0,
          'G',   -0.2,
          'N',   -0.6,
          'R',   -0.6,
          'H',   -2.1,
          'K',   -2.1,
    );

    if ($TEST)
    {

        $sequence = "GASP";

    }

    my $mean_hydrophobicity = calcHydroph( sequence => $sequence,
        hash_ref => \%hash);

    if ($TEST)
    {

        my $testExpected = 3.6;

        my $testCalculated = sprintf("%.2f", $mean_hydrophobicity);

        if ($testExpected != $testCalculated)
        {

            print "TEST FAILED in calcHydrophobicityG\n";
            print "expected: $testExpected, but calculated: $testCalculated\n"

        }

    }

    return $mean_hydrophobicity;    
}


#######################################################################
#  calcHydrophobicityKD -- calculate hydrophobicity using Kyte-Doolittle
#  params.  uses window_size = peptide length for length < 19 and
#  window_size = 19 for length >= 19.
#
#  Reference: Kyte, J. and Doolittle, R. 1982. 
#  "A simple method for displaying the hydropathic character of a protein."
#   J. Mol. Biol. 157: 105-132.
#
#  @param sequence  peptide sequence
#  @return mean hydrophobicity
#######################################################################
sub calcHydrophobicityKD 
{

    my %args = @_;

    my $TEST = $args{'test'} || "";

    my $sequence = $args{'sequence'} || ""; 

    ## chomp sequence, and remove trailing "*" if present:
    chomp($sequence);

    $sequence =~ s/^(.*)\*$/$1/g;


    my %hash = (
          'A',    1.800,
          'R',   -4.500,
          'N',   -3.500,
          'B',   -3.500,
          'D',   -3.500,
          'C',    2.500,
          'Q',   -3.500,
          'E',   -3.500,
          'Z',   -3.500,
          'G',   -0.400,
          'H',   -3.200,
          'I',    4.500,
          'L',    3.800,
          'K',   -3.900,
          'M',    1.900,
          'F',    2.800,
          'P',   -1.600,
          'S',   -0.800,
          'T',   -0.700,
          'W',   -0.900,
          'Y',   -1.300,
          'V',    4.200
    );

    if ($TEST)
    {

        $sequence = "GASP";

    }

    my $mean_hydrophobicity = calcHydroph( sequence => $sequence,
        hash_ref => \%hash);

    if ($TEST)
    {

        my $testExpected = -0.25;

        my $testCalculated = sprintf("%.2f", $mean_hydrophobicity);

        if ($testExpected != $testCalculated)
        {

            print "TEST FAILED in calcHydrophobicityKD\n";
            print "expected: $testExpected, but calculated: $testCalculated\n"

        }

    }

    return $mean_hydrophobicity;    
}

#######################################################################
#  calcHydrophobicityE -- calculate hydrophobicity using Eisenberg
#  params.  uses window_size = peptide length for length < 19 and
#  window_size = 19 for length >= 19.
#
## values were taken from http://expasy.org/tools/pscale/Hphob.Eisenberg.html
## Amino acid scale: Normalized consensus hydrophobicity scale.
## Author(s): Eisenberg D., Schwarz E., Komarony M., Wall R.
## Reference: J. Mol. Biol. 179:125-142(1984).
#
#  @param sequence  peptide sequence
#  @return mean hydrophobicity
#######################################################################
sub calcHydrophobicityE
{

    my %args = @_;

    my $TEST = $args{'test'} || "";

    my $sequence = $args{'sequence'} || ""; 

    ## chomp sequence, and remove trailing "*" if present:
    chomp($sequence);

    $sequence =~ s/^(.*)\*$/$1/g;

    my %hash = (
        'A',   0.620,
        'R',  -2.530,
        'N',  -0.780,
        'D',  -0.900,
        'B',  -0.900,
        'C',   0.290,
        'Q',  -0.850,
        'E',  -0.740,
        'Z',  -0.740,
        'G',   0.480,
        'H',  -0.400,
        'I',   1.380,
        'L',   1.060,
        'K',  -1.500,
        'M',   0.640,
        'F',   1.190,
        'P',   0.120,
        'S',  -0.180,
        'T',  -0.050,
        'W',   0.810,
        'Y',   0.260,
        'V',   1.080
    );

    if ($TEST)
    {

        $sequence = "GASP";

    }

    my $mean_hydrophobicity = calcHydroph( sequence => $sequence,
        hash_ref => \%hash);

    if ($TEST)
    {

        my $testExpected = +0.26;

        my $testCalculated = sprintf("%.2f", $mean_hydrophobicity);

        if ($testExpected != $testCalculated)
        {

            print "TEST FAILED in calcHydrophobicityE,n";
            print "expected: $testExpected, but calculated: $testCalculated\n"

        }

    }

    return $mean_hydrophobicity;    
}

#######################################################################
#  calcHydrophilicityHW -- calculate hydrophophilicity using Hopp - Woods
#  params.  uses window_size = peptide length for length < 19 and
#  window_size = 19 for length >= 19.
#
#  from http://expasy.org/tools/pscale/Hphob.Woods.html
#  Amino acid scale: Hydrophilicity.
#  Author(s): Hopp T.P., Woods K.R.
#  Reference: Proc. Natl. Acad. Sci. U.S.A. 78:3824-3828(1981).
#
#  @param sequence  peptide sequence
#  @return mean hydropholicity
#######################################################################
sub calcHydrophilicityHW
{

    my %args = @_;

    my $TEST = $args{'test'} || "";

    my $sequence = $args{'sequence'} || ""; 

    ## chomp sequence, and remove trailing "*" if present:
    chomp($sequence);

    $sequence =~ s/^(.*)\*$/$1/g;

    my %hash = (
        'A',    -0.500,
        'R',     3.000,
        'N',     0.200,
        'D',     3.000,
        'B',     3.000,
        'C',    -1.000,
        'Q',     0.200,
        'E',     3.000,
        'Z',     3.000,
        'G',     0.000,
        'H',    -0.500,
        'I',    -1.800,
        'L',    -1.800,
        'K',     3.000,
        'M',    -1.300,
        'F',    -2.500,
        'P',     0.000,
        'S',     0.300,
        'T',    -0.400,
        'W',    -3.400,
        'Y',    -2.300,
        'V',    -1.500
    );

    if ($TEST)
    {

        $sequence = "GASP";

    }

    my $mean_hydrophilicity = calcHydroph( sequence => $sequence,
        hash_ref => \%hash);

    if ($TEST)
    {

        my $testExpected = -0.05;

        my $testCalculated = sprintf("%.2f", $mean_hydrophilicity);

        if ($testExpected != $testCalculated)
        {

            print "TEST FAILED in calcHydrophobicityE,n";
            print "expected: $testExpected, but calculated: $testCalculated\n"

        }

    }

    return $mean_hydrophilicity;    
}


#######################################################################
#  calcHydroph -- calculate hydrophobicity or hydrophilicity using 
#  supplied param hash  and peptide sequence.  Called internally
#  by other subroutines.
#
#  uses window_size = peptide length for length < 19 or
#  window_size = 19 for length >= 19.
#  @param sequence  peptide sequence
#  @param amino acid hydrophobicity or hydrophilicity param hash
#  @return mean hydrophobicity or mean hydrophilicity
#######################################################################
sub calcHydroph
{

    my %args = @_;

    my $sequence = $args{'sequence'} || die "need peptide sequence ($!)"; 

    ## chomp sequence, and remove trailing "*" if present:
    chomp($sequence);

    #$sequence =~ s/^(.*)\*$/$1/g;
    ## remove all "*" 's
    $sequence =~ s/\*//g;

    my $amino_acid_hydroph_hash_ref = $args{'hash_ref'} ||
        die "need amino_acid_hydroph_hash_ref ($!)";

    my %amino_acid_hydroph_hash = %{$amino_acid_hydroph_hash_ref};


    my $sequence_length = length($sequence);


    my $window_size = 19;

    if ($sequence_length < $window_size)
    {

        $window_size = $sequence_length;

    }

    my($center,$length);

    my $half = (($window_size + 1)/2);


    my $mean_hydroph = 0;

    for( my $i=0; $i <= ( $sequence_length - $window_size ); $i++) 
    {

        my $window = substr($sequence, $i, $window_size);

        my $sum=0;

        for( my $j=0; $j < $window_size; $j++) 
        {

            my $hydroph = 0;

            my $residue = substr($window, $j, 1);

            if ( exists $amino_acid_hydroph_hash{$residue} )
            {

                $hydroph = $amino_acid_hydroph_hash{$residue};

            } elsif ($residue ne "X")
            {

                print "hmm, what's the hydro* of this residue: $residue? Seen in sequence: $sequence \n";

            }

            $sum+=$hydroph;

        }

        $center = $i + $half;

        $mean_hydroph = $sum/$window_size;

    }

    return $mean_hydroph;    
}


1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Hydrophobicity and Hydrophility module

=head1 SYNOPSIS

  use Hydro;

  ## to use Kyte-Doolittle params:
  my $hydrophobicity = Hydro::calcHydrophobicityKD( sequence => $peptideSequence );

  ## to use Eisenberg params:
  my $hydrophobicity = Hydro::calcHydrophobicityE( sequence => $peptideSequence );

  ## to use Hopp - Woods params:
  my $hydrophilicity = Hydro::calcHydrophilicityHW( sequence => $peptideSequence );

  ## to use Guo et al. params:
  my $hydrophilicity = Hydro::calcHydrophilicityG( sequence => $peptideSequence );



=head1 DESCRIPTION

Hydrophobicity and Hydrophility module

=head2 EXPORT

None by default.


=head1 AUTHOR

Nichole King

=head1 SEE ALSO

L<perl>.

=cut
