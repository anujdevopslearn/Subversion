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
use vars qw(%REGISTRY);

use base qw(SBEAMS::Microarray);		#declare superclass
use Carp;

#@ISA = qw(SBEAMS::Microarray);     #use our to avoid adding @ISA to the vars mod



#######################################################
# Constructor
#######################################################
sub new {
	my $class = shift;
	
	my $self = {};
	
	bless $self, $class;
	
	$REGISTRY{$self} = $self;	#also returns $self
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
	confess(__PACKAGE__ . "::$method No sample name provided '$name'\n") unless ($name =~ /^\w/);
	
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
	confess(__PACKAGE__ . "::$method No user name provided '$name'\n") unless ($name =~ /^\d/);
	
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
#set get pair:afs_organism_id
#######################################################
# set_afs_organism_id
# organism_id for a sample applied to an array 
#######################################################
sub set_afs_organism_id { 
	my $method = 'set_afs_organism_id';
	
	my $self = shift;
	my $name = shift;
	confess(__PACKAGE__ . "::$method No Organism name provided '$name'\n") unless ($name =~ /^\w/);
	
	return $self->{ORGANISM_ID} = $name;
}

#######################################################
# get_organism
#  return the organism_id for a sample applied to an array 
#######################################################
	
sub get_organism {
	my $self = shift;
	return $self->{ORGANISM_ID};
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
	return $self->{ROOT_NAME};
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
	
	confess(__PACKAGE__ . "::$method No base path given '$name'\n") unless ($name =~ /^\w/);
	
	return $self->{FILE_BASE_PATH} = $name;
}

#######################################################
# get_afa_file_path_id
#  Get the file_base_path which is every thing Upton the root_file_name
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
	
	confess(__PACKAGE__ . "::$method No base path given '$name'\n") unless ($name =~ /^\w/);
	
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
	
	confess(__PACKAGE__ . "::$method No base path given '$name'\n") unless ($name =~ /^\w/);
	
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
	
	confess(__PACKAGE__ . "::$method No base path given '$name'\n") unless ($name =~ /^\w/);
	
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
	
	confess(__PACKAGE__ . "::$method No base path given '$name'\n") unless ($name =~ /^\w/);
	
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
	
	confess(__PACKAGE__ . "::$method No base path given '$name'\n") unless ($name =~ /^\w/);
	
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
	
	confess(__PACKAGE__ . "::$method No base path given '$name'\n") unless ($name =~ /^\w/);
	
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





}#Close of package bracket 
1;




