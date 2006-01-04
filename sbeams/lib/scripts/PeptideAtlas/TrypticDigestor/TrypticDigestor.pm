package TrypticDigestor;

use 5.008;
use strict;
use warnings;

use AvgMolWgt::AvgMolWgt;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use TrypticDigestor ':all';
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
#  digestSequence - tryptically digest a sequence
#
#  @param sequence  is protein sequence to digest
#  @param n_allowed_missed_cleavages is number of allowed missed cleavages
#  @param min_avg_mol_wgt is lower limit of peptide avg mol wgt to keep
#  @param max_avg_mol_wgt is upper limit of peptide avg mol wgt to keep
#  @return hash with key = peptide sequence
#                    value = avg mol wgt
#######################################################################
sub digestSequence 
{

    my %args = @_;

    my $sequence= $args{'sequence'} || 
        "die need digestSequence needs sequence";

    my $n_allowed_missed_cleavages = $args{'n_allowed_missed_cleavages'}
        || "0";

    my $min_avg_mol_wgt = $args{'min_avg_mol_wgt'} || "0";

    my $max_avg_mol_wgt = $args{'max_avg_mol_wgt'} || "40000";


    ## chomp sequence, and remove trailing "*" if present:
    chomp($sequence);

    $sequence =~ s/^(.*)\*$/$1/g;

    ## length of sequence:
    my $len = length($sequence);


    ## hash to fill:
    my %peptide_mass_hash;


    ## array to hold positions of cleavages in sequence:
    my @tryptic_positions;

    ######## get array of K and R positions, excluding when before a proline: ##############
    for (my $i=0; $i <= $len; $i++)
    {

        my $amino_acid = substr($sequence, $i, 1);

        if ( ($amino_acid eq "K") || ($amino_acid eq "R") )
        {

            my $next_amino_acid = substr($sequence, $i+1, 1);

            unless ( $next_amino_acid eq "P" )
            {

                push(@tryptic_positions, $i);

            }

        }

    }


    ########### In chops below, handling: ####################
    ## (1) sub-sequence from first letter to first cleavage allowing $n_allowed_missed_cleavages
    ## (2) sub-sequence from second cleavage to last cleavage allowing $n_allowed_missed_cleavages
    ## (3) sub-sequence from last cleavage to last letter

    my $first_amino_acid_position;

    my $peptide;

    my $avgMolWgt;

    ## handling the first 2 cases:
    for (my $i=0; $i <= $#tryptic_positions; $i++)
    {

        my $nmc = $n_allowed_missed_cleavages;

        if ($i == 0)
        {

            ## position of first amino-acid letter in protein sequence:
            $first_amino_acid_position = 0;

        } else
        {
            ## position of (value of last index) + 1
            $first_amino_acid_position = ($tryptic_positions[$i-1]) + 1;

        }


        ## if on last tryptic position, don't look further for missed cleavages:
        if ( $i == $#tryptic_positions)
        {

            $nmc = 0;

        }

        for (my $j = 0; $j <= $nmc; $j++)
        {

            if ( $tryptic_positions[$i + $j] < $len)
            {

                my $seq_length = $tryptic_positions[$i + $j] - $first_amino_acid_position + 1;

                $peptide = substr($sequence, $first_amino_acid_position, $seq_length);

                ## now get avg mass of peptide sequence:
                $avgMolWgt = AvgMolWgt::calcAvgMolWgt( sequence => $peptide );


                ## if between lower and upper mass limits, store it in hash:
                if ( ($avgMolWgt >= $min_avg_mol_wgt) && ($avgMolWgt <= $max_avg_mol_wgt) )
                {

                    $peptide_mass_hash{$peptide} = $avgMolWgt;

                }

##              print "$peptide:$first_amino_acid_position:$tryptic_positions[$i + $j]\n";

            }

        }

    }


    ## handling the last case, trailing peptide sequence:
    ## if tryptic_positions[$#tryptic_positions] is last character, done, else get trailing
    ## peptide
    if ( $#tryptic_positions > 0)
    {
        unless ( $tryptic_positions[$#tryptic_positions] == $len )
        {
            $first_amino_acid_position =
                ($tryptic_positions[$#tryptic_positions]) + 1;

            $peptide = substr($sequence, $first_amino_acid_position);

            $avgMolWgt = AvgMolWgt::calcAvgMolWgt( sequence => $sequence );

            ## if between lower and upper mass limits, store it in hash:
            if ( ($avgMolWgt > $min_avg_mol_wgt) && ($avgMolWgt < $max_avg_mol_wgt) )
            {

                $peptide_mass_hash{$peptide} = $avgMolWgt;

##      print "$peptide\n";

            }

        }

    }


    return %peptide_mass_hash;

}
1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

TrypticDigestor - Perl extension for insilico tryptic digestion of a sequence,
allowing n missed cleavages

=head1 SYNOPSIS

  use TrypticDigestor;

  my %peptide_hash = TrypticDigestor::digestSequence( 
      sequence => $sequence, 
      n_allowed_missed_cleavages => '1',
      min_avg_mol_wgt = 200,
      max_avg_mol_wgt = 5000
  );

  returns a hash with with key = tryptically digested peptide,
                           value = avg mol wgt

=head1 ABSTRACT

  Module to parse a protein sequence into peptides following tryptic digestion
  rules and filtered by supplied parameters.


=head1 DESCRIPTION

  Module to parse a protein sequence into peptides following tryptic digestion
  rules and filtered by supplied parameters.

  Tryptic digest rules:
  -- cleaves on K's and R's, cleaving on C-terminus
  -- exception: no cleavage with a trailing N-terminus P (proline)
      so not cleaving on KP nor RP

  Additional parameters accepted by the digestSequence method are:
  n_allowed_missed_cleavages, min_avg_mol_wgt, and max_avg_mol_wgt.

  The parameters default to the following if not specified:
     n_allowed_missed_cleavages = 0
     min_avg_mol_wgt = 0 
     max_avg_mol_wgt = 40,000  [for QStar...]


=head2 EXPORT

None by default.


=head1 AUTHOR

Nichole King

=head1 SEE ALSO

    uses AvgMolWgt

L<perl>.

=cut
