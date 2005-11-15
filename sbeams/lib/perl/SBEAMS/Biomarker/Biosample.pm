package SBEAMS::Biomarker::Biosample;

###############################################################################
#
# Description :   Library code for inserting biosource/biosample records into 
# the database
# $Id$
#
# Copywrite 2005   
#
###############################################################################

use strict;

use SBEAMS::Connection qw( $log );
use SBEAMS::Biomarker;     
use SBEAMS::Biomarker::Biosource;     
use SBEAMS::Biomarker::Tables;     
use SBEAMS::Connection::Tables;     
 
#### Set up new variables
#use vars qw(@ISA @EXPORT);
#require Exporter;
#@ISA = qw (Exporter);
#@EXPORT = qw ();

sub new {
  my $class = shift;
	my $this = { @_ };
	bless $this, $class;
	return $this;
}

#+
# Method to check for existance of specified Attribute
#-
sub attrExists {
  my $this = shift;
  my $attr = shift;
  return unless $attr;

  my $sbeams = $this->get_sbeams() || die "sbeams object not set";
  die "unsafe attr detected: $attr\n" if $sbeams->isTaintedSQL($attr);

  my ($cnt) = $sbeams->selectrow_array( <<"  END_SQL" );
  SELECT COUNT(*) FROM $TBBM_ATTRIBUTE
  WHERE attribute_name = '$attr'
  END_SQL

  return $cnt;
}   

####
#+
# Method for creating new biosample from a biosource/upload.
#-
sub add_new {
  my $this = shift;
  my %args = @_;

  for ( qw( data_ref group_id src_id  ) ) {
    die "Missing parameter $_" unless defined $_;    
  }

  my $sbeams = $this->get_sbeams() || die "sbeams object not set";
  my $name = $args{data_ref}->{biosample_name} || die "no biosample name!";
  $args{data_ref}->{biosource_id} = $args{src_id};
  $args{data_ref}->{biosample_group_id} = $args{group_id};
  $args{data_ref}->{biosample_type_id} ||= ( $this->get_sample_type_id('source') ) ?
              $this->get_sample_type_id('source') : $this->add_source_type();



  # Sanity check 
  my ($is_there) = $sbeams->selectrow_array( <<"  END_SQL" );
  SELECT COUNT(*) FROM $TBBM_BIOSAMPLE
  WHERE biosample_name = '$name'
  END_SQL

  if( $is_there ) {
    print STDERR "Skipping biosample creation, entry exists: $name\n";
    next;
  }

   my $id = $sbeams->updateOrInsertRow( insert => 1,
                                     return_PK => 1,
                                    table_name => $TBBM_BIOSAMPLE,
                                   rowdata_ref => $args{data_ref},
                          add_audit_parameters => 1
                                    );

   $log->error( "Couldn't create biosample record" ) unless $id;
   return $id;

} # End add_new   

#+
# Inserts new biosamples genearted by applying a treatment to a set of 
# input samples
#-
sub insert_biosamples {
  my $this = shift;
  my %args = @_;

  for my $arg ( qw( data_ref treatment_id bio_group ) ) {
    die( "Missing required arguement $arg" ) unless $args{$arg};
  }
  my $sbeams = $this->get_sbeams() || die "sbeams object not set";
  my $biomarker = $this->get_biomarker();
  my $gid = $biomarker->create_biogroup(group_name => $args{bio_group});

  my %kids = %{$args{data_ref}};

  for my $key (sort{$a <=> $b}(keys( %kids ))) {
    my $dup_id;
    for my $child ( @{$kids{$key}} ) {
      $child->{biosample_group_id} = $gid;
      $child->{biosource_id} = 1;
      $child->{treatment_id} = $args{treatment_id};
      $child->{duplicate_biosample_id} = $dup_id if $dup_id;

      my $id = $sbeams->updateOrInsertRow( insert => 1,
                                        return_PK => 1,
                                       table_name => $TBBM_BIOSAMPLE,
                                      rowdata_ref => $child,
                             add_audit_parameters => 1
                                         );
      $log->info( "Inserted new child sample: $id" );
      $dup_id = $id unless $dup_id;
    }
  $log->info( "NEXT!" ); 
  }


}


#+
# Routine to resolve/validate user-specified mappings for a sample 'treatment'
#-
sub get_treatment_mappings {
  my $this = shift;
  my %args = @_;
  for my $arg ( qw( p_ref ) ) {
    die( "Missing required arguement $arg" ) unless $args{$arg};
  }
  my %p = %{$args{p_ref}};
  my @samples = split( ',', $p{biosample_id} );

  my $biomarker = $this->get_biomarker();
  my $sbeams = $this->get_sbeams();

  my $contact_id = $sbeams->getCurrent_contact_id();

# Should have some code here to check validity of experiment_id, input/output,
# treatement, protocols, # replicates, etc.
  
  # Accumulator for errors  
  my @errors;

  unless( $p{num_replicates} ) {
    $log->warn( 'Illegal number of replicates' );
    return undef;
  }

  my $base = $p{replicate_names} eq 'abc' ? 'a' : 1;
  
  my $expt_name = $biomarker->get_experiment_name($p{experiment_id});
  
  # validate user's access to this project?
  
  # Get hashref of id->values for existing samples
  my $parent_samples = $this->get_sample_info( samples => \@samples,
                                         experiment_id => $p{experiment_id}, 
                                             error_log => \@errors 
                                              ); 

  # Populate hash representing treatment, since we're messing with the params
  my %treatment = ( treatment_type_id => $p{treatment_type_id},
                treatment_description => $p{treatment_description},
                       treatment_name => $p{treatment_name},
                         input_volume => $p{input_volume},
                        notebook_page => $p{notebook_page},
                         processed_by => $contact_id );
 
  # Hash to hold parent/child samples keyed by parent sample_id 
  my %parents;
  my %children;
  for my $psample ( @{$parent_samples} ) {
    $parents{$psample->{biosample_id}} = $psample;
    my @children;
    my $num_anc = $psample->{num_ancestors} + 1;
    my $rep_base = $base;
    for ( my $i = 1; $i <= $p{num_replicates}; $i++ ) {
      my %child = ( biosample_name => "$psample->{biosample_name}_${rep_base}",
                    parent_biosample_id => $psample->{biosample_id},
                    num_ancestors => $num_anc,
                    experiment_id => $p{experiment_id},
                    prep_replicate => $rep_base,
                    storage_location_id => $p{storage_location_id},
                    biosample_type_id => $p{output_type},
                    original_volume => $p{output_volume},
                  );
      # Push current child onto array of children for this parent
      push @children, \%child;
      $rep_base++;
    }
    # Cache all the children for this parent keyed by parent biosample_id
    $children{$psample->{biosample_id}} = \@children;
  }
  # Data structure to return.  Set info for treatment and errors here, 
  # plus info for specific parent samples in loop below. 
  my %data_ref = ( treatment => \%treatment,
                   errors => \@errors, 
                   parents => \%parents,
                   children => \%children );

  print "Send the data<BR>";
  return \%data_ref; 
}

#+
# Routine to return information about existing samples in the database
sub get_sample_info {
  my $this = shift;
  my %args = @_;
  for my $arg ( qw( samples error_log experiment_id ) ) {
    die( "Missing required arguement $arg" ) unless $args{$arg};
  }
  my $sbeams = $this->get_sbeams() || die "sbeams object not set";

  my $sample_list = join( ',', @{$args{samples}} );
  unless( $sample_list ) {
    $log->warn( "Empty sample list in get_sample_info" );
    return '';
  }

  my $sql =<<"  END";
  SELECT BS.*, BG.bio_group_name 
  FROM $TBBM_BIOSAMPLE BS JOIN $TBBM_BIO_GROUP BG
    ON BG.bio_group_id = BS.biosample_group_id
  WHERE biosample_id IN ( $sample_list )
  AND experiment_id = $args{experiment_id}
  AND BG.record_status <> 'D'
  AND BS.record_status <> 'D'
  END

  # Simply return array of sample info hashrefs 
  my @samples = $sbeams->selectHashArray($sql);
  return \@samples;
#
#  my %sample_info;
#  for my $row ( $sbeams->selectHashArray( $sql ) ) {
    # Each row is going to be a hashref
#    for my $key ( keys( %$row ) ) { print "$key => $row->{$key}<BR>"; }
#    unless( grep /^$row->{biosample_id}$/, @{$args{samples}} ) {
#      push @errors (
#    }
#    $sample_info{$row->{biosample_id}} = $row; 
#  }
#  return \%sample_info;

}


#+
#
#-
sub add_biosample_attrs {
  my $this = shift;
  my %args = @_;
   
  for ( qw( attrs smpl_id ) ) {
    die "Missing parameter $_" unless defined $_;    
  }

  my $sbeams = $this->get_sbeams() || die "sbeams object not set";
   
  my %attr_hash = $sbeams->selectTwoColumnHash( <<"  END" );
  SELECT attribute_name, attribute_id FROM $TBBM_ATTRIBUTE
  END
   
  for my $key (keys(%{$args{attrs}})) {

    my $dataref = { biosample_id => $args{smpl_id},
                    attribute_id => $attr_hash{$key},
                    attribute_value => $args{attr}->{$key} };

    my $id = $sbeams->updateOrInsertRow( insert => 1,
                                      return_PK => 1,
                                   table_name => $TBBM_BIOSAMPLE_ATTRIBUTE,
                                    rowdata_ref => $dataref, 
                           add_audit_parameters => 0
                                       );

    $log->error( "Couldn't create biosample record" ) unless $id;
  }

} # End add_biosample_attrs   

####

#+
# Method to check for existance of specified storage_location
#-
sub storageLocExists {
  my $this = shift;
  my $stor = shift;
  return '' unless $stor;

  my $sbeams = $this->get_sbeams() || die "sbeams object not set";
  die "unsafe storage location: $stor\n" if $sbeams->isTaintedSQL($stor);

  my ($cnt) = $sbeams->selectrow_array( <<"  END_SQL" );
  SELECT COUNT(*) FROM $TBBM_STORAGE_LOCATION
  WHERE location_name = '$stor'
  END_SQL

  return $cnt;
}   


#+
# Method for creating storage_location records.
# narg strg_loc, ref to array of storage_locations to add
# narg auto, default 0
#-
sub createStorageLoc {
  my $this = shift;
  my %args = @_;
  return unless $args{strg_loc};

  $args{auto} ||= 0;

  my $sbeams = $this->get_sbeams() || die "sbeams object not set";

  foreach my $strg_loc ( @{$args{strg_loc}} ) {
    die "unsafe name detected: $strg_loc\n" if $sbeams->isTaintedSQL($strg_loc);
    $log->info("Creating storage location: $strg_loc");

    # Sanity check 
    my ($is_there) = $sbeams->selectrow_array( <<"    END_SQL" );
    SELECT COUNT(*) FROM $TBBM_STORAGE_LOCATION
    WHERE location_name = '$strg_loc'
    END_SQL

    next if $is_there;

    my $id = $sbeams->updateOrInsertRow( insert => 1,
                                      return_PK => 1,
                                     table_name => $TBBM_STORAGE_LOCATION,
                           add_audit_parameters => 1,
                                    rowdata_ref => {location_name => $strg_loc,
                        location_description => 'autogenerated, please update'},
                           add_audit_parameters => 1
                                     );

    $log->error( "Couldn't create storage location $strg_loc" ) unless $id;
  }
}

#+
# Setter method for cached biosource
#-
sub set_biosource {
  my $this = shift;
  # Use passed biosource if available
  $this->{_biosource} = shift;
  # Otherwise, create a new one
  $this->{_biosource} ||= SBEAMS::Biomarker::Biosource->new();
}

#+
# Accessor method for cached biosource
#-
sub get_biosource {
  my $this = shift;
  if ( !$this->{_biosource} ) {
    $log->info('get_biosource called when none was cached, creating anew'); 
    $this->set_biosource();
  }
  return $this->{_biosource};
}

#+
# Setter method for cached biomarker
#-
sub set_biomarker {
  my $this = shift;
  my $biomarker = shift;
  $this->{_biomarker} ||=  SBEAMS::Biomarker->new();
}

#+
# Accessor method for cached biomarker
#-
sub get_biomarker {
  my $this = shift;
  if ( !$this->{_biomarker} ) {
    $log->info('get_biosample called when none was cached, creating anew'); 
    $this->set_biomarker();
  }
  return $this->{_biomarker};
}
  
#+
# Setter method for cached sbeams
#-
sub set_sbeams {
  my $this = shift;
  my $sbeams = shift || die "Must pass sbeams object";
  $this->{_sbeams} = $sbeams;
}

#+
# Accessor method for cached sbeams
#-
sub get_sbeams {
  my $this = shift;
  return $this->{_sbeams};
}

sub add_source_type {
  my $this = shift;
  # if it exists, return it, else create it
  print "calling with $this\n";
  my $id = $this->get_sample_type_id( 'source' );
  print "called with source\n";
  return $id if $id;

  my $rd = { biosample_type_name => 'source',
             biosample_type_description => 'New sample direct from biosource' };

  $this->get_sbeams()->updateOrInsertRow( insert => 1,
                                      return_PK => 1,
                                     table_name => $TBBM_BIOSAMPLE_TYPE,
                                    rowdata_ref => $rd,
                           add_audit_parameters => 1
                                        );         
}


sub get_sample_type_id {
  my $this = shift;
  my $type = shift;
  my ( $id ) = $this->get_sbeams()->selectrow_array( <<"  END" );
  SELECT biosample_type_id FROM $TBBM_BIOSAMPLE_TYPE
  WHERE biosample_type_name = '$type'
  END
  return $id;
}

#+
# Routine for inserting biosample
#
#-
#sub insertBiosamples {
#  my $this = shift;
#  my %args = @_;
#  my $p = $args{'wb_parser'} || die "Missing required parameter wb_parser";
#  $this->insertBiosamples( wb_parser => $p );
#}
#



1;







__DATA__

# Attributes 
'Sample Setup Order'
'MS Sample Run Number'
'Name of Investigators'
'PARAM:time of sample collection '
'PARAM:meal'
'PARAM:alcohole'
'PARAM:smoke'
'PARAM:Date of Sample Collection'
'Study Histology'

# Bioource 
'ISB sample ID'
'Patient_id'
'External Sample ID'
'Name of Institute'
'species'
'age'
'gender'

'Sample type'

# Biosample
'amount of sample received'
'Location of orginal sample'

# Disease
'Disease:Breast cancer'
'Disease:Ovarian cancer'
'Disease:Prostate cancer'
'Disease:Blader Cancer'
'Disease:Skin cancer'
'Disease:Lung cancer'
'Disease: Huntington\'s Disease'
'diabetic'

# tissue_type
'heart'
'blood'
'liver'
'neuron'
'lung'
'bone'

biosource_disease
'Disease Stage'

#orphan
'Disease Info: Group'
'Prep Replicate id'
'Sample Prep Name'
'status of sample prep'
'date of finishing prep'
'amount of sample used in prep'
'Sample prep method'
'person prepared the samples'
'Volume of re-suspended sample'
'location of finished sample prep'
'MS Replicate Number'
'MS Run Name'
'status of MS'
'date finishing MS'
'Random Sample Run order'
'order of samples ran per day'
'MS run protocol'
'Volume Injected'
'location of data'
'status of Conversion'
'Date finishing conversion'
'name of raw files'
'location of raw files'
'name of mzXML'
'location of mzXML'
'person for MS analysis'
'date finishing alignment'
'location of alignment files'
'person for data analysis'
'peplist peptide peaks file location'
