#!/usr/local/bin/perl -w
# (won't work on regis)
# Look up each of a list of proteins in a particular atlas build.
#  Return one line per protein. Report if protein identifier is
#  unknown.

use strict;
use Getopt::Long;
use vars qw ($USAGE %OPTIONS);
$| = 1;  #disable output buffering

my $USAGE = <<EOU;
USAGE: $0 [OPTIONS]
 Looks up each identifier in prot_list_file in specified Atlas.
 Prints all equivalent primary identifiers for which
 there are one or more peptides in the atlas.
 First tries Search, then GetProteins.
 Reports UNKNOWN if not found anywhere.

Options:
  --prot_list_file           File containing protein identifiers, one per line
                              or multiple per line separated by comma or semicolon.
                              Each line should represent one protein.
  --atlas_build_id           ID number for Atlas to search 

e.g.: $0 --prot_list_file Anderson_protids.list --atlas_build_id 162

EOU

# If no parameters are given, print usage information
unless ($ARGV[0]) {
  print "$USAGE";
  exit;
}

# Process options
unless (GetOptions(\%OPTIONS,"prot_list_file:s", "atlas_build_id:s",
  )) {
  print "$USAGE";
  exit;
}

my $prot_list_file = $OPTIONS{prot_list_file} || 
  die "Must specify prot_list_file.\n";
my $atlas_build_id = $OPTIONS{atlas_build_id} ||
  die "Must specify atlas_build_id.\n";

open (PROTLIST, $prot_list_file);


print "prot_id\tsearch_key\thit\tequiv_ids\tn_obs\n";

while (my $protid_string = <PROTLIST>) {
  my $search_key="";
  chomp ($protid_string);
  $protid_string =~ s/\s+$//; #remove trailing spaces
  my @protids = split(/[;,]/, $protid_string);
  #for my $p (@protids) { print "$p\n"; }
  my @search_output;
  for my $protid (@protids) {
    # if protid_string is from Swiss-Prot and is not a 2nd, 3rd, etc. splice
    # variant, match either P12345 or P12345-1.
    if ($protid =~ /^[ABOPQ].....$/) {
      $search_key = "$search_key;$protid;$protid-1";
    } elsif ($protid =~ /(^[ABOPQ].....)-1$/) {
      $search_key = "$search_key;$1;$protid";
    }
    # if protid_string is IPI with version extension, look for identifier
    # without version
    if ($protid =~ /(IPI........)\.\d+/) {
      $search_key = "$search_key;$1";
    } else {
      $search_key = "$search_key;$protid";
    }
  }
  # remove leading semicolon from $search_key
  $search_key =~ s/^;//;

  my $cmd = "$ENV{'SBEAMS'}/cgi/PeptideAtlas/Search " .
	    "action=GO " .
	    "output_mode=tsv " .
	    "search_key=\"$search_key\" " .
	    "atlas_build_id=\"$atlas_build_id\"";

  @search_output = `$cmd`;

  my $output_line = process_search_output(\@search_output, $protid_string,
                                            $search_key);

  print $output_line;
}

sub process_search_output {
  my $search_output_href = shift;
  my @search_output = @{$search_output_href};
  my $query_protid = shift;
  my $search_key = shift;
  my $output_line;
  my %protids;  # if $query_protid has wildcard, may match multiple protids.
  my %equiv_ids;

  if ($search_output[0] =~ /There were no matches/) {
    $output_line = "$query_protid\t$search_key\tUNKNOWN\t\n";
    # try looking in biosequence set
    if ($atlas_build_id ne '') {
      my $cmd = "$ENV{'SBEAMS'}/cgi/PeptideAtlas/GetProteins ".
              "action=QUERY " .
	      "output_mode=tsv " .
	      "biosequence_name_constraint=\"\%$search_key\%\" " .
              "atlas_build_id=\"$atlas_build_id\"";
      my @search_output = `$cmd`;
      #for my $line (@search_output) { print $line; }
      if ($#search_output > 0) {
        print $search_output[0];
        # choose one line from multi-line output
        my $selected_search_output = select_search_output(\@search_output);
	my @fields = split("\t",$selected_search_output);
        my $protid = $fields[0];
        my $n_obs = $fields[3];
        my $equiv_id_string = $fields[7] || "";
	$output_line = "$query_protid\t$search_key\t$protid\t".
                       "$equiv_id_string\t$n_obs\n";
      }
    }
  } else {
    %equiv_ids = ();
    %protids = ();
    my $n_obs = "";
    for (my $i = 1; $i <= $#search_output; $i++) {
      my $line = $search_output[$i];
      chomp $line;
      my @fields = split("\t", $line);
      if ($#fields < 3) {  #no peptides
        next;
      }
      my $protid = $fields[0];
      $protids{$protid} = 1;
      my $equiv_id = $fields[2];
      $equiv_ids{$equiv_id} = 1;
      $n_obs = $fields[3];
    }
    my $equiv_id_string = join(";", keys(%equiv_ids));
    my $prot_id_string = join(";", keys(%protids));
    $output_line = "$query_protid\t$search_key\t$prot_id_string\t".
                   "$equiv_id_string\t$n_obs\n";
  }
  return $output_line;
}

sub select_search_output {
  my $search_output_aref = shift;
  my @search_output = @{$search_output_aref};
  my $i;
  my $non_decoy_found = 0;
  for ($i=1; $i<=$#search_output; $i++) {
    if ($search_output[$i] !~ /DECOY_/) {
      $non_decoy_found = 1;
      last;
    }
  }
  if (!$non_decoy_found) {
    $i = 1;
  }
  return ($search_output[$i]);
}
