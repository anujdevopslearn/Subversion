{package SBEAMS::Microarray::Merge_results_sets;
	
our $VERSION = '1.00';

####################################################
=head1 NAME

SBEAMS::Microarray::Merge_results_sets - Methods to merge multipule results sets into one


=head1 SYNOPSIS



=head1 DESCRIPTION



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
				$merged_data_h{$current_key}{DATA}[$row_count] .= "$row;";
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


}#end of package