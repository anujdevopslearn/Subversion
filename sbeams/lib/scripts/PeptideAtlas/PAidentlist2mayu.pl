#!/usr/bin/perl  -w
# PAidentlist2mayu.pl
# Convert PAidentlist file to Mayu input format,
#  using adjusted probabilities (not initial probabilities),
#  and, if desired, grabbing protein identifications from ProteinProphet.
# If PAidentlist was created with "regularized" protein IDs, then
#  grabbing protein IDs from ProtPro here is redundant, tho harmless.
# Terry Farrah, Institute for Systems Biology   January, 2009

use strict;
use Getopt::Long;

my %options;
GetOptions( \%options, 'identlist_file=s', 'output_file=s', 'unmapped_preserve',
                       'help|?', 'protXML_file=s', 'verbose|s',
          );
printUsage() if $options{help};

my $verbose = $options{verbose};

my $identlist_filehandle;
my $identlist_file = $options{identlist_file};
if ($identlist_file) {
  $identlist_filehandle = *IDENTLIST;
  open ($identlist_filehandle, $identlist_file);
} else {
  $identlist_filehandle = *STDIN;
}

my $output_filehandle;
my $output_file = $options{output_file};
if ($output_file) {
  $output_filehandle = *OUTFILE;
  open ($output_filehandle, ">".$output_file);
} else {
  $output_filehandle = *STDOUT;
}

my $protXML_file = $options{protXML_file};
if ($protXML_file) {
  open (PROTXMLFILE, $protXML_file) ||
  die("ProtXML file $protXML_file does not exist or can't be opened for reading.");
} else {
  print STDERR
    "INFO: ProtXML file not provided; using protein IDs from PAidentlist.\n"
    if $verbose;
}

### Read protXML file.
### Assumptions: Each <protein_group> tag incudes multiple
### <protein> tags, in descending order of probability (except that
### proteins of probability zero are mixed in).
### Each <protein> tag includes multiple <peptide>
###  tags, and peptide sets for proteins within the same
###  <protein_group> are overlapping.
### Each peptide belongs to proteins in only one protein_group.
### Assign each peptide to the highest probability protein
###  among those including that peptide.
### Store protein for each peptide in a hash.


my %pepProtHash = (); #stores best protein for peptide seen so far
my %pepProtProbHash = (); #stores prob for that protein
my %pepGroupProbHash = (); #stores protein group prob for that protein
my $peptide;
my %globalPepProtHash = ();
my %globalPepProtProbHash = ();
my %globalPepGroupProbHash = ();
my $line;
my $protein_name;
my $protein_prob;
my $prev_protein_prob;
my $groupNumber;
my $groupProbability;
my $skip_this_protein;
my $firstgroup = 1;


if ($protXML_file) {
  while (<PROTXMLFILE>) {
    $line = $_;
    if ( $line =~ /\<protein_group group_number="(\d*)".+probability="([\d\.]+)"/ ) {
      $groupNumber = $1;
      $groupProbability = $2;
      #print STDERR "Entering protein group $groupNumber.\n" if $verbose;
      undef $prev_protein_prob;
      #process previous protein group by storing info in global hash
      if (!$firstgroup) {
        my @key_list = keys %pepProtHash;
        my $nkeys = @key_list;
        #print STDERR "Completed pepProtHash has $nkeys keys.\n" if $verbose;
        foreach $peptide (keys %pepProtHash) {
          if ( defined $globalPepProtHash{$peptide}  ) {
            print STDERR "Peptide $peptide of group $groupNumber".
                  " already seen in previous protein group.\n" if $verbose;
          } else {
            #print STDERR "Storing $peptide in global hash.\n" if $verbose;
            $globalPepProtHash{$peptide} = $pepProtHash{$peptide};
            $globalPepProtProbHash{$peptide} = $pepProtProbHash{$peptide};
            $globalPepGroupProbHash{$peptide} = $pepGroupProbHash{$peptide};
          }
        }
      }
      $firstgroup = 0;
      #@protein_group_list = ();
      %pepProtHash = ();
      %pepProtProbHash = ();
      %pepGroupProbHash = ();
    }
    if ( $line =~ /\<protein protein_name=\"(.*?)\".*probability=\"(.*?)\"/ ) {
      $protein_name = $1;
      # prob = 0.0 means we do not need this protein to explain the peptides.
      $skip_this_protein = ($2 < 0.00001);
      if (!$skip_this_protein) {
        $prev_protein_prob = $protein_prob;
        $protein_prob = $2;
        #print STDERR "$protein_name is prob $protein_prob\n" if $verbose;
        # note where <protein> are not in descending order of probability
        #  (not a problem, though; does not affect results)
        if ( 0 && $verbose && defined $prev_protein_prob &&
           $protein_prob > $prev_protein_prob) {
             print STDERR "Protein group $groupNumber: Protein of prob ".
               "$prev_protein_prob followed by protein of prob $protein_prob.\n";
        }
      }
    }
    if ( !$skip_this_protein &&  $line =~ /\<peptide peptide_sequence=\"(.*?)\"/) {
      $peptide = $1;
      if (!defined $pepProtProbHash{$peptide} || $protein_prob > $pepProtProbHash{$peptide}) {
        #print STDERR "Storing this protein & prob in the hash for $peptide.\n" if $verbose;
        $pepProtHash{$peptide} = $protein_name;
        $pepProtProbHash{$peptide} = $protein_prob;
        $pepGroupProbHash{$peptide} = $groupProbability;
        my @key_list = keys %pepProtHash;
        my $nkeys = @key_list;
        #print STDERR "pepProtHash now has $nkeys keys.\n" if $verbose;
      }
    }
  }
  #process last protein group
  foreach $peptide (keys %pepProtHash) {
    if ( defined $globalPepProtHash{$peptide}  ) {
      print STDERR "WARNING: Peptide $peptide of group $groupNumber".
            " already seen in another protein group!\n" if $verbose;
    } else {
      $globalPepProtHash{$peptide} = $pepProtHash{$peptide};
      $globalPepProtProbHash{$peptide} = $pepProtProbHash{$peptide};
      $globalPepGroupProbHash{$peptide} = $pepGroupProbHash{$peptide};
    }
  }
  my @k = keys %globalPepProtHash;
  my $nk = @k;
  print STDERR
     "Hash constructed; $groupNumber protein groups, $nk peptide keys.\n"
         if $verbose;
}


sub getmods{
  my %args = @_;
  my $modseq = $args{'modseq'};
  my $inmod = 0;
  my $modmass = "";
  my $pos = 1;
  my $modpos;
  my $mods = "";
  my @chars = split '', $modseq;
  foreach my $char (@chars) {
    if ($char eq "[") {
      $inmod = 1;
      $modpos = $pos-1;
    }
    elsif ($char eq "]") {
      #print $modpos, " ", $modmass, "\n";
      $mods = $mods . sprintf("%d=%d:", $modpos, $modmass);
      #print $mods, "\n";
      $modmass = "";
      $inmod = 0;
    }
    elsif ($inmod) {  # we're inside a pair of square brackets
      $modmass = $modmass . $char;
    }
    else {   # char is an amino acid
      $pos++;
    }
  }
  # remove final colon
  #print $modseq;
  if ($mods ne "") { chop($mods); }
  #print " final mods = ", $mods, "\n";
  return ($mods);
}

my $protXML_proteinID;
my @peps_not_found_in_hash = ();
my @peps_with_changed_ids = ();
my @peps_with_low_prob_protein_ids = ();

print STDERR
   "PAidentlist being processed: one dot per 10,000 lines.\n"
       if $verbose;

my $nlines = 0;
my $n_unmapped = 0;
while (my $line = <$identlist_filehandle>) {
  $nlines++;
  if ($verbose &&  (($nlines % 100000) == 0)) {
    print STDERR "$nlines";
  } elsif ($verbose &&  (($nlines % 10000) == 0)) {
    print STDERR ".";
  }
  chomp($line);
  # parse input line into fields
  my ($a, $scan, $b, $peptide, $c, $modseq, $d, $e,
         $probability, $f, $proteinID, $adj_prob, $g, $h) =
    split(/\s+/,$line);
  # if protXML file was given,
  # look up peptide in hash to get possibly different proteinID
  if ( $protXML_file ) {
    if ( $globalPepProtHash{$peptide} ) {
      # get the proteinID from the protXML
      $protXML_proteinID = $globalPepProtHash{$peptide};
      # if this protein is of prob < 0.9 and its group is also of
      # prob < 0.9, report it
      if ($verbose && $globalPepProtProbHash{$peptide} < 0.90 &&
           $globalPepGroupProbHash{$peptide} < 0.90 ) {
        if( ! (grep /^$peptide$/, @peps_with_low_prob_protein_ids) ) {
          push (@peps_with_low_prob_protein_ids, $peptide);
          print STDERR
            "WARNING: Peptide $peptide assigned to protein $protXML_proteinID ".
            "of low prob $globalPepProtProbHash{$peptide};\n   and low group prob ".
            "of $globalPepGroupProbHash{$peptide}\n";
        }
      }
      # if this protein is different from that in the PAidentlist, remember it
      if( ($proteinID ne $protXML_proteinID) &&
           ! (grep /^$peptide$/, @peps_with_changed_ids) ) {
        push (@peps_with_changed_ids, $peptide);
      }
      # finally, assign to variable for printing later
      $proteinID = $protXML_proteinID;
    } else {
      if (! (grep /^$peptide$/, @peps_not_found_in_hash) ) {
        push (@peps_not_found_in_hash, $peptide);
      }
    }
  }

  # skip PSMs mapped to protIDs that are UNMAPPED. These were hits to the
  # search database, but do not map to anything in the database that the pepXML
  # was refreshed to. They are probably bogus hits.
  if ( ( ! $options{unmapped_preserve}) &&
       ( $proteinID !~ /DECOY_/ ) && ( $proteinID =~ /UNMAPPED/) ) {
    $n_unmapped++;
    next;
  }

  # construct Mayu modification field from modified peptide string
  #  (all other fields are direct copies from input)
  my $mods = getmods(modseq => $modseq);
  # output line
  #if (defined $adj_prob) {
    printf($output_filehandle "%s,%s,%s,%s,%s\n",
         $scan, $peptide, $proteinID, $mods, $probability);
  #}
}

if ($verbose && $n_unmapped) {
  print STDERR "\n$n_unmapped UNMAPPED PSMs ignored.\n";
}

#Print list of peptides in PAidentlist that were not found in protXML
if ($verbose && @peps_not_found_in_hash) {
  my $npeps = @peps_not_found_in_hash;
  print STDERR "WARNING: $npeps peptides in PAidentlist not found in ".
      "protXML file $protXML_file:\n";
  foreach $peptide (@peps_not_found_in_hash) {
    print STDERR "$peptide\n";
  }
}

# Print list of peptides whose protein identifications were different
# in protXML than in PAidentlist
if ($verbose && @peps_with_changed_ids) {
  my $npeps = @peps_with_changed_ids;
  print STDERR "$npeps peptides received a different protein ID".
      " from $protXML_file than what it originally had in PAidentlist.\n";
}


sub printUsage {
  print( <<"  END" );

Usage:  $0 

  -h, --help             Print this usage information and exit
  -i, --identlist_file   PAidentlist file to convert (default: STDIN)
  -o, --output_file      Mayu input format file (default: STDOUT)
  -u, --unmapped_preserve  Count PSMs that map to a protID =~ /UNMAPPED/
  -p, --protXML_file     protXML file corresponding to the PAidentlist file.
                         Used to regularize protein IDs so that protein
                         count is not inflated.
                         (default: use IDs in PAidentlist file)
  -v, --verbose          Print details about execution.
 
  END
  exit;
}
