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

sub keyword_search {
	my $self = shift;
  my %args = @_;

  my $err;
  for my $key ( qw( search_type search_term ) ) {
    $err .= ( $err ) ? ", $key" : $key unless $args{$key};  
  }
  die "Missing required params: $err" if $err;

  my $sql = $self->get_query_sql( type => $args{search_type},
                                  term => $args{search_term} );

  if ( !$sql ) {
    $log->error( "No SQL generated from query: $args{search_type}, $args{search_term}" );
    return undef;
  }
  $log->debug( $sql );
	my @results = $sbeams->selectHashArray($sql);
  return \@results;
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
  my $observed = ( $mode eq 'all' ) ? '' : "WHERE num_observed > 0 ";
  my $order = ( $mode eq 'all' ) ? 'protein_name ASC' : 'num_observed DESC, protein_name ASC';
#  my $identified = ( $mode eq 'all' ) ? '' : 
#                   ( $mode eq 'identified' ) ? "WHERE num_identified > 0 " : "WHERE num_identified > 0 AND transmembrane_info like '%-%'";
#  my $order = ( $mode eq 'all' ) ? 'protein_name ASC' : 'num_identified DESC, protein_name ASC';
  my $cutoff = $self->get_current_prophet_cutoff();
	
	my $sql = qq~
    SELECT * FROM (
     SELECT ID.ipi_data_id, ipi_accession_number, protein_name, protein_symbol, 
     COUNT(DISTINCT matching_sequence) AS num_observed
      FROM $TBGP_OBSERVED_TO_IPI ITI
       JOIN $TBGP_OBSERVED_PEPTIDE OP ON ITI.observed_peptide_id = OP.observed_peptide_id
       JOIN $TBGP_IPI_DATA ID ON ID.ipi_data_id = ITI.ipi_data_id
      WHERE peptide_prophet_score >= $cutoff
      AND ipi_version_id = 27
      GROUP BY ID.ipi_data_id, ipi_accession_number, protein_name, protein_symbol
      HAVING COUNT(*) > 0
    ) AS temp
    $observed
    ORDER BY $order
  ~;
  $log->debug( $sql );
  

# my $sql = qq~
#  SELECT * FROM (
#  SELECT ipi_data_id, ipi_accession_number, protein_name, protein_symbol, 
#  ( SELECT COUNT(*) 
#  FROM $TBGP_IDENTIFIED_TO_IPI ITI
#  JOIN $TBGP_IDENTIFIED_PEPTIDE IP ON ITI.identified_peptide_id = IP.identified_peptide_id
#  WHERE ipi_data_id = $TBGP_IPI_DATA.ipi_data_id 
#  AND peptide_prophet_score >= $cutoff ) AS num_identified 
#  FROM $TBGP_IPI_DATA
#  ) AS temp
#  $identified
#  ORDER BY $order
#  ~;
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
	my $method = 'make_or_search_string';
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
  for my $k ( keys ( %args ) ) { $log->debug( "querysql: $k => $args{$k}" ); }

  my $cutoff = $self->get_current_prophet_cutoff();

  my $subclause = '';

  if ( $args{type} eq 'swiss_prot' ) {
	  $subclause = " swiss_prot_acc like 'ID_VALUE'";
  } elsif ( $args{type} eq 'protseq' ) {
    $subclause = " protein_sequence like 'ID_VALUE'";
  } elsif ( $args{type} eq 'gene_symbol' ) {
    $subclause = " protein_symbol like 'ID_VALUE'";
  } elsif ( $args{type} eq 'gene_name' ) {
    $subclause = " protein_name like 'ID_VALUE'";
  } elsif ( $args{type} eq 'accession' ) {
    $subclause = " ipi_accession_number like 'ID_VALUE'";
  } elsif ( $args{type} eq 'gene_id' ) {
    $subclause = " ipi_accession_number IN ( SELECT ipi_accessions FROM DCAMPBEL.dbo.ipi_xrefs WHERE entrez_id IN ($args{term}) ) ";
  } else {
    $log->error( "Unknown type" );
    return '';
  }
  my $terms = $self->split_string( $args{term} );
  my $joiner = ' ';
  my $clause = '';
  for my $term ( @$terms ) {
    my $sc = $subclause;
    $sc =~ s/ID_VALUE/$term/g;
    $clause .= $joiner . $sc;
    $joiner = "\n        OR ";
  }
  $clause = $subclause if $args{type} eq 'gene_id';

  my $sql = qq~
  SELECT ID.ipi_data_id, ipi_accession_number, protein_name, protein_symbol, 
    ( SELECT COUNT(*) 
      FROM $TBGP_OBSERVED_TO_IPI ITI 
      JOIN $TBGP_OBSERVED_PEPTIDE IP
        ON IP.observed_peptide_id = ITI.observed_peptide_id
      WHERE ITI.ipi_data_id = ID.ipi_data_id
      AND peptide_prophet_score >= $cutoff ) AS num_observed 
  FROM $TBGP_IPI_DATA ID
  WHERE(  $clause )
  ~;
  $log->info( $sbeams->evalSQL( $sql ) );
  return $sql;
  
#AND peptide_prophet_score >= $cutoff

}

sub split_string {
  my $self = shift;
  my $string = shift || return;
  my @ids = split ",", $string;
  for my $id ( @ids ) {
    $id =~ s/^\s*//g;
    $id =~ s/\s*$//g;
  }
  return \@ids;
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
      ( SELECT ipi_accessions FROM DCAMPBEL.dbo.ipi_xrefs WHERE entrez_id IN ( $term ) )
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
				n_proteins_match_peptide,
				matching_protein_ids,
				predicted_start,
				protein_similarity_score,
				gs.glyco_score,
				gs.protein_glycosite_position,
				predicted_stop, 
        synthesized_sequence
				FROM $TBGP_PREDICTED_PEPTIDE pp
				JOIN $TBGP_PREDICTED_TO_GLYCOSITE ptg ON (ptg.predicted_peptide_id = pp.predicted_peptide_id)
				JOIN $TBGP_GLYCOSITE gs ON (gs.glycosite_id = ptg.glycosite_id AND gs.ipi_data_id = pp.ipi_data_id )
				LEFT JOIN $TBGP_SYNTHESIZED_PEPTIDE sp 
         ON sp.glycosite_id = pp.glycosite_id
				WHERE pp.ipi_data_id = $ipi_data_id
				~;
#   $log->debug( $sql );
	
		return $sbeams->selectHashArray($sql);		
}			


##############################
#get_observed_peptides
#Give a ipi_data_id
#return an array of hashref or nothing
###############################
sub get_observed_peptides{
	my $self = shift;
	my $ipi_data_id = shift;

  #  Broke out the glycosite fetch, couldn't get it to work with
  # without either no non-site mapped peptides or an excess copies of peps.
  my $siteSQL = qq~
  SELECT observed_peptide_id,
    gs.glycosite_id,
  	gs.protein_glycosite_position,
			site_start,
      site_stop
      FROM $TBGP_OBSERVED_TO_GLYCOSITE OTG 
		  JOIN $TBGP_GLYCOSITE GS ON ( GS.glycosite_id = OTG.glycosite_id )
			WHERE ipi_data_id = $ipi_data_id
  ~;

  # hash values keyed by observed_id
  my @rows = $sbeams->selectSeveralColumns( $siteSQL );
  my %sites;
  for my $row ( @rows ) {
    $sites{$row->[0]} = $row;
  }
  
  # Fetch all peptides for given protein entry
	my $sql = qq~
				SELECT OB.observed_peptide_id, peptide_prophet_score,
				matching_sequence, observed_peptide_sequence,
				peptide_mass
				FROM $TBGP_OBSERVED_PEPTIDE OB
          JOIN $TBGP_OBSERVED_TO_IPI OTI 
          ON OTI.observed_peptide_id = OB.observed_peptide_id
				WHERE OTI.ipi_data_id = $ipi_data_id
        ORDER BY matching_sequence
				~;

  my @rows = $sbeams->selectHashArray( $sql );
  my @observed;
  my %current;
  my $cnt = 0;
  for my $row ( @rows ) {
    $cnt++;

    # Merge in glycosite info
    my $opi = $row->{observed_peptide_id};
    if ( $sites{$opi} ) {
      $row->{protein_glycosite_position} = $sites{$opi}->[2]; 
      $row->{site_start} = $sites{$opi}->[3]; 
      $row->{site_stop} = $sites{$opi}->[4]; 
    }

    if ( %current && $current{matching_sequence} =~ /^$row->{matching_sequence}$/i ) {
      $log->debug( "cache" );
      $current{n_obs}++;
      $current{peptide_prophet_score} = $row->{peptide_prophet_score} if $row->{peptide_prophet_score} > $current{peptide_prophet_score};
    } else {  
      if ( %current ) {
        $log->debug( 'save' );
        my %finished = %current;
        push @observed, \%finished;
      } else {
        $log->debug( 'debut' );
      }
      %current = %{$row};
      $log->debug( "Pre: $current{observed_peptide_sequence}" );
      $current{observed_peptide_sequence} =~ s/N[\W]/N#/g;
      $current{observed_peptide_sequence} =~ s/[^a-zA-Z\#\.]//g;
      $current{observed_peptide_sequence} =~ s/([^N])\#/$1/g;
      $log->debug( "Post: $current{observed_peptide_sequence}" );
      $current{n_obs}++;
      $current{tryptic_end} = SBEAMS::Glycopeptide->countTrypticEnds( $row->{observed_peptide_sequence} );
    }
  }
  return ( @observed, \%current );
}	

##############################
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
				SELECT OB.observed_peptide_id,
				observed_peptide_sequence,
				peptide_prophet_score,
				peptide_mass,
				2 AS tryptic_end,
				gs.glyco_score,
				gs.protein_glycosite_position,
				site_start,
				site_start,
        1 AS n_obs
				FROM $TBGP_OBSERVED_PEPTIDE OB
          JOIN $TBGP_OBSERVED_TO_IPI OTI 
            ON OTI.observed_peptide_id = OB.observed_peptide_id
          JOIN $TBGP_OBSERVED_TO_GLYCOSITE OTG 
            ON OTG.observed_peptide_id = OB.observed_peptide_id
	  			JOIN $TBGP_GLYCOSITE GS 
            ON (GS.glycosite_id = OTG.glycosite_id)
				WHERE OTI.ipi_data_id = $ipi_data_id
				~;
	
#  	my $sql = qq~
#  				SELECT 
#  				id.identified_peptide_id
#  				identified_peptide_sequence
#  				peptide_prophet_score,
#  				peptide_mass,
#  				tryptic_end,
#  				gs.glyco_score,
#  				gs.protein_glycosite_position,
#  				identified_start,
#  				identified_stop,
#  n_obs
#  				FROM $TBGP_IDENTIFIED_PEPTIDE id
#  JOIN $TBGP_IDENTIFIED_TO_IPI iti 
#  ON iti.identified_peptide_id = id.identified_peptide_id
#  				JOIN $TBGP_GLYCOSITE gs ON (gs.glycosite_id = iti.glycosite_id)
#  				WHERE iti.ipi_data_id = $ipi_data_id
#  				~;
  	
  		return $sbeams->selectHashArray($sql);	
}	

##############################
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
				SELECT OB.observed_peptide_id,
				observed_peptide_sequence,
				peptide_prophet_score,
				peptide_mass,
				2 AS tryptic_end,
				gs.glyco_score,
				gs.protein_glycosite_position,
				site_start,
				site_start,
        1 AS n_obs
				FROM $TBGP_OBSERVED_PEPTIDE OB
          JOIN $TBGP_OBSERVED_TO_IPI OTI 
            ON OTI.observed_peptide_id = OB.observed_peptide_id
          JOIN $TBGP_OBSERVED_TO_GLYCOSITE OTG 
            ON OTG.observed_peptide_id = OB.observed_peptide_id
	  			JOIN $TBGP_GLYCOSITE GS 
            ON (GS.glycosite_id = OTG.glycosite_id)
				WHERE OTI.ipi_data_id = $ipi_data_id
				~;
	
#  	my $sql = qq~
#  				SELECT 
#  				id.identified_peptide_id
#  				identified_peptide_sequence
#  				peptide_prophet_score,
#  				peptide_mass,
#  				tryptic_end,
#  				gs.glyco_score,
#  				gs.protein_glycosite_position,
#  				identified_start,
#  				identified_stop,
#  n_obs
#  				FROM $TBGP_IDENTIFIED_PEPTIDE id
#  JOIN $TBGP_IDENTIFIED_TO_IPI iti 
#  ON iti.identified_peptide_id = id.identified_peptide_id
#  				JOIN $TBGP_GLYCOSITE gs ON (gs.glycosite_id = iti.glycosite_id)
#  				WHERE iti.ipi_data_id = $ipi_data_id
#  				~;
  	
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
				glycosite_id, 
				protein_glycosite_position,
				glyco_score 
				FROM $TBGP_GLYCOSITE
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
  $log->printStack('debug');
	confess(__PACKAGE__ . "::$method ID '$id' is not good  \n") unless $id; 
	my $sql = qq~
				SELECT t.tissue_type_name 
				FROM $TBGP_PEPTIDE_TO_SAMPLE ptp 
				JOIN $TBGP_UNIPEP_SAMPLE g ON ( ptp.sample_id = g.sample_id ) 
				JOIN $TBGP_TISSUE_TYPE t ON (t.tissue_type_id = g.tissue_type_id) 
				WHERE ptp.identified_peptide_id = $id
        ORDER BY t.tissue_type_name
				~;
  $log->debug( $sql );
	
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


###############################
#get_identified_tissues
#Give a identified_peptide_id
#return an array of hashref or nothing
###############################
sub get_observed_tissues{
	my $self = shift;
	my $seq = shift;
	my $sql = qq~
				SELECT t.tissue_type_name 
				FROM $TBGP_OBSERVED_PEPTIDE op
        JOIN $TBGP_PEPTIDE_SEARCH ps ON ( ps.peptide_search_id = op.peptide_search_id ) 
				JOIN $TBGP_UNIPEP_SAMPLE g ON ( ps.sample_id = g.sample_id ) 
				JOIN $TBGP_TISSUE_TYPE t ON (t.tissue_type_id = g.tissue_type_id) 
				WHERE op.matching_sequence = '$seq'
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
