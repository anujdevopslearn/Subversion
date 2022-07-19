package SBEAMS::PeptideAtlas::AtlasBuild;

###############################################################################
# Class       : SBEAMS::PeptideAtlas::AtlasBuild
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
#
=head1 SBEAMS::PeptideAtlas::AtlasBuild

=head2 SYNOPSIS

  SBEAMS::PeptideAtlas::AtlasBuild

=head2 DESCRIPTION

This is part of the SBEAMS::PeptideAtlas module which handles
atlas build related things.

=cut
#
###############################################################################

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
require Exporter;
@ISA = qw();
$VERSION = q[$Id$];
@EXPORT_OK = qw();

use SBEAMS::Connection qw( $log );
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::Settings;
use SBEAMS::PeptideAtlas::Tables;

my $sbeams = SBEAMS::Connection->new();

###############################################################################
# Global variables
###############################################################################
use vars qw($VERBOSE $TESTONLY $sbeams);


###############################################################################
# Constructor
###############################################################################
sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;
    $sbeams = $self->getSBEAMS();
    return($self);
} # end new


###############################################################################
# setSBEAMS: Receive the main SBEAMS object
###############################################################################
sub setSBEAMS {
    my $self = shift;
    $sbeams = shift;
    return($sbeams);
} # end setSBEAMS



###############################################################################
# getSBEAMS: Provide the main SBEAMS object
###############################################################################
sub getSBEAMS {
    my $self = shift;
    return $sbeams || SBEAMS::Connection->new();
} # end getSBEAMS



###############################################################################
# listBuilds -- List all PeptideAtlas builds
###############################################################################
sub listBuilds {
  my $METHOD = 'listBuilds';
  my $self = shift || die ("self not passed");
  my %args = @_;

  my $sql = qq~
    SELECT atlas_build_id,atlas_build_name
      FROM $TBAT_ATLAS_BUILD
     WHERE record_status != 'D'
     ORDER BY atlas_build_name
  ~;

  my @atlas_builds = $sbeams->selectSeveralColumns($sql) or
    die("ERROR[$METHOD]: There appear to be no atlas builds in your database");

  foreach my $atlas_build (@atlas_builds) {
    printf("%5d %s\n",$atlas_build->[0],$atlas_build->[1]);
  }

} # end listBuilds

sub GetBuildSelect {
  my $self = shift || die ("self not passed");
  my %args = ( set_onchange => 1, 
	                 build_id => '',
	               build_name => '',
                  form_name => 'switch_build',
	            @_ );

	if ( !$args{build_name} && $args{build_id} ) {
		$args{build_name} = $self->getBuildName( build_id => $args{build_id} );
	}

	my $project_string = join( ', ', $sbeams->getAccessibleProjects() );
	return unless $project_string;

	my $onchange_script = '';
	my $onchange = '';
  if ($args{set_onchange}) {
	  $onchange = 'onchange="switchAtlasBuild()"';
		$onchange_script =  qq~
		<SCRIPT LANGUAGE=javascript TYPE=text/javascript>
		function switchAtlasBuild() {
			document.$args{form_name}.submit();
		}
		</SCRIPT>
		~;
	}

#  for my $build_id ( keys( %{$atlas_builds} ) ) {
  my $sql = qq~
    SELECT atlas_build_id,atlas_build_name
      FROM $TBAT_ATLAS_BUILD
		 WHERE project_id IN ( $project_string )
     AND record_status != 'D'
     ORDER BY atlas_build_name
  ~;
	my $sth = $sbeams->get_statement_handle( $sql );
	my $select = "<SELECT NAME=atlas_build_id $onchange>\n";
	while ( my @row = $sth->fetchrow_array() ) {
		# default to first one
		$args{build_name} ||= $row[1];
		my $selected = ( $row[1] =~ /^$args{build_name}$/ ) ? 'SELECTED' : '';
		$select .= "<OPTION VALUE=$row[0] $selected> $row[1] </OPTION>\n";
	}
	$select .= "</SELECT>\n";

	return ( wantarray() ) ? ($select, $onchange_script) :  $select . $onchange_script; 

} # end GetBuildSelect

sub getBuildPeptideSourceTypes {
  my $self = shift;
  my %args = @_;

  my $atlas_build_id = $args{atlas_build_id} || return;

  my $sql = qq~
  SELECT DISTINCT peptide_source_type, ASB.atlas_search_batch_id
  FROM $TBAT_ATLAS_SEARCH_BATCH ASB
  JOIN $TBAT_ATLAS_BUILD_SEARCH_BATCH ABSB ON ASB.atlas_search_batch_id = ABSB.atlas_search_batch_id
  JOIN $TBAT_SAMPLE S ON ASB.sample_id = S.sample_id
  WHERE atlas_build_id = '$atlas_build_id'
  ~;

  my %sourceTypes = 0;
  my $sth = $sbeams->get_statement_handle($sql); 
  while ( my @row = $sth->fetchrow_array() ) {
    $sourceTypes{$row[0]}++;
  }
  return \%sourceTypes;
}

sub getAtlasBuildDirectory {
  my $self = shift;
  my %args = @_;

  my $atlas_build_id = $args{atlas_build_id} || return;

  my $sql = qq~
  SELECT data_path
  FROM $TBAT_ATLAS_BUILD
  WHERE atlas_build_id = '$atlas_build_id'
  AND record_status != 'D'
  ~;

  my @path = $sbeams->selectOneColumn($sql); 

  ## get the global variable PeptideAtlas_PIPELINE_DIRECTORY
  my $pipeline_dir = $CONFIG_SETTING{PeptideAtlas_PIPELINE_DIRECTORY};

  return "$pipeline_dir/$path[0]";
}

sub getBuildName {
  my $self = shift;
  my %args = @_;

  my $build_id = $args{build_id} || return;

  my $sql = qq~
  SELECT atlas_build_name
  FROM $TBAT_ATLAS_BUILD
  WHERE atlas_build_id = '$build_id'
  AND record_status != 'D'
  ~;

  my @build = $sbeams->selectOneColumn($sql); 

  return $build[0];
}

# convenience method to look up hash of proteomics search batch to atlas SB
sub getProtSB2AtlasSB {
	my $self = shift;
	my %args = @_;
	my $where = '';
	if ( $args{build_id} ) {
		if ( ref $args{build_id} ne 'ARRAY' ) {
			die "build_id must be an array reference, not a " . ref $args{build_id};
		}
		$where = "WHERE atlas_build_id IN ( " . join( ',', @{$args{build_id}} ) . ' )';
	}
  my $sql = qq~
    SELECT DISTINCT proteomics_search_batch_id, ASB.atlas_search_batch_id
    FROM $TBAT_ATLAS_SEARCH_BATCH ASB
		JOIN $TBAT_ATLAS_BUILD_SEARCH_BATCH ABSB
	    ON ASB.atlas_search_batch_id = ABSB.atlas_search_batch_id
	  $where
  ~;
#	print "$sql\n";

  my $sth = $sbeams->get_statement_handle( $sql );
  
  my %mapping;
  while( my $row = $sth->fetchrow_arrayref() ) {
    if ( $mapping{$row->[0]} ) {
      $log->warn( "Doppelganger! more than one Atlas SB for Prot SB $row->[0]\n" );
    }
    $mapping{$row->[0]} = $row->[1];
  }
  return \%mapping;
}

#####

# convenience method to look up hash of proteomics search batch to sample
sub getSearchBatch2Sample {
	my $self = shift;
	my %args = @_;
	my $where = '';
	if ( $args{build_id} ) {
		if ( ref $args{build_id} ne 'ARRAY' ) {
			die "build_id must be an array reference, not a " . ref $args{build_id};
		}
		$where = "WHERE atlas_build_id IN ( " . join( ',', @{$args{build_id}} ) . ' )';
	}
  my $sql = qq~
    SELECT DISTINCT proteomics_search_batch_id, ASB.sample_id
    FROM $TBAT_ATLAS_SEARCH_BATCH ASB
		JOIN $TBAT_ATLAS_BUILD_SEARCH_BATCH ABSB
	    ON ASB.atlas_search_batch_id = ABSB.atlas_search_batch_id
	  $where
  ~;
#	print "$sql\n";

  my $sth = $sbeams->get_statement_handle( $sql );
  
  my %mapping;
  while( my $row = $sth->fetchrow_arrayref() ) {
    if ( $mapping{$row->[0]} ) {
      $log->warn( "Doppelganger! more than one sample_id for prot_search_batch $row->[0]\n" );
    }
    $mapping{$row->[0]} = $row->[1];
  }
  return \%mapping;
}

# getPepInstRecords( build_id => $ATLAS_BUILD_ID );
# getModPepInstRecords( build_id => $ATLAS_BUILD_ID );

#+
# returns ref to hash of peptide => sample => pep_inst_sample_id
#-
sub getPepInstRecords {
	my $self = shift;
	my %args = @_;

	if ( !$args{build_id} ) {
		$log->error( "Missing required param build_id" );
		return undef;
	}

  my $sql = qq~
    SELECT peptide_sequence, PI.peptide_instance_id, 
		peptide_instance_search_batch_id, atlas_search_batch_id
    FROM $TBAT_PEPTIDE P
		JOIN $TBAT_PEPTIDE_INSTANCE PI ON P.peptide_id = PI.peptide_id
		JOIN $TBAT_PEPTIDE_INSTANCE_SEARCH_BATCH PIS ON PI.peptide_instance_id = PIS.peptide_instance_id
	  WHERE atlas_build_id = $args{build_id}
  ~;
#	print "$sql\n";

  my $sth = $sbeams->get_statement_handle( $sql );
  
  my %mapping;
  while( my @row = $sth->fetchrow_array() ) {
    $mapping{$row[0]} ||= {};
    $mapping{$row[0]}->{$row[3]} = $row[2];
  }
  return \%mapping;
}


#+
# returns ref to hash of peptide => sample => pep_inst_sample_id
#-
sub getModPepInstRecords {
	my $self = shift;
	my %args = @_;

	if ( !$args{build_id} ) {
		$log->error( "Missing required param build_id" );
		return undef;
	}

  my $sql = qq~
    SELECT modified_peptide_sequence, peptide_charge, 
		modified_peptide_instance_search_batch_id, atlas_search_batch_id
    FROM $TBAT_PEPTIDE P
		JOIN $TBAT_PEPTIDE_INSTANCE PI ON P.peptide_id = PI.peptide_id
		JOIN $TBAT_MODIFIED_PEPTIDE_INSTANCE MPI ON PI.peptide_instance_id = MPI.peptide_instance_id
		JOIN $TBAT_MODIFIED_PEPTIDE_INSTANCE_SEARCH_BATCH MPIS ON MPI.modified_peptide_instance_id = MPIS.modified_peptide_instance_id
	  WHERE atlas_build_id = $args{build_id}
  ~;
#	print "$sql\n";

  my $sth = $sbeams->get_statement_handle( $sql );
  my %mapping;
  while( my @row = $sth->fetchrow_array() ) {
		my $mpi_key = $row[0] . '::::' . $row[1];
    $mapping{$mpi_key} ||= {};
    $mapping{$mpi_key}->{$row[3]} = $row[2];
  }
  return \%mapping;
}

sub cntObsFromIdentlist {

  my $self = shift;
	my %args = @_;

	for my $arg ( qw( identlist_file psb2asb ) ) {
		die "Missing required param $arg" unless defined $args{$arg};
	}

  open IDLIST, $args{identlist_file} || die "Unable to open $args{identlist_file}\n";

# col defs for PA Identlist file
# 0: search_batch_id
# 1: spectrum_query
# 2: peptide_accession
# 3: peptide_sequence
# 4: preceding_residue
# 5: modified_peptide_sequence
# 6: following_residue
# 7: charge
# 8: probability
# 9: massdiff
# 10: protein_name
# 11: adjusted_probability
# 12: n_adjusted_observations
# 13: n_sibling_peptides
# _________________________

  # hash of sample_id => peptide instance counts
  my %mappings;
  my $cnt = 0;
  while ( my $line = <IDLIST> ) {
    chomp $line;
    $cnt++;
    my @line = split( "\t", $line, -1 );
    if ($line[5] =~ /\(/){
      $line[5] =~ s/\([\d\.]+\)//g;
    }
    my $mpi_key = $line[5] . '::::' . $line[7];
    
		my $asb = $args{psb2asb}->{$line[0]};
		unless ( $asb ) {
			print STDERR "Unable to find atlas search batch for $line[0], skipping\n";
			next;
		}

    # Add on, can key off peptide seq (+ chg) or search_batches (original)
    if ( $args{key_type} && $args{key_type} eq 'peptide' ) {
      $mappings{$line[3]} ||= {}; 
      $mappings{$line[3]}->{$asb}++; 
      $mappings{$mpi_key} ||= {}; 
      $mappings{$mpi_key}->{$asb}++; 
    
		} else {
      $mappings{$asb} ||= {};
      $mappings{$asb}->{$line[3]}++;
      $mappings{$asb}->{$mpi_key}++;
		}
  }
  return \%mappings;
}


sub get_protein_build_coverage {
  my $self = shift;
  my %args = @_;
  for my $arg ( qw( build_id biosequence_ids ) ) {
    die "Missing required param $arg" unless defined $args{$arg};
  }

  # SQL defined peptides that have been observed for given bioseqs and build 
  my $sql =<<"  ENDSQL";
  SELECT 
  PM.matched_biosequence_id,
  PM.start_in_biosequence, 
  peptide_sequence,
  PI.n_observations,
  PM.peptide_preceding_residue
  FROM $TBAT_PEPTIDE_MAPPING PM
  JOIN $TBAT_PEPTIDE_INSTANCE PI ON PI.peptide_instance_id = PM.peptide_instance_id
  JOIN $TBAT_PEPTIDE P ON ( PI.peptide_id = P.peptide_id )
  JOIN $TBAT_ATLAS_BUILD AB ON ( PI.atlas_build_id = AB.atlas_build_id )
  WHERE AB.atlas_build_id = $args{build_id}
  AND PM.matched_biosequence_id IN ( $args{biosequence_ids} )
  --ORDER BY matched_biosequence_id
  ENDSQL
  my @rows = $sbeams->selectSeveralColumns( $sql );
  my %peps;
  foreach my $row(@rows) {
    $peps{$row->[1]}{$row->[2]}{$row->[0]}{nobs} = $row->[3];
    $peps{$row->[1]}{$row->[2]}{$row->[0]}{pre} = $row->[4];
  }
  return \%peps;
}


sub get_mapped_biosequences {
  my $self = shift;
	my %args = @_;
	for my $arg ( qw( build_id peptide_sequence ) ) {
		die "Missing required param $arg" unless defined $args{$arg};
	}

  my $sql =<<"  ENDSQL";
  SELECT distinct
  PM.matched_biosequence_id
  FROM $TBAT_PEPTIDE_MAPPING PM
  JOIN $TBAT_PEPTIDE_INSTANCE PI ON PI.peptide_instance_id = PM.peptide_instance_id
  JOIN $TBAT_PEPTIDE P ON ( PI.peptide_id = P.peptide_id )
  WHERE PI.atlas_build_id = $args{build_id}
  AND P.peptide_sequence = '$args{peptide_sequence}'
  ENDSQL
	$log->debug( $sql );

  my $sth = $sbeams->get_statement_handle( $sql );
	my @ids;
  while ( my @row = $sth->fetchrow_array() ) {
		push @ids, $row[0];
	}
  return \@ids;
}

sub getBioseqIDsFromProteinList {
	my $self = shift;
	my %args = @_;
	my $err = '';

	for my $arg ( qw( protein_list build_id ) ) {
		if ( !$args{$arg} ) {      
			my $msg = "Missing required param $arg\n";
			$err .= $msg;
		}
	}
	if ( $err ) {
		$log->error( $err );
		return undef;
	}

	my @names = split( /,/, $args{protein_list} );
	my $name_str = '';
	for my $name ( @names ) {
		$name_str .= ( $name_str ) ? ",'$name'" : "'$name'";
	}


	my $sql = qq~
	SELECT DISTINCT biosequence_id 
	FROM $TBAT_BIOSEQUENCE B 
	JOIN $TBAT_ATLAS_BUILD AB
	  ON AB.biosequence_set_id = B.biosequence_set_id
	WHERE biosequence_name IN ( $name_str )
	  AND atlas_build_id = $args{build_id}
	~;
	
	if ( $sbeams->isTaintedSQL( $sql ) ) {
		$log->error( "Tainted SQL passed: \n $sql" );
		$log->error( "protein list is $args{protein_list}" );
		return '';
	}

	
  my $sth = $sbeams->get_statement_handle( $sql );
	my $id_string;
	while ( my @row = $sth->fetchrow_array() ) {
		$id_string .= ( $id_string ) ? ",$row[0]" : $row[0];
	}
	return $id_string;
#	( list => $args{protein_list}, build_id => $curr_bid );
}


sub getBioseqNamesFromBioseqenceIDs {
	my $self = shift;
	my %args = @_;
	my $err = '';

	for my $arg ( qw( biosequence_ids ) ) {
		if ( !$args{$arg} ) {      
			my $msg = "Missing required param $arg\n";
			$err .= $msg;
		}
	}
	if ( $err ) {
		$log->error( $err );
		return undef;
	}

	my @ids = split( /,/, $args{biosequence_ids} );
	my $id_str = join(",", @ids);

	my $sql = qq~
	SELECT DISTINCT biosequence_name
	FROM $TBAT_BIOSEQUENCE B 
	JOIN $TBAT_ATLAS_BUILD AB
	  ON AB.biosequence_set_id = B.biosequence_set_id
	WHERE biosequence_id IN ( $id_str )
	~;
	
	if ( $sbeams->isTaintedSQL( $sql ) ) {
		$log->error( "Tainted SQL passed: \n $sql" );
		$log->error( "protein list is $args{protein_list}" );
		return '';
	}

	
  my $sth = $sbeams->get_statement_handle( $sql );
	my $name_string;
	while ( my @row = $sth->fetchrow_array() ) {
		$name_string .= ( $name_string ) ? ",$row[0]" : $row[0];
	}
	return $name_string;
}
###############################################################################
=head1 BUGS

Please send bug reports to SBEAMS-devel@lists.sourceforge.net

=head1 AUTHOR

Eric W. Deutsch (edeutsch@systemsbiology.org)

=head1 SEE ALSO

perl(1).

=cut
###############################################################################
1;

__END__
###############################################################################
###############################################################################
###############################################################################
