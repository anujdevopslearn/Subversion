{package SBEAMS::Connection::Merge_results_sets;
	
our $VERSION = '1.00';

####################################################
=head1 NAME

SBEAMS::Connection::Merge_results_sets - Methods to merge multiple results sets into one


=head1 SYNOPSIS
	
Merge Results sets methods

my $m_sbeams = SBEAMS::Connection::Merge_results_sets->new();
			
my $all_pk = $m_sbeams ->get_pk_from_results_set(
  results_set    => $resultset_ref, 
  pk_column_name => "affy_annotation_id",
  );
			  								 				
my $seconds_data_sets_aref = $m_sbeams->run_sql_statments(%second_sql_statements);
			
#loop thru all the secondary results sets appending the data to the main results set

foreach my $second_resultset_ref (@ {$seconds_data_sets_aref} ){	
#first condense down the results sets 
  $m_sbeams->condense_results_set(
    results_set => $second_resultset_ref, 
  	merge_key => "affy_annotation_id",
     );
		
  $m_sbeams->merge_results_sets( main_results_set => $resultset_ref,
    column_to_append_after => 'gene_title',
    merge_column_name      => 'affy_annotation_id',
    second_results_set     => $second_resultset_ref,
    display_columns        => \@column_titles,
    );
}
	
	
	
#######Append new data Methods
	
my $m_sbeams = SBEAMS::Microarray::Merge_results_sets->new();
		
$m_sbeams->append_new_data( 
	resultset_ref => $resultset_ref,
	file_types    => \@downloadable_file_types,    #append on new values to the data_ref foreach column to add
	default_files => \@default_file_types,
	display_files => \@diplay_files,  #Names for columns which will have urls to pop  open files
	image_url	=> '<a href=View_Affy_files.cgi?action=view_image&affy_array_id=$pk_id&file_ext=$display_file>View</a>',
	text_url	=> '<a href=View_Affy_files.cgi?action=view_file&affy_array_id=$pk_id&file_ext=$display_file>View</a>',
	find_file_object => $sbeams_affy_groups,		#send in an object that has a method called check_for_file that will be called, the method will be called with three arguments
);


=head1 DESCRIPTION

Various methods for merging two or more result sets into one.  Also some 
methods for adding checkboxes or links to a results set.  Initially it 
was set up to do two different things to results sets.

=head1 Merge results sets

Initially this was setup to merge data from multiple sql queries.  
Specifically it was used to merge data from from a main query with 
data come from additional queries coming from child tables that
contain a foreign key to the main query.  It assumes that in both queries 
to join there will be column with the same name containing the keys to 
join on.  The name of column will need to be supplied to the method.


=item m_sbeams->get_pk_from_results_set

Extract all the primary queries from a results set.  
Method is useful if you need produce a bunch of secondary queries 
utilizing the foreign keys. Results sets should be produced via the standard sbeams method.
$sbeams->fetchResultSet(
				sql_query     => $sql,
				resultset_ref => $resultset_ref,
			);
All the data from the sql query will be placed into the $resultset_ref

=item $m_sbeams->run_sql_statments(%second_sql_statements);

This method can take in a hash of sql statements $hash{name} = $sql_statment
Given a list of sql statements run them producing results sets. 
It will collect all the results sets refs in a array and return it as an 
array ref. Warning this method is setup to run statements that will be 
used to merge results sets Via a Destructive merge. 
What does this mean??  
If the secondary query being ran contains an 'AND' in the query it assumes 
it has a condition applied to the query and the user only wants to see records 
in the main query that also has data in the secondary query.  If the secondary 
query does not have data for a PK in the main query it will delete the record 
from the main query so it cannot be displayed. 

=item $m_sbeams->condense_results_set

Give a results_set from fetchResultSet and the name of a column to use to 
figure out which rows should be merged.  Will concatenate other row columns 
together (that have same the same value in the name merge_key column) with a semi-colon 
Return: A new results set

=item $m_sbeams->merge_results_sets

Will merge the main results set with the secondary results set.  
"column_to_append_after" is the column name in the main query.
"merge_column_name" is the column contained in both queries to merge on
"display_columns" is the column names for the main query.  It will append 
on the column names from the secondary query
Give back a regular sbeams results sets that can be used in any of the functions you wish


=head1 append_new_data

Method to add new data to a results set such as hyper-linked columns or 
checkboxes.  This method was setup to add links to files or checkboxes so 
a certain file can be downloaded.  Therefore it is built around the toughs 
the new urls or checkboxes will be "pointing" to a file

=item $m_sbeams->append_new_data

Append on more columns of data which can then be shown via the displayResultSet
method.  The method is Setup to display checkboxes or hyperlinks to files pointed 
to by the results set, therefore it will look to see if the file exists to.  
User will have to supply an object that has a method that can be called, 
called "check_for_file"  The method is very selective in what data it expects 
so use with caution.

The data set that is returned by the SQL query via the fetchResultSet method (
and fed into this method must have a pk in the first column and a 
file_name in the second column

=item Arguments 

Arguments for append_new_data method

=item file_types
  
Append on new values to the data_ref foreach value in the given array ref
ALL these columns will be check boxes
Example: @downloadable_file_types = qw(html xml txt JPEG zip)
Will add 5 new columns to the data set
the Html it produces will look like
<input type='checkbox' name='get_all_files' value='${pk_id}__$file_ext' $checked>";

=item default_files
 
The given values will have the check box checked by defualt. Names must be contained 
within the names given to file_types

=item display_files
  
Names for columns which will have urls made to pop open files

=item image_url

Example  
"<a href=View_Affy_files.cgi?action=view_image&affy_array_id=$pk_id&file_ext=$display_file>View</a>"
Info if the file is JPEG then the url given by this argument will be used.
WARNING currently hard coded to only know about the extension JPEG

=item text_url

This is default url to be used to view the file contained in the display_files url
Example '<a href=View_Affy_files.cgi?action=view_file&affy_array_id=$pk_id&file_ext=$display_file>View</a>',

=item find_file_object

Info:This agrument is very strange!!!
The argument is an object that contains a method called "check_for_file" AND it must be able to
work with the following arguments....
$find_object->check_for_file(
			pk_id  		   => $pk_id,
			file_root_name => $root_name,
			file_extension => $file_ext,
			);
The method needs to return a true value if the files exists and 0 (zero) if the file is missing



=head2 EXPORT

None by default.



=head1 SEE ALSO



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

use File::Basename;
use File::Find;
use Data::Dumper;
use Carp;
use FindBin;

	
use base qw(SBEAMS::Connection);		#declare superclass
###############################################################################
# merge_results_sets
# 
###############################################################################
sub merge_results_sets {
	my $method = "merge_results_sets";
	my $self = shift;
		
	my %args = @_;
	
	my $main_results_set_href   = $args{main_results_set};
	my $second_results_set_href = $args{second_results_set};
		
	my $column_name_to_apend_after = $args{column_to_append_after};
	my $merge_column_name     = $args{merge_column_name};
	my $display_column_names  = $args{display_columns};
	
	
	#print STDERR Dumper ($second_results_set_href);
	
	my $main_merge_col_number = $self->find_column_number(results_set => $main_results_set_href,
		  			   							  		  column_name => $merge_column_name,
	  			   							  		     );
	my $column_number_to_append_after = $self->find_column_number(results_set => $main_results_set_href,
		  			   							  		  column_name => $column_name_to_apend_after,
	  			   							  		     );
	$column_number_to_append_after ++;	#we actually want to append after the named column so increment by one
	
	my $extra_data_col_number = $self->find_column_number(results_set => $second_results_set_href,
		  			   							  		  column_name => $merge_column_name,
	  			   							  		     );
	my $number_of_rows_second_results =  $self->find_number_of_rows(results_set => $second_results_set_href);			   							  		     
	 			   							  		 
	###Add in the precisions_list_ref data to the main data set
	splice (@ {$main_results_set_href->{precisions_list_ref} }, $column_number_to_append_after, 0, _remove_first_element(@ {$second_results_set_href->{precisions_list_ref} }));
	
	###Add in the column_list_ref data to the main data set
	splice (@ {$main_results_set_href->{column_list_ref} }, $column_number_to_append_after, 0, _remove_first_element(@ {$second_results_set_href->{column_list_ref} }));
	
	###Add in the types_lists_ref data to the main data set
	splice (@ {$main_results_set_href->{types_list_ref} }, $column_number_to_append_after, 0, _remove_first_element(@ {$second_results_set_href->{types_list_ref} }));
	
	###Update the Display Column Array
	splice (@ {$display_column_names}, $column_number_to_append_after, 0, _remove_first_element(@ {$second_results_set_href->{column_list_ref} }));
	
	###Update the column_hash_ref
	$self->update_column_hash_ref(results_set => $main_results_set_href,
		  			   				  merge_col_numb_number => $column_number_to_append_after,
	  			   					  );
	
	my @good_records_number =();
	my $record_count = 0;
	
	#make and index hash on the second results sets pk and record the index position
	my %index_hash = map{$second_results_set_href->{data_ref}[$_][$extra_data_col_number], $_}0..$#{$second_results_set_href->{data_ref}};
	
	
	MAINLOOP:foreach my $main_data_row_aref (@ {$main_results_set_href->{data_ref} } ) {	#loop thru the main data set
		my $main_data_pk_val = $main_data_row_aref->[$main_merge_col_number];
	
			if ( exists $index_hash{$main_data_pk_val} ){
				
				my $second_index_val = $index_hash{$main_data_pk_val};
				my $second_data_aref = $second_results_set_href->{data_ref}[$second_index_val];
				splice (@{ $main_data_row_aref }, $column_number_to_append_after, 0, _remove_first_element(@ {$second_data_aref}));	
			
				###collect the good records if we need to do a destructive merge
				if ($second_results_set_href->{destructive_merge} eq 'YES'){
					push @good_records_number, $record_count;		
				}
				$record_count++;
				next MAINLOOP;    #assume the secondary results ref will only have one record for each key so go on to the next main record
			}
			
		
			### If we make it here we need to add some blank rows to the data record otherwise everything will be messed up if some of the records in the secondary results set do not have any data
		unless ($second_results_set_href->{destructive_merge} eq 'YES'){
			my @blank_filler_array = ();
			$blank_filler_array[($number_of_rows_second_results-2)] = undef; #remember to take off two values (one since we count from zero and one for ignoring the first value)
			splice (@{ $main_data_row_aref }, $column_number_to_append_after, 0, @blank_filler_array);
		}	
			$record_count++;
	
	}
	
	###Destructive merge.  If a constriant was used on one of the secondary queries we only want to see records 
	### for data that was returned in the second query.  So if no data exists in the second query for a record in the
	### Main query, we will "delete" the records in the main results set
	if ($second_results_set_href->{destructive_merge} eq 'YES'){
		
		my @orginal_records = @{$main_results_set_href->{data_ref}}; #take a slice off the main data_ref of all the good records
		my @good_records = @orginal_records[@good_records_number];
		$main_results_set_href->{data_ref}  = \@good_records;		 #replace the old data with just the good records
	}
	#print STDERR "DONE WITH MERGE\n";
	#print STDERR Dumper ($resultset_ref);	
			
}
###############################################################################
# _remove_first_element
#simple sub to remove the first element of an array
###############################################################################
sub _remove_first_element{
		shift @_;
		return @_;
} 

###############################################################################
# find_number_of_rows
# Give a results_set from fetchResultSet 
# 
# Return: A number: Which is the number of rows that each record should have. Will count
#the number of rows in the precissions_list_ref array.  
###############################################################################
sub find_number_of_rows {
	my $method = "find_number_of_rows";

	my $self = shift;
	
	my %args = @_;
	
	my $results_set_href= $args{results_set};
	
	return (scalar @ {$results_set_href->{precisions_list_ref} });
	
	
}
###############################################################################
# condense_results_set
# Give a results_set from fetchResultSet and the name of a column to use to figure out which 
# rows should be merged.  Will concatenate other row columns together with a semi-colon 
# Return: A new results set
###############################################################################
sub condense_results_set {
	my $method = "condense_results_set";

	my $self = shift;
	
	my %args = @_;
	
	my $results_set_href= $args{results_set};
	my $merge_key	= $args{merge_key};
	
	
	  $self->update_results_data(results_set => $results_set_href,
		  			   			 merge_key => $merge_key,
		  			   			);
	
}


###############################################################################
# update_column_hash_ref
#update the column hash ref within a results set
#Give the results set that has just had the secondary column names inserted into
# the main resultset column_list_ref
#Retrun nothing
###############################################################################
sub update_column_hash_ref {
	my $method = "update_column_hash_ref";
	my $self = shift;
	my %args = @_;
	
	my $results_set_href = $args{results_set};
	##Example Data Structure of column_hash_ref which is what needs to be updated
	#		'column_hash_ref' => {
    #                             'file_root'  => 1,
    #                             'sample_tag' => 2,
	#							   }
	
	
	my %new_href = ();
	my $column_list_ref = $results_set_href->{column_list_ref};
	
	for(my $i = 0; $i <= $#{$column_list_ref} ; $i++){
		my $column_name = $column_list_ref->[$i];
		$new_href{$column_name} = $i;
	
	}
	
	$results_set_href->{column_hash_ref} = \%new_href;	#replace the old href with a new one
}
	
###############################################################################
# update_results_data
#Look at the data make sure there is more then one record for each key and then start merging the data
#Give Resutls_set_href and the a merge_key_name
#return the condensed results set
###############################################################################
sub update_results_data {
	my $method = "update_results_data";
	my $self = shift;
	
	my %args = @_;

	my $results_set_href= $args{results_set};
	my $column_name	= $args{merge_key};
	confess(__PACKAGE__ . "::$method Must Provide Args 'results_set' &  'column_name' \n") unless ($results_set_href && $column_name);
	
	my $column_number = $self->find_column_number(results_set => $results_set_href,
		  			   							  column_name => $column_name,
	  			   							  );
	my $inital_record = 0;
	my $ordered_count = 1;
	my $current_key = '';
	my %merged_data_h = ();
	foreach my $record_aref (@ {$results_set_href->{data_ref} }){	#points to array of arrays
											
		my $current_key = $record_aref->[$column_number];			#Grab the id
		#print STDERR Dumper ($record_aref);
		$merged_data_h{$current_key}{ORDER_COUNT} = $ordered_count;	#remember the order of the records
		$ordered_count++;
		
		
		my $row_count = 0;
		foreach my $row (@{ $record_aref } ){						#loop thru the rows of an array
			if ($row_count == $column_number){;						#skip merging the key column
				$merged_data_h{$current_key}{DATA}[$row_count] = $row;
				$row_count++;
				next;
			}
			if ($row){												#if we have data glue everything together
				$merged_data_h{$current_key}{DATA}[$row_count] .= $merged_data_h{$current_key}{DATA}[$row_count] ? "$row;": "$row";
			}
			$row_count++;
		}
	}
	
	
	$results_set_href->{data_ref}	= [];							#now that the data is merged delete the old data ref and put in the new stuff
	foreach my $a_ref (map {$merged_data_h{$_->[0]}{DATA} }
						  sort { $a <=> $b 
									||
								 $a cmp $b
							   } 
							   map { [$_, $merged_data_h{$_}{ORDER_COUNT}]} keys %merged_data_h)
	{
		
		push @ {$results_set_href->{data_ref} }, $a_ref;
	}
	
	#print STDERR Dumper ($results_set_href);

}
###############################################################################
# run_sql_statments
#Given a list of sql statments run them producing results sets.  Warning this method is setup to run statemnts
#that will be used to merge results sets.  It will try and set a flag to indicate if it should do a destructive merge
#which might not do what you want
#Return an aref of the resultsets
###############################################################################
sub run_sql_statments {
 	my $self = shift;
 	my %second_sql_queries = @_;
 	
 	my @result_sets_data = ();
 	
 	foreach my $sql_name ( keys %second_sql_queries){
 		
 		my $sql = $second_sql_queries{$sql_name};
 		#$self->display_sql(sql=>$sql);
 		
 		my $resultset_ref = {};
 		$self->fetchResultSet(sql_query=>$sql,
		  						resultset_ref=>$resultset_ref,
 								);
 		
 			
 		#if the query has a AND Statement within the WHERE clause we know that this was appended by a constriant statment
 		#therfore when we merge the data delete anything in the main resultset that is not in the secondary results set
 		if ($sql =~ /\sAND\s.+?\sAND\s/si && $sql =~ /gene_ontology_description/){	#Sad Hack to see if the query is a GO query which will always have one AND, therefore if it has two AND's we know it has a constriant
 																					
 			$$resultset_ref{destructive_merge} = "YES";
 			
 		}elsif($sql =~ /\sAND\s/i && $sql !~ /gene_ontology_description/){
 			$$resultset_ref{destructive_merge} = "YES";
 			
 		}
 		
 		push @result_sets_data,  $resultset_ref;
 		
 	}	

 	
 	return 	\@result_sets_data;
}  	

###############################################################################
# updatecolumn_names  #Currently not used.  Will utilize the name from the SQL query alias.  But this might break running if constructing a URL
#Append a name to the column names to make them unique 
#Give a resultset_ref and query_name which will be added as a prefix to all the column names
#Return nothing.  Write directly to the $resultset_ref
###############################################################################
sub updatecolumn_names {
 	my $self = shift;
 	
 	my %args = @_;
 	my $resultset_ref = $args{resultset_ref};
 	my $sql_name      = $args{query_name};
 	
 	my $error_count = 0;
 	
	my $column_list_aref = $resultset_ref->{column_list_ref};		#pull out the column_list_aref
	
	for (my $i=0; $i < $#{$column_list_aref} ; $i++){
		$column_list_aref->[$i] = "${sql_name}__$column_list_aref->[$i]";
		
		$error_count ++;
		die if $error_count > 300;
	
	}

																	#Change the keys withing the column_list_href
	my %new_href = ();
	foreach my $key (keys %{ $resultset_ref->{column_list_href} }){
		my $new_key = "${sql_name}__$key";
		$new_href{$new_key} = $resultset_ref->{column_list_href}{$key};
	}
	$resultset_ref->{column_list_href} = \%new_href;

}	
	
###############################################################################
# find_column_number
#Give a results_set_href and a column name 
#Return the column number
###############################################################################
sub find_column_number {
	my $method = "find_column_number";
	my $self = shift;
	
	my %args = @_;

	my $results_set_href= $args{results_set};
	my $column_name	= $args{column_name};
	
	my $all_columns = '';
	confess(__PACKAGE__ . "::$method Must Provide Args 'results_set' &  'merge_key' \n") unless ($results_set_href && $column_name);
	
	foreach my $col_name (keys % {$results_set_href->{column_hash_ref} }) {#column_hash_ref points to anno_hash with keys of the sql column names and val the row number 'file_root' => 7,
		if ($col_name eq $column_name){
			return $results_set_href->{column_hash_ref}{$col_name};
		}
		$all_columns .= "$col_name<br>";
	}
		print "<h2>Error: Cannot find Column name '$column_name' in Columns<br>$all_columns<br>\n";
		confess(__PACKAGE__ . "::$method THE COLUMN NAME '$column_name' cannot be found in this results set\n");
}


###############################################################################
# get_pk_from_results_set
#Give a results_set_href and a column name for the data to collect
#Return the data from the pk column as a string of concatenated values comma seperated
###############################################################################
sub get_pk_from_results_set {
	my $method = "get_pk_from_results_set";
	
	
	my $self = shift;
	my %args = @_;
	my $results_set_href = $args{results_set};
	my $column_name	= $args{pk_column_name};
	
	confess(__PACKAGE__ . "::$method Must Provide Args 'results_set' &  'pk_column_name' \n") unless ($results_set_href && $column_name);
	
	my $column_number = $self->find_column_number(results_set => $results_set_href,
		  			   							  column_name => $column_name,
	  			   							  );
	
	my %all_values = ();
	foreach my $record_aref (@ {$results_set_href->{data_ref} }){	#points to array of arrays
											
		my $pk_value = $record_aref->[$column_number];			#Grab the pk value
		$all_values{$pk_value} = 1;
	}
	
	if (%all_values){											#join all the values together
		return join ",", sort keys %all_values;
	}else{
		return;
	}	
	
}

###############################################################################
# append_new_data
#
# Append on more columns of data which can then be shown via the displayResultSet method.
# The method is Setup to display checkboxes or hyperlinks to files pointed to by the results set,
# therefore it will look to see if the file exists to.  User will have to supply an object that has a 
#method that can be called, called "check_for_file"
# The method is very selective in what data it expects so use with caution.
#
# The data set that is returned by the SQL query via the fetchResultSet method (
# and fed into this method must have a pk in the first column and a 
# file_name in the second column
#
#
###############################################################################

sub append_new_data {
	my $method = "append_new_data";
	
	my $self = shift;
	my %args = @_;

	my $resultset_ref = $args{resultset_ref};
	my @file_types    = @{ $args{file_types} }; 	  #array ref of columns to add
	my @default_files = @{ $args{default_files} };    #array ref of column names that should be checked
	my @display_files = @{ $args{display_files} }; 	  #array ref of columns to make which will have urls to files to open
	
	my $find_object = $args{find_file_object};  #need to give a object instance that has a method which can take 3 args and tell if a file is present or not
	
	my $text_display_url = $args{text_url};
	my $image_display_url = $args{image_url};
	
	my %search_for_file_h = ();
	
		my $aref =
	  $$resultset_ref{data_ref}; #data is stored as an array of arrays from the $sth->fetchrow_array each row a row from the database holding an aref to all the values

		########################################################################################
	foreach my $display_file_ext (@display_files){    #First, add the Columns for the files that can be viewed directly

			foreach my $row_aref ( @{$aref} ) {
#need to make sure the query has the PK in the first column since we are going directly into the array of arrays and pulling out values
				my $pk_id     = $row_aref->[0] ; 
				my $root_name = $row_aref->[1];

#loop through the files to make sure they exists.  If they do not don't make a check box for the file
				
				my $file_exists = '';
				my $file_exists = $self->_check_for_file( find_file_object => $find_object,
												  pk_id  		   => $pk_id,
												  file_root_name   => $root_name,
												  file_extension   => $display_file_ext,);
				
				
				my $anchor = '';
				if ( $display_file_ext eq 'JPEG' && $file_exists ) {	#FIX ME NEED TO CONVERT SEARCH TO SEE MORE IMAGE TYPES....
					$anchor = "$image_display_url";

				}elsif ($file_exists) {    			#make a url to open this file
					$anchor = "$text_display_url";
				}else {
					$anchor = "No File";
				}
				
				if ($file_exists){
					$anchor = eval $anchor ;
					print "DEBUG EVAL PRODUCED NEW URL '$anchor'\n";
					if ($@){
						confess(__PACKAGE__ . "::$method COULD NOT EVAL URL");
					}
				}
	
				push @$row_aref, $anchor;    		#append on the new data
			}

			push @{ $resultset_ref->{column_list_ref} }, "View $display_file_ext";    #add on column header for each of the file types
		 #need to add the column headers into the resultset_ref since DBInterface display results will reference this

			append_precision_data($resultset_ref); 	#need to append a value for every column added otherwise the column headers will not show
	}

		########################################################################################

		foreach my $file_ext (@file_types){       #loop through the column names to add checkboxes
			my $checked = '';
			if ( grep { $file_ext eq $_ } @default_files ) {
				$checked = "CHECKED";
			}

			foreach my $row_aref ( @{$aref} )
		{ #serious breach of encapsulation,  !!!! De-reference the data array and pushes new values onto the end

			my $pk_id     = $row_aref->[0]; #need to make sure the query has the array_id in the first column since we are going directly into the array of arrays and pulling out values
			my $root_name = $row_aref->[1];

#loop through the files to make sure they exists.  If they do not don't make a check box for the file
			my $file_exists = $self->_check_for_file( find_file_object => $find_object,
												  pk_id  		   => $pk_id,
												  file_root_name   => $root_name,
												  file_extension   => $file_ext,);

			my $input = '';
			if ($file_exists)
			{ #make Check boxes for all the files that are present <array_id__File extension> example 48__CHP
				$input = "<input type='checkbox' name='get_all_files' value='${pk_id}__$file_ext' $checked>";
			}else {
				$input = "No File";
			}

				push @$row_aref, $input;    #append on the new data

			}
#need to add the column headers into the resultset_ref since DBInterface display results will refence this
		 #add on column header for each of the file types	
			push @{ $resultset_ref->{column_list_ref} }, "$file_ext";   
			 
		 #need to append a value for every column added otherwise the column headers will not show
			append_precision_data($resultset_ref);
		}

}


###############################################################################
# append_precision_data
#
# need to append a value for every column added otherwise the column headers will not show
###############################################################################

	sub append_precision_data {
		my $resultset_ref = shift;

		my $aref = $$resultset_ref{precisions_list_ref};

		push @$aref, '-10';

		$$resultset_ref{precisions_list_ref} = $aref;

		

	}
###############################################################################
# _check_for_file
#
# calls method from 
###############################################################################
sub _check_for_file {
	my $method = "check_for_file";
	my $self = shift;
	my %args = @_;
	my $find_object = $args{find_file_object};
	  		
	my $pk_id = $args{pk_id};
	my $root_name = $args{file_root_name};
	my $file_ext = $args{file_extension};
	
	my $previous_call = '';
	if ($previous_call =  $self->_get_previous_file_call(pk_id  		=> $pk_id,
														 file_root_name => $root_name,
														 file_extension => $file_ext,) 
		){
			return $previous_call;
	}else{
		##Make the call to the method that will actually determiine if the file exists
		my $file_exists = $find_object->check_for_file(
			pk_id  		   => $pk_id,
			file_root_name => $root_name,
			file_extension => $file_ext,
			);
		$self->_set_previous_file_call(file_exists  => $file_exists,
									   pk_id  		=> $pk_id,
									   file_root_name => $root_name,
									   file_extension => $file_ext,);
		return $file_exists;
	}
}
###############################################################################
# _set_previous_file_call
#
# Private method to set file exists status
###############################################################################
sub _set_previous_file_call {
		my $self = shift;
		my %args = @_;
		my $file_exists_call = $args{file_exists};
		my $pk_id = $args{pk_id};
		my $root_name = $args{file_root_name};
		my $file_ext = $args{file_extension};
		
		$self->{_PREVIOUS_FILE_CALLS}{$pk_id}{$root_name}{$file_ext} = $file_exists_call;
		
		
}

###############################################################################
# _get_previous_file_call
#
# Private method to record the values from the calls of the find file method
###############################################################################
sub _get_previous_file_call {
		my $self = shift;
		my %args = @_;
		
		my $pk_id = $args{pk_id};
		my $root_name = $args{file_root_name};
		my $file_ext = $args{file_extension};
		
	return	$self->{_PREVIOUS_FILE_CALLS}{$pk_id}{$root_name}{$file_ext}  ;
		
}
	
	

}#end of package