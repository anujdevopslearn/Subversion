#!/usr/local/bin/perl

use strict;
use Test::Harness;

runtests( qw(
./Core/transactionTest.t
./Core/sessionTest.t
./Core/biosequenceRegexTest.t
./Core/utilities.t
./Core/SQLTest.t
./Core/CoreTablesTest.t
./Core/ManageTable.t
./Core/authenticationTest.t
./Core/TableInfoTest.t
./BioLink/KGMLTest.t
./BioLink/KEGGMapsTest.t
) );
__DATA__


./Core/transactionTest.t
./Core/sessionTest.t
./Core/biosequenceRegexTest.t
./Core/utilities.t
./Core/SQLTest.t
./Core/CoreTablesTest.t
./Core/ManageTable.t
./Core/authenticationTest.t
./Core/TableInfoTest.t
./BioLink/KGMLTest.t
./BioLink/KEGGMapsTest.t

./PeptideAtlas/General.t
./Proteomics/PeptideMassCalculator.t
./Proteomics/proteomicsProjectControlTest.t
./Proteomics/SQLMethodsTest.t
./Proteomics/TableInfoTest.t
./Glycopeptide/GlycopeptideTest.t ) );

__DATA__
runtests( qw(
./other/transactionTest.t
./other/DBStressTest.t
./Core/transactionTest.t
./Core/biosequenceRegexTest.t
./Core/sessionTest.t
./Core/utilities.t
./Core/SQLTest.t
./Core/CoreTablesTest.t
./Core/authenticationTest.t
./Core/ManageTable.t
./Core/TableInfoTest.t
./PeptideAtlas/General.t
./Proteomics/PeptideMassCalculator.t
./Proteomics/proteomicsProjectControlTest.t
./Proteomics/SQLMethodsTest.t
./Proteomics/TableInfoTest.t
./Glycopeptide/GlycopeptideTest.t ) );

