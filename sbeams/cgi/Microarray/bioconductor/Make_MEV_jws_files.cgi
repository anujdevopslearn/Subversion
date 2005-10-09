#!/usr/local/bin/perl -w

use CGI qw/:standard/;
use CGI::Pretty;
$CGI::Pretty::INDENT = "";
use POSIX;
use FileManager;
use Batch;
use BioC;
use Site;
use strict;
use Data::Dumper;
$Data::Dumper::Pad = "<br>";
$Data::Dumper::Pair = "<br><br>";


use XML::LibXML;

use FindBin;

use lib "$FindBin::Bin/../../../lib/perl";
use SBEAMS::Connection qw($q $log);
use SBEAMS::Connection::Settings;
use SBEAMS::Microarray::Tables;

use SBEAMS::Microarray;
use SBEAMS::Microarray::Settings;
use SBEAMS::Microarray::Tables;
use SBEAMS::Microarray::Affy_file_groups;
use SBEAMS::Microarray::Affy_Analysis;
use SBEAMS::Microarray::Affy_Annotation;



use vars qw ($sbeams $affy_o $cgi $current_username $USER_ID
  $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
  $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
  @MENU_OPTIONS %CONVERSION_H);


$sbeams    = new SBEAMS::Connection;
$affy_o = new SBEAMS::Microarray::Affy_Analysis;
$affy_o->setSBEAMS($sbeams);

#### Do the SBEAMS authentication and exit if a username is not returned
	exit
	  unless (
		$current_username = $sbeams->Authenticate(
			permitted_work_groups_ref =>
			  [ 'Microarray_user', 'Microarray_admin', 'Admin' ],
			#connect_read_only=>1,
			#allow_anonymous_access=>1,
		)
	  );
# Create the global CGI instance
#our $cgi = new CGI;
#using a single cgi in instance created during authentication
$cgi = $q;

#### Read in the default input parameters
	my %parameters;
	my $n_params_found = $sbeams->parse_input_parameters(
		q              => $cgi,
		parameters_ref => \%parameters
	);
	
	
# Create the global FileManager instance
our $fm = new FileManager;

# Handle initializing the FileManager session
if ($cgi->param('token') ) {
    my $token = $cgi->param('token');
    
	if ($fm->init_with_token($BC_UPLOAD_DIR, $token)) {
	    error('Upload session has no files') if !($fm->filenames > 0);
	} else {
	    error("Couldn't load session from token: ". $cgi->param('token')) if
	        $cgi->param('token');
	}
}



if (! $cgi->param('step')) {
    step1();
} elsif ($cgi->param('step') == 1) {
    step2();
} else {
    error('There was an error in form input.');
}

#### Subroutine: step1
# Make step 1 form
####
sub step1 {
	print $cgi->header;    
	my $sample_groups_href = parse_sample_groups_file(folder=>$fm->token());
	site_header('Make Java FIles');
	$sbeams->printStyleSheet();
	print h1('Make Files to Load into Multiple Experiment Viewer (MeV)'),
	      h2('Step 1:');
	      
	my @classes = ();
	print h2("Below are the files and Sample groups that will be used in Mev"),
		  h3("If there are any problems please go back and make corrections"),
			"<table>";
			
### Print out little table showing files for each sample_group
	foreach my $sample_group (
						map {$_->[0]}
						sort {$a->[1] <=> $b->[1]}
						map {  [$_, &first_key_val( $sample_groups_href->{$_})] } 
	 					keys %$sample_groups_href){
		next if $sample_group eq 'SAMPLE_NAMES'; #skip key not pointing a sample group
			
		print Tr(
			  td({-class=>'med_gray_bg'},"Sample Group"),
			  td({-class=>'rev_gray'},$sample_group)
			),
			Tr(
			  td({-class=>'grey_bg'}, scalar keys %{ $sample_groups_href->{$sample_group} }, " Files"),
			  td([sort keys  %{ $sample_groups_href->{$sample_group} } ])
			);
	}
	
	
	print '</table>';
	
	print $cgi->start_form(-name => 'make_files'),
	 	  hidden('token', $fm->token),
	 	  hidden('step', 1),
	 	  submit("Submit Job"),
	 	  end_form;
		  
	      
}
	

#### Subroutine: step2
# Make step 2 Jar up data, sign files, and copy to tomcat server
####
sub step2 {
	
	my $token = $fm->token();
	my $stanford_data_file = "${token}_annotated.txt";
	
	my $data_path = "$BC_UPLOAD_DIR/$token/$stanford_data_file";
	my $group_path = "$BC_UPLOAD_DIR/$token/$SAMPLE_GROUP_XML";
	
	print $cgi->header;    
	my $sample_groups_href = parse_sample_groups_file(folder=>$fm->token());
	site_header('Make Java FIles');
	$sbeams->printStyleSheet();
	print "Starting to process files..";
	
	
	
	copy_sign_jar(data_path => {PATH=>"$BC_UPLOAD_DIR/$token",
								FILE=>"$stanford_data_file",
							   },
				  groups 	=> {PATH=>"$BC_UPLOAD_DIR/$token",
								FILE=>"$SAMPLE_GROUP_XML",
							   },
				  token  	=> $token,
				  );
	
	print h1('Make Files to Load into MeV'),
	      h2('Step 2:'),
	      br,h3("Your data is ready to launch in Mev, click <a href='$MEV_JWS_BASE_HTML/$token/Affy_$token.jnlp'>here</a> to start");
}

#### Subroutine: copy_sign_jar
# Produce jar files each of the data files, copy them onto tomcat then sign them
####
sub copy_sign_jar {
	my %args = @_;
	my $token 		= $args{token};

	my %jnlp_info = ("token", $token);
##Loop thru the keys that point to full file paths for the data files that need to be made into a jar files
	
	foreach my $file_type ( ('data_path', 'groups') ){
		
		my $file_to_jar_href = $args{$file_type};
		my $jar_file_name = "${token}_${file_type}.jar"; 
		my $jar_local_path = "$token";

###Need to stored just the file name of the file to be jar(ed)		
		my $file_to_jar = $file_to_jar_href->{FILE};
		my $file_path = $file_to_jar_href->{PATH};
				
		$jnlp_info{$file_type} = {JAR_FILE => $jar_file_name,
								  JAR_PATH => $jar_local_path,
								  DATA_FILE =>$file_to_jar,
								 };
	
		
		
		my $java_out_path = "$MEV_JWS_BASE_DIR/$jar_local_path";
	$log->debug("JAVA OUT PATH '$java_out_path'");
unless (-d $java_out_path) {
##Make directory to hold jar files	
		umask(0000);					#delete for production
		my $umask = umask();			#delete for production
		mkdir($java_out_path, 0777) ||  
		error("Could not make directory for '$java_out_path' $!");	#TURN TO 0700 for PRODUCTION !!!!
}
##Make and run command to make jar file	
		my $command_line = "$JAVA_PATH/bin/jar -cf $java_out_path/$jar_file_name -C $file_path $file_to_jar";
		my $results = `$command_line`;
#		print "<br>Results for Make JAR for $file_type '$results'<br>$command_line<br>";
		
#               print "<BR><BR>Alias is $KEYALIAS, Store is $KEYSTORE, Pass is $KEYPASS\n";
##Make and run command to sign jar file
		$command_line = "$JAVA_PATH/bin/jarsigner -storepass $KEYPASS -keystore $KEYSTORE $java_out_path/$jar_file_name  $KEYALIAS";
		$results = `$command_line`;
#		print "Results for Signing JAR for $file_type '$results'<br>$command_line<br>";
		
	}
		
	make_jnlp(%jnlp_info);
}

#### Subroutine: make JNLP
# Make JNLP file and write to tomcat server
####
sub make_jnlp {
	
	my %args = @_;
	my $data_href 	= $args{data_path};
	my $group_href 	= $args{groups};
	my $token 		= $args{token};
	
	
	my $jnlps_file = "Affy_$token.jnlp";	



my $xml_data = qq~
<?xml version="1.0" encoding="utf-8"?>
	<jnlp
	  codebase="$MEV_JWS_BASE_HTML/$token"
	  href="$jnlps_file">
	  <information>
	    <title>ISB MeV</title>
	    <vendor>TIGR, ISB</vendor>
	    <homepage href="http://www.google.com"/>
	    <offline-allowed/>
	  </information>
	  <security>
	      <all-permissions/>
	  </security>
	  <resources>
	    <j2se version="1.4+" max-heap-size="1024M"/>
	    <jar href="$SHARED_JAVA_HTML/jars/TMEV_ISB.jar"/>
	    <jar href="$data_href->{JAR_FILE}"/>
	    <jar href="$group_href->{JAR_FILE}"/>
	  </resources>
	  <application-desc>
	    <argument>--webstart</argument>
	    <argument>jar://$data_href->{DATA_FILE}</argument>
	    <argument>jar://$group_href->{DATA_FILE}</argument>
	  </application-desc>
	</jnlp>
~;
	my $out_location = "$MEV_JWS_BASE_DIR/$token/$jnlps_file";
	
	open OUT, ">$out_location" or 
	error("Cannot open OUT file to write XML FILE $out_location $!"); 
	print OUT $xml_data;
	close OUT;      
}


#### Subroutine: error
# Print out an error message and exit
####
sub error {
    my ($error) = @_;

	print $cgi->header;    
	site_header("Make Java files");
	
	print h1("Make Mev Jar Files"),
	      h2("Error:"),
	      p($error);
	
	print "DEBUG INFO<br>";
	my @param_names = $cgi->param;
	foreach my $p (@param_names){
		print $p, " => ", $cgi->param($p),br; 
	}
	site_footer();
	
	exit(1);
}




