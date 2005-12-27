#!/usr/local/bin/perl -w

###############################################################################
# Program     : Re_sign_jar_files.pl
# Author      : Bruz Marzolf <bmarzolf@systemsbiology.org>
# $Id$
#
# Description : This script imports data from an SBEAMS database export
#               file into an SBEAMS database
#
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################


###############################################################################
# Generic SBEAMS script setup
###############################################################################
use strict;
use Getopt::Long;
use FindBin;
use XML::Parser;
use Data::Dumper;
use Cwd;


use lib "$FindBin::Bin/../../perl";
use vars qw ($sbeams
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $TESTONLY
             $current_contact_id $current_username
            );
use vars qw ($content_handler);
use vars qw ($table_info $post_update);


#### Set up SBEAMS package
use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TableInfo;
$sbeams = new SBEAMS::Connection;

#### To get the table names resolving to work all affected modules must
#### Be listed here.  This is bad.  Is there any way around it?
use SBEAMS::Microarray::Tables;
use SBEAMS::Proteomics::Tables;
use SBEAMS::Immunostain::Tables;
use SBEAMS::BioLink::Tables;

#use DBI;
#use Getopt::Long;
#use FindBin qw( $Bin );
#use File::Basename;

use vars qw ($DIR $JAVA_HOME $KEYSTORE $KEYPASS $KEYALIAS);

#### Process options
processOptions();

$VERBOSE    = $OPTIONS{"verbose"} || 0;
$DEBUG      = $OPTIONS{"debug"} || 0;
$DIR	    = $OPTIONS{"dir"};
if ($DEBUG) {
	print "Options settings:\n";
	print "  VERBOSE = $VERBOSE\n";
	print "  DEBUG = $DEBUG\n";
	print "  DIR = $DIR\n";
}

my $JAVA_PATH = $sbeams->get_java_path();
my $KEYSTORE  = $sbeams->get_jnlp_keystore();
my $KEYPASS   = $sbeams->get_keystore_passwd();
my $KEYALIAS  = $sbeams->get_keystore_alias();

###############################################################################
# Set Global Variables and execute main()
###############################################################################
main();
exit 0;

###############################################################################
# Main Program:
#
# Get a directory listing, attempt to process all .jar files.
###############################################################################
sub main {
	chdir("$DIR") or die "Cannot read dir $!\n";;	
	$DIR = cwd;

	my @jars = glob("*.jar");

	foreach my $jar (@jars){
		process_file($jar);
	}
}

sub process_file{
	my $file = shift;
		
	print "Prosessing file '$file'...";

	my $temp_dir = mk_temp_dir($file);
	copy_original_to_temp(temp_folder => $temp_dir,
			     file	    => $file,
			      );
	unpack_jar(temp_folder => $temp_dir,
		  file	       => $file,
	          );

	remove_meta_info(temp_folder => $temp_dir,
		  	file	       => $file,
	                );
	re_jar(temp_folder => $temp_dir,
		file	       => $file,
	       );
	move_files(temp_folder => $temp_dir,
		   file	       => $file,
	          );
	delete_temp_files(
		   temp_folder => $temp_dir,
		   file	       => $file,
	          );
	sign_jar($file);		
	print "Done!\n";
}

sub mk_temp_dir{
	my $file = shift;
	my $base_name = $file;
	$base_name =~ s/\.jar$//;
	my $temp_name = "_temp_$base_name";
	my $temp_dir = "$DIR/$temp_name";
	if (-e $temp_dir){
		print "Removing previous folder '$temp_dir'\n" if $VERBOSE;
		system("rm -r $temp_dir");
	}
	print "Making new temporary folder '$temp_dir'\n" if $VERBOSE;
	mkdir ($temp_dir) or 
		die "Cannot make temp dir for file '$file' $!\n";
	return ($temp_dir);	
}

sub copy_original_to_temp {
	my %args = @_;
	my $file = $args{file};
	my $temp_folder = $args{temp_folder};
	
	print "Copying $DIR/$file to $temp_folder/$file\n" if $VERBOSE;
	run_command("cp $DIR/$file $temp_folder/$file");
}

sub unpack_jar{
	my %args = @_;
	my $file = $args{file};
	my $temp_folder = $args{temp_folder};
	
	chdir("$temp_folder");
	print "Unpacking jar with $file in $temp_folder\n" if $VERBOSE;
	run_command("$JAVA_PATH/bin/jar xf $file");
	chdir("$DIR");
	
	run_command("rm $temp_folder/$file");
}

sub remove_meta_info {
	my %args = @_;
	my $file = $args{file};
	my $temp_folder = $args{temp_folder};
	
	if (-e "$temp_folder/META-INF/"){
		
		collect_good_manifest_info($temp_folder);
		
		#run_command("ls $temp_folder/META-INF");
		run_command("rm $temp_folder/META-INF/*");
		
	}else{
		print "FILE '$file' DOES NOT HAVE A META-INF FOLDER\n";
	}
	
	
	
}

sub re_jar {
	my %args = @_;
	my $file = $args{file};
	my $temp_folder = $args{temp_folder};
	chdir "$temp_folder" or die "Cannot change into temporary directory $temp_folder\n$!\n";
	
	my $command_line = "$JAVA_PATH/bin/jar -cfm $file /tmp/temp_manifest.mf -C ./ .";
	print "Re-packing jar $file in $temp_folder\n" if $VERBOSE;
	run_command($command_line);

	chdir("$DIR");
}

sub move_files{
	my %args = @_;
	my $file = $args{file};
	my $temp_folder = $args{temp_folder};
	
	unless (-e "$DIR/ORIGINAL_JARS"){
	
		mkdir "$DIR/ORIGINAL_JARS" or die "Cannot mk ORIGINAL DIR $!\n";
	}
	print "Saving original jar $DIR/$file in $DIR/ORIGINAL_JARS/$file\n" .
	      "Moving new jar $temp_folder/$file to $DIR/$file\n" if $VERBOSE;
	#save_orginal
	run_command("mv $DIR/$file $DIR/ORIGINAL_JARS/$file");
	#copy in new file
	run_command("mv $temp_folder/$file $DIR/$file");
	
}

sub delete_temp_files {
	my %args = @_;
	my $file = $args{file};
	my $temp_folder = $args{temp_folder};
	print "Deleting temporary folder $temp_folder\n" if $VERBOSE;
	run_command("rm -r $temp_folder");
	print "Deleting temporary manifest /tmp/temp_manifest.mf\n" if $VERBOSE;
	run_command("rm /tmp/temp_manifest.mf");
}

sub sign_jar {
	my $file = shift;
	chdir($DIR);
	
	my $command_line = "$JAVA_PATH/bin/jarsigner -keystore $KEYSTORE -storepass $KEYPASS $file $KEYALIAS";
	print "Signing command line: $command_line\n" if $DEBUG;
	print "Signing jar $file with keystore $KEYSTORE, password $KEYPASS, and alias $KEYALIAS\n" if $VERBOSE;
	run_command($command_line);
}

sub collect_good_manifest_info{
	my $temp_folder = shift;

	#need to collect the good information about the manifest what is the main method
	open (FILE, "$temp_folder/META-INF/MANIFEST.MF") or die "Cannot open $!\n";
	my $count =0;
	print "START PRINTING MANIFEST INFO ###################\n" if $VERBOSE;
	my $good_info = '';
	while(<FILE>){
		$good_info .= $_;
		last if ($_ =~ /Main-Class/)
		
	}
	print "$good_info\n" if $VERBOSE;
	print "END PRINTING MANIFEST INFO ###################\n" if $VERBOSE;
	close FILE;
	open OUT, ">/tmp/temp_manifest.mf" or die "Cannot open temp out $!\n";
	print OUT $good_info;
	close OUT;

}

sub run_command {
	my $command_line = shift;
	
	my $output = system($command_line);
	print "COMMAND LINE '$command_line'\nOUTPUT '$output'\n" if $DEBUG;
	
}

sub processOptions {
  GetOptions( \%OPTIONS, "verbose:s", "debug:s", "dir=s") || printUsage( "Failed to get parameters" );
  
  for my $param ( qw(dir) ) {
    printUsage( "Missing required parameter $param" ) unless $OPTIONS{$param};
  }
}

sub printUsage {

  print( <<"  EOU" );
   The script takes a directory of jar files, removes the information
   in the META-INF directory re-jars the data then resigns the jar file 
   using the SBEAMS keystore
   
   Usage: 
   --dir	directory of jar files to process
   --verbose    verbose output
   --debug	debug output
  
  Example
  ./Re_sign_jar_files.pl --dir /path/to/jars
  EOU
  exit;
}
