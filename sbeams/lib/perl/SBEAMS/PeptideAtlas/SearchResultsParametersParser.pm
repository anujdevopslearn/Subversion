package SearchResultsParametersParser;
use strict;
use Carp;

use 5.008;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use SearchResultsParametersParser ':all';
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
    $self->{search_batch_directory} = undef;
    $self->{TPP_version} = undef;
    bless ($self, $class);
    return $self;
}


sub setSearch_batch_directory
{
    my ($self, $dir) = @_;
    croak("missing argument to setSearch_batch_directory") unless defined $dir;

    ## make sure it exists
    unless (-e $dir)
    {
        croak("directory doesn't exist: setSearch_batch_directory (" +
            $dir + ")" ) unless defined $dir;
    }

    $self->{search_batch_directory} = $dir;
}

sub getTPP_version
{
    my ($self) = @_;
    return $self->{TPP_version};
}


sub parse
{
    my ($self) = @_;
    croak("missing search_batch_directory, please use setSearch_batch_directory(xx)") 
        unless defined $self->{search_batch_directory};

    ## get pepXML file
    my $infile = $self->{search_batch_directory} . "/interact-prob.xml";

    #### Sometimes search_batch_dir_path is actually a file??
    if ($self->{search_batch_directory} =~ /\.xml/) {
      $infile = $self->{search_batch_directory};
    }

    unless(-e $infile)
    {
        print "[WARN] could not find $infile\n";

        $infile = $self->{search_batch_directory} . "/interact.xml";
    }
    unless(-e $infile)
    {
        print "[WARN] could not find $infile either\n";

        ## A fudge to obtain an interact.xml file when multiple exist (cases when
        ## datasets are too large for TPP)
        $infile = $self->{search_batch_directory} . "/interact-prob01.xml";
    }
    unless(-e $infile)
    {
        die "could not find $infile either\n";
    }

    open(INFILE, "<$infile") or die "cannot open $infile for reading ($!)";

    ## example entry:
    ## <peptideprophet_summary version="PeptideProphet v3.0 April 1, 2004 (TPP v2.6 Quantitative Precipitation Forecast rev.2, Build 200512211154)" author="AKeller@ISB" min_prob="0.00" options=" MINPROB=0" est_tot_num_correct="12527.0">

    my $str1 = '\<peptideprophet_summary version=\"PeptideProphet';

    my $versionString;

    while (my $line = <INFILE>)
    {
        chomp($line);

        if ($line =~ /^($str1)(.+)(\()(TPP\sv)(\d\.\d+\.*\d*)\s(.+)(\))(.+)/)
        {
            $versionString = $5;

            last;
        }

    }

    close(INFILE) or die "Cannot close $infile";

    if ($versionString eq "")
    {
        print "[WARN] could not find TPP version in $infile\n";

    }

    $self->{search_batch_directory} = $versionString;
}



1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 SearchResultsParametersParser


=head1 SYNOPSIS

SearchResultsParametersParser does a quick parse of files in the 
search_batch directory to get the information information needed 
for database attributes in PeptideAtlas to help with versioning, etc.

USAGE:

use SearchResultsParametersParser;

my $results_parser = new SearchResultsParametersParser();

$results_parser->setSearch_batch_directory("/path/to/search_batch_directory");

$results_parser->parse();

my $TPP_version = $results_parser->getTPP_version();




=head1 ABSTRACT

   see above


=head1 DESCRIPTION

  see above

=head2 EXPORT

None by default.



=head1 SEE ALSO


=head1 AUTHOR Nichole King

=head1 COPYRIGHT AND LICENSE


This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
