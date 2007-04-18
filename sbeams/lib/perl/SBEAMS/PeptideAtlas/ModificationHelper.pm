package ModificationHelper;

use 5.008;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration       use AvgMolWgt ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(

) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(

);
our $VERSION = '0.01';


## %AAmasses is hash of monoisotopic masses with key = AA, value = mass
use vars qw ( %massHash );

# Preloaded methods go here.
sub new
{
    my $class = shift;
    my %args = @_;
    my $self = {};
    initializeMasses();
    bless ($self, $class);
    return $self;
}

###############################################################################
# initializesMasses -- populates hash of amino acid mono-isotopic masses
###############################################################################
sub initializeMasses {
    %massHash = (
    "G" => "57.02146",
    "A" => "71.03711",
    "S" => "87.02303",
    "P" => "97.05276",
    "V" => "99.06841",
    "T" => "101.04768",
    "C" => "103.00919",
    "L" => "113.08406",
    "I" => "113.08406",
    "N" => "114.04293",
    "D" => "115.02694",
    "Q" => "128.05858",
    "K" => "128.09496",
    "E" => "129.04259",
    "M" => "131.04049",
    "H" => "137.05891",
    "F" => "147.06841",
    "R" => "156.10111",
    "Y" => "163.06333",
    "W" => "186.07931",
    );
}


###############################################################################
# getMasses
#
# @param modified_sequence -- string of amino acid sequences with modications
#  in TPP and SBEAMS style. For example:  EDALN[115]ETR
# @return array of mono-isotopic masses that include modifications 
#
#  Note, this doesn't yet have a way to deal with Nterminus and Cterminus
#  modifications (unless they are specified in same way that amino-acid mods
#  are specified...)
###############################################################################
sub getMasses {

    my ($self, $modified_sequence) = @_;

    croak("missing argument to getMasses") unless defined $modified_sequence;

    my $tmpMod = "";

    my $isInBracket = 0; ## false
    my $isStartBracket = 0; ## false
    my $isEndBracket = 0; ## false

    my @mods;

    for (my $i = 0; $i < length($modified_sequence); $i++)
    {
        my $a = substr($modified_sequence, $i, 1);

        if ( $a =~ /\[/) {
            $isStartBracket = 1; ## true, mod will get added to previous $a
            $isEndBracket = 0;
            $isInBracket = 0;
        } elsif ( $a =~ /\]/) {
            $isEndBracket = 1; ## true
            $isStartBracket = 0;
            $isInBracket = 0;
        } elsif ( $a =~ /\d/) {
            $isInBracket = 1; ## true
            $isEndBracket = 0;
            $isStartBracket = 0;
        } elsif ( $a =~ /\w/) {
            $isInBracket = 0;
            $isEndBracket = 0;
            $isStartBracket = 0;
        }

        ## if not in a bracket sequence, it's modification is 0
        if ( !$isStartBracket && !$isInBracket && !$isEndBracket) {

            if (exists $massHash{$a}) {

                push(@mods, $massHash{$a});

            } else {

                print "WARNING: Unable to find mass for 'residues[$i]'<BR>\n";
            }
        }

        if ($isStartBracket) {

            $tmpMod = "";

            pop(@mods); ## mod gets added to previous $a
        }

        if ($isEndBracket) {

            push(@mods, $tmpMod);

            $tmpMod = "";
        }

        if ($isInBracket) {

            $tmpMod = $tmpMod . $a;
        }
    }

    return @mods;
}

###############################################################################
# getUnmodifiedAAs
#
# @param modified_sequence -- string of amino acid sequences with modications
#  in TPP and SBEAMS style. For example:  EDALN[115]ETR
# @return array of just the amino-acid sequences
#
###############################################################################
sub getUnmodifiedAAs {

    my ($self, $modified_sequence) = @_;

    croak("missing argument to getUnmodifiedAAs") unless defined $modified_sequence;

    my @aas;

    for (my $i = 0; $i < length($modified_sequence); $i++)
    {
        my $a = substr($modified_sequence, $i, 1);

        if ( $a =~ /[a-zA-Z]/) {
            push(@aas, $a);
        }
    }

    return @aas;
}

###############################################################################
# getMass
#
# @param aa -- amino acid sequences 
# @return mono-isotopic mass
###############################################################################
sub getMass {

    my ($self, $aa) = @_;

    croak("missing argument to getMass") unless defined $aa;

    return exists($massHash{$a}) ? exists($massHash{$a}) : 0;
}

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

ModificationHelper - Perl extension to help handle modification masses

=head1 SYNOPSIS

  use ModificationHelper;

  my $helper = new ModificationHelper();

  my @masses = $helper->getMasses("C[330]AT");

  my @aa = $helper->getUnmodifiedAAs("C[330]AT");


=head1 DESCRIPTION

ModificationHelper - Perl extension to help handle modification masses


=head1 SEE ALSO

=head1 AUTHOR

Nichole King

=head1 COPYRIGHT AND LICENSE

=cut
