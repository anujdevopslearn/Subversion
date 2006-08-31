{package SBEAMS::Glycopeptide::Glyco_query;
	

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
use base qw(SBEAMS::Glycopeptide);		


use SBEAMS::Connection;
use SBEAMS::Connection::Tables;
use SBEAMS::Glycopeptide::Tables;
use SBEAMS::Glycopeptide::Test_glyco_data;
use SBEAMS::Glycopeptide::Get_peptide_seqs;


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
    $sbeams ||= new SBEAMS::Connection();
    return($sbeams);
}

################################
#gene_symbol_query
###############################
sub gene_symbol_query{
	my $method = 'gene_symbol_query';
	my $self = shift;
	my $term = shift;
	
	my $osql = qq~
    SELECT ipi_data_id, ipi_accession_number, protein_name, protein_symbol, 
    (SELECT COUNT(*) FROM $TBGP_IDENTIFIED_TO_IPI 
    WHERE ipi_data_id = $TBGP_IPI_DATA.ipi_data_id ) AS num_identified 
    FROM $TBGP_IPI_DATA
    WHERE protein_symbol like '$term'
  ~;

  my $sql = $self->get_query_sql( type => 'protsymbol', term => $term );
	
	return $sbeams->selectHashArray($sql);
}
################################
#gene_name_query
###############################
sub gene_name_query{
	my $method = 'gene_name_query';
	my $self = shift;
	my $term = shift;
	
	my $osql = qq~
    SELECT ipi_data_id, ipi_accession_number, protein_name, protein_symbol, 
    (SELECT COUNT(*) FROM $TBGP_IDENTIFIED_TO_IPI 
    WHERE ipi_data_id = $TBGP_IPI_DATA.ipi_data_id ) AS num_identified 
    FROM $TBGP_IPI_DATA
    WHERE protein_name like '$term'
  ~;

  my $sql = $self->get_query_sql( type => 'protname', term => $term );

	return $sbeams->selectHashArray($sql)
}

sub all_proteins_query {

	my $self = shift;
	my $mode = shift;
  my $identified = ( $mode eq 'all' ) ? '' : 
                   ( $mode eq 'identified' ) ? "WHERE num_identified > 0 " : "WHERE num_identified > 0 AND transmembrane_info like '%-%'";
  my $order = ( $mode eq 'all' ) ? 'protein_name ASC' : 'num_identified DESC, protein_name ASC';
  my $cutoff = $self->get_current_prophet_cutoff();
	
	my $sql = qq~
    SELECT * FROM (
    SELECT ipi_data_id, ipi_accession_number, protein_name, protein_symbol, 
    ( SELECT COUNT(*) 
      FROM $TBGP_IDENTIFIED_TO_IPI ITI
      JOIN $TBGP_IDENTIFIED_PEPTIDE IP ON ITI.identified_peptide_id = IP.identified_peptide_id
      WHERE ipi_data_id = $TBGP_IPI_DATA.ipi_data_id 
      AND peptide_prophet_score >= $cutoff ) AS num_identified, transmembrane_info 
    FROM $TBGP_IPI_DATA
    ) AS temp
    $identified
    ORDER BY $order
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
	

	my $search_string = '';
	my $table_name = 'ipi_accession_number';
	
	if ($term =~ /,/){
		$search_string = $self->make_or_search_string(term => $term,
								table_name =>$table_name);
	}else{
		$search_string = "$table_name like '$term' ";
	}

	my $osql = qq~
    SELECT ipi_data_id, ipi_accession_number, protein_name, protein_symbol, 
    (SELECT COUNT(*) FROM $TBGP_IDENTIFIED_TO_IPI 
    WHERE ipi_data_id = $TBGP_IPI_DATA.ipi_data_id ) AS num_identified 
    FROM $TBGP_IPI_DATA
    WHERE $search_string
  ~;

  my $sql = $self->get_query_sql( type => 'ipi', term => $search_string );

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

sub get_query_sql {
  my $self = shift;
  my %args = @_;
  my $cutoff = $self->get_current_prophet_cutoff();
  my $clause = '';
  if ( $args{type} eq 'swissprot' ) {
	  $clause = "WHERE swiss_prot_acc like '$args{term}'";
  } elsif ( $args{type} eq 'protseq' ) {
    $clause = "WHERE protein_sequence like '$args{term}'";
  } elsif ( $args{type} eq 'protsymbol' ) {
    $clause = "WHERE protein_symbol like '$args{term}'";
  } elsif ( $args{type} eq 'protname' ) {
    $clause = "WHERE protein_name like '$args{term}'";
  } elsif ( $args{type} eq 'ipi' ) {
    $clause = "WHERE $args{term}";
  } else {
    $log->error( "Unknown type" );
    return '';
  }

  my $sql = qq~
  SELECT ipi_data_id, ipi_accession_number, protein_name, protein_symbol, 
    ( SELECT COUNT(*) 
      FROM $TBGP_IDENTIFIED_TO_IPI ITI 
      JOIN $TBGP_IDENTIFIED_PEPTIDE IP
        ON IP.identified_peptide_id = ITI.identified_peptide_id
      WHERE ipi_data_id = $TBGP_IPI_DATA.ipi_data_id
      AND peptide_prophet_score >= $cutoff ) AS num_identified 
  FROM $TBGP_IPI_DATA
  $clause
  ~;
  $log->info( $sbeams->evalSQL( $sql ) );
  return $sql;
  
#AND peptide_prophet_score >= $cutoff

}

#+
# Entrez gene id query
#-
sub gene_id_query {
	my $method = 'gene_id_query';
	my $self = shift;
	my $term = shift;

  $term =~ s/\;/\,/g;
	
	my $sql = qq~
    SELECT ipi_data_id, ipi_accession_number, protein_name, protein_symbol, 
    (SELECT COUNT(*) FROM $TBGP_IDENTIFIED_TO_IPI 
    WHERE ipi_data_id = $TBGP_IPI_DATA.ipi_data_id ) AS num_identified 
    FROM $TBGP_IPI_DATA
	  WHERE ipi_accession_number IN 
      ( SELECT ipi_accessions FROM DCAMPBEL.dbo.ipi_xrefs WHERE 
        entrez_id IN ( $term ) )
  ~;

  # Newfangled
#  my $sql = $self->get_query_sql( type => 'swissprot', term => $term );
	return $sbeams->selectHashArray($sql)
}

################################
#swiss_prot_query
###############################
sub swiss_prot_query{
	my $method = 'swiss_prot_query';
	my $self = shift;
	my $term = shift;
	
	confess(__PACKAGE__ . "::$method term '$term' is not good  \n") unless $term;
	
	my $sql = qq~
    SELECT ipi_data_id, ipi_accession_number, protein_name, protein_symbol, 
    (SELECT COUNT(*) FROM $TBGP_IDENTIFIED_TO_IPI 
    WHERE ipi_data_id = $TBGP_IPI_DATA.ipi_data_id ) AS num_identified 
    FROM $TBGP_IPI_DATA
	  WHERE swiss_prot_acc LIKE '$term'
  ~;

  # Newfangled
  my $sql = $self->get_query_sql( type => 'swissprot', term => $term );

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

	my $osql = qq~
    SELECT ipi_data_id, ipi_accession_number, protein_name, protein_symbol, 
    (SELECT COUNT(*) FROM $TBGP_IDENTIFIED_TO_IPI 
    WHERE ipi_data_id = $TBGP_IPI_DATA.ipi_data_id ) AS num_identified 
    FROM $TBGP_IPI_DATA
    WHERE protein_sequence like '%$seq%'
  ~;

  # Newfangled
  chomp $seq;
  my $sql = $self->get_query_sql( type => 'protseq', term => $seq );

	
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
        FROM $TBGP_IPI_DATA ipid
        JOIN $TBGP_CELLULAR_LOCATION cl ON (cl.cellular_location_id = ipid.cellular_location_id) 
        WHERE ipi_data_id =  $ipi_data_id
		  ~;
	
	my @results = $sbeams->selectHashArray($sql);
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
				pp.predicted_peptide_id,
				pp.predicted_peptide_sequence,
				predicted_peptide_mass,
				detection_probability,
				number_proteins_match_peptide,
				matching_protein_ids,
				predicted_start,
				protein_similarity_score,
				gs.glyco_score,
				gs.protein_glyco_site_position,
				predicted_stop, 
        synthesized_sequence
				FROM $TBGP_PREDICTED_PEPTIDE pp
				JOIN $TBGP_GLYCO_SITE gs ON (gs.glyco_site_id = pp.glyco_site_id)
				LEFT JOIN $TBGP_SYNTHESIZED_PEPTIDE sp 
         ON sp.glyco_site_id = pp.glyco_site_id
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
				id.identified_peptide_id,
				identified_peptide_sequence,
				peptide_prophet_score,
				peptide_mass,
				tryptic_end,
				gs.glyco_score,
				gs.protein_glyco_site_position,
				identified_start,
				identified_stop,
        n_obs
				FROM $TBGP_IDENTIFIED_PEPTIDE id
        JOIN $TBGP_IDENTIFIED_TO_IPI iti 
          ON iti.identified_peptide_id = id.identified_peptide_id
				JOIN $TBGP_GLYCO_SITE gs ON (gs.glyco_site_id = iti.glyco_site_id)
				WHERE iti.ipi_data_id = $ipi_data_id
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
				FROM $TBGP_GLYCO_SITE
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
				SELECT t.tissue_type_name 
				FROM $TBGP_PEPTIDE_TO_TISSUE ptp 
				JOIN $TBGP_GLYCO_SAMPLE g ON ( ptp.sample_id = g.sample_id ) 
				JOIN $TBGP_TISSUE_TYPE t ON (t.tissue_type_id = g.tissue_type_id) 
				WHERE ptp.identified_peptide_id = $id
        ORDER BY t.tissue_type_name
				~;
	
	my @all_tissues = $sbeams->selectHashArray($sql);	
  my @coalesced_tissues;
  my %seen;
  for my $tissue ( @all_tissues ) {
    next if $seen{$tissue->{tissue_type_name}};
    push @coalesced_tissues, $tissue->{tissue_type_name};
    $seen{$tissue->{tissue_type_name}}++;
  }
  return \@coalesced_tissues;
}

} #end of package
1;
