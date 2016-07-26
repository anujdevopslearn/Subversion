package SBEAMS::PeptideAtlas::ModelExport;

###############################################################################
#
# Class       : SBEAMS::PeptideAtlas::ModelExport
# Author      :
#
=head1 SBEAMS::PeptideAtlas::ModelExport

=head2 SYNOPSIS

  SBEAMS::PeptideAtlas::ModelExport

=head2 DESCRIPTION

 Module to facilitate export of PeptideAtlas data in a structured fashion,
 especially to external XML formats.

=cut
#
###############################################################################

use strict;
use Data::Dumper;
use POSIX qw(strftime);

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
require Exporter;
@ISA = qw();
$VERSION = q[$Id$];
@EXPORT_OK = qw();

use SBEAMS::Connection qw( $log );
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::Settings;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;
use SBEAMS::Proteomics::Tables;
use SBEAMS::Proteomics::AminoAcidModifications;


###############################################################################
# Global variables
###############################################################################
use vars qw($VERBOSE $TESTONLY $sbeams);
my $aamods = new SBEAMS::Proteomics::AminoAcidModifications;
my $mod_names = $aamods->get_modification_names();


#+
# Constructor
#-
sub new {
    my $class = shift;
    $class = ref($class) if ref($class);
    $sbeams = new SBEAMS::Connection;
    my $date = strftime "%Y-%m-%d", localtime;
    my $self = { sbeams => $sbeams,
                 date => $date,
                 @_ };
    bless $self, $class;
    return($self);
} # end new


sub getPASS {
  my $self = shift;
  my %args = @_;
  return '' unless $args{pass_id};

  my $sql = qq~
  SELECT * FROM $TBAT_PASS_DATASET
  WHERE datasetIdentifier = '$args{pass_id}'
  ~;
  my $pass_sth = $sbeams->getDBHandle()->prepare( $sql );
  $pass_sth->execute();
  print "$sql\n";
  while ( my $row = $pass_sth->fetchrow_hashref() ) {
    die Dumper( $row );
  }
}

#+
# Supports export of PeptideAtlas Samples, currently supports ddi and tsv format
#-
sub getSamples {
  my $self = shift;
  my %args = @_;
  my $where = "";
  my $xtra_join = '';
  my $release = 'Custom';
  my $species;
  if ( $args{sample_ids} ) {
    $where = ' WHERE S.sample_id IN ( ' . join( ',', @{$args{sample_ids}} ) . ')';
  } elsif ( $args{atlas_build_id} ) {
    die unless $args{atlas_build_id} =~ /^\d+$/;
    $where = " WHERE atlas_build_id = $args{atlas_build_id}";
    $xtra_join = "JOIN $TBAT_ATLAS_BUILD_SAMPLE ABS ON ABS.sample_id = S.sample_id\n";
    ($release) = $sbeams->getDBHandle()->selectrow_array( "SELECT atlas_build_name FROM $TBAT_ATLAS_BUILD WHERE atlas_build_id = $args{atlas_build_id}" );
    $species = get_species( $args{atlas_build_id} );
  } elsif ( $args{sample_tag} ) {
    $where = " WHERE S.sample_tag = '$args{sample_tag}}' ";
  } elsif ( $args{sample_tag_like} ) {
    $where = " WHERE S.sample_tag LIKE '$args{sample_tag_like}}' ";
  }
  my $sql = qq~
  SELECT
  S.sample_id,
  project_tag,
  sample_accession,
  O.common_name,
  O.species,
  O.genus,
  sample_title ,
  sample_tag   ,
  original_experiment_tag ,
  sample_date   ,
  sample_description ,
  instrument_name,
  --search_batch_id
  sample_publication_ids,
  data_contributors,
  primary_contact_email,
  -- anatomical_site_term
  --  developmental_stage_term
  --  pathology_term
  --  cell_type_term
  S.comment,
  -- date_created
  --    created_by_id
  -- date_modified
  --  modified_by_id
  -- owner_group_id
  -- record_status
  --peptide_source_type
  S.protease_id as protease,
  --  fragmentation_type_ids
  -- sample_category_id
  SC.name AS sample_category_name,
  repository_identifiers,
  -- labeling
  -- fractionation
  -- sample_preparation
  --  enrichment
  --  concentration_purification_desalting
  -- caloha
  --cellosaurus
  -- NCI_Thesaurus
  S.tissue_cell_type,
  S.cell_line,
  S.disease,
  -- biological_conditions
  -- treatment_physiological_state
  O2.common_name eo_common_name,
  O2.species eo_species,
  O2.genus eo_genus,
  O.ncbi_taxonomy_id,
  is_public,
  S.project_id

  FROM $TBAT_SAMPLE S
  JOIN $TB_PROJECT P on P.project_id = S.project_id
  LEFT JOIN $TB_ORGANISM O on O.organism_id = S.organism_id
  LEFT JOIN $TBPR_INSTRUMENT I ON I.instrument_id = S.instrument_model_id
  LEFT JOIN $TBAT_SAMPLE_CATEGORY SC ON SC.id = S.sample_category_id
  LEFT JOIN $TBPR_PROTEOMICS_EXPERIMENT EXP on EXP.experiment_tag = S.original_experiment_tag
  LEFT JOIN $TB_ORGANISM O2 ON EXP.organism_id = O2.organism_id
  $xtra_join
  $where
  ORDER BY sample_id DESC
  ~;
  my $sth = $sbeams->get_statement_handle( $sql );
  my @samples;
  if ( $args{public_check} ) {
    if ( ! -e "public_mismatch.tsv" ) {
      open PUB, ">public_mismatch.tsv";
      print PUB join( "\t", qw( AtlasBuild SampleID SampleAccession SampleTag isPublic PublicProject ) ) . "\n";
    } else {
      open PUB, ">>public_mismatch.tsv";
    }
  }

  my $accessible = $sbeams->getAccessibleProjects( as_guest => 1, 
                                                   wg_module => 'PeptideAtlas',
                                                   as_hashref => 1 );

  while ( my $row = $sth->fetchrow_hashref() ) {
    push @samples, $row;
    next if !$args{public_check};
    if ( !$row->{is_public} || $row->{is_public} eq 'N' ) {
      my $project_public = ( $accessible->{$row->{project_id}} ) ? 'Y' : 'N';
      print PUB join( "\t", $args{atlas_build_id}, $row->{sample_id}, $row->{sample_accession}, $row->{sample_tag}, 'N', $project_public ) . "\n";
    } elsif ( !$accessible->{$row->{project_id}} ) {
      print PUB join( "\t", $args{atlas_build_id}, $row->{sample_id}, $row->{sample_accession}, $row->{sample_tag}, 'Y', 'N' ) . "\n";
    }
  }
  close PUB if $args{public_check};

  my $sample_mods = $self->get_sample_mods( samples => \@samples, build_id => $args{atlas_build_id}  );
  my $sample_prots = $self->get_sample_proteins( samples => \@samples, build_id => $args{atlas_build_id}  );

  $args{format} ||= 'TSV';
  if ( $args{format} =~ /DDI/i ) {
    return $self->getDDISampleXML( samples => \@samples, release => $release, mods => $sample_mods, species => $species, prots => $sample_prots );
  } else {
    my $out = $self->getTSV( samples => \@samples );
    return $out;
  }
  return 1;
}

sub get_sample_mods {
  my $self = shift;
  my %args = @_;
  my %sample2mods;
  return \%sample2mods unless defined $args{samples} && defined $args{build_id};

  my %mods;
  my %unknown_mods;
  open MODS, "/net/dblocal/www/html/devDC/sbeams/lib/scripts/PeptideAtlas/mods/" . $args{build_id} . "_mods.tsv";
  while ( my $mods = <MODS> ) {
    chomp $mods;
    my @mods = split( /\t/, $mods );
    $mods{$mods[1]} ||= {};
    $mods{$mods[1]}->{$mods[2]} += $mods[3];
    $unknown_mods{$mods[2]}++ unless $mod_names->{$mods[2]};
  }


  my $dbh = $sbeams->getDBHandle();
  my $sb_sth = $dbh->prepare( "SELECT DISTINCT atlas_search_batch_id FROM $TBAT_ATLAS_BUILD_SEARCH_BATCH WHERE atlas_build_id = $args{build_id} AND sample_id = ?" );
  for my $s ( @{$args{samples}} ) {
    my $sid = $s->{sample_id} || die;
    $sb_sth->execute( $sid );
    my @sbids;
    while ( my @row = $sb_sth->fetchrow_array() ) {
      $sample2mods{$sid} ||= {};
      if ( $mods{$row[0]} ) {
        for my $obsmod ( keys( $mods{$row[0]} ) ) {
          my $name = $mod_names->{$obsmod} || 'Unknown';
          $sample2mods{$sid}->{$name} += $mods{$row[0]}->{$obsmod};
        }
      }
    }
  }
#  die Dumper( sort(keys(%unknown_mods)) );

  return \%sample2mods;

}

sub get_species {
  my $build_id = shift || die;
  my $sql = qq~
  SELECT genus,species, common_name
  FROM $TBAT_ATLAS_BUILD AB
  JOIN $TBAT_BIOSEQUENCE_SET BSS
    ON BSS.biosequence_set_id = AB.biosequence_set_id
  JOIN $TB_ORGANISM O
    ON BSS.organism_id = O.organism_id
  WHERE atlas_build_id = $build_id
  ~;
  my @name_info = $sbeams->getDBHandle()->selectrow_array( $sql );
  my $species = join( " ", ucfirst($name_info[0]), lc($name_info[1]) );
  $species ||= $name_info[2];
  return $species;
}
sub writeTSV {
  return 'Not yet implemented';
}

sub getTSV {
  my $self = shift;
  my %args = @_;
  return '' unless $args{samples};

  my @headings;
  my $out;
  for my $sample ( @{$args{samples}} ) {
    if ( !@headings ) {
      @headings = keys( %{$sample} );
      $out = join( "\t", @headings ) . "\n";
    }
    my $sep = '';
    for my $head ( @headings ) {
      $out .= $sep . $sample->{$head};
      $sep = "\t";
    }
    $out .= "\n";
  }
  return $out;
}

sub getDDISampleXML {
  my $self = shift;
  my %args = @_;
  return '' unless $args{samples};
  my $species = $args{species};

  $args{release} ||= 'Custom';

  my $cnt = scalar( @{$args{samples}} );

  my %src_db = ( SwissProt => 'UniProt',
                 ENSP_Hs   => 'Ensembl',
                 UniProt_CMP => 'UniProt',
                 UniProt_Other => 'UniProt',
                 NCBIProt => 'NCBI'
               );

#  <?xml version="1.0"?>
  my $xml = '<?xml version="1.0" encoding="ISO-8859-1"?>';
  $xml .= qq~
  <database>
   <name>$args{release} PeptideAtlas</name>
   <description>$species data from the PeptideAtlas knowledge base</description>
   <release>$args{release}</release>
   <release_date>$self->{date}</release_date>
   <entry_count>$cnt</entry_count>
    <entries>
  ~;

  for my $sample ( @{$args{samples}} ) {

    # Sanitize
    my @additional;
    for my $field ( keys( %{$sample} ) ) {
      $sample->{$field} = escape( $sample->{$field} );
      next if $field =~ /sample_id|sample_tag|sample_description|repository_identifiers|sample_publication_ids/;
      push @additional, $field;
    }

    my @repos;
    my $xref_tag = " <cross_references>\n";

    if ( $sample->{repository_identifiers} ) {
      $sample->{repository_identifiers} =~ s/\s//g;
      @repos = split( /,/, $sample->{repository_identifiers} );
    }

    # Publications are possibly a one-to-many proposition
    my $primary_publication = '';
    my $primary_publication_date = '';
    my @pmids;
    if ( $sample->{sample_publication_ids} ) {
      $self->{pub_sth} = $sbeams->getDBHandle()->prepare( "SELECT pubmed_id, publication_name, published_year FROM $TBAT_PUBLICATION WHERE publication_id = ?" );
      for my $id ( split( /,/, $sample->{sample_publication_ids} ) ) {
        $id =~ s/\s//g;
        next unless $id =~ /^\d+$/;
        $self->{pub_sth}->execute( $id );
        while ( my $row = $self->{pub_sth}->fetchrow_arrayref() ) {
          $primary_publication ||= escape( $row->[1] );
          $primary_publication_date ||= escape( $row->[2] );
          push @pmids, $row->[0];
        }
      }
    }
    if ( $primary_publication ) {
      $sample->{publication} = $primary_publication;
      push @additional, $primary_publication;
    }
    my $pub_date = '';
    if ( $primary_publication_date ) {
      if ( $primary_publication_date =~ /^\d\d\d\d$/ ) {
         $pub_date = "<date type='publication' value='$primary_publication_date-12-31'/>";
      }
    }

    # Defaults
    $sample->{sample_accession} ||= $sample->{sample_id};
    $sample->{sample_tag} ||= $sample->{accession};
    $sample->{sample_description} ||= $sample->{comment};
    $sample->{sample_description} ||= $sample->{sample_tag};

    $xml .= qq~
     <entry id="$sample->{sample_accession}">
      <keywords>proteomics, mass spectrometry</keywords>
      <authors/>
      <dates>
       <date type="export" value="2016-03-29"/>
       $pub_date
      </dates>
      <name>$sample->{sample_tag}</name>
      <description>$sample->{sample_description}</description>
      $xref_tag
    ~;

    for my $repos ( @repos ) {
      my $name = ( $repos =~ /^PASS/ ) ? 'PASS' :
                 ( $repos =~ /^PXD/ ) ? 'ProteomExchange' : 
                 ( $repos =~ /^RPXD/ ) ? 'ProteomExchange' : 'Unknown';

      $xml .= '  <ref dbkey="' . $repos . '" dbname="' . $name . '" />' . "\n";
    }
    for my $id ( @pmids ) {
      $xml .= '      <ref dbkey="' . $id . '" dbname="pubmed" />' . "\n";
    }

    $xml .= "      <ref dbkey='$sample->{ncbi_taxonomy_id}' dbname='taxonomy'/>\n" if $sample->{ncbi_taxonomy_id};

    if ( $args{prots} && $args{prots}->{$sample->{sample_id}} ) {
      my $smp_prots = $args{prots}->{$sample->{sample_id}};
      for my $prot ( sort( keys( %{$smp_prots} ) ) ) {
        my $src_db = $src_db{$smp_prots->{$prot}} || $smp_prots->{$prot};
        $xml .= qq~      <ref dbkey="$prot" dbname="$src_db"/>\n~;
      }
    }

    $xml .= "      </cross_references>\n" if $xref_tag;

    if ( $args{mods} && $args{mods}->{$sample->{sample_id}} ) {
      $xml .= "      <modifications>\n";
      for my $mod ( sort( keys( $args{mods}->{$sample->{sample_id}} ) ) ) {
        $xml .= "       <field name='modification'>$mod</field>\n";
      }
      $xml .= "      </modifications>\n";
    }

    $xml .= "      <additional_fields>\n";
    my %additional_fields = ( repository => 'Peptide Atlas',
                              omics_type =>	'Proteomics',
                              'software' =>	'TPP' );
    if ( $sample->{genus} && $sample->{species} ) {
      $additional_fields{species} = "$sample->{genus} $sample->{species} ($sample->{common_name})";
    } else {
      $additional_fields{species} = $sample->{common_name};
    }


    if ( !$additional_fields{species} ) {
      if ( 0 && $sample->{eo_genus} && $sample->{eo_species} ) {
        $additional_fields{species} = "$sample->{genus} $sample->{species} ($sample->{common_name})";
      } elsif ( 0 && $sample->{eo_common_name} ) {
        $additional_fields{species} = $sample->{eo_common_name};
      } else {
        $additional_fields{species} ||= $args{species};
        $additional_fields{species} ||= 'Unknown';
      }
    }

    if ( $sample->{tissue_cell_type} ) {
      $additional_fields{tissue} = $sample->{tissue_cell_type};
    } elsif ( $sample->{sample_category_name} ) {
      $additional_fields{tissue} = $sample->{sample_category_name};
    } else {
      $additional_fields{tissue} = undef;
    }

    if ( $sample->{cell_line} ) {
      $additional_fields{cell_type} = $sample->{cell_line};
#    } elsif ( $sample->{tissue_cell_type} ) {
#      $additional_fields{cell_type} = $sample->{tissue_cell_type};
    } else {
      $additional_fields{cell_type} = undef;
    }

    my %translate = ( submitter => 'data_contributors',
                        disease => 'disease',
                 submitter_email => 'primary_contact_email',
             instrument_platform => 'instrument_name',
                    project_tag => 'project_name',
                sample_protocol => 'sample_preparation' );

    for my $key ( keys( %translate )  ) {
      $additional_fields{$key} = $sample->{$translate{$key}} || '';
    }
    $additional_fields{instrument_platform} ||= 'Unknown';
    $additional_fields{instrument_platform} = 'Unknown' if $additional_fields{instrument_platform} eq 'UNKNOWN';

    for my $field ( sort( keys( %additional_fields ) ) ) {
      $xml .= '       <field name="' . $field . '"' . ">$additional_fields{$field}</field>\n" if defined $additional_fields{$field};

    }
    $xml .= "<field name='full_dataset_link'>'https://db.systemsbiology.net/sbeams/cgi/PeptideAtlas/ManageTable.cgi?TABLE_NAME=AT_sample&amp;sample_id=$sample->{sample_id}'</field>";

    # These are 'required' by ddi validator
    $xml .= qq~
    <field name="data_protocol" />
    <field name="pubmed" />
    <field name="submitter_email" />
    <field name="synonyms" />
    <field name="publication"></field>
    ~;
    $xml .= "      </additional_fields>\n";




    $xml .= "   </entry>\n";
  }
  $xml .= "</entries>\n";
  $xml .= "</database>\n";
  return $xml;

}
sub escape {
  my $field = shift || return '';
  $field =~ s/\&/&amp;/gm;
  $field =~ s/\</&lt;g/gm;
  $field =~ s/\>/&gt;/gm;
  $field =~ s/"/&quot;/gm;
  $field =~ s/'/&apos;/gm;
  return $field;
}

# Read from XML source. Requires source file and model type
# Read from TSV source. Requires source file and model type
sub readTSV {
  my $self = shift;
  my %args = @_;
}

# Read from XML source. Requires source file and model type
sub readXML {
  my $self = shift;
  my %args = @_;
}

# Read from database source - useful?
# Requires database connection, table info and/or query
sub readTable {
  my $self = shift;
  my %args = @_;
}

# Write to TSV. Requires destination file, model type, and data source
sub writeTSV {
  my $self = shift;
  my %args = @_;
}

# Write to XML. Requires destination file, model type, and data source
sub writeXML {
  my $self = shift;
  my %args = @_;
}



# Return a TSV formatted model description for any supported types.
# Requires Type
sub getModel {
  my $self = shift;
  my %args = @_;
}

# Given data source, determine type.  Useful?
sub determineType {
  my $self = shift;
  my %args = @_;
}

# Validators
sub isValidSampleData {
  my $self = shift;
  my %args = @_;
}

sub isValidBD2K {
  my $self = shift;
  my %args = @_;
}

sub isValidPASSData {
  my $self = shift;
  my %args = @_;
}

sub isValidPASSELData {
  my $self = shift;
  my %args = @_;
}

# Conversions to/from known formats
sub Sample2PASS {
  my $self = shift;
  my %args = @_;
}

sub PASS2Sample {
  my $self = shift;
  my %args = @_;
}

sub get_sample_proteins {
  my $self = shift;
  my %args = @_;
  my %sample2prots;
  return \%sample2prots unless defined $args{samples} && defined $args{build_id};

  my %prots;

  my $dbh = $sbeams->getDBHandle();
  my $sql = qq~
  SELECT DISTINCT PIS.sample_id, biosequence_accession,
       CASE WHEN dbxref_tag IS NULL THEN 'Unknown' ELSE dbxref_tag END AS dbxref_tag
  FROM $TBAT_PEPTIDE P
  JOIN $TBAT_PEPTIDE_INSTANCE PIN
    ON P.peptide_id = PIN.peptide_id
  JOIN $TBAT_ATLAS_BUILD AB
    ON AB.atlas_build_id = PIN.atlas_build_id
  JOIN $TBAT_PEPTIDE_INSTANCE_SAMPLE PIS
    ON PIS.peptide_instance_id = PIN.peptide_instance_id
  JOIN $TBAT_PEPTIDE_MAPPING PM
    ON PM.peptide_instance_id = PIN.peptide_instance_id
  JOIN $TBAT_BIOSEQUENCE B
    ON B.biosequence_id = PM.matched_biosequence_id
  JOIN $TBAT_BIOSEQUENCE_SET BS
    ON BS.biosequence_set_id = B.biosequence_set_id
  JOIN $TBAT_PROTEIN_IDENTIFICATION PID
    ON ( PID.biosequence_id = B.biosequence_id AND PID.atlas_build_id = AB.atlas_build_id )
  JOIN $TBAT_DBXREF DBX ON DBX.dbxref_id = B.dbxref_id
  WHERE AB.atlas_build_id = $args{build_id}
    AND presence_level_id = 1
  ~;
#    AND PIS.sample_id = ?
  my $psth = $sbeams->get_statement_handle( $sql );
  while ( my @row = $psth->fetchrow_array() ) {
    $sample2prots{$row[0]} ||= {};
    $sample2prots{$row[0]}->{$row[1]} = $row[2];
  }
  return \%sample2prots;

  # deprecated sth-prepare-exec with each sample
  my $sth = $dbh->prepare( $sql );
  for my $s ( @{$args{samples}} ) {
    my $sid = $s->{sample_id} || die;
    $sth->execute( $sid );
    $sample2prots{$sid} ||= {};
    while ( my @row = $sth->fetchrow_array() ) {
      $sample2prots{$sid}->{$row[0]} = $row[1];
    }
  }

  return \%sample2prots;
}




=head2 DESCRIPTION

#+
# Routine to fetch accession number for a peptide sequence
#-
sub getPeptideAccession {
  my $self = shift;
  my %args = @_;

  return unless $args{seq} && $self->isValidSeq( seq => $args{seq} );
  $sbeams = $self->getSBEAMS();

  my $sql =<<"  END";
    SELECT peptide_accession
    FROM $TBAT_PEPTIDE
    WHERE peptide_sequence = '$args{seq}'
  END

  if( $args{no_cache} ) {
    my ($acc) = $sbeams->selectrow_arrayref( $sql );
    return $acc;
  }

  # Already cached info?
  if ( !$self->{_pa_acc_list} ) {
    $self->cacheAccList();
  }

  # current seq not found, try to lookup.
  unless( $self->{_pa_acc_list}->{$args{seq}} ) {
    ( $self->{_pa_acc_list}->{$args{seq}} ) = $sbeams->selectrow_arrayref($sql);
  }

  # Might be null, but we tried!
  return $self->{_pa_acc_list}->{$args{seq}}

} # End getPeptideAccession


sub getPeptideId {
  my $self = shift;
  my %args = @_;

  return unless $args{seq} && $self->isValidSeq( seq => $args{seq} );
  $sbeams = $self->getSBEAMS();

  my $sql =<<"  END";
    SELECT peptide_id
    FROM $TBAT_PEPTIDE
    WHERE peptide_sequence = '$args{seq}'
  END

  if( $args{no_cache} ) {
    my ($id) = $sbeams->selectrow_arrayref( $sql );
    return $id;
  }

  # Already cached info?
  if ( !$self->{_pa_id_list} ) {
    $self->cacheIdList();
  }

  # current seq not found, try to lookup.
  unless( $self->{_pa_id_list}->{$args{seq}} ) {
    ( $self->{_pa_id_list}->{$args{seq}} ) = $sbeams->selectrow_arrayref($sql);
  }

  # Might be null, but we tried!
  return $self->{_pa_id_list}->{$args{seq}}
}

#+
# Routine fetches peptide_id, accession, and instance_id for a passed
# set of peptide sequences.
#-
sub getPeptideList {
  my $self = shift;
  my %args = @_;

  return unless $args{sequence_ref};
  $sbeams = $self->getSBEAMS();

  my @peptides;
  for my $pep ( @{$args{sequence_ref}} ) {
    push @peptides, "'" . $pep . "'" if isValidSeq( seq => $pep );
  }

  my @results;
  return \@results unless @peptides;

  $log->warn( "Large seq list in getPeptideList: " . scalar( @peptides) );

  my $in_clause = '(' . join( ", ", @peptides ) . ')';

  my $sql;
  if ( $args{build_id} ) {
    my $sql =<<"    END";
      SELECT peptide_id, peptide_accession, peptide_instance_id
      FROM $TBAT_PEPTIDE P
      LEFT JOIN  $TBAT_PEPTIDE_INSTANCE PI ON P.peptide_id = PI.peptide_id
      WHERE peptide_sequence IN ( $in_clause )
      AND atlas_build_id = $args{build_id}
    END
  } else {
    my $sql =<<"    END";
      SELECT peptide_id, peptide_accession, ''
      FROM $TBAT_PEPTIDE P
      WHERE peptide_sequence IN ( $in_clause )
    END
  }

  my $sth = $sbeams->get_statement_handle( $sql );
  while ( my $row = $sth->fetchrow_arrayref() ) {
    push @results, $row;
  }
  return \@results;

}



#+
# Routine to fetch and return entries from the peptide table
#-
sub cacheAccList {
  my $self = shift;
  my %args = @_;

  return if $self->{_pa_acc_list} && !$args{refresh};

  my $sql = <<"  END";
  SELECT peptide_sequence, peptide_accession
  FROM $TBAT_PEPTIDE
  END
  my $sth = $sbeams->get_statement_handle( $sql );
  $sth->execute();

  my %accessions;
  while ( my @row = $sth->fetchrow_array() ) {
    $accessions{$row[0]} = $row[1];
  }
  $self->{_pa_acc_list} = \%accessions;
} # end get_accessions


#+
# Routine to fetch and return entries from the peptide table
#-
sub cacheIdList {
  my $self = shift;
  my %args = @_;

  return if $self->{_pa_id_list} && !$args{refresh};

  my $sql = <<"  END";
  SELECT peptide_sequence, peptide_id
  FROM $TBAT_PEPTIDE
  END
  my $sth = $sbeams->get_statement_handle( $sql );
  $sth->execute();

  my %ids;
  while ( my @row = $sth->fetchrow_array() ) {
    $ids{$row[0]} = $row[1];
  }
  $self->{_pa_id_list} = \%ids;
}

sub updateIdCache {
  my $self = shift;
  my %args = @_;
}


#+
# Routine to add new peptide to the atlas.  This is comprised of two steps,
# which by default are wrapped in a transaction to make them atomic.
#
# @narg make_atomic   Should inserts be wrapped in transaction? default = 1
# @narg sequence      Peptide sequence to be added [required]
#
#-
sub addNewPeptide {
  my $self = shift;
  my %args = @_;

  # return if no sequence specified
  return unless $args{seq} && $self->isValidSeq( seq => $args{seq} );

  if ( $self->getPeptideId( seq => $args{seq} ) ) {
    # Should we do more here, i.e. update cache?
    $log->warn( "addNewPeptide called on existing sequence: $args{seq}" );
#    return 0;
  }

  $sbeams = $self->getSBEAMS();

  # fetch and cache identity list if not already done
  unless ( $self->{_apd_id_list} ) {
    $self->cacheIdentityList();
  }

  unless ( $self->{_apd_id_list}->{$args{seq}} ) {
    $self->addAPDIdentity( %args ); # Pass through seq and make_atomic args.
  }

  return unless $self->{_apd_id_list}->{$args{seq}};

  # We have an APD ID, and peptide is not otherwise in the database.  Calculate
  # peptide attributes and insert


  $self->{_massCalc} ||= new SBEAMS::Proteomics::PeptideMassCalculator;
  $self->{_ssrCalc} ||= $self->getSSRCalculator();

  my $mw =  $self->{_massCalc}->getPeptideMass( mass_type => 'monoisotopic',
                                                  sequence => $args{seq} );

  my $pI = $self->calculatePeptidePI( sequence => $args{seq} );

  my $ssr;
  if ($self->{_ssrCalc}->checkSequence($args{seq})) {
    $ssr = $self->{_ssrCalc}->TSUM3($args{seq});
  }

  my $rowdata_ref = {};

  $rowdata_ref->{molecular_weight} = $mw;
  $rowdata_ref->{peptide_isoelectric_point} = $pI;
  $rowdata_ref->{SSRCalc_relative_hydrophobicity} = $ssr;
  $rowdata_ref->{peptide_sequence} = $args{seq};
  $rowdata_ref->{peptide_length} = length( $args{seq} );
  $rowdata_ref->{peptide_accession} = $self->{_apd_id_list}->{$args{seq}};

  my $peptide_id = $sbeams->updateOrInsertRow(
    insert      => 1,
    table_name  => $TBAT_PEPTIDE,
    rowdata_ref => $rowdata_ref,
    PK          => 'peptide_id',
    return_PK   => 1,
    verbose     => $VERBOSE,
    testonly    => $args{testonly} );

  return $peptide_id;

}

sub calc_SSR {
  my $self = shift;
  my %args = @_;
  return unless $args{seq};
  my $ssr;
  if ($self->{_ssrCalc}->checkSequence($args{seq})) {
    $ssr = $self->{_ssrCalc}->TSUM3($args{seq});
  }
  return $ssr;
}

sub getSSRCalculator {
  my $self = shift;

  # Create and initialize SSRCalc object with 3.0
  my $ssr = $self->getSSRCalcDir();

  $ENV{SSRCalc} = $ssr;

  use lib '/net/db/src/SSRCalc/ssrcalc';
  use SSRCalculator;

  my $calculator = new SSRCalculator();
  $calculator->initializeGlobals3();
  $calculator->ReadParmFile3();
  return $calculator;
}

# Routine to calculate average ECS (Eisenberg consensus scale) hydrophobicity
sub calc_ECS {
  my $self = shift;
  my %args = @_;
  return unless $args{seq};

  $self->{ecs} ||= getECSVals();


  my @aa = split( '', $args{seq} );
  my $cnt = 0;
  my $sum = 0;
  for my $aa ( @aa ) {
    next unless $aa =~ /[A-Z]/;

    $cnt++;
    my $aa_hyd = $self->{ecs}->{$aa};

    if ( !defined $aa_hyd ) {
      $log->warn( "Undefined value for $aa in ECS index" );
      next;
    }
    $sum += $aa_hyd;
  }
  if ( !$cnt ) {
    return 0;
  } else {
    return sprintf( "%0.2f", $sum/$cnt);
  }
}


sub getECSVals {
  my %ecs = ( F => 1.19,
              S => -0.18,
              T => -0.05,
              N => -0.78,
              K => -1.5,
              Y => 0.26,
              E => -0.74,
              V => 1.08,
              Q => -0.85,
              M => 0.64,
              C => 0.29,
              L => 1.06,
              A => 0.62,
              W => 0.81,
              P => 0.12,
              H => -0.4,
              D => -0.9,
              I => 1.38,
              R => -2.53,
              G => 0.48 );
  return \%ecs;
}


sub addAPDIdentity {
  my $self = shift;
  my %args = @_;

  # return if no sequence specified
  return unless $args{seq} && $self->isValidSeq( seq => $args{seq} );

  # Make atomic if not already handled by calling code
  $args{make_atomic} = 1 if !defined $args{make_atomic};

  $sbeams = $self->getSBEAMS();

  unless ( $self->{_apd_id_list} ) {
    $self->cacheIdentityList();
  }

  # log and return if it is already there
  if ( $self->{_apd_id_list}->{$args{seq}} ) {
    $log->warn("Tried to add APD identity for seq $args{seq}, already exists");
    return;
  }

  my $rowdata = {};
  $rowdata->{peptide} = $args{seq};
  $rowdata->{peptide_identifier_str} = 'tmp';

  # Do the next two statements as a transaction
  $sbeams->initiate_transaction() if $args{make_atomic};

  #### Insert the data into the database
  my $apd_id = $sbeams->updateOrInsertRow(
    table_name => $TBAPD_PEPTIDE_IDENTIFIER,
        insert => 1,
   rowdata_ref => $rowdata,
            PK => "peptide_identifier_id",
     return_PK => 1,
       verbose => $VERBOSE,
    testonly   => $args{testonly} );

  unless ($apd_id ) {
    $log->error( "Unable to insert APD_identity for $args{seq}" );
    return;
  }

  if ( $apd_id > 99999999 ) {
    $log->error( "key length too long for current Atlas accession template!" );
    die " Unable to insert APD accession";
  }

  $rowdata->{peptide_identifier_str} = 'PAp' . sprintf( "%08s", $apd_id );

  #### UPDATE the record
  my $result = $sbeams->updateOrInsertRow(
    table_name => $TBAPD_PEPTIDE_IDENTIFIER,
        update => 1,
   rowdata_ref => $rowdata,
            PK => "peptide_identifier_id",
      PK_value => $apd_id ,
     return_PK => 1,
       verbose => $VERBOSE,
      testonly => $args{testonly} );

  #### Commit the INSERT+UPDATE pair
  $sbeams->commit_transaction() if $args{make_atomic};

  #### Put this new one in the hash for the next lookup
  $self->{_apd_id_list}->{$args{seq}} = $apd_id;

} # end addAPDIdentity



#+
# Routine to fetch and return entries from the APD protein_identity table
#-
sub cacheIdentityList {
  my $self = shift;
  my %args = @_;

  $self->{_apd_id_list} = { GSYGSGGSSYGSGGGSYGSGGGGGGHGSYGSGSSSGGYR => 'PAp00000038' };

  if ( $self->{_apd_id_list} && !$args{refresh} ) {
    return;
  }
  $sbeams = $self->getSBEAMS();

  my $sql = <<"  END";
  SELECT peptide, peptide_identifier_str, peptide_identifier_id
  FROM $TBAPD_PEPTIDE_IDENTIFIER
  END

  my $sth = $sbeams->get_statement_handle( $sql );

  my %accessions;
  while ( my @row = $sth->fetchrow_array() ) {
    $accessions{$row[0]} = $row[1];
  }
  $self->{_apd_id_list} = \%accessions;

} # end getIdentityList


sub _addPeptideIdentity {
  my $self = shift;
}

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
# setTESTONLY: Set the current test mode
###############################################################################
sub setTESTONLY {
    my $self = shift;
    $TESTONLY = shift;
    return($TESTONLY);
} # end setTESTONLY



###############################################################################
# setVERBOSE: Set the verbosity level
###############################################################################
sub setVERBOSE {
    my $self = shift;
    $VERBOSE = shift;
    return($VERBOSE);
} # end setVERBOSE


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
#
# passel_model.tsv
# 0    SEL_experiment_id [ 4 ]
# 1    sample_id [ 3128 ]
# 2    data_path [ /regis/sbeams/archive/ukusebauch/SRM/T47D_kinase_ataqs ]
# 3    comment [ 50 peptides from 32 kinases were measured, with heavy peptides spiked in at three concentrations. Three replicates. ]
# 10   experiment_title [ ATAQS T-47D cell line ]
# 11   project_id [ 475 ]
# 12   mprophet_analysis [ Y ]
# 13   heavy_label [ yes ]
# 14   datasetIdentifier [ PASS00011 ]
# 17   PX_identifier [ PXD000845 ]
# 4    date_created [ 2011-06-02 18:42:46.537 ]
# 5    created_by_id [ 667 ]
# 6    date_modified [ 2014-03-17 13:09:34.497 ]
# 7    modified_by_id [ 668 ]
# 8    owner_group_id [ 40 ]
# 9    record_status [ N ]
# 15   q1_tolerance [ 0.007 ]
# 16   q3_tolerance [ 0.007 ]

# pass_model.tsv
# 0    dataset_id [ 2 ]
# 1    submitter_id [ 1 ]
# 2    datasetIdentifier [ PASS00002 ]
# 3    datasetType [ MSMS ]
# 4    datasetPassword [ WP4844d ]
# 5    datasetTag [ raftapr2 ]
# 6    datasetTitle [ Jurkat T-cell lipid rafts stim & unstim ICAT labeled Replicate 1 ]
# 7    publicReleaseDate [ 2013-12-30 00:00:00.0 ]
# 8    finalizedDate [ 2012-10-24 21:55:58.587 ]
# 9    comment [  ]
# 16   lab_head_full_name [  ]
# 17   lab_head_email [  ]
# 18   lab_head_organization [  ]
# 19   lab_head_country [  ]
# 20   submitter_organization [  ]
# 10   date_created [ 2011-09-15 23:59:14.163 ]
# 11   created_by_id [ 107 ]
# 12   date_modified [ 2011-09-15 23:59:14.163 ]
# 13   modified_by_id [ 107 ]
# 14   owner_group_id [ 22 ]
# 15   record_status [ N ]

# sample_model.tsv
# 0    sample_id [ 2 ]
# 1    project_id [ 476 ]
# 2    sample_accession [ PAe000001 ]
# 3    organism_id [  ]
# 4    sample_title [ test2 TARVOS ]
# 5    sample_tag [ test2 ]
# 6    original_experiment_tag [  ]
# 7    sample_date [ 2003-12-09 22:10:52.0 ]
# 8    sample_description [ using this record as place holder for old search of mwright's nuclear3 ]
# 9    instrument_model_id [ 12 ]
# 10   search_batch_id [  ]
# 11   sample_publication_ids [  ]
# 12   data_contributors [ Serikawa KA, Xu XL, MacKay VL, Law GL, Zong Q, Zhao LP, Bumgarner R, Morris DR. ]
# 13   primary_contact_email [  ]
# 14   is_public [ N ]
# 15   anatomical_site_term [  ]
# 16   developmental_stage_term [  ]
# 17   pathology_term [  ]
# 18   cell_type_term [  ]
# 19   comment [  ]
# 26   peptide_source_type [ Natural ]
# 27   protease_id [  ]
# 28   fragmentation_type_ids [  ]
# 29   sample_category_id [  ]
# 30   repository_identifiers [  ]
# 31   labeling [  ]
# 32   fractionation [  ]
# 33   sample_preparation [  ]
# 34   enrichment [  ]
# 35   concentration_purification_desalting [  ]
# 36   caloha [  ]
# 37   cellosaurus [  ]
# 38   NCI_Thesaurus [  ]
# 39   tissue_cell_type [  ]
# 40   cell_line [  ]
# 41   disease [  ]
# 42   biological_conditions [  ]
# 43   treatment_physiological_state [  ]
# 20   date_created [ 2003-12-09 22:00:22.44 ]
# 21   created_by_id [ 2 ]
# 22   date_modified [ 2003-12-09 22:12:58.693 ]
# 23   modified_by_id [ 2 ]
# 24   owner_group_id [ 40 ]
# 25   record_status [ D ]
#
# #  BD2K-DDI schema example 1
# <database>
#   <name>PRIDE Archive</name>
#   <description/>
#   <release>3</release>
#   <release_date>2015-03-17</release_date>
#   <entry_count>1</entry_count>
#   <entries>
#     <entry id="PXD001810">
#       <name>PXD001810</name>
#       <description>SUMO-2 Orchestrates Chromatin Modifiers in Response to DNA Damage</description>
#       <cross_references>
#         <ref dbkey="9606" dbname="TAXONOMY"/>
#         <ref dbkey="25772364" dbname="pubmed"/>
#       </cross_references>
#       <dates>
#         <date type="submission" value="2015-02-12"/>
#         <date type="publication" value="2015-03-16"/>
#       </dates>
#       <additional_fields>
#         <field name="project_tag">Biological</field>
#         <field name="tissue">HeLa cell</field>
#         <field name="instrument">LTQ Orbitrap Velos</field>
#         <field name="instrument">Q Exactive</field>
#         <field name="sample_processing_protocol">Protein-data: Stable expression of FLAG-tagged SUMO-2 wild-type in HeLa cells, light/heavy (Exp1) and light/medium/heavy (Exp2) SILAC labeling of the cells, optional MMS treatment of the cells (one SILAC label only), purification by FLAG-IP to enrich SUMOylated proteins, size-separation by SDS-PAGE, in-gel trypsin digestion, LC-MS/MS. Analysis by Velos (Exp1) and Q-Exactive (Exp2). Site-data: Stable expression of His10-tagged SUMO-2-K0-Q87R in HeLa cells, label-free, optional MMS treatment of the cells, purification by His-pulldown, sample concentration and removal of free SUMO by kDa filtering, digestion with Lys-C, purification by His-pulldown, sample concentration and removal of unrelated peptides by kDa filtering, in-solution trypsin digestion, LC-MS/MS. Analysis by Q-Exactive.</field>
#         <field name="data_processing_protocol">Protein-data: MaxQuant 1.2.2.9 was used. Search parameters were essentially left at default. Light/heavy SILAC labeling was used for Exp1, and Light/medium/heavy labeling was used for Exp2. Site-data: MaxQuant 1.5.1.2 was used. Search parameters were essentially left at default. QQTGG and pyro-QQTGG were searched as variable modifications, including a list of diagnostic peaks corresponding to unique mass fragments resulting from fragmentation of the QQTGG or pyro-QQTGG tryptic remnant.</field>
#         <field name="project_description">Small Ubiquitin-like Modifiers play critical roles in the DNA Damage Response (DDR). To increase our understanding of SUMOylation in the mammalian DDR, we employed a quantitative proteomics approach to identify dynamically regulated SUMO-2 conjugates and modification sites upon treatment with the DNA damaging agent MMS. We have uncovered a dynamic set of 20 upregulated and 33 downregulated SUMO-2 conjugates, and 755 SUMO-2 sites, of which 362 were dynamic in response to MMS. In contrast to yeast, where a response is centered on homologous recombination, we identified dynamically SUMOylated interaction networks of chromatin modifiers, transcription factors, DNA repair factors and nuclear body components. SUMOylated chromatin modifiers include JARID1B/KDM5B, JARID1C/KDM5C, p300, CBP, PARP1, SetDB1 and MBD1. Whereas SUMOylated JARID1B was ubiquitylated by the SUMO-targeted ubiquitin ligase RNF4 and degraded by the proteasome in response to DNA damage, JARID1C was SUMOylated and recruited to the chromatin to demethylate histone H3K4.</field>
#         <field name="experiment_type">Affinity purification coupled with mass spectrometry proteomics</field>
#         <field name="keywords">SUMO-2, SUMO, MMS, DNA, damage, chromatin, repair, site</field>
#         <field name="quantification_method">SILAC</field>
#         <field name="quantification_method">Label free</field>
#         <field name="submission_type">PARTIAL</field>
#         <field name="modification">sumoylated lysine</field>
#         <field name="disease">Cervix carcinoma</field>
#         <field name="software">Not available</field>
#         <field name="cell_type">permanent cell line cell</field>
#         <field name="species">Homo sapiens (Human)</field>
#         <field name="publication">Hendriks IA, Treffers LW, Verlaan-de Vries M, Olsen JV, Vertegaal AC. SUMO-2 Orchestrates Chromatin Modifiers in Response to DNA Damage. Cell Rep. 2015 Mar 10. pii: S2211-1247(15)00179-5</field>
#       </additional_fields>
#     </entry>
#   </entries>
# </database>
#
# #  BD2K-DDI schema example 2
# <database>
#   <name>PRIDE Archive</name>
#   <description/>
#   <release>3</release>
#   <release_date>2015-05-13</release_date>
#   <entry_count>1</entry_count>
#   <entries>
#     <entry id="PRD000123">
#       <name>Large scale qualitative and quantitative profiling of tyrosine phosphorylation using a combination of phosphopeptide immuno-affinity purification and stable isotope dimethyl labeling</name>
#       <description>Triplex stable isotope dimethyl labeling of phosphotyrosine peptides after EGF stimulation</description>
#       <cross_references>
#         <ref dbkey="9606" dbname="TAXONOMY"/>
#         <ref dbkey="19770167" dbname="pubmed"/>
#         <ref dbkey="P60323" dbname="uniprot"/>
#         <ref dbkey="ENSP00000243501" dbname="ensembl"/>
#         <ref dbkey="Q7RTV3" dbname="uniprot"/>
#         <ref dbkey="ENSP00000354251" dbname="ensembl"/>
#         <ref dbkey="ENSP00000296955" dbname="ensembl"/>
#         <ref dbkey="Q14103" dbname="uniprot"/>
#         <ref dbkey="Q9UKK9" dbname="uniprot"/>
#         <ref dbkey="P35658" dbname="uniprot"/>
#       </cross_references>
#       <dates>
#         <date type="submission" value="2009-07-14"/>
#         <date type="publication" value="2010-07-09"/>
#       </dates>
#       <additional_fields>
#         <field name="omics_type">Proteomics</field>
#         <field name="full_dataset_link">http://www.ebi.ac.uk/pride/archive/projects/PRD000123</field>
#         <field name="repository">pride</field>
#         <field name="sample_protocol">Not available</field>
#         <field name="data_protocol">Not available</field>
#         <field name="instrument_platform">LTQ Orbitrap</field>
#         <field name="instrument_platform">instrument model</field>
#         <field name="species">Homo sapiens (Human)</field>
#         <field name="cell_type">Not available</field>
#         <field name="disease">Not available</field>
#         <field name="tissue">HeLa cell</field>
#         <field name="modification">2x(13)C,6x(2)H labeled dimethylated L-arginine</field>
#         <field name="modification">monohydroxylated residue</field>
#         <field name="modification">dimethylated residue</field>
#         <field name="modification">phosphorylated residue</field>
#         <field name="modification">iodoacetamide - site C</field>
#         <field name="modification">4x(2)H labeled dimethylated residue</field>
#         <field name="technology_type">Bottom-up proteomics</field>
#         <field name="technology_type">Mass Spectrometry</field>
#         <field name="submitter_keywords">Not available</field>
#         <field name="quantification_method">Not available</field>
#         <field name="submission_type">PRIDE</field>
#         <field name="software">unknown unknown</field>
#         <field name="publication">Boersema PJ, Foong LY, Ding VM, Lemeer S, van Breukelen B, Philp R, Boekhorst J, Snel B, den Hertog J, Choo AB, Heck AJ; In-depth qualitative and quantitative profiling of tyrosine phosphorylation using a combination of phosphopeptide immunoaffinity purification and stable isotope dimethyl labeling., Mol Cell Proteomics, 2010 Jan, 9, 1, 84-99, </field>
#         <field name="submitter">Paul Boersema</field>
#         <field name="submitter_mail">p.j.boersema@uu.nl</field>
#         <field name="submitter_affiliation">Beta faculty</field>
#         <field name="dataset_file">ftp://ftp.pride.ebi.ac.uk/pride/data/archive/2010/07/PRD000123/PRIDE_Exp_Complete_Ac_9777.xml.gz</field>
#         <field name="dataset_file">ftp://ftp.pride.ebi.ac.uk/pride/data/archive/2010/07/PRD000123/PRIDE_Exp_Complete_Ac_9779.xml.gz</field>
#         <field name="dataset_file">ftp://ftp.pride.ebi.ac.uk/pride/data/archive/2010/07/PRD000123/PRIDE_Exp_Complete_Ac_9780.xml.gz</field>
#       </additional_fields>
#     </entry>
#   </entries>
# </database>

=cut

1;
