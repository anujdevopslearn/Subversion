{package SBEAMS::Microarray::Affy_file_groups;
	
our $VERSION = '1.00';

####################################################
=head1 NAME

SBEAMS::Microarray::Affy_file_groups - Methods to help find and upload a group of affy files into
SBEAMS::Microarray

=head1 SYNOPSIS

 use SBEAMS::Connection::Tables;
 use SBEAMS::Microarray::Tables;
 
 use SBEAMS::Microarray::Affy;
 use SBEAMS::Microarray::Affy_file_groups;

 my $sbeams_affy_groups = new SBEAMS::Microarray::Affy_file_groups;

$sbeams_affy_groups->setSBEAMS($sbeams);		#set the sbeams object into the sbeams_affy_groups


=head1 DESCRIPTION

Methods to work with the load_affy_array_files.pl to determine what a "group" of affy files should be.  When the script load_affy_array_files.pl
scans a directory tree it reads the file names.  These methods know what the files name should contain and can parse them to figure out what files
belong together by looking at the root_file_names.  Also contains some general methods for generating SQL to help display data on some of the 
cgi pages

=head2 EXPORT

None by default.



=head1 SEE ALSO

SBEAMS::Microarray::Affy;
lib/scripts/Microarray/load_affy_array_files.pl

=head1 AUTHOR

Pat Moss, E<lt>pmoss@systemsbiology.org<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2004 by Pat Moss

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.3 or,
at your option, any later version of Perl 5 you may have available.


=cut
##############################################################
use strict;
use vars qw($sbeams $self);		#HACK within the read_dir method had to set self to global since read below for more info

use File::Basename;
use File::Find;
use Data::Dumper;
use Carp;
use FindBin;

		
use SBEAMS::Connection::Tables;
use SBEAMS::Microarray::Tables;

use base qw(SBEAMS::Microarray::Affy);		#declare superclass




#######################################################
# Constructor
#######################################################
sub new {
	my $class = shift;
	
	my $self = {};
	
	bless $self, $class;
	
	
}
###############################################################################
# Receive the main SBEAMS object
###############################################################################
sub setSBEAMS {
    my $self = shift;
    $sbeams = shift;
    return($sbeams);
}


###############################################################################
# Provide the main SBEAMS object
###############################################################################
sub getSBEAMS {
    my $self = shift;
    return($sbeams);
}

###############################################################################
# Get/Set the directory to start searching in
#
#the Base directory holding the Affy files.
###############################################################################
sub base_dir {
	my $self = shift;
		
	if (@_){
		#it's a setter
		$self->{BASE_DIR} = $_[0];
	}else{
		#it's a getter
		$self->{BASE_DIR};
	}
}

###############################################################################
# Get/Set the file extension names to start searching for to make a valid group
#
#Return an array of the file extensions
###############################################################################
sub file_extension_names {
	my $either = shift;
	
		
	my $class = ref($either) ||$either;
	
	if (@_){
		#it's a setter
		$either->{FILE_EXTENSION_A_REF} = \@_;
	}else{
		#it's a getter
		@{ $either->{FILE_EXTENSION_A_REF} };
	}
}

###############################################################################
# Get/Set the VERBOSE status
#
#
###############################################################################
sub verbose {
	my $self = shift;
	
		
	if (@_){
		#it's a setter
		$self->{_VERBOSE} = $_[0];
	}else{
		#it's a getter
		$self->{_VERBOSE};
	}
}
###############################################################################
# Get/Set the DEBUG status
#
#
###############################################################################
sub debug {
	my $self = shift;
	
		
	if (@_){
		#it's a setter
		$self->{_DEBUG} = $_[0];
	}else{
		#it's a getter
		$self->{_DEBUG};
	}
}

###############################################################################
# check_previous_arrays
#
#Check to see if an affy_array exists in the db with the same root_name
#Give file_root name 
#return the affy_array_id PK or 0
###############################################################################
sub check_previous_arrays {
	my $method = "check_previous_arrays";
	
	my $self = shift;
	my %args = @_;
	
	my $root_name = $args{root_name};
	
	
	
	my $sql = qq~ SELECT affy_array_id
			FROM $TBMA_AFFY_ARRAY
			WHERE file_root like '$root_name'
		   ~;
		 
	my @rows = $sbeams->selectOneColumn($sql);
	
	if ($self->verbose() > 0){
		print "method '$method' SQL '$sql'\n";
		print "DATA RESULTS '@rows'\n";
	}
	
	
	if ($rows[0] =~ /^\d/){
		if ($self->verbose() > 0){
			print "RETURN ARRAY IN DB PK'$rows[0]'\n";
		}
		return $rows[0];		#return the affy_array_id if the record is in the database
	}else{
		if ($self->verbose() > 0){
			print "RETURN '0' ARRAY ROOT NOT IN DB\n";
		}
		return "ADD";
	}

}


#######################################################
# find_affy_array_id
# 
#used to get the array_id from the root_file name
# Provide the key value pair 'root_file_name'
# return the affy_array_id or 0 (zero) if no id exists
#######################################################
sub find_affy_array_id { 
	my $method = 'find_affy_array_id';

	my $self = shift;
	my %args = @_;
	
	unless (exists $args{root_file_name} ) {
		confess(__PACKAGE__ . "::$method need to provide key value pairs 'root_file_name'\n");
	}
	
	my $sql = qq~ SELECT affy_array_id
			FROM $TBMA_AFFY_ARRAY
			WHERE file_root like '$args{root_file_name}'
			
		  ~;
		  
	my ($affy_array_id) = $sbeams->selectOneColumn($sql);
	
	if ($affy_array_id){
		return $affy_array_id;
	}else{
		return 0;
	}
}
#######################################################
# find_affy_array_sample_id
#
# used to get the affy_array_sample_id given the affy_array_id
# Provide the key value pair 'root_file_name'
# return the affy_array_sample_id or 0 (zero) if no id exists
#######################################################
sub find_affy_array_sample_id { 
	my $method = 'find_affy_array_sample_id';

	my $self = shift;
	my %args = @_;
	
	unless (exists $args{affy_array_id} ) {
		confess(__PACKAGE__ . "::$method need to provide key value pairs 'affy_array_id'\n");
	}
	
	my $sql = qq~ SELECT affy_array_sample_id
			FROM $TBMA_AFFY_ARRAY
			WHERE affy_array_id = '$args{affy_array_id}'
			
		  ~;
		  
	my ($affy_array_sample_id) = $sbeams->selectOneColumn($sql);
	
	if ($affy_array_sample_id){
		return $affy_array_sample_id;
	}else{
		return 0;
	}
}

#######################################################
# get_all_affy_file_root_names
#
# used to get an array of all affy_file_root names
#Provide nothing
#Return an array of Names or 0 (zero) if none exists
#######################################################
sub get_all_affy_file_root_names { 
	my $method = 'get_all_affy_file_root_names';

	my $self = shift;
	
	
	my $sql = qq~ SELECT file_root
			FROM $TBMA_AFFY_ARRAY
		 ~;
		  
	my @all_file_names = $sbeams->selectOneColumn($sql);
	
	if (@all_file_names){
		return @all_file_names;
	}else{
		return 0;
	}
}
			
###############################################################################
# Set the file path	
#
#Foreach file found set the information into the Affy_file_groups object
#Provide key value pairs for keys root_file_name, file_ext,  file_path
#Return: scalar "HAS BEEN SEEN" or nothing 
###############################################################################
sub set_file_path {
	my $method = 'set_file_path';
	
	my $self = shift;
	my %args = @_;
	
	unless (exists $args{root_file_name} && $args{file_ext} && $args{file_path}) {
		confess(__PACKAGE__ . "::$method need to provide key value pairs 'root_file_name', 'file_ext', 'file_path'\n");
	}
	
	
	
	if ( $self->  {$args{root_file_name}}  {$args{file_ext}}) {		#check to see if this has already been set
		return "HAS BEEN SEEN"							#return 'HAS BEEN SEEN' if this value has been seen
	}
	
		
	return $self->  {ALL_FILES} {$args{root_file_name}}  {$args{file_ext}}   = $args{file_path};
}

###############################################################################
# Get the get_file_path	
#
#Provide Key value pairs root_file_name, file_ext  
#Return full file path or Zero
###############################################################################
sub get_file_path {
	my $method = 'get_file_path';
	
	my $self = shift;
	my %args = @_;
	
	unless (exists $args{root_file_name} && $args{file_ext}) {
		confess(__PACKAGE__ . "::$method Need to provide key value pairs 'root_file_name', 'file_ext'\n");
	}
	
	if (my $path =  $self->  {ALL_FILES}{$args{root_file_name}}  {$args{file_ext}} ) {		
		return  $path;
	}else{
		return 0;
	}	
}
###############################################################################
# Get  get_file_path_from_id	
#
#Provide Key value pair 'affy_array_id' 
#Return an array, (file_root, file_path_name) or 0 (zero) if it failed
###############################################################################
sub get_file_path_from_id {
	my $method = 'get_file_path_from_id';
	
	my $self = shift;
	
	my %args = @_;
	unless (exists $args{affy_array_id}  && $args{affy_array_id} =~ /^\d/) {
		confess(__PACKAGE__ . "::$method Need to provide key value pair for 'affy_array_id' VAL '$args{affy_array_id}'\n");
	}
	
	my $sql = qq~   SELECT afa.file_root, fp.file_path 
			FROM $TBMA_AFFY_ARRAY afa
			JOIN $TBMA_FILE_PATH fp ON (afa.file_path_id = fp.file_path_id)
			WHERE afa.affy_array_id = $args{affy_array_id}
		  ~;
	my ($results) = $sbeams->selectSeveralColumns($sql);
	
	
	if ($results) {
	
		return ($results->[0], $results->[1]);		#return the file_root_name and file_base_path
	}else{
		return 0;
	}
	
}
###############################################################################
# Get number of groups
#
#Return: Number of root_file names seen
###############################################################################
sub get_total_root_file_name_count {
	my $self = shift;
		
	return scalar (keys %{ $self->{ALL_FILES} } );
	
}
###############################################################################
# Get file group
#
#Return: Array of files paths a single root_file_name points to
###############################################################################
sub get_file_group {
	my $method  = 'get_file_group';
	
	my $self = shift;
	my %args = @_;
	
	
	unless (exists $args{'root_file_name'}) {
		confess(__PACKAGE__. "::$method Need to provide a key value pair for the key 'root_file_name'\n");
	}
	

												#get the keys for a single root name, pass them into map which will call the get_file_path method
	return ( map {$self->get_file_path(	root_file_name  => $args{root_file_name},	#return an array of file paths
						file_ext	=> $_,
					   )} keys %{ $self->{ALL_FILES} { $args{'root_file_name'} } } );
	
}

###############################################################################
# get get_affy_arrays_sql
#
#get all the arrays for a particular project_id from the database
###############################################################################
sub get_affy_arrays_sql{
	my $method = 'get_affy_arrays';
	
	my $self = shift;
	my %args = @_;
	
	unless ($args{project_id} ){
		confess(__PACKAGE__ . "::$method Need to provide key value pairs 'project_id'");
	}


	my $sql = qq~ SELECT afa.affy_array_id AS "Array_ID", 
				afa.file_root AS "File_Root", 
				st.name AS "Affy Chip Design", 
				afs.affy_array_sample_id AS "Sample_ID",
				afs.sample_tag AS "Sample_Tag",
				afs.sample_group_name AS "Sample Group Name",
				afs.full_sample_name AS "Full_Sample_Name",
				o.organism_name AS "Organism"
				FROM $TBMA_AFFY_ARRAY afa 
				LEFT JOIN $TBMA_AFFY_ARRAY_SAMPLE afs ON (afa.affy_array_sample_id = afs.affy_array_sample_id)
				LEFT JOIN $TBMA_SLIDE_TYPE st ON (afa.array_type_id = st.slide_type_id) 
				LEFT JOIN $TB_ORGANISM o ON (afs.organism_id = o.organism_id) 
				WHERE afs.project_id = $args{project_id} AND
				afs.record_status != 'D' AND 
				afa.record_status != 'D'
		    ~;
	
	return $sql;
}


###############################################################################
# get get_all_affy_info_sql
#
# get all the (affy_array_sample, affy_array) info for a group of arrays
###############################################################################
sub get_all_affy_info_sql{
	my $method = 'get_affy_arrays';
	
	my $self = shift;
	my %args = @_;
	
	unless ($args{affy_array_ids} ){
		confess(__PACKAGE__ . "::$method Need to provide key value pairs 'affy_array_ids' => 'a_ref' ");
	}

 	my $array_ids =  $args{affy_array_ids}; #pass in a string of comma delimited affy array ids
	
	
	my $sql = qq~

		SELECT afa.affy_array_id AS "Array ID", 
		afa.file_root            AS "File Root", 
		st.name                  AS "Slide Type",
		afs.sample_tag           AS "Sample Tag",
		ul.username              AS "User Name",
		proj.name                AS "Project Name",
		afa.affy_array_protocol_ids AS "Array Protcol Ids",
		afa.protocol_deviations  AS "Array Protocol Deviations",
		afa.comment              As "Array Comment",
		afa.processed_date       AS "Processed Date",
		afs.full_sample_name     AS "Full Name", 
		afs.sample_group_name    AS "Sample Group Name",
		o.organism_name          AS "Organism",
		afs.strain_or_line       AS "Strian or Line", 
		afs.individual           AS "Individual", 
		MOT2.name                AS "Sex",
		afs.age                  AS "Age", 
		afs.organism_part        AS "Organism Part", 
		afs.cell_line            AS "Cell Line", 
		afs.cell_type            AS "Cell Type", 
		afs.disease_state        AS "Disease_state", 
		afs.rna_template_mass 	 AS "Mass of RNA Labeled (ng)",
		afs.affy_sample_protocol_ids AS "Sample Protocol Ids",
		afs.protocol_deviations  AS "Sample Protocol Deviations", 
		afs.sample_description      AS "Sample Description",
		afs.sample_preparation_date AS "Sample Prep Date", 
		afs.treatment_description   AS "Treatment Description",
		afs.comment                 AS "Comment"
		FROM $TBMA_AFFY_ARRAY afa 
		JOIN $TBMA_AFFY_ARRAY_SAMPLE afs ON (afa.affy_array_sample_id = afs.affy_array_sample_id)
		JOIN $TBMA_SLIDE_TYPE st ON (afa.array_type_id = st.slide_type_id) 
		JOIN $TB_ORGANISM o ON (afs.organism_id = o.organism_id)
		LEFT JOIN $TB_PROJECT proj ON ( afs.project_id = proj.project_id)
		JOIN $TB_USER_LOGIN ul ON  (ul.user_login_id = afa.user_id)
		LEFT JOIN $TB_MGED_ONTOLOGY_TERM MOT2 ON ( MOT2.MGED_ontology_term_id = afs.sex_ontology_term_id ) 
		WHERE afa.affy_array_id IN ($array_ids)
	 ~;
	 
	 
	return $sql;
}
###############################################################################
# export_data_array_sample_info
#
# use the sql statement to dump out all the information for a group arrays
###############################################################################
sub export_data_array_sample_info{
	my $method = 'export_data_array_sample_info';
	
	my $self = shift;
	my %args = @_;
	my $sql = $args{sql};
	my %resultset = ();
	my $resultset_ref = \%resultset;
	
	unless ($sql){
		confess(__PACKAGE__ . "::$method Need to provide key value pairs 'sql' \n");
	}
	$sbeams->output_mode('tsv');
	
	$sbeams->fetchResultSet(sql_query=>$sql,
				resultset_ref=>$resultset_ref,
				);
				
	my @column_titles = @{$resultset_ref->{column_list_ref}};
	
	my $aref = $$resultset_ref{data_ref};			#data is stored as an array of arrays from the $sth->fetchrow_array each row a row from the database holding an aref to all the values
	
	my $all_data = '';
	
	$all_data .= join "\t", @column_titles;			#add the column titles
	$all_data .= "\n";					#add record separator
	foreach my $row_aref ( @ { $aref }){
		foreach my $column ( @{$row_aref}){
		
			$all_data .= "$column\t";		#package up the data as a tsv
		}
		$all_data .= "\n";				#add a return at the end or $.
	}
	
	return $all_data ;
}


###############################################################################
# get sorted_root_names
#
#Makes inserting the data into the database and viewing the data much cleaner
#Return:A sorted Array of root_file names.  
###############################################################################
sub sorted_root_names {
	my $self = shift;
		
	
	my @sorted_root_names =  map { $_->[0]}
								#element [0] should be the full root_file_name
				sort {	my $a_date      = $$a[1];	#should be the YYYYMMDD
					my $a_scan_numb = $$a[2];	#should be the scan number
					
					my $b_date      = $$b[1];
					my $b_scan_numb = $$b[2];
				 
				 	$a_date	<=> $b_date
						||
					$a_scan_numb <=> $b_scan_numb
						||
					$$a[0] cmp $$b[0]	
				 
				 }
				 
				map { [$_, split /_/]} keys %{$self->{ALL_FILES}};	# example root file name '20040609_03_LPS1-60'
		
	return @sorted_root_names;
	
}


###############################################################################
# read_dirs
#
#Reads the Base directory holding the Affy files.
###############################################################################
sub read_dirs {
	$self = shift;					#need to set global object since _group_files sub needs to write to the instance to store all the data
							#if multiple objects are made bad things might happen.....  Need to test
	my %args = @_;
	
	###define local variables
	my $base_dir = $self->base_dir();
	
	
	
	find(\&_group_files, $base_dir);		#find sub in File::Find

	if ($self->verbose > 0){
		if ($self->debug > 1){
			print Dumper ($self);
		}
		my $file_extn_count = scalar(   $self->file_extension_names()  ); #get a count of the number of file types.  If a group of files has this many it's good
		my $total_file_count = $self->get_total_root_file_name_count();
		my @good_group = grep {$file_extn_count == scalar ($self->get_file_group(root_file_name => $_))}  $self->sorted_root_names(); #grep on the number of keys in the file hash
		my @bad_count = grep  {$file_extn_count >  scalar ($self->get_file_group(root_file_name => $_))}  $self->sorted_root_names();
		print "TOTAL NUMB FILE EXT '$file_extn_count'\n";
		print "GOOD FILE GROUPS ". scalar(@good_group). " of $total_file_count TOTAL\n '@good_group'\n";
		print scalar(@bad_count) . " BAD GROUPS of $total_file_count\n";
	}

}



###############################################################################
# _group_files
#
#sub used by File::Find to populate the a hash of hashes, contained within the Affy_file_groups object, if files are found that
#match one of the file extensions in the @FILE_TYPES array
###############################################################################

sub _group_files {
	#my $self = shift;	#global instance set up read_dirs
	
	
	
	foreach my $file_ext ( $self->file_extension_names() ){  		#assuming that all files will end in some extension 
		
		if ( $_ =~ /(.*)\.$file_ext/){					#check to see if one of the file extensions matches to a file found within the default data dir
			print "FILE $1 EXT $file_ext\n";
		
			#Data into a hash of hashes with {file root name}{file extension} = "Full path to file"
			
			
			my $exists = $self->set_file_path(	root_file_name => $1,
					   			file_ext	=> $file_ext,
								file_path	=> $File::Find::name
							);
			
			
			if ($exists eq 'HAS BEEN SEEN' ){
				die "WOW I HAVE SEEN THIS FILE BEFORE BUT IN A DIFFERENT SPOT\n",
					"PREVIOUS DATA FILE '". $self->get_file_path(root_file_name => $1,
										     file_ext => $file_ext,
									             ) . "'\n";
					"CURRENT  DATA FILE '$File::Find::name'\n";
			}
		}
	}
}


###############################################################################
# Get/Set group_error
#
#If a group fails to meet minimum amount of data to upload set a ERROR FLAG
###############################################################################
sub group_error {
	my $method = 'group_error';
	my $self = shift;
	
	my %args = @_;
	
	if (exists $args{error} && $args{root_file_name}){
		
		
		return $self-> { $args{root_file_name} } {ERROR} .= "\n$args{error}";	#might be more then one error so append on new errors
	
	}elsif (exists $args{root_file_name} ){		
		
		$self-> {$args{root_file_name} } {ERROR};
	}else{
		confess(__PACKAGE__ . "::$method Need to provide key value pairs 'root_file_name', 'error'");
	
	}
}
	


###############################################################################
# check_file_group
#
#sub used to check if the minimal amount of data is present to consider uploading the data
###############################################################################

sub check_file_group {
	my $method = 'check_file_group';
	
	my $self = shift;
	
	my %args = @_;
	
	unless (exists $args{root_file_name} ) {
		confess( __PACKAGE__ . "::$method Need to provide key value pair 'root_file_name', \n");
	}
	
	my $file_name = $args{root_file_name};
	
	if (($self->get_file_path(root_file_name=> $args{root_file_name}, file_ext => 'XML' )
						|| 
	     $self->get_file_path(root_file_name=> $args{root_file_name}, file_ext => 'INFO' ))
						&&
	    ($self->get_file_path(root_file_name=> $args{root_file_name}, file_ext => 'CEL' )
	     					||
	     $self->get_file_path(root_file_name=> $args{root_file_name}, file_ext => 'CHP'  ))
	   ) 
	{
	    	
		print "\nGOOD FILE '$file_name'\n";
		return "YES";
	}else{
		
		$self->group_error(root_file_name => $args{root_file_name},
				   error	  =>	"Cannot not find Minimum Number of files to Upload\n",
				  );
	
		return "NO";
	}
}


}#closing bracket for the package

1;
