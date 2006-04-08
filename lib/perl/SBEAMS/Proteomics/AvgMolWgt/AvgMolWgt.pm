package AvgMolWgt;

use 5.006;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use AvgMolWgt ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);
our $VERSION = '0.01';


# Preloaded methods go here.

sub calcAvgMolWgt {

    my %args = @_;

    my $TEST = $args{'test'} || "";

    my $sequence = $args{'sequence'} || ""; 

    if ($TEST) {

        $sequence = "GASP"; 

    }

    unless( ($sequence) || ($TEST) ) {

        die "need to provide sequence ($!)";    

    }


    my %amino_acid_ave_mass_hash = (
        "G" => "57.0519",
        "A" => "71.0788",
        "S" => "87.0782",
        "P" => "97.1167",
        "V" => "99.1326",
        "T" => "101.1051",
        "C" => "103.1388",
        "L" => "113.1594",
        "I" => "113.1594",
        "N" => "114.1038",
        "B" => "114.6",
        "D" => "115.0886",
        "Q" => "128.1307",
        "K" => "128.1741",
        "E" => "129.1155",
        "Z" => "129.1155",
        "M" => "131.1926",
        "H" => "137.1411",
        "F" => "147.1766",
        "R" => "156.1875",
        "Y" => "163.1760",
        "W" => "186.2132",
        "X" => "119.",
        "U" => "150.03",
        "*" => "0.0",
    );
    ## X corresponds to any residue
    ## U is Selenocysteine: C3H5NOSe : SeC : U with monoisoptopic wgt 150.95364

    # Split sequence into individual chars
    my @sequence_letters = split( // , $sequence );

    my $sequence_length = $#sequence_letters + 1;

    my $mass = 0;
	
    for ( my $counter = 0 ; $counter < $sequence_length ; $counter++ ) {

        my $letter = $sequence_letters[$counter];

#       ## xxxx ...comment out when not needed
#       unless (exists $amino_acid_ave_mass_hash{$letter}) {

#           die "could not identify ($counter/$sequence_length) ".
#               "letter $letter".
#               " in sequence $sequence";

#       }

        ##get mass from letter hash:
        $mass = $mass + $amino_acid_ave_mass_hash{$letter};

    }


    # Add hydroxy group at the C terminus and an H at the N ter
    $mass = $mass + 18.0106796;


    if ($TEST) {

        my $testExpectedMass = 330.3363;

        my $m1 = sprintf("%.4f", $mass);

        unless ( $m1 == $testExpectedMass) {

           die "TEST failed ($!)";

        }

        print "\npassed tests in AvgMolWgt::calcAvgMolWgt\n";
    }

    return $mass;    
}
1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

AvgMolWgt - given a peptide sequence, returns average molecular weight

=head1 SYNOPSIS

  use SBEAMS::Proteomics::AvgMolWgt::AvgMolWgt

  my $mass = AvgMolWgt::calcAvgMolWgt( sequence => $peptide_sequence );

=head1 DESCRIPTION

AvgMolWgt - given a peptide sequence, returns average molecular weight


=head2 EXPORT

None by default.


=head1 AUTHOR

Nichole King

=head1 SEE ALSO

L<perl>.

=cut
