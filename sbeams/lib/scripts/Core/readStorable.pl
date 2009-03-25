#!/usr/local/bin/perl -w

use strict;
use Storable;
use Data::Dumper;

exit unless $ARGV[0];

my $ret = retrieve( $ARGV[0] ) || '';
if ( !ref $ret ) {
  print $ret;
} elsif ( ref $ret eq 'HASH' ) {
  for my $k ( keys( %$ret ) ) {
    print "$k ===> $ret->{$k}\n";
  }
} elsif ( ref $ret eq 'ARRAY' ) {
  for my $k ( @$ret ) {
    print "$k\n";
  }
}
