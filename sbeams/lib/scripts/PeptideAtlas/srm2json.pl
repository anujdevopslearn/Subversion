#!/usr/local/bin/perl

# Create .json files used by Dick K's chromatogram viewer.
# Take as input one of the following:
#   - chromatogram text files produced by peptideChromatogramExtractor
#     (which extracts from mzML)
#   - mzXML files

use strict;
use MIME::Base64;
$|++;

my $nargs = scalar @ARGV;
my $usage ="Usage: srm2json {ataqs | mzxml} [rt] [q1] [eri_string] < SRM_data_file > json_file\n";

if ($nargs < 1) { print $usage; exit(); }

my $mode = $ARGV[0];
if ($mode ne 'ataqs' && $mode ne 'mzxml') { print $usage; exit(); }

my ($rt, $target_q1, $eri);
if ($nargs > 1) { $rt = $ARGV[1]; }
if ($nargs > 2) { $target_q1 = $ARGV[2]; }
if ($nargs > 3) { $eri = $ARGV[3]; }

# a JSON object for the chromatogram,
#  is simply one or more lists (named "data") of (time, intensity)
#   (or, for RT marker, (id, value)) pairs:
#      var data_json = [
#        { full : 'Q1:590.337 Q3:385.22 Z1:3 Z3:1 CE:16.5 ION:y3',
#         label : '$num Q1:590.337 Q3:385.22',
#           data : [{time : 2898.333, intensity : 40.166},
#                   {time : 3056.667, intensity : -0.052}, ...
#                   {id : 'Retention Time', value : 1200}, ...
#                  ]},
#          ...


# Open data_json
print "var data_json = [\n";

my $count = 0;

if ($mode eq 'ataqs') {
  while (my $line = <STDIN>) {
    # First line in Mi-Youn's text file has some infos: read them.
    chomp $line;
    $line =~ /Q1:(\S+) Q3:(\S+) Z1:(\S+) Z3:(\S+) CE:(\S+) ION:(\S+)/;
    my ($q1, $q3, $z1, $z3, $ce, $ion) = ($1, $2, $3, $4, $5, $6);
    $count++;

    # Read next input line.
    $line = <STDIN>;
    # Strip punctuation from input line. What's left is a list of numbers.
    $line =~ s/\(//g;
    $line =~ s/\)//g;
    $line =~ s/,//g;
    my @numbers = split(' ', $line);

    # Open this chromatogram in JSON object
    print "  {  full : 'COUNT: $count Q1:$q1 Q3:$q3 Z1:$z1 Z3:$z3 CE:$ce ION:$ion',\n";
    #my $label = "ION:$ion";
    my $label =  sprintf "%3d  Q1:$q1 Q3:$q3", $count;
    print "    label : '$label',\n";
    print "     data : [\n";

    # Write each pair of numbers in Dick's JSON format.
    while (@numbers) {
      my $time = shift @numbers;
      my $intensity = shift @numbers;
      print "          {time : $time, intensity : $intensity},\n";
    }
    # Close this chromatogram in JSON object
    print "        ]},\n";
  }

} elsif ($mode eq 'mzxml') {
  my ($scan, $time, $q1, $q3, $intensity);
  my $tol = 0.005;
  my (%scan_data, $intensity_aref);
  # Read scans for $q1 into a hash
  while (my $line = <STDIN>) {
    # New scan. Store data from previous.
    if ($line =~ /<scan num="(\d+)"/) {
      $scan = $1;
      # maybe need to check when scans start at 0
      #print "Q1: $q1\n";
      if (($scan > 1) && ($q1 <= $target_q1+$tol) && ($q1 >= $target_q1-$tol)) {
        if ($intensity_aref) {
	  my @intensities = @{$intensity_aref};
	  while (@intensities) {
	    my $q3 = shift @intensities;
	    my $intensity = shift @intensities;
	    $scan_data{$q1}->{$q3}->{'rt'}->{$time} = $intensity;
	    $scan_data{$q1}->{$q3}->{'q1'} = $q1;
            # initialize eri to a tiny value in case we don't get a value
	    $scan_data{$q1}->{$q3}->{'eri'} = 0.1 if $eri;
	    #print "$q1\t$q3\t$time\t$intensity\n";
	  }
	} else {
	  $scan_data{$q1}->{$q3}->{'rt'}->{$time} = $intensity;
	  $scan_data{$q1}->{$q3}->{'q1'} = $q1;
	  $scan_data{$q1}->{$q3}->{'eri'} = 0.01 if $eri;
	  #print "$q1\t$q3\t$time\t$intensity\n";
        }
	undef $intensity_aref;
      }
    # Data for current scan.
    } elsif ($line =~ /retentionTime="PT(\S+)(\w)"/) {
      # Report RT in seconds
      # Complete parser of this element, type="xs:duration", is more complicated.
      my $n = $1;
      my $units = $2;
      $time = sprintf ("%0.3f", ($units eq 'M') ? $n*60 : $n );
    } elsif ($line =~ /basePeakIntensity="(\S*?)"/) {
      $intensity = $1;
    } elsif ($line =~ /basePeakMz="(\S*?)"/) {
      $q3 = $1;
    # sometimes, multiple peaks are encoded in a single <scan>
    } elsif ($line =~ /compressedLen.*\>(.+)\<.peaks>/) {
      #print $1, "\n";
      $intensity_aref = decodeScan($1);
      #for my $elt (@{$intensity_aref}) { print "$elt\n"; }
    } elsif ($line =~ /<precursorMz.*>(\S+)<.precursorMz>/) {
      $q1 = $1;
    }
  }

  # Unpack and store the expected intensity ratios, if provided
  if ($eri) {
    my %eri_values;
    my $tol = 0.0005;
    my @values = split(",",$eri);
    while (@values) {
      # get a q3, intensity pair
      my $eri_q3 = shift @values;
      my $int = shift @values;
      # see if we have data for this q3
      for my $data_q1 (keys %scan_data) {
        # initialize eri to a small number in case we don't find it.
	for my $data_q3 (keys %{$scan_data{$data_q1}}) {
	  if (($eri_q3 <= $data_q3+$tol) && ($eri_q3 >= $data_q3-$tol)) {
	    # if we do, store the eri
	    $scan_data{$data_q1}->{$data_q3}->{'eri'} = $int;
            last;
	  }
	}
      }
    }
  }

  # Write .json file
  $count = 0;
  for $q1 (keys %scan_data) {
    for $q3 (keys %{$scan_data{$q1}}) {
      $count++;
      printf "  {  full : 'COUNT: %d Q1:%0.3f Q3:%0.3f',\n", $count, $scan_data{$q1}->{$q3}->{'q1'}, $q3;
      #my $label = "ION:$ion";
      my $label =  sprintf "%3d  Q1:%0.3f Q3:%0.3f", $count, $scan_data{$q1}->{$q3}->{'q1'}, $q3;
      $label .= sprintf " ERI: %0.1f",
               $scan_data{$q1}->{$q3}->{eri}
               if ($eri);
      print "    label : '$label',\n";
      print "      eri : $scan_data{$q1}->{$q3}->{eri},\n" if ($eri);
      print "     data : [\n";
      # Write each pair of numbers in Dick's JSON format.
      for my $time (sort keys %{$scan_data{$q1}->{$q3}->{'rt'}}) {
	my $intensity = $scan_data{$q1}->{$q3}->{'rt'}->{$time};
	printf "          {time : $time, intensity : %0.5f},\n", $intensity;
      }
      # Close this chromatogram in JSON object
      print "        ]},\n";
    }
  }
}

# Close data_json
print "]\n";

# Write the retention time marker, if value provided
if ($rt )  {
  my $formatted_rt = sprintf "%0.3f", $rt;
  print "var vmarker_json = [ {id : '$formatted_rt', value : $rt} ]\n";
} else {
  print "var vmarker_json = [  ]\n";
}

######################################################
# subroutines
######################################################

# A base 64 string encodes a list of q3, intensity pairs.
# Return that list.
sub decodeScan {
  my $base64_string = shift || die ("decodeScan: no argument");;
  my $decoded = decode_base64($base64_string);
  my @array = unpack("f*", byteSwap($decoded));
  return \@array;
}

sub byteSwap {
  my $in = shift || die("byteSwap: no input");

  my $out = '';
  for (my $i = 0; $i < length($in); $i+=4) {
    $out .= reverse(substr($in,$i,4));
  }
  return($out);
}
