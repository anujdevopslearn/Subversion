package SBEAMS::Connection::Utilities;

###############################################################################
# Program     : SBEAMS::Connection::Utilities
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::Connection module which contains
#               generic utilty methods.
#
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################

use strict;
use POSIX;


use SBEAMS::Connection::Log;
use SBEAMS::Connection::Settings qw( $DBADMIN $PHYSICAL_BASE_DIR );
use vars qw( $q @ERRORS);
my $log = SBEAMS::Connection::Log->new();

###############################################################################
# Constructor
###############################################################################
sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;
    return($self);
}


###############################################################################
# histogram
#
# Given an input array of data, calculate a histogram, CDF and other goodies
###############################################################################
sub histogram {
  my $self = shift || croak("parameter self not passed");
  my %args = @_;
  my $SUB_NAME = "histogram";
  my $VERBOSE = 0;

  #### Decode the argument list
  my $data_array_ref = $args{'data_array_ref'};
  my $min = $args{'min'};
  my $max = $args{'max'};
  my $bin_size = $args{'bin_size'};


  #### Create a return result structure
  my $result;
  $result->{result} = 'FAILED';


  #### extract out the data array and sort
  #my @data = @{$data_array_ref};
  #### Extract only the non-empty elements
  my @data;
  foreach my $element (@{$data_array_ref}) {
    if (defined($element) && $element gt '' && $element !~ /^\s+$/) {
      push(@data,$element);
    }
  }
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
      print "Histogram error: round_range = 0<BR>\n" unless $args{quiet};
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
  $n_elements = 0; # Reset back to 0 and count only non-empty numbers
  foreach my $element (@data) {

    #### If the value is empty then ignore - ALREADY DONE ABOVE
    #print "$n_elements: element = $element<BR>\n";
    #next unless (defined($element));
    #next unless ($element gt '');
    #next if ($element =~ /^\s+$/);

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
    $n_elements++;

  }


  #### Calculate some statistics of this dataset
  my $divisor = $n_elements;
  $divisor = 1 if ($divisor < 1);
  my $mean = $total / $divisor;


  #### Loop through all the bins and calculate the CDF
  my @cdf;
  my $sum = $n_below_histmin;
  for (my $i=0; $i<$n_bins; $i++) {
    $sum += $yaxis[$i];
    $cdf[$i] = $sum / $divisor;
  }


  #### Calculate the standard deviation now that we know the mean
  my $stdev = 0;
  foreach my $element (@data) {

    #### If the value is empty then ignore - ALREADY DONE ABOVE
    #next unless (defined($element));
    #next unless ($element gt '');
    #next if ($element =~ /^\s+$/);

    $stdev += ($element-$mean) * ($element-$mean);
  }
  $divisor = $n_elements - 1;
  $divisor = 1 if ($divisor < 1);
  $stdev = sqrt($stdev / $divisor);


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
  $n_elements = 1 if ($n_elements < 1);
  $result->{median} = $sorted_data[int($n_elements/2)];
  $result->{quartile1} = $sorted_data[int($n_elements*0.25)];
  $result->{quartile3} = $sorted_data[int($n_elements*0.75)];
  $result->{SIQR} = ($result->{quartile3}-$result->{quartile1})/2;

  $result->{ordered_statistics} = ['n_elements','minimum','maximum','total',
    'mean','stdev','median','SIQR','quartile1','quartile3',
    'n_bins','bin_size','histogram_min','histogram_max'];

  $result->{result} = 'SUCCESS';

  return $result;


} # end histogram



###############################################################################
# discrete_value_histogram
#
# Given an input array of data, calculate a histogram using the discrete
# values in the data
###############################################################################
sub discrete_value_histogram {
  my $self = shift || croak("parameter self not passed");
  my %args = @_;
  my $SUB_NAME = "discrete_value_histogram";
  my $VERBOSE = 0;

  #### Decode the argument list
  my $data_array_ref = $args{'data_array_ref'};


  #### Create a return result structure
  my $result;
  $result->{result} = 'FAILED';


  #### extract out the data array and sort
  #my @data = @{$data_array_ref};
  #### Extract only the non-empty elements
  my @data;
  foreach my $element (@{$data_array_ref}) {
    if (defined($element) && $element gt '' && $element !~ /^\s+$/) {
      push(@data,$element);
    }
  }
  my $n_elements = scalar(@data);
  return $result unless ($n_elements >= 1);

  #### Build a hash of the discrete elements
  my %discrete_elements;
  $n_elements = 0;
  foreach my $element (@data) {
    #### If there are semicolons in the data; treat that as a delimiter
    my @values = split (";",$element);
    foreach my $value ( @values ) {
      #### strip leading and trailing whitespace
      $value =~ s/^\s+//;
      $value =~ s/\s+$//;
      $discrete_elements{$value}++;
      $n_elements++;
    }
  }


  my @xaxis;
  my @xaxis_disp;
  my @yaxis;
  my $min = -1;
  my $max = -1;

  #### Loops over each discrete element and build the arrays needed
  #### for the histogram
  foreach my $element (sort(keys(%discrete_elements))) {
    my $count = $discrete_elements{$element};
    push(@xaxis,$element);
    push(@xaxis_disp,sprintf("%s (%.1f%)",$element,
			$count/$n_elements*100));
    push(@yaxis,$count);
    $max = $count if ($count > $max);
    $min = $count if ($min == -1);
    $min = $count if ($count < $min);
  }
  my $n_discrete_elements = scalar(@xaxis);


  #### Fill the output data structure with goodies that we've learned
  $result->{xaxis} = \@xaxis;
  $result->{xaxis_disp} = \@xaxis_disp;
  $result->{yaxis} = \@yaxis;

  $result->{n_bins} = $n_discrete_elements;
  $result->{n_elements} = $n_elements;

  $result->{minimum} = $min;
  $result->{maximum} = $max;

  $result->{ordered_statistics} = ['n_elements','n_bins'];

  $result->{result} = 'SUCCESS';

  return $result;


} # end discrete_value_histogram



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

#+
# Rounds floats to int, 'randomly'  rounds x.500 up or down 
#-
sub roundToInt {
  my $self = shift;
  my $float = shift || '';
  unless ( $float =~ /^[-.eE\d]+$/ ) {
    print STDERR "Illegal non-numeric input passed: $float\n";
    return 0;
  }
  my $floor = floor($float);
  my $f_diff = abs( $floor - $float );
  my $ceil = ceil($float);
  my $c_diff = abs( $ceil - $float );
  return ( $c_diff > $f_diff ) ? $floor :  # If closer to floor, return that
         ( $c_diff < $f_diff ) ? $ceil :   # If closer to ceil, return that
         ( time() % 2 ) ? $ceil : $floor;  # Else round up/down 
}

#+ 
# Quick n dirty, assume number is > 0, positive 
# @narg number    Number to be formatted
# @narg minimum   Minimum number to format, default 10
#-
sub formatScientific {
  my $self = shift;
  my %args = ( minimum => 10,
               precision => 2,
               output_mode => 'text',
               @_ );
	# Need something to format
  return '' unless $args{number};

  # Only format if bigger than minimum.
  return $args{number} if $args{number} < $args{minimum};

  my $number = int( $args{number} );
  my $len = length($number) - 1;
  my $num_val = sprintf( "%0.$args{precision}f", ($number/10**$len) );

  # Text mode 1.3E4
  my $exp = "E${len}";

	# HTML mode 1.3x10<sup>4</sup>
  if ( $args{output_mode} eq 'html' ) {
    $exp = 'x10<SPAN CLASS="small_super_text">' . $len . '</SPAN>';
  }
  $number = $num_val . $exp;

  return $number;
}

###############################################################################
# average
#
# Given an input array of data, as well as an optional array or weights or
# uncertainties, calculate a mean and final uncertainty
###############################################################################
sub average {
  my $self = shift || croak("parameter self not passed");
  my %args = @_;
  my $SUB_NAME = 'average';
  my $VERBOSE = 0;

  #### Decode the argument list
  my $values_ref = $args{'values'};
  my $errors_ref = $args{'uncertainties'};
  my $weights_ref = $args{'weights'};

  #### Determine nature of the input arrays
  return(undef) unless (defined($values_ref) && @{$values_ref});
  my @values = @{$values_ref};
  my $n_values = scalar(@values);

  my @errors;
  my $n_errors;
  if (defined($errors_ref) && @{$errors_ref}) {
    @errors = @{$errors_ref};
    $n_errors = scalar(@errors);
  }

  my @weights;
  my $n_weights;
  if (defined($weights_ref) && @{$weights_ref}) {
    @weights = @{$weights_ref};
    $n_weights = scalar(@weights);
  }


  #### If no weights or errors were provided, calculate a plain mean
  #### of all non-undef values
  unless ($n_errors || $n_weights) {
    my $n_elements = 0;
    my $total = 0;
    foreach my $element (@values) {
      if (defined($element)) {
	$total += $element;
	$n_elements++;
      }
    }
    return(undef) unless ($n_elements > 0);
    return($total/$n_elements);
  }


  #### If only errors were provided, convert to weights
  if (defined($n_errors) && !defined($n_weights)) {
    unless ($n_errors == $n_values) {
      print "ERROR: $SUB_NAME: values and errors arrays must have same size\n";
      return(undef);
    }
    @weights = ();
    foreach my $element (@errors) {
      if (defined($element) && $element > 0) {
	push(@weights,1.0/($element * $element));
      } else {
	push(@weights,undef);
      }
    }
  }


  #### If both errors and weights were provided, we really should verify


  #### Calculate weighted mean and final uncertainty
  my $array_sum = 0;
  my $weight_sum = 0;
  my $n_elements = 0;
  my $err_sum = 0;
  for (my $i=0; $i<$n_values; $i++) {
    if (defined($values[$i]) && defined($weights[$i])) {
      $array_sum += $values[$i] * $weights[$i];
      $weight_sum += $weights[$i];
      $err_sum += 1.0/($weights[$i] * $weights[$i]);
      $n_elements++;
    }
  }

  my $divisor = $weight_sum;
  $divisor = 1 unless ($divisor);
  my $mean = $array_sum / $divisor;

  if ($n_errors) {
    my $uncertainty = sqrt(1.0/$divisor);
    return($mean,$uncertainty);
  }

  return($mean);

}



###############################################################################
# stdev
#
# Given an input array of data, calculate the standard deviation
###############################################################################
sub stdev {
  my $self = shift || croak("parameter self not passed");
  my %args = @_;
  my $SUB_NAME = 'stdev';
  my $VERBOSE = 0;

  #### Decode the argument list
  my $values_ref = $args{'values'};

  #### Determine nature of the input array
  return(undef) unless (defined($values_ref) && @{$values_ref});
  my @values = @{$values_ref};
  my $n_values = scalar(@values);

  #### Return undef for just one value
  return(undef) if ($n_values < 2);

  #### Calculate the average
  my ($mean) = $self->average(values => $values_ref);
  return(undef) unless (defined($mean));

  #### Calculate the standard deviation now that we know the mean
  my $stdev = 0;
  my $n_elements = 0;
  for (my $i=0; $i<$n_values; $i++) {
    if (defined($values[$i])) {
      $stdev += ($values[$i]-$mean) * ($values[$i]-$mean);
      $n_elements++;
    }
  }

  my $divisor = $n_elements - 1;
  $divisor = 1 if ($divisor < 1);
  $stdev = sqrt($stdev / $divisor);

  return($stdev);

}


###############################################################################
# min
#
# Given an input array of data, return the minimum value
###############################################################################
sub min {
  my $self = shift || croak("parameter self not passed");
  my %args = @_;
  my $SUB_NAME = 'min';

  #### Decode the argument list
  my $values_ref = $args{'values'};

  #### Determine nature of the input array
  return(undef) unless (defined($values_ref) && @{$values_ref});
  my @values = @{$values_ref};
  my $n_values = scalar(@values);

  #### Find the minimum
  my $minimum = undef;
  for (my $i=0; $i<$n_values; $i++) {
    if (defined($values[$i])) {
      if (defined($minimum)) {
	if ($values[$i] < $minimum) {
	  $minimum = $values[$i];
	}
      } else {
	$minimum = $values[$i];
      }

    }
  }

  return($minimum);

}

###############################################################################
# max
#
# Given an input array of data, return the maximum value
###############################################################################
sub max {
  my $self = shift || croak("parameter self not passed");
  my %args = @_;
  my $SUB_NAME = 'max';

  #### Decode the argument list
  my $values_ref = $args{'values'};

  #### Determine nature of the input array
  return(undef) unless (defined($values_ref) && @{$values_ref});
  my @values = @{$values_ref};
  my $n_values = scalar(@values);

  #### Find the minimum
  my $maximum = undef;
  for (my $i=0; $i<$n_values; $i++) {
    if (defined($values[$i])) {
      if (defined($maximum)) {
	if ($values[$i] > $maximum) {
	  $maximum = $values[$i];
	}
      } else {
	$maximum = $values[$i];
      }

    }
  }

  return($maximum);

}
sub get_datetime {
  my $self = shift;
  my @time = localtime();
  my @days = qw(Sun Mon Tue Wed Thu Fri Sat );
  my $year = $time[5] + 1900;
  my $mon = $time[4] + 1;
  my $day = $time[3];
  my $hour = $time [2];
  my $min = $time[1];
  my $sec = $time[0];
  for ( $min, $day, $hour, $mon, $sec ) {
    $_ = '0' . $_ if length( $_ ) == 1;
  }
  my $date = "${year}-${mon}-${day} ${hour}:${min}:${sec}";
  return $date;
}


#+
# Routine to return pseudo-random string of characters
#
# narg: num_chars   Optional, length of character string, def = 8.
# narg: char_set    Optional, character set to use passed as array reference,
#                   def = ( 'A'-'Z', 'a'-'z', 0-9 )
# ret:              Random string of specified length comprised of elements of 
#                   character set.
#-
sub getRandomString {
  my $self =  shift;
  my %args = @_;

  # Use passed number of chars or 8
  $args{num_chars} ||= 8;

  # Use passed char set if any, else use default a-z, A-Z, 0-9
  my @chars = ( ref( $args{char_set} ) eq 'ARRAY' ) ?  @{$args{char_set}} :
                         ( 'A'..'Z', 'a'..'z', 0..9 );

# removed these from default set, 4/2006 (DC)
# qw( ! @ $ % ^ & * ? ) );

  # Thank you perl cookbook... 
  my $rstring = join( "", @chars[ map {rand @chars} ( 1..$args{num_chars} ) ]);
  
  return( $rstring );

}


#+
# Routine returns name of subroutine from which it was called.  if an argument
# is also sent, will return fully qualified namespace name 
# (e.g. SBEAMS::Foo::my_subroutine)
#-
sub get_subname {
  my $self = shift;
  my $package = shift || 0;
  my @call = caller(1);
  $call[3] =~ s/.*:+([^\:]+)$/$1/ unless $package;
  return $call[3];
}

#+
# Utility routine to dump out a hash in key => value formatt
#-
sub dump_hashref {
  my $this = shift;
  my %args = @_;
  return unless $args{href};
  my $mode = $args{mode} || 'text';
  my $eol = ( $mode =~ /HTML/i ) ? "<BR>\n" : "\n";
  my $dumpstr = '';
  for my $k ( keys( %{$args{href}} ) ) {
    my $val = $args{href}->{$_} || '';
    $dumpstr .= "$k => $val" . $eol;
  }
  return $dumpstr;
}

#+
# Utility routine to dump out an array ref
#-
sub dump_arrayref {
  my $this = shift;
  my %args = @_;
  return unless $args{aref};
  my $mode = $args{mode} || 'text';
  my $eol = ( $mode =~ /HTML/i ) ? "<BR>\n" : "\n";
  my $dumpstr = '';
  for my $line ( @{$args{aref}} ) {
    $dumpstr .= $line . $eol;
  }
  return $dumpstr;
}

sub set_page_message {
  my $this = shift;
  my %args = @_;
  return unless $args{msg};

  my $type = ( $args{type} && $args{type} eq 'Error' ) ? 'Error' : 'Info';

  $this->setSessionAttribute( key => '_SBEAMS_message', 
                            value => $type . '::' . $args{msg} );
  
}

sub get_page_message {
  my $this = shift;
  my %args = @_;

  my %color = ( Error => $args{error_color} || 'red',
                Info => $args{info_color} || 'green' );

  my $sbeams_msg = $this->getSessionAttribute( key => '_SBEAMS_message' );

  if ( !$sbeams_msg && $args{q} ) {
    $sbeams_msg = $args{q}->cookie( '__SBEAMS_message' );
  }

  return '' unless $sbeams_msg;
  $sbeams_msg =~ /(\w+)(::)/;
  my $mode = $1;
  $sbeams_msg =~ s/$1$2//gm;

  $log->debug( "Mode is $mode from message of $sbeams_msg" );

  # In case the format was goofy:
  $mode ||= 'Info';

  # Clean up
  $this->deleteSessionAttribute( key => '_SBEAMS_message' );
  if ( $args{no_color} ) {
    return $sbeams_msg; 
  } else {
    $sbeams_msg = "<FONT COLOR=$color{$mode}>$sbeams_msg</FONT>"; 
    $sbeams_msg = "<I>$sbeams_msg</I>" unless $args{no_italics};
  }
  return $sbeams_msg;
}

sub get_notice {
  my $this = shift;

  # Default to Core
  my $module = shift || 'Core';
  
  my $file = $PHYSICAL_BASE_DIR . '/lib/conf/' . $module . '/notice.txt';
  open( NOTICE, $file ) || return '';
  
  undef local $/;
  my $msg = <NOTICE>;

  return $msg;
}

sub truncateString {
  my $self = shift;
  my %args = @_;
  return undef unless $args{string};
  my $string = $args{string};
  my $len = $args{len} || 35;

  # Trim trailing space
  chomp( $string );
  $string =~ s/\s*$//;

  if ( $len < length($string) ) {
    $string = substr( $string, 0, $len - 3 ) . '...'; 
  }
  return $string;
}

sub getRomanNumeral {
  my $self = shift;
  my %args = @_;
  return undef unless $args{number};
  unless ( $self->{_rnumerals} ) {
    my %num = ( 1  => 'I',
                2  => 'II',
                3  => 'III',
                4  => 'IV',
                5  => 'V',
                6  => 'VI',
                7  => 'VII',
                8  => 'VIII',
                9  => 'IX',
                10 => 'X',
                11 => 'XI',
                12 => 'XII',
                13 => 'XIII',
                14 => 'XIV',
                15 => 'XV',
                16 => 'XVI',
                17 => 'XVII',
                18 => 'XVIII',
                19 => 'XIX',
                20 => 'XX',
                21 => 'XXI',
                22 => 'XXII',
                23 => 'XXIII',
                24 => 'XXIV',
                25 => 'XXV',
                26 => 'XXVI',
                27 => 'XXVII' );
    $self->{_rnumerals} = \%num;
  }
  return $self->{_rnumerals}->{$args{number}};
}


sub getGaggleXML {
  my $self = shift;
  my %args = @_;
  $args{type} ||= 'direct';
  $args{name} ||= 'generic';
  $args{organism} ||= 'unknown';
  my $xml;

  if ( $args{start} ) {
    $xml =<<"    END";
    <STYLE TYPE="text/css" media="screen">
    div.visible {
    display: inline;
    white-space: nowrap;         
    }
    div.hidden {
    display: none;
    }
    </STYLE>
    <DIV name=gaggle_xml class=hidden>
    <gaggleData version="0.1">
    END
  }

#    <dataMatrix type="indirect"
#                name="Microarray experiments"
#                species="Halobacterium sp. NRC-1"
#                url="http://www.mydomain.com/myapp/myprojects/123456789.tsv"/>


  if ( $args{object} =~ /^namelist$/i ) {
    my $items = '';
    my $url = '';
    if ( $args{type} eq 'indirect' ) {
      $url = "url=$args{data}";
    } else {
      return unless @{$args{data}};
      $items = join( "\t", @{$args{data}} );
    }
      $xml .=<<"      END";
      <namelist type='$args{type}'
                name='$args{name}' 
             species='$args{organism}'
             $url
      >  
      $items
      </namelist>
      END
  } else {
    $log->error( "Unknown object type" );
  }

#  $xml .= "</gaggleData>\n  -->" if $args{end};
  $xml .= "</gaggleData>\n </DIV>" if $args{end};
  return $xml;
}

#+
# Companion method to getGaggleXML, routine creates gaggle microformat
# from passed data structure.  Currently supports only namelist data type
#
# @narg type      
# @narg name      
# @narg organism      
# @narg object      
# @narg data      
#-
sub getGaggleMicroformat {
  my $self = shift;
  my %args = @_;

  # some reasonable defaults
  $args{type} ||= 'direct';
  $args{name} ||= 'generic';
  $args{organism} ||= 'unknown';

  # Sanity check
  unless ( $args{data} ) {
    $log->error( "Must provide data object" );
    return '';
  }
  return unless @{$args{data}};
  my $nrows = scalar(  @{$args{data}} );

  my $microformat = qq~
    <div class="gaggle-data">
     <p>name=<span class="gaggle-name">$args{name}</span><br />
     <p>species=<span class="gaggle-species">$args{organism}</span><br />
     <p>(optional)size=<span class="gaggle-size">$nrows</span><br />
     </p>
     <div class="gaggle-namelist">
      <ol>
   ~;

  if ( $args{object} =~ /^namelist$/i ) {
    $microformat .= '<li>' . join( "</li>\n<li>", @{$args{data}} );
  } else {
    $log->error( "Unknown object type, $args{object}" );
  }

  $microformat .= "</li>";
  $microformat .= qq~
      </ol>
     </div>
    </div>
  ~;

  return $microformat;

} # end getGaggleMicroformat



sub get_admin_mailto {
  my $self = shift;
  my $linktext = shift;

  my ( $email ) = $DBADMIN =~ /(\w+@\w+\.\w+[\w\.]*)/;
  $log->debug( "Email $email extracted from DBADMIN setting: $DBADMIN" );
  return ( $email ) ? "<A HREF=mailto:$email>$linktext</A>" : '';
}

sub map_peptide_to_protein {
	my $self = shift;
	my %args = @_;
	my $pep_seq = $args{pepseq};
	my $protein_seq = $args{protseq};
	
	if ( $protein_seq =~ /$pep_seq/ ) {
		my $start_pos = length($`);    
		my $stop_pos = length($pep_seq) + $start_pos;  
		return ($start_pos, $stop_pos);	
	}else{
		return;
	}
}

sub get_site_positions {
  my $self = shift;
  my %args = @_;
  $args{pattern} = 'N.[S|T]' if !defined $args{pattern};
  return unless $args{seq};

  my @posn;
  while ( $args{seq} =~ m/$args{pattern}/g ) {
    my $posn = length($`);
    push @posn, $posn;# pos($string); # - length($&) # start position of match
  }
#  $log->debug( "Found $posn[0] for NxS/T in $args{seq}\n" );
  return \@posn;
}

sub rs_has_data {
  my $self = shift;
  my %args = @_;
  my $rs = $args{resultset_ref} || return undef;
  return scalar( @{$rs->{data_ref}} );
}


#### Get biosequence_accession, biosequence_gene_name, and dbxref_id
####  for a biosequence by parsing its descriptor, and store the info
####  in rowdata_ref hash.

sub parseBiosequenceDescriptor {
  my $self = shift;
  my %args = @_;

  my $SUB_NAME = 'parseBiosequenceDescriptor';

  #### Decode the argument list
  my $biosequence_set_name = $args{'biosequence_set_name'}
   || die "ERROR[$SUB_NAME]: biosequence_set_name not passed";
  my $rowdata_ref = $args{'rowdata_ref'}
   || die "ERROR[$SUB_NAME]: rowdata_ref not passed";
  my $fav_codon_frequency = $args{'fav_codon_frequency'} || {};


  #### Define a few variables
  my ($n_other_names,@other_names);


  #### Failing anything else, make the accession the biosequence_name
  ####  and the gene name undefined. (07/30/09: before today, the
  ####  gene_name was also set to the biosequence_name by default.)
  #$rowdata_ref->{biosequence_gene_name} = $rowdata_ref->{biosequence_name};
  $rowdata_ref->{biosequence_gene_name} = undef;
  $rowdata_ref->{biosequence_accession} = $rowdata_ref->{biosequence_name};


  #### Encoding popular among a bunch of databases
  #### Can be overridden later on a case-by-case basis

  if ($rowdata_ref->{biosequence_name} =~ /^SW.{0,1}\:(.+)$/ ) {
     #$rowdata_ref->{biosequence_gene_name} = $1;
     $rowdata_ref->{biosequence_accession} = $1;
     $rowdata_ref->{dbxref_id} = '1';
  }

  # Uniprot, from http://www.expasy.ch/sprot/userman.html#AC_line
  # includes varsplic accessions (e.g. P12345-2)
  if ($rowdata_ref->{biosequence_name} =~ /(^[O-Q]\d\w{3}\d$)/ ||
      $rowdata_ref->{biosequence_name} =~ /(^[O-Q]\d\w{3}\d-\d+$)/ ||
      $rowdata_ref->{biosequence_name} =~ /(^[A-N,R-Z]\d[A-Z]\w\w\d$)/ ||
      $rowdata_ref->{biosequence_name} =~ /(^[A-N,R-Z]\d[A-Z]\w\w\d-\d+$)/) {
    $rowdata_ref->{biosequence_accession} = $1;
    if ($rowdata_ref->{biosequence_desc} =~ /GN=(\S+)/ ) {
      $rowdata_ref->{biosequence_gene_name} = $1;
    }
    $rowdata_ref->{dbxref_id} = '35';  #01/15/13: this used to be 1, which means Swiss-Prot
  }

  if ($rowdata_ref->{biosequence_name} =~ /^PIR.\:(.+)$/ ) {
     #$rowdata_ref->{biosequence_gene_name} = $1;
     $rowdata_ref->{biosequence_accession} = $1;
     $rowdata_ref->{dbxref_id} = '6';
  }

  if ($rowdata_ref->{biosequence_name} =~ /^GP.{0,1}\:(.+)_\d+$/ ) {
     #$rowdata_ref->{biosequence_gene_name} = $1;
     $rowdata_ref->{biosequence_accession} = $1;
     $rowdata_ref->{dbxref_id} = '8';
  }

  if ($rowdata_ref->{biosequence_name} =~ /^(UPSP|UPTR)\:(.+)$/ ) {
     #$rowdata_ref->{biosequence_gene_name} = $2;
     $rowdata_ref->{biosequence_accession} = $2;
     $rowdata_ref->{dbxref_id} = '35';
  }


  #### Conversion rules for the older ENSEMBL Human Protein databases v <= 19
  if ($rowdata_ref->{biosequence_name} =~ /^Translation:(ENSP\d+)$/ ) {
     $rowdata_ref->{biosequence_name} = $1;
     $rowdata_ref->{biosequence_accession} = $1;
     if ($rowdata_ref->{biosequence_desc} =~ /(ENSG\d+)/ ) {
       $rowdata_ref->{biosequence_gene_name} = $1;
     }
     $rowdata_ref->{dbxref_id} = '20';
  }

  #### Conversion rules for the  ENSEMBL Human Protein database v 22 - 28
  if ($rowdata_ref->{biosequence_desc} =~ /^.*(ENSG\d+)\s.*$/) {
     $rowdata_ref->{biosequence_gene_name} = $1;
     $rowdata_ref->{biosequence_accession} = $rowdata_ref->{biosequence_name};
     $rowdata_ref->{dbxref_id} = '20';
  }


  #### Conversion rules for the ENSEMBL Drosophila Protein database
  if ($rowdata_ref->{biosequence_name} =~ /^Translation:(.+)$/ ) { ## parse for old format 
     $rowdata_ref->{biosequence_name} = $1;
     $rowdata_ref->{biosequence_accession} = $1;
     if ($rowdata_ref->{biosequence_name} =~ /Gene:(.+)$/ ) {
       $rowdata_ref->{biosequence_gene_name} = $1;
     }
  } elsif ($rowdata_ref->{biosequence_name} =~ /^(CG.+)/ ) { ## updated parse
     $rowdata_ref->{biosequence_name} = $1;
     $rowdata_ref->{biosequence_accession} = $1;
     if ($rowdata_ref->{biosequence_name} =~ /(CG\d+)/ ) {
       $rowdata_ref->{biosequence_gene_name} = $1;
     }
     $rowdata_ref->{dbxref_id} = '25';
  }

  #### Conversion rules for the SGD yeast orf fasta
  ## >YAL003W EFB1 SGDID:S0000003, Chr I from 142176-142255,142622-143162, Verified ORF
  if ($rowdata_ref->{biosequence_desc} =~ /^(\S+)\s(SGDID:.*)$/ ) {
     $rowdata_ref->{biosequence_gene_name} = $1;
     $rowdata_ref->{biosequence_accession} = $rowdata_ref->{biosequence_name};
     $rowdata_ref->{dbxref_id} = '5';
  }


  #### Conversion rules for the IPI database
  if ($rowdata_ref->{biosequence_name} =~ /^IPI:(IPI[\d\.]+)$/ ) {
     $rowdata_ref->{biosequence_accession} = $1;
     if ($rowdata_ref->{biosequence_name} =~ /^IPI:(IPI[\d]+)\.\d+$/ ) {
       #$rowdata_ref->{biosequence_gene_name} = $1;
     }
     $rowdata_ref->{dbxref_id} = '9';
  }


  #### Conversion rules for the new IPI database
  if ($rowdata_ref->{biosequence_name} =~ /^(IPI[\d\.]+)$/ ) {
     $rowdata_ref->{biosequence_accession} = $1;
     #$rowdata_ref->{biosequence_gene_name} = $1;
     $rowdata_ref->{dbxref_id} = '9';
  }

  #### Conversion rules for the new IPI database 2 (dreiss)
  if ($rowdata_ref->{biosequence_name} =~ /^IPI:(IPI[\d\.]+)\|/ ) {
     $rowdata_ref->{biosequence_accession} = $1;
     #$rowdata_ref->{biosequence_gene_name} = $1;
     $rowdata_ref->{dbxref_id} = '9';
  }


  #### Conversion rules for some generic GenBank IDs  
  if ($rowdata_ref->{biosequence_name} =~ /gb\|([A-Z\d\.]+)\|/ ) {
     #$rowdata_ref->{biosequence_gene_name} = $1;
     $rowdata_ref->{biosequence_accession} = $1;
     $rowdata_ref->{dbxref_id} = '7';
  }
  #### Conversion rules for some generic GenBank IDs
  if ($rowdata_ref->{biosequence_name} =~ /gi\|(\d+)\|/ ) {
     $rowdata_ref->{biosequence_accession} = $1;
     $rowdata_ref->{dbxref_id} = '12';
  }

  #### Special Conversion rules for yeast orf names from GB (dreiss)
  if ($rowdata_ref->{biosequence_desc} =~ /\s(\S+)p\s\[Saccharomyces cerevisiae/ ) {
      $rowdata_ref->{biosequence_gene_name} = $1;
  }

  # Process bioseq names with more than one pipe in them - probably not desirable.
#  if ( $rowdata_ref->{biosequence_name} =~ /\|*\|/ ) { 
#    my @pieces = split( /\|/, $rowdata_ref->{biosequence_name}, -1 );
#    if ( length($pieces[0]) < 4 || ($pieces[0] =~ /DECOY/i && length($pieces[0]) < 10) ) { 
#      $rowdata_ref->{biosequence_accession} = join( "|", @pieces[0,1] );
#      $rowdata_ref->{biosequence_desc} ||= join( "|", @pieces );
#    } else {
#      $rowdata_ref->{biosequence_accession} = $pieces[0];
#      $rowdata_ref->{biosequence_desc} ||= join( "|", @pieces );
#    }
#  }

  #### Special conversion rules for Haloarcula
  #### >hmvng0001	rrnAC1199-1066585_1069440
  if ($biosequence_set_name eq "Haloarcula Proteins") {
      if ($rowdata_ref->{biosequence_desc} =~ /^(.+)-(\d+)_(\d+)(\sGenbank_ID=\"(\d+)\")?$/) {
	  my $gene_tag = $1;
	  $rowdata_ref->{former_names} = $rowdata_ref->{biosequence_name};
	  $rowdata_ref->{biosequence_name} = $1;
	  $rowdata_ref->{gene_symbol} = $1;
	  $rowdata_ref->{full_gene_name} = $1;
	  $rowdata_ref->{biosequence_gene_name} = $gene_tag;
	  $rowdata_ref->{start_in_chromosome} = $2;
	  $rowdata_ref->{end_in_chromosome} = $3;
	  if ($gene_tag =~ /^(rrnAC)/) {
	    $rowdata_ref->{chromosome} = $1;
	  } elsif ($gene_tag =~ /^(rrnB)/) {
	    $rowdata_ref->{chromosome} = $1;
	  } elsif ($gene_tag =~ /^(pNG\d)/) {
	    $rowdata_ref->{chromosome} = $1.'00';
	  } else {
	    print "WARNING: Unable to parse gene_tag '$gene_tag'\n";
	  }
	  

	  if ($rowdata_ref->{biosequence_desc} =~ /.*Genbank_ID=\"(\d+)\"/) {
		$rowdata_ref->{biosequence_accession} = $1;
	  }else {
		$rowdata_ref->{biosequence_accession} = "";
	  }
	  $rowdata_ref->{dbxref_id} = '36';

      } else {
	print "WARNING: The following description cannot be parsed:\n  ==".
	  $rowdata_ref->{biosequence_desc}."==\n";
      }

  }

 
  #### Special conversion rules for Haloarcula Genes
  #### >png1001 pNG100 817 170
  if ($biosequence_set_name eq "haloarcula open reading frames" || 
      $biosequence_set_name eq "halobacterium open reading frames") {
      if ($rowdata_ref->{biosequence_desc} =~ /^(.+)\s(\d+)\s(\d+)$/) {
	  my $gene_tag = $rowdata_ref->{biosequence_name};

      if($3 > $2) {
		$rowdata_ref->{strand} = 'F';
      }else{
        $rowdata_ref->{strand} = 'R';
	  }

	  $rowdata_ref->{start_in_chromosome} = $2;
	  $rowdata_ref->{end_in_chromosome} = $3;
	  $rowdata_ref->{chromosome} = $1;
	  unless($1) {
	    print "Chromosome not found: $1\n";
	  }
	  $rowdata_ref->{biosequence_accession} = $gene_tag;
          #$rowdata_ref->{dbxref_id} = '24';

      } else {
	      print "WARNING: The following description cannot be parsed:\n  ==".
	      $rowdata_ref->{biosequence_desc}."==\n";
      }
  }

  #### Special conversion rules for Halobacterium halo_ORFs.fasta
  #### >VNG0021H common_name="VNG0021H" Genbank_ID="15789357" COG_ID="COG3436" location="Chromosome 16342 17706";VNG5087H common_name="VNG5087H" aliases="H0698,H1655,VNG7063,VNG7146" location="pNRC100 63303 64667";VNG5210H common_name="VNG5210H" location="pNRC100 160086 158722";VNG6084H common_name="VNG6084H" Genbank_ID="16120048" COG_ID="COG3436" location="pNRC200 63303 64667";VNG6442H common_name="VNG6442H" Genbank_ID="16120314" COG_ID="COG3436" location="pNRC200 334165 332801";
  if ($biosequence_set_name eq "Halobacterium ORFs" ||
	  $biosequence_set_name eq "Halobacterium Proteins") {
	my @redundant_orfs = split ";", $rowdata_ref->{biosequence_desc};

	$rowdata_ref->{biosequence_desc} = $redundant_orfs[0];

	# get ORF name
	$rowdata_ref->{full_gene_name} = $rowdata_ref->{biosequence_name};
	
	# get common name
	if ($redundant_orfs[0] =~ /common_name=\"(.*?)\"/) {
	  my $common_name = $1;
	  $rowdata_ref->{biosequence_gene_name} = $common_name;
	  $rowdata_ref->{gene_symbol} = $common_name; 
	}

	# get function
	if ($redundant_orfs[0] =~ /function=\"(.*?)\"/){
	  $rowdata_ref->{functional_description}= $1;
	}

	# get comment
	if ($redundant_orfs[0] =~ /comments=\"(.*?)\"/){
	  $rowdata_ref->{comment}= $1;
	}

	# get location
	$redundant_orfs[0] =~ /location=\"(\w+)\s(\d+)\s(\d+)\"/;
	$rowdata_ref->{chromosome} = $1;
	$rowdata_ref->{start_in_chromosome} = $2;
	$rowdata_ref->{end_in_chromosome} = $3;

	# get aliases
	my @aliases;
	if ($redundant_orfs[0] =~ /common_name=\"(.*?)\"/) {
	  push @aliases, $1;
	}
	if ($redundant_orfs[0] =~ /Genbank_ID=\"(.*?)\"/) {
	  my $id = $1;
	  $rowdata_ref->{dbxref_id} = '36';
	  $rowdata_ref->{biosequence_accession} = $id;
	  push @aliases, $id;
	}
	if ($redundant_orfs[0] =~ /COG_ID=\"(.*?)\"/) {
	  push @aliases, $1;
	}
	if ($redundant_orfs[0] =~ /aliases=\"(.*?)\"/) {
	  push @aliases, $1;
	}
	if (@aliases) {
	  $rowdata_ref->{aliases} = join ",", @aliases;
	}

	# identify redundant VNG names
	my @red_orf_names;
	foreach my $red_orf (@redundant_orfs) {
	  if ($red_orf =~ /^(VNG\d{4}\w\w?)/) {
		push @red_orf_names, $1;
	  }
	}
	if (@red_orf_names) {
	  $rowdata_ref->{duplicate_biosequences} = join ",", @red_orf_names;
	}
  }


  #### Special conversion rules for Halobacterium HALOprot_clean.fasta
  #### >VNG1023c chp-1013_1023-1023
#  if ($biosequence_set_name eq "Halobacterium Proteins") {
#    $rowdata_ref->{biosequence_accession} = $rowdata_ref->{biosequence_name};
#  }



  #### Special conversion rules for Halobacterium
  #### >gabT   , from VNG6210g 
  if ($biosequence_set_name eq "Halo Biosequences") {
      if ($rowdata_ref->{biosequence_desc} =~ /from (\S+)/) {
	  my $temp_gene_name = $1;
	  $rowdata_ref->{biosequence_gene_name} = $rowdata_ref->{biosequence_name};
	  delete($rowdata_ref->{biosequence_name}); #delete old name
	  $rowdata_ref->{biosequence_name} = $temp_gene_name; #add new name
      }

  }


  #### Special conversion rules for Halobacterium
  #### >VNG1667G_cdc48c CDCH_HALN1 (Q9HPF0) CdcH protein
  if ($biosequence_set_name eq "halo092602_pA") {
    $rowdata_ref->{biosequence_gene_name} = $rowdata_ref->{biosequence_name};
    $rowdata_ref->{biosequence_accession} = $rowdata_ref->{biosequence_name};
    if ($rowdata_ref->{biosequence_desc} =~ /([\w_]+_HALN1)/) {
      $rowdata_ref->{biosequence_gene_name} = $1;
      $rowdata_ref->{biosequence_accession} = $1;
      $rowdata_ref->{dbxref_id} = '1';
    } elsif ($rowdata_ref->{biosequence_desc} =~ /\((\w+?)\)/) {
      $rowdata_ref->{biosequence_gene_name} = $1;
      $rowdata_ref->{biosequence_accession} = $1;
      $rowdata_ref->{dbxref_id} = '1';
    } else {
      $rowdata_ref->{dbxref_id} = '17';
    }
  }


  #### Special conversion rules for new Halobacterium proteins
  #### >VNG0008G graD5;Glucose-1-phosphate thymidylyltransferase
  if ($biosequence_set_name =~ "Halobacterium-20") {
    $rowdata_ref->{biosequence_accession} = $rowdata_ref->{biosequence_name};
    $rowdata_ref->{dbxref_id} = '12';
    if ($rowdata_ref->{biosequence_desc} =~ /(.+?);(.+)/) {
      $rowdata_ref->{biosequence_gene_name} = $1;
      $rowdata_ref->{dbxref_id} = '1';
    }
  }


  #### Special conversion rules for Drosophila genome R2, e.g.:
  #### >Scr|FBgn0003339|CT1096|FBan0001030 "transcription factor" mol_weight=44264  located on: 3R 84A6-84B1; 
  if ($biosequence_set_name eq "Drosophila aa_gadfly Protein Database R2" ||
      $biosequence_set_name eq "Drosophila na_gadfly Nucleotide Database R2") {
    @other_names = split('\|',$rowdata_ref->{biosequence_name});
    $n_other_names = scalar(@other_names);
    if ($n_other_names > 1) {
       $rowdata_ref->{biosequence_gene_name} = $other_names[0];
       $rowdata_ref->{biosequence_accession} = $other_names[1];
       $rowdata_ref->{dbxref_id} = '2';
       $rowdata_ref->{biosequence_desc} =~ s/^\s+//;
    }
  }

  #### Special conversion rules for Drosophila genome R3, e.g.:
  #### >Scr|FBgn0003339|CT1096|FBan0001030 "transcription factor" mol_weight=44264  located on: 3R 84A6-84B1; 
  if ($biosequence_set_name eq "Drosophila aa_gadfly Protein Database R3 Non-redundant" ||
      $biosequence_set_name eq "Drosophila aa_gadfly Protein Database R3 Original" ||
      $biosequence_set_name eq "Drosophila na_gadfly Nucleotide Database R3") {

    if ($rowdata_ref->{biosequence_desc} =~
                      /gene_info:\[.*gene symbol:(\S+) .*?(FBgn\d+) /) {
       #print "******\ndesc: $rowdata_ref->{biosequence_desc}\n1: $1\n2: $2\n*****\n";
       $rowdata_ref->{biosequence_gene_name} = $1;
       $rowdata_ref->{biosequence_accession} = $2;
       $rowdata_ref->{dbxref_id} = '2';
    } else {
       $rowdata_ref->{biosequence_gene_name} = undef;
       $rowdata_ref->{biosequence_accession} = undef;
       $rowdata_ref->{dbxref_id} = undef;
    }
  }


  #### Special conversion rules for Drosophila genome R3 genome, e.g.:
  if ($biosequence_set_name eq "Drosophila genome_gadfly Nucleotide Database R3") {
    $rowdata_ref->{biosequence_accession} = $rowdata_ref->{biosequence_name};
  }


  #### Special conversion rules for Human Contig, e.g.:
  #### >Contig109 fasta_990917.300k.no_chimeric_4.Contig38095 1 767 REPEAT: 15 318 REPEAT: 320 531 REPEAT: 664 765


  #### Special conversion rules for NRP, e.g.:
  #### >SWN:AAC2_MOUSE Q9ji91 mus musculus (mouse). alpha-actinin 2 (alpha actinin skeletal muscle isoform 2) (f-actin cross linking protein). 8/2001


  #### Special conversion rules for Human NCI, e.g.:
  #### >SWN:3BP1_HUMAN Q9y3l3 homo sapiens (human). sh3-domain binding protein 1 (3bp-1). 3/2002 [MASS=66765]
  #### >SW:AKA7_HUMAN O43687 homo sapiens (human). a-kinase anchor protein 7 (a-kinase anchor protein 9 kda). 5/2000 [MASS=8838]
  #### >PIR1:SNHUC3 multicatalytic endopeptidase complex (EC 3.4.99.46) chain C3 - human [MASS=25899]
  #### >PIR2:S17526 aconitate hydratase (EC 4.2.1.3) - human (fragments) [MASS=6931]
  #### >PIR4:T01781 probable pol protein pseudogene - human (fragment) [MASS=13740]
  #### >GPN:AF345332_1 Homo sapiens SWAN mRNA, complete cds; SH3/WW domain anchor protein in the nucleus. [MASS=97395]
  #### >GP:AF119839_1 Homo sapiens PRO0889 mRNA, complete cds; predicted protein of HQ0889. [MASS=6643]
  #### >GP:BC001812_1 Homo sapiens, clone IMAGE:2959521, mRNA, partial cds. [MASS=5769]
  #### >3D:2clrA HUMAN CLASS I HISTOCOMPATIBILITY ANTIGEN (HLA-A 0201) COMPLEXED WITH A DECAMERIC [MASS=31808]
  #### >TFD:TFDP00561 : HOX 2.2 ((human)) polypeptide [MASS=25574]
  if ($biosequence_set_name eq "Human NCI Database") {
    #### Nothing special, uses generic SW, PIR, etc. encodings above
  }


  #### Special conversion rules for Yeast NCI from regis, e.g.:
  #### SW:ACEA_YEAST P28240 saccharomyces cerevisiae (baker's yeast). isocitrate lyase (ec 4.1.3.1) (isocitrase) (isocitratase) (icl). 2/1996 [MASS=62409]

  if ($biosequence_set_name eq "Yeast NCI Database") {
    #### Nothing special, uses generic SW, PIR, etc. encodings above
  }

  if ($biosequence_set_name eq "ISB Yeast Database") {
      $rowdata_ref->{biosequence_gene_name} = $rowdata_ref->{biosequence_name};
  }

  #### Special conversion rules for Yeast genome, e.g.:
  #### >ORFN:YAL014C YAL014C, Chr I from 128400-129017, reverse complement
  if ($biosequence_set_name eq "yeast_orf_coding" ||
      $biosequence_set_name eq "Yeast ORFs Database" ||
      $biosequence_set_name eq "Yeast ORFs Common Name Database" ||
      $biosequence_set_name eq "Yeast ORF Proteins" ||
      $biosequence_set_name eq "Yeast ORFs Database 2003-12-17" ||
      $biosequence_set_name eq "Yeast ORFs Database 200210" ||
      $biosequence_set_name eq "Yeast ORFs Database 20040422") {
    if ($rowdata_ref->{biosequence_desc} =~ /([\w\-\:]+)\s([\w\-\:]+), .+/ ) {
      if ($biosequence_set_name eq "Yeast ORFs Common Name Database" ||
          $biosequence_set_name eq "Yeast ORFs Database 200210" ) {
        $rowdata_ref->{biosequence_gene_name} = $rowdata_ref->{biosequence_name};
        #$rowdata_ref->{biosequence_accession} = $1;
        $rowdata_ref->{biosequence_accession} = $rowdata_ref->{biosequence_name};
      } else {
        $rowdata_ref->{biosequence_gene_name} = $1;
        #$rowdata_ref->{biosequence_accession} = $rowdata_ref->{biosequence_name};
        $rowdata_ref->{biosequence_accession} = $1;
      }
      $rowdata_ref->{dbxref_id} = '5'; 
    }
  }


  #### Conversion Rules for SGD:
  #### >ORFN:YAL001C TFC3 SGDID:S0000001, Chr I from 147591-147660,147751-151163, reverse complement
  if ($biosequence_set_name eq "SGD Yeast ORF Database"){
    if ($rowdata_ref->{biosequence_desc} =~ /([\w-]+)\sSGDID\:([\w-]+), .+/ ) {
	$rowdata_ref->{biosequence_gene_name} = $1;
	$rowdata_ref->{biosequence_accession} = $2;
	$rowdata_ref->{dbxref_id} = '5';
    }
  }

  #### Special conversion rules for DQA, DBQ, DRB exons, e.g.:
  #### >DQB1_0612_exon1
  if ($biosequence_set_name =~ /Allelic exons/) {
    if ($rowdata_ref->{biosequence_name} =~ /^([A-Za-z0-9]+)_/ ) {
       $rowdata_ref->{biosequence_gene_name} = $1;
    }
    $rowdata_ref->{biosequence_desc} = $rowdata_ref->{biosequence_name};
  }

  #### Special conversion rules for Halobacterium genome, e.g.:
  #### >gene-275_2467-rpl31e
  if ($biosequence_set_name eq "halobacterium_orf_coding") {
    if ($rowdata_ref->{biosequence_name} =~ /-(\w+)$/ ) {
       $rowdata_ref->{biosequence_gene_name} = $1;
   }
  }

  #### Special conversion rules for Human FASTA file, e.g.:
  ####>ACC:AA406372|zv10c10.s1 Soares_NhHMPu_S1 Homo sapiens cDNA clone IMAGE:753234 3' similar to gb:X59739_rna1 ZINC FINGER X-CHROMOSOMAL PROTEIN (HUMAN );, mRNA sequence.
  if ($biosequence_set_name eq "Human BioSequence Database") {
    if ($rowdata_ref->{biosequence_name} =~ /^ACC\:([\w-]+)\|/) {
	$rowdata_ref->{biosequence_gene_name} = $1;
	$rowdata_ref->{biosequence_accession} = $1;
	$rowdata_ref->{dbxref_id} = '8';
    }
  }

  #### Special conversion rules for Human genome, e.g.:
  #### >gnl|UG|Hs#S35 Human mRNA for ferrochelatase (EC 4.99.1.1) /cds=(29,1300) /gb=D00726 /gi=219655 /ug=Hs.26 /len=2443
  if ($biosequence_set_name eq "Human unique sequences") {
    if ($rowdata_ref->{biosequence_desc} =~ /\/gi=(\d+) / ) {
       $rowdata_ref->{biosequence_accession} = $1;
    }
    if ($rowdata_ref->{biosequence_name} =~ /\|(Hs\S+)$/ ) {
       $rowdata_ref->{biosequence_gene_name} = $1;
    }
  }


  #### Conversion Rules for ATH1.pep (TAIR):
  #### >At1g79800.1 hypothetical protein   /  contains similarity to phytocyanin/early nodulin-like protein GI:4559346 from [Arabidopsis thaliana]
  if ($biosequence_set_name eq "Arabidopsis Protein Database") {
    $rowdata_ref->{biosequence_gene_name} = $rowdata_ref->{biosequence_name};
    $rowdata_ref->{biosequence_accession} = $rowdata_ref->{biosequence_name};
    $rowdata_ref->{dbxref_id} = '10';
  }

  #### Conversion Rules for ATH1.pep.2004061 (TIGR R5, Jan 2004):
  #### >At1g79800.1 hypothetical protein   /  contains similarity to phytocyanin/early nodulin-like protein GI:4559346 from [Arabidopsis thaliana]
  if ($biosequence_set_name eq "Arabidopsis Protein Database R5") {
    $rowdata_ref->{biosequence_gene_name} = $rowdata_ref->{biosequence_name};
    $rowdata_ref->{biosequence_accession} = $rowdata_ref->{biosequence_name};
    $rowdata_ref->{dbxref_id} = '10';
  }


  #### Conversion Rules for wormpep92 (C Elegans):
  #### >B0285.7 CE00646   Aminopeptidase status:Partially_confirmed SW:P46557 protein_id:CAA84298.1
  if ($biosequence_set_name eq "C Elegans Protein Database") {
    $rowdata_ref->{biosequence_gene_name} = $rowdata_ref->{biosequence_name};
    if ($rowdata_ref->{biosequence_desc} =~ /^(\S+)\s+(.+)/ ) {
      $rowdata_ref->{biosequence_accession} = $1;
      $rowdata_ref->{dbxref_id} = '11';
    }
  }


  #### If there's favored codon frequency lookup information, set it
  if (defined($fav_codon_frequency)) {
    if ($fav_codon_frequency->{$rowdata_ref->{biosequence_name}}) {
      $rowdata_ref->{fav_codon_frequency} =
        $fav_codon_frequency->{$rowdata_ref->{biosequence_name}};
    }
  }


#  #### If there's n_transmembrane_regions lookup information, set it
#  if (defined($n_transmembrane_regions)) {
#    if ($n_transmembrane_regions->{$rowdata_ref->{biosequence_name}}) {
#      $rowdata_ref->{n_transmembrane_regions} =
#	 $n_transmembrane_regions->{$rowdata_ref->{biosequence_name}}->
#	   {n_tmm};
#    }
#  }
#
#
#  #### If the calc_n_transmembrane_regions flag is set, do the calculation
#  if (defined($OPTIONS{"calc_n_transmembrane_regions"}) &&
#      defined($rowdata_ref->{biosequence_seq}) &&
#      $rowdata_ref->{biosequence_seq} ) {
#    $rowdata_ref->{n_transmembrane_regions} = 
#      SBEAMS::Proteomics::Utilities::calcNTransmembraneRegions(
#	 peptide=>$rowdata_ref->{biosequence_seq},
#	 calc_method=>'NewMethod');
#  }


}

#+
# @narg filename     Name of file to read.  Required.
# @narg acc_regex    Regex to parse out accession.
# @narg verbose      Print stats about file
#
#-
sub read_fasta_file {
  my $self = shift;
  my %args = ( acc_regex => ['\>(\S*)'],
               verbose => 0,
               @_ );

  my $missing;
  for my $arg ( qw( filename ) ) {
    $missing = ( $missing ) ? $missing . ',' . $arg : $arg if !defined $args{$arg};
  }
  die "Missing required parameter(s) $missing" if $missing;

  if ( ref( $args{acc_regex} ) ne 'ARRAY' ) {
    die "acc_regex must be ref to array of regexes...";
  }

  open FIL, "$args{filename}" || die "Unable to open file $args{filename}";
  my %entries;
  my $acc;
  my %seq;
  my $accumulator = '';
  my $line_cnt = 0;
  while ( my $line = <FIL> ) {
    $line_cnt++;
    chomp( $line );

    if ( $line =~ /^>/ ) {
      # If we've already been through, record entry 
      if( $accumulator ) {
        # Print and reset accumulated sequence.
        $entries{$acc} = $accumulator;
        $seq{$accumulator}++;
        $accumulator = '';
        $acc = '';
      }

      # Extract accession.
      for my $regex ( @{$args{acc_regex}} ) {
        if ( $line =~ /$regex/ ) {
          $acc = $1;
          $acc .= " $2" if $2;
          $acc .= " $3" if $3;
        }
        last if $acc;
      }
      if ( !$acc ) {
        print STDERR "Problem extracting accession from $line with $args{acc_regex}\n";
        $acc = $line;
        $acc =~ s/\^>//g;
      }

      if ( $entries{$acc} ) {
        print STDERR "doppelganger accession $acc\n";
        exit;
      }
    next;
    }
    $line =~ s/\s//g;
    $accumulator .= $line;
  }
  close FIL;

  # Last line
  $entries{$acc} = $accumulator;
  $seq{$accumulator}++;
  $accumulator = '';

  if ( $args{verbose} ) {
    print "Found " . scalar( keys( %entries ) ) . " distinct accessions\n";
    print "Found " . scalar( keys( %seq ) ) . " distinct sequences\n";

#    for my $k( keys( %seq ) ) { print STDERR "$k\n"; }
  }
  
  return \%entries;
}

#+
# @narg    file       Req'd, formatted file to open
# @narg    delimier   Delimiter on which to split input lines, defaults to "\t";
# @narg    acc_idx    Req'd, 0-based index of accession column.  Data returned as reference
#                     to hash keyed by index, each entry is a ref to an array of row arrayrefs
# @narg    val_idx    Ref to array of col indexes, will return just those in row arrayrefs (not all)
# @narg    lookup     Indicates file is a one-to-one lookup with [0] -> [1].  If there are duplicated
#                     accessions (column 0) the routine will die().
# @narg    key_limit  Array ref, will cache only accession which are represented.
#-
sub read_file {
  my $self = shift;
  my %args = ( delimiter => "\t", @_ );
  for my $arg ( qw( file acc_idx ) ) {
    die "missing required argument $arg\n" unless defined $args{$arg};
  }

  open FIL, $args{file} || die;
  my %contents;
  my $cnt = 0;
  while ( my $line = <FIL> ) {
    chomp $line;
    next if !$cnt++ && $args{header};
    next if $line =~ /^\s*$/; # skip blanks

    my @line = split( $args{delimiter}, $line, -1);

    # Should be one to one, short circuit
    if ( $args{lookup} ) {
      die "bad lookup!" if $contents{$line[0]};
      $contents{$line[0]} = $line[1];
      next;
    }

    my $acc = $line[$args{acc_idx}];

    if ( $args{key_limit} ) {
      next unless $args{key_limit}->{$acc};
    }

    $contents{$acc} ||= [];
    if ( defined $args{val_idx} ) {
      push @{$contents{$acc}}, [@line[@{$args{val_idx}}]];
    } else {
      push @{$contents{$acc}}, \@line;
    }


  }
  my $contents_cnt = scalar( keys( %contents ) );
  print STDERR "read $cnt entries, hashed $contents_cnt unique keys\n" if $args{verbose};
  close FIL;
  return \%contents;
} # end read_file


#######################################################################
# sendEmail
#######################################################################
sub sendEmail {
  my %args = @_;
  my $SUB_NAME = 'sendEmail';

  #### Decode the argument list
  my $toRecipients = $args{'toRecipients'} || die "[$SUB_NAME] ERROR: toRecipients  not passed";
  my $ccRecipients = $args{'ccRecipients'} || die "[$SUB_NAME] ERROR: ccRecipients not passed";
  my $bccRecipients = $args{'bccRecipients'} || die "[$SUB_NAME] ERROR: bccRecipients not passed";
  my $subject = $args{'subject'} || die "[$SUB_NAME] ERROR: subject not passed";
  my $message = $args{'message'} || die "[$SUB_NAME] ERROR: message not passed";

  my @toRecipients = @{$toRecipients};
  my @ccRecipients = @{$ccRecipients};
  my @bccRecipients = @{$bccRecipients};

  my $toLine = '';
  my $ccLine = '';
  my $recipients = '';

  #### Process recipients in the To: part
  for (my $i=0; $i<scalar(@toRecipients); $i+=2) {
    my $j = $i+1;
    $toLine .= " $toRecipients[$i] <$toRecipients[$j]>,";
    $recipients .= "$toRecipients[$j],";
  }

  #### Process recipients in the Cc: part
  if (scalar(@ccRecipients) > 1) {
    for (my $i=0; $i<scalar(@ccRecipients); $i+=2) {
      my $j = $i+1;
      $ccLine .= " $ccRecipients[$i] <$ccRecipients[$j]>,";
      $recipients .= "$ccRecipients[$j],";
    }
  }

  #### Process recipients in the Bcc: part
  if (scalar(@bccRecipients) > 1) {
    for (my $i=0; $i<scalar(@bccRecipients); $i+=2) {
      my $j = $i+1;
      $recipients .= "$bccRecipients[$j],";
    }
  }

  #### Remove trailing commas
  chop($toLine);
  chop($ccLine);
  chop($recipients);

  #### Create message
  my $content = '';
  $content .= "From: PeptideAtlas Agent <sbeams\@systemsbiology.org>\n";
  $content .= "To:$toLine\n";
  $content .= "Cc:$ccLine\n" if ($ccLine);
  $content .= "Reply-to: PeptideAtlas Agent <sbeams\@systemsbiology.org>\n";
  $content .= "Subject: $subject\n\n";
  $content .= $message;

  if (1) {
    my $mailprog = "/usr/lib/sendmail";
    open (MAIL, "|$mailprog $recipients") || die("Can't open $mailprog!\n");
    print MAIL $content;
    close (MAIL);
  } else {
    print $content;
  }

  return(1);
}

sub time_stmt {
  my $self = shift;
  my $msg = shift || '';
  $self->{_previous_stmt_time} ||= 0;
  my $curr_time = time;
  my $delta = 'n/a';
  if ( $self->{_previous_stmt_time} ) {
    $delta = $curr_time - $self->{_previous_stmt_time};
  }
  $self->{_previous_stmt_time} = $curr_time;
  $log->info( join( "\t", $delta, $msg ) );
}

1;


###############################################################################
###############################################################################
###############################################################################

=head1 SBEAMS::Connection::Utilities

A part of the SBEAMS module containing generic utility methods not logically
placed in one of the standard pm's.

=head2 SYNOPSIS

See SBEAMS::Connection and individual methods for usage synopsis.

=head2 DESCRIPTION

This part of the SBEAMS module containing generic utility methods not logically
placed in one of the standard pm's.

=head2 METHODS

=over

=item * B<histogram( see key value input parameters below )>

    Given an array of numbers, calculate a histogram and various other
    statistcs for the array.  All results are returned numerically; no
    image or plot of the histogram is created.

    INPUT PARAMETERS:

      data_array_ref => Required array reference containing the input data
      for which a histogram and statistics are calculated.

      min => Minimum edge of the first bin of the histogram.  If none
      is supplied, a suitable one is chosen.

      max => Maximum edge of the last bin of the histogram?  If none
      is supplied, a suitable one is chosen.

      bin_size => Width of the bins for the histogram.  If none
      is supplied, a suitable one is chosen based on the number of
      data points in the input array; the more data points there are,
      the finer the bin size.


    OUTPUT:

      A hash reference containing all resulting data from the calculation.
      The hash keys are as follows:

        result = SUCCESS or FAILED

        xaxis = Array ref of lower edge of the output histogram ordinate values

        xaxis_disp = Same as xaxis but with minor tick bin labels
        blanked out for use by a histogram display program

        yaxis = Array ref of the number of original array values that
        fall into each bin, corresponding to xaxis

        cdf = Array ref containing the Cumulative Distribution
        Function (CDF) values corresponding to xaxis.  This is
        essentially the count of all data array elements in this bin and
        below.

        n_bins = Scalar number of bins in the histogram

        bin_size = Size of the bins in the histogram, either user
        specified or determined automatcally

        histogram_min = Minimum edge of the first bin of the histogram

        histogram_max = Maximum edge of the last bin of the histogram?

        minimum = Minimum numeric value in the input data array

        maximum = Maximum numeric value in the input data array

        total = Sum of all values in the input data array

        n_elements = Number of elements in the input data array

        mean = Mean (average) value of the elements in the input data array

        stdev = Standard deviation of the values in the input data array

        median = Median value in the input data array (the smallest
        50% of values have value this or less)

        quartile1 = First quartile value of the input data array (the smallest
        25% of values have value this or less)

        quartile3 = Third quartile value of the input data array (the smallest
        75% of values have value this or less)

        SIQR = Semi-interquartile Range (SIRQ) is half of the difference between
        quartile3 and quartile1.  SIQR is analogous to the standard deviation
        but relatively insensitive to outliers (like median is to mean).

        ordered_statistics = Array ref a the list of the scalar
        statistics returned in the hash, in a vaguely logical order,
        suitable for use for dumping out the all returned statistics.



=item * B<find_nearest( $map_array_ref, $value )>

    This internal method is used by histogram to determine round min, max,
    bin_size numbers.  It is a pretty icky function that could stand some
    rewriting to work more generically and better.

    See the histogram() function for usage example

    INPUT PARAMETERS:

      $map_array_ref: Array ref of ordered list of "round" numbers.  An example
      may be [0.25,0.5,1,2,5,10,15,20,25,50,75,100]

      $value: Scalar value which is to be rounded with the supplied array

    OUTPUT:

      The largest value in $map_array_ref that is smaller than $value or the
      end value if $value is out of bounds.


=back

=head2 BUGS

Please send bug reports to the author

=head2 AUTHOR

Eric Deutsch <edeutsch@systemsbiology.org>

=head2 SEE ALSO

SBEAMS::Connection

=cut
