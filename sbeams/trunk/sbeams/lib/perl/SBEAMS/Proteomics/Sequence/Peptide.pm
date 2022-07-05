package SBEAMS::Proteomics::Sequence::Peptide;

###############################################################################
# Class       : Proteomics::Peptide
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
#
# Description : This class is represent and manipulate a peptide sequence.
#
# Methods:
#   new()
#   setSequenceString()
#   getSequenceString()
#   setModificationString()
#   parseSequenceString()
#   parseModificationString()
#   showAttributes()
#
# Scalar Attributes:
#   inputSequenceString
#   inputModificationsString
#   sequenceString
#   modifiedSequenceString
#   modifiedTPP4SequenceString
#   lcModSequenceString
#   modificationsString
#   ionString
#   nTerminalModification
#   cTerminalModification
#   phantomModification
#   length
#   charge
#
# Complex Attributes:
#   modifiedSequenceArray
#   modificationsArray
#   decodedSequenceArray->{}
#     nativeString
#     aminoAcid
#     modificationAccession
#     modificationName
#     modificationMass
#     totalMass
#     integerTotalMass
#
#
###############################################################################

use strict;
use warnings;

my $VERBOSE = 0;
my $DEBUG = 0;

###############################################################################
# Class variables and setup
###############################################################################
use SBEAMS::Proteomics::CV::MassModificationControlledVocabulary;
my $cv = new SBEAMS::Proteomics::CV::MassModificationControlledVocabulary();


###############################################################################
# Constructor
###############################################################################
sub new {
  my $METHOD = 'new';
  print "DEBUG: Entering $METHOD\n" if ($DEBUG);
  my $self = shift;
  my %parameters = @_;

  my $class = ref($self) || $self;

  #### Create the object with any attributes if supplied
  $self = {
    status => 'SUCCESS',
    message => 'No problems to report',
    translation_override => $parameters{translation_override}
  };
 
  ## add common translations 
  my %common_translation = $cv->getCommonTranslation();
  foreach my $residue (keys %common_translation){
    foreach my $mod (keys %{$common_translation{$residue}}){
      if (not defined $self->{translation_override}->{$residue}{$mod}){
        $self->{translation_override}->{$residue}{$mod} = $common_translation{$residue}{$mod};
      }
    }
  }
  #use Data::Dumper;
  #print Dumper($self->{translation_override});

  bless $self => $class;

  #### Process any passed parameters on new()
  if ( $parameters{sequenceString} ) {
    $self->setSequenceString($parameters{sequenceString});
  }

  if ( $parameters{modificationsString} ) {
    $self->setModificationsString($parameters{modificationsString});
  }

  print "DEBUG: Exiting $METHOD\n" if ($DEBUG);
  return $self;
}


###############################################################################
# setSequenceString: Set the input peptide sequence and parse it
###############################################################################
sub setSequenceString {
  my $METHOD = 'setSequenceString';
  print "DEBUG: Entering $METHOD\n" if ($DEBUG);
  my $self = shift || die ("ERROR [$METHOD]: self not passed");

  $self->{inputSequenceString} = shift;
  $self->parseSequenceString();

  print "DEBUG: Exiting $METHOD\n" if ($DEBUG);
  return $self->{sequenceString};
}


###############################################################################
# getSequenceString: Get attribute sequenceString
###############################################################################
sub getSequenceString {
  my $METHOD = 'getSequenceString';
  print "DEBUG: Entering $METHOD\n" if ($DEBUG);
  my $self = shift;

  print "DEBUG: Exiting $METHOD\n" if ($DEBUG);
  return $self->{sequenceString};
}


###############################################################################
# setModificationsString: Set and parse the modification string
###############################################################################
sub setModificationsString {
  my $METHOD = 'setModificationsString';
  print "DEBUG: Entering $METHOD\n" if ($DEBUG);
  my $self = shift || die ("ERROR [$METHOD]: self not passed");

  $self->{inputModificationsString} = shift;
  $self->parseModificationsString();

  print "DEBUG: Exiting $METHOD\n" if ($DEBUG);
  return $self->{modificationsString};
}

###############################################################################
# parseSequenceString
###############################################################################
sub parseSequenceString {
  my $METHOD = 'parseSequenceString';
  print "DEBUG: Entering $METHOD\n" if ($DEBUG);
  my $self = shift || die ("self not passed");
  my %args = @_;

  my $verbose = $args{verbose};
  $VERBOSE = $verbose if ($verbose);

  my $sequenceString = $args{sequenceString};

  #### If a sequenceString was not passed, then look for a previously supplied one
  unless ( $sequenceString ) {
    $sequenceString = $self->{inputSequenceString};
  }

  #### If sequenceString is not now available, we cannot continue
  unless ( $sequenceString ) {
    $self->{status} = 'ERROR';
    $self->{message} = "ERROR: Attempt to $METHOD with no available sequence string";
    return;
  }

  #### Split and reassemble the peptide into an array
  #print "INFO: sequenceString=$sequenceString\n";
  my @characters = split('',$sequenceString);
  #### Destination array
  my @residues;
  my $iResidue = 0;
  my @aminoAcids;
  my $state = 'start';

  #### Loop over each character and handle it depending on the state we're in
  foreach my $character ( @characters ) {
    #print "**$iResidue\t$state\t$character\n";
      #### Handle the opening of the sequence: could be an nterm mod, phantom mod, or amino acid
      if ( $state eq 'start' ) {
        if ( $character eq 'n' ) {
            $residues[$iResidue] = '' unless ($residues[$iResidue]);
            $residues[$iResidue] .= $character;
            $aminoAcids[$iResidue] = 'n';
            $state = 'nTerminus';
        } elsif ( $character eq '[' ) {
            $residues[$iResidue] = '' unless ($residues[$iResidue]);
            $residues[$iResidue] .= 'n[';
            $aminoAcids[$iResidue] = 'n';
            $state = 'nTerminus';
        } elsif ( $character eq '{' ) {
            $self->{phantomModification} = '' unless ($self->{phantomModification});
            $self->{phantomModification} .= $character;
            $state = 'phantomModification';
        } elsif ( $character =~ /^[A-Za-z]$/) {
            $residues[$iResidue] = '';
            $aminoAcids[$iResidue] = '';
            $iResidue++;
            $residues[$iResidue] = '' unless ($residues[$iResidue]);
            $residues[$iResidue] .= $character;
            $aminoAcids[$iResidue] = '' unless ($aminoAcids[$iResidue]);
            $aminoAcids[$iResidue] .= $character;
            $state = 'residue';
        } else {
            print("ERROR: Unsupported starting character '$character'\n")
        }
      #### Handle just standard amino acid
      } elsif ( $state eq 'residue' ) {
        if ( $character =~ /^[\[]$/ ) {
        $residues[$iResidue] = '' unless ($residues[$iResidue]);
            $residues[$iResidue] .= $character;
            $state = 'inner';
        } elsif ( $character =~ /^[A-Za-z]$/ ) {
            $iResidue++;
        $residues[$iResidue] = '' unless ($residues[$iResidue]);
            $residues[$iResidue] .= $character;
        $aminoAcids[$iResidue] = '' unless ($aminoAcids[$iResidue]);
            $aminoAcids[$iResidue] .= $character;
        } elsif ( $character =~ /^[\]]$/ ) {
            $residues[$iResidue] .= $character;
            $state = 'residue';
        }
      #### Handle in the middle of a modification string
      } elsif ( $state eq 'inner' ) {
        if ( $character !~ /^[\]]$/ ) {
          $residues[$iResidue] = '' unless ($residues[$iResidue]);
          $residues[$iResidue] .= $character;
        } elsif ( $character =~ /^[\]]$/ ) {
          $residues[$iResidue] .= $character;
          $state = 'residue';
        } else {
          print "ERROR parsing $character\n";
        }
      #### Handle the n terminus
      } elsif ( $state eq 'nTerminus' ) {
        if ( $character !~ /^[\]]$/ ) {
          $residues[$iResidue] = '' unless ($residues[$iResidue]);
          $residues[$iResidue] .= $character;
        } elsif ( $character =~ /^[\]]$/ ) {
          $residues[$iResidue] .= $character;
          $self->{nTerminalModification} = $residues[$iResidue];
          $state = 'residue';
        }
      #### Handle inner phantom modification (this is an extra mass on the precursor that immediately and always falls off during fragmentation)
      } elsif ( $state eq 'phantomModification' ) {
        if ( $character =~ /^[\{\[\(\)\.\+\-A-Za-z0-9]$/ ) {
            $self->{phantomModification} .= $character;
        } elsif ( $character =~ /^[\}\]]$/ ) {
            $self->{phantomModification} .= $character;
            $state = 'start';
        }
      ### Handle the cterminus. FIXME. Maybe this should just be a post processing
      } elsif ( $state eq 'cTerminus' ) {
      }
  }

  #### Loop over each of the residues we found and print them if debug mode
  if ($DEBUG) {
    my $i = 0;
    foreach my $residue ( @residues ) {
      printf("Residue %2i: %s\n",$i,($residue||''));
      $i++;
    }
  }


  #### Store some known attributes already
  $self->{modifiedSequenceArray} = \@residues;
  $self->{modifiedSequenceString} = join('',@residues);
  $self->{sequenceString} = join('',@aminoAcids);
  my $length = $iResidue;
  $self->{length} = $length;


  #### In debugging mode, print what we have so far
  if ($DEBUG) {
    print "  modifiedSequenceArray=".join(",",@residues)."\n";
    print "  modifiedSequenceString=$self->{modifiedSequenceString}\n";
    print "  sequenceString=$self->{sequenceString}\n";
    print "  length=$length\n";
  }


  #### Create the decodedSequenceArray, which contains full information about each residue
  my @decodedSequenceArray;
  for (my $iResidue=0; $iResidue<=$length; $iResidue++) {
    $decodedSequenceArray[$iResidue]->{nativeString} = $residues[$iResidue];
    $decodedSequenceArray[$iResidue]->{aminoAcid} = $aminoAcids[$iResidue];

    #### If this is a modified residue
    if ( $residues[$iResidue] =~ /[\[\(](.+)[\]\)]/ ) {
      my $modification = $1;
      my $modification_mass = $1;
      #### If this is a delta notation residue (e.g. M[+16])
      if ( $modification =~ /^([\+\-])([\d\.]+)$/) {
        #$decodedSequenceArray[$iResidue]->{integerTotalMass} = $modification;  #### do we need this???
					#### Check to make sure we have the reverse lookup loaded, and if not, trigger a load. FIXME, this is awkward
				unless ( $cv->{massReverseLookup} ) {
					$cv->getTerm( name => 'oxidation' );
						}
				#### Look for this numerical modification (e.g. M[+16]) in the CV to find out what it really is
				my $siteCode = substr($residues[$iResidue],0,1);
        my $modification_4digit = sprintf("%s%.4f", $1, $2);
				#use Data::Dumper;
				#print Dumper($self->{translation_override});
        if (defined $self->{translation_override}->{$siteCode}{$modification_4digit}){
          $modification = $self->{translation_override}->{$siteCode}{$modification_4digit};
        }else{
					#print "Looking for a deltaMass $modification for site $siteCode\n";
					my $lookup = $cv->{massReverseLookup}->{$siteCode};
					#### For now, look for the closest match
					my $closestDelta = 999;
					my @closestMatchList=();
					foreach my $possibleMatch ( @{$lookup} ) {
						if ( abs($possibleMatch->{deltaMass} - $modification) < $closestDelta ) {
							@closestMatchList = ();
							#printf("==$modification\t$possibleMatch->{deltaMass}\t%f\t$closestDelta\n",$possibleMatch->{deltaMass} - $modification);
							$closestDelta = abs($possibleMatch->{deltaMass} - $modification);
							push @closestMatchList, $possibleMatch if ($closestDelta < 0.001);
						}elsif(abs($possibleMatch->{deltaMass} - $modification)  == $closestDelta){
							push @closestMatchList, $possibleMatch if ($closestDelta < 0.001); 
						}
					}
					if (@closestMatchList ) {
						my $str = '';
						foreach my $closestMatch (@closestMatchList){
							$modification = $cv->{terms}->{$closestMatch->{accession}}->{name};
              my $sign = '+';
              $sign = '-' if ($closestMatch->{deltaMass} < 0);
							$str .= "$siteCode\[". sprintf("%.4f", $modification_mass) .
                      "\]=$siteCode\[$modification\]   closestMatchMass=$closestMatch->{deltaMass}\n";
							print "  Input modification $modification interpreted as $closestMatch->{accession} with mass delta $closestMatch->{deltaMass} (diff $closestDelta)\n" if ($verbose || $DEBUG);
						}
						if (@closestMatchList > 1){
							print "please generate translation override file, TPP_PTM_translation_override.txt\n";
							print "WARNING: more than one closestMatch for $siteCode\n$str\n";
						}
					}
        }
      #### If this is a numerically modified residue (e.g. M[147])
      } elsif ( $modification =~ /^[\d\.]+$/) {
        $decodedSequenceArray[$iResidue]->{integerTotalMass} = $modification;

        #### Check to make sure we have the reverse lookup loaded, and if not, trigger a load. FIXME, this is awkward
        unless ( $cv->{commonModificationsReverseLookup} ) {
          $cv->getTerm( name => 'oxidation' );
            }

        #### Look for this numerical modification (e.g. M[147]) in the CV to find out what it really is
        my $lookup = $cv->{commonModificationsReverseLookup}->{$residues[$iResidue]};
        #use Data::Dumper;
        #print Dumper($lookup);
        my $primaryMatch = $lookup->{main};
        print "  Input modification $residues[$iResidue] interpreted as $primaryMatch\n" if ($verbose || $DEBUG);
            if ( $primaryMatch && $primaryMatch =~ /([A-Za-z])\((.+)\)/) {
          $modification = $2;
            }
        }

      #### If we have a word-based modification (e.g. M(Oxidation)) either originally or after the reverse lookup
      unless ( $modification =~ /^[\d]+$/ ) {
        my $modificationName = $modification;
        $decodedSequenceArray[$iResidue]->{modificationName} = $modification;

        #### Get information about this modification
        my $modificationAccession = $modificationName;
        my $modificationAttributes;
        if ($modification =~ /^[\+\-][\d\.]+$/){
           ## modifications not in Unimod
           #print "residue=$aminoAcids[$iResidue] modificationName=$modificationName\n";
           $modificationAttributes = $self->getDeltaNotionAttributes($aminoAcids[$iResidue], $modificationName);
        }else{
					if ( $modificationAccession =~ /MOD:/ ) {
						$modificationAccession = $cv->getTerm( accession => $modificationAccession, verbose => 0 );
					} else {
						$modificationAccession = $cv->getTerm( name => $modificationName, verbose => 0 );
					}
					if ($modificationAccession) {
						$modificationAttributes = $cv->getAttributes( accession => $modificationAccession, residue => $aminoAcids[$iResidue], verbose => 0 );
					} else {
						print "ERROR: Unable to find '$modificationName' in the controlled vocabulary\n"
					}
        }
        if ($modificationAttributes){
						$decodedSequenceArray[$iResidue]->{modificationAccession} = $modificationAttributes->{accession} if ($modificationAttributes);
						$decodedSequenceArray[$iResidue]->{modificationName} = $modificationAttributes->{name} if ($modificationAttributes);
						$decodedSequenceArray[$iResidue]->{modificationMass} = $modificationAttributes->{monoisotopicMass} if ($modificationAttributes);
						$decodedSequenceArray[$iResidue]->{totalMass} = $modificationAttributes->{totalMass}||0 if ($modificationAttributes);
						$decodedSequenceArray[$iResidue]->{integerTotalMass} = int(($modificationAttributes->{totalMass}||0)+0.5) if ($modificationAttributes);
						$decodedSequenceArray[$iResidue]->{modFormatTPP4} = $modificationAttributes->{modFormatTPP4} if ($modificationAttributes);
        }
      }
    }
  }

  $self->{decodedSequenceArray} = \@decodedSequenceArray;
  $self->createFormattedStrings();

  print "DEBUG: Exiting $METHOD\n" if ($DEBUG);
  return;
}


###############################################################################
# parseModificationsString
###############################################################################
sub parseModificationsString {
  my $METHOD = 'parseModificationsString';
  print "DEBUG: Entering $METHOD\n" if ($DEBUG);
  my $self = shift || die ("self not passed");
  my %args = @_;

  my $verbose = $args{verbose};
  $VERBOSE = $verbose if ($verbose);

  my $modificationsString = $args{modificationsString};

  #### If a modificationsString was not passed, then look for a previously supplied one
  unless ( $modificationsString ) {
    $modificationsString = $self->{inputModificationsString};
  }

  #### If nothing useful was passed, the return
  unless ( $modificationsString ) {
    $self->{inputModificationsString} = '';
    return;
  }

  #### If sequenceString is not available, we cannot continue
  unless ( $self->{modifiedSequenceArray} ) {
    $self->{status} = 'ERROR';
    $self->{message} = "ERROR: Attempt to $METHOD with no available modifiedSequenceArray";
    return;
  }
  my @sequenceArray = @{$self->{modifiedSequenceArray}};
  my $length = $self->{length};
  my @decodedSequenceArray = @{$self->{decodedSequenceArray}};

  #### Parse the modifications string into a hash
  my @modifications = split(";",$modificationsString);
  my %modifications;
  foreach my $modification ( @modifications ) {
    print "DEBUG: Parsing and validating '$modification'\n" if ($DEBUG);
    my ( $position,$residue,$modificationName ) = split(",",$modification);

    #### If only two elements are provided, assume they are position and name
    if (defined($residue) && !defined($modificationName)) {
      $modificationName = $residue;
      $residue = '?';
    }

    #### Validate the data
    unless ( defined($position) ) {
      $self->{status} = 'ERROR';
      $self->{message} = "ERROR: Error parsing modification '$modification': position is missing";
      return;
    }
    unless ( $position =~ /^\d+$/ ) {
      $self->{status} = 'ERROR';
      $self->{message} = "ERROR: Error parsing modification '$modification': position must be an integer";
      return;
    }
    unless ( $position >= 0 && $position <= $length ) {
      $self->{status} = 'ERROR';
      $self->{message} = "ERROR: Error parsing modification '$modification': position out of bounds";
      return;
    }
    unless ( defined($residue) ) {
      $self->{status} = 'ERROR';
      $self->{message} = "ERROR: Error parsing modification '$modification': residue is missing";
      return;
    }
    unless ( $residue =~ /^[A-Za-z\?]$/ || $residue =~ /^[nc]\-term$/ ) {
      $self->{status} = 'ERROR';
      $self->{message} = "ERROR: Error parsing modification '$modification': residue is not a legal value";
      return;
    }
    unless ( defined($modificationName) ) {
      $self->{status} = 'ERROR';
      $self->{message} = "ERROR: Error parsing modification '$modification': modificationName is missing";
      return;
    }

    #### Validate that the referred amino acid is correct
    #### First, skip n or c terminal modifications
    if ( $position > 0 && $position <= $length ) {

      #### If the input did not specify the modified residue, assume it from the position in the peptide
      if ( $residue eq '?' ) {
        $residue = uc(substr($sequenceArray[$position],0,1));
      }

      #### Check that the specified residue matches the one in the peptide sequence
      unless ( uc($residue) eq uc(substr($sequenceArray[$position],0,1) ) ) {
        $self->{status} = 'ERROR';
        $self->{message} = "ERROR: Error parsing modification '$modification': residue at position $position is ".substr($sequenceArray[$position],0,1)." instead of $residue";
        return;
      }
    }

    #### Store the modification as a hash
    my %tmp = (
      position => $position,
      residue => $residue,
      modificationName => $modificationName,
    );
    $modifications{$position} = \%tmp;
  }

  #### Iterate through list modifying the peptide
  foreach my $modification ( keys(%modifications) ) {
    print "DEBUG: Applying modification at '$modification'\n" if ($DEBUG);
    my $position = $modifications{$modification}->{position};
    my $residue = $modifications{$modification}->{residue};
    my $modificationName = $modifications{$modification}->{modificationName};

    #### Get information about this modification
    my $modificationAttributes;
    if ($modificationName =~ /^[\+\-][\d\.]+$/){
        ## mods not found in Unimod
        #print "2 residue=$residue modificationName=$modificationName\n";
        $modificationAttributes = $self->getDeltaNotionAttributes($residue, $modificationName); 
    }else{
			my $modificationAccession = $cv->getTerm( name => $modificationName, verbose => 0 );
			if ($modificationAccession) {
				$modificationAttributes = $cv->getAttributes( accession => $modificationAccession, residue => $residue, verbose => 0 );
			}else{
				print "ERROR: Unable to find '$modificationName' in the controlled vocabulary\n"
			}
    }

    if ( $position == 0 ) {
      $sequenceArray[$position] = "n($modificationName)";
      $decodedSequenceArray[$position]->{nativeString} = "n($modificationName)";
      $decodedSequenceArray[$position]->{aminoAcid} = "n-term";
    } elsif ( $position <= $length ) {
      $sequenceArray[$position] = "$residue($modificationName)";
      $decodedSequenceArray[$position]->{nativeString} = "$residue($modificationName)";
      $decodedSequenceArray[$position]->{aminoAcid} = "$residue";
    } else {
      $sequenceArray[$position] = "c($modificationName)";
      $decodedSequenceArray[$position]->{nativeString} = "c($modificationName)";
      $decodedSequenceArray[$position]->{aminoAcid} = "c-term";
    }
    $decodedSequenceArray[$position]->{modificationName} = $modificationName;
    $decodedSequenceArray[$position]->{modificationAccession} = $modificationAttributes->{accession} if ($modificationAttributes);
    $decodedSequenceArray[$position]->{modificationMass} = $modificationAttributes->{monoisotopicMass} if ($modificationAttributes);
    $decodedSequenceArray[$position]->{totalMass} = $modificationAttributes->{totalMass} if ($modificationAttributes);
  }

  #### Store the array and create the whole set of variously formatted strings
  $self->{modifiedSequenceArray} = \@sequenceArray;
  $self->createFormattedStrings();

  return;
}

###############################################################################
# showAttributes
###############################################################################
sub showAttributes {
  my $METHOD = 'showAttributes';
  print "DEBUG: Entering $METHOD\n" if ($DEBUG);
  my $self = shift || die ("self not passed");
  my %args = @_;

  my $verbose = $args{verbose};
  $VERBOSE = $verbose if ($verbose);

  my $buffer = "Peptide attributes:\n";
  foreach my $attribute ( qw ( status message inputSequenceString inputModificationsString sequenceString modifiedSequenceString modifiedTPP4SequenceString
                               lcModSequenceString modificationsString ionString nTerminalModification cTerminalModification phantomModification length charge ) ) {
    $buffer .= "  $attribute=".($self->{$attribute}||'')."\n";
  }

  #### Display the full internal information
  $buffer .= "Internal array:\n";
  my $length = $self->{length};
  for (my $i=0; $i<=$length; $i++) {
    my $residueRef = $self->{decodedSequenceArray}->[$i];
    my $aminoAcid = $residueRef->{aminoAcid} || '?';
    my $nativeString = $residueRef->{nativeString} || '?';
    my $modificationAccession = $residueRef->{modificationAccession} || '?';
    my $modificationName = $residueRef->{modificationName} || '?';
    my $modificationMass = $residueRef->{modificationMass} || 0;
    my $modificationTotalMass = $residueRef->{totalMass} || 0;

    $modificationMass = sprintf("%.4f",$modificationMass) if ($modificationMass);
      $modificationTotalMass = sprintf("%.4f",$modificationTotalMass) if ($modificationTotalMass);

    $buffer .= sprintf("  %2i %6s %15s %10s %15s %10s %10s\n",$i,$aminoAcid,$nativeString,$modificationAccession,$modificationName,$modificationMass,$modificationTotalMass);
  }

  return $buffer;
}


###############################################################################
# createFormattedStrings
###############################################################################
sub createFormattedStrings {
  my $METHOD = 'createFormattedStrings';
  print "DEBUG: Entering $METHOD\n" if ($DEBUG);
  my $self = shift || die ("self not passed");
  my %args = @_;

  my $verbose = $args{verbose};
  $VERBOSE = $verbose if ($verbose);

  #### Create empty strings for the various formats
  my $sequenceString = '';
  my $lcModSequenceString = '';
  my $modifiedSequenceString = '';
  my $modifiedTPP4SequenceString = '';
  my $modificationsString = '';
  my $deltaMassSequenceString = '';

  #### Loop over each residue, building the variously formatted strings
  my $length = $self->{length};
  for (my $i=0; $i<=$length; $i++) {
    my $residueRef = $self->{decodedSequenceArray}->[$i];
    my $aminoAcid = $residueRef->{aminoAcid} || '';
    my $nativeString = $residueRef->{nativeString} || '';
    my $modificationAccession = $residueRef->{modificationAccession} || '';
    my $modificationName = $residueRef->{modificationName} || '';
    my $modificationMass = $residueRef->{modificationMass} || 0;
    my $modificationTotalMass = $residueRef->{totalMass} || 0;
    my $modificationMassString = $modificationMass;
    $modificationMassString = "+$modificationMassString" if ( $modificationMass > 0 );

    my $modificationIntegerMass = int($modificationMass + 0.5);
    my $modificationTotalIntegerMass = int($modificationTotalMass + 0.5);

    #### If this is the zero n-terminal position, special handling is needed
    if ( $i == 0 ) {
      if ( $modificationName ) {
        $modifiedSequenceString .= "[$modificationName]-";
        $modifiedTPP4SequenceString .= "n\[$modificationTotalIntegerMass\]";
        $modificationsString .= "$i,n-term,$modificationName;";
        $deltaMassSequenceString .= "\[$modificationMassString\]-";
      } else {
      }
    #### All other positions
    } else {
      $sequenceString .= $aminoAcid;
      if ( $modificationName ) {
        $lcModSequenceString .= lc($aminoAcid);
        $modifiedSequenceString .= "$aminoAcid\[$modificationName\]";
        $modifiedTPP4SequenceString .= "$aminoAcid\[$modificationTotalIntegerMass\]";
        $modificationsString .= "$i,$aminoAcid,$modificationName;";
        $deltaMassSequenceString .= "$aminoAcid\[$modificationMassString\]";
      } else {
        $lcModSequenceString .= $aminoAcid;
        $modifiedSequenceString .= $aminoAcid;
        $modifiedTPP4SequenceString .= $aminoAcid;
        $deltaMassSequenceString .= $aminoAcid;
      }
    }
  }

  #### Chop extra delimiters if necessary
  chop($modificationsString) if ($modificationsString);

  #### Store the resulting strings in object attributes
  $self->{sequenceString} = $sequenceString;
  $self->{modifiedSequenceString} = $modifiedSequenceString;
  $self->{modifiedTPP4SequenceString} = $modifiedTPP4SequenceString;
  $self->{lcModSequenceString} = $lcModSequenceString;
  $self->{modificationsString} = $modificationsString;
  $self->{deltaMassSequenceString} = $deltaMassSequenceString;

  return;
}

sub getDeltaNotionAttributes {
  my $METHOD = 'getDeltaNotionAttributes';
  print "DEBUG: Entering $METHOD\n" if ($DEBUG);
  my $self = shift || die ("self not passed");
  my $residue = shift; 
  my $modification_name = shift;
  my %attributes;

  $attributes{accession} = '';
	$attributes{monoisotopicMass} = $modification_name; 
	$attributes{averageMass} = '';
	$attributes{sites} = '';

	my $masses = $cv->getAminoAcidMasses();
	my $residueMass = $masses->{$residue} || 0;
	my $totalMass = $residueMass + $attributes{monoisotopicMass}; 
	my $intTotalMass = int($totalMass + 0.5);
	$attributes{totalMass} = $totalMass;
	$attributes{modFormatTPP4} = "$residue\[$intTotalMass\]";
	$attributes{modificationName} = $modification_name;
  $attributes{name} = $modification_name;
  return \%attributes;
}
###############################################################################
1;
