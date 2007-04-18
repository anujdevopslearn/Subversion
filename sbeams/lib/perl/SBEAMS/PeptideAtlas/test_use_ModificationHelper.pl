#!/usr/bin/perl

use ModificationHelper;

my $helper = new ModificationHelper();

my @masses = $helper->getMasses("C[330]AT");

if ( $#masses != 2) {
    print "failed\n";
}

my @aa = $helper->getUnmodifiedAAs("C[330]AT");

if ( $#aa != 2) {
    print "failed\n";
}

if ($aa[0] ne "C") {
    print "failed\n";
}
if ($aa[1] ne "A") {
    print "failed\n";
}
if ($aa[2] ne "T") {
    print "failed\n";
}

for (my $i = 0; $i <= $#masses; $i++) {
    print "$masses[$i]\n";
}
