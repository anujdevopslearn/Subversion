package PeptideFilesGenerator;

use 5.008;
use strict;
use warnings;

our @ISA = qw();

our $VERSION = '0.01';


# Preloaded methods go here.

###############################################################################
## constructor, with declarations for minimumProbability,
## organismAbbreviation, and buildPath
###############################################################################
sub new
{
    my $class = shift;
    my %args = @_;
    my $self = {};
    $self->{minimumProbability} = undef;
    $self->{organismAbbreviation} = undef;
    $self->{buildPath} = undef;
    $self->{dataPath} = undef;
    bless ($self, $class);
    return $self;
}

###############################################################################
## set minimum probability thresshold
###############################################################################
sub setMinimumProbability
{
    my ($self, $minimumProbability) = @_;
    croak("missing argument to setMinimumProbability") unless 
        defined $minimumProbability;
    $self->{minimumProbability} = $minimumProbability;
}

###############################################################################
## set Organism Abbreviation (needed in names of outfiles)
###############################################################################
sub setOrganismAbbreviation
{
    my ($self, $organismAbbreviation) = @_;
    croak("missing argument to setOrganismAbbreviation") 
        unless defined $organismAbbreviation;
    $self->{organismAbbreviation} = $organismAbbreviation;
}

###############################################################################
## set path to build directory
###############################################################################
sub setBuildPath
{
    my ($self, $buildPath) = @_;
    croak("missing argument to setBuildPath") 
        unless defined $buildPath;
    $self->{buildPath} = $buildPath;
}

###############################################################################
## set path to build data directory
###############################################################################
sub setDataPath
{
    my ($self, $dataPath) = @_;
    croak("missing argument to setDataPath") 
        unless defined $dataPath;
    $self->{dataPath} = $dataPath;
}


###############################################################################
# makes a system call to
#     $SBEAMS/lib/scripts/PeptideAtlas/createPipelineInput.pl
# which creates APD_Hs_all.PAxml and APD_Hs_all.peplist
# and then creates APD files from those.
###############################################################################
sub generateFiles
{
    my ($self) = @_;

    my $minProbability = $self->{minimumProbability} || '0.9';

    my $organismAbbreviation = $self->{organismAbbreviation} ||
        die "must setOrganismAbbreviation";

    my $buildPath = $self->{buildPath} || die "must setBuildPath";

    my $dataPath = $self->{dataPath} || die "must setDataPath";

    my $experiments_list = "$buildPath/Experiments.list";

    ## check that directories to write to exist before long duration sys call...
    unless (-d $buildPath)
    {
        print "The output directory ($buildPath) does not exist($!)\n";
        exit;
    }
    unless (-d $dataPath)
    {
        print "The output directory ($dataPath) does not exist($!)\n";
        exit;
    }
    ## check that Experiments.list exists in the build directory
    unless (-e $experiments_list)
    {
        print "\nNeed Experiments.list file in $buildPath.\n";
        print "Experiments.list holds the search_batch_ids and experiment paths\n";
        exit;
    }


    #### Define the names of the output files
    my $APDFastaFileName = getAPDFileName(
        organismAbbreviation => $organismAbbreviation,
        dataPath => $dataPath,
    );

    ## create the tsv filename
    my $APDTsvFileName = $APDFastaFileName;

    $APDTsvFileName =~ s/\.fasta$/\.tsv/;

    #### Get the peptide list
    my $SBEAMS = $ENV{SBEAMS} || die("ERROR: Must have env variable SBEAMS set");

    my $cmd = 
        " $SBEAMS/lib/scripts/PeptideAtlas/createPipelineInput.pl ".
        "--source_file $experiments_list --P $minProbability ".
        "--output_file $APDTsvFileName";

    system($cmd);


    #### read and write APD files:
    open(TSV,"<$APDTsvFileName") or die "cannot open $APDTsvFileName for reading";
    open(FASTA,">$APDFastaFileName") or die "cannot open $APDFastaFileName for writing";


    #### Get column names
    my $line = <TSV>;
    chomp($line);
    my @columns = split("\t",$line);
    my %col;
    my $i=0;
    foreach my $column ( @columns ) 
    {
        $col{$column} = $i++;
    }
    unless ( defined($col{peptide_identifier_str}) && defined($col{peptide}) ) 
    {
        die("Could not find peptide_identifier_str and peptide columns in tsv file");
    }


    #### Loop of each entry and write out peptide information
    while(<TSV>)
    {
        my @data = split("\t",$_);
        print FASTA ">$data[$col{peptide_identifier_str}]\n$data[$col{peptide}]\n";
    }

    close(TSV);
    close(FASTA);

    return;
}

###############################################################################
# getAPDFileName - gets APD file name to create/use
#
# @param organismAbbreviation -- organism abbreviation (e.g. Hs, Sc, Dm, ...)
# @param dataPath -- path to directory where built atlas files will reside
# @return APDFileName
###############################################################################
sub getAPDFileName 
{
    my %args = @_;

    my $organismAbbreviation = $args{organismAbbreviation};

    my $dataPath = $args{dataPath};

    my $file = "$dataPath/APD_" . $organismAbbreviation . "_all.fasta";

    return $file;
}


1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

PeptideFilesGenerator - Perl module which uses 
$SBEAMS/lib/scripts/PeptideAtlas/createPipelineInput.pl to generate
APD_<org>_all.PAxml and APD_<org>_all.peplist, and then uses
those files to generate te APD tsv and fasta files

=head1 SYNOPSIS

  use PeptideFilesGenerator;

  my $peptideFilesGenerator = new PeptideFilesGenerator();

  $peptideFilesGenerator->setMinimumProbability( $min_prob );

  $peptideFilesGenerator->setOrganismAbbreviation( $organism_abbrev );

  $peptideFilesGenerator->setBuildPath( $build_abs_path );

  $peptideFilesGenerator->generateFiles();


=head1 ABSTRACT

PeptideFilesGenerator uses
$SBEAMS/lib/scripts/PeptideAtlas/createPipelineInput.pl to generate
APD_<org>_all.PAxml and APD_<org>_all.peplist, and then uses
those files to generate te APD tsv and fasta files

=head1 DESCRIPTION

PeptideFilesGenerator uses
$SBEAMS/lib/scripts/PeptideAtlas/createPipelineInput.pl to generate
APD_<org>_all.PAxml and APD_<org>_all.peplist, and then uses
those files to generate te APD tsv and fasta files


=head1 SEE ALSO

$SBEAMS/lib/scripts/PeptideAtlas/createPipelineInput.pl

=head1 AUTHOR


=head1 COPYRIGHT AND LICENSE


This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
