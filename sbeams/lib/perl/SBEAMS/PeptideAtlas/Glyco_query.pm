{package SBEAMS::PeptideAtlas::Glyco_query;
	

####################################################
=head1 NAME

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
use vars qw($sbeams);		

use File::Basename;
use File::Find;
use File::Path;
use Data::Dumper;
use Carp;
use FindBin;


use SBEAMS::Connection qw($q $log);

use Data::Dumper;
use base qw(SBEAMS::PeptideAtlas);		


use SBEAMS::Connection::Tables;
use SBEAMS::PeptideAtlas::Tables;
use SBEAMS::PeptideAtlas::Test_glyco_data;
use SBEAMS::PeptideAtlas::Get_peptide_seqs;




##############################################################################
#constructor
###############################################################################
sub new {
    my $method = 'new';
    my $this = shift;
    my $class = ref($this) || $this;
    
    
    my $self = {};
    bless $self, $class;
    return($self);
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

################################
#gene_symbol_query
###############################
sub gene_symbol_query{
	my $method = 'gene_symbol_query';
	my $self = shift;
	my $term = shift;
	
	confess(__PACKAGE__ . "::$method term '$term' is not good  \n") unless $term;
	
	my $sql = qq~ SELECT ipi_data_id, ipi_accession_number, protein_name, protein_symbol 
				  FROM $TBAT_IPI_DATA 
				  WHERE protein_symbol like '$term'
		  ~;
	
	$log->debug(__PACKAGE__. "::$method $sql");
	return $sbeams->selectHashArray($sql);
}
################################
#gene_name_query
###############################
sub gene_name_query{
	my $method = 'gene_name_query';
	my $self = shift;
	my $term = shift;
	
	confess(__PACKAGE__ . "::$method term '$term' is not good  \n") unless $term;
	
	my $sql = qq~ SELECT ipi_data_id, ipi_accession_number, protein_name, protein_symbol 
				  FROM $TBAT_IPI_DATA 
				  WHERE protein_name like '$term'
		  ~;
	return $sbeams->selectHashArray($sql)
}

################################
#ipi_accession_query
###############################
sub ipi_accession_query{
	my $method = 'ipi_accession_query';
	my $self = shift;
	my $term = shift;
	
	confess(__PACKAGE__ . "::$method term '$term' is not good  \n") unless $term;
	my $search_string = '';
	my $table_name = 'ipi_accession_number';
	
	if ($term =~ /,/){
		$search_string = $self->make_or_search_string(term => $term,
								table_name =>$table_name);
	}else{
		$search_string = "$table_name like '$term' ";
	}


	my $sql = qq~ SELECT ipi_data_id, ipi_accession_number, protein_name, protein_symbol 
				  FROM $TBAT_IPI_DATA 
				  WHERE  $search_string
		  ~;

	$log->debug($sql);
	return $sbeams->selectHashArray($sql)
}
################################
#make_or_search_string
###############################
sub make_or_search_string {
	my $method = 'make_or_search_strin';
	my $self = shift;
	my %args = @_;
	my $term = $args{term};
	my $table_name = $args{table_name};
	 
	confess(__PACKAGE__ . "::$method Table Name '$table_name' is not good  \n") unless $table_name;

	my @parts = split /,/, $term;
	my @info = ();
	foreach my $part(@parts){
		push @info, "$table_name = '$part'";
	}
	my $string = join(" OR ", @info);
	return $string;


}

################################
#swiss_prot_query
###############################
sub swiss_prot_query{
	my $method = 'swiss_prot_query';
	my $self = shift;
	my $term = shift;
	
	confess(__PACKAGE__ . "::$method term '$term' is not good  \n") unless $term;
	
	my $sql = qq~ SELECT ipi_data_id, ipi_accession_number, protein_name, protein_symbol 
				  FROM $TBAT_IPI_DATA 
				  WHERE swiss_prot_acc like '$term'
		  ~;
	return $sbeams->selectHashArray($sql)
}

################################
#protein_seq_query
###############################
sub protein_seq_query{
	my $method = 'protein_seq_query';
	
	my $self = shift;
	my $seq = shift;
	confess(__PACKAGE__ . "::$method seq '$seq' is not good  \n") unless $seq;
	my $sql = qq~ SELECT ipi_data_id, ipi_accession_number, protein_name, protein_symbol 
				  FROM $TBAT_IPI_DATA 
				  WHERE protein_sequence like '%$seq%'
		  ~;
	$log->debug($sql);
	
	return $sbeams->selectHashArray($sql)
}

################################
#query_ipi_data
#Give a ipi_data_id
#return a href of the sql query results or nothing
###############################
sub query_ipi_data{
	my $method = 'query_ipi_data';
	my $self = shift;
	my $ipi_data_id = shift;
	confess(__PACKAGE__ . "::$method ID '$ipi_data_id' is not good  \n") unless $ipi_data_id; 
	my $sql = qq~ 
	    SELECT  
	    ipi_data_id,
        ipi_accession_number,
        protein_name, 
        protein_symbol,
        swiss_prot_acc,
        cellular_location_name,
        protein_summary,
        protein_sequence,
        transmembrane_info,
        signal_sequence_info,
        synonyms
        FROM $TBAT_IPI_DATA ipid
        JOIN $TBAT_CELLULAR_LOCATION cl ON (cl.cellular_location_id = ipid.cellular_location_id) 
        WHERE ipi_data_id =  $ipi_data_id
		  ~;
	
	my @results = $sbeams->selectHashArray($sql);
	#$log->debug(Dumper($results[0]));
	return $results[0];
	
}
################################
#get_predicted_peptides
#Give a ipi_data_id
#return an array of hashref or nothing
###############################
sub get_predicted_peptides{
	my $method = 'get_predicted_peptides';
	my $self = shift;
	
	my $ipi_data_id = shift;
	confess(__PACKAGE__ . "::$method ipi_data_id '$ipi_data_id' is not good  \n") unless $ipi_data_id  ; 
	my $sql = qq~
				SELECT 
				predicted_peptide_id,
				predicted_peptide_sequence,
				predicted_peptide_mass,
				detection_probability,
				number_proteins_match_peptide,
				matching_protein_ids,
				predicted_start,
				protein_similarity_score,
				gs.glyco_score,
				gs.protein_glyco_site_position,
				predicted_stop 
				FROM $TBAT_PREDICTED_PEPTIDE pp
				JOIN $TBAT_GLYCO_SITE gs ON (gs.glyco_site_id = pp.glyco_site_id)
				WHERE pp.ipi_data_id = $ipi_data_id
				~;
	
		return $sbeams->selectHashArray($sql);		
}			

################################
#get_identified_peptides
#Give a ipi_data_id
#return an array of hashref or nothing
###############################
sub get_identified_peptides{
	my $method = 'get_identified_peptides';
	my $self = shift;
	my $ipi_data_id = shift;
	confess(__PACKAGE__ . "::$method ID '$ipi_data_id' is not good  \n") unless $ipi_data_id; 
	my $sql = qq~
				SELECT 
				identified_peptide_id,
				identified_peptide_sequence,
				peptide_prophet_score,
				peptide_mass,
				tryptic_end,
				gs.glyco_score,
				gs.protein_glyco_site_position,
				identified_start,
				identified_stop 
				FROM $TBAT_IDENTIFIED_PEPTIDE id
				JOIN $TBAT_GLYCO_SITE gs ON (gs.glyco_site_id = id.glyco_site_id)
				WHERE id.ipi_data_id = $ipi_data_id
				~;
	
		return $sbeams->selectHashArray($sql);	
}	
################################
#get_glyco_sites
#Give a ipi_data_id
#return an array of hashref or nothing
###############################
sub get_glyco_sites{
	my $method = 'get_glyco_sites';
	my $self = shift;
	my $ipi_data_id = shift;
	confess(__PACKAGE__ . "::$method ID '$ipi_data_id' is not good  \n") unless $ipi_data_id; 
	my $sql = qq~
				SELECT 
				glyco_site_id, 
				protein_glyco_site_position,
				glyco_score 
				FROM $TBAT_GLYCO_SITE
				WHERE ipi_data_id = $ipi_data_id
				~;
	
		return $sbeams->selectHashArray($sql);	

}
###############################
#get_identified_tissues
#Give a identified_peptide_id
#return an array of hashref or nothing
###############################
sub get_identified_tissues{
	my $method = 'get_identified_tissues';
	my $self = shift;
	my $id = shift;
	confess(__PACKAGE__ . "::$method ID '$id' is not good  \n") unless $id; 
	my $sql = qq~
				SELECT t.tissue_name 
				FROM $TBAT_PEPTIDE_TO_TISSUE ptp 
				JOIN $TBAT_TISSUE t ON(t.tissue_id = ptp.tissue_id) 
				WHERE ptp.identified_peptide_id = $id
				~;
	
		return $sbeams->selectHashArray($sql);	

}

} #end of package
1;
