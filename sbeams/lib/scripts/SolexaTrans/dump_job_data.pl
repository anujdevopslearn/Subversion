#!/tools64/bin/perl
use Carp;
use strict;
use warnings;
use lib "/net/dblocal/www/html/devDM/sbeams/lib/perl";
use SBEAMS::Connection;
use SBEAMS::Connection::Settings;;
use SBEAMS::Connection::Tables;
use SBEAMS::SolexaTrans::Solexa_file_groups;
use SBEAMS::SolexaTrans::SolexaTransPipeline;
use SBEAMS::SolexaTrans::Tables;
use SBEAMS::SolexaTrans::SolexaUtilities;
use POSIX qw(strftime);
use Data::Dumper;
use Getopt::Long;

use vars qw ($sbeams $q $sbeams_solexa $utilities
  $PROG_NAME $USAGE %OPTIONS
  $VERBOSE $QUIET $DEBUG
  $DATABASE $TESTONLY
  $DIRECTORY
  $FILE_LANE
  );

my $sbeams = new SBEAMS::Connection;
my $utilities = new SBEAMS::SolexaTrans::SolexaUtilities;
$utilities->setSBEAMS($sbeams);

my $current_username = $sbeams->Authenticate();
my $log = SBEAMS::Connection::Log->new();

my $created_by_id=$sbeams->getCurrent_contact_id();
my $owner_group_id=$sbeams->getCurrent_work_group_id();


# $sbeams->selectOneColumn

# expects to be run in a directory that contains subdirectories that are all STP jobs
# subdirectories are jobnames
# A .pl file in the directory contains the STP object and we can use that object to get the
#   parameters that STP was started with


# Set program name and usage banner for command like use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
$PROG_NAME is used to produce JCR appropriate information for STP runs.
Expects that directories are named 'stp-*'.

Usage: $PROG_NAME --dir <directory> [OPTIONS]

Required for all operations:
    --dir <directory>     The directory to scan for STP jobs.

Options:
    --file_lane        If this flag is provided, filenames are constructed with lane numbers in the filename.
                       Default is 0.  Produces <project name>.<sample_id>.ext
                       With Flag : <project name>.<sample_id>.<lane>.ext 

    --verbose <num>    Set verbosity level.  Default is 0
    --quiet            Set flag to print nothing at all except errors
    --debug n          Set debug flag
    --testonly         Information in the database is not altered


EOU

#### Process options
unless (
  GetOptions(
    \%OPTIONS,  "verbose:i",    "quiet", "debug:i",  
    "directory:s", "testonly", "file_lane",
  )
  )
{
  print "$USAGE";
  exit;
}

$VERBOSE  = $OPTIONS{verbose} || 0;
$QUIET    = $OPTIONS{quiet};
$DEBUG    = $OPTIONS{debug} || 0;
$TESTONLY = $OPTIONS{testonly} || 0;

$FILE_LANE = $OPTIONS{file_lane} || 0;


if ( $OPTIONS{directory} ) {
  $DIRECTORY = $OPTIONS{directory};
}
else {
  print "\n** Missing directory to scan ****\n\n $USAGE";
  exit;
}


if ($DEBUG) {
  print "Options settings:\n";
  print "  VERBOSE = $VERBOSE\n";
  if ($QUIET) { print "  QUIET = $QUIET\n";} else { print "  QUIET NOT SET\n"; }
  print "  DEBUG = $DEBUG\n";
  print "  BASE_DIR = $DIRECTORY\n";
  if ($TESTONLY) { print "  TESTONLY = $OPTIONS{testonly}\n"; } else { print "  TESTONLY NOT SET\n"; }
  print "\n";
}


###############################################################################
# Set Global Variables and execute main()
###############################################################################
$utilities->base_dir($DIRECTORY);
$utilities->verbose($VERBOSE);
$utilities->debug($DEBUG);
$utilities->testonly($TESTONLY);

main();
exit(0);

###############################################################################
# Main Program:
#
###############################################################################
sub main {

  my %files;
  my %parameters;

  # expects that the directory name contains 'stp-'.
  my @job_dirs = grep { -d && /stp-/ } <$DIRECTORY/*>;

  foreach my $job_dir (@job_dirs) {
    my ($job_name) = $job_dir;
    $job_name =~ s/$DIRECTORY//;
    $job_name =~ s/\///g;
    my $perl_script = $job_dir.'/'.$job_name.'.pl';
    $parameters{$job_name}{'DIR'} = $job_dir;
    $parameters{$job_name}{'SCRIPT'} = $perl_script;

    my $write_script = (stat($perl_script))[9];
    $parameters{$job_name}{'TIMESTAMP'} = $write_script;
    $parameters{$job_name}{'STATUS'}{'STATUS'} = 'UNKNOWN';

    my %logs;
    $logs{'OUT'} = $job_dir.'/'.$job_name.'.out';
    $logs{'ERR'} = $job_dir.'/'.$job_name.'.err';

    $parameters{$job_name}{'LOGS'} = \%logs;


    open IN, $perl_script or die "can't open perl script $perl_script\n";

    # top of script contains 3 parameters we need: my $sample_id = '#'; my $project_name = '<name>'; my $lane = '#';
    my @lines = <IN>;
    my ($sample_id) = grep ( /my \$sample_id = /, @lines);
    ($sample_id) = $sample_id =~ /'(.*)'/;
    $parameters{$job_name}{'SAMPLE'} = $sample_id;
    
    my ($project_name) = grep ( /my \$project_name = /, @lines);
    ($project_name) = $project_name =~ /'(.*)'/;
    $parameters{$job_name}{'PROJECT'} = $project_name;

    my ($lane) = grep ( /my \$lane = /, @lines);
    ($lane) = $lane =~ /'(.*)'/;
    $parameters{$job_name}{'LANE'} = $lane;

    my @newlines = @lines;
    my %lines_to_add;
    # split lines that have ,'s in them, two fields, and =>'s in each field into new lines
    for (my $i = 0; $i <= $#lines; $i++) {
        chomp($lines[$i]);
        $lines[$i] =~ s/^#//;
        $lines[$i] =~ s/^\s*//g;
        if ($lines[$i] =~ /,/ && $lines[$i] !~ /#/) {
        $lines[$i] =~ s/^\s*//g;
          my @fields = split(/, /, $lines[$i]);
          if ((scalar @fields) == 2 && $fields[0] =~ /=>/ &&  $fields[1] =~ /=>/) {
            $newlines[$i] = $fields[0].',';
            if ($lines_to_add{$i}) {
              $lines_to_add{$i} .= $fields[1];
            } else {
              $lines_to_add{$i} = $fields[1];
            }
          }
        }
    }

    foreach my $lkey (keys %lines_to_add) {
      splice(@newlines, $lkey, 0, ($lines_to_add{$lkey}));
    }

    # go through the perl script and get the parameters supplied to the new pipeline call
    my $flag =0;
    foreach my $line (@newlines) {
      chomp($line);
      if ($line =~ /\)\;/) {
        $flag = 0;
      }
      if ($flag) {
        $line =~ s/^#//;
        $line =~ s/,.*//;
        $line =~ s/^\s*//g;
        $line =~ s/'//g;
        my ($key, $value) = split(/\s*=>\s*/,$line);
        if ($key =~ /^babel/) { next; } # skips any key that starts with babel - this is db info
        if ($value =~ /\$sample_id/) { $value = $sample_id; }
        if ($value =~ /\$project_name/) { $value = $project_name; }
        if ($value =~ /\$lane/) { $value = $lane; }
        if ($key =~ /^db/) {
         $parameters{$job_name}{'OUTPUT'}{'DATABASES'}{$key} = $value;
        } else {
         $parameters{$job_name}{'INPUTS'}{$key} = $value;
        }

      }

      if ($line =~ /SolexaTransPipeline->new/) {
        $flag = 1;
      }
    }
    close IN;

  }

#print Dumper(\%parameters);
  foreach my $jobname ( keys %parameters) {
    print "Processing job $jobname\n";
    my $basename;  # base filename for .cpm, .stats, .unkn, .tags, .ambg files
    my $project_name = $parameters{$jobname}{'PROJECT'};
    my $sample_id = $parameters{$jobname}{'SAMPLE'};
    my $lane = $parameters{$jobname}{'LANE'};
    my $job_dir = $parameters{$jobname}{'DIR'};

    if (!$sample_id || !$project_name || !$lane || !$job_dir) {
      print "Job is missing required parameters\n";
      next;
    }

    if (!$parameters{$jobname}{'INPUTS'}) {
       print "Job is missing INPUTS\n";
    }

    if ($FILE_LANE) {
      $basename  = $project_name.'.'.$sample_id.'.'.$lane;
    } else {
      $basename = $project_name.'.'.$sample_id;
    }

    my %files;
    $files{'AMBG'} = $job_dir.'/'.$basename.'.ambg';
    $files{'CPM'} = $job_dir.'/'.$basename.'.cpm';
    $files{'UNKN'} = $job_dir.'/'.$basename.'.unkn';
    $files{'TAGS'} = $job_dir.'/'.$basename.'.tags';

    $parameters{$jobname}{'OUTPUT'}{'FILES'} = \%files;

    $parameters{$jobname}{'OUTPUT'}{'DATABASES'}{'DSN'} = 'DBI:mysql:host='.$parameters{$jobname}{'DATABASES'}{'db_host'}.
                                                ':database='.$parameters{$jobname}{'DATABASES'}{'db_name'};

    $parameters{$jobname}{'OUTPUT'}{'DATABASES'}{'CPM'} = $basename.'_cpm';
    $parameters{$jobname}{'OUTPUT'}{'DATABASES'}{'CPM'} =~ s/\./_/g;

    $parameters{$jobname}{'OUTPUT'}{'DATABASES'}{'TAGS'} = $basename.'_tags';
    $parameters{$jobname}{'OUTPUT'}{'DATABASES'}{'TAGS'} =~ s/\./_/g;

    $parameters{$jobname}{'OUTPUT'}{'DATABASES'}{'AMBG'} = $basename.'_ambg';
    $parameters{$jobname}{'OUTPUT'}{'DATABASES'}{'AMBG'} =~ s/\./_/g;

    $parameters{$jobname}{'OUTPUT'}{'DATABASES'}{'UNKN'} = $basename.'_unkn';
    $parameters{$jobname}{'OUTPUT'}{'DATABASES'}{'UNKN'} =~ s/\./_/g;


    my $stats_file = $job_dir.'/'.$basename.'.stats';
    if (-e $stats_file) {  
      open STATS, "$stats_file" or die "Can't open stats file - $stats_file\n";
      my %stats;
      while(<STATS>) {
       chomp;
       my ($name, $num) = split(/\t/, $_);
       $stats{$name} = $num;
      }
      close STATS;

      $parameters{$jobname}{'STATS'} = \%stats;

      my $stats_secs = (stat($stats_file))[9];
      $parameters{$jobname}{'STATUS'}{'TIMESTAMP'} = $stats_secs;
      $parameters{$jobname}{'STATUS'}{'STATUS'} = 'COMPLETED';
    } else {
      print "WARN: Stats file did not exist for job $jobname\n";
    }

  } # foreach jobname

  my %skip = ('SCRIPT' => 1,
              'DIR' => 1,
              'PROJECT' => 1,
              'SAMPLE' => 1,
              'LANE' => 1,
              );

  my %output; # hash to dump
  foreach my $jobname (keys %parameters) {
    foreach my $ikey (keys %{$parameters{$jobname}}) {
      print "skipped $ikey\n" if $skip{$ikey};
      print "added $ikey to output\n" unless $skip{$ikey};
      $output{$jobname}{$ikey} = $parameters{$jobname}{$ikey} unless $skip{$ikey};
    }
  }

  foreach my $jobname (keys %output) { 

    my $outfile = "JCR_info.".$jobname;
    open OUT, ">$outfile" or die "Can't open outfile $outfile\n";
    print OUT Dumper($output{$jobname});

    close OUT;
  }

} # end main
