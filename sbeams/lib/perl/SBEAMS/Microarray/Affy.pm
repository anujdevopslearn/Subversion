###############################################################################
# Program     : SBEAMS::Microarray::Affy_Analysis
# Author      : Pat Moss <pmoss@systemsbiology.org>
# $Id$
#
# Description : Object representation of single Affy Array.
# 
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
#
###############################################################################


{package SBEAMS::Microarray::Affy;

our $VERSION = '1.00';

=head1 NAME

SBEAMS::Microarray::Affy- Class to contain information about Affy Arrays and samples



=head1 SYNOPSIS

  $sbeams_affy = new SBEAMS::Microarray::Affy;		#make an instance of a Affy obj to use for finding all the objects to be made
  
 #make more $affy_o to hold  data describing a single array/sample pair
 
 foreach my $affy_o ($sbeams_affy->registered) {
 	#read data from the affy_o and use the information some how
}
 	

=head1 DESCRIPTION

Instances of this class are used to hold information about a single array and sample pair.  As the script load_affy_array_files.pl is finding groups of affy
files that belong together it will create new Affy objects to hold the data needed to upload into the SBEAMS database.  For example the objects will 
store the project_id, user_id, root_file names, sample_name and so on.
.
The class contains a plethora of simple getter and setters for entering and reading data.  Most method names are created by having the prefix
<set or get><database table_name symbol><table column name>.  Therefore most of the data these objects hold are database id's ie PK and FK.


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



use strict;
use vars qw(%REGISTRY $sbeams);

use SBEAMS::Connection::Tables;
use SBEAMS::Microarray::Tables;
use SBEAMS::BioLink::Tables;

use base qw(SBEAMS::Microarray);		#declare superclass
use Carp;

#@ISA = qw(SBEAMS::Microarray::Affy_Analysis);     



#######################################################
# Constructor
#######################################################
sub new {
	my $class = shift;
	
	my $self = {};
	
	bless $self, $class;
	
	$REGISTRY{$self} = $self;	#also returns $self
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
#######################################################
# registered
# Make a list of all the instances made and return a sorted list by the root_name
#######################################################
sub registered{
	my $either = shift;


	
	my @all_affy_objects = grep {ref()} values %REGISTRY;		#not interested in collecting the keys since they are just stringifed object refs.  Values returns a list (key, value) but grep is only 
									#accepting one value which should be the last value in the list
	
	return _sorted_affy_objects(@all_affy_objects);;

}

#######################################################
# _sorted_affy_objects
# private method to sort the instances by their root_name
#######################################################
sub _sorted_affy_objects{
  no warnings; # Turn off warnings for this block...
	my @objects = @_;
	 

	my @sorted_objects =  map { $_->[0]}
									#element [0] should be the object
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
				 
				map { [$_, (split /_/, $_->get_afa_file_root) ]} @objects;	# example root file name '20040609_03_LPS1-60'
		
	return @sorted_objects;

}


###################################################################################################
#Here comes the getter and setters    

##################################################################################################
#set get pair:afa_user_id
#######################################################
# set_afa_user_id
# user id associated with a group of affy files usually taken from the MAGE XML 
#######################################################
sub set_afa_user_id { 
	my $method = 'set_user_name';
	
	my $self = shift;
	my $name = shift;
	confess(__PACKAGE__ . "::$method No user id provided '$name'\n") unless ($name =~ /^\d/);
	
	return $self->{USER_ID} = $name;
}

#######################################################
# get_afa_user_id
# user name associated with a group of affy files usually taken from the MAGE XML 
#######################################################
	
sub get_afa_user_id {
	my $self = shift;
	return $self->{USER_ID};
}	

#######################################################
# set_afa_array_id
# affy_array_id 
#######################################################
sub set_affy_array_id { 
	my $method = 'set_affy_array_id';
	
	my $self = shift;
	my $name = shift;
	confess(__PACKAGE__ . "::$method No affy_array_id provided '$name'\n") unless ($name =~ /^\d/);
	
	return $self->{ARRAY_ID} = $name;
}

#######################################################
# get_affy_array_id
# affy_array_id
#######################################################
	
sub get_affy_array_id {
	my $self = shift;
	return $self->{ARRAY_ID};
}



##################################################################################################
#set get pair:afs_sample_group_name
#######################################################
# set_afa_sample_group_name
# Sample Group Name taken from the MAGE XML file 
#######################################################
sub set_afs_sample_group_name {
	my $method = 'set_afa_sample_group_name';
	
	my $self = shift;
	my $name = shift;
	confess(__PACKAGE__ . "::$method No sample name provided '$name'\n") unless ($name =~ /^[\w+-]/);
	
	return $self->{SAMPLE_GROUP_NAME} = $name;
}

#######################################################
# get_afs_sample_group_name
# Sample Group Name taken from the MAGE XML file 
#######################################################
	
sub get_afs_sample_group_name {
	my $self = shift;
	return $self->{SAMPLE_GROUP_NAME};
}	

##################################################################################################
#set get pair:afs_sample_tag
#######################################################
# set_afs_sample_tag
# Sample Tag taken from the root file name
#######################################################
sub set_afs_sample_tag {
	my $method = 'set_afs_sample_tag';
	
	my $self = shift;
	my $name = shift;
	confess(__PACKAGE__ . "::$method No sample name provided '$name'\n") unless ($name =~ /^[\w+-]/);
	
	return $self->{SAMPLE_TAG} = $name;
}

#######################################################
# get_afs_sample_tag
# Sample Tag taken from the root file name
#######################################################
	
sub get_afs_sample_tag {
	my $self = shift;
	return $self->{SAMPLE_TAG};
}

##################################################################################################
#set get pair:afs_affy_array_sample_id
#######################################################
# set_afs_affy_array_sample_id
# Affy array sample id
#######################################################
sub set_afs_affy_array_sample_id {
	my $method = 'set_afs_sample_tag';
	
	my $self = shift;
	my $name = shift;
	confess(__PACKAGE__ . "::$method No affy sample id provided '$name'\n") unless ($name =~ /^\d/);
	
	return $self->{SAMPLE_ID} = $name;
}

#######################################################
# get_afs_affy_array_sample_id
# Affy array sample id
#######################################################
	
sub get_afs_affy_array_sample_id {
	my $self = shift;
	return $self->{SAMPLE_ID};
}


##################################################################################################
#set get pair:afs_project_id
#######################################################
# set_afs_project_id
#Project id associated with a group of affy files usually taken from the MAGE XML 
#######################################################
sub set_afs_project_id {
	my $method = 'set_afs_project_id';
	
	my $self = shift;
	my $name = shift;
	confess(__PACKAGE__ . "::$method No project id provided '$name'\n") unless ($name =~ /^\d/);
	
	return $self->{PROJECT_ID} = $name;
}

#######################################################
# get_afs_project_id
# project_id associated with a group of affy files usually taken from the MAGE XML 
#######################################################
	
sub get_afs_project_id {
	my $self = shift;
	return $self->{PROJECT_ID};
}

##################################################################################################
#set get pair:afa_array_type_id
#######################################################
# set_array_type_id
# array type id associated with a group of affy files usually taken from the MAGE XML 
#######################################################
sub set_afa_array_type_id { 
	my $method = 'set_array_type_id';
	
	my $self = shift;
	my $name = shift;
	confess(__PACKAGE__ . "::$method No array type_id provided '$name'\n") unless ($name =~ /^\d/);
	
	return $self->{ARRAY_TYPE_ID} = $name;
}

#######################################################
# get_afa_array_type_id
# array type id associated with a group of affy files usually taken from the MAGE XML 
#######################################################
	
sub get_afa_array_type_id {
	my $self = shift;
	return $self->{ARRAY_TYPE_ID};
}

##################################################################################################
#set get pair:afa_array_slide_type
#######################################################
# set_array_slide_type
# Store the name of array
#######################################################
sub set_array_slide_type { 
	my $method = 'set_array_slide_type';
	
	my $self = shift;
	my $name = shift;
	confess(__PACKAGE__ . "::$method No slide name provided provided '$name'\n") unless ($name =~ /^\w/);
	
	return $self->{ARRAY_SLIDE_TYPE} = $name;
}

#######################################################
# get_array_slide_type
#Store the type of the array
#######################################################
	
sub get_array_slide_type {
	my $self = shift;
	return $self->{ARRAY_SLIDE_TYPE};
}		

##################################################################################################
#set get pair:afs_organism_id
#######################################################
# set_afs_organism_id
# organism_id for a sample applied to an array 
#######################################################
sub set_afs_organism_id { 
	my $method = 'set_afs_organism_id';
	
	my $self = shift;
	my $name = shift;
	confess(__PACKAGE__ . "::$method No Organism id provided '$name'\n") unless ($name =~ /^\w/);
	
	return $self->{ORGANISM_ID} = $name;
}

#######################################################
# get_afs_organism_id 
#  return the organism_id for a sample applied to an array 
#######################################################
	
sub get_afs_organism_id {
	my $self = shift;
	return $self->{ORGANISM_ID};
}	

##################################################################################################
#set get pair:organism
#######################################################
# set_organism
# organism for a sample applied to an array 
#######################################################
sub set_organism { 
	my $method = 'set_organism';
	
	my $self = shift;
	my $name = shift;
	confess(__PACKAGE__ . "::$method No Organism name provided '$name'\n") unless ($name =~ /^\w/);
	
	return $self->{ORGANISM_NAME} = $name;
}

#######################################################
# get_afs_organism
#  return the organism for a sample applied to an array 
#######################################################
	
sub get_organism {
	my $self = shift;
	return $self->{ORGANISM_NAME};
}


##################################################################################################
#set get pair:afa_file_root
#######################################################
# set_afa_file_root
# file_root name for an array
#######################################################
sub set_afa_file_root { 
	my $method = 'set_afa_file_root';
	
	my $self = shift;
	my $name = shift;
	confess(__PACKAGE__ . "::$method No file_root name provided '$name'\n") unless ($name =~ /^\w/);
	
	return $self->{ROOT_NAME} = $name;
}

#######################################################
# root_name
#  return the root file name for an a array 
#######################################################
	
sub get_afa_file_root {
	my $self = shift;
	return $self->{ROOT_NAME} || '';
}	


##################################################################################################
#set get pair:afa_processed_date 
#######################################################
# set_afa_processed_date
# Set the file_date taken mainly from the MAGE XML file for the date of the scan
#######################################################
sub set_afa_processed_date { 
	my $method = 'set_afa_processed_date';
	
	my $self = shift;
	my $name = shift;
	confess(__PACKAGE__ . "::$method No file date given '$name'\n") unless ($name =~ /^\w/);
	
	return $self->{FILE_DATE} = $name;
}

#######################################################
# get_afa_processed_date
#  Get the file_date taken mainly from the MAGE XML file for the date of the scan
#######################################################
	
sub get_afa_processed_date {
	my $self = shift;
	return $self->{FILE_DATE};
}


##################################################################################################
#set get pair:afa_file_path_id
#######################################################
# set_afa_file_path_id
# Set the file_base_path which is every thing up to the root_file_name
#######################################################
sub set_afa_file_path_id { 
	my $method = 'set_afa_file_path_id';
	
	my $self = shift;
	my $name = shift;
	
	confess(__PACKAGE__ . "::$method No file path id given '$name'\n") unless ($name =~ /^\w/);
	
	return $self->{FILE_BASE_PATH} = $name;
}

#######################################################
# get_afa_file_path_id
#  Get the file_base_path which is every thing Upto the root_file_name
#######################################################
	
sub get_afa_file_path_id {
	my $self = shift;
	return $self->{FILE_BASE_PATH};
}

##################################################################################################
#set get pair:afa_hyb_protocol
#######################################################
# set_afa_hyb_protocol
# the affy array hyb protocol which covers hyb, wash and staining
#######################################################
sub set_afa_hyb_protocol { 
	my $method = 'set_afa_hyb_protocol';
	
	my $self = shift;
	my $name = shift;
	
	confess(__PACKAGE__ . "::$method No hyb protocol '$name'\n") unless ($name =~ /^\w/);
	
	$self->append_protocol_id(value 		=> $name,
				  append_to_method 	=> 'afa_affy_array_protocol_ids',
				  );
				  
	return $self->{AFA_HYB_PROTOCOL} = $name;
}

#######################################################
# get_afa_hyb_protocol
#  the affy array hyb protocol which covers hyb, wash and staining
#######################################################
	
sub get_afa_hyb_protocol {
	my $self = shift;
	return $self->{AFA_HYB_PROTOCOL};
}

##################################################################################################
#set get pair:afa_scan_protocol
#######################################################
# set_afa_scan_protocol
# protocol used to scan a affy array
#######################################################
sub set_afa_scan_protocol { 
	my $method = 'set_afa_scan_protocol';
	
	my $self = shift;
	my $name = shift;
	
	confess(__PACKAGE__ . "::$method No scan protocol given '$name'\n") unless ($name =~ /^\w/);
	
	$self->append_protocol_id(value 		=> $name,
				  append_to_method 	=> 'afa_affy_array_protocol_ids',
				  );
	
	return $self->{AFA_SCAN_PROTOCOL} = $name;
}

#######################################################
# get_afa_scan_protocol
#  protocol used to scan a affy array
#######################################################
	
sub get_afa_scan_protocol {
	my $self = shift;
	return $self->{AFA_SCAN_PROTOCOL};
}

##################################################################################################
#set get pair:afa_feature_extraction_protocol
#######################################################
# set_afa_feature_extraction_protocol
# protocol used to quantitate an affy array to produce a CEL file
#######################################################
sub set_afa_feature_extraction_protocol { 
	my $method = 'set_afa_feature_extraction_protocol';
	
	my $self = shift;
	my $name = shift;
	
	confess(__PACKAGE__ . "::$method feature extraction '$name'\n") unless ($name =~ /^\w/);
	
	$self->append_protocol_id(value 		=> $name,
				  append_to_method 	=> 'afa_affy_array_protocol_ids',
				  );
	
	return $self->{AFA_FEATURE_EXTRACTION_PROTOCOL} = $name;
}

#######################################################
# get_afa_feature_extraction_protocol
# protocol used to quantitate an affy array to produce a CEL file
#######################################################
	
sub get_afa_feature_extraction_protocol {
	my $self = shift;
	return $self->{AFA_FEATURE_EXTRACTION_PROTOCOL};
}

##################################################################################################
#set get pair:afa_chp_generation_protocol
#######################################################
# set_afa_chp_generation_protocol
# protocol used to convert a CEL file to a CHP file
#######################################################
sub set_afa_chp_generation_protocol { 
	my $method = 'set_afa_chp_generation_protocol';
	
	my $self = shift;
	my $name = shift;
	
	confess(__PACKAGE__ . "::$method chp_generation_protocol given '$name'\n") unless ($name =~ /^\w/);
	
	$self->append_protocol_id(value 		=> $name,
				  append_to_method 	=> 'afa_affy_array_protocol_ids',
				  );
	
	return $self->{AFA_CHP_GENERATION_PROTOCOL} = $name;
}

#######################################################
# get_afa_chp_generation_protocol
# protocol used to convert a CEL file to a CHP file
#######################################################
	
sub get_afa_chp_generation_protocol {
	my $self = shift;
	return $self->{AFA_CHP_GENERATION_PROTOCOL};
}

##################################################################################################
#set get pair:afa_affy_array_protocol_ids
#######################################################
# set_afa_affy_array_protocol_ids
# Hold comma delimited list of ALL protocols used on an affy array
#######################################################
sub set_afa_affy_array_protocol_ids { 
	my $method = 'set_afa_affy_array_protocol_ids';
	
	my $self = shift;
	my $name = shift;
	
	confess(__PACKAGE__ . "::$method No base array protocols given '$name'\n") unless ($name =~ /^\w/);
	
	return $self->{AFA_AFFY_ARRAY_PROTOCOL_IDS} = $name;
}

#######################################################
# get_afa_affy_array_protocol_ids
# Hold comma delimited list of protocols used on an affy array
#######################################################
	
sub get_afa_affy_array_protocol_ids {
	my $self = shift;
	return $self->{AFA_AFFY_ARRAY_PROTOCOL_IDS};
}


##################################################################################################
#set get pair:afs_affy_sample_protocol_ids
#######################################################
# set_afs_affy_sample_protocol_ids
# Hold comma delimited list of ALL protocols used on an affy array samples
#######################################################
sub set_afs_affy_sample_protocol_ids { 
	my $method = 'set_afs_affy_sample_protocol_ids';
	
	my $self = shift;
	my $name = shift;
	
	confess(__PACKAGE__ . "::$method No protocol ids given '$name'\n") unless ($name =~ /^\w/);
	
	return $self->{AFS_AFFY_ARRAY_SAMPLE_PROTOCOL_IDS} = $name;
}

#######################################################
# get_afs_affy_sample_protocol_ids
# Hold comma delimited list of protocols used on an affy array samples
#######################################################
	
sub get_afs_affy_sample_protocol_ids {
	my $self = shift;
	return $self->{AFS_AFFY_ARRAY_SAMPLE_PROTOCOL_IDS};
}

##################################################################################################
#set get pair:afa_comment
#######################################################
# set_afa_comment
# array comment
#######################################################
sub set_afa_comment { 
	my $method = 'set_afa_comment';
	
	my $self = shift;
	my $name = shift;	
	return $self->{AFA_COMMENT} = $name;
}

#######################################################
# get_afa_comment
# array comment
#######################################################
	
sub get_afa_comment {
	my $self = shift;
	return $self->{AFA_COMMENT};
}

#################################################################################################
#set get pair:afs_full_sample_name
#######################################################
# set_afs_full_sample_name
#######################################################
sub set_afs_full_sample_name { 
	my $self = shift;
	my $name = shift;
	return $self->{AFS_FULL_SAMPLE_NAME} = $name;
}
#######################################################
# get_afs_full_sample_name
#######################################################	
sub get_afs_full_sample_name {
	my $self = shift;
	return $self->{AFS_FULL_SAMPLE_NAME};
}

##################################################################################################
#set get pair:strain_or_line
#######################################################
# set_strain_or_line
#######################################################
sub set_afs_strain_or_line { 
	my $self = shift;
	my $name = shift;
	return $self->{AFS_STRAIN_OR_LINE} = $name;
}
#######################################################
# get_strain_or_line
#######################################################	
sub get_afs_strain_or_line {
	my $self = shift;
	return $self->{AFS_STRAIN_OR_LINE};
}

##################################################################################################
#set get pair:individual
#######################################################
# set_afs_individual
#######################################################
sub set_afs_individual { 
	my $self = shift;
	my $name = shift;
	return $self->{AFS_INDIVIDUAL} = $name;
}
#######################################################
# get_afs_individual
#######################################################	
sub get_afs_individual {
	my $self = shift;
	return $self->{AFS_INDIVIDUAL};
}

##################################################################################################
#set get pair:afs_sex_ontology_term_id
#######################################################
# set_afs_sex_ontology_term_id
#######################################################
sub set_afs_sex_ontology_term_id { 
	my $self = shift;
	my $name = shift;
	return $self->{AFS_SEX} = $name;
}
#######################################################
# get_afs_sex_ontology_term_id
#######################################################	
sub get_afs_sex_ontology_term_id {
	my $self = shift;
	return $self->{AFS_SEX};
}
##################################################################################################
#set get pair:afs_age
#######################################################
# set_afs_age
#######################################################
sub set_afs_age { 
	my $self = shift;
	my $name = shift;
	return $self->{AFS_AGE} = $name;
}
#######################################################
# get_afs_age
#######################################################	
sub get_afs_age {
	my $self = shift;
	return $self->{AFS_AGE};
}


#######################################################
#set/get pair:afs_organism_part
#######################################################
# set_afs_organism_part
#######################################################
sub set_afs_organism_part { 
  my $self = shift;
  my $name = shift;
  return $self->{AFS_ORGANISM_PART} = $name;
}
#######################################################
# get_afs_organism_part
#######################################################	
sub get_afs_organism_part {
  my $self = shift;
  return $self->{AFS_ORGANISM_PART};
}

##################################################################################################
#set get pair:afs_cell_line
#######################################################
# set_afs_cell_line
#######################################################
sub set_afs_cell_line { 
	my $self = shift;
	my $name = shift;
	return $self->{AFS_CELL_LINE} = $name;
}
#######################################################
# get_afs_cell_line
#######################################################	
sub get_afs_cell_line {
	my $self = shift;
	return $self->{AFS_CELL_LINE};
}

##################################################################################################
#set get pair:afs_cell_type
#######################################################
# set_afs_cell_type
#######################################################
sub set_afs_cell_type { 
	my $self = shift;
	my $name = shift;
	return $self->{AFS_CELL_TYPE} = $name;
}
#######################################################
# get_afs_cell_type
#######################################################	
sub get_afs_cell_type {
	my $self = shift;
	return $self->{AFS_CELL_TYPE};
}
##################################################################################################
#set get pair:afs_disease_state
#######################################################
# set_afs_disease_state
#######################################################
sub set_afs_disease_state { 
	my $self = shift;
	my $name = shift;
	return $self->{AFS_DISEASE_STATE} = $name;
}
#######################################################
# get_afs_disease_state
#######################################################	
sub get_afs_disease_state {
	my $self = shift;
	return $self->{AFS_DISEASE_STATE};
}

##################################################################################################
#set get pair:afs_rna_template_mass
#######################################################
# set_afs_rna_template_mass
#######################################################
sub set_afs_rna_template_mass { 
	my $self = shift;
	my $name = shift;
	return $self->{AFS_RNA_TEMPLATE_MASS} = $name;
}
#######################################################
# get_afs_rna_template_mass
#######################################################	
sub get_afs_rna_template_mass {
	my $self = shift;
	return $self->{AFS_RNA_TEMPLATE_MASS};
}
##################################################################################################
#set get pair:afs_protocol_deviations
#######################################################
# set_afs_protocol_deviations
#######################################################
sub set_afs_protocol_deviations { 
	my $self = shift;
	my $name = shift;
	return $self->{AFS_SAMPLE_PROTOCOL_DEVIATIONS} = $name;
}
#######################################################
# get_afs_protocol_deviations
#######################################################	
sub get_afs_protocol_deviations {
	my $self = shift;
	return $self->{AFS_SAMPLE_PROTOCOL_DEVIATIONS};
}

##################################################################################################
#set get pair:afs_sample_description
#######################################################
# set_afs_sample_description
#######################################################
sub set_afs_sample_description { 
	my $self = shift;
	my $name = shift;
	return $self->{AFS_SAMPLE_DESCRIPTION} = $name;
}
#######################################################
# get_afs_sample_description
#######################################################	
sub get_afs_sample_description {
	my $self = shift;
	return $self->{AFS_SAMPLE_DESCRIPTION};
}

#######################################################
#set get pair:afs_treatment_description
#######################################################
# set_afs_treatment_description
#######################################################
sub set_afs_treatment_description { 
	my $self = shift;
	my $name = shift;
	return $self->{AFS_TREATMENT_DESCRIPTION} = $name;
}
#######################################################
# get_afs_treatment_description
#######################################################	
sub get_afs_treatment_description {
	my $self = shift;
	return $self->{AFS_TREATMENT_DESCRIPTION};
}

#######################################################
#set get pair:afs_data_flag
#######################################################
# set_afs_data_flag
#######################################################
sub set_afs_data_flag { 
	my $self = shift;
	my $name = shift || 'OK';
	return $self->{AFS_DATA_FLAG} = $name;
}
#######################################################
# get_afs_data_flag
#######################################################	
sub get_afs_data_flag {
	my $self = shift;
	return $self->{AFS_DATA_FLAG};
}

#######################################################
#set get pair:treatment_values
#######################################################
# set_treatment_values
#######################################################
sub set_treatment_values { 
	my $self = shift;
	my $values = shift;
  $self->{TREATMENT} ||= [];

  # Maps the XML fields to the field names
  my %field_map = ( 'Stimulus 1 Modifier' => 'modifier', 
                    'Time 1'              => 'time',
                    'Stimulus 1'          => 'treatment_name', 
                    'Stimulus 1 Type'     => 'treatment_mode', 
                    'Stimulus 2 Modifier' => 'modifier', 
                    'Time 2'              => 'time',
                    'Stimulus 2'          => 'treatment_name', 
                    'Stimulus 2 Type'     => 'treatment_mode' 
                  ); 

  my @stim_num = ( 1,2 );
  for my $stim_num ( @stim_num ) {
    my $skip = 1;
    my %treatment;
    for my $key_templ ( 'Stimulus NUM Modifier', 'Time NUM', 
                  'Stimulus NUM', 'Stimulus NUM Type' ) {
      my $key = $key_templ;
      $key =~ s/NUM/$stim_num/;
      $treatment{$field_map{$key}} = $values->{$key};
      if ( defined $values->{$key} && $values->{$key} ne '' ) {
        $skip = 0;
      }
    }
    next if $skip; # Don't add record unless at least one of the params is set
    $treatment{treatment_name} = 'unspecified';
    $treatment{treatment_agent} = $treatment{treatment_name};
    # Fixme - add defaults to config file?
    $treatment{time_units} ||= 'minutes';
    $treatment{treatment_agent} ||= 'chemical agent';
    $treatment{sort_order} ||= 200;
#    for my $t ( keys( %treatment ) ) { print "TREAT SAYS $t => $treatment{$t}\n"; }
    push @{$self->{TREATMENT}}, \%treatment;
  }
#  print  'Total of ' . scalar( @{$self->{TREATMENT}} ) . ' treatments seen' . "\n";
}
#######################################################
# get_treatment_values
#######################################################	
sub get_treatment_values {
	my $self = shift;
#  print "Returning treatments: " . scalar( @{$self->{TREATMENT}} ) . "\n";
	return $self->{TREATMENT};
}

##################################################################################################
#set get pair:afs_comment
#######################################################
# set_afs_sample_comment
#######################################################
sub set_afs_comment { 
	my $self = shift;
	my $name = shift;
	return $self->{AFS_SAMPLE_COMMENT} = $name;
}
#######################################################
# get_afs_comment
#######################################################	
sub get_afs_comment {
	my $self = shift;
	return $self->{AFS_SAMPLE_COMMENT};
}

##################################################################################################
#set get pair:afs_sample_preparation_date
#######################################################
# set_afs_sample_preparation_date
#######################################################
sub set_afs_sample_preparation_date { 
	my $self = shift;
	my $name = shift;
	return $self->{AFS_SAMPLE_PREP_DATE} = $name;
}
#######################################################
# get_afs_sample_preparation_date
#######################################################	
sub get_afs_sample_preparation_date {
	my $self = shift;
	return $self->{AFS_SAMPLE_PREP_DATE};
}
#######################################################
# append_protocol_id
# Append a new protocol id to previous ones all values will be entered in a comma delimited fashion
#######################################################
sub append_protocol_id { 
	my $method = '_append_protocol_id';
	
	my $self = shift;
	my %args = @_;
	
	my $value = $args{value};
	my $append_to_method =  $args{append_to_method};
	
	
	unless ($append_to_method && $value){
		confess(__PACKAGE__ . "::$method Must give values for append_to_method and value, your gave '$value' '$append_to_method' \n") 
	}
	
	my $getter = "get_$append_to_method";
	my $setter = "set_$append_to_method";
	
	my $current_val = $self->$getter();			#grab the current values in the affy_o object
	
	if ($current_val){
		$self->$setter("$current_val,$value");		#append on the new value comma delimited
	}else{	
		$self->$setter($value);				#append on the first protocol		
	}
	
	
	
	return 1;
}


###############################################################################
#find_slide_type_id
#Given the name of a Affy Array Slide get the Slide_type_id
#return slide_type_id
###############################################################################
sub find_slide_type_id {
    my $method = 'find_slide_type_id';
    my $self = shift;
	
	my %args = @_;
	my $slide_name = $args{slide_name};
	
	
	confess(__PACKAGE__ . "::$method Need to provide key value pair 'slide_name'") unless ($slide_name);
	
	my $sql =  qq~ 	SELECT slide_type_id
			FROM $TBMA_SLIDE_TYPE
			WHERE name = '$slide_name'
		    ~;

	my @rows = $sbeams->selectOneColumn($sql);
	
	unless($rows[0] =~ /^\d/){
		die "SLIDE NAME '$slide_name' DOES NOT MATCH ANY NAME in MA_SLIDE_TYPE, PLEASE GO ADD IT\n";
	}
	return $rows[0];
	
}

###############################################################################
#find_project_id
#Given a project_name
#return project_id
###############################################################################
sub find_project_id {
	my $method = 'find_project_id';
    my $self = shift;
	
	my %args = @_;
	my $project_name= $args{project_name};
	my $do_not_die_flag = $args{do_not_die};	#simple flag to use the die statement here or let the caller take care of seeing if the value is good or not
	
	confess(__PACKAGE__ . "::$method Need to provide key value pair 'project_name'") unless ($project_name =~ /^\w/);
	
	my $sql =  qq~ 	SELECT project_id
					FROM $TB_PROJECT
					WHERE name like '$project_name'
				~;
	my @rows = $sbeams->selectOneColumn($sql);
	
	if ($rows[0] =~ /^\d/ || $do_not_die_flag){
		return $rows[0];
	}else{
		die "PROJECT NAME '$project_name' DOES NOT MATCH ANY PROJECT TAGS, PLEASE GO ADD IT\n";
	}
	
}

###############################################################################
#find_organism_id
#Given a organism_name
#return organism_id
###############################################################################
sub find_organism_id {
	my $method = 'find_organism_id';
    my $self = shift;
	
	my %args = @_;
	my $organism_name= $args{organism_name};
	my $do_not_die_flag = $args{do_not_die};	#simple flag to use the die statement here or let the caller take care of seeing if the value is good or not
	
	confess(__PACKAGE__ . "::$method Need to provide key value pair 'project_name'") unless ($organism_name =~ /^\w/);
	
	my $sql =  qq~ 	SELECT organism_id
					FROM $TB_ORGANISM
					WHERE organism_name like '$organism_name'
				~;
	my @rows = $sbeams->selectOneColumn($sql);
	
	if ($rows[0] =~ /^\d/ || $do_not_die_flag){
		return $rows[0];
	}else{
		die "ORGANISM NAME '$organism_name' DOES NOT MATCH ANY OGANISM NAMES, PLEASE GO ADD IT\n";
	}
	
}
###############################################################################
#find_user_login_id
#Given a username
#return userid
###############################################################################
sub find_user_login_id {
	my $method = 'find_user_login_id';
    my $self = shift;
	
	my %args = @_;
	my $user_name= $args{username};
	my $do_not_die_flag = $args{do_not_die};	#simple flag to use the die statement here or let the caller take care of seeing if the value is good or not
	
	confess(__PACKAGE__ . "::$method Need to provide key value pair 'username'") unless ($user_name =~ /^\w/);
	
	my $sql =  qq~ 	SELECT user_login_id
					FROM $TB_USER_LOGIN
					WHERE username like '$user_name'
				~;
	my @rows = $sbeams->selectOneColumn($sql);
	
	if ($rows[0] =~ /^\d/ || $do_not_die_flag){
		return $rows[0];
	}else{
		die "USER NAME '$user_name' DOES NOT MATCH ANY USER NAMES, PLEASE GO ADD IT\n";
	}
	
}


###############################################################################
#find_ontology_id
#Given a term
#return return ontology_id .. #Currently the database is located in the Biolink database
###############################################################################
sub find_ontology_id {
	my $method = 'find_ontology_id';
    my $self = shift;
	
	my %args = @_;
	my $ontology_term= $args{ontology_term};
	my $do_not_die_flag = $args{do_not_die};	#simple flag to use the die statement here or let the caller take care of seeing if the value is good or not
	
	return if (!$ontology_term && $do_not_die_flag >0);
	confess(__PACKAGE__ . "::$method Need to provide key value pair 'ontology_term' VALUE '$ontology_term'") unless ($ontology_term =~ /^\w/);
	
	my $sql =  qq~ 	SELECT MGED_ontology_term_id 
					FROM $TBBL_MGED_ONTOLOGY_TERM
					WHERE name like '$ontology_term'
				~;
	my @rows = $sbeams->selectOneColumn($sql);
	
	if ($rows[0] =~ /^\d/ || $do_not_die_flag){
		return $rows[0];
	}else{
		die "ONTOLOGY NAME '$ontology_term' DOES NOT MATCH ANY ONTOLOGY NAMES, PLEASE GO ADD IT\n";
	}
	
}

}#Close of package bracket 
1;




