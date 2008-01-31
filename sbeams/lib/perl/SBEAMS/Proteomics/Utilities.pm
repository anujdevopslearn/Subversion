package SBEAMS::Proteomics::Utilities;

###############################################################################
# Program     : SBEAMS::Proteomics::Utilities
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::Proteomics module which
#               defines many of the module-specific methods
#
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################


use strict;
use vars qw($sbeams
           );

use SBEAMS::Connection::DBConnector;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::TableInfo;

#### Commented out because it was forcing SBEAMS_SUBDIR in load_BSS.pl
#use SBEAMS::Proteomics::Settings;
#use SBEAMS::Proteomics::TableInfo;


###############################################################################
# Constructor
###############################################################################
sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;
    return($self);
}



###############################################################################
# readOutFile
###############################################################################
sub readOutFile { 
  my $self = shift;
  my %args = @_;


  #### Decode the argument list
  my $inputfile = $args{'inputfile'} || '';
  my $verbose = $args{'verbose'} || '';

  #### Define some variables
  my ($line,$last_part);
  my ($key,$value,$i,$matches,$tmp);

  #### Define a hash to hold header parameters
  my %parameters;
  my @column_titles;
  my $columns_line;


  #### Open the specified file
  unless ( open(INFILE, "$inputfile") ) {
    die("Cannot open input file $inputfile\n");
  }


  #### Find the filename in the file and parse it
  while ($line = <INFILE>) {
    $line =~ s/[\r\n]//g;
    if ($line =~ /\.out/) {
      $line =~ s/\.out//;
      $line =~ s/\s*\.\///;
      $line =~ s/\s*//g;
      $parameters{'file_root'} = $line;
      $line =~ /.+\.(\d+)\.(\d+)\.(\d)$/;
      $parameters{'start_scan'} = $1;
      $parameters{'end_scan'} = $2;
      $parameters{'assumed_charge'} = $3;
      last;
    }
  }


  #### Sometimes we rename the file from the original, so use the actual
  #### file name instead of the name that's in the contents of the file
  my $filepart = $inputfile;
  $filepart =~ s/^.*\///;
  $filepart =~ s/\.out//;
  $parameters{'file_root'} = $filepart;


  #### Initial hash defining search patterns and corresponding storage keys
  my (%ScanInfoPatternKey) = (
    "sample_mass_plus_H",'\(M\+H\)\+ mass = ([0-9.]+)',
#    "mass_error",' \~ ([0-9.]+) \(',
    "assumed_charge",'\(\+([0-9])\), fragment',
    "search_date",'(\d+\/\d+\/\d+, \d+:\d+ [AP]M)',
    "search_elapsed_hr",' ([\d.]+) hr. ',
    "search_elapsed_min",' ([\d.]+) min. ',
    "search_elapsed_sec",' ([\d.]+) sec.',
    "search_host",'. on (.+)',
    "total_intensity",'total inten = ([0-9.]+)',
    "lowest_prelim_score",'lowest Sp = ([0-9.]+)',
    "matched_peptides",'\# matched peptides = ([0-9.]+)',
    "search_database",', # proteins = \d+, (.+)',
#    "Dmass1",'\(C\* \+([0-9.]+)\)',
#    "Dmass2",'\(M\@ \+([0-9.]+)\)',
#    "mass_C",' C=([0-9.]+)',
    "search_program",'^\s*(\S+).+\(c\) 19',
  );


  #### Initialize desired hash values to ""
  while ( ($key,$value) = each %ScanInfoPatternKey ) {
    $parameters{$key}="";
  }


  #### Process header portion of the input file, putting data in hash
  $matches = 0;
  while ($line = <INFILE>) {
    $line =~ s/[\r\n]//g;

    while ( ($key,$value) = each %ScanInfoPatternKey ) {
      if ($line =~ /$value/) {
        $parameters{$key}="$1";
        $matches++;
      }
    }

    last unless $line;

  }


  #### If a sufficient number of matches were't found, bail out.
  if ($matches < 6) {
    print "ERROR: Only found $matches matches in the header.  I fear a header format problem.  Unable to parse header of $inputfile\n";
    while ( ($key,$value) = each %parameters ) {
      printf("%22s = %s\n",$key,$value);
    }
    return;
  }


  #### Do a little manual cleaning up
  $parameters{'search_date'} =~ s/,//g;
  $parameters{'search_elapsed_min'} = 0.0 +
    $parameters{'search_elapsed_hr'} * 60.0 +
    $parameters{'search_elapsed_min'} +
    $parameters{'search_elapsed_sec'} / 60.0;
  delete $parameters{'search_elapsed_hr'};
  delete $parameters{'search_elapsed_sec'};


  #### Print out the matched header values if verbose
  if ($verbose) {
    while ( ($key,$value) = each %parameters ) {
      printf("%22s = %s\n",$key,$value);
    }
  }


  #### Parse the header information
  while ($line = <INFILE>) {
    $line =~ s/[\r\n]//g;
    if ($line =~ /Rank\/Sp/) {
      $columns_line = $line;
      $line =~ s/^\s+//;
      @column_titles = split(/\s+/,$line);
    }

    last if ($line =~ /------/);

  }


  print "\n",join(",",@column_titles),"\n\n" if ($verbose);


  #### Define data format
  my $format = '';
  if ($parameters{search_program} eq 'SEQUEST') {
    $format = "a5a8a11a8a8a8a8";
  } elsif ($parameters{search_program} eq 'TurboSEQUEST') {
    $format = "a5a8a11a11a8a8a8a8";
  } elsif ($parameters{search_program} =~ /^SEQUEST/ ) {
    if ( $verbose ) {
      print "Non-standard search program version ($parameters{search_program}), should be OK\n";
    }
    $format = "a5a8a11a8a8a8a8";
  } else {
    die("ERROR: Unrecognized search program specified in header of file");
  }


  #### And some other variables
  my @result;
  my $processed_flag;


  #### Create a list of standard, simple columns
  my (%simple_columns) = (
    "#","hit_index",
    "(M+H)+","hit_mass_plus_H",
    "deltCn","norm_corr_delta",
    "XCorr","cross_corr",
    "Sp","prelim_score"
  );


  #### Find the offset for "Reference".  Need this for later parsing
  my $start_pos = index ($columns_line,"Reference");
  print "Offset for Reference: $start_pos\n" if ($verbose);

  #### Store the hash reference for each line in an array
  my @best_matches = ();
  my @values;


  #### Define a standard error string
  my $errstr = "ERROR: while parsing '$inputfile':\n      ";

  #### Parse the tabular data
  while ($line = <INFILE>) {
    $line =~ s/[\r\n]//g;
    last unless $line;


    #### If the line begins with 6 spaces and then stuff, assume it's a
    #### multiple protein match (special sequest format option)
    if ($line =~ /^      (\S+)/) {

      #### Extract the name of the protein as the first item after 6 spaces
      my $additional_protein = $1;
      #print "Found additional protein '$additional_protein'\n";

      #### If there hasn't already been at least one search_hit, die horribly
      die "ERROR: Found what was thought to be an 'additional_protein' ".
        "line before finding any search_hits!  This is fatal."
        unless (@best_matches);

      #### Get the handle of the previous best match
      my $previous_hit = $best_matches[-1];

      #### If there hasn't yet been an additional protein, create a container
      #### for all additional proteins
      unless ($previous_hit->{search_hit_proteins}) {
        my @search_hit_proteins;
        #### Put the in-line, top hit as the first item
        push(@search_hit_proteins,$previous_hit->{reference});
        $previous_hit->{search_hit_proteins} = \@search_hit_proteins;
      }

      #### Add this additional protein and skip to the next line
      push(@{$previous_hit->{search_hit_proteins}},$additional_protein);
      next;
    }


    #### Do a basic test of the line: skip if less than 8 columns
    @values = split(/\s+/,$line);
    print "line has ",scalar(@values)," values\n" if ($verbose); 
    if ($#values < 8) {
      print "WARNING: Skipping line (maybe duplicate references?):\n$line\n";
      next;
    }


    #### Unpack the first part and then append the Reference and Peptide,
    #### which seems to have a less-than-consistent format
    @result = unpack($format,$line);
    $last_part = substr($line,$start_pos,999);

    #### Switched from A-Z to \w due to a SEQUEST bug
    #$last_part =~ /(.+) [A-Z-\@]\..+\.[A-Z-\@]$/;
    #### Add the possibility for flanking *'s: stop codons
    #$last_part =~ /(.+) [\w\-\@]\..+\.[\w\-\@]$/;
    $last_part =~ /(.+) [\w\-\*\@]\..+\.[\w\-\*\@]$/;

    #### If the Regexp worked, then append the Reference to result
    if ($1) {
      push(@result,$1);
    } else {
      print "ERROR: Unable to parse Reference from '$last_part'\n";
    }

    #### Switched from A-Z to \w due to a SEQUEST bug
    #$last_part =~ /.+ ([A-Z-\@]\..+\.[A-Z-\@])$/;
    #### Add the possibility for flanking *'s: stop codons
    #$last_part =~ /.+ ([\w\-\@]\..+\.[\w\-\@])$/;
    $last_part =~ /.+ ([\w\-\*\@]\..+\.[\w\-\*\@])$/;

    #### If the Regexp worked, then append the Reference to result
    if ($1) {
      push(@result,$1);
    } else {
      print "ERROR: Unable to parse Reference from '$last_part'\n";
    }


    if ($verbose) {
      print "--------------------------------------------------------\n";
      print join("=",@result),"\n";
    }


    my %tmp_hash;

    #### Store the data in an array of hashes
    for ($i=0; $i<=$#column_titles; $i++) {
      $processed_flag = 0;


      #### Parse and store Rank/Sp
      if ($column_titles[$i] eq "Rank/Sp") {
        my @tmparr = split(/\//,$result[$i]);

        my $tmp = $tmparr[0];
        if ($tmp > 0 && $tmp < 100) {
          $tmp =~ s/ //g;
          $tmp_hash{'cross_corr_rank'} = $tmp;
        } else {
          print "$errstr Rank is out of range: $tmp\n";
        }

        $tmp = $tmparr[1];
        if ($tmp > 0 && $tmp <= 500) {
          $tmp =~ s/ //g;
          $tmp_hash{'prelim_score_rank'} = $tmp;
        } else {
          print "$errstr Sp Rank is out of range: $tmp\n";
        }

        $processed_flag++;
      }


      #### Parse and store the standard, simple columns
      if ($simple_columns{$column_titles[$i]}) {

        my $tmp = $result[$i];
        if ( ($tmp > 0 && $tmp < 10000) ||
             ($tmp == 0 && $column_titles[$i] eq "deltCn") ||
             ($tmp == 0 && $column_titles[$i] eq "Sp") ||
             ($tmp == 0 && $column_titles[$i] eq "XCorr") ) {
          $tmp =~ s/ //g;
          $tmp_hash{$simple_columns{$column_titles[$i]}} = $tmp;
        } else {
          print "$errstr $column_titles[$i] is out of range: $tmp\n";
        }

        $processed_flag++;
      }


      #### Parse and store Ions
      if ($column_titles[$i] eq "Ions") {
        my @tmparr = split(/\//,$result[$i]);

        my $tmp = $tmparr[0];
        if ($tmp > 0 && $tmp < 1000) {
          $tmp =~ s/ //g;
          $tmp_hash{'identified_ions'} = $tmp;
        } else {
          print "$errstr identified_ions is out of range: $tmp\n";
        }

        $tmp = $tmparr[1];
        if ($tmp > 0 && $tmp <= 1000) {
          $tmp =~ s/ //g;
          $tmp_hash{'total_ions'} = $tmp;
        } else {
          print "$errstr total_ions is out of range: $tmp\n";
        }

        $processed_flag++;
      }


      #### Parse and store Reference
      if ($column_titles[$i] eq "Reference") {
        my @tmparr = split(/\s+/,$result[$i]);

        my $tmp = $tmparr[0];
        if ($tmp) {
          $tmp =~ s/ //g;
          $tmp_hash{'reference'} = $tmp;
        } else {
          print "$errstr Reference is out of range: $tmp\n";
        }

        $tmp = $tmparr[1];
        if ($tmp > 0 && $tmp <= 1000) {
          $tmp =~ s/[ \+]//g;
          $tmp_hash{'additional_proteins'} = $tmp;
        } else {
          $tmp_hash{'additional_proteins'} = 0;
        }

        $processed_flag++;
      }


      #### Parse and store Peptide
      if ($column_titles[$i] eq "Peptide") {

        my $tmp = $result[$i];
        if ($tmp) {
          $tmp =~ s/ //g;

	  #### Compensate for SEQUEST bug
	  $tmp =~ s/[0-9]/-/g;

          $tmp_hash{'peptide_string'} = $tmp;
          $tmp =~ s/[\*\@\#]//g;
          $tmp =~ /.*\.([A-Z-\@]+)\..*/;
          if ($1) {
            $tmp_hash{'peptide'} = $1;
          } else {
            print "$errstr Unable to parse peptide_string to peptide: $tmp\n";
          }

        } else {
          print "$errstr Peptide is out of range: $tmp\n";
        }

        $processed_flag++;
      }


      #### At least be aware of column Id#
      if ($column_titles[$i] eq "Id#") {
        ### Don't know what to do with this but ignore it
        $processed_flag++;
     }


      unless ($processed_flag) {
        print "$errstr Don't know what to do with column '$column_titles[$i]'\n";
      }


    } ## End for


    #### Add a few manual calculations
    $tmp_hash{'mass_delta'} =
      $parameters{'sample_mass_plus_H'} - $tmp_hash{'hit_mass_plus_H'};

    #### Remove a pesky trailing period
    $tmp_hash{'hit_index'} =~ s/\.//g;

    #### Print out the matched header values if verbose
    if ($verbose) {
      while ( ($key,$value) = each %tmp_hash ) {
        printf("%22s = %s\n",$key,$value);
      }
    }


    #### Store the hash of values in array
    push(@best_matches,\%tmp_hash);


  } ## End while


  close(INFILE);


  my %final_structure;
  $final_structure{'parameters'} = \%parameters;
  $final_structure{'matches'} = \@best_matches;

  return %final_structure;

}



###############################################################################
# readParamsFile
###############################################################################
sub readParamsFile { 
  my $self = shift;
  my %args = @_;

  #### Decode the argument list
  my $inputfile = $args{'inputfile'} || "";
  my $verbose = $args{'verbose'} || "";

  #### Define a few variables
  my ($line,$last_part);
  my ($key,$value,$i,$matches,$tmp);


  #### Try to determine what kind of file this is
  my $filetype;
  if ($inputfile =~ /sequest.params/) {
    $filetype = 'SEQUEST';
  } elsif ($inputfile =~ /comet.def/) {
    $filetype = 'Comet';
  } elsif ($inputfile =~ /tandem/) {
    $filetype = 'XTandem';
  } else {
    $filetype = 'unknown';
  }
  if ($verbose) {
    print "filetype = $filetype\n";
  }

  #### Define a hash to hold parameters from the file and also an array
  #### to have an ordered list of keys
  my %parameters;
  my @keys_in_order;


  #### Open the specified file
  if ( open(INFILE, "$inputfile") == 0 ) {
    die "\nCannot open input file '$inputfile'\n\n";
  }


  #### Read through the entire file, extracting key value pairs
  $matches = 0;
  while ($line = <INFILE>) {

    #### If the line isn't a comment line, then parse it
    unless ($line =~ /^\s*\#/) {

      #### Strip linefeeds and carriage returns
      $line =~ s/[\r\n]//g;
      ($key,$value) = (undef,undef);

      #### If this is X!Tandem, then parse XML tag
      if ($filetype eq 'XTandem') {
        if ($line =~ /label="(.+)".*>(.+)<\/note>/) {
          ($key,$value) = ($1,$2);
        }

      #### Otherwise, assume SEQUEST/Comet style key = value pattern
      } else {
        if ($line =~ /\s*(\w+)\s*=\s*(.*)/) {
          ($key,$value) = ($1,$2);
        }
      }

      #### If a suitable key was found then store the key value pair
      if ($key) {

        #### Strip off a possible trailing comment identified by ;
        $value =~ s/\s*;.*$//;

        #### Strip off a possible trailing comment identified by #
        $value =~ s/\s*#.*$//;

        #print "$key = $value\n";
        $parameters{$key} = $value;
        push(@keys_in_order,$key);
      }
    }
  }


  #### Put parameters and data into a single structure and return
  my %finalhash;
  $finalhash{parameters} = \%parameters;
  $finalhash{keys_in_order} = \@keys_in_order;

  return \%finalhash;

}



###############################################################################
# readDtaFile
###############################################################################
sub readDtaFile { 
  my $self = shift;
  my %args = @_;

  #### Decode the argument list
  my $inputfile = $args{'inputfile'} || "";
  my $verbose = $args{'verbose'} || "";

  #### Define a few variables
  my $line;
  my @parsed_line;


  #### Define a hash to hold parameters from the file
  #### and a two dimensional array for the mass, intensity pairs
  my %parameters;
  my @mass_intensities;


  #### Parse information from the filename
  my $file_root = $inputfile;
  $file_root =~ s/.*\///;
  $file_root =~ /.+\.(\d+)\.(\d+)\.(\d).dta$/;
  $parameters{'start_scan'} = $1;
  $parameters{'end_scan'} = $2;
  $parameters{'assumed_charge'} = $3;
  $file_root =~ s/\.\d\.dta//;
  $parameters{'file_root'} = $file_root;


  #### Open the specified file
  if ( open(INFILE, "$inputfile") == 0 ) {
    die "\nCannot open input file $inputfile\n\n";
  }


  #### Read the header
  $line = <INFILE>;
  $line =~ s/[\r\n]//g;
  @parsed_line = split(/\s+/,$line);
  if ($#parsed_line != 1) {
    print "ERROR: Reading dta file '$inputfile'\n".
          "       Expected first line to have two columns.\n";
    return;
  }


  #### Stored results
  $parameters{sample_mass_plus_H} =  $parsed_line[0];
  $parameters{assumed_charge} =  $parsed_line[1];

  #### There cannot be repeated m/z values, but this has been observed
  #### on occasion, so define a hash that will allow us to filter those out
  my %masses;

  #### Read through the rest of the file, extracting mass, intensity pairs
  my $n_peaks = 0;
  while ($line = <INFILE>) {

    #### Strip linefeeds and carriage returns
    $line =~ s/[\r\n]//g;

    #### split into two values
    @parsed_line = split(/\s+/,$line);

    #### If we didn't get two values, then bail with error
    if ($#parsed_line != 1) {
      print "ERROR: Reading dta file '$inputfile'\n".
            "       Expected line $n_peaks to have two columns.\n";
      return;
    }


    #### Check to make sure we haven't seen this m/z yet
    my $mz = $parsed_line[0];
    if ($masses{$mz}) {
      print "WARNING: Duplicate m/z value $mz in '$inputfile'. Ignoring ".
	"subsequent m/z,intensity pair but beware this may be indicative of ".
	"a more serious problem in the pipeline.  Investigate!\n";

    #### Else store the mass, intensity pair
    } else {
      push(@mass_intensities,[@parsed_line]);
      $masses{$mz} = $parsed_line[1];
      $n_peaks++;
    }

  }

  $parameters{n_peaks} =  $n_peaks;


  #### Put parameters and data into a single structure and return
  my %finalhash;
  $finalhash{parameters} = \%parameters;
  $finalhash{mass_intensities} = \@mass_intensities;

  return \%finalhash;


}



###############################################################################
# readSummaryFile
###############################################################################
sub readSummaryFile {
  my $self = shift;
  my %args = @_;

  #### Decode the argument list
  my $inputfile = $args{'inputfile'} || "";
  my $verbose = $args{'verbose'} || "";

  #### Define a few variables
  my $line;
  my @parsed_line;


  #### Define a hash to hold pointers to the files with interesting information
  my %files;


  #### Open the specified file or return
  if ( open(INFILE, "$inputfile") == 0 ) {
    print "\nCannot open input file $inputfile\n\n";
    my %finalhash;
    $finalhash{files} = \%files;
    return \%finalhash;
  }


  while ($line = <INFILE>) {
    last if ($line =~ /------------/);
    last if ($line =~ /<HTML><BODY BGCOLOR="#FFFFFF"><PRE>/);
  }


  #### Initial hash defining search patterns and corresponding storage keys
  my (%ScanInfoPatternKey) = (
    "d0_first_scan",'LightFirstScan=(\d+)',
    "d0_last_scan",'LightLastScan=(\d+)',
    "d0_mass",'LightMass=([\d\.]+)',
    "d8_first_scan",'HeavyFirstScan=(\d+)',
    "d8_last_scan",'HeavyLastScan=(\d+)',
    "d8_mass",'HeavyMass=([\d\.]+)',
    "norm_flag",'bICATList1=([\d\.]+)',
    "mass_tolerance",'MassTol=([\d\.]+)'
  );



  my ($outfile,$matches,$key,$value);
  my $counter = 1;

  #### Read through the rest of the file, extracting information
  while ($line = <INFILE>) {

    #### Strip linefeeds and carriage returns
    $line =~ s/[\r\n]//g;

    #### Skip if we've reached the end
    last unless $line;

    #### Find the .outfile
    unless ($line =~ /showout_html5\?OutFile=(.+?\"\>)/ ||
            $line =~ /sequest-tgz-out.cgi\?OutFile=(.+?\"\>)/) {
      print "ERROR: Unable to parse line: $line\n";
      next;
    }

    $outfile = $1;
    $outfile =~ /.+\/(.+\.out)/;
    $outfile = $1;

    unless ($outfile) {
      print "ERROR: Unable to parse line: $line\n";
      next;
    }


    #### Define a hash to hold parameters for each file,
    my %parameters;
    my $matches = 0;

    #### If there's probability information, extract it
    if ($line =~ /Prob=([\d\.]+)/) {
      $parameters{probability}="$1";
      $matches++;
    }


    #### If there's quantitation information, extract it
    if ($line =~ /LightFirstScan/) {

      #### Extract the data, putting into a hash
      while ( ($key,$value) = each %ScanInfoPatternKey ) {
        if ($line =~ /$value/) {
          $parameters{$key}="$1";
          $matches++;
        }
      }


      #### Extract the actual ratio
      $line =~ /\>\s*([\d\.]+)\:([\d\.]+)([\*]*)\</;
      unless ($outfile) {
        print "ERROR: Unable to extract light:heavy line: $line\n";
      }
      $parameters{d0_intensity} = $1;
      $parameters{d8_intensity} = $2;
      $parameters{manually_changed} = $3;

      #print "$counter:  $outfile  matches=$matches ".
      #  "light_first_scan = $parameters{light_first_scan}  ".
      #  "ratio=$1:$2\n";
      #$files{$outfile}=\%parameters;

    } else {
      #print "$counter:  $outfile\n";
    }

    $files{$outfile}=\%parameters if ($matches);

    $counter++;

  }


  #### Put data into a single structure and return
  my %finalhash;
  $finalhash{files} = \%files;


  return \%finalhash;


}



###############################################################################
# readNfoFile
###############################################################################
sub readNfoFile {
  my $self = shift;
  my %args = @_;

  my $source_file = $args{'source_file'} || "";
  my $verbose = $args{'verbose'} || "";


  #### Define some standard variables
  my $line = '';


  #### Define a hash to hold parameters from the file
  #### and an array for the parsed data lines
  my %parameters;
  my @spec_data;


  #### Parse information from the filename
  $parameters{'full_name'} = $source_file;
  my $file_name = $source_file;
  $file_name =~ s/.*\///;
  $parameters{'file_name'} = $file_name;
  my $lcms_run_name = $file_name;
  $lcms_run_name =~ s/.nfo$//;
  $parameters{'lcms_run_name'} = $lcms_run_name;


  #### Open the specified file
  unless (open(INFILE,$source_file)) {
    die "\nCannot open input file $source_file\n\n";
  }


  #### Read the header
  while (!($line =~ /^\#spect_num/)) {
    $line = <INFILE>;
    $line =~ s/[\r\n]//g;

    #### Try to match the key = value format
    if ($line =~ /^\#(.+?)\s+= (.*)$/) {
      $parameters{$1} = $2;
      #print "$1 = $2\n";
    }

  }


  #### Save the column names
  $line =~ s/^\#//;
  my @columns = split("\t",$line);


  #### Now read the data and store in the array
  while ($line = <INFILE>) {
    $line =~ s/[\r\n]//g;
    my @parsed_line = split("\t",$line);
    push(@spec_data,\@parsed_line);
  }


  #### Put parameters and data into a single structure and return
  my %finalhash;
  $finalhash{parameters} = \%parameters;
  $finalhash{spec_data} = \@spec_data;
  $finalhash{columns} = \@columns;

  return %finalhash;


} # end readNfoFile



###############################################################################
# readPrecurFile
###############################################################################
sub readPrecurFile {
  my $self = shift;
  my %args = @_;

  #### Parse input parameters
  my $source_file = $args{'source_file'} || "";
  my $verbose = $args{'verbose'} || "";

  #### Define a hash to hold the data
  my %data;

  #### Open the specified file
  unless (open(INFILE,$source_file)) {
    die "\nCannot open input file $source_file\n\n";
  }

  #### Read the header
  my $line = <INFILE>;

  #### Define column names
  my @column_names = qw ( full_msrun_name spectrum_number spectrum_file_name
			  precursor_mass precursor_intensity );
  my %column_indices;
  my $i = 0;
  foreach my $name ( @column_names ) {
    $column_indices{$name} = $i;
    $i++;
  }
  $data{column_names_array} = \@column_names;
  $data{column_names_hash} = \%column_indices;

  #### Now read the data and store in the array
  while ($line = <INFILE>) {
    $line =~ s/[\r\n]//g;
    my @parsed_line = split("\t",$line);
    my $spectrum_number = $parsed_line[$column_indices{spectrum_number}];
    $data{$spectrum_number} = \@parsed_line;
  }

  return \%data;

} # end readPrecurFile



###############################################################################
# getHydropathyIndex: Get a hash of hydropathy indexes for each of the residues
###############################################################################
sub getHydropathyIndex {
  my %args = @_;
  my $SUB_NAME = 'getHydropathyIndex';

  #### Define the hydropathy index
  my %hydropathy_index = (
    I => 4.5,
    V => 4.2,
    L => 3.8,
    F => 2.8,
    C => 2.5,
    M => 1.9,
    A => 1.8,
    G => -0.4,
    T => -0.7,
    W => -0.9,
    S => -0.8,
    Y => -1.3,
    P => -1.6,
    H => -3.2,
    E => -3.5,
    Q => -3.5,
    D => -3.5,
    N => -3.5,
    K => -3.9,
    R => -4.5,

    X => 0.0,
    B => -3.5,
    Z => -3.5,
    U => 2.5,

  );

  return %hydropathy_index;

}



###############################################################################
# getWimleyWhiteIndex: Get a hash of Wimley-White indexes for each of the
# residues
###############################################################################
sub getWimleyWhiteIndex {
  my %args = @_;
  my $SUB_NAME = 'getWimleyWhiteIndex';

  #### Define the hydropathy index
  my %hydropathy_index = (
    I => -1.12,
    V => -0.46,
    L => -1.25,
    F => -1.71,
    C => -0.02,
    M => -0.67,
    A => +0.50,
    G => +1.15,
    T => +0.25,
    W => -2.09,
    S => +0.46,
    Y => -0.71,
    P => +0.14,
    H => +0.11,  #### His 0
    E => +3.68,
    Q => +0.77,
    D => +3.64,
    N => +0.85,
    K => +2.80,
    R => +1.81,

    X => 0.0,
    B => 2,
    Z => 2,
    U => 0,

  );

  return %hydropathy_index;

}



###############################################################################
# getPNNLRetentionCoeffs: Get a hash of the Retention Time Coefficients
# as calculated by Petritis et al. (2003): Anal. Chem 2003, 75, 1039
###############################################################################
sub getPNNLRetentionCoeffs {
  my %args = @_;
  my $SUB_NAME = 'getPNNLRetentionCoeffs';

  #### Define the retention time coefficients
  my %retention_coefficients = (
    L => 6.12,
    F => 3.37,
    I => 2.37,
    W => 2.27,
    M => 1.63,
    V => 1.63,
    Y => 0.72,
    A => 0.71,
    E => 0.56,
    P => 0.48,
    C => 0.32,
    D => 0.18,
    T => 0.18,
    G => -0.21,
    R => +0.24,
    N => -0.29,
    Q => -0.3,
    S => -0.35,
    K => -0.55,
    H => -0.59,

    X => 4.25,
    B => -0.06,
    Z => 0.13,
    U => 0,    # ????

  );

  return %retention_coefficients;

}



###############################################################################
# getResidueMasses: Get a hash of masses for each of the residues
###############################################################################
sub getResidueMasses {
  my %args = @_;
  my $SUB_NAME = 'getResidueMasses';

  #### Define the residue masses
  my %residue_masses = (
    I => 113.1594,   # Isoleucine
    V =>  99.1326,   # Valine
    L => 113.1594,   # Leucine
    F => 147.1766,   # Phenyalanine
    C => 103.1388,   # Cysteine
    M => 131.1926,   # Methionine
    A =>  71.0788,   # Alanine
    G =>  57.0519,   # Glycine
    T => 101.1051,   # Threonine
    W => 186.2132,   # Tryptophan
    S =>  87.0782,   # Serine
    Y => 163.1760,   # Tyrosine
    P =>  97.1167,   # Proline
    H => 137.1411,   # Histidine
    E => 129.1155,   # Glutamic_Acid (Glutamate)
    Q => 128.1307,   # Glutamine
    D => 115.0886,   # Aspartic_Acid (Aspartate)
    N => 114.1038,   # Asparagine
    K => 128.1741,   # Lysine
    R => 156.1875,   # Arginine

    X => 113.1594,   # L or I
    B => 114.5962,   # avg N and D
    Z => 128.6231,   # avg Q and E
    U => 100,        # ?????

  );

  return %residue_masses;

}




###############################################################################
# calcElutionTime: Calculate the elution time of the peptide
#   Thus far, all we have is some lame, unitless calculation from the
#   PNNL paper.  This is bad. and wrong. bad and wrong together.
###############################################################################
sub calcElutionTime {
  my %args = @_;
  my $SUB_NAME = 'calcElutionTime';

  #### Parse input parameters
  my $peptide = $args{'peptide'} || die "Must supply the peptide";
  my $mode = $args{'mode'} || "PNNL_ANN";


  #### Define the retention coefficients
  my %retention_coefficients = getPNNLRetentionCoeffs();

  #### Split peptide into an array of residues and get number
  my @residues = split(//,$peptide);
  my $nresidues = scalar(@residues);

  #### Loop over each residue and add in the hydropathy_index
  my $retention_index = 0;
  foreach my $residue (@residues) {
    $retention_index += $retention_coefficients{$residue};
  }

  return $retention_index;

} # end calcElutionTime



###############################################################################
# calcGravyScore: Calculate the gravy_score based on the hydropathy indexes
#   of each of the residues in the peptide
###############################################################################
sub calcGravyScore {
  my %args = @_;
  my $SUB_NAME = 'calcGravyScore';

  #### Parse input parameters
  my $peptide = $args{'peptide'} || die "Must supply the peptide";

  #### Define the hydropathy index
  my %hydropathy_index = getHydropathyIndex();

  #### Split peptide into an array of residues and get number
  my @residues = split(//,$peptide);
  my $nresidues = scalar(@residues);

  #### Loop over each residue and add in the hydropathy_index
  my $gravy_score = 0;
  foreach my $residue (@residues) {
    $gravy_score += $hydropathy_index{$residue};
  }


  #### Divide the total score by the number of residues
  $gravy_score = $gravy_score / $nresidues;

  return $gravy_score;

}



###############################################################################
# calcNTransmembraneRegions: Calculate the number of transmembrane regions
# based on the hydropathy indexes of each of the residues in the protein
###############################################################################
sub calcNTransmembraneRegions {
  my %args = @_;
  my $SUB_NAME = 'calcNTransmembraneRegions';

  #### Parse input parameters
  my $peptide = $args{'peptide'} || die "Must supply the peptide";
  my $iWindowSize = $args{'window_size'} || 19.0;
  my $calc_method = $args{'calc_method'} || '';
  my $verbose = $args{'verbose'} || 0;


  #### Define the hydropathy index
  my %hydropathy_index = getHydropathyIndex();
  if ($calc_method eq 'WimleyWhite') {
    %hydropathy_index = getWimleyWhiteIndex();
  }


  #### Define some variables
  my ($i,$iStart);
  my $dHydro = 0.0;
  my $iNumHydroRegions = 0;
  my $dCutOff = 1.58;
  my ($new_residue,$old_residue);


  #### Define information for specific residue counting
  my $iProleinCount = 0;
  my $iKRDECount = 0;
  my %KRDE = (K=>1,R=>1,D=>1,E=>1);


  #### If a specific calc_method was selected, set those parameters
  if ($calc_method eq 'NewMethod') {
    # Engelman et al., "Identifying nonpolar transbilayer helices in
    # amino acid sequences of emmbrane proteins", Annu. Rev. Biophys.
    # Biophys. Chem., 15, 321-353, 1986.
    $iWindowSize = 19;
    print "iWindowSize = $iWindowSize\n" if ($verbose);
    #### Subtract 1.0 from every hydropathy index
    while ( my ($key,$value) = each %hydropathy_index) {
      $hydropathy_index{$key} = $value - 1.0;
    }
  }


  #### If a specific calc_method was selected, set those parameters
  if ($calc_method eq 'WimleyWhite') {
    # Engelman et al., "Identifying nonpolar transbilayer helices in
    # amino acid sequences of emmbrane proteins", Annu. Rev. Biophys.
    # Biophys. Chem., 15, 321-353, 1986.
    $iWindowSize = 19;
    print "iWindowSize = $iWindowSize\n" if ($verbose);
  }



  #### Split peptide into an array of residues and get number
  my @residues = split(//,$peptide);
  my $iLengthProtein = scalar(@residues);


  #### If the peptide/protein is shorter than window size, return 0
  if ($iLengthProtein <= $iWindowSize) {
    return($iNumHydroRegions);
  }


  #### Sum up the hydropathy scores for first window-width residues
  for ($i=0; $i<$iWindowSize; $i++) {
    $dHydro += $hydropathy_index{$residues[$i]};
    $iProleinCount += 1 if ($residues[$i] eq 'P');
    $iKRDECount += 1 if (defined($KRDE{$residues[$i]}));
  }


  my $isHydroRegion=0;

  #### Loop over the residues in the protein, checking the rolling average
  #### for peaks above the cutoff
  for ($i=$iWindowSize; $i<$iLengthProtein; $i++) {

    #### If we're not in a transmembrane region, see if we entered one
    if ($isHydroRegion==0) {
      my $enter_region_flag = 0;
      $enter_region_flag = 1 if ($dHydro/$iWindowSize >= $dCutOff);
      $enter_region_flag = 0 if ($calc_method gt '' &&
        ($iProleinCount > 0 || $iKRDECount > 2) );

      if ($enter_region_flag) {
        $iNumHydroRegions++;
        $isHydroRegion = 1;
        print "  Region at ",$i-$iWindowSize," (",
          substr($peptide,$i-$iWindowSize,$iWindowSize),") ",
          " is above cutoff at ",
          $dHydro/$iWindowSize," ($iKRDECount)\n" if ($verbose);
      }

    #### Else if we are in a transmembrane region, see if we should exit
    } else {
      $isHydroRegion = 0 if ($dHydro/$iWindowSize < $dCutOff);
      $isHydroRegion = 0 if ($calc_method gt '' &&
        ($iProleinCount > 0 || $iKRDECount > 2) );
    }

    print $i-$iWindowSize,": ",substr($peptide,$i-$iWindowSize,$iWindowSize)," has ",
      "KRDE=$iKRDECount, P=$iProleinCount, avg=",
      $dHydro/$iWindowSize,"\n" if ($verbose>1);


    #### During debugging, figure out who's missing
    if (0) {
      unless (defined($hydropathy_index{$residues[$i]}) && defined($hydropathy_index{$residues[$i-$iWindowSize]})) {
        print "Leading residue '$residues[$i]'\n";
        print "Trailing residue '$residues[$i-$iWindowSize]'\n";
        print "i=$i\n";
        print "Sequence: $peptide\n";
        exit;
      }
    }

    #### Update the rolling hydropathy sum
    $new_residue = $residues[$i];
    $old_residue = $residues[$i-$iWindowSize];
    $dHydro += $hydropathy_index{$new_residue} -
      $hydropathy_index{$old_residue};

    #### Update the window content statistics
    $iProleinCount += 1 if ($new_residue eq 'P');
    $iProleinCount -= 1 if ($old_residue eq 'P');
    $iKRDECount += 1 if (defined($KRDE{$new_residue}));
    $iKRDECount -= 1 if (defined($KRDE{$old_residue}));

  }

  return $iNumHydroRegions;

}



###############################################################################

1;

__END__
###############################################################################
###############################################################################
###############################################################################

=head1 NAME

SBEAMS::Proteomics::Utilities - Module-specific utilities

=head1 SYNOPSIS

  Used as part of this system

    use SBEAMS::Connection;
    use SBEAMS::Proteomics::Utilties;


=head1 DESCRIPTION

    This module is inherited by the SBEAMS::Proteomics module,
    although it can be used on its own.  Its main function 
    is to encapsulate common module-specific functionality.

=head1 METHODS

=item B<readOutFile()>

    Read a sequest .out file

=item B<readParamsFile()>

    Read a sequest.params file

=item B<readDtaFile()>

    Read a sequest .dta file

=item B<readSummaryFile()>

    Read a sequest .html summary file

=item B<readNfoFile()>

    Read a sequest .nfo file

=head1 AUTHOR

Eric Deutsch <edeutsch@systemsbiology.org>

=head1 SEE ALSO

perl(1).

=cut
