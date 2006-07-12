package ProtFeatures;
use strict;

use 5.008;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use ProtFeatures ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION = '5.8';



# Preloaded methods go here.

sub new {

    my $class = shift;

    my %args = @_;

    my $self = {};

    $self->{FEATURESFILE} = $args{FEATURESFILE};

    $self->{PROTEINHITSFILE} = $args{PROTEINHITSFILE};

    $self->{PROTEINS} = undef; 

    bless ($self, $class);

    return $self;
}



## set/get method for features file name
sub featuresFile {

    my $self = shift;

    if (@_) { $self->{FEATURESFILE} = shift }

    return $self->{FEATURESFILE};
}



## set/get method for protein hits file name
sub proteinHitsFile {

    my $self = shift;

    if (@_) { $self->{PROTEINHITSFILE} = shift }

    return $self->{PROTEINHITSFILE};
}



## assign coordinate attributes
sub readProteinCoords {

    my $self = shift;


    ## read protein hits file and write proteins to a hash:
    unless ( $self->{PROTEINHITSFILE} ) {

        die "need to set proteinHitsFile";

    }

    my $infile = $self->{PROTEINHITSFILE};

    open(INFILE,"<$infile") or die "Cannot open $infile ($!)";

    my %protH;

    my $line;

    while ($line = <INFILE>) {

        my @columns = split(/\t/,$line);

        $protH{$columns[2]} = $columns[2];

    }

    close(INFILE) or die "Cannot close $infile ($!)";

    print "Finished reading protein hits file\n";



    ##open features file:
    unless ( $self->{FEATURESFILE} ) {

        die "need to set featuresFile";

    }

    $infile = $self->{FEATURESFILE};

    open(INFILE,"<$infile") or die "Cannot open $infile ($!)";
    

    my %indexOfCDS = ();

    while ($line = <INFILE>) {

        my @columns = split(/\t/,$line);

        my $SGDID = $columns[0];

        my $featureType = $columns[1];

        my $featureName = $columns[3];

        my $parentFeature = $columns[6];

        my $featureChrom = $columns[8];

        my $featureChromStart = $columns[9];

        my $featureChromEnd = $columns[10];

        my $strand = $columns[11];

        my $featureChromStrand;


        ## if it's in protH, store it:
        foreach my $prot ( keys %protH ) {

            ## CDS features of a protein:
            if ($parentFeature eq $prot && $featureType eq "CDS" ) {

                ## converting Watson and Crick notation to 1 and -1, respectively:
                if ($strand eq "W") {

                    $featureChromStrand = 1

                } else {

                    $featureChromStrand = -1;

                }


                if ( exists $indexOfCDS{$prot} ) {

                    $indexOfCDS{$prot} = $indexOfCDS{$prot} + 1;

                } else {

                    $indexOfCDS{$prot} = 0;

                }


                my $ind = $indexOfCDS{$prot};

                ## assign object attributes:
                $self->{PROTEINS}{$prot}{chrom} = $featureChrom;

                $self->{PROTEINS}{$prot}{CDS}{$ind}{chromStart} = $featureChromStart;
             
                $self->{PROTEINS}{$prot}{CDS}{$ind}{chromEnd} = $featureChromEnd;

                $self->{PROTEINS}{$prot}{CDS}{$ind}{SGDID} = $SGDID;

                $self->{PROTEINS}{$prot}{strand} = $featureChromStrand;

            }

            ## ORF/protein:
            if ($featureName eq $prot && $featureType eq "ORF") {

                $self->{PROTEINS}{$prot}{chrom} = $featureChrom;

                $self->{PROTEINS}{$prot}{ORF}{chromStart} 
                    = $featureChromStart;

                $self->{PROTEINS}{$prot}{ORF}{chromEnd} 
                    = $featureChromEnd;

                $self->{PROTEINS}{$prot}{ORF}{SGDID} = $SGDID;

                if ($strand eq "W") {

                    $featureChromStrand = 1

                } else {

                    $featureChromStrand = -1;

                }


                $self->{PROTEINS}{$prot}{strand} = $featureChromStrand;


            }

        }
        
    }


    close(INFILE) or die "Cannot close $infile ($!)";
    print "Finished storing features info\n";
    

    return $self->{PROTEINS};
} ## end readProteinCoords



## get orf start in chromosomal coordinates
sub getORFChromStart {

    my $self = shift;

    my $protein = shift;

    return $self->{PROTEINS}{$protein}{ORF}{chromStart};

}



## get orf end in chromosomal coordinates
sub getORFChromEnd {

    my $self = shift;

    my $protein = shift;

    return $self->{PROTEINS}{$protein}{ORF}{chromEnd};

}


## get protein strand 
sub getStrand {

    my $self = shift;

    my $protein = shift;

    return $self->{PROTEINS}{$protein}{strand};

}


## get chromosome 
sub getChrom {

    my $self = shift;

    my $protein = shift;

    return $self->{PROTEINS}{$protein}{chrom};

}


## get number of CDS's in protein
sub getNumberOfCDSs {

    my $self = shift;

    my $protein = shift;

    my $num = keys ( %{$self->{PROTEINS}{$protein}{CDS}} ) + 1;

    return $num;

}




## Calculate coding bps from CDSs 
## (NOTE: if adapting to use Ensembl, have to exclude non-coding regions (UTRs) first)
## (NOTE: if adapting to use Ensembl, looks like start is < end even in reverse strand.  This
## is different in Yeast features file).
sub calcCDSBasePairs {

    my $self = shift;

    foreach my $prot ( keys %{$self->{PROTEINS}} ) {

        my $strand = $self->{PROTEINS}{$prot}{strand};

        my $bpLastCoded = 0; 

        my @cds_keys;

        if ($strand == 1) {

            @cds_keys = sort keys %{$self->{PROTEINS}{$prot}{CDS}};

        } elsif ($strand == -1) { #reverse sort indices

            @cds_keys = reverse sort keys %{$self->{PROTEINS}{$prot}{CDS}};

        }


        foreach my $cds_index ( @cds_keys ) {

            my $startC = $self->{PROTEINS}{$prot}{CDS}{$cds_index}{chromStart};
    
            my $endC = $self->{PROTEINS}{$prot}{CDS}{$cds_index}{chromEnd};
   
            my $deltaBP = abs ( $startC - $endC ) ;
  
            my $startBP = $bpLastCoded + 1;
 
            my $endBP = $deltaBP + $startBP;

            $self->{PROTEINS}{$prot}{CDS}{$cds_index}{bpStart} = $startBP;

            $self->{PROTEINS}{$prot}{CDS}{$cds_index}{bpEnd} = $endBP;

            $bpLastCoded = $endBP;

        } 

    }

    print "Finished calculating coding bps from CDS info\n";

} ## end calcCDSBasePairs


## a toString + print method
sub printCDSInfo {

    my $self = shift;

    my $prot = shift;


    my $strand = $self->{PROTEINS}{$prot}{strand};

    my $chrom = $self->{PROTEINS}{$prot}{chrom};

    my ($startBP, $endBP, $startChrom, $endChrom) = ();

    print "\nprotein: $prot  chromosome: $chrom  strand:  $strand\n";

    printf "    %10s %10s %10s %10s \n", "start[chrom]", "end[chrom]", "start[bp]", "end[bp]";


    foreach my $cds_index (sort keys %{$self->{PROTEINS}{$prot}{CDS}} ) {

       $startBP = $self->{PROTEINS}{$prot}{CDS}{$cds_index}{bpStart};

       $endBP = $self->{PROTEINS}{$prot}{CDS}{$cds_index}{bpEnd};

       $startChrom = $self->{PROTEINS}{$prot}{CDS}{$cds_index}{chromStart};

       $endChrom = $self->{PROTEINS}{$prot}{CDS}{$cds_index}{chromEnd};

       printf "    %10s %10s %10s %10s \n", $startChrom, $endChrom, $startBP, $endBP;

    }

}



## uses protein coord info to convert peptide location in ORF to chromosomal coords
## returns a hash with first level key {index}
##                          second level key{chrom}
##                          second level key{chromStart}
##                          second level key{chromEnd}
##                          second level key{strand}

sub getChromCoordHash{

    my $self = shift;

    my %args = @_;


    my $prot = $args{protein};

    my $pepStart = $args{pepStart} or die "need pepStart in getChromCoordHash";

    my $pepEnd = $args{pepEnd} or die "need pepEnd in getChromCoordHash";

    ## translated ORF contains start codon M, so subtract that from chromStart
    # my $start = (3*$pep_start) - 2 + ($cdna_coding_start - 1); 
    # my $end   = (3*$pep_end)  +      ($cdna_coding_start - 1);

    ## convert to CDS relative base-pair units : 
    my $pepStartBP = ( 3 * $pepStart ) - 2 ;

    my $pepEndBP = ( 3 * $pepEnd );


    my %pepH;


    my $strand = $self->{PROTEINS}{$prot}{strand};

    my $chrom = $self->{PROTEINS}{$prot}{chrom};

    #index will be greater than 0 when peptide spans more than one CD
    # and in that case, we'll be recording the boundaries of CDSs too...
    my $indexofCDSwithPeptide = 0;  

    my @cds_keys;

    if ($strand == 1) {

        @cds_keys = sort keys %{$self->{PROTEINS}{$prot}{CDS}};

    } elsif ($strand == -1) { #reverse sort indices

        @cds_keys = reverse sort keys %{$self->{PROTEINS}{$prot}{CDS}};

    }


    foreach my $cds_index ( @cds_keys ) {

        my $startBP = $self->{PROTEINS}{$prot}{CDS}{$cds_index}{bpStart};

        my $endBP = $self->{PROTEINS}{$prot}{CDS}{$cds_index}{bpEnd};
    
        my $startChrom = $self->{PROTEINS}{$prot}{CDS}{$cds_index}{chromStart};
    
        my $endChrom = $self->{PROTEINS}{$prot}{CDS}{$cds_index}{chromEnd};
    
        my $SGDID = $self->{PROTEINS}{$prot}{CDS}{$cds_index}{SGDID};
    

        my ($pepStartChrom, $pepEndChrom);


        ## tests to see if peptide start and end are in this CDS
        my $x = $pepStartBP;
    
        my $pepStartBP_in_CDS = ( ( $x >= $startBP) && ($x <= $endBP) );
    
        $x = $pepEndBP;
    
        my $pepEndBP_in_CDS = ( ( $x >= $startBP) && ($x <= $endBP) );


        ## should re-do this someday, and have skip to return when finished with end mapping

        ## if pepStart or pepEnd  are in this CDS: (increments index at end)
        if (  $pepStartBP_in_CDS || $pepEndBP_in_CDS ) {


            ## if peptide start and end are in this cds:  checked this...
            if ( $pepStartBP_in_CDS && $pepEndBP_in_CDS ) {
                        
                $pepStartChrom = $startChrom + ( ($pepStartBP - $startBP) * $strand);
                        
                $pepEndChrom   = $startChrom + ( ($pepEndBP   - $startBP) * $strand );

            }

               
            ## if peptide start is in CDS, but end isn't:
            if ( $pepStartBP_in_CDS && !$pepEndBP_in_CDS ) {

                $pepStartChrom = $startChrom + ( ($pepStartBP - $startBP) * $strand);
                
                $pepEndChrom = $endChrom;
                    
            }


            ## if peptide start is not in CDS, but end is, and indexofCDSwithPeptide > 0:
            if ( !$pepStartBP_in_CDS  &&  $pepEndBP_in_CDS && ( $indexofCDSwithPeptide > 0 ) ) {

                $pepStartChrom = $startChrom;

                $pepEndChrom = $endChrom + ( ($pepEndBP - $endBP) * $strand );
                    
            }

            ## and if strand is -1, swap peptide chromosomal coords:
            if ($strand == -1)
            {

                my $tmp = $pepStartChrom;

                $pepStartChrom = $pepEndChrom;

                $pepEndChrom = $tmp;

            } 


            $pepH{$indexofCDSwithPeptide}{chromStart} = $pepStartChrom;

            $pepH{$indexofCDSwithPeptide}{chromEnd} = $pepEndChrom;

            $pepH{$indexofCDSwithPeptide}{chrom} =  $chrom;

            $pepH{$indexofCDSwithPeptide}{strand} =  $strand;

            $pepH{$indexofCDSwithPeptide}{pepStartInORF} =  $pepStart;

            $pepH{$indexofCDSwithPeptide}{pepStartBP} =  $pepStartBP;

            $pepH{$indexofCDSwithPeptide}{pepEndInORF} =  $pepEnd;

            $pepH{$indexofCDSwithPeptide}{pepEndBP} =  $pepEndBP;

            $pepH{$indexofCDSwithPeptide}{protein} = $prot;

            $pepH{$indexofCDSwithPeptide}{SGDID} = $SGDID;

            $indexofCDSwithPeptide++ ;

        }

    }

    return %pepH;
}



1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 ProtFeatures


  Use to convert peptide locations in ORF to chromosomal coordinates
  for yeast organism (Saccharomyces cerevisiae).
  It's suited for SGD protein database and features file.

=head1 SYNOPSIS


    use ProtFeatures;


    Create protein features instance:

        my $proteinFeatures = new ProtFeatures(

            FEATURESFILE => $featuresFileName,
    
            PROTEINHITSFILE => $proteinHitsFileName

        );

 

    Store chrom coordinate info in attributes:

        $proteinFeatures->readProteinCoords();



    Calculate and store coding bps in the translated protein:

        $proteinFeatures->calcCDSBasePairs();



    Convert peptide ORF location to chromosomal coordinates:

        my %peptideHash = $proteinFeatures->getChromCoordHash(

            protein => $protein,

            pepStart => $pep_hit_start,

            pepEnd => $pep_hit_end,

        );

        returns a hash with first level key {index}, second level key{chrom}
                                                     second level key{chromStart}
                                                     second level key{chromEnd}
                                                     second level key{strand}
                                                     second level key{SGDID}




    (NOTE: should probably have readProteinCoords() and calcCDSBasePairs() be
    called internally during new construction...originally, construction didn't
    need file names)



    Miscellaneous:
    --------------

    Print the CDS coordinate info for a protein:
        $proteinFeatures->printCDSInfo( 'YLR367W');


    Print the protein hits file name:
        print $proteinFeatures->proteinHitsFile(), "\n";


    Print the number of CDSs in a protein:
        print $proteinFeatures->getNumberOfCDSs('YLR367W'), "\n";


    Print the start of a protein ORF:
        print $proteinFeatures->getORFChromStart('YLR367W'), "\n";


    Print the strand:
        print $proteinFeatures->getStrand('YLR367W'), "\n";



    Summary of all methods:
    -----------------------

        new (FEATURESFILE =>, PROTEINHITSFILE =>)
  
        readProteinCoords()

        calcCDSBasePairs()

        printCDSInfo(protein)

        getChromCoordHash( protein => , pepStart => , pepEnd =>)

        getORFChromStart(protein)

        getORFChromEnd(protein)

        getStrand(protein)

        getChrom(protein)

        getNumberOfCDSs(protein)

        featuresFile(PROTEINHITSFILE)

        proteinHitsFile(PROTEINHITSFILE)

   

=head1 ABSTRACT

   see above


=head1 DESCRIPTION

  see above

=head2 EXPORT

None by default.



=head1 SEE ALSO

   see script written to use this module: peptideAtlasPipeline_yeast.pl


=head1 AUTHOR

Nichole King, E<lt>nking@localemailaddress<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2004 by Institute for Systems Biology

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
