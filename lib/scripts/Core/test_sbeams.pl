#!/usr/local/bin/perl -w

#
# Implements test harness for sbeams tests.
#

                                       
use Test::Harness;  
use Getopt::Long;
use FindBin qw( $Bin );

use lib "$Bin/../../perl";
use SBEAMS::Connection;
use SBEAMS::Connection::Settings qw( $DBCONFIG $DBINSTANCE );
use strict;

# Globals
my $sbeams = SBEAMS::Connection->new();
my $verbose = 0;

$|++; # don't buffer output

{ # MAIN

  # If no args are given, print usage and exit
  printUsage( 'Insufficient input' ) unless @ARGV;

  my $args = processArgs();

  my $tests = getTests( $args );
 
  if ( $args->{dryrun} ) {
    printTests( \@{$tests} );
    exit;
  }

  runTests( $tests );
  
  exit 0;
}


sub getTests {

  my $args = shift();

  # Figure out which tests to run, order of priority
  my @modules;     # Which modules to test
  my @tests;       # Which tests to run
  my $tdir;        # Test dir, base of search for tests

  # 1. Tests specified in @ARGV
  if ( @ARGV ) { 
    # We assume that these are tests.
    @tests = @ARGV;
    return( validateTests(\@tests) );

  # 2. Tests found under dir specified by --basedir option
  } elsif ( $args->{basedir} ) {
    $tdir = "$args->{basedir}/lib/perl/t";

  # 3. Tests found under dir specified in $SBEAMS envrionment variable
  } elsif ( $ENV{SBEAMS} ) {
    $tdir = "$ENV{SBEAMS}/lib/perl/t";

  # 4. Tests found under dir relative to script exe dir
  } else {
    $tdir = "$Bin/../../perl/t";
  }

  my $tests;
  if ( $args->{all} ) {
    my $dirs = findDirs( $tdir );
    $tests = findTests( dirs => $dirs, base => $tdir );
  } else {
    $tests = findTests( dirs => $args->{module}, base => $tdir );
  }
  return validateTests( $tests );
}

sub validateTests {
  my $tests = shift || [];
  my @validated;
  for my $t ( @{$tests} ) {
    push @validated, $t if -e $t && -x $t;
  }
  printUsage( "No valid tests found" ) unless @validated;
  return \@validated;
}

sub findDirs {
  my $dir = shift;
  opendir DIR, $dir || die "Unable to open dir $dir";

  # Crafty dopplegrep, first extract non-dot files, then grab only the dirs
  my @dirs = grep( -d "$dir/$_", (grep !/^\./, readdir DIR) );

  return( \@dirs );
}

sub findTests {
  my %args = @_;
  my @all_tests;
  
  for my $mod ( @{$args{dirs}} ) {
    print "Reading $mod \n" if $verbose;
    opendir DIR, "$args{base}/$mod" || warn "Unable to open $args{base}/$mod";
    my @tests = map { "$args{base}/$mod/$_" } grep(/^[^\.]+\.t$/, readdir DIR);
    push @all_tests, @tests;
  }
#  for ( @all_tests ){ print STDERR "$_\n"; }
    
  return( \@all_tests );
}


sub processArgs {
  my %args;
  unless( GetOptions( \%args, 'verbose', 'module=s@', 'all',
                      'dryrun') ) {
    printUsage("Error with options, please check usage:");
  }
  $args{module} ||= [];

  printUsage( ) if $args{help};

  unless( $args{all} || @{$args{module}} || @ARGV ) {
    printUsage( "No tests specified" );
  }

  $verbose = $args{verbose};
  $Test::Harness::Verbose = $verbose;

  return \%args;
}

sub printTests {
  my $tests = shift;
  for my $t ( @$tests ) {
    print "$t\n";
  }
}

sub runTests {
  my $tests = shift;
  runtests( @$tests );
}

sub printUsage {
  my $err = shift || '';
  my $program = $0;
  $program =~ s/.*(\/)+//g;
  print( <<"  EOU" );
   $err
 
   Usage:
     $program o-m Proteomics [ -m Core ]
     $program --all --verbose
     $program *.t

   -m, --module        Run all tests in specified module
   -a, --all           Run all tests in various module subdirs
   -b, --basedir       Explicitly set sbeams base dir
   -d, --dryrun        Print all tests specified by options, but do not run
   -h, --help          Print this help text and exit
   -v, --verbose       Verbose output

  EOU
  exit;
}
