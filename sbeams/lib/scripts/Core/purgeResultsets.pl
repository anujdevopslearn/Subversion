#!/usr/local/bin/perl -w

###############################################################################
# Program     : purgeResultsets.pl
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This script provides a maintenance mechanism for the cached
#               resultsets that would otherwise pile up forever
#
###############################################################################


###############################################################################
# Generic SBEAMS setup for all the needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;

use lib "$FindBin::Bin/../../perl";
use vars qw ($sbeams $sbeamsMOD $q
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $TESTONLY
             $current_contact_id $current_username
            );

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

$sbeams = new SBEAMS::Connection;


###############################################################################
# Set program name and usage banner for command like use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS]
Options:
  --verbose n          Set verbosity level.  default is 0
  --quiet              Set flag to print nothing at all except errors
  --debug n            Set debug flag
  --testonly           If set, rows in the database are not changed or added
  --show_statistics    If set, report the statistics of resultsets
  --purge              If set, delete sufficiently obsolete resultsets

 e.g.:  $PROG_NAME --testonly

EOU


#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
  "show_statistics","purge",
  )) {
  print "$USAGE";
  exit;
}

$VERBOSE = $OPTIONS{"verbose"} || 0;
$QUIET = $OPTIONS{"quiet"} || 0;
$DEBUG = $OPTIONS{"debug"} || 0;
$TESTONLY = $OPTIONS{"testonly"} || 0;
if ($DEBUG) {
  print "Options settings:\n";
  print "  VERBOSE = $VERBOSE\n";
  print "  QUIET = $QUIET\n";
  print "  DEBUG = $DEBUG\n";
  print "  TESTONLY = $TESTONLY\n";
}


###############################################################################
# Set Global Variables and execute main()
###############################################################################
main();
exit(0);


###############################################################################
# Main Program:
#
# Call $sbeams->Authenticate() and exit if it fails or continue if it works.
###############################################################################
sub main {

  #### Do the SBEAMS authentication and exit if a username is not returned
  exit unless ($current_username = $sbeams->Authenticate(
    work_group=>'Admin',
  ));


  $sbeams->printPageHeader() unless ($QUIET);
  handleRequest();
  $sbeams->printPageFooter() unless ($QUIET);


} # end main



###############################################################################
# handleRequest
###############################################################################
sub handleRequest {
  my %args = @_;


  #### Set the command-line options
  my $purge = $OPTIONS{"purge"} || '';
  my $show_statistics = $OPTIONS{"show_statistics"} || '';


  #### Print out the header
  unless ($QUIET) {
    $sbeams->printUserContext();
    print "\n";
  }


  #### Process the directory
  my $result = purgeResultsets(
    purge => $purge,
    show_statistics => $show_statistics,
  );


  print "handleRequest done.\n" if ($VERBOSE > 1);
  return;

} # end handleRequest



###############################################################################
# purgeResultsets
###############################################################################
sub purgeResultsets {
  my %args = @_;
  my $SUB_NAME = 'purgeResultsets';


  #### Process the arguments list
  my $purge = $args{'purge'} || '';
  my $show_statistics = $args{'show_statistics'} || '';


  #### If --purge not set, admit we're just testing
  unless ($purge) {
    print "INFO:  --purge is not set.  Actions will not actually be performed\n\n";
  }



  #### Get a dump of all the entries in the cached_resultset table
  print "Fetching all resultsets in database...\n" if ($VERBOSE);
  my $sql = qq~
    SELECT cache_descriptor,cached_resultset_id,resultset_name,query_name
      FROM $TB_CACHED_RESULTSET
  ~;
  my @resultsets = $sbeams->selectSeveralColumns($sql);
  print "Got ".scalar(@resultsets)." resultsets from cached_resultset\n";

  my %resultsets;
  foreach my $resultset (@resultsets) {
    $resultsets{$resultset->[0]} = $resultset;
  }

  #### Get a listing of all files in the directory
  #my $directory = "zztmp";
  print "Getting all files in cache directory...\n" if ($VERBOSE);
  my $directory = "$PHYSICAL_BASE_DIR/tmp/queries";
  my @files = getDirListing(
    directory => $directory,
    exclude_dot_files => 0,
    nosort => 1,
  );
  print "Got ".scalar(@files)." files from cache directory\n";


  #### Initialize some statistics for all the files
  my $n_files = scalar(@files);
  my $size_total = 0;
  my $size_large = 0;
  my $size_orphan = 0;
  my $size_deleted_orphan = 0;
  my $n_files_deleted_orphan = 0;
  my $size_deleted_large = 0;
  my $n_files_deleted_large = 0;
  my $size_special = 0;
  my $size_deleted_special = 0;
  my $n_files_deleted_special = 0;


  #### Keep a hash of all resultsets for which there is file
  my %complete_resultsets;


  #### Loop over all the files and keep stats
  print "Looping over all files to decide what to do...\n" if ($VERBOSE);
  my $ifile = 0;
  foreach my $file (@files) {
    my $file_root = $file;
    $file_root =~ s/\..+?$//;

    my $file_size = ( -s "$directory/$file" );
    unless (defined($file_size)) {
      print "ERROR: Unable to determine size of file $directory/$file\n";
      $file_size = 0;
    }

    $size_total += $file_size;
    my $age = ( -M "$directory/$file" );

    #### If this file has a table entry, make a note
    if (exists($resultsets{$file_root})) {
      $complete_resultsets{$file_root} = 1;

    #### Else it's temporary resultset that doesn't need a table entry
    #### Purge it after 30 days
    } else {
      if ($age > 30.0) {
	unlink("$directory/$file") if ($purge);
        $size_deleted_orphan += $file_size;
        $n_files_deleted_orphan++;
      }

      $size_orphan += $file_size;
    }


    #### Purge files > 10MB if more than 30 days old
    if ($file_size > 10000000) {
      #printf("%10d  %10.2f  %s\n",$file_size,$age,$file);
      if ($age > 30.0) {
        if (defined($resultsets{$file_root}) &&
	    defined($resultsets{$file_root}->[2]) &&
            $resultsets{$file_root}->[2] gt '') {
          printf("\nRetaining %s (%7.2f MB) (aged %d days) (named '%s')...\n",
                 $file,$file_size/1024/1024,$age,$resultsets{$file_root}->[2])
	    if ($VERBOSE);
	} else {
	  printf("\nPurging $file (%7.2f MB)...",$file_size/1024/1024);
	  if (defined($resultsets{$file_root}->[1]) &&
            $resultsets{$file_root}->[1] gt '') {
 	    $sql = qq~
	      DELETE $TB_CACHED_RESULTSET
	       WHERE cached_resultset_id = '$resultsets{$file_root}->[1]'
	    ~;
	    $sbeams->executeSQL($sql) if ($purge);
	  } else {
	    print "\n  Warning no resultset in database by that name!";
	  }
	  if ($purge) {
	    unlink("$directory/$file_root.resultsets");
	    unlink("$directory/$file_root.params");
	  }
	  delete($resultsets{$file_root});
          $size_deleted_large += $file_size;
          $n_files_deleted_large++;
	}
      }
      $size_large += $file_size;
    }


    #### Purge special cases if older than 7 days
    if (defined($resultsets{$file_root}) &&
	defined($resultsets{$file_root}->[3]) &&
	$resultsets{$file_root}->[3] eq 'Proteomics/GetSearchHits' &&
        $file_root =~ /pmallick/) {
      if ($age > 7.0) {
        if (defined($resultsets{$file_root}) &&
	    defined($resultsets{$file_root}->[2]) &&
            $resultsets{$file_root}->[2] gt '') {
          printf("\nRetaining %s (%d bytes) (aged %d days) (named '%s')...\n",
                 $file,$file_size,$age,$resultsets{$file_root}->[2])
	    if ($VERBOSE);
	} else {
	  #print "\nPurging $file ($file_size bytes)...";
	  $sql = qq~
	    DELETE $TB_CACHED_RESULTSET
	     WHERE cached_resultset_id = '$resultsets{$file_root}->[1]'
	  ~;
	  if ($purge) {
	    $sbeams->executeSQL($sql);
	    unlink("$directory/$file_root.resultset");
	    unlink("$directory/$file_root.params");
	  }
	  delete($resultsets{$file_root});
          $size_deleted_special += $file_size;
          $n_files_deleted_special++;
	}
      }
      $size_special += $file_size;
    }



    print "$ifile..." if ($ifile/100 == int($ifile/100) && $VERBOSE);
    $ifile++;
    #last if ($ifile >= 500000);

  }
  print "\nDone looping over files.\n" if ($VERBOSE);


  #### Loop over all the resultsets, looking for ones without files
  my $n_resultsets_with_no_file = 0;
  print "\nChecking for resultsets with no data files\n" if ($VERBOSE);
  foreach my $resultset (keys %resultsets) {
    if (exists($complete_resultsets{$resultset})) {
      # great
    } else {
      #print "There is no file for $resultset!\n";
      $n_resultsets_with_no_file++;
      print "$n_resultsets_with_no_file..."
        if ($n_resultsets_with_no_file/100 ==
	    int($n_resultsets_with_no_file/100) && $VERBOSE);

      if (defined($resultsets{$resultset}->[1]) &&
          $resultsets{$resultset}->[1] gt '') {
        $sql = qq~
	    DELETE $TB_CACHED_RESULTSET
	     WHERE cached_resultset_id = '$resultsets{$resultset}->[1]'
        ~;
        #print "($resultsets{$resultset}->[1])";
        $sbeams->executeSQL($sql) if ($purge);
      } else {
	print "\n",$resultsets{$resultset};
        print "\n",join(',',@{$resultsets{$resultset}}),"\n";
        exit;
      }

    }

  }


  #### If the user wants to see the stats, show them
  if ($show_statistics) {
    print "\n\nCache information:\n";
    print "  Number of resultsets in database: ".scalar(@resultsets)."\n";
    print "  Number of files: $n_files\n";
    print "  Number of resultsets with no file: $n_resultsets_with_no_file\n";
    printf("  Total size of files: %.2f MB\n\n",$size_total/1024/1024);

    print "  Number of deleted orphan files: $n_files_deleted_orphan\n";
    printf("  Total size of deleted orphan files: %.2f MB\n",$size_deleted_orphan/1024/1024);
    printf("  Total size of orphan files: %.2f MB\n\n",$size_orphan/1024/1024);

    print "  Number of deleted large files: $n_files_deleted_large\n";
    printf("  Total size of deleted large files: %.2f MB\n",$size_deleted_large/1024/1024);
    printf("  Total size of large files: %.2f MB\n\n",$size_large/1024/1024);

    print "  Number of deleted special files: $n_files_deleted_special\n";
    print "  Total size of deleted special files: $size_deleted_special\n";
    printf("  Total size of special files: %.2f MB\n\n",$size_special/1024/1024);

  }



  print "Purge 1\n" if ($VERBOSE > 1);
  %resultsets = ();
  print "Purge 2\n" if ($VERBOSE > 1);
  @resultsets = ();
  print "Purge 3\n" if ($VERBOSE > 1);
  @files = ();
  print "purgeResultsets done.\n" if ($VERBOSE > 1);
  print "\n";
  return 1;

}



###############################################################################
# getDirListing
###############################################################################
sub getDirListing {
  my %args = @_;
  my $SUB_NAME = 'getDirListing';


  #### Decode the argument list
  my $dir = $args{'directory'}
   || die "ERROR[$SUB_NAME]: directory not passed";
  my $exclude_dot_files = $args{'exclude_dot_files'} || 0;
  my $nosort = $args{'nosort'} || 0;

  #### Open the directory and get the files (except . and ..)
  print "Opening directory $dir...\n" if ($VERBOSE);
  opendir(DIR, $dir) || die "[$PROG_NAME:getDirListing] Cannot open $dir: $!";
  print "Getting file list and removing ./ and ../.\n" if ($VERBOSE);
  my @files = grep (!/^\.{1,2}$/, readdir(DIR));
  closedir(DIR);

  #### Remove the dot files if we don't want them
  if ($exclude_dot_files) {
    print "Removing other dot files\n" if ($VERBOSE);
    @files = grep (!/^\./,@files);
  }

  #### Always sort the files
  unless ($nosort) {
    print "sorting files\n" if ($VERBOSE);
    @files = sort(@files);
  }

  return @files;
}


