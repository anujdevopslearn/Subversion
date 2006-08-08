#!/usr/local/bin/perl -w
###############################################################################
# Program     : addModule.pl
# $Id$
# Description: Simple wrapper script to AvailableModules.conf
#
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################

use strict;
use File::Basename;

$|++;

my $module = $ARGV[0];
printUsage( "Must define module" ) unless $module;

my $base = $ENV{SBEAMS};
printUsage( "Must set SBEAMS environment variable" ) unless $base;

# is given module name valid?
validateModule();

# add module (if necessary )
addModule();

exit 0;


#+
# Check to see if specified module is in Modules.conf file.  Since we'll have 
# it open anyway, use Mod.conf to create a stub AvailableModules.conf if one
# does not already exist.
#-
sub validateModule {

  unless ( -e "$base/lib/conf/Core/Modules.conf" ) {
    print Usage( "Modules.conf file does not exist" );
  }

  open( MODS, "$base/lib/conf/Core/Modules.conf" ) || printUsage( <<"  END" );
  Unable to open file $base/lib/conf/Core/Modules.conf
  END


  my $avail = ( -e "$base/lib/conf/Core/AvailableModules.conf" ) ? 1 : 0; 
  open ( AVAIL, ">$base/lib/conf/Core/AvailableModules.conf" ) if !$avail;

  my $valid = 0;
  my @all_mods;
  while ( my $line = <MODS> ) {
    chomp $line;
    if ( $line =~ /^#/ ) {
      print AVAIL "$line\n" if !$avail;
      next; 
    }
    next if $line =~ /^\s*$/;
    if ( $line =~ /^$module$/ ) {
      $valid++;
    } else {
      push @all_mods, $line;
    }
  }
  close AVAIL if !$avail;
  close MODS;

  return if $valid;

  printUsage( <<"  END" . join( ",\n", @all_mods ) . "\n" );
Invalid module name: $module.\nValid modules include: 
  END

}

#+
# Read AvailableModules.conf file, add specified module iff necessary
#-
sub addModule {

  open( AVAIL, "$base/lib/conf/Core/AvailableModules.conf" ) 
                                                     || printUsage( <<"  END" );
Unable to open file $base/lib/conf/Core/AvailableModules.conf
  END

  my %all_mods;
  my $comments = '';
  while ( my $line = <AVAIL> ) {
    chomp $line;
    if ( $line =~ /^#/ ) {
      $comments .= "$line\n" 
    } else {
      $all_mods{$line}++ unless $line =~ /^\s*$/;
    }
  }
  close AVAIL;

  if ( $all_mods{$module} ) { # mod is already there!
    print "Module $module is already registered\n";
  } else {
    open( AVAIL, ">$base/lib/conf/Core/AvailableModules.conf" ) 
                                                     || printUsage( <<"    END" );
Unable to open file $base/lib/conf/Core/AvailableModules.conf for writing
    END
    $all_mods{$module}++;
    print AVAIL "$comments" . join( "\n", sort( keys(%all_mods) ) ) . "\n";
    print "Added $module to AvailableModules file\n";
    close AVAIL;
  }
}

#+
# What passes for documentation.
#-
sub printUsage {
  my $msg = shift;
  my $script = basename( $0 );
  print <<"  END";
  $msg

  $script is a simple script to maintain a list of modules installed at an
  SBEAMS site, and is simply a wrapper for the AvailableModules.conf file.

  Usage: $script ModuleName

  END
  exit 1;
}
