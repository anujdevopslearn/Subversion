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


my $mass = $helper->getMass("C");
if ( abs($mass - 103.01) > 0.2) {
     print "failed\n";
}


my @modAAs = $helper->getModifiedAAs("C[330]AT");
if ( $#modAAs != 2) {
    print "failed\n";
}
if ($modAAs[0] ne "C[330]") {
    print "failed\n";
}
if ($modAAs[1] ne "A") {
    print "failed\n";
}
if ($modAAs[2] ne "T") {
    print "failed\n";
}


@modAAs = $helper->getModifiedAAs("AC[330]AT");
if ( $#modAAs != 3) {
    print "failed\n";
}
if ($modAAs[0] ne "A") {
    print "failed\n";
}
if ($modAAs[1] ne "C[330]") {
    print "failed\n";
}
if ($modAAs[2] ne "A") {
    print "failed\n";
}
if ($modAAs[3] ne "T") {
    print "failed\n";
}


@masses = $helper->getMasses("AC[330]AT");
if ( $#masses != 3) {
    print "failed\n";
}
for (my $i = 0; $i <= $#masses; $i++) {
    print "$masses[$i]\n";
}
