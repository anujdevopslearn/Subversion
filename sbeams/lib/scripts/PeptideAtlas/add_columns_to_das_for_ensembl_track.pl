#!/usr/local/bin/perl  -w
use strict;

###############################################################################
# Program     : add_columns_to_das_for_ensembl_track.pl
# Author      : Nichole King <nking@systemsbiology.org>
# $Id$
#
# Description : adds 2 columns to the das tsv file for format needed by
#               ensembl's isb track.  
#               someday - should include the export to tsv stage in this
#               script too, but for now, need tsv file as input
###############################################################################

my $infile = "pa_april2005.tsv";

my $outfile = "pa_april2005_ensembl.tsv";

open INFILE, "<$infile" or die "Cannot open file $infile ($)";

open OUTFILE, ">$outfile" or die "Cannot open file $outfile ($)";


## read columns, write 'em into outfile, and add the 2 new columns
my $line = <INFILE>;

chomp ($line);

my @column_names = split(/\t/,$line);

push(@column_names, "feature" );

push(@column_names, "url" );

## set up hash with key=column_name, value=index
my $i = 0;

my %column_indices;

foreach my $column_name (@column_names) 
{

    $column_indices{$column_name} = $i;

    $i++;

}


## write columns into outfile:
print OUTFILE "$column_names[0]";

for ($i = 1; $i <= $#column_names; $i++)
{

    print OUTFILE "\t$column_names[$i]";

}

print OUTFILE "\n";


my $urlPre = "https://db.systemsbiology.net/sbeams/cgi/PeptideAtlas/GetPeptide?_tab=3&atlas_build_id=70&searchWithinThis=Peptide+Sequence&searchForThis=";

my $urlPost = "&action=QUERY";

my $numEntries = $#column_names;

## read the rest of the file, write into new, and add the 2 new columns:
while ($line = <INFILE>) 
{

    chomp($line);

    my @entries = split(/\t/,$line);

    my $str = $entries[ $column_indices{'peptide_sequence'} ];

    my $lastEntry = $urlPre.$str.$urlPost;

    push(@entries, "peptide");

    push(@entries, $lastEntry);


    print OUTFILE "$entries[0]";

    for (my $i = 1; $i <= $numEntries; $i++)
    {

        print OUTFILE "\t$entries[$i]";
   
    }

    print OUTFILE "\n";

}


close (INFILE) or die "Cannot close file $infile ($)";

close (OUTFILE) or die "Cannot close file $outfile ($)";

