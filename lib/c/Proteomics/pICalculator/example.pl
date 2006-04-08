#!/usr/local/bin/perl -w

use strict;

use lib "blib/lib";
use lib "blib/arch";

use pICalculator;
my $peptide = "PEPTIDE";
my $result = pICalculator::COMPUTE_PI($peptide,length($peptide),0);
print "pI for peptide '$peptide' is $result\n";

