package SBEAMS::Biomarker::Biosource;

##############################################################################
#
# Description :   Library code for manipulating biosource records within 
# the database
# $Id:   $
#
# Copywrite 2005   
#
##############################################################################

use strict;

use SBEAMS::Connection qw($log);
use SBEAMS::Biomarker::Tables;
use SBEAMS::Connection::Tables;

#### Set up new variables
#use vars qw(@ISA @EXPORT);
#require Exporter;
#@ISA = qw (Exporter);
#@EXPORT = qw ();
# Keep CGI::Carp's hands off my die!
BEGIN {
# $SIG{__DIE__} = sub { 1; };
}

sub new {
  my $class = shift;
	my $this = { @_ };
	bless $this, $class;
	return $this;
}

#+
# Method to check for existance of specified tissue
#-
sub tissue_type_exists {
  my $this = shift;
  my $tissue = shift;
  return unless $tissue;

  my $sbeams = $this->getSBEAMS() || die "sbeams object not set";
  die "unsafe tissue detected: $tissue\n" if $sbeams->isTaintedSQL($tissue);

  my ($cnt) = $sbeams->selectrow_array( <<"  END_SQL" );
  SELECT COUNT(*) FROM $TBBM_TISSUE_TYPE
  WHERE tissue_type_name = '$tissue'
  END_SQL

  return $cnt;
}   

#+
# Method to check for existance of specified organization
#-
sub organizationExists {
  my $this = shift;
  my $org = shift;
  return unless $org;

  my $sbeams = $this->getSBEAMS() || die "sbeams object not set";
  die "unsafe org detected: $org\n" if $sbeams->isTaintedSQL($org);

  my ($cnt) = $sbeams->selectrow_array( <<"  END_SQL" );
  SELECT COUNT(*) FROM $TB_ORGANIZATION
  WHERE organization = '$org'
  END_SQL

  return $cnt;
}   


#+
# Method to check for existance of specified organism
#-
sub organismExists {
  my $this = shift;
  my $organism = shift;
  return '' unless $organism;

  my $sbeams = $this->getSBEAMS() || die "sbeams object not set";
  die "unsafe organism: $organism\n" if $sbeams->isTaintedSQL($organism);

  my ($cnt) = $sbeams->selectrow_array( <<"  END_SQL" );
  SELECT COUNT(*) FROM $TB_ORGANISM
  WHERE organism_name = '$organism'
  END_SQL

  return $cnt;
}   
  
#+
# Method to check for existance of specified disease
#-
sub diseaseExists {
  my $this = shift;
  my $disease = shift;
  return unless $disease;

  my $sbeams = $this->getSBEAMS() || die "sbeams object not set";
  die "unsafe disease detected: $disease\n" if $sbeams->isTaintedSQL($disease);

  my ($cnt) = $sbeams->selectrow_array( <<"  END_SQL" );
  SELECT COUNT(*) FROM $TBBM_DISEASE
  WHERE disease_name = '$disease'
  END_SQL

  return $cnt;
}   


#+
# Method for creating new biosource.
# narg tissue, ref to array of tissue names to add
# narg tissue_type, default unknown
# narg auto, default 0
#-
sub add_new {
  my $this = shift;
  my %args = @_;

  for ( qw( data_ref group_id ) ) {
    die "Missing parameter $_" unless defined $_;    
  }
  my $sbeams = $this->getSBEAMS() || die "sbeams object not set";
  my $name = $args{data_ref}->{biosource_name} || die "no biosource name!";
  $args{data_ref}->{biosource_group_id} = $args{group_id};

  # Sanity check 
  my ($is_there) = $sbeams->selectrow_array( <<"  END_SQL" );
  SELECT COUNT(*) FROM $TBBM_BIOSOURCE
  WHERE biosource_name = '$name'
  END_SQL

  if( $is_there ) {
    print STDERR "Skipping biosource creation, entry exists: $name\n";
    return;
  }

#  for my $k ( keys( %{$args{data_ref}} ) ){ print "$k => $args{data_ref}->{$k}\n"; }
  my $id = $sbeams->updateOrInsertRow( insert => 1,
                                    return_PK => 1,
                                   table_name => $TBBM_BIOSOURCE,
                                  rowdata_ref => $args{data_ref},
                         add_audit_parameters => 1
                                     );

  $log->error( "Couldn't create biosource record" ) unless $id;

  return $id;

} # End add_new   

#+
#
#-
sub add_biosource_attrs {
  my $this = shift;
  my %args = @_;
   
  for ( qw( attrs src_id ) ) {
    die "Missing parameter $_" unless defined $_;    
  }

  my $sbeams = $this->getSBEAMS() || die "sbeams object not set";
   
  my %attr_hash = $sbeams->selectTwoColumnHash( <<"  END" );
  SELECT attribute_name, attribute_id FROM $TBBM_ATTRIBUTE
  END
   
  for my $key (keys(%{$args{attrs}})) {

    my $dataref = { biosource_id => $args{src_id},
                    attribute_id => $attr_hash{$key},
                    attribute_value => $args{attr}->{$key} };

    my $id = $sbeams->updateOrInsertRow( insert => 1,
                                      return_PK => 1,
                                   table_name => $TBBM_BIOSOURCE_ATTRIBUTE,
                                    rowdata_ref => $dataref, 
                           add_audit_parameters => 0
                                       );

    $log->error( "Couldn't create biosource record" ) unless $id;
  }

} # End add_biosource_attrs   


#+
#
#-
sub add_biosource_diseases {
  my $this = shift;
  my %args = @_;
   
  for ( qw( diseases src_id ) ) {
    die "Missing parameter $_" unless defined $_;    
  }
  my %diseases = %{$args{diseases}};

  my $sbeams = $this->getSBEAMS() || die "sbeams object not set";

  my %dnames = $sbeams->selectTwoColumnHash( <<"  END" );
  SELECT disease_name, disease_id FROM $TBBM_DISEASE
  END
   
  for my $key (keys(%diseases)) {
    next unless $diseases{$key};
    print "$key, $diseases{$key}\n";

    my $dataref = { biosource_id => $args{src_id},
                    disease_id => $dnames{$key} };

    my $id = $sbeams->updateOrInsertRow( insert => 1,
                                      return_PK => 1,
                                   table_name => $TBBM_BIOSOURCE_DISEASE,
                                    rowdata_ref => $dataref,
                           add_audit_parameters => 0
                                       );
    $log->error( "Couldn't create biosource disease record" ) unless $id;
  }

} # End add_biosource_diseasess   



#+
# Method for creating tissues.
# narg tissue, ref to array of tissue names to add
# narg tissue_type, default unknown
# narg auto, default 0
#-
sub create_tissues {
  my $this = shift;
  my %args = @_;
  return unless $args{tissue_type};
  my $tissues = $args{tissue_type};

  my $sbeams = $this->getSBEAMS() || die "sbeams object not set";

  for my $tissue_type ( @$tissues ) {
    die "unsafe tissue detected: $tissue_type\n" 
                                         if $sbeams->isTaintedSQL($tissue_type);

    # Sanity check 
    my ($existing_id) = $sbeams->selectrow_array( <<"    END_SQL" );
    SELECT tissue_type_id FROM $TBBM_TISSUE_TYPE
    WHERE tissue_type_name = '$tissue_type'
    END_SQL

    $log->warn("tissue type already exists, why are we making it? ($existing_id)");
    $log->info("Creating Tissue: $tissue_type");

    my $id = $sbeams->updateOrInsertRow( insert => 1,
                                      return_PK => 1,
                                     table_name => $TBBM_TISSUE_TYPE,
                                    rowdata_ref => {tissue_type_name => $tissue_type,
                        tissue_type_description => 'autogenerated, please update'},
                           add_audit_parameters => 1
                                       );
    print "Got ID($id) from tissue($tissue_type)\n";
    $log->error( "Couldn't create tissue $tissue_type" ) unless $id;
  }

} # End createTissues   


#+
# Method for creating diseases.
# narg disease, ref to array of disease names to add
# narg disease_type, default unknown
# narg auto, default 0
#-
sub createDiseases {
  my $this = shift;
  my %args = @_;
  return unless $args{diseases};

  $args{disease_type} ||= 'unknown';
  $args{auto} ||= 0;

  my $disease_type_id = $this->getDiseaseTypeID( type => $args{disease_type},
                                              auto => $args{auto}
                                         );
  unless( $disease_type_id ) {
    $log->error( "Disease type creation failed" ) if $args{auto};
    return;
  }

  my $sbeams = $this->getSBEAMS() || die "sbeams object not set";

  foreach my $disease ( @{$args{diseases}} ) {
    die "unsafe disease detected: $disease\n" if $sbeams->isTaintedSQL($disease);
    $log->info("Creating Disease: $disease");

    # Sanity check 
    my ($is_there) = $sbeams->selectrow_array( <<"    END_SQL" );
    SELECT COUNT(*) FROM $TBBM_DISEASE
    WHERE disease_name = '$disease'
    END_SQL

    next if $is_there;

    my $id = $sbeams->updateOrInsertRow( insert => 1,
                                      return_PK => 1,
                                     table_name => $TBBM_DISEASE,
                                    rowdata_ref => {disease_name => $disease,
                                disease_type_id => $disease_type_id },
                           add_audit_parameters => 1
                                     );
    $log->error( "Couldn't create disease $disease" ) unless $id;
  }

} # End createDiseases   

#+
# Method fetches id of disease type, optionally creating it first if necessary
# narg disease_type, default unknown
# narg auto, default 0
#-
sub getDiseaseTypeID {
  my $this = shift;
  my %args = @_;

  $args{disease_type} ||= 'unknown';
  $args{auto} ||= 0;

  my $sbeams = $this->getSBEAMS() || die "sbeams object not set";

  my $sql =<<"  END_SQL";
  SELECT disease_type_id FROM $TBBM_DISEASE_TYPE
  WHERE disease_type_name = '$args{disease_type}'
  END_SQL

  my ($id) = $sbeams->selectrow_array( $sql );
  return $id if $id || !$args{auto};

  $id = $sbeams->updateOrInsertRow( insert => 1,
                                 return_PK => 1,
                                table_name => $TBBM_DISEASE_TYPE,
                               rowdata_ref => {disease_type_name => $args{disease_type},
                disease_type_description => 'autogenerated, please update' },
                           add_audit_parameters => 1
                                   );
  return $id || undef;

} # End getDiseaseTypeID

  
#+
# Method for creating attributes.
# narg attr, ref to array of attribute names to add
# narg attr_type, default unknown
# narg auto, default 0
#-
sub createAttributes {
  my $this = shift;
  my %args = @_;
  return unless $args{attr};

  $args{attr_type} ||= 'unknown';
  $args{auto} ||= 0;

  my $attr_type_id = $this->getAttrTypeID( type => $args{attr_type},
                                           auto => $args{auto}
                                         );
  unless( $attr_type_id ) {
    $log->error( "Attr type creation failed" ) if $args{auto};
    return;
  }

  my $sbeams = $this->getSBEAMS() || die "sbeams object not set";

  foreach my $attr ( @{$args{attr}} ) {
    die "unsafe attr detected: $attr\n" if $sbeams->isTaintedSQL($attr);
    $log->info("Creating Attribute: $attr");

    # Sanity check 
    my ($is_there) = $sbeams->selectrow_array( <<"    END_SQL" );
    SELECT COUNT(*) FROM $TBBM_ATTRIBUTE
    WHERE attribute_name = '$attr'
    END_SQL

    next if $is_there;

    my $id = $sbeams->updateOrInsertRow( insert => 1,
                                      return_PK => 1,
                                     table_name => $TBBM_ATTRIBUTE,
                                    rowdata_ref => {attribute_name => $attr,
                              attribute_type_id => $attr_type_id,
                       attribute_description => 'autogenerated, please update'},
                           add_audit_parameters => 1
                                     );
    $log->error( "Couldn't create attribute $attr" ) unless $id;
  }

} # End createAttributes   

#+
# Method fetches id of attribute type, optionally creating it first if necessary
# narg attr_type, default unknown
# narg auto, default 0
#-
sub getAttrTypeID {
  my $this = shift;
  my %args = @_;

  $args{attr_type} ||= 'unknown';
  $args{auto} ||= 0;

  my $sbeams = $this->getSBEAMS() || die "sbeams object not set";

  my $sql =<<"  END_SQL";
  SELECT attribute_type_id FROM $TBBM_ATTRIBUTE_TYPE
  WHERE attribute_type_name = '$args{attr_type}'
  END_SQL

  my ($id) = $sbeams->selectrow_array( $sql );
  return $id if $id || !$args{auto};

  $id = $sbeams->updateOrInsertRow( insert => 1,
                                 return_PK => 1,
                                table_name => $TBBM_ATTRIBUTE_TYPE,
                               rowdata_ref => {attribute_type_name => $args{attr_type},
                attribute_type_description => 'autogenerated, please update' },
                      add_audit_parameters => 1
                                   );
  return $id || undef;

} # End getAttrTypeID
sub attrExists {
  my $this = shift;
  my $attr = shift;
  return unless $attr;

  my $sbeams = $this->getSBEAMS() || die "sbeams object not set";
  die "unsafe attr detected: $attr\n" if $sbeams->isTaintedSQL($attr);

  my ($cnt) = $sbeams->selectrow_array( <<"  END_SQL" );
  SELECT COUNT(*) FROM $TBBM_ATTRIBUTE
  WHERE attribute_name = '$attr'
  END_SQL

  return $cnt;
}   
sub setSBEAMS {
  my $this = shift;
  my $sbeams = shift || die "Must pass sbeams object";
  $this->{_sbeams} = $sbeams;
}
sub getSBEAMS {
  my $this = shift;
  return $this->{_sbeams};
}

  


#+
# Routine for inserting biosource(s)
#
#-
sub insertBiosources {
  my $this = shift;
  my %args = @_;
  my $p = $args{'wb_parser'} || die "Missing required parameter wb_parser";
  $this->insertBiosamples( wb_parser => $p );
}

#+
# Routine to create and cache biosource object if desired
#-
sub setBiosample {
  my $this = shift;
  $this->{_biosample} = shift || die 'Missing required biosource parameter'; 
}

#+
# Routine to fetch Biosample object
#-
sub getBiosample {
  my $this = shift;

  unless ( $this->{_biosample} ) {
    $log->warn('getBiosample called, none defined'); 
    return undef;
  }
  return $this->{_biosample};
}

1;
# End biosource

