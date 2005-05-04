#!/tools/bin/perl -w

use DBI;
use Getopt::Long;
use FindBin qw( $Bin );
use File::Basename;

use lib "$Bin/../../perl";
use strict;

use vars qw (%OPTIONS $VERBOSE $DEBUG $DIR $KEYSTORE $KEYPASS $KEYNAME);

#### Process options
unless (GetOptions(\%OPTIONS,
		   "keystore:s",
		   "keypass:s",
		   "keyname:s",
		   "dir:s",
		   "debug:s",
		   )) {
 printUsage();
}


$DEBUG      = $OPTIONS{debug};
$DIR	    = $OPTIONS{dir};
$KEYSTORE   = $OPTIONS{keystore};
$KEYPASS    = $OPTIONS{keypass};
$KEYNAME    = $OPTIONS{keyname};

die "Cannot find dir $!\n" . printUsage() unless( -e $DIR);
unless($KEYSTORE){
	print "KEYSTORE DOES NOT LOOK GOOD '$KEYSTORE'\n";
	printUsage();
}
unless($KEYPASS){
	print "KEYPASS DOES NOT LOOK GOOD '$KEYPASS'\n";
	printUsage();
}
unless($KEYNAME){
	print "KEYNAME DOES NOT LOOK GOOD '$KEYNAME'\n";
	printUsage();
}


opendir DIR, $DIR or die "Cannot read dir $!\n";

my @files = readdir DIR;
close DIR;

foreach my $file (@files){
	if ($file =~ /\.jar/){
		process_file($file);
	}else{
		next;
	}
}

sub process_file{

	my $file = shift;
	
	
	
	my $temp_dir = mk_temp_dir($file);
	copy_orginial_to_temp(temp_folder => $temp_dir,
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
	delete_temp_folder(
		   temp_folder => $temp_dir,
		   file	       => $file,
	          );
	sign_jar($file);		
	print "Done prosessing file '$file'\n\n";
}


sub sign_jar {
	my $file = shift;
	chdir($DIR);
	
my $command_line = "jarsigner -keystore $KEYSTORE -storepass $KEYPASS $file $KEYNAME";
	
	run_command($command_line);
}

sub delete_temp_folder {
	my %args = @_;
	my $file = $args{file};
	my $temp_folder = $args{temp_folder};
	run_command("rm -r $temp_folder");
	
	
}

sub move_files{
	my %args = @_;
	my $file = $args{file};
	my $temp_folder = $args{temp_folder};
	unless (-e "$DIR/ORGINIAL_JARS"){
	
		mkdir "$DIR/ORGINIAL_JARS" or die "Cannot mk ORGINIAL DIR $!\n";
	}
	#save_orginal
	run_command("mv $DIR/$file $DIR/ORGINIAL_JARS/$file");
	#copy in new file
	run_command("mv $temp_folder/$file $DIR/$file");
	
}

sub re_jar {
	my %args = @_;
	my $file = $args{file};
	my $temp_folder = $args{temp_folder};
	chdir "$temp_folder" or die "Cannot change directory $!\n";
	
	my $command_line = "/tools/java/sdk/bin/jar -cfm $file /tmp/temp_manifest.mf -C ./ .";
	run_command($command_line);

}
sub copy_orginial_to_temp {
	my %args = @_;
	my $file = $args{file};
	my $temp_folder = $args{temp_folder};
	
	run_command("cp $DIR/$file $temp_folder/$file");
}

sub unpack_jar{
	my %args = @_;
	my $file = $args{file};
	my $temp_folder = $args{temp_folder};
	
	run_command("unzip $temp_folder/$file -d $temp_folder");
	
	
	run_command("rm $temp_folder/$file");
}


sub remove_meta_info {
	my %args = @_;
	my $file = $args{file};
	my $temp_folder = $args{temp_folder};
	
	if (-e "$temp_folder/META-INF/"){
		
		collect_good_manifest_info($temp_folder);
		
		run_command("ls $temp_folder/META-INF");
		run_command("rm $temp_folder/META-INF/*");
		
	}else{
		print "FILE '$file' DOES NOT HAVE A META-INF FOLDER\n";
	}
	
	
	
}
sub collect_good_manifest_info{
	my $temp_folder = shift;

		#need to collect the good information about the manifest what is the main method
		print "META INFO\n";
		open (FILE, "$temp_folder/META-INF/MANIFEST.MF") or die "Cannot open $!\n";
		my $count =0;
		print "START PRINTING MANIFEST INFO ###################\n";
		my $good_info = '';
		while(<FILE>){
			$good_info .= $_;
			last if ($_ =~ /^\s+/)
			
		}
		print "$good_info\n";
		close FILE;
		open OUT, ">/tmp/temp_manifest.mf" or die "Cannot open temp out $!\n";
		print OUT $good_info;
		close OUT;

}
sub mk_temp_dir{
	my $file = shift;
	my $base_name = $file;
	$base_name =~ s/\.jar$//;
	my $temp_name = "_temp_$base_name";
	my $temp_dir = "$DIR/$temp_name";
	print "Make folder for '$temp_dir'\n";
	if (-e $temp_dir){
		system("rm -r $temp_dir");
	}
	
	mkdir ($temp_dir) or 
		die "Cannot make temp dir for file '$file' $!\n";
	return ($temp_dir);
	
}

sub run_command {
	my $command_line = shift;
	
	
	my $output = system($command_line);
	print "COMMAND LINE '$command_line'\nOUTPUT '$output'\n" if $DEBUG;
	
}


sub printUsage {

  print( <<"  EOU" );
   The script takes a directory of jar files or a single jar file,
   removes the information in the META-INF directory
   re-jars the data then resigns the jar file.
   
   
   Usage: 
   --keystore	path to keystore to sign jar with
   --keypass	password for the key to use
   --keyname    name of the key to use
   --dir	directory of jar files to process
   --verbose       verbose output
  --debug	debug output
  
  Example
  ./Re_sign_jar_files.pl --dir <full_file_path>/jars \
   --keystore /net/db/etc/.keystore \
   --keypass sbeamsDevKey \
   --keyname sbeamsDev
  EOU
  exit;
}
