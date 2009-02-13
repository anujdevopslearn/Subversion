###############################################################################
# Program     : SBEAMS::SolexaTrans::Affy_Analysis
# Author      : Pat Moss <pmoss@systemsbiology.org>
# $Id: Analysis_Data.pm 3645 2005-06-10 18:56:22Z dcampbel $
#
# Description :  Module for working with results of previous analysis sessions.
# 
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
#
###############################################################################


{package SBEAMS::SolexaTrans::Analysis_Data;
	
our $VERSION = '1.00';

####################################################
=head1 NAME

SBEAMS::SolexaTrans::Analysis_Data - Methods to hold data from previous analysis sessions
SBEAMS::SolexaTrans

=head1 SYNOPSIS

 use SBEAMS::Connection::Tables;
 use SBEAMS::SolexaTrans::Tables;
 
 use SBEAMS::SolexaTrans::Affy;
 use SBEAMS::SolexaTrans::Affy_file_groups;

 my $analysis_data_o = new SBEAMS::SolexaTrans::Analysis_data;


=head1 DESCRIPTION


=head2 EXPORT

None by default.



=head1 SEE ALSO

Affy::Analysis

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
use vars qw($sbeams);		

use File::Basename;
use File::Find;
use Data::Dumper;
use Carp;
use FindBin;

use base qw(SBEAMS::SolexaTrans::Solexa_Analysis);		
use SBEAMS::Connection::Tables;
use SBEAMS::SolexaTrans::Tables;

#######################################################
# Constructor
#######################################################
sub new {
	my $class = shift;
	my %args= @_;
	my $data_aref = $args{data};
	
	my $self = {};
	
	foreach my $href (@{$data_aref}){
		my $data_type   = $href->{affy_analysis_name};
		my $folder_name = $href->{folder_name};
		my $date_created = $href->{date_created};
		$date_created =~ s/\s.*// ;#Clean up the time to just the date not the time 2005-01-14 14:49:38.443
		
		
		$self->{_DATA_TYPES}{$data_type}{$folder_name} = {
			_ANALYSIS_DESC 	  	=> $href->{analysis_description}, 
			_USER_DESC			=> $href->{user_description},
			_PARENT_ANALYSIS_ID => $href->{parent_analysis_id},
			_ANALYSIS_ID		=> $href->{affy_analysis_id},
			_ANALYSIS_DATE		=> $date_created,
			_USER_LOGIN_NAME 	=> $href->{username},
		};   
	}
	
	bless $self, $class;
}

#######################################################
# get_analysis_types
# Give affy analysis object
# Return return an array of analysis types
#
#######################################################
sub get_analysis_types {

	my $method = 'get_analysis_types';
	my $self = shift;
	my @analysis_types = ();
	unless (ref $self) {
		confess( __PACKAGE__ . "::$method Must provide an affy analysis object\n");
	}
	
	foreach my $analysis_name_type (sort keys %{$self->{_DATA_TYPES}}){
		push @analysis_types, $analysis_name_type;
	}
	unless (scalar @analysis_types >= 1){
		die "THERE WAS NO ANALYSIS TYPES IN THIS AFFY ANALYSIS OBJECT. THIS IS NOT GOOD\n"
	}
	return @analysis_types;
}

#######################################################
# check_for_analysis_data
# Give affy_analysis_name
# Return  the folders that exists from previous analysis sessions
# or 0 if no folders exists for a particular data type
#######################################################
sub check_for_analysis_data_type {

	my $method = 'check_for_analysis_data_type';
	my $self = shift;
	
	my %args= @_;
	my $analysis_name_type = $args{analysis_name_type};
	
	#print "CHECK FOR ANALYSIS DATA ANALYSIS NAME '$analysis_name_type'<br>";
	unless ($analysis_name_type =~ /^\w/ ) {
		confess( __PACKAGE__ . "::$method Need to provide a affy_analysis_name type\n");
	}
	
	if (exists $self->{_DATA_TYPES}{$analysis_name_type}){
		
##Sort the folders by the Analysis ID
		my @folders = map {$_->[0]} 
			sort {  $b->[1] <=> $a->[1]
						   ||
					$b->[0] cmp $a->[0]						
			} 
			map{[$_, $self->{_DATA_TYPES}{$analysis_name_type}{$_}{_ANALYSIS_ID}] } 
			keys %{ $self->{_DATA_TYPES}{$analysis_name_type} };
		
		#print "$method FOLDER COUNT '" . scalar @folders. "'<br>\n";
		return \@folders;
	}else{
		return 0;
	}
}

#######################################################
# get_analysis_info
# Give affy_analysis_name,  folder_name, info[anno array]
# Current keys ("analysis_desc" "user_desc" "parent_analysis_id" "analysis_id" "analysis_date" "user_login"  )			
# Return all the data as a list
#######################################################
sub get_analysis_info {
	my $method = 'get_analysis_info';
	my $self = shift;
	
	my %args= @_;
	my $analysis_name_type 	= $args{analysis_name_type};
	my $folder_name 		= $args{folder_name};
	my @info_types 			= @ {$args{info_types} };
	my $truncate_data 		= $args{truncate_data};
	
	unless ($analysis_name_type =~ /^\w/  && $folder_name =~ /^\w/ && @info_types) {
		confess( __PACKAGE__ . "::$method Need to provide a affy_analysis_name_type , folder_name and info_type\n");
	}
	
	my @all_data = ();
	
	foreach my $info_type (@info_types){
		
		my $info_hash_key = uc($info_type); 
		$info_hash_key = "_$info_hash_key";	#pre-pend underscore to match the actual keys being used 
	
		#print "INFO KEY '$info_hash_key' ANALYSIS '$analysis_name_type' FOLDER '$folder_name'<br>";
		if (my $info =  $self->{_DATA_TYPES}{$analysis_name_type}{$folder_name}{$info_hash_key}){
			
			$info =~ s~//~<br>~g;
			if ($truncate_data > 0){
				$info = truncate_data($self, $info);
			}
			push @all_data, $info;
		}else{
			
			push @all_data, "No Data";
		}
	}	
	return @all_data;
}
#######################################################
# truncate_data
# Give  object and a term to truncate	
# Return truncated value to 50 char which will look much better for display
#######################################################
sub truncate_data {
	my $method = 'find_analysis_id';
	my $self = shift;
	my $term = shift;
	if (length $term > 50){
		$term = substr($term, 0, 50) . "...";
	}
	
	return ($term );
	
	
}	
#######################################################
# find_analysis_id
# Give  folder_name, affy_analysis_name_type	
# Return list of the analsysis_id, parent_id or 0 if there is no data
#######################################################
sub find_analysis_id {
	my $method = 'find_analysis_id';
	my $self = shift;
	
	my %args= @_;
	my $analysis_name_type 	= $args{analysis_name_type};
	my $folder_name 		= $args{folder_name};
	my @data = ();
	
	unless ($analysis_name_type =~ /^\w/  && $folder_name =~ /^\w/ ) {
		confess( __PACKAGE__ . "::$method Need to provide affy_analysis_name_type , folder_name arguments\n" . Dumper($self) );
	}
	
	if (exists $self->{_DATA_TYPES}{$analysis_name_type}{$folder_name}){
		push @data, $self->{_DATA_TYPES}{$analysis_name_type}{$folder_name}{_ANALYSIS_ID};
		push @data, $self->{_DATA_TYPES}{$analysis_name_type}{$folder_name}{_PARENT_ANALYSIS_ID};
		
		unless ($self->{_DATA_TYPES}{$analysis_name_type}{$folder_name}{_PARENT_ANALYSIS_ID}){
			confess( "ERROR CANNOT FIND DATA". Dumper($self) );
		}
		return @data;
	}
	
	return 	0;
	
}

}#end of the package
