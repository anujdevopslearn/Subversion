package SBEAMS::Connection::Utilities;

###############################################################################
# Program     : SBEAMS::Connection::Utilities
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::Connection module which contains
#               generic utilty methods.
#
# SBEAMS is Copyright (C) 2000-2002 by Eric Deutsch
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################


use strict;
use vars qw(@ERRORS
           );

###############################################################################
# histogram
#
# Given an input array of data, calculate a histogram, CDF and other goodies
###############################################################################
sub histogram {
  my $self = shift || croak("parameter self not passed");
  my %args = @_;
  my $SUB_NAME = "histogram";
  my $VERBOSE = 1;

  #### Decode the argument list
  my $data_array_ref = $args{'data_array_ref'};
  my $min = $args{'min'};
  my $max = $args{'max'};
  my $bin_size = $args{'bin_size'};


  #### Create a return result structure
  my $result;
  $result->{result} = 'FAILED';


  #### extract out the data array and sort
  my @data = @{$data_array_ref};
  my @sorted_data = sort sortNumerically @data;
  my $n_elements = scalar(@data);
  return $result unless ($n_elements >= 1);


  #### Determine some defaults if they were not supplied
  if (!defined($min) || !defined($max) || !defined($bin_size)) {

    #### If the user didn't supply a min, set to the minimum aray value
    my $user_min = 1;
    if (!defined($min)) {
      $min = $sorted_data[0];
      $user_min = 0;
    }

    #### If the user didn't supply a max, set to the maximum aray value
    my $user_max = 1;
    if (!defined($max)) {
      $max = $sorted_data[$#sorted_data];
      $user_max = 0;
    }

    #### Determine the desired data range and a rounded range
    my $range = $max - $min;
    my $round_range = find_nearest([1000,500,100,50,20,10,
      5,2,1,0.5,0.25,0.1,0.05,0.02,0.01,0.005,0.002,0.001],$range);
    print "n_elements=$n_elements, min=$min, max=$max, range=$range, ".
      "round_range=$round_range<BR>\n" if ($VERBOSE);
    if ($round_range == 0) {
      print "Histogram error: round_range = 0<BR>\n";
      return $result;
    }


    #### If the user didn't supply a bin_size, determine roughly the
    #### number of desired bins based on the number of data points we
    #### have (the more points, the larger the number of bins) and
    #### then pick the closest round bin_size
    if (!defined($bin_size)) {
      my $desired_bins;
      $desired_bins = 10 if ($n_elements < 50);
      $desired_bins = 20 if ($n_elements >= 50 && $n_elements <= 200);
      $desired_bins = 30 if ($n_elements >= 200 && $n_elements <= 1000);
      $desired_bins = 40 if ($n_elements > 1000);
      $bin_size = ( $max - $min ) / $desired_bins;
      $bin_size = find_nearest([1000,500,100,50,20,10,5,2,1,0.5,0.25,0.1,
        0.05,0.02,0.01,0.005,0.002,0.001],$bin_size);
      print "Setting bin_size to $bin_size<BR>\n" if ($VERBOSE);
    }

    #### If the user didn't supply a min, then round off the min
    unless ($user_min) {
      print "range = $range,  round_range = $round_range,  ".
        "original min = $min<BR>\n" if ($VERBOSE);
      my $increment = ( $round_range / 10.0 );
      $increment = find_nearest([1000,500,100,50,20,10,5,2,1,0.5,0.25,0.1,
        0.05,0.02,0.01,0.005,0.002,0.001],$increment);
      $increment = 0.001 if ($increment < 0.001);
      $min = int( $min / $increment - 0.5 ) * $increment;
      print "Setting min to $min<BR>\n" if ($VERBOSE);
    }


    #### If the user didn't supply a max, then round off the max
    unless ($user_max) {
      print "range = $range,  round_range = $round_range,  ".
        "original max = $max<BR>\n" if ($VERBOSE);
      my $increment = ( $round_range / 10.0 );
      $increment = find_nearest([1000,500,100,50,20,10,5,2,1,0.5,0.25,0.1,
        0.05,0.02,0.01,0.005,0.002,0.001],$increment);
      $increment = 0.001 if ($increment < 0.001);
      $max = int( $max / $increment + 1.5 ) * $increment;
      print "Setting max to $max<BR>\n" if ($VERBOSE);
    }

  }


  #### To work around a floating-point imprecision problems (i.e. where
  #### 0.25 can become 0.250000000001), round to the bin_size precision
  my $precision = 0;
  $bin_size =~ /\d+\.(\d+)/;
  $precision = length($1) if ($1);

  #### Define arrays for the x axis, y axis, and displayed x axis (i.e.
  #### only the numbers we want to show being present and formatted nicely).
  my @xaxis;
  my @yaxis;
  my @xaxis_disp;

  #### Loop through all the bins, preparing the arrays
  my $ctr = $min;
  my $n_bins = 0;
  while ($ctr < $max) {
    push(@xaxis,$ctr);
    my $fixed_ctr = $ctr;
    $fixed_ctr = sprintf("%15.${precision}f",$ctr) if ($precision);
    $fixed_ctr =~ s/ //g;
    push(@xaxis_disp,$fixed_ctr);
    push(@yaxis,0);
    $ctr += $bin_size;
    $n_bins++;
  }


  #### We cannot always display all x axis numbers due to crowding, so
  #### use approximately 10 displayed numbers on the X axis as a rule of thumb
  my $x_label_skip = int( $n_bins / 10.0 );
  $x_label_skip = 1 if ($x_label_skip < 1);

  #### Override with some special, common cases
  $x_label_skip = 4
    if ($bin_size eq 0.25 && $x_label_skip >=3 && $x_label_skip <=5);
  print "x_label_skip=$x_label_skip, bin_size=$bin_size<BR>\n" if ($VERBOSE);

  #### Start off by keeping the first point
  my $skip_ctr = $x_label_skip;

  #### Loop through all the x axis points and blank some out for display
  for (my $i=0; $i<$n_bins; $i++) {
    if ($skip_ctr == $x_label_skip) {
      $skip_ctr = 1;
    } else {
      $xaxis_disp[$i] = '';
      $skip_ctr++;
    }
  }


  #### Loop through all the input data and place in appropriate bins
  my $total = 0;
  my $n_below_histmin = 0;
  my $n_above_histmax = 0;
  foreach my $element (@data) {

    #### If the data point is outside the range, don't completely ignore
    if ($element < $min || $element >= $max) {
      if ($element < $min) {
        $n_below_histmin++;
      } else {
        $n_above_histmax++;
      }

    #### If it is within the range, update the histogram
    } else {
      my $bin = ( $element - $min ) / $bin_size;
      $bin = int($bin);
      $yaxis[$bin]++;
    }

    #### Keep some additional statistics for latest calculations
    $total += $element;

  }


  #### Calculate some statistics of this dataset
  my $mean = $total / $n_elements;


  #### Calculate the standard deviation now that we know the mean
  my $stdev = 0;
  foreach my $element (@data) {
    $stdev += ($element-$mean) * ($element-$mean);
  }
  my $divisor = $n_elements - 1;
  $divisor = 1 if ($divisor < 1);
  $stdev = sqrt($stdev / $divisor);


  #### Loop through all the bins and calculate the CDF
  my @cdf;
  my $sum = $n_below_histmin;
  for (my $i=0; $i<$n_bins; $i++) {
    $sum += $yaxis[$i];
    $cdf[$i] = $sum / $n_elements;
  }


  #### Fill the output data structure with goodies that we've learned
  $result->{xaxis} = \@xaxis;
  $result->{xaxis_disp} = \@xaxis_disp;
  $result->{yaxis} = \@yaxis;
  $result->{cdf} = \@cdf;

  $result->{n_bins} = $n_bins;
  $result->{bin_size} = $bin_size;
  $result->{histogram_min} = $min;
  $result->{histogram_max} = $max;

  $result->{minimum} = $sorted_data[0];
  $result->{maximum} = $sorted_data[$#sorted_data];
  $result->{total} = $total;
  $result->{n_elements} = $n_elements;
  $result->{mean} = $mean;
  $result->{stdev} = $stdev;
  $result->{median} = $sorted_data[int($n_elements/2)];
  $result->{quartile1} = $sorted_data[int($n_elements*0.25)];
  $result->{quartile3} = $sorted_data[int($n_elements*0.75)];
  $result->{SIQR} = ($result->{quartile3}-$result->{quartile1})/2;

  $result->{ordered_statistics} = ['n_elements','minimum','maximum',
    'mean','stdev','median','SIQR','quartile1','quartile3',
    'n_bins','bin_size','histogram_min','histogram_max'];

  $result->{result} = 'SUCCESS';

  return $result;


} # end histogram


###############################################################################
# find_nearest
###############################################################################
sub find_nearest {
  my $map_array_ref = shift || die("parameter map_array_ref not passed");
  my $value = shift;
  my $SUB_NAME = "histogram";

  my $result = $value;

  my $prev_element = $map_array_ref->[0] * 2;
  foreach my $element (@{$map_array_ref}) {
    if ($element < $value) {
      if ($value - $element gt $prev_element - $element) {
        $result = $prev_element;
      } else {
        $result = $element;
      }
      last;
    }
    $prev_element = $element;
  }

  return $result;

}


###############################################################################
# Numerically
###############################################################################
sub sortNumerically {

  return $a <=> $b;

}



###############################################################################
###############################################################################
###############################################################################
###############################################################################
1;
