#!/usr/local/bin/perl

###############################################################################
# Program     : getPApFromSequence.pl
# Author      : Sandra Loevenich <loevenich@imsb.biol.ethz.ch>
# 
#
# Description : This script receives a file with a list of Sequences and prints
#               a list of the appropriate PAp numbers (in FastA Format) to STDOUT.
#               If a given sequence does not live in PeptideAtlas, these 
#               Sequences are written to STDERR.
#
#
###############################################################################


###############################################################################
# Generic SBEAMS setup for all the needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;
use DirHandle;
#use lib "$FindBin::Bin/../../perl";
use vars qw ($sbeams $sbeamsMOD $q
             $PROG_NAME $USAGE %OPTIONS
            );

#### Set up SBEAMS core module
use SBEAMS::Connection qw($q);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;
use SBEAMS::Proteomics::Tables;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::PeptideAtlas;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);




#### Set program name and usage banner
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS]
Options:

  --file              name of tsv file with has the sequences as first column 


EOU


#### If no parameters are given, print usage information
unless ($ARGV[0]){
  print "$USAGE";
  exit;
}

#### Process options
unless (GetOptions(\%OPTIONS,"file:s",
  )) {
  print "$USAGE";
  exit;
}


my $file = $OPTIONS{"file"} || '';

unless ($file){
  print "\nINVOCATION ERROR: --file option is missing \n";
  print "\n\n$USAGE";
  exit;
}



###############################################################################
# Set Global Variables and execute main()
###############################################################################


main();
exit(0);


###############################################################################
# Main Program:
###############################################################################
sub main {
  my $SUB_NAME = 'main';

  my (%sequences);

  %sequences = getSequencesFromFile( file => $file );
  
  getPAaccessions( sequences => \%sequences );
   
  for my $string ( keys %sequences ) {
      my $accession = $sequences{$string};

      if ($accession eq "NotInPeptideAtlas"){
	  print STDERR ">$accession\n$string\n";
      }else{
	  print STDOUT ">$accession\n$string\n";
      }
      
  }

} # end main








###############################################################################
# getSequencesFromFile --  returns hash which has the sequences as keys and 
#                          the value is always "NotInPeptideAtlas"
###############################################################################
sub getSequencesFromFile{
    my $SUB = 'getSequencesFromFile';
    my %args = @_;

    my $infile = $args{file} || die "need file ($!)";

    my (%seqs);

    unless ( open INFILE, "< $infile" ) {
        die "Cannot open file $infile ($!)";
    }

    while (<INFILE>) {
        chomp;
        split;
	$seqs{$_[0]}="NotInPeptideAtlas";
    }

    close INFILE;
    return %seqs;
}




###############################################################################
# getPAaccessions
###############################################################################
sub getPAaccessions{
    my $SUB = 'getPAaccessions';
    my %args = @_;

    my $seqref = $args{"sequences"} || die "parameter 'sequences' not passed to $SUB ($!)";

    for my $peptideString ( keys %$seqref) {
	
	my $sql = qq~
	    SELECT P.peptide_accession
	    FROM $TBAT_PEPTIDE P
	    WHERE P.peptide_sequence LIKE '$peptideString'
	    ~;
	my @rows = $sbeams->selectSeveralColumns($sql);

	foreach my $row (@rows) {

	    my $nrAccession = scalar @{$row};

	    if ($nrAccession > 1 ){
		print "Peptide $peptideString has $nrAccession PAp accession numbers associated with it. This should never happen. \n";
		print "\n abort!\n";
		exit;
	    };

	    for my $i (@{$row}) {
		$seqref->{$peptideString} = $i;
#		%$seqref{$peptideString} = $i;
	    }
	}
    }

}





