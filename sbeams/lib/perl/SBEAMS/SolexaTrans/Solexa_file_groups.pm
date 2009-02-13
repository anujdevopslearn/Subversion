###############################################################################
# Program     : SBEAMS::SolexaTrans::Solexa_file_groups
# Author      : Denise Mauldin <dmauldin@systemsbiology.org>
#
# Description :  Module that provides methods for associating Solexa
# files with appropriate groups.
# 
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
#
###############################################################################


{package SBEAMS::SolexaTrans::Solexa_file_groups;
	
our $VERSION = '1.00';
use SBEAMS::Connection::Settings;

####################################################
=head1 NAME

SBEAMS::SolexaTrans::Solexa_file_groups - Methods to help find and upload a group of Solexa files into
SBEAMS::SolexaTrans

=head1 SYNOPSIS

 use SBEAMS::Connection::Tables;
 use SBEAMS::Connection::Log;
 use SBEAMS::SolexaTrans::Tables;
 
 use SBEAMS::SolexaTrans::SolexaTrans;
 use SBEAMS::SolexaTrans::Solexa_file_groups;

 my $sbeams_affy_groups = new SBEAMS::SolexaTrans::Affy_file_groups;
 my $log = SBEAMS::Connection::Log->new();

$sbeams_solexa_groups->setSBEAMS($sbeams);		#set the sbeams object into the sbeams_solexa_groups


=head1 DESCRIPTION

Methods to work with the load_solexatrans.pl to determine what a "group" of solexa runs should be.  When the script load_solexatrans.pl scans a directory tree it reads the file names.  These methods know what the files name should contain and can parse them to figure out what files belong together by looking at the root_file_names.  Also contains some general methods for generating SQL to help display data on some of the cgi pages

=head2 EXPORT

None by default.



=head1 SEE ALSO

SBEAMS::SolexaTrans::Solexa;
lib/scripts/SolexaTrans/load_solexatrans.pl

=head1 AUTHOR

Denise Mauldin <lt>dmauldin@systemsbiology.org<gt>

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
use SBEAMS::SolexaTrans::Tables;
use SBEAMS::BioLink::Tables;
use SBEAMS::Connection::Log;

my $log = SBEAMS::Connection::Log->new();

use base qw(SBEAMS::SolexaTrans::Solexa);		#declare superclass




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
#the Base directory holding the Solexa files.
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
		@{$either->{FILE_EXTENSION_A_REF}};
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
# check_previous_runs  REDUNDANT !!! USE find_solexa_run_id
#
#Check to see if a solexa run exists in the db with the same root_name
#Give file_root name 
#return the solexa_run_id PK or 0
###############################################################################
sub check_previous_runs {
	my $method = "check_previous_runs";

	my $self = shift;
	my %args = @_;
	
	my $root_name = $args{root_name};
	
	my $sql = qq~ SELECT solexa_run_id
			FROM $TBST_SOLEXA_RUN
			WHERE file_root like '$root_name'
		   ~;
		 
	my @rows = $sbeams->selectOneColumn($sql);
	
	if ($self->verbose() > 0){
		print "method '$method' SQL '$sql'\n";
		print "DATA RESULTS '@rows'\n";
	}
	
	if (defined $rows[0] && $rows[0] =~ /^\d/){
		if ($self->verbose() > 0){
			print "RETURN RUN IN DB PK'$rows[0]'\n";
		}
		return $rows[0];		#return the solexa_run_id if the record is in the database
	}else{
		if ($self->verbose() > 0){
			print "RETURN '0' RUN ROOT NOT IN DB\n";
		}
	#	return "ADD";
		return 0;
	}

}

#######################################################
# find_flow_cell_lane_id
# 
# used to get the flow_cell_lane_id from the lane number
# and flow cell id
# Provide the key value pair 'lane_number' and 'flow_cell_id'
# return the flow_cell_lane_id or 0 (zero) if no id exists
#######################################################
sub find_flow_cell_lane_id {
	my $method = 'find_flow_cell_lane_id';

	my $self = shift;
	my %args = @_;

        unless (exists $args{"lane_number"} && exists $args{"flow_cell_id"} ) {
                confess(__PACKAGE__ . "::$method need to provide key value pairs 'lane_number' and 'flow_cell_id'\n");
        }

        my $sql = qq~ SELECT flow_cell_lane_id
                        FROM $TBST_SOLEXA_FLOW_CELL_LANE
                        WHERE lane_number = '$args{"lane_number"}'
			AND flow_cell_id = '$args{"flow_cell_id"}'
                        AND record_status != 'D'
                  ~;

        my ($fcl_id) = $sbeams->selectOneColumn($sql);

        if ($fcl_id){
                return $fcl_id;
        }else{
                return 0;
        }
}

#######################################################
# find_flow_cell_id
# 
# used to get the flow_cell_id from the flow cell name
# and flow cell id
# Provide the key value pair 'flow_cell_name' and 'flow_cell_id'
# return the flow_cell_id or 0 (zero) if no id exists
#######################################################
sub find_flow_cell_id {
	my $method = 'find_flow_cell_id';

	my $self = shift;
	my %args = @_;

        unless (exists $args{"flow_cell_name"} && exists $args{"flow_cell_id"} ) {
                confess(__PACKAGE__ . "::$method need to provide key value pairs 'flow_cell_name' and 'flow_cell_id'\n");
        }

        my $sql = qq~ SELECT flow_cell_id
                        FROM $TBST_SOLEXA_FLOW_CELL
                        WHERE name = '$args{"flow_cell_name"}'
			AND flow_cell_id = '$args{"flow_cell_id"}'
                        AND record_status != 'D'
                  ~;

        my ($flow_cell_id) = $sbeams->selectOneColumn($sql);

        if ($flow_cell_id){
                return $flow_cell_id;
        }else{
                return 0;
        }
}


#######################################################
# find_solexa_run_id
# 
#used to get the solexa_run_id from the root_file name
# Provide the key value pair 'root_file_name'
# return the solexa_run_id or 0 (zero) if no id exists
#######################################################
sub find_solexa_run_id { 
	my $method = 'find_solexa_run_id';

	my $self = shift;
	my %args = @_;
	
	unless (exists $args{root_file_name} ) {
		confess(__PACKAGE__ . "::$method need to provide key value pairs 'root_file_name'\n");
	}
	
	my $sql = qq~ SELECT solexa_run_id
			FROM $TBST_SOLEXA_RUN
			WHERE file_root like '$args{root_file_name}'
			AND record_status != 'D'
			
		  ~;
print "tbst_solexa_run $TBST_SOLEXA_RUN\n";
	my ($solexa_run_id) = $sbeams->selectOneColumn($sql);
	
	if ($solexa_run_id){
		return $solexa_run_id;
	}else{
		return 0;
	}
}
#######################################################
# find_solexa_sample_id
#
# used to get the solexa_sample_id given the full_sample_name
# Provide the key value pair 'root_file_name'
# return the solexa_run_sample_id or 0 (zero) if no id exists
#######################################################
sub find_solexa_sample_id { 
	my $method = 'find_solexa_sample_id';

	my $self = shift;
	my %args = @_;
	
	unless (exists $args{full_sample_name} || exists $args{solexa_run_id} ) {
		confess(__PACKAGE__ . "::$method need to provide key value pairs 'full_sample_name'\n");
	}
	my $sql;

        if ($args{full_sample_name}) {
	   $sql = qq~ SELECT solexa_sample_id
			FROM $TBST_SOLEXA_SAMPLE
			WHERE full_sample_name = '$args{full_sample_name}'
			
		  ~;
        } elsif ($args{solexa_run_id}) {
	   $sql = qq~ SELECT FCLS.solexa_sample_id
		      FROM $TBST_SOLEXA_FLOW_CELL_LANE_SAMPLES FCLS
		      LEFT JOIN $TBST_SOLEXA_FLOW_CELL_LANE FCL on 
			FCLS.flow_cell_lane_id = FCL.flow_cell_lane_id
		      LEFT JOIN $TBST_SOLEXA_FLOW_CELL FC on
			FCL.flow_cell_id = FC.flow_cell_id
		      LEFT JOIN $TBST_SOLEXA_RUN SR on
			FC.flow_cell_id = SR.flow_cell_id
		      WHERE SR.solexa_run_id = $args{solexa_run_id}
		  ~;
	}
		  
	my ($solexa_sample_id) = $sbeams->selectOneColumn($sql);
	
	if ($solexa_sample_id){
		return $solexa_sample_id;
	}else{
		return 0;
	}
}

#######################################################
# get_all_solexa_file_root_names
#
# used to get an array of all solexa_file_root names
#Provide nothing
#Return an array of Names or 0 (zero) if none exists
#######################################################
sub get_all_solexa_file_root_names { 
	my $method = 'get_all_solexa_file_root_names';

	my $self = shift;
	
	my $sql = qq~ SELECT file_root
			FROM $TBST_SOLEXA_RUN
			WHERE record_status != 'D'
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
#Foreach file found set the information into the Solexa_file_groups object
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
	
	if ( $self->{$args{root_file_name}}{$args{file_ext}}) {		#check to see if this has already been set
		return "HAS BEEN SEEN"					#return 'HAS BEEN SEEN' if this value has been seen
	}
		
	return $self->{ALL_FILES}{$args{root_file_name}}{$args{file_ext}} = $args{file_path};
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
	
	if (my $path =  $self->{ALL_FILES}{$args{root_file_name}}{$args{file_ext}} ) {		
		return  $path;
	}else{
		return 0;
	}	
}
###############################################################################
# Get  get_file_path_from_id	
#
#Provide Key value pair 'solexa_fcl_id' 
#Return an array, (file_root, file_path_name) or 0 (zero) if it failed
###############################################################################
sub get_file_path_from_id {
	my $method = 'get_file_path_from_id';
	
	my $self = shift;
	
	my %args = @_;
	unless (exists $args{solexa_fcl_id}  && $args{solexa_fcl_id} =~ /^\d/) {
		confess(__PACKAGE__ . "::$method Need to provide key value pair for 'solexa_fcl_id' VAL '$args{solexa_fcl_id}'\n");
	}
	
	my $sql = qq~   SELECT EOF.file_path, RDP.file_path
			FROM $TBST_SOLEXA_PIPELINE_RESULTS SPR
			JOIN $TBST_FILE_PATH EOF ON (SPR.ELAND_OUTPUT_FILE_ID = EOF.FILE_PATH_ID)
                        JOIN $TBST_FILE_PATH RDP ON (SPR.RAW_DATA_PATH_ID = RDP.FILE_PATH_ID)
			WHERE SPR.FLOW_CELL_LANE_ID = $args{solexa_fcl_id}
                        AND EOF.RECORD_STATUS != 'D'
                        AND RDP.RECORD_STATUS != 'D'
		  ~;
	my ($results) = $sbeams->selectSeveralColumns($sql);
	
	
	if ($results) {
		# return the eland_output_file and the raw_data_path
		return ($results->[0], $results->[1]);
	}else{
		return 0;
	}
	
}

###############################################################################
# check_for_file_existance
#
#Give the solexa_run_id, root_name, file_ext 
#Pull the file base path from the database then do a file exists on the full file path
#Return the 1 if it exists or 0 if it does not
###############################################################################
sub check_for_file {
	my $self = shift;
	my %args = @_;

	my $solexa_run_id  = $args{pk_id};
	my $root_name = $args{file_root_name};
	my $file_ext  = $args{file_extension}; #Fix me same query is ran to many times, store the data localy
	  

		my $sql = qq~  SELECT fp.file_path 
		FROM $TBST_SOLEXA_RUN sr, $TBST_FILE_PATH fp 
		WHERE sr.file_path_id = fp.file_path_id
		AND sr.solexa_run_id = $solexa_run_id
	   ~;
	my ($path) = $sbeams->selectOneColumn($sql);

		my $file_path = "$path/$root_name.$file_ext";

	if ( -e $file_path ) {
		return 1;
	}else {
		#print "MISSING FILE '$file_path'<br/>";
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
	#return an array of file paths
	return ( map {$self->get_file_path(	root_file_name  => $args{root_file_name},	
						file_ext	=> $_,
					   )} keys %{ $self->{ALL_FILES}{$args{'root_file_name'}} } );
	
}

###############################################################################
# get get_solexa_sample_sql
#
#get all the samples for a particular project_id from the database
###############################################################################
sub get_solexa_sample_sql{
	my $method = 'get_solexa_sample';
	
	my $self = shift;
	my %args = @_;
	
	unless ($args{project_id} ){
		confess(__PACKAGE__ . "::$method Need to provide key value pairs 'project_id'");
	}
	
	my $constraint = $args{constraint};

	my $sql = qq~ SELECT    ss.solexa_sample_id AS "Sample_ID",
				ss.sample_tag AS "Sample_Tag",
				ss.sample_group_name AS "Sample Group Name",
				ss.full_sample_name AS "Full_Sample_Name",
				o.organism_name AS "Organism"
				FROM $TBST_SOLEXA_SAMPLE ss 
				LEFT JOIN $TB_ORGANISM o ON (ss.organism_id = o.organism_id) 
				WHERE ss.project_id IN ($args{project_id}) 
				AND ss.record_status != 'D'
		    ~;
	
	if ($constraint){
		$sql .= $constraint;
	}
	
	
	return $sql;
}

###############################################################################
# get_solexa_sample_pipeline_sql
#
#get all the samples for a particular project_id from the database
# where those samples can be run by the solexatrans pipeline
###############################################################################
sub get_solexa_sample_pipeline_sql{
	my $method = 'get_solexa_sample_pipeline_sql';
	
	my $self = shift;
	my %args = @_;
	
	unless ($args{project_id} ){
		confess(__PACKAGE__ . "::$method Need to provide key value pairs 'project_id'");
	}
	
	my $constraint = $args{constraint};

	my $sql = qq~ SELECT    ss.solexa_sample_id AS "Sample_ID",
				ss.sample_tag AS "Sample_Tag",
				ss.sample_group_name AS "Sample Group Name",
				ss.full_sample_name AS "Full_Sample_Name",
				o.organism_name AS "Organism"
				FROM $TBST_SOLEXA_SAMPLE ss 
				LEFT JOIN $TB_ORGANISM o ON (ss.organism_id = o.organism_id) 
				LEFT JOIN $TBST_SOLEXA_SAMPLE_PREP_KIT sspk
				  ON (ss.solexa_sample_prep_kit_id = sspk.solexa_sample_prep_kit_id)
				WHERE ss.project_id IN ($args{project_id}) 
				AND sspk.restriction_enzyme is not null
				AND ss.record_status != 'D'
				AND sspk.record_status != 'D'
		    ~;
	
	if ($constraint){
		$sql .= $constraint;
	}
	
	
	return $sql;
}



###############################################################################
# get get_solexa_flow_cell_sql
#
#get all the flow_cells for a particular project_id from the database
###############################################################################
sub get_solexa_flow_cell_sql{
	my $method = 'get_solexa_flow_cell';
	
	my $self = shift;
	my %args = @_;
	
	unless ($args{project_id} ){
		confess(__PACKAGE__ . "::$method Need to provide key value pairs 'project_id'");
	}
	
	my $constraint = $args{constraint};

	my $sql = qq~ SELECT    sfc.flow_cell_id AS "Solexa_Flow_Cell_ID", 
				ss.solexa_sample_id AS "Sample_ID",
				ss.sample_tag AS "Sample_Tag",
				ss.sample_group_name AS "Sample Group Name",
				ss.full_sample_name AS "Full_Sample_Name",
				o.organism_name AS "Organism"
				FROM $TBST_SOLEXA_SAMPLE ss 
				LEFT JOIN $TB_ORGANISM o ON (ss.organism_id = o.organism_id) 
                                LEFT JOIN $TBST_SOLEXA_FLOW_CELL_LANE_SAMPLES sfcls on 
                                   (ss.solexa_sample_id = sfcls.solexa_sample_id)
                                LEFT JOIN $TBST_SOLEXA_FLOW_CELL_LANE sfcl on
                                   (sfcls.flow_cell_lane_id = sfcl.flow_cell_lane_id)
                                LEFT JOIN $TBST_SOLEXA_FLOW_CELL sfc on
                                   (sfcl.flow_cell_id = sfc.flow_cell_id)
				WHERE ss.project_id IN ($args{project_id}) 
				AND ss.record_status != 'D'
				AND sfcls.record_status != 'D'
				AND sfcl.record_status != 'D'
				AND sfc.record_status != 'D'
		    ~;
	
	if ($constraint){
		$sql .= $constraint;
	}
	
	
	return $sql;
}

###############################################################################
# get get_solexa_flow_cell_lane_sql
#
#get all the flow_cells for a particular project_id from the database
###############################################################################
sub get_solexa_flow_cell_lane_sql{
	my $method = 'get_solexa_flow_cell_lane';
	
	my $self = shift;
	my %args = @_;
	
	unless ($args{project_id} ){
		confess(__PACKAGE__ . "::$method Need to provide key value pairs 'project_id'");
	}
	
	my $constraint = $args{constraint};

	my $sql = qq~ SELECT    
				ss.solexa_sample_id AS "Sample_ID",
				ss.sample_tag AS "Sample_Tag",
				ss.sample_group_name AS "Sample Group Name",
				sfcl.flow_cell_lane_id AS "Solexa_Flow_Cell_Lane_ID",
				sfcl.lane_number as "Solexa Lane Number",
				o.organism_name AS "Organism"
				FROM $TBST_SOLEXA_SAMPLE ss 
				LEFT JOIN $TB_ORGANISM o ON (ss.organism_id = o.organism_id) 
                                LEFT JOIN $TBST_SOLEXA_FLOW_CELL_LANE_SAMPLES sfcls on 
                                   (ss.solexa_sample_id = sfcls.solexa_sample_id)
                                LEFT JOIN $TBST_SOLEXA_FLOW_CELL_LANE sfcl on
                                   (sfcls.flow_cell_lane_id = sfcl.flow_cell_lane_id)
				WHERE ss.project_id IN ($args{project_id}) 
				AND ss.record_status != 'D'
				AND sfcls.record_status != 'D'
				AND sfcl.record_status != 'D'
		    ~;
	
	if ($constraint){
		$sql .= $constraint;
	}
	
	
	return $sql;
}

###############################################################################
# get get_solexa_pipeline_run_info_sql
#
#get the information to run the solexaTrans pipeline 
###############################################################################
sub get_solexa_pipeline_run_info_sql{
	my $method = 'get_solexa_pipeline_run_info';
	
	my $self = shift;
	my %args = @_;
	
	unless ($args{project_id} && $args{solexa_sample_ids} ){
		confess(__PACKAGE__ . "::$method Need to provide key value pairs 'project_id' and 'solexa_sample_ids'");
	}
	
	my $constraint = $args{constraint};

	my $sql = qq~ SELECT    
				ss.solexa_sample_id AS "Sample_ID",
                                efi.file_path as "ELAND_Output_File",
                                rdp.file_path as "Raw_Data_Path",
                                ss.alignment_end_position - ss.alignment_start_position+1 as "Tag_Length",
                                srg.name as "Genome"
				FROM $TBST_SOLEXA_SAMPLE ss
                                LEFT JOIN $TBST_SOLEXA_FLOW_CELL_LANE_SAMPLES sfcls on 
                                   (ss.solexa_sample_id = sfcls.solexa_sample_id)
                                LEFT JOIN $TBST_SOLEXA_FLOW_CELL_LANE sfcl on
                                   (sfcls.flow_cell_lane_id = sfcl.flow_cell_lane_id)
                                LEFT JOIN $TBST_SOLEXA_PIPELINE_RESULTS spr on
                                   (sfcl.flow_cell_lane_id = spr.flow_cell_lane_id)
                                LEFT JOIN $TBST_FILE_PATH efi on
                                   (spr.eland_output_file_id = efi.file_path_id)
                                LEFT JOIN $TBST_FILE_PATH rdp on
                                   (spr.raw_data_path_id = rdp.file_path_id)
                                LEFT JOIN $TBST_SOLEXA_REFERENCE_GENOME srg on 
                                   (ss.solexa_reference_genome_id = srg.solexa_reference_genome_id)
				WHERE ss.project_id IN ($args{project_id})
                                AND ss.solexa_sample_id in ($args{solexa_sample_ids})
				AND ss.record_status != 'D'
				AND sfcls.record_status != 'D'
				AND sfcl.record_status != 'D'
                                AND spr.record_status != 'D'
                                AND efi.record_status != 'D'
                                AND rdp.record_status != 'D'
		    ~;
	
	if ($constraint){
		$sql .= $constraint;
	}
	
	
	return $sql;
}



###############################################################################
# get get_solexa_sql
#
#get all the runs for a particular project_id from the database
###############################################################################
sub get_solexa_run_sql{
	my $method = 'get_solexa_run';
	
	my $self = shift;
	my %args = @_;
	
	unless ($args{project_id} ){
		confess(__PACKAGE__ . "::$method Need to provide key value pairs 'project_id'");
	}
	
	my $constraint = $args{constraint};

	my $sql = qq~ SELECT sr.solexa_run_id AS "Solexa_Run_ID", 
				sr.file_root AS "File_Root", 
				sfs.solexa_sample_id AS "Sample_ID",
				sfs.sample_tag AS "Sample_Tag",
				sfs.sample_group_name AS "Sample Group Name",
				sfs.full_sample_name AS "Full_Sample_Name",
				o.organism_name AS "Organism"
				FROM $TBST_SOLEXA_RUN sr 
				LEFT JOIN $TBST_SOLEXA_SAMPLE sfs ON (sr.solexa_sample_id = sfs.solexa_sample_id)
				LEFT JOIN $TB_ORGANISM o ON (sfs.organism_id = o.organism_id) 
				WHERE sfs.project_id IN ($args{project_id}) AND
				sfs.record_status != 'D'
		    ~;
	
	if ($constraint){
		$sql .= $constraint;
	}
	
	
	return $sql;
}


###############################################################################
# get get_all_solexa_info_sql
#
# get all the (solexa_sample, solexa) info for a group of solexa runs
# 
# return all info if no solexa ids passed
###############################################################################
sub get_all_solexa_info_sql{
	my $method = 'get_solexa_runs';
	
	my $self = shift;
	my %args = @_;
	
  # Modified to allow bulk lookup
  my $where = '';
  if ( $args{solexa_run_ids} ) {  # optional csv solexa ids
    $where = "WHERE sr.solexa_run_id IN ( $args{solexa_run_ids} )";
  }
	
	
	my $sql = qq~

		SELECT sr.solexa_run_id       AS "Solexa Run ID", 
		sr.file_root                  AS "File Root", 
		ss.sample_tag                 AS "Sample Tag",
		ul.username                   AS "User Name",
		proj.name                     AS "Project Name",
		sr.solexa_run_protocol_ids    AS "Solexa Protcol Ids",
		sr.protocol_deviations        AS "Solexa Protocol Deviations",
		sr.comment                    As "Solexa Run Comment",
		sr.processed_date             AS "Processed Date",
		ss.full_sample_name           AS "Full Name", 
		ss.sample_group_name          AS "Sample Group Name",
		o.organism_name               AS "Organism",
		ss.strain_or_line             AS "Strain or Line", 
		ss.individual                 AS "Individual", 
		ss.age                        AS "Age", 
		ss.organism_part              AS "Organism Part", 
		ss.cell_line                  AS "Cell Line", 
		ss.cell_type                  AS "Cell Type", 
		ss.disease_state              AS "Disease_state", 
		ss.template_mass 	      AS "Mass of template Labeled (ng)",
		ss.solexa_sample_protocol_ids AS "Sample Protocol Ids",
		ss.protocol_deviations        AS "Sample Protocol Deviations", 
		ss.sample_description         AS "Sample Description",
		ss.sample_preparation_date    AS "Sample Prep Date", 
		ss.treatment_description      AS "Treatment Description",
		ss.comment                    AS "Comment"
		FROM $TBST_SOLEXA_RUN sr
		JOIN $TBST_SOLEXA_SAMPLE ss ON (sr.solexa_sample_id = ss.solexa_sample_id)
		JOIN $TB_ORGANISM o ON (ss.organism_id = o.organism_id)
		LEFT JOIN $TB_PROJECT proj ON ( ss.project_id = proj.project_id)
		JOIN $TB_USER_LOGIN ul ON  (ul.user_login_id = sr.user_id)
    		$where
	 	ORDER BY sr.solexa_run_id ASC
	 ~;
	 
	 
	return $sql;
}

###############################################################################
# get get_solexa_geo_info_sql
#
# get all the (solexa_sample, solexa_run) info for a group of solexa runs
# querying on file root
###############################################################################
sub get_solexa_geo_info_sql{
	my $method = 'get_solexa_runs';
	
	my $self = shift;
	my %args = @_;
	
	unless ($args{file_roots} ){
		confess(__PACKAGE__ . "::$method Need to provide key value pairs 'file_roots' => 'string of csv file root(s)' ");
	}

 	my $file_roots =  $args{file_roots}; #pass in a string of comma delimited solexa run ids
	
	
	my $sql = qq~

		SELECT sr.solexa_run_id AS "Solexa Run ID", 
		sr.file_root            AS "File Root", 
		sfs.sample_tag           AS "Sample Tag",
		o.organism_name          AS "Organism",
		sfs.sample_description      AS "Sample Description",
		sfs.treatment_description   AS "Treatment Description",
		sr.solexa_protocol_ids AS "Solexa Protocol Ids",
		sr.protocol_deviations  AS "Solexa Protocol Deviations",
		sfs.full_sample_name     AS "Full Name",
		sfs.strain_or_line       AS "Strain or Line",
		sfs.individual           AS "Individual",
		MOT2.name                AS "Sex",
		sfs.age                  AS "Age",
		sfs.organism_part        AS "Organism Part",
		sfs.cell_line            AS "Cell Line",
		sfs.cell_type            AS "Cell Type",
		sfs.disease_state        AS "Disease_state",
		sfs.template_mass 	 AS "Mass of Template Labeled (ng)",
		sfs.affy_sample_protocol_ids AS "Sample Protocol Ids",
		sfs.protocol_deviations  AS "Sample Protocol Deviations",
		sfs.sample_preparation_date AS "Sample Prep Date",
		sfs.comment                 AS "Comment",
		f.file_path            AS "File Path"
		FROM $TBST_SOLEXA_RUN sr
		JOIN $TBST_FILE_PATH f ON (sr.file_path_id=f.file_path_id)
		JOIN $TBST_SOLEXA_SAMPLE sfs ON (sr.solexa_sample_id = sfs.solexa_sample_id)
		JOIN $TB_ORGANISM o ON (sfs.organism_id = o.organism_id)
		LEFT JOIN $TB_PROJECT proj ON ( sfs.project_id = proj.project_id)
		JOIN $TB_USER_LOGIN ul ON  (ul.user_login_id = sr.user_id)
		LEFT JOIN $TBBL_MGED_ONTOLOGY_TERM MOT2 ON ( MOT2.MGED_ontology_term_id = sfs.sex_ontology_term_id ) 
		WHERE sr.file_root IN ($file_roots)
		AND sr.record_status != 'D'
	~;
	 
	 
	return $sql;
}

###############################################################################
# export_data_solexa_sample_info
#
# use the sql statement to dump out all the information for a group of solexa runs
###############################################################################
sub export_data_solexa_sample_info{
	my $method = 'export_data_solexa_sample_info';
	
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

  # Conditional allows sites to use simple perl sort to avoid warnings if
  # filenames don't conform to ISB standard.  No-op if param isn't set in
  # SBEAMS.conf file.
  if( $CONFIG_SETTING{ST_NAIVE_SORT} ) {
    for my $file ( keys( %{$self->{ALL_FILES}} ) ) { 
      return(sort(keys(%{$self->{ALL_FILES}}))) if $file !~ /\d+_\d+_.*$/;
    }
  }
	
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
#Reads the Base directory holding the Solexa files.
###############################################################################
sub read_dirs {
	$self = shift;		#need to set global object since _group_files sub needs to write to the instance to store all the data
				#if multiple objects are made bad things might happen.....  Need to test
	my %args = @_;
	
	###define local variables
	my $base_dir = $self->base_dir();
	
	find(\&_group_files, $base_dir);		#find sub in File::Find
	my $total_file_count = $self->get_total_root_file_name_count();
	print "Total File Count '$total_file_count'\n";
	
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
#sub used by File::Find to populate a hash of hashes, contained within the Solexa_file_groups object
#, if files are found that match one of the file extensions in the @FILE_TYPES array
###############################################################################

sub _group_files {
	#my $self = shift;	#global instance set up read_dirs
	
	foreach my $file_ext ( $self->file_extension_names() ){  	#assuming that all files will end in some extension 

		if ( $_ =~ /(.*)\.$file_ext/){				#check to see if one of the file extensions matches to a file found within the default data dir
			print "FILE $1 EXT $file_ext\n" if $self->verbose() ;
		
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
					$log->debug("CURRENT  DATA FILE '$File::Find::name'\n");
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
		
		return $self->{$args{root_file_name}}{ERROR} .= "\n$args{error}";	#might be more then one error so append on new errors
	
	}elsif (exists $args{root_file_name} ){	
		
		$self->{$args{root_file_name}}{ERROR};
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
	    	
		#print "\nGOOD FILE '$file_name'\n";
		return "YES";
	}else{
		
		$self->group_error(root_file_name => $args{root_file_name},
				   error	  =>	"Cannot not find Minimum Number of files to Upload\n",
				  );
	
		return "NO";
	}
}
###############################################################################
# get_projects_with_runs
# Give Nothing
#Return an array of runs
###############################################################################
sub get_projects_with_runs {
	my $method = 'get_projects_with_runs';
	my $self = shift;
	my %args = @_;

  # Should we limit access to projects that this user has access to?
  # off by default for backwards compatibilty
  $args{limited_access} ||= 0;
  my $limitSQL = '';
  if ( $args{limited_access} && !$sbeams->isAdmin() ) {
    my $contactID = $sbeams->getCurrent_contact_id();
    $limitSQL =<<"    END_SQL";
    AND ( P.pi_contact_id = $contactID OR 
    END_SQL
  }
	
	my $sql = qq~ 
				SELECT DISTINCT P.project_id,UL.username || ' - ' || P.name 
				FROM $TB_PROJECT P 
				INNER JOIN $TBST_SOLEXA_SAMPLE sfs ON ( P.project_id = sfs.project_id )
				INNER JOIN $TBST_SOLEXA_RUN sr ON (sr.solexa_sample_id = sfs.solexa_sample_id)  
				LEFT JOIN $TB_USER_LOGIN UL ON ( P.PI_contact_id=UL.contact_id ) 
				WHERE P.record_status != 'D'
				ORDER BY UL.username || ' - ' || P.name 
			~;
	#$sbeams->display_sql(sql=> $sql);
	my @all_projects_info = $sbeams->selectSeveralColumns($sql);
	return @all_projects_info;
}




}#closing bracket for the package

1;
