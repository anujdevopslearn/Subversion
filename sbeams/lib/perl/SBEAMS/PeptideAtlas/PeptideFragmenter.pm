package SBEAMS::PeptideAtlas::PeptideFragmenter;

use strict;

my $DEBUG = 0;

use SBEAMS::Proteomics::AminoAcidModifications;
my $AAmodifications = new SBEAMS::Proteomics::AminoAcidModifications;

my %AAmasses = %{InitializeMass(1)};

use vars qw( $mzMinimum $mzMaximum );


###############################################################################
# Constructor
###############################################################################
sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = { @_ };
    bless $self, $class;

    # Allow these to be set in the constructor
    my $mzMin = $self->{MzMinimum} || 0;
    my $mzMax = $self->{MzMaximum} || 99000 ;

    $self->setMzMinimum( $mzMin );
    $self->setMzMaximum( $mzMax );
    return($self);
}


###############################################################################
# setDEBUG
#
###############################################################################
sub setDEBUG {
    my $SUB_NAME = "setDEBUG";
    my $self = shift || croak("parameter self not passed");
    my $value = shift;
    croak("ERROR: value not passed to $SUB_NAME") if (!defined($value));

    $DEBUG = $value;
    return;
}


###############################################################################
# setMzMinimum
#
###############################################################################
sub setMzMinimum {
    my $SUB_NAME = "setMzMinimum";
    my $self = shift || croak("parameter self not passed");
    my $value = shift;
    die("ERROR: value not passed to $SUB_NAME") if (!defined($value));

    $mzMinimum = $value;
    return;
}


###############################################################################
# setMzMaximum
#
###############################################################################
sub setMzMaximum {
    my $SUB_NAME = "setMzMaximum";
    my $self = shift || croak("parameter self not passed");
    my $value = shift;
    die("ERROR: value not passed to $SUB_NAME") if (!defined($value));

    $mzMaximum = $value;
    return;
}

###############################################################################
# getMzMinimum
###############################################################################
sub getMzMinimum {
    my $self = shift;
    return $mzMinimum;
}

###############################################################################
# getMzMaximum
###############################################################################
sub getMzMaximum {
    my $self = shift;
    return $mzMaximum;
}


###############################################################################
# getExpectedFragments
# @narg   modifiedSequence (required) - peptide sequence to fragment
# @narg   charge (required) - desired precursor charge
# @narg   precursor_excl - m/z range around precursor 
# @narg   omit_precursor - Omit ions within precursor_excl of precursor mass
# @narg   fragment_charge - return only specified series
###############################################################################
sub getExpectedFragments {
    my $METHOD = 'getExpectedFragments';
    my $self = shift || die ("self not passed");
    my %args = @_;

    #### Process parameters
    my $modifiedSequence = $args{modifiedSequence}
    or die("ERROR[$METHOD]: Parameter modifiedSequence not passed");
    my $charge = $args{charge}
    or die("ERROR[$METHOD]: Parameter charge not passed");

    my @residues = Fragment($modifiedSequence);
    my $length = scalar(@residues);
    my $pluses = '+++++++++++++';
    my @masses;

    my $H = $AAmasses{"h"};
    my $totalMass;

    for (my $i=0; $i<$length; $i++) {
			foreach my $residue (split(/(?=[A-Za-z])/, $residues[$i])){
			  print "residues[$i]=$residue\t";
				my $mass = $AAmasses{$residue};
				unless ($mass) {
					if ($residue =~ /(\w)\[(\d+)\]/) {
						$mass = $AAmasses{$1};
						if ($1 =~ /[nc]/){
						 	$mass = 0; 
						}
						if ($AAmodifications->{supported_modifications}->{monoisotopic}->{$residue}) {
								$mass += $AAmodifications->{supported_modifications}->{monoisotopic}->{$residue};
						} else {
								die("ERROR: Unable to find mass for '$residue'");
						}
            print "$mass\n";
					}
					unless ($mass) {
						die("ERROR: Unable to find mass for '$residue'");
					}
				}
				
			  $masses[$i] += $mass;
			  $totalMass += $mass;
			  print "residues[$i] = $residues[$i] = $masses[$i] $totalMass\n";
			}
    }


    my (@Bions,@Yions,@indices,@rev_indices,@productIons);
    my (@Bbonds, @Ybonds);

    my %precursor = (
		     mz => ( ( 2 * $H + $AAmasses{"o"} + $totalMass ) + $charge * $H ) / $charge,
		     series => 'precursor',
		     charge => $charge,
		     label => "precursor",
		     );
			push(@productIons,\%precursor);


			for (my $iCharge=1; $iCharge<=$charge; $iCharge++) {

				# Caller can request only certain fragment charges
				next if $args{fragment_charge} && $iCharge != $args{fragment_charge};

				my $Bion = 0;
				my $Yion = 2*$H + $AAmasses{"o"} + $totalMass;

				#### Compute the ion masses
				for (my $i = 0; $i<$length; $i++) {
						$Bion += $masses[$i];
						$Yion -= $masses[$i-1] if ($i > 0);

						#### B index & Y index
						$indices[$i] = $i+1;
						$rev_indices[$i] = $length-$i;

						#### B ion mass & Y ion mass
						$Bions[$i] = ($Bion + $iCharge*$H)/$iCharge;
						$Yions[$i] = ($Yion + $iCharge*$H)/$iCharge;

						#### Bonds
						$Bbonds[$i] = $residues[$i].($residues[$i+1]||' ');
						$Ybonds[$i] = ($residues[$i-1]||' ').$residues[$i];

						my %tmp = (
								 mz => $Bions[$i],
								 series  => 'b',
								 ordinal => $indices[$i],
								 charge  => $iCharge,
								 label   => "b".$indices[$i].substr($pluses,0,$iCharge),
								 label_st=> "b".$indices[$i].(($iCharge == 1)?'':"^$iCharge"),
								 bond    => $Bbonds[$i],
								 );

						if ( $args{precursor_excl} && $args{omit_precursor} ) {
					unless ( ( $precursor{mz} + $args{precursor_excl} ) > $Bions[$i] &&  ( $precursor{mz} - $args{precursor_excl} ) < $Bions[$i] ) {
							if ( $Bions[$i] >= $mzMinimum && $Bions[$i] <= $mzMaximum ) {
						push(@productIons,\%tmp);
							}
					}
						} else {
					if ( $Bions[$i] >= $mzMinimum && $Bions[$i] <= $mzMaximum ) {
							push(@productIons,\%tmp);
					}
	    }

	    my %tmp2 = (
				mz => $Yions[$i],
				series  => 'y',
				ordinal => $rev_indices[$i],
				charge  => $iCharge,
				label   => "y".$rev_indices[$i].substr($pluses,0,$iCharge),
				label_st=> "y".$rev_indices[$i].(($iCharge == 1)?'':"^$iCharge"),
				bond    => $Ybonds[$i],
			);

	    if ( $args{precursor_excl} && $args{omit_precursor} ) {
				unless ( ( $precursor{mz} + $args{precursor_excl} ) > $Yions[$i] &&  ( $precursor{mz} - $args{precursor_excl} ) < $Yions[$i] ) {
						if ( $Yions[$i] >= $mzMinimum && $Yions[$i] <= $mzMaximum ) {
					push(@productIons,\%tmp2);
						}
				}
					} else {
				if ( $Yions[$i] >= $mzMinimum && $Yions[$i] <= $mzMaximum ) {
						push(@productIons,\%tmp2);
				}
	    }

	    #printf("%i  %10.3f  %2i  %6s  %2i  %10.3f\n",$iCharge,$Bions[$i],$indices[$i],$residues[$i],$rev_indices[$i],$Yions[$i]);
	}
    }

    my @sortedProductIons = sort byMz @productIons;
    foreach my $ion ( @sortedProductIons ) {
	#printf("%10.4f  %s  %s\n",$ion->{mz},$ion->{label},$ion->{bond});
    }


    return(\@sortedProductIons);
}



###############################################################################
# byMz
###############################################################################
sub byMz {
    return $a->{mz} <=> $b->{mz};
}


###############################################################################
# numerically
###############################################################################
sub numerically {
    return $a <=> $b;
}


###############################################################################
# Fragment
###############################################################################
sub Fragment {
    my $peptide = shift;
    my $length = length($peptide);
    my @residues = ();
    my $i;

#    for ($i=0; $i<$length; $i++) {
#			if (substr($peptide,$i+1,1) eq '[') {
#				if (substr($peptide,$i+5,1) eq ']') {
#					push (@residues, substr($peptide,$i,6));
#					$i = $i + 5;
#				} elsif (substr($peptide,$i+4,1) eq ']') {
#					push (@residues, substr($peptide,$i,5));
#					$i = $i + 4;
#				} else {die("Blech!");}
#			} elsif (substr($peptide,$i+1,1) =~ /\W/) {
#					push (@residues, substr($peptide,$i,2));
#					$i = $i + 1;
#			} else {
#					push (@residues, substr($peptide,$i,1));
#			}
#   }

    my @modAAs = split(/(?=[A-Za-z])/, $peptide);
    for (my $i=0; $i<=$#modAAs; $i++){
      my $residue = $modAAs[$i];
			## nterminal
			if ($residue =~ /^n/){
				$residue = "$residue$modAAs[$i+1]";
				$i++;
			}
			## cterminal 
			if ($residue =~ /^c\[\d+\]/){
				## append to last residue
				$residues[$#residues] .= $residue;
				$i++;
        next;
      }
      push (@residues, $residue);
    }
        
    #### Return residue array
    return @residues;
}


###############################################################################
# InitializeMasses
###############################################################################
sub InitializeMass {
    my $masstype = shift;
    my %AAmassestmp = ();
    my ($code, $avg, $mono);

    #### AminoAcidMasses contains the mass info
    open (MASSFILE,'/net/dblocal/www/html/sbeams/cgi/Proteomics/AminoAcidMasses.dat') ||
	die "unable to open AminoAcidMasses.dat file!\n";
    while (<MASSFILE>) {
	#### Ignore header line
	next if /^CODE/;
	($code,$avg,$mono) = split;
	if ($masstype) {
	    $AAmassestmp{$code} = $mono;
	} else {
	    $AAmassestmp{$code} = $avg;
	}
    }

    close MASSFILE;
    #### Return references to AAmasses
    return (\%AAmassestmp);
}

1;
