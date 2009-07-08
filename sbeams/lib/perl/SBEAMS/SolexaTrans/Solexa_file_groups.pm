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
#sub check_previous_runs {
#	my $method = "check_previous_runs";
#
#	my $self = shift;
#	my %args = @_;
	
#	my $root_name = $args{root_name};
	
#	my $sql = qq~ SELECT solexa_run_id
#			FROM $TBST_SOLEXA_RUN
#			WHERE file_root like '$root_name'
#		   ~;
		 
#	my @rows = $sbeams->selectOneColumn($sql);
	
#	if ($self->verbose() > 0){
#		print "method '$method' SQL '$sql'\n";
#		print "DATA RESULTS '@rows'\n";
#	}
	
#	if (defined $rows[0] && $rows[0] =~ /^\d/){
#		if ($self->verbose() > 0){
#			print "RETURN RUN IN DB PK'$rows[0]'\n";
#		}
#		return $rows[0];		#return the solexa_run_id if the record is in the database
#	}else{
#		if ($self->verbose() > 0){
#			print "RETURN '0' RUN ROOT NOT IN DB\n";
#		}
	#	return "ADD";
#		return 0;
#	}

#}

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
#sub find_solexa_run_id { 
#	my $method = 'find_solexa_run_id';

#	my $self = shift;
#	my %args = @_;
	
#	unless (exists $args{root_file_name} ) {
#		confess(__PACKAGE__ . "::$method need to provide key value pairs 'root_file_name'\n");
#	}
	
#	my $sql = qq~ SELECT solexa_run_id
#			FROM $TBST_SOLEXA_RUN
#			WHERE file_root like '$args{root_file_name}'
#			AND record_status != 'D'
#		  ~;
#print "tbst_solexa_run $TBST_SOLEXA_RUN\n";
#	my ($solexa_run_id) = $sbeams->selectOneColumn($sql);
	
#	if ($solexa_run_id){
#		return $solexa_run_id;
#	}else{
#		return 0;
#	}
#}

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
# Get the server
#
#Provide Key value pairs file_path
#Return server name
###############################################################################
sub get_server {
	my $method = 'get_server';
	
	my $self = shift;
	my %args = @_;
	
	unless (exists $args{file_path}) {
		confess(__PACKAGE__ . "::$method Need to provide key value pairs 'file_path'\n");
	}

        my $sql = qq~ SELECT s.server_name
                      FROM $TBST_SERVER s
                      LEFT JOIN $TBST_FILE_PATH fp ON
                        (fp.server_id = s.server_id)
                      WHERE fp.file_path = '$args{file_path}'
                  ~;

	my ($server_name) = $sbeams->selectOneColumn($sql);
        if ($server_name) {
          return $server_name;
        } else {
          return "ERROR: Could not find an entry for file path ".$args{file_path};
        }

}
###############################################################################
# Get  get_file_path_from_id	
#
#Provide Key value pair 'solexa_sample_id' and 'file_type' 
#Return a file path for a particular file_type or 0 (zero) if it failed
###############################################################################
sub get_file_path_from_id {
	my $method = 'get_file_path_from_id';
	
	my $self = shift;
	
	my %args = @_;
	unless ((exists $args{solexa_sample_id}  && $args{solexa_sample_id} =~ /^\d/) || 
	(exists $args{slimseq_sample_id}  && $args{slimseq_sample_id} =~ /^\d/)) {
		confess(__PACKAGE__ . "::$method Need to provide key value pair for 'solexa_sample_id' or 'slimseq_sample_id'\n");
	}

        my $where;
        if (exists $args{'solexa_sample_id'}) {
           $where = "WHERE SS.SOLEXA_SAMPLE_ID = '".$args{'solexa_sample_id'}."'";
        } elsif (exists $args{'slimseq_sample_id'}) {
           $where = "WHERE SS.SLIMSEQ_SAMPLE_ID = '".$args{'slimseq_sample_id'}."'";
        } else {
           return("Error in get_file_path_from_id - Neither solexa_sample_id nor slimseq_sample_id were supplied.");
        }
	my $sql = qq~   SELECT EOF.file_path as "ELAND_FILE", 
                        SF.file_path as "SUMMARY_FILE",
                        RDP.file_path as "RAW_DATA_PATH"
			FROM $TBST_SOLEXA_PIPELINE_RESULTS SPR
			JOIN $TBST_FILE_PATH EOF ON (SPR.ELAND_OUTPUT_FILE_ID = EOF.FILE_PATH_ID)
                        JOIN $TBST_FILE_PATH RDP ON (SPR.RAW_DATA_PATH_ID = RDP.FILE_PATH_ID)
                        JOIN $TBST_FILE_PATH SF ON (SPR.SUMMARY_FILE_ID = SF.FILE_PATH_ID)
                        JOIN $TBST_SOLEXA_FLOW_CELL_LANE SFCL ON 
                          (SPR.FLOW_CELL_LANE_ID = SFCL.FLOW_CELL_LANE_ID)
                        JOIN $TBST_SOLEXA_FLOW_CELL_LANE_SAMPLES SFCLS ON
                          (SFCL.FLOW_CELL_LANE_ID = SFCLS.FLOW_CELL_LANE_ID)
                        JOIN $TBST_SOLEXA_SAMPLE SS ON (SFCLS.SOLEXA_SAMPLE_ID = SS.SOLEXA_SAMPLE_ID)
                        $where
                        AND EOF.RECORD_STATUS != 'D'
                        AND RDP.RECORD_STATUS != 'D'
                        AND SF.RECORD_STATUS != 'D'
                        AND SFCLS.RECORD_STATUS != 'D'
                        AND SFCL.RECORD_STATUS != 'D'
                        AND SS.RECORD_STATUS != 'D'
                        AND SPR.RECORD_STATUS != 'D'
		  ~;
	my ($results) = $sbeams->selectSeveralColumns($sql);
	
	if ($results) {
          if ($args{file_type}) {
            if ($args{file_type} eq 'ELAND') {
               return($results->[0]);
            } elsif ($args{file_type} eq 'SUMMARY') {
               return($results->[1]);
            } elsif ($args{file_type} eq 'RAW') {
                return($results->[2]);
            } else {
                return 0;
            }
          } else {
	    # return the eland_output_file, summary_file, and the raw_data_path
	    return ($results->[0], $results->[1], $results->[2]);
          }
	} else{
		return 0;
	}
	
}

###############################################################################
# Get  get_file_path_from_jobname	
#
#Provide Key value pair 'solexa_sample_id' and 'file_type' 
#Return a file path for a particular file_type or 0 (zero) if it failed
###############################################################################
sub get_file_path_from_jobname {
	my $method = 'get_file_path_from_jobname';
	
	my $self = shift;
	
	my %args = @_;
	unless ( exists $args{jobname}) {
		confess(__PACKAGE__ . "::$method Need to provide key value pair for 'jobname'\n");
	}

	my $sql = qq~   
                       SELECT OPD.file_path as "Output_Directory"
                       FROM $TBST_SOLEXA_ANALYSIS SA
                       INNER JOIN $TBST_FILE_PATH OPD ON
                         SA.OUTPUT_DIRECTORY_ID = OPD.FILE_PATH_ID
                       WHERE SA.JOBNAME = '$args{jobname}'
                       AND SA.RECORD_STATUS != 'D'
                        AND OPD.RECORD_STATUS != 'D'
		  ~;
	my ($results) = $sbeams->selectSeveralColumns($sql);
	
	if ($results) {
	    return ($results->[0]);
	} else{
		return 0;
	}
	
}


###############################################################################
# check_for_file
#
#Give the solexa_run_id, root_name, file_ext 
#Pull the file base path from the database then do a file exists on the full file path
#Return the 1 if it exists or 0 if it does not
###############################################################################
#sub check_for_file {
#	my $self = shift;
#	my %args = @_;

#	my $solexa_run_id  = $args{pk_id};
#	my $root_name = $args{file_root_name};
#	my $file_ext  = $args{file_extension}; #Fix me same query is ran to many times, store the data localy
	  

#		my $sql = qq~  SELECT fp.file_path 
#		FROM $TBST_SOLEXA_RUN sr, $TBST_FILE_PATH fp 
#		WHERE sr.file_path_id = fp.file_path_id
#		AND sr.solexa_run_id = $solexa_run_id
#	   ~;
#	my ($path) = $sbeams->selectOneColumn($sql);

#		my $file_path = "$path/$root_name.$file_ext";

#	if ( -e $file_path ) {
#		return 1;
#	}else {
#		#print "MISSING FILE '$file_path'<br/>";
#		return 0;
#	}
#}

###############################################################################
# Get number of groups
#
#Return: Number of root_file names seen
###############################################################################
#sub get_total_root_file_name_count {
#	my $self = shift;
#		
#	return scalar (keys %{ $self->{ALL_FILES} } );
#	
#}
###############################################################################
# Get file group
#
#Return: Array of files paths a single root_file_name points to
###############################################################################
#sub get_file_group {
#	my $method  = 'get_file_group';
	
#	my $self = shift;
#	my %args = @_;
	
#	unless (exists $args{'root_file_name'}) {
#		confess(__PACKAGE__. "::$method Need to provide a key value pair for the key 'root_file_name'\n");
#	}
	
	#get the keys for a single root name, pass them into map which will call the get_file_path method
	#return an array of file paths
#	return ( map {$self->get_file_path(	root_file_name  => $args{root_file_name},	
#						file_ext	=> $_,
#					   )} keys %{ $self->{ALL_FILES}{$args{'root_file_name'}} } );
	
#}

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
                                sfcl.flow_cell_id as "Flow_Cell_ID",
                                sfcl.lane_number AS "Lane",
				ss.sample_tag AS "Sample_Tag",
				ss.full_sample_name AS "Full_Sample_Name",
				o.organism_name AS "Organism"
				FROM $TBST_SOLEXA_SAMPLE ss 
				LEFT JOIN $TB_ORGANISM o ON (ss.organism_id = o.organism_id) 
                                LEFT JOIN $TBST_SOLEXA_FLOW_CELL_LANE_SAMPLES sfcls ON
                                  (ss.solexa_sample_id = sfcls.solexa_sample_id)
                                LEFT JOIN $TBST_SOLEXA_FLOW_CELL_LANE sfcl ON
                                  (sfcls.flow_cell_lane_id = sfcl.flow_cell_lane_id)
				WHERE ss.project_id IN ($args{project_id}) 
				AND ss.record_status != 'D'
		    ~;
	
	if ($constraint){
		$sql .= $constraint;
	}
	
	
	return $sql;
}

###############################################################################
# get get_slimseq_sample_sql
#
#get all the slimseq sample ids for a particular project_id from the database
###############################################################################
sub get_slimseq_sample_sql{
	my $method = 'get_slimseq_sample';
	
	my $self = shift;
	my %args = @_;
	
	unless ($args{project_id} ){
		confess(__PACKAGE__ . "::$method Need to provide key value pairs 'project_id'");
	}
	
	my $constraint = $args{constraint};

	my $sql = qq~ SELECT    ss.slimseq_sample_id AS "Sample ID",
                                sfcl.flow_cell_id as "Flow Cell ID",
                                sfcl.lane_number AS "Lane",
				ss.sample_tag AS "Sample Tag",
				ss.full_sample_name AS "Full Sample Name"
				FROM $TBST_SOLEXA_SAMPLE ss 
                                LEFT JOIN $TBST_SOLEXA_FLOW_CELL_LANE_SAMPLES sfcls ON
                                  (ss.solexa_sample_id = sfcls.solexa_sample_id)
                                LEFT JOIN $TBST_SOLEXA_FLOW_CELL_LANE sfcl ON
                                  (sfcls.flow_cell_lane_id = sfcl.flow_cell_lane_id)
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
# get_slimseq_sample_pipeline_sql
#
#get all the samples for a particular project_id from the database
# where those samples can be run by the solexatrans pipeline
###############################################################################
sub get_slimseq_sample_pipeline_sql{
	my $method = 'get_slimseq_sample_pipeline_sql';
	
	my $self = shift;
	my %args = @_;
	
	unless ($args{project_id} ){
		confess(__PACKAGE__ . "::$method Need to provide key value pairs 'project_id'");
	}
	
	my $constraint = $args{constraint};

	my $sql = qq~ SELECT    ss.slimseq_sample_id AS "Sample_ID",
				ss.sample_tag AS "Sample_Tag",
				ss.full_sample_name AS "Full_Sample_Name",
				o.organism_name AS "Organism",
                                count(sa.jobname) as "Num_Jobs"
				FROM $TBST_SOLEXA_SAMPLE ss 
				LEFT JOIN $TB_ORGANISM o ON 
                                  (ss.organism_id = o.organism_id
                                    AND o.record_status != 'D') 
				LEFT JOIN $TBST_SOLEXA_SAMPLE_PREP_KIT sspk ON
				  (ss.solexa_sample_prep_kit_id = sspk.solexa_sample_prep_kit_id
                                    AND sspk.record_status != 'D')
                                LEFT JOIN $TBST_SOLEXA_FLOW_CELL_LANE_SAMPLES sfcls ON
                                  (ss.solexa_sample_id = sfcls.solexa_sample_id
                                    AND sfcls.record_status != 'D')
                                LEFT JOIN $TBST_SOLEXA_FLOW_CELL_LANE sfcl ON
                                  (sfcls.flow_cell_lane_id = sfcl.flow_cell_lane_id
                                    AND sfcl.record_status != 'D')
                                LEFT JOIN $TBST_SOLEXA_PIPELINE_RESULTS spr ON
                                  (sfcl.flow_cell_lane_id = spr.flow_cell_lane_id
                                    AND spr.record_status != 'D')
                                LEFT JOIN $TBST_SOLEXA_ANALYSIS sa ON
                                  (spr.solexa_pipeline_results_id = sa.solexa_pipeline_results_id 
                                    AND sa.record_status != 'D')
				WHERE ss.project_id IN ($args{project_id}) 
				AND sspk.restriction_enzyme is not null
                                AND spr.slimseq_status is not null
				AND ss.record_status != 'D'
                                GROUP BY ss.slimseq_sample_id, ss.sample_tag, ss.full_sample_name, o.organism_name
		    ~;
	
	if ($constraint){
		$sql .= $constraint;
	}
	
	
	return $sql;
}

###############################################################################
# get_slimseq_sample_info_sql
#
#get all the samples for a particular project_id from the database
# where those samples can be run by the solexatrans pipeline
###############################################################################
sub get_slimseq_sample_info_sql{
	my $method = 'get_slimseq_sample_info_sql';
	
	my $self = shift;
	my %args = @_;
	
	unless ($args{project_id} ){
		confess(__PACKAGE__ . "::$method Need to provide key value pairs 'project_id'");
	}
	
	my $constraint = $args{constraint} || '';

	my $sql = qq~ SELECT    ss.slimseq_sample_id AS "Sample_ID",
				ss.sample_tag AS "Sample_Tag",
				ss.full_sample_name AS "Full_Sample_Name",
				o.organism_name AS "Organism",
                                sa.job_tag as "Job_Tag",
                                sa.total_genes as "Total Genes",
                                sa.total_tags as "Total Tags",
                                sa.match_tags as "Total Matched Tags",
                                sa.unkn_tags as "Total Unknown Tags",
                                sa.ambg_tags as "Total Ambiguous Tags",
                                sa.jobname as "Job_Name"
				FROM $TBST_SOLEXA_SAMPLE ss 
				LEFT JOIN $TB_ORGANISM o ON (ss.organism_id = o.organism_id) 
				LEFT JOIN $TBST_SOLEXA_SAMPLE_PREP_KIT sspk
				  ON (ss.solexa_sample_prep_kit_id = sspk.solexa_sample_prep_kit_id)
                                LEFT JOIN $TBST_SOLEXA_FLOW_CELL_LANE_SAMPLES sfcls 
                                  ON (ss.solexa_sample_id = sfcls.solexa_sample_id)
                                LEFT JOIN $TBST_SOLEXA_FLOW_CELL_LANE sfcl
                                  ON (sfcls.flow_cell_lane_id = sfcl.flow_cell_lane_id)
                                LEFT JOIN $TBST_SOLEXA_PIPELINE_RESULTS spr 
                                  ON (sfcl.flow_cell_lane_id = spr.flow_cell_lane_id)
                                LEFT JOIN $TBST_SOLEXA_ANALYSIS sa 
                                  ON (spr.solexa_pipeline_results_id = sa.solexa_pipeline_results_id)
				WHERE ss.project_id IN ($args{project_id}) 
				AND sspk.restriction_enzyme is not null
				AND ss.record_status != 'D'
				AND sspk.record_status != 'D'
				AND sfcls.record_status != 'D'
				AND sfcl.record_status != 'D'
				AND spr.record_status != 'D'
				AND sa.record_status != 'D'
                                $constraint
                                ORDER BY ss.slimseq_sample_id
		    ~;
	
	
	
	return $sql;
}

###############################################################################
# get_slimseq_sample_qc_sql
#
#get all the samples for a particular project_id from the database
# where those samples can be run by the solexatrans pipeline
###############################################################################
sub get_slimseq_sample_qc_sql{
	my $method = 'get_slimseq_sample_qc_sql';
	
	my $self = shift;
	my %args = @_;
	
	unless ($args{project_id} ){
		confess(__PACKAGE__ . "::$method Need to provide key value pairs 'project_id'");
	}
	
	my $constraint = $args{constraint} || '';

	my $sql = qq~ SELECT    
                                CONVERT(varchar(8),sfc.date_generated,112) AS "Run Date",
                                ss.slimseq_sample_id AS "Sample ID",
				ss.sample_tag AS "Sample Tag",
				ss.full_sample_name AS "Full Sample Name",
				o.organism_name AS "Organism",
                                sfcl.lane_yield_kb as "Lane Yield (KB)",
                                sfcl.average_clusters as "Average Clusters",
                                sfcl.percent_pass_filter_clusters AS "\% Clusters Pass Filter",
                                sfcl.percent_align as "Percent Align",
                                sfcl.percent_error AS "Percent Error"
				FROM $TBST_SOLEXA_SAMPLE ss 
				LEFT JOIN $TB_ORGANISM o ON (ss.organism_id = o.organism_id) 
				LEFT JOIN $TBST_SOLEXA_SAMPLE_PREP_KIT sspk
				  ON (ss.solexa_sample_prep_kit_id = sspk.solexa_sample_prep_kit_id)
                                LEFT JOIN $TBST_SOLEXA_FLOW_CELL_LANE_SAMPLES sfcls 
                                  ON (ss.solexa_sample_id = sfcls.solexa_sample_id)
                                LEFT JOIN $TBST_SOLEXA_FLOW_CELL_LANE sfcl
                                  ON (sfcls.flow_cell_lane_id = sfcl.flow_cell_lane_id)
                                LEFT JOIN $TBST_SOLEXA_FLOW_CELL sfc
                                  ON (sfcl.flow_cell_id = sfc.flow_cell_id AND sfc.record_status != 'D')
				WHERE ss.project_id IN ($args{project_id}) 
				AND sspk.restriction_enzyme is not null
				AND ss.record_status != 'D'
				AND sspk.record_status != 'D'
				AND sfcls.record_status != 'D'
				AND sfcl.record_status != 'D'
                                $constraint
                                ORDER BY ss.slimseq_sample_id
		    ~;
	
	
	
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
# get get_solexa_pipeline_form_sql
#
#get information for pipeline form
###############################################################################
sub get_solexa_pipeline_form_sql{
	my $method = 'get_solexa_pipeline_form';
	
	my $self = shift;
	my %args = @_;
	
	unless ($args{slimseq_sample_id} ){
		confess(__PACKAGE__ . "::$method Need to provide key value pairs 'slimseq_sample_id'");
	}
	
	my $constraint = $args{constraint};

	my $sql = qq~ 
                            SELECT O.organism_name,
                            SS.alignment_end_position - SS.alignment_start_position+1 as "Tag_Length",
                            SSPK.restriction_enzyme_id,
                            SS.full_sample_name as 'Full_Sample_Name'
                            FROM $TBST_SOLEXA_SAMPLE SS
                            LEFT JOIN $TBST_SOLEXA_SAMPLE_PREP_KIT SSPK ON
                              (SS.solexa_sample_prep_kit_id = SSPK.solexa_sample_prep_kit_id)
                            LEFT JOIN $TB_ORGANISM O ON (SS.organism_id = O.organism_id)
                            WHERE SS.slimseq_sample_id = $args{'slimseq_sample_id'}
			    AND SS.record_status != 'D'
			    AND SSPK.record_status != 'D'
			    AND O.record_status != 'D'
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
	
	unless ($args{project_id} &&( $args{solexa_sample_ids} || $args{slimseq_sample_ids} )){
		confess(__PACKAGE__ . "::$method Need to provide key value pairs 'project_id' and 'solexa_sample_ids' or 'slimseq_sample_ids'");
	}
	
	my $constraint = $args{constraint};

        my ($id) = '';
        if ($args{slimseq_sample_ids}) {
           $id = 'ss.slimseq_sample_id as "Sample_ID"';
           $constraint = "AND ss.slimseq_sample_id in (".$args{"slimseq_sample_ids"}.")";
        } elsif ($args{solexa_sample_ids}) {
           $id = 'ss.solexa_sample_id as "Sample_ID"';
           $constraint = "AND ss.solexa_sample_id in (".$args{"solexa_sample_ids"}.")";
        }

	my $sql = qq~ SELECT    
                                $id,
                                spr.solexa_pipeline_results_id as "SPR_ID",
                                efi.file_path as "ELAND_Output_File",
                                rdp.file_path as "Raw_Data_Path",
                                o.organism_name as "Organism",
                                sfcl.lane_number as "Lane"
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
                                LEFT JOIN $TB_ORGANISM o on
                                    (ss.organism_id = o.organism_id)
                                WHERE ss.project_id IN ($args{project_id})
                                $constraint
				AND ss.record_status != 'D'
				AND sfcls.record_status != 'D'
				AND sfcl.record_status != 'D'
                                AND spr.record_status != 'D'
                                AND efi.record_status != 'D'
                                AND rdp.record_status != 'D'
                                AND o.record_status != 'D'
		    ~;
	
	if ($constraint){
		$sql .= $constraint;
	}
	
	
	return $sql;
}



###############################################################################
# get get_solexa_run_sql
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
# get get_spr_ids_by_sample_id_sql
#
#get all the solexa_pipeline_results_ids for a sample
###############################################################################
sub get_spr_ids_by_sample_id_sql {
  my $method = 'get_spr_ids_by_sample_id';
  my $self = shift;
  my %args = @_;

  unless ($args{'solexa_sample_id'} || $args{'slimseq_sample_id'}) {
    confess(__PACKAGE__ . "::$method Need to provide key value pair for 'solexa_sample_id' or 'slimseq_sample_id'");
  }

  my $constraint = $args{constraint} if $args{constraint};

  my $where;
  if ($args{'solexa_sample_id'}) {
    $where = 'WHERE ss.solexa_sample_id = '.$args{'solexa_sample_id'};
  } elsif ($args{'slimseq_sample_id'}) {
    $where = 'WHERE ss.slimseq_sample_id = '.$args{'slimseq_sample_id'};
  } else {
    confess(__PACKAGE__."::$method error with arguments provided - could not find slimseq_sample_id or solexa_sample_id");
  }

  my $sql = qq~
                                SELECT
                                spr.solexa_pipeline_results_id as "SPR_ID",
                                spr.date_modified as "Last_Modified"
                                FROM $TBST_SOLEXA_SAMPLE ss
                                LEFT JOIN $TBST_SOLEXA_FLOW_CELL_LANE_SAMPLES sfcls on
                                   (ss.solexa_sample_id = sfcls.solexa_sample_id)
                                LEFT JOIN $TBST_SOLEXA_FLOW_CELL_LANE sfcl on
                                   (sfcls.flow_cell_lane_id = sfcl.flow_cell_lane_id)
                                LEFT JOIN $TBST_SOLEXA_PIPELINE_RESULTS spr on
                                   (sfcl.flow_cell_lane_id = spr.flow_cell_lane_id)
                                $where
                                AND ss.record_status != 'D'
                                AND sfcls.record_status != 'D'
                                AND sfcl.record_status != 'D'
                                AND spr.record_status != 'D'
                                order by ss.slimseq_sample_id
  ~;

  if ($constraint) {
    $sql .= $constraint;
  }

  return $sql;
}


###############################################################################
# get_jobs_by_sample_id_sql
#
#
###############################################################################
sub get_jobs_by_sample_id_sql {
  my $method = 'get_jobs_by_sample_id_sql';
  my $self = shift;
  my %args = @_;

  unless ($args{slimseq_sample_id}) {
    confess(__PACKAGE__."::$method Need to provide key value pairs 'slimseq_sample_id'");
  }

  my $constraint = $args{constraint};
  my $sql = qq~
                  SELECT
                  sa.solexa_analysis_id as "Job_ID",
                  sa.jobname as "Job_Name",
                  sa.status as "Job_Status",
                  sa.job_tag as "Job_Tag",
                  sa.date_created as "Job_Created"
                  FROM $TBST_SOLEXA_ANALYSIS sa
                  WHERE sa.slimseq_sample_id = $args{slimseq_sample_id}
                  AND sa.record_status != 'D'
                  ORDER BY sa.status_time DESC
            ~;

  if ($constraint) {
    $sql .= $constraint;
  }

  return $sql;
}

###############################################################################
# get_sample_job_status_sql
#
#get all the runs for a particular project_id from the database
###############################################################################
sub get_sample_job_status_sql{
	my $method = 'get_sample_job_status';
	
	my $self = shift;
	my %args = @_;
	
	unless ($args{project_id} ){
		confess(__PACKAGE__ . "::$method Need to provide key value pairs 'project_id'");
	}
	
	my $constraint = $args{constraint};

	my $sql = qq~ 
                                SELECT 
                                sa.solexa_analysis_id as "Job_ID",
                                sa.jobname as "Job_Name",
                                sa.status as "Job_Status",
                                sa.status_time as "Job_Status_Updated",
                                ss.slimseq_sample_id as "Sample_ID",
                                ss.sample_tag as "Sample_Tag",
                                ss.full_sample_name as "Full_Sample_Name"
				FROM $TBST_SOLEXA_ANALYSIS sa
                                LEFT JOIN $TBST_SOLEXA_PIPELINE_RESULTS spr on
                                  (sa.solexa_pipeline_results_id = spr.solexa_pipeline_results_id)
                                LEFT JOIN $TBST_SOLEXA_FLOW_CELL_LANE sfcl on
                                  (spr.flow_cell_lane_id = sfcl.flow_cell_lane_id)
                                LEFT JOIN $TBST_SOLEXA_FLOW_CELL_LANE_SAMPLES sfcls on
                                  (sfcl.flow_cell_lane_id = sfcls.flow_cell_lane_id)
				LEFT JOIN $TBST_SOLEXA_SAMPLE ss ON 
                                  (sfcls.solexa_sample_id = ss.solexa_sample_id)
				WHERE ss.project_id IN ($args{project_id}) 
                                AND spr.record_status != 'D'
                                AND sfcl.record_status != 'D'
                                AND sfcls.record_status != 'D'
                                AND ss.record_status != 'D'
		    ~;
	
	if ($constraint){
		$sql .= $constraint;
	}
	
	
	return $sql;
}

###############################################################################
# get get_detailed_job_status_sql
#
#get all the information for a particular jobname from the database
###############################################################################
sub get_detailed_job_status_sql{
	my $method = 'get_detailed_job_status';
	
	my $self = shift;
	my %args = @_;
	
	unless ($args{jobname} || $args{solexa_analysis_id}){
		confess(__PACKAGE__ . "::$method Need to provide key value pairs 'jobname' or 'solexa_analysis_id'");
	}
	
        my $where;
        if ($args{jobname}) {
          $where = "WHERE sa.jobname IN ('$args{jobname}')";
        } elsif ($args{solexa_analysis_id}) {
          $where = "WHERE sa.solexa_analysis_id = '$args{solexa_analysis_id}'";
        } else {
          return "ERROR: Incorrect parameters for $method";
        }

	my $constraint = $args{constraint};

	my $sql = qq~ 
                                SELECT 
                                sa.solexa_analysis_id,
                                spr.record_status as "Record_Status",
                                sa.jobname as "Job_Name",
                                sa.analysis_description as "Job_Description",
                                sa.status as "Job_Status",
                                sa.status_time as "Job_Status_Updated",
                                opd.file_path as "Output_Directory",
                                sa.total_tags as "Total_Tags",
                                sa.total_unique_tags as "Total_Unique_Tags",
                                sa.match_tags as "Match_Tags",
                                sa.match_unique_tags as "Match_Unique_Tags",
                                sa.ambg_tags as "Ambiguous_Tags",
                                sa.ambg_unique_tags as "Ambiguous_Unique_Tags",
                                sa.unkn_tags as "Unknown_Tags",
                                sa.unkn_unique_tags as "Unknown_Unique_Tags",
                                ss.slimseq_sample_id as "Sample_ID",
                                ss.sample_tag as "Sample_Tag",
                                ss.full_sample_name as "Full_Sample_Name"
				FROM $TBST_SOLEXA_ANALYSIS sa
                                LEFT JOIN $TBST_SOLEXA_PIPELINE_RESULTS spr on
                                  ( 
                                    sa.solexa_pipeline_results_id = spr.solexa_pipeline_results_id
                                  )
                                LEFT JOIN $TBST_SOLEXA_FLOW_CELL_LANE sfcl on
                                  ( 
                                    spr.flow_cell_lane_id = sfcl.flow_cell_lane_id
                                    AND sfcl.record_status != 'D'
                                  )
                                LEFT JOIN $TBST_SOLEXA_FLOW_CELL_LANE_SAMPLES sfcls on
                                  (
                                    sfcl.flow_cell_lane_id = sfcls.flow_cell_lane_id
                                    AND sfcls.record_status != 'D'
                                  )
				LEFT JOIN $TBST_SOLEXA_SAMPLE ss ON 
                                  (
                                    sfcls.solexa_sample_id = ss.solexa_sample_id
                                    AND ss.record_status != 'D'
                                  )
                                LEFT JOIN $TBST_FILE_PATH opd ON
                                  (
                                    sa.output_directory_id = opd.file_path_id
                                    AND opd.record_status != 'D'
                                  )
                                $where
		    ~;
	
	if ($constraint){
		$sql .= $constraint;
	}
	
	
	return $sql;
}

###############################################################################
# get_job_parameters_sql
#
# get all the entries in analysis_parameters for a solexa_analysis_id
###############################################################################
sub get_job_parameters_sql{
	my $method = 'get_job_parameters';
	
	my $self = shift;
	my %args = @_;
	
	unless ($args{solexa_analysis_id} ){
		confess(__PACKAGE__ . "::$method Need to provide key value pairs 'solexa_analysis_id'");
	}
	
	my $constraint = $args{constraint};

	my $sql = qq~ 
                                SELECT 
                                param_display,
                                param_value,
                                param_key
                                FROM $TBST_ANALYSIS_PARAMETERS
				WHERE solexa_analysis_id IN ($args{solexa_analysis_id}) 
                                AND record_status != 'D'
		    ~;
	
	if ($args{constraint}){
		$sql .= $args{constraint};
	}
	
	return $sql;
}


###############################################################################
# get get_sample_results_sql
#
#get all the runs for a particular project_id from the database
###############################################################################
sub get_sample_results_sql{
	my $method = 'get_sample_results';
	
	my $self = shift;
	my %args = @_;
	
	unless ($args{project_id} ){
		confess(__PACKAGE__ . "::$method Need to provide key value pairs 'project_id'");
	}
	
	my $constraint = $args{constraint};

	my $sql = qq~ 
                                SELECT 
                                ss.slimseq_sample_id as "Sample ID",
                                ss.sample_tag as "Sample Tag",
                                ss.full_sample_name as "Full Sample Name",
                                spr.slimseq_status as "Solexa Status",
                                count(spr.solexa_pipeline_results_id) as "Num Runs"
                                FROM $TBST_SOLEXA_SAMPLE ss 
                                LEFT JOIN $TBST_SOLEXA_FLOW_CELL_LANE_SAMPLES sfcls on
                                  (sfcls.solexa_sample_id = ss.solexa_sample_id
                                    AND sfcls.record_status != 'D')
                                LEFT JOIN $TBST_SOLEXA_FLOW_CELL_LANE sfcl on
                                  (sfcl.flow_cell_lane_id = sfcls.flow_cell_lane_id
                                    AND sfcl.record_status != 'D')
                                LEFT JOIN $TBST_SOLEXA_PIPELINE_RESULTS spr on
                                  (spr.flow_cell_lane_id = sfcl.flow_cell_lane_id 
                                    AND spr.record_status != 'D')
                                LEFT OUTER JOIN $TBST_SOLEXA_ANALYSIS sa on
                                  (sa.solexa_pipeline_results_id = spr.solexa_pipeline_results_id
                                    AND sa.record_status != 'D')
                                LEFT JOIN $TBST_SOLEXA_SAMPLE_PREP_KIT sspk ON
                                  (ss.solexa_sample_prep_kit_id = sspk.solexa_sample_prep_kit_id
                                    AND sspk.record_status != 'D')
				WHERE ss.project_id IN ($args{project_id}) 
                                AND sspk.restriction_enzyme is not null
                                AND ss.record_status != 'D'
                                GROUP BY ss.slimseq_sample_id, ss.sample_tag, ss.full_sample_name, spr.slimseq_status
                                ORDER BY ss.slimseq_sample_id

		    ~;

	if ($constraint){
		$sql .= $constraint;
	}
	
	
	return $sql;
}


###############################################################################
# get get_detailed_sample_results_sql
#
#get all the information for a particular sample from the database
###############################################################################
sub get_detailed_sample_results_sql{
	my $method = 'get_detailed_sample_results';
	
	my $self = shift;
	my %args = @_;
	
	unless (($args{slimseq_sample_id} || $args{solexa_sample_id}) && $args{solexa_analysis_id}){
		confess(__PACKAGE__ . "::$method Need to provide key value pairs 'slimseq_sample_id' OR 'solexa_sample_id'");
	}
	
        my $id;
        my $where;
        if ($args{slimseq_sample_id}) {
           $id = 'ss.slimseq_sample_id as "Sample_ID",';
           $where = " ss.slimseq_sample_id IN (".$args{slimseq_sample_id}.")";
        } elsif ($args{solexa_sample_id}) {
           $id = 'ss.solexa_sample_id as "Solexa_Sample_ID",';
           $where = " ss.solexa_sample_id IN (".$args{solexa_sample_id}.")";
        }


	my $constraint = $args{constraint};

                                #convert(varchar,sa.date_created,112) +
                                #  replace(convert(varchar,sa.date_created,108),':','')
                                #  as "Job_Timestamp",
	my $sql = qq~ 
                                SELECT $id
                                ss.sample_tag as "Sample_Tag",
                                ss.full_sample_name as "Full_Sample_Name",
                                sa.jobname as "Job_Name",
                                sa.date_created as "Job_Created",
                                sa.total_tags as "Total_Tags",
                                sa.total_unique_tags as "Total_Unique_Tags",
                                sa.match_tags as "Match_Tags",
                                sa.match_unique_tags as "Match_Unique_Tags",
                                sa.ambg_tags as "Ambiguous_Tags",
                                sa.ambg_unique_tags as "Ambiguous_Unique_Tags",
                                sa.unkn_tags as "Unknown_Tags",
                                sa.unkn_unique_tags as "Unknown_Unique_Tags"
				FROM $TBST_SOLEXA_ANALYSIS sa
                                LEFT JOIN $TBST_SOLEXA_PIPELINE_RESULTS spr on
                                  (sa.solexa_pipeline_results_id = spr.solexa_pipeline_results_id)
                                LEFT JOIN $TBST_SOLEXA_FLOW_CELL_LANE sfcl on
                                  (spr.flow_cell_lane_id = sfcl.flow_cell_lane_id)
                                LEFT JOIN $TBST_SOLEXA_FLOW_CELL_LANE_SAMPLES sfcls on
                                  (sfcl.flow_cell_lane_id = sfcls.flow_cell_lane_id)
				LEFT JOIN $TBST_SOLEXA_SAMPLE ss ON 
                                  (sfcls.solexa_sample_id = ss.solexa_sample_id)
                                LEFT JOIN $TBST_FILE_PATH opd ON
                                  (sa.output_directory_id = opd.file_path_id)
                                WHERE $where
                                AND sa.status = 'COMPLETED'
                                AND sa.solexa_analysis_id = $args{solexa_analysis_id}
                                AND spr.record_status != 'D'
                                AND sfcl.record_status != 'D'
                                AND sfcls.record_status != 'D'
                                AND ss.record_status != 'D'
                                AND opd.record_status != 'D'
                                OR $where
                                AND sa.status = 'UPLOADING'
                                AND sa.solexa_analysis_id = $args{solexa_analysis_id}
                                AND spr.record_status != 'D'
                                AND sfcl.record_status != 'D'
                                AND sfcls.record_status != 'D'
                                AND ss.record_status != 'D'
                                AND opd.record_status != 'D'
                                OR $where
                                AND sa.status = 'PROCESSED'
                                AND sa.solexa_analysis_id = $args{solexa_analysis_id}
                                AND spr.record_status != 'D'
                                AND sfcl.record_status != 'D'
                                AND sfcls.record_status != 'D'
                                AND ss.record_status != 'D'
                                AND opd.record_status != 'D'

		    ~;
	
	if ($constraint){
		$sql .= $constraint;
	}
	
	
	return $sql;
}

###############################################################################
# get get_sample_job_output_directory_sql
#
# return the file path to the tag file
###############################################################################
sub get_sample_job_output_directory_sql{
	my $method = 'get_sample_job_output_directory';
	
	my $self = shift;
	my %args = @_;
	
	unless ($args{solexa_analysis_id} && $args{slimseq_sample_id} ){
		confess(__PACKAGE__ . "::$method Need to provide key value pairs 'solexa_analysis_id', 'slimseq_sample_id'");
	}
	
	my $constraint = $args{constraint};

	my $sql = qq~ 
                                SELECT opd.file_path as "Output_Directory"
                                FROM $TBST_FILE_PATH opd
                                LEFT JOIN $TBST_SOLEXA_ANALYSIS sa on
                                  (opd.file_path_id = sa.output_directory_id)
                                WHERE sa.solexa_analysis_id = $args{solexa_analysis_id}
                                AND sa.slimseq_sample_id = $args{slimseq_sample_id}
                                AND opd.record_status != 'D'
                                AND sa.record_status != 'D'
		    ~;

	if ($constraint){
		$sql .= $constraint;
	}
	
	return $sql;
}

###############################################################################
# get_uploadable_samples_sql 
#
# get the samples that haven't been uploaded - PROCESSED or UPLOADING samples
###############################################################################
sub get_uploadable_samples_sql {
  my $method = 'get_uploadable_samples';
  my $self = shift;
  my %args = @_;

  unless ($args{project_id}) {
    confess(__PACKAGE__."::$method Need to provide key value pairs 'project_id'");
  }

  my $constraint = $args{constraint};

  my $sql = qq~
                  SELECT 
                  sa.slimseq_sample_id as 'Sample_ID',
                  ss.sample_tag as 'Sample_Tag',
                  ss.full_sample_name as 'Full_Sample_Name',
                  sa.solexa_analysis_id as 'Job_ID',
                  sa.jobname as 'Job_Name',
                  sa.status as 'Job_Status',
                  sa.status_time as 'Job_Updated'
                  FROM $TBST_SOLEXA_ANALYSIS sa
                  LEFT JOIN $TBST_SOLEXA_SAMPLE ss on
                    (sa.slimseq_sample_id = ss.slimseq_sample_id)
                  WHERE sa.project_id = $args{project_id}
                  AND (status = 'UPLOADING' OR status = 'PROCESSED')
                  AND sa.record_status != 'D'
                  AND ss.record_status != 'D'
  ~;

  if ($constraint) {
    $sql .= $constraint;
  }

  return $sql;

}

###############################################################################
# get_start_upload_sample_info_sql
#
# get sample information for samples to start uploading
###############################################################################
sub get_start_upload_info_sql {
  my $method = 'get_start_upload_sample_info';
  my $self = shift;
  my %args = @_;

  unless ($args{solexa_analysis_id}) {
    confess(__PACKAGE__."::$method Need to provide key value pairs 'solexa_analysis_id'");
  }

  my $constraint = $args{constraint};

  my $sql = qq~
                  SELECT 
                  sa.slimseq_sample_id as 'Sample_ID',
                  sa.jobname as 'Job_Name',
                  opd.file_path as 'Output_Directory'
                  FROM $TBST_SOLEXA_ANALYSIS sa
                  LEFT JOIN $TBST_FILE_PATH opd
                    ON (sa.output_directory_id = opd.file_path_id)
                  WHERE sa.solexa_analysis_id = $args{solexa_analysis_id}
                  AND sa.record_status != 'D'
                  AND opd.record_status != 'D'
  ~;

  if ($constraint) {
    $sql .= $constraint;
  }

  return $sql;

}




###############################################################################
# get get_all_sample_info_sql
#
# takes a slimseq_sample_id or a solexa_sample_id and returns info about that sample
# 
# return all info if no solexa ids passed
###############################################################################
sub get_all_sample_info_sql{
	my $method = 'get_all_sample_info';
	
	my $self = shift;
	my %args = @_;
	
  # Modified to allow bulk lookup
  my $where = '';
  if ( $args{solexa_sample_ids} ) {  # optional csv solexa ids
    $where = "WHERE ss.solexa_sample_id IN ( $args{solexa_sample_ids} )";
  } elsif ($args{slimseq_sample_ids}) {
    $where = "WHERE ss.slimseq_sample_id IN ( $args{slimseq_sample_ids} )";
  }
	
	
	my $sql = qq~
                SELECT
		ss.sample_tag                 AS "Sample Tag",
		ss.full_sample_name           AS "Full Name", 
		ss.sample_description         AS "Sample Description",
		proj.name                     AS "Project Name",
		o.organism_name               AS "Organism",
		ss.strain_or_line             AS "Strain or Line", 
		ss.individual                 AS "Individual", 
		ss.age                        AS "Age", 
		ss.organism_part              AS "Organism Part", 
		ss.cell_line                  AS "Cell Line", 
		ss.cell_type                  AS "Cell Type", 
		ss.disease_state              AS "Disease_state", 
		ss.sample_preparation_date    AS "Sample Prep Date", 
		ss.treatment_description      AS "Treatment Description",
		ss.comment                    AS "Comment"
		FROM $TBST_SOLEXA_SAMPLE ss 
		JOIN $TB_ORGANISM o ON (ss.organism_id = o.organism_id)
		LEFT JOIN $TB_PROJECT proj ON ( ss.project_id = proj.project_id)
    		$where
	 	ORDER BY ss.solexa_sample_id
	 ~;
	 
	return $sql;
}

###############################################################################
# get get_download_info_sql
#
# takes a slimseq_sample_id or a solexa_sample_id and returns info about that sample
# 
# return all info if no solexa ids passed
###############################################################################
sub get_download_info_sql{
	my $method = 'get_download_info';
	
	my $self = shift;
	my %args = @_;
	
  # Modified to allow bulk lookup
  my $where = '';
  if ( $args{solexa_sample_ids} ) {  # optional csv solexa ids
    $where = "WHERE ss.solexa_sample_id IN ( $args{solexa_sample_ids} )";
  } elsif ($args{slimseq_sample_ids}) {
    $where = "WHERE ss.slimseq_sample_id IN ( $args{slimseq_sample_ids} )";
  }
	
	
	my $sql = qq~
                SELECT
		ss.sample_tag                 AS "Sample Tag",
		ss.full_sample_name           AS "Full Name", 
		o.organism_name               AS "Organism"
		FROM $TBST_SOLEXA_SAMPLE ss 
		JOIN $TB_ORGANISM o ON (ss.organism_id = o.organism_id)
		LEFT JOIN $TB_PROJECT proj ON ( ss.project_id = proj.project_id)
    		$where
	 	ORDER BY ss.solexa_sample_id
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
# get_form_defaults_sql
###############################################################################
sub get_form_defaults_sql {
        my $method = 'get_form_defaults_sql';
        my $self = shift;

        my $sql = qq~
                SELECT option_key, option_value
                FROM $TBST_QUERY_OPTION
                WHERE option_type = 'JP_form_defaults'
                  AND RECORD_STATUS != 'D'
        ~;


       return $sql;
}

###############################################################################
# get_form_job_data_sql
###############################################################################
sub get_form_job_data_sql {
        my $method = 'get_form_job_data_sql';
        my $self = shift;
	my %args = @_;
	
	unless ($args{jobname} ){
		confess(__PACKAGE__ . "::$method Need to provide key value pairs 'jobname' ");
	}

        my $sql = qq~
                SELECT AP.param_key, AP.param_value
                FROM $TBST_ANALYSIS_PARAMETERS AP
                LEFT JOIN $TBST_SOLEXA_ANALYSIS SA ON
                  (SA.solexa_analysis_id = AP.solexa_analysis_id)
                WHERE SA.jobname  = '$args{jobname}'
                  AND AP.param_key is not null
                  AND SA.RECORD_STATUS != 'D'
                  AND AP.RECORD_STATUS != 'D'
        ~;

       return $sql;
}



###############################################################################
# export_data_sample_info
#
# use the sql statement to dump out all the information for a group of solexa samples
###############################################################################
sub export_data_sample_info{
	my $method = 'export_data_sample_info';
	
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
	my $self = shift;		#need to set global object since _group_files sub needs to write to the instance to store all the data
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
	my $self = shift;	#global instance set up read_dirs
	
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
