#!/usr/local/bin/perl -w
# (won't work on regis)
# Look up each of a list of proteins in a particular atlas build.
#  Return one line per protein. Report if protein identifier is
#  unknown.
#  08/21/09: deprecated. Being replaced by
#  $SBEAMS/cgi/PeptideAtlas/SearchProteins.
#  However, the above is not yet fully functional (does not export
#  properly; not sure it works in command line mode yet)

use strict;
use Getopt::Long;
use vars qw ($USAGE %OPTIONS);
$| = 1;  #disable output buffering

print "Deprecated. Use \$SBEAMS/cgi/PeptideAtlas/SearchProteins.\n";
exit;

my $USAGE = <<EOU;
USAGE: $0 [OPTIONS]
 Looks up each identifier in prot_file in specified Atlas.
 Prints all equivalent primary identifiers for which
 there are one or more peptides in the atlas.
 First tries Search, then GetProteins.
 Reports UNKNOWN if not found anywhere.
 DEPRECATED: use \$SBEAMS/cgi/PeptideAtlas/SearchProteins.

Options:
  --prot_file                File containing protein identifiers, one per line
                              or multiple per line separated by comma or semicolon.
                              Each line should represent one protein.
  --prot_list                Comma separated list of protein identifiers.
  --atlas_build_id           ID number for Atlas to search 
  --html                     Return an HTML table instead of tsv

e.g.: $0 --prot_file Anderson_protids.list --atlas_build_id 162

EOU

# If no parameters are given, print usage information
unless ($ARGV[0]) {
  print "$USAGE";
  exit;
}

# Process options
unless (GetOptions(\%OPTIONS,"prot_file:s","prot_list:s","atlas_build_id:s", "html",
  )) {
  print "$USAGE";
  exit;
}

my $prot_file = $OPTIONS{prot_file};
my $prot_list = $OPTIONS{prot_list};
if ($prot_file && $prot_list) {
  die "Specify only one of  prot_file or prot_list.\n";
} elsif (!$prot_file && !$prot_list) {
  die "Must specify prot_file or prot_list.\n";
}
my @prot_array;
if ($prot_file) {
  open (PROTLIST, $prot_file) || die "Unable to open $prot_file for reading.";
  @prot_array = <PROTLIST>;
} else {
  @prot_array = split(",", $prot_list);
}
  
my $atlas_build_id = $OPTIONS{atlas_build_id} ||
  die "Must specify atlas_build_id.\n";
my $output_html = $OPTIONS{html};
### TMF: temporary kludge!
my $SBEAMS = "$ENV{'SBEAMS'}" || "/net/dblocal/www/html/devTF/sbeams";

look_up_protids_in_atlas_and_print_one_line_each (
  output_html => $output_html,
  prot_array_ref => \@prot_array,
  atlas_build_id => $atlas_build_id,
);

###############################################################################
# look_up_protids_in_atlas_and_print_one_line_each
###############################################################################
sub look_up_protids_in_atlas_and_print_one_line_each {

  my %args = @_;

  my $output_html = $args{'output_html'};
  my $prot_array_ref = $args{'prot_array_ref'};
  my @prot_array = @{$prot_array_ref};
  my $atlas_build_id = $args{'atlas_build_id'};

  my $output_line = "prot_id\tsearch_key\thit\tn_obs\tfound_using\tequiv_ids\n";
  if ($output_html) {
    print "\<table border=1\>\n";
    $output_line =~ s/\t/\<\/td\>\<td\>/g;
    $output_line =~ s/^/\<tr\>\<td\>/;
    $output_line =~ s/$/\<\/td\>\<\/tr\>/;
  }
  print $output_line;

  for my $protid_string (@prot_array) {
    my $search_key="";
    chomp ($protid_string);
    $protid_string =~ s/\s+$//; #remove trailing spaces
    my @protids = split(/[;,]/, $protid_string);
    #for my $p (@protids) { print "$p\n"; }
    for my $protid (@protids) {
      # if protid_string is from Swiss-Prot and is not a 2nd, 3rd, etc. splice
      # variant, match either P12345 or P12345-1.
      if ($protid =~ /^[ABOPQ].....$/) {
	$search_key = "$search_key;$protid;$protid-1";
      } elsif ($protid =~ /(^[ABOPQ].....)-1$/) {
	$search_key = "$search_key;$1;$protid";
      # if protid_string is IPI with version extension, look for identifier
      # without version
      } elsif ($protid =~ /(IPI........)\.\d+/) {
	$search_key = "$search_key;$1";

      } else {
	$search_key = "$search_key;$protid";
      }
    }
    # remove leading semicolon from $search_key
    $search_key =~ s/^;//;

    my $output_line;

    # First, try Search
    my $cmd = "$SBEAMS/cgi/PeptideAtlas/Search " .
	      "action=GO " .
	      "output_mode=tsv " .
	      "search_key=\"$search_key\" " .
	      "atlas_build_id=\"$atlas_build_id\"";

    my @search_output = `$cmd`;

    if ($search_output[0] !~ /There were no matches/) {
      $output_line = process_search_output(\@search_output, $protid_string,
					      $search_key);
      if ($output_html) {
	$output_line =~ s/\t/\<\/td\>\<td\>/g;
	$output_line =~ s/^/\<tr\>\<td\>/;
	$output_line =~ s/$/\<\/td\>\<\/tr\>/;
      }
      print $output_line;
      next;
    }

    # Next, try looking in biosequence set using GetProteins
    $cmd = "$SBEAMS/cgi/PeptideAtlas/GetProteins ".
	    "action=QUERY " .
	    "output_mode=tsv " .
	    "biosequence_name_constraint=\"\%$search_key\%\" " .
	    "atlas_build_id=\"$atlas_build_id\"";
    my @get_proteins_output = `$cmd`;

    my $header_line = 0;
    # in non-command-line mode, GetProteins apparently returns with a 2-line header
    if ($output_html) {
      $header_line = 2;
    }
    if ($#get_proteins_output > $header_line) {
      # choose one line from multi-line output
      my $selected_get_proteins_output =
         select_get_proteins_output(\@get_proteins_output);
      my @fields = split("\t",$selected_get_proteins_output);
      my $protid = $fields[0];
      my $n_obs = $fields[3];
      my $equiv_id_string = $fields[7] || "";
      $output_line = "$protid_string\t$search_key\t$protid\t$n_obs\t".
		     "GetProteins\t$equiv_id_string\n";
      if ($output_html) {
	$output_line =~ s/\t/\<\/td\>\<td\>/g;
	$output_line =~ s/^/\<tr\>\<td\>/;
	$output_line =~ s/$/\<\/td\>\<\/tr\>/;
      }
      print $output_line;
      next;
    }

    # If couldn't find it using Search or looking in bioseq set, print UNKNOWN.
    $output_line = "$protid_string\t$search_key\tUNKNOWN\t\t\t\n";
    if ($output_html) {
      $output_line =~ s/\t/\<\/td\>\<td\>/g;
      $output_line =~ s/^/\<tr\>\<td\>/;
      $output_line =~ s/$/\<\/td\>\<\/tr\>/;
    }
    print $output_line;

  }
  if ($output_html) {
    print "\<\/table\>\n";
  }
}

sub process_search_output {
  my $search_output_href = shift;
  my @search_output = @{$search_output_href};
  my $query_protid = shift;
  my $search_key = shift;
  my $output_line;
  my %successful_search_keys; # if $query has wildcard, may match mul protids.
  my %equiv_ids;

  %equiv_ids = ();
  %successful_search_keys = ();
  my $n_obs = 0;
  my $default_protid;
  # each output line corresponds to a biosequence that is equivalent to one of
  # the input protIDs, including sometimes the input protIDs themselves
  # Collect all these, and collect also the maximum n_obs of all (they should
  # be identical but maybe they won't be)
  #
  # Skip header line ($i=0)
  for (my $i = 1; $i <= $#search_output; $i++) {
    my $line = $search_output[$i];
    chomp $line;
    my @fields = split("\t", $line);
    if ($fields[0] =~ /search_key_name/ ) {  #skip header line (not sure why needed)
      next;
    }
    my $successful_search_key = $fields[0];
    if ($successful_search_key && $successful_search_key !~ /\n/ ) {
      $successful_search_keys{$successful_search_key} = 1;
    }
    my $equiv_id = $fields[2];
    if ($equiv_id) {
    $equiv_ids{$equiv_id} = 1;
    }
    if ($#fields < 3 || ! $fields[3]) {  # no peps for this prot observed
      $fields[3] = 0;
    }
    if ($fields[3] > $n_obs) {
      $n_obs = $fields[3];
    }
  }
  my $equiv_id_string = join(";", keys(%equiv_ids));
  if ($equiv_id_string eq "") {
    $equiv_id_string = "-";
  }
  my $successful_search_key_string = join(";", keys(%successful_search_keys));
  if ($successful_search_key_string eq "") {
    $successful_search_key_string = "-";
  }
  $output_line = "$query_protid\t$search_key\t$successful_search_key_string\t$n_obs\t".
		 "Search\t$equiv_id_string\n";
  return $output_line;
}

sub select_get_proteins_output {
  my $get_proteins_output_aref = shift;
  my @get_proteins_output = @{$get_proteins_output_aref};
  my $i;
  my $non_decoy_found = 0;
  for ($i=1; $i<=$#get_proteins_output; $i++) {
    if ($get_proteins_output[$i] !~ /DECOY_/) {
      $non_decoy_found = 1;
      last;
    }
  }
  if (!$non_decoy_found) {
    $i = 1;
  }
  return ($get_proteins_output[$i]);
}
