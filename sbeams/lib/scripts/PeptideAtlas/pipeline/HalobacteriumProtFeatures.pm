package HalobacteriumProtFeatures;
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

sub new 
{
    my $class = shift;

    my %args = @_;

    my $self = {};

    ## reference to hash with key = protein name, value = string of indices
    ## to peptides in the parallel array that have this protein
    $self->{proteinNameHash} = undef;

    ## references to parallel arrays to hold peptide coords
    $self->{pepName} = undef;

    $self->{protName} = undef;

    $self->{pepStartInProt} = undef;

    $self->{pepEndInProt} = undef;

    ## main, plasmid1, plasmid2 where the plasmids are the mini-chromosomes
    $self->{chromName} = undef; 

    $self->{strand} = undef; 

    $self->{pepStartInChrom} = undef;

    $self->{pepEndInChrom} = undef;

    ## the eventual output file needs the other hits vars too, so here
    ## are a few more parallel arrays
    $self->{queryLength} = undef;
    $self->{hitLength} = undef;
    $self->{hitPercentIdentity} = undef;
    $self->{hitDifference} = undef;

    bless ($self, $class);

    return $self;
}


## read formatted peptide hits file
sub readPeptideCoords 
{
    my ($self, $infile) = @_;

    die ("missing argument to readPeptideCoords")
        unless defined $infile;

    open(INFILE,"<$infile") or die "Cannot open $infile ($!)";

    my %proteinNameHash;

    my $line;

    my $index = 0;

    while ($line = <INFILE>) 
    {
        chomp($line);

        my @columns = split(/\t/,$line);

        my $peptide = $columns[0];

        my $protein = $columns[2];
        ## only retaining the VNG names
        $protein =~ s/^(VNG.*)\s(.*)/$1/g;

        ##converting to all caps
        $protein = uc($protein);

        my $startInProt = $columns[5];

        my $endInProt = $columns[6];

        if (exists $proteinNameHash{$protein} )
        {
            $proteinNameHash{$protein} = join( ",", $proteinNameHash{$protein}, "$index");
        } else
        {
            $proteinNameHash{$protein} = "$index";
        }

        push(@{$self->{pepName}}, $peptide);

        push(@{$self->{protName}}, $protein);

        push(@{$self->{pepStartInProt}}, $startInProt);

        push(@{$self->{pepEndInProt}}, $endInProt);

        ## initialize other parallel arrays
        push(@{$self->{pepStartInChrom}}, 0);
        push(@{$self->{pepEndInChrom}}, 0);
        push(@{$self->{chromName}}, "init");
        push(@{$self->{strand}}, "init");

        push(@{$self->{queryLength}}, $columns[1]);
        push(@{$self->{hitLength}}, $columns[3]);
        push(@{$self->{hitPercentIdentity}}, $columns[4]);
        push(@{$self->{hitDifference}}, $columns[7]);

        $index = $index + 1;
    }

    close(INFILE) or die "Cannot close $infile ($!)";

    $self->{proteinNameHash} = \%proteinNameHash;

    print "Finished reading protein hits file\n";
}


sub readMainFeaturesFile 
{
    my ($self, $featuresFile) = @_;

    die ("missing argument to readMainFeaturesFile")
        unless defined $featuresFile;

    $self->readFeaturesFile( $featuresFile, "main" );
}

sub readP1FeaturesFile 
{
    my ($self, $featuresFile) = @_;

    die ("missing argument to readP1FeaturesFile")
        unless defined $featuresFile;

    $self->readFeaturesFile( $featuresFile, "plasmid1" );
}

sub readP2FeaturesFile 
{
    my ($self, $featuresFile) = @_;

    die ("missing argument to readMainFeaturesFile")
        unless defined $featuresFile;

    $self->readFeaturesFile( $featuresFile, "plasmid2" );
}


sub readFeaturesFile 
{
    my ($self, $infile, $type) = @_;

    die ("missing infile argument to readFeaturesFile")
        unless defined $infile;

    die ("missing type argument to readFeaturesFile")
        unless defined $type;

    my %protNameHash = %{$self->{proteinNameHash}};

    open(INFILE,"<$infile") or die "Cannot open $infile ($!)";
    
    ## read and toss first line
    my $line = <INFILE>;

    while ($line = <INFILE>) 
    {
        chomp($line);

        my @columns = split(/\t/,$line);

        ## these are the VNG names, need to convert them to all upper case
        my $canonicalName = $columns[0];

        my $geneName = $columns[1];

        my $featureChrom = $type;

        my $featureChromStart = $columns[2];

        my $featureChromEnd = $columns[3];

        my $strand = $columns[4];

        my $featureChromStrand;

        ## if it's in protein hash, use it to calc coords:
        if (exists $protNameHash{$canonicalName} ) 
        {
            my $protein = $canonicalName;

            if ($strand eq "For") 
            {
                $featureChromStrand = 1
            } else 
            { ## Reverse
                $featureChromStrand = -1;
            }

            ## calculate coordinates for all peptides with this
            ## protein (no need to account for introns of UTRS in these features
            ## for halobacterium)
            my @indices = split(",", $protNameHash{$protein});

            for (my $j = 0; $j <= $#indices; $j++)
            {
                my $i = $indices[$j];

                my $pepStartInProt = ${$self->{pepStartInProt}}[$i];
                
                my $pepEndInProt = ${$self->{pepEndInProt}}[$i];
                
                ${$self->{strand}}[$i] = $featureChromStrand;

                ${$self->{chromName}}[$i] = $featureChrom;

                ## calc pepStartInChrom and pepEnd in Chrom
                my $pepStartInChrom = $featureChromStart + 
                    ($featureChromStrand * ( ($pepStartInProt - 1) * 3));

                my $pepEndInChrom = $featureChromStart + 
                    ($featureChromStrand * ( ($pepEndInProt * 3) - 1));

                ## in PA, we store smaller number as start chromosome,
                ## so reverese these for Reverse strand
                if ($featureChromStrand == -1 )
                {
                    my $swap = $pepStartInChrom;

                    my $pepStartInChrom = $pepEndInChrom;

                    my $pepEndInChrom = $swap;
                }
                
                ${$self->{pepStartInChrom}}[$i] = $pepStartInChrom;

                ${$self->{pepEndInChrom}}[$i] = $pepEndInChrom;

            }

        }
        
    }

    close(INFILE) or die "Cannot close $infile ($!)";

    print "Finished storing features info\n";

} ## end readFeaturesFile


## write coordinate file
sub writeCoordinateFile 
{
    my ($self, $outfile) = @_;

    die ("missing argument to writeCoordinateFile")
        unless defined $outfile;

    open(OUTFILE,">$outfile") or die "cannot open $outfile for writing";

    ## make a local of the peptide array to make index num easier
    my @pepName = @{$self->{pepName}};

    for (my $i = 0; $i <= $#pepName; $i++)
    {
        my $str = 
            $pepName[$i] . "\t" .
            ${$self->{queryLength}}[$i] . "\t" .
            ${$self->{protName}}[$i] . "\t" .
            ${$self->{hitLength}}[$i] . "\t" .
            ${$self->{hitPercentIdentity}}[$i] . "\t" .
            ${$self->{pepStartInProt}}[$i] . "\t" .
            ${$self->{pepEndInProt}}[$i] . "\t" .
            ${$self->{hitDifference}}[$i] . "\t" .
            ${$self->{protName}}[$i] . "\t" .
            ${$self->{strand}}[$i] . "\t" .
            ${$self->{pepStartInChrom}}[$i] . "\t" .
            ${$self->{pepEndInChrom}}[$i] . "\t" .
            ${$self->{chromName}}[$i];

        print OUTFILE "$str\n";
    }

    close(OUTFILE) or die "cannot close $outfile";
}


1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 ProtFeatures


  Use to convert peptide locations in ORF to chromosomal coordinates
  for yeast organism (Saccharomyces cerevisiae).
  It's suited for SGD protein database and features file.

=head1 SYNOPSIS


    use HalobacteriumProtFeatures;


    Create protein features instance:

        my $proteinFeatures = new HalobacteriumProtFeatures();

    Store peptide coordinate info:

        $proteinFeatures->readPeptideCoords( $peptideCoordHitsFile);

    Read in chromosomal features (calculates peptide relative coords in process):

        $proteinFeatures->readFeaturesFile( $main_chrom_features_file );

        $proteinFeatures->readFeaturesFile( $p1_chrom_features_file );

        $proteinFeatures->readFeaturesFile( $p2_chrom_features_file );

    Write results to output file
        $proteinFeatures->writeCoordinateFile( $outfile );



=head1 ABSTRACT

   see above


=head1 DESCRIPTION

  see above

=head2 EXPORT

None by default.



=head1 SEE ALSO

   see script written to use this module: peptideAtlasPipeline_halo.pl


=head1 AUTHOR

Nichole King, E<lt>nking@localemailaddress<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2004 by Institute for Systems Biology

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
