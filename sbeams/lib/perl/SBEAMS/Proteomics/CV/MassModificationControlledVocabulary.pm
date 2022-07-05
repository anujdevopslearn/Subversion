package SBEAMS::Proteomics::CV::MassModificationControlledVocabulary;

###############################################################################
# Class       : Proteomics::CV::MassModificationControlledVocabulary
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
#
# Description : This class is used to parse and access information in a
#               mass modification controlled vocabulary file, in OBO format,
#               such as Unimod or PSI-MOD.
#
###############################################################################

use strict;
use warnings;

my $VERBOSE = 0;

###############################################################################
# Constructor
###############################################################################
sub new {
  my $self = shift;
  my %parameters = @_;

  my $class = ref($self) || $self;

  #### Create the object with any attributes if supplied
  $self = {
    filename => $parameters{filename},
    };

  bless $self => $class;
  return $self;
}


###############################################################################
# setFilename: Set attribute filename
###############################################################################
sub setFilename {
  my $self = shift;
  $self->{filename} = shift;
  return $self->{filename};
}


###############################################################################
# getFilename: Get attribute filename
###############################################################################
sub getFilename {
  my $self = shift;
  return $self->{filename};
}


###############################################################################
# loadMissingNamespace
###############################################################################
sub loadMissingNamespace {
  my $METHOD = 'loadMissingNamespace';
  my $self = shift || die ("self not passed");
  my %args = @_;

  my $accession = $args{accession} || '';
  my $namespace = $args{namespace} || '';

  my $verbose = $args{verbose};
  $VERBOSE = $verbose if ($verbose);

  #### If no term was provided, then I don't know what to do
  unless ( $accession  || $namespace ) {
    die("ERROR: No namespace or accession provided. Don't know what to load");
  }

  #### If no namespace was provided, then try to extract from the term
  unless ( $namespace ) {
    if ( $accession =~ /^(.+):(\d+)/ ) {
      $namespace = $1;
      print "INFO: Extracted namespace '$namespace' from accession '$accession'\n" if ($verbose);
    } else {
      die("ERROR: Cannot parse term '$accession' to extract namespace");
    }
  }

  #### Return if this namespace was already loaded
  unless ( exists($self->{loadedNamespaces}) ) {
    my %tmp = ();
    $self->{loadedNamespaces} = \%tmp;
  }
  if ( exists($self->{loadedNamespaces}->{$namespace}) ) {
    return;
  }

  #### Define the namespaces that we know
  my %namespaces = (
    'MS' => '/net/dblocal/wwwspecial/proteomecentral/extern/PSI-MS/controlledVocabulary/psi-ms.obo',
    'PRIDE' => '/net/dblocal/wwwspecial/proteomecentral/extern/PRIDE/schema/pride_cv.obo',
    'UNIMOD' => "/net/dblocal/wwwspecial/proteomecentral/extern/CVs/unimod.obo",
    'MOD' => "/net/dblocal/wwwspecial/proteomecentral/extern/CVs/PSI-MOD.obo",
    'CELL' => '/net/dblocal/wwwspecial/proteomecentral/extern/CELL/ontology/cl.obo',
    'BRENDA' => '/net/dblocal/wwwspecial/proteomecentral/extern/BRENDA/BrendaTissueOBO',
    'DOID' => '/net/dblocal/wwwspecial/proteomecentral/extern/DOID/doid.obo',
  );

  if ( $namespaces{$namespace} ) {
    $self->readFile( filename=>$namespaces{$namespace} );
    if ( $self->{status} eq 'OK' && $namespace eq 'UNIMOD' ) {
      $self->generateReverseLookups();
    }
  }

  return;
}


###############################################################################
# checkCvParam
###############################################################################
sub checkCvParam {
  my $METHOD = 'checkCvParam';
  my $self = shift || die ("self not passed");
  my %args = @_;

  my $paramAccession = $args{paramAccession};
  my $paramName = $args{paramName};
  my $paramValue = $args{paramValue};
  my $paramCvRef = $args{paramCvRef};

  my $verbose = $args{verbose};
  $verbose = $VERBOSE if ($VERBOSE);

  my $accession = $paramAccession;
  my $name = $paramName;
  my $value = $paramValue;

  print "INFO: Checking cvParam '$paramAccession' = '$paramName'\n" if ($verbose);

  if ($accession =~ /\s/) {
    $self->addCvError(errorMessage=>"WARNING: term '$accession' has whitespace in it. This is not good.");
    $accession =~ s/\s//g;
  }

  unless ($name) {
    $self->addCvError(errorMessage=>"WARNING: term '$accession' does not have a corresponding name specified.");
  }

  #### If this term is not present, try to load the namespace
  unless ($self->{terms}->{$accession}) {
    $self->loadMissingNamespace( accession => $accession );
  }

  if ($self->{terms}->{$accession}) {
    if ($self->{terms}->{$accession}->{name} eq $name) {
      print "INFO: $accession = $name matches CV\n" if ($verbose);
      $self->{validationStats}->{n_valid_terms}++;
    } elsif ($self->{terms}->{$accession}->{synonyms}->{$name}) {
      print "INFO: $accession = $name matches CV\n" if ($verbose);
      $self->{validationStats}->{n_valid_terms}++;
    } else {
      $self->addCvError(errorMessage=>"WARNING: $accession should be '$self->{terms}->{$accession}->{name}' instead of '$name'");
      $self->{validationStats}->{mislabeled_terms}++;
      #print "replaceall.pl \"$name\" \"$self->{terms}->{$accession}->{name}\" \$file\n";
    }

    #### Assess the correct presence of a value attribute
    my $shouldHaveValue = 0;
    my $hasValue = 0;
    if ($self->{terms}->{$accession}->{datatypes}) {
      $shouldHaveValue = 1;
    }
    if (defined($value) && $value ne '') {
      $hasValue = 1;
    }
    if ($shouldHaveValue && $hasValue) {
      $self->{validationStats}->{correctly_has_value}++
    } elsif ($shouldHaveValue && ! $hasValue) {
      $self->addCvError(errorMessage=>"ERROR: cvParam $accession ('$name') should have a value, but it does not!");
      $self->{validationStats}->{is_missing_value}++
    } elsif (! $shouldHaveValue && $hasValue) {
      $self->addCvError(errorMessage=>"ERROR: cvParam $accession ('$name') has a value, but it should not!");
      $self->{validationStats}->{incorrectly_has_value}++
    } else {
      $self->{validationStats}->{correctly_has_no_value}++
    }

  } else {
    #### Exceptions
    if ($paramCvRef eq 'NEWT') {
      #### Skip for now
    } else {
      $self->addCvError(errorMessage=>"WARNING: CV term $accession ('$name') is not in the cv");
      $self->{validationStats}->{unrecognized_terms}++;
    }
  }

}


###############################################################################
# getTerm
###############################################################################
sub getTerm {
  my $METHOD = 'getTerm';
  my $self = shift || die ("self not passed");
  my %args = @_;

  my $accession = $args{accession};
  my $name = $args{name};

  my $verbose = $args{verbose};
  $verbose = $VERBOSE if ($VERBOSE);

  if ($verbose) {
    print "INFO: Looking for '$name'\n" if ($name);
    print "INFO: Looking for '$accession'\n" if ($accession);
  }

  if ($accession && $accession =~ /\s/) {
    $self->addCvError(errorMessage=>"WARNING: term '$accession' has whitespace in it. This is not good.");
    $accession =~ s/\s//g;
  }

  if ($name && ($name =~ /^\s/ || $name =~ /\s$/)) {
    $self->addCvError(errorMessage=>"WARNING: term '$name' has leading or trailing whitespace. This is not good.");
    $name =~ s/^\s+//;
    $name =~ s/\s+$//;
  }

  #### If this term is not present, try to load the namespace
  if ($accession) {
    unless ($self->{terms}->{$accession}) {
      $self->loadMissingNamespace( accession => $accession );
    }
  }

  my $foundTerm;

  #### If an accession was supplied, look for it
  if ( $accession ) {
    if ( $self->{terms}->{$accession} ) {
      $foundTerm = 1;
    }
  }

  #### If name was supplied, look for it as a primary name or as a synonym
  if ( $name ) {

    #### Make sure that the CVs are loaded
    unless ($self->{terms}->{'UNIMOD:1'}) {
      $self->loadMissingNamespace( accession => 'UNIMOD:1' );
    }
    unless ($self->{terms}->{'MOD:00001'}) {
      $self->loadMissingNamespace( accession => 'MOD:00001' );
    }

    if ( $self->{names}->{$name} ) {
      $foundTerm = 1;
      my $accessions = $self->{names}->{$name}->{accessions};
      if ( $accessions ) {
         my @accessions = keys(%{$accessions});
         if (scalar(@accessions) == 1) {
           $accession = $accessions[0];
         } else {
           $accession = $accessions[0];
           $self->addCvError(errorMessage=>"WARNING: Multiple accessions for term name '$name'. Will use the first for now '$accession'");
         }
      }
    } elsif ( $self->{synonyms}->{$name} ) {
      $foundTerm = 1;
      my $accessions = $self->{synonyms}->{$name}->{accessions};
      if ( $accessions ) {
         my @accessions = keys(%{$accessions});
         if (scalar(@accessions) == 1) {
           $accession = $accessions[0];
         } else {
           $accession = $accessions[0];
           $self->addCvError(errorMessage=>"WARNING: Multiple accessions for the synonym '$name'. Will use the first for now '$accession'");
         }
      }
    } elsif ( $self->{caseInsensitive}->{uc($name)} ) {
      $foundTerm = 1;
      my $accessions = $self->{caseInsensitive}->{uc($name)}->{accessions};
      if ( $accessions ) {
         my @accessions = keys(%{$accessions});
         if (scalar(@accessions) == 1) {
           $accession = $accessions[0];
         } else {
           $accession = $accessions[0];
           $self->addCvError(errorMessage=>"WARNING: Multiple accessions for the case insensitive search for '$name'. Will use the first for now '$accession'");
         }
      }
    }

  }

  #### If we found a term, return its accession, or fall through to undef
  if ( $foundTerm ) {
    return $accession;
  }

  return;
}


###############################################################################
# showTerm
###############################################################################
sub showTerm {
  my $METHOD = 'showTerm';
  my $self = shift || die ("self not passed");
  my %args = @_;

  my $accession = $args{accession};

  my $verbose = $args{verbose};
  $verbose = $VERBOSE if ($VERBOSE);

  unless ( $accession ) {
    print "ERROR: no term accession supplied to showTerm()\n";
    return;
  }

  print "INFO: Showing accession '$accession'\n" if ($verbose);

  #### If this term is not present, return and error
  unless ($self->{terms}->{$accession}) {
    print "ERROR: Term with accession '$accession' not found\n";
    return;
  }

  my $buffer = '';

  $buffer .= "Accession: $accession\n";
  $buffer .= "Name: $self->{terms}->{$accession}->{name}\n";
  $buffer .= "Monoisotopic mass: $self->{terms}->{$accession}->{monoisotopicMass}\n";

  if ( $self->{terms}->{$accession}->{synonyms} ) {
    my @synonyms = keys(%{$self->{terms}->{$accession}->{synonyms}});
    $buffer .= "Synonyms: ".join(",",@synonyms)."\n";
  }

  if ( $self->{terms}->{$accession}->{sites} ) {
    my @sites = keys(%{$self->{terms}->{$accession}->{sites}});
    $buffer .= "Sites: ".join(",",@sites)."\n";
  }

  return $buffer;
}


###############################################################################
# getAttributes
###############################################################################
sub getAttributes {
  my $METHOD = 'getAttributes';
  my $self = shift || die ("self not passed");
  my %args = @_;

  my $accession = $args{accession};
  my $residue = $args{residue};

  my $verbose = $args{verbose};
  $verbose = $VERBOSE if ($VERBOSE);

  unless ( $accession ) {
    print "ERROR: no term accession supplied to $METHOD\n";
    return;
  }

  print "INFO: Getting attributes for accession '$accession'\n" if ($verbose);

  #### If this term is not present, return and error
  unless ($self->{terms}->{$accession}) {
    print "ERROR: Term with accession '$accession' not found\n";
    return;
  }

  #### Create a hash to fill
  my %attributes;
  $attributes{accession} = $accession;
  $attributes{name} = $self->{terms}->{$accession}->{name};
  $attributes{monoisotopicMass} = $self->{terms}->{$accession}->{monoisotopicMass};
  $attributes{averageMass} = $self->{terms}->{$accession}->{averageMass};

  $attributes{sites} = $self->{terms}->{$accession}->{sites};
  $attributes{synonyms} = $self->{terms}->{$accession}->{synonyms};
  

  #### Create a mod string in different formats
  if ( $residue ) {
    #print "**residue=$residue  -> ";
    $residue = 'n' if ( $residue eq 'N-term' );
    $residue = 'c' if ( $residue eq 'C-term' );
    #print "residue=$residue\n";
    my $masses = $self->getAminoAcidMasses();
    my $residueMass = $masses->{$residue} || 0;
    my $totalMass = $residueMass + $attributes{monoisotopicMass};
    #my $totalMass = $residueMass + $attributes{averageMass};
    my $intTotalMass = int($totalMass + 0.5);
    #print "      = $residueMass, $totalMass, $intTotalMass\n";
    $attributes{totalMass} = $totalMass;
    $attributes{modFormatTPP4} = "$residue\[$intTotalMass\]";
  }
  return \%attributes;
}


###############################################################################
# addCvError
###############################################################################
sub addCvError {
  my $METHOD = 'addCvError';
  my $self = shift || die ("self not passed");
  my %args = @_;

  my $errorMessage = $args{errorMessage} || 'INTERNAL ERROR: No CV error message provided';

  #### Check to see if this error is already in the error hash
  if ($self->{errorHash} && $self->{errorHash}->{$errorMessage}) {
    # It exists already, nothing to do

  #### Otherwise, push the error onto the list
  } else {
    push(@{$self->{errorList}},$errorMessage);
  }

  #### Create or increment the counter for this kind of message
  $self->{errorHash}->{$errorMessage}->{count}++;

  print "$errorMessage\n" if ($VERBOSE);

  return;
}


###############################################################################
# readFile
###############################################################################
sub readFile {
  my $METHOD = 'readFile';
  my $self = shift || die ("self not passed");
  my %args = @_;

  my $filename = $args{filename} || $self->{filename} || 'psi-ms.obo';

  my $verbose = $args{verbose};
  $VERBOSE = $verbose if ($verbose);

  $self->{status} = 'ERROR';
  $self->{message} = 'CV Error 611';

  #### Check to see if file exists
  unless (-e $filename) {
    my $message = "ERROR: controlled vocabulary file '$filename' does not exist";
    $self->{message} = $message;
    print "$message\n";
    return $self->{status};
  }

  #### Open file
  unless (open(INFILE,$filename)) {
    my $message = "ERROR: Unable to open for reading controlled vocabulary file '$filename'";
    $self->{message} = $message;
    print "$message\n";
    return $self->{status};
  }

  print "INFO: Reading cv file '$filename'\n" if ($VERBOSE);

  #### Read in file
  #### Very simple reader with minimal sanity/error checking
  my ($line,$id,$name,$synonym);
  my %sites =();

  while ($line = <INFILE>) {

    #### Strip out any possible line endings
    $line =~ s/[\r\n]//g;

    #### Parse the id field
    if ($line =~ /^id:\s*(\S+)\s*/) {
      $id = $1;
    }

    #### Parse the name field and store the results in the current id
    if ($line =~ /^name:\s*(.+)\s*$/) {
      $name = $1;
      $self->{terms}->{$id}->{name} = $name;
      $self->{names}->{$name}->{accessions}->{$id} = 1;
      $self->{caseInsensitive}->{uc($name)}->{accessions}->{$id} = 1;
    }

    #### Parse the def field and under some circumstances, add it as a synonym
    if ($line =~ /^def:\s*\"(.+)\"\s*\[.+\]\s*$/) {
      my $def = $1;
      $def =~ s/\.$//;
      my @synonyms = ();
      if ( $def =~ /^\S+$/ ) {
        push(@synonyms,$def);
      } elsif ( $def =~ /^(\S+) or (\S+)$/ ) {
        push(@synonyms,$1,$2);
      }
      foreach my $synonym ( @synonyms ) {
        next if ( $name eq $synonym );
        next if ( $self->{synonyms}->{$synonym} );
        $self->{terms}->{$id}->{synonyms}->{$synonym} = $synonym;
        $self->{synonyms}->{$synonym}->{accessions}->{$id} = 1;
          $self->{caseInsensitive}->{uc($synonym)}->{accessions}->{$id} = 1;
      }
    }

    #### Parse the exact_synonym field and store the results in the current id
    if ($line =~ /^exact_synonym:\s*\"(.+)\"\s*[\[\]]*\s*$/) {
      $synonym = $1;
      $self->{terms}->{$id}->{synonyms}->{$synonym} = $synonym;
      $self->{synonyms}->{$synonym}->{accessions}->{$id} = 1;
      $self->{caseInsensitive}->{uc($synonym)}->{accessions}->{$id} = 1;
    }

    #### Parse the synonym field and store the results in the current id
    if ($line =~ /^synonym:\s*\"(.+)\"\s*[\[\]]*\s*$/) {
      $synonym = $1;
      $self->{terms}->{$id}->{synonyms}->{$synonym} = $synonym;
      $self->{synonyms}->{$synonym}->{accessions}->{$id} = 1;
      $self->{caseInsensitive}->{uc($synonym)}->{accessions}->{$id} = 1;
    }

    #### Parse the def field and store the results also as a synomym
    if ($line =~ /^def:\s*\"(.+)\"\s+\[/) {
      my $definition = $1;
      $definition =~ s/\.$//;
      $self->{terms}->{$id}->{synonyms}->{$definition} = $definition;
      $self->{synonyms}->{$definition}->{accessions}->{$id} = 1;
      $self->{caseInsensitive}->{uc($definition)}->{accessions}->{$id} = 1;
    }

    #### Parse the has_units relationship and store the results in the current id
    if ($line =~ /^relationship:\s*has_units\s*(\S+) \! (.+)?\s*$/) {
      my $unit = $1;
      my $unitName = $2;
      $self->{terms}->{$id}->{units}->{$unit} = $unitName;
    }

    #### Parse an xref value-type and store the results in the current id
    if ($line =~ /^xref:\s*value-type:\s*(\S+)\s+\"/) {
      my $datatype = $1;
      $datatype =~ s/\\//g;
      $self->{terms}->{$id}->{datatypes}->{$datatype} = $datatype;
    }

    #### Parse isa relationship and store the results in the current id
    if ($line =~ /^is_a:/) {
      %sites =();
      if ($line =~ /^is_a:\s*(\S+)[\s\!]+/) {
        my $child = $1;
        if ( !defined($self->{terms}->{$id}->{is_a}) ) {
          my @tmp = ();
          $self->{terms}->{$id}->{is_a} = \@tmp;
        }
        push(@{$self->{terms}->{$id}->{is_a}},$child);
      } else {
        print "CV ERROR: Error parsing: $line\n";
      }
    }

    #### Parse an xref delta_mono_mass and store the results in the current id
    if ($line =~ /^xref:\s*delta_mono_mass/) {
      if ($line =~ /^xref:\s*delta_mono_mass\s+\"\s*([\+\-\.\d]+)\s*\"/) {
        $self->{terms}->{$id}->{monoisotopicMass} = $1;
      } else {
        print "CV ERROR: Error parsing: $line\n";
      }
    }

    #### Parse an xref delta_avge_mass and store the results in the current id
    if ($line =~ /^xref:\s*delta_avge_mass/) {
      if ($line =~ /^xref:\s*delta_avge_mass\s+\"\s*([\+\-\.\d]+)\s*\"/) {
        $self->{terms}->{$id}->{averageMass} = $1;
        #print "AverageMass = $1\n";
      } else {
        print "CV ERROR: Error parsing: $line\n";
      }
    }

    #### Parse an xref DiffMono and store the results in the current id
    if ($line =~ /^xref:\s*DiffMono:/) {
      if ($line =~ /^xref:\s*DiffMono:\s+\"\s*([\+\-\.\d]+)\s*\"/) {
        $self->{terms}->{$id}->{monoisotopicMass} = $1;
      } elsif ($line =~ /^xref:\s*DiffMono:\s+\"\s*none\s*\"/) {
        $self->{terms}->{$id}->{monoisotopicMass} = 0;
      } else {
        print "CV ERROR: Error parsing: $line\n";
      }
    }

    #### Parse an xref spec_NN_site and store the results in the current id
    if ($line =~ /^xref:\s+spec_\d+_site/) {
      if ($line =~ /^xref:\s+spec_(\d+)_site\s+\"\s*(.+)\s*\"/) {
        $sites{$1} = $2; 
        $self->{terms}->{$id}->{sites}->{$2} = 1;
      } else {
        print "CV ERROR: Error parsing: $line\n";
      }
    }
    if ($line =~ /^xref:\s+spec_(\d+)_classification\s+"(.*)"/) {
      my $classification = $2;
      my $n = $1;
      if ($classification =~ /AA substitution/i){
        #print "$line $id,$name,$synonym $n $sites{$n}\n"; 
        delete $self->{terms}->{$id}->{sites}->{$sites{$n}};
      }
    } 


    #### Parse an xref Origin and store the results in the current id
    if ($line =~ /^xref:\s+Origin:/) {
      if ($line =~ /^xref:\s+Origin:\s+\"\s*(.+)\s*\"/) {
        my $sites = $1;
        my @sites = split(/,/,$sites);
        foreach my $site ( @sites ) {
          $site =~ s/\s+//g;
          $self->{terms}->{$id}->{sites}->{$site} = 1;
        }
      } else {
        print "CV ERROR: Error parsing: $line\n";
      }
    }

  }

  #### Close and set a good status
  close(INFILE);
  $self->{status} = 'OK';

  return $self->{status};
}


###############################################################################
# getAminoAcidMasses: Get a hash of amino acid masses
###############################################################################
sub getAminoAcidMasses {
  my $self = shift;

  my %masses = qw (
G        57.0214636
A        71.0371136
S        87.0320282
P        97.0527636
V        99.0684136
T       101.0476782
C       103.0091854
L       113.0840636
I       113.0840636
N       114.0429272
D       115.0269428
Q       128.0585772
K       128.0949626
E       129.0425928
M       131.0404854
H       137.0589116
F       147.0684136
R       156.1011106
Y       163.0633282
W       186.0793126
n         1.0078250
  );

  return \%masses;
}

###############################################################################
# getCommonModifications: Get a hash of common modifications to create a reverse-lookup for
###############################################################################
sub getCommonModifications {
  my $self = shift;
  my @commonModifications = qw (
Glu->pyro-glu
Gln->pyro-glu
deoxy
deamidation
methylation
oxidation
formylation
ethylation
S-nitrosylation
hydroxymethyl
persulfide
dioxidation
acetylation
guanidinyl
trimethyl
Gly
carbamylation
trioxidation
carbamidomethyl
carboxymethyl
sulfurdioxide
piperidine
phosphorylation
iTRAQ4plex
iTRAQ8plex
TMT6plex
  );

  return @commonModifications;
}

sub getCommonTranslation { 
  my $self = shift;
  ## 4 digit precision 
  my %common_translation =(
    'K' => {'+28.0313' => 'Dimethyl',
            '+144.1021' => 'iTRAQ4plex',
            '+304.2022' => 'iTRAQ8plex',
           },
    'n' => {'+28.0313' => 'Dimethyl',
            '+144.1021' => 'iTRAQ4plex',
            '+304.2022' => 'iTRAQ8plex',
           },
  );
  return %common_translation;
}

###############################################################################
# generateReverseLookups: Generate a set of reverse lookups, i.e. M[147] to M(oxidation)
###############################################################################
sub generateReverseLookups {
  my $self = shift;
  my $localDebug = 0;

  my %commonModificationsReverseLookup;
  my %massReverseLookup;

  #### Loop through all the common modifications forwards to generate the reverse lookups
  for (my $index = 1; $index < 3000; $index++) {

    my $accession = "UNIMOD:$index";
    print "Resolving accession $accession\n" if ( $localDebug );

    #### If this accession is not available, just move on to the next one
    next unless ($self->{terms}->{$accession});

    my $modificationAttributes = $self->getAttributes( accession => $accession );
    unless ($modificationAttributes) {
      print "ERROR: Unable to find a term for '$accession'. Skipping..\n" if ( $localDebug );
      next;
    }
    my $modificationAccession = $accession;

    #### Get a list of all the sites (i.e. amino acids or termini) where this modification can take place
    my @sites = keys(%{$modificationAttributes->{sites}});
    print "Sites: ".join(",",@sites)."\n" if ( $localDebug );
  
    #### Loop over each site, creating the TPP4 style modification string (e.g. M[147]) and store it in the reverse lookup hash
    foreach my $residue ( @sites ) {
      my $modificationAttributes = $self->getAttributes( accession => $modificationAccession, residue => $residue );
      my $modFormatTPP4 = $modificationAttributes->{modFormatTPP4};
      my $modificationName = $self->{terms}->{$modificationAccession}->{name};
      $residue = 'n' if ( $residue eq 'N-term' );
      $residue = 'c' if ( $residue eq 'C-term' );
      my $modificationString = "$residue($modificationName)";
      print "==$modFormatTPP4==$modificationString==\n" if ( $localDebug );

      #### If there is already a record for this modFormatTPP4, then add to it
      if ( exists($commonModificationsReverseLookup{$modFormatTPP4}) ) {
        push(@{$commonModificationsReverseLookup{$modFormatTPP4}->{array}},$modificationString);
        $commonModificationsReverseLookup{$modFormatTPP4}->{hash}->{$modificationString} = $modificationAccession;

      #### Or else create it
      } else {
        my @array = ( $modificationString );
        my %hash = ( $modificationString => $modificationAccession );
        my %possibilities = ( main => $modificationString, hash=> \%hash, array => \@array );
        $commonModificationsReverseLookup{$modFormatTPP4} = \%possibilities;
      }

      #### Now store my residue and mass

      #### If there is not already an entry for this site massReverseLookup, then create it
      if ( ! exists($massReverseLookup{$residue}) ) {
          my @array = ( );
        $massReverseLookup{$residue} = \@array;
      }

      #### store the modification by mass
      my $deltaMass = $self->{terms}->{$modificationAccession}->{monoisotopicMass};
      my %hash = ( deltaMass => $deltaMass, accession => $modificationAccession );
      push(@{$massReverseLookup{$residue}},\%hash);
      print("Storing deltaMass=$deltaMass for $modificationAccession on $residue\n")  if ( $localDebug );

    }

  }

  #### Save the hash and return
  $self->{commonModificationsReverseLookup} = \%commonModificationsReverseLookup;
  $self->{massReverseLookup} = \%massReverseLookup;
  return;

}


###############################################################################
1;
