package PAxmlContentHandler;
###############################################################################
###############################################################################
###############################################################################
# PAxmlContentHandler package: SAX parser callback routines
#
# This PAxmlContentHandler package defines all the content handling callback
# subroutines used the SAX parser
###############################################################################
use strict;
use XML::Xerces;
use Date::Manip;
use vars qw(@ISA $VERBOSE);
@ISA = qw(XML::Xerces::PerlContentHandler);
$VERBOSE = 0;


###############################################################################
# new
###############################################################################
sub new {
  my $class = shift;
  my $self = $class->SUPER::new();
  $self->object_stack([]);
  $self->unhandled({});
  return $self;
}


###############################################################################
# object_stack
###############################################################################
sub object_stack {
  my $self = shift;
  if (scalar @_) {
    $self->{OBJ_STACK} = shift;
  }
  return $self->{OBJ_STACK};
}


###############################################################################
# setVerbosity
###############################################################################
sub setVerbosity {
  my $self = shift;
  if (scalar @_) {
    $VERBOSE = shift;
  }
}


###############################################################################
# unhandled
###############################################################################
sub unhandled {
  my $self = shift;
  if (scalar @_) {
    $self->{UNHANDLED} = shift;
  }
  return $self->{UNHANDLED};
}


###############################################################################
# start_element
###############################################################################
sub start_element {
  my ($self,$uri,$localname,$qname,$attrs) = @_;

  #### Make a hash to of the attributes
  my %attrs = $attrs->to_hash();

  #### Convert all the values from hashref to single value
  while (my ($aa1,$aa2) = each (%attrs)) {
    $attrs{$aa1} = $attrs{$aa1}->{value};
  }

  ##########################################################################
  #### If this is a spectrum, then store some attributes
  if ($localname eq 'atlas_build') {
    #### TODO UPDATE atlas_build table with probability
  }

  ##########################################################################
  #### If this is the peptide_instance, store it
  if ($localname eq 'peptide_instance') {

    $self->{pi_counter}++;
    #### Create a list of sample_ids, using proteomics sbid
    my @search_batch_ids = split(",",$attrs{search_batch_ids});

    my @sample_ids;

    my @atlas_search_batch_ids;

    foreach my $search_batch_id ( @search_batch_ids ) 
    {
        push(@sample_ids,
            $self->{sbid_asbid_sid_hash}->{$search_batch_id}->{sample_id});
        push(@atlas_search_batch_ids,
            $self->{sbid_asbid_sid_hash}->{$search_batch_id}->{atlas_search_batch_id});
    }

    my $sample_ids = join(",",@sample_ids);

    my $n_samples = $#sample_ids + 1;

    $attrs{atlas_search_batch_ids} = join(",",@atlas_search_batch_ids);

    # Left in when committing changes 2007-10-19
    unless ( 1 || $self->{counter} % 1000 ) {
      print "\n";
      print "PAIdent hash has " . scalar(keys(%{$self->{peptide_acc_id_hash}})) . " elements\n";
      print "Been in peptide_instance $self->{pi_counter} times of $self->{counter}\n";
    }

    #### Get the peptide_id for this peptide
    my $peptide_id = $self->{peptide_acc_id_hash}->{$attrs{peptide_accession}};

    #### If this peptide_id doesn't yet exist in the peptide table, add it
    if ( !$peptide_id ) {

      my %rowdata = ( peptide_accession => $attrs{peptide_accession},
                       peptide_sequence => $attrs{peptide_sequence},
                         peptide_length => length($attrs{peptide_sequence}) );

      $peptide_id = &main::insert_peptide( rowdata_ref=>\%rowdata );

        ## add new peptide_id to hash:
        $self->{peptide_acc_id_hash}->{$attrs{peptide_accession}} = $peptide_id;
    }

    #### Create the peptide_instance record itself
    my %rowdata = (
      atlas_build_id => $self->{atlas_build_id},
      peptide_id => $peptide_id,
      best_probability => $attrs{best_probability},
      n_observations => $attrs{n_observations},
      n_adjusted_observations => $attrs{n_adjusted_observations},
      n_sibling_peptides => $attrs{n_sibling_peptides},
      best_adjusted_probability => $attrs{best_adjusted_probability},
      n_genome_locations => -1,
      sample_ids => $sample_ids,
      n_samples => $n_samples,
      is_exon_spanning => '?',
      n_protein_mappings => -1,
      search_batch_ids => $attrs{search_batch_ids},
      preceding_residue => $attrs{peptide_prev_aa},
      following_residue => $attrs{peptide_next_aa},
      original_protein_name => $attrs{original_protein_name},
    );

    my $peptide_instance_id = &main::insert_peptide_instance(
      rowdata_ref=>\%rowdata,
    );
    $self->{peptide_instance_id} = $peptide_instance_id;


    #### Create peptide_instance_sample records
    &main::insert_peptide_instance_samples(
      peptide_instance_id => $peptide_instance_id,
      sample_ids => $sample_ids,
    );


    #### Create peptide_instance_search_batch records
    &main::insert_peptide_instance_search_batches(
      peptide_instance_id => $peptide_instance_id,
      atlas_search_batch_ids => $attrs{atlas_search_batch_ids},
    );


  }


  ##########################################################################
  #### If this is the peptide_instance, store it
  if ($localname eq 'modified_peptide_instance') {

    #### Create a list of sample_ids
    my @search_batch_ids = split(",",$attrs{search_batch_ids});

    my @sample_ids;

    my @atlas_search_batch_ids;

    foreach my $search_batch_id ( @search_batch_ids ) 
    {
        push(@sample_ids,
            $self->{sbid_asbid_sid_hash}->{$search_batch_id}->{sample_id});
        push(@atlas_search_batch_ids,
            $self->{sbid_asbid_sid_hash}->{$search_batch_id}->{atlas_search_batch_id});
    }

    my $sample_ids = join(",",@sample_ids);

    $attrs{atlas_search_batch_ids} = join(",",@atlas_search_batch_ids);


    #### Get the peptide_instance_id for this modified_peptide
    my $peptide_instance_id = $self->{peptide_instance_id} or
      die("ERROR: Unable to find a valid peptide_instance_id in the ".
	  "content handler.\n");


    #### Create the modified_peptide_instance record itself
    my %rowdata = (
      peptide_instance_id => $peptide_instance_id,
      modified_peptide_sequence => $attrs{peptide_string},
      peptide_charge => $attrs{charge_state},
      best_probability => $attrs{best_probability},
      n_observations => $attrs{n_observations},
      n_adjusted_observations => $attrs{n_adjusted_observations},
      n_sibling_peptides => $attrs{n_sibling_peptides},
      best_adjusted_probability => $attrs{best_adjusted_probability},
      sample_ids => $sample_ids,
      search_batch_ids => $attrs{search_batch_ids},
    );

    my $modified_peptide_instance_id = &main::insert_modified_peptide_instance(
      rowdata_ref=>\%rowdata,
    );
    $self->{modified_peptide_instance_id} = $modified_peptide_instance_id;

    #### Create modified_peptide_instance_sample records
    &main::insert_modified_peptide_instance_samples(
      modified_peptide_instance_id => $modified_peptide_instance_id,
      sample_ids => $sample_ids,
    );


    #### Create modified_peptide_instance_search_batch records
    &main::insert_modified_peptide_instance_search_batches(
      modified_peptide_instance_id => $modified_peptide_instance_id,
      atlas_search_batch_ids => $attrs{atlas_search_batch_ids},
    );

  }



  #### Increase the counters and print some progress info
  $self->{counter}++;
#  print $self->{counter}."..." if ($self->{counter} % 100 == 0);
  if ($self->{counter} % 100 == 0) {
    print $self->{counter}."...";
    # Assumes we are explicitly committing.
    &main::commit_transaction();
  }



  #### Push information about this element onto the stack
  my $tmp;
  $tmp->{name} = $localname;
  push(@{$self->object_stack},$tmp);


} # end start_element



###############################################################################
# end_element
###############################################################################
sub end_element {
  my ($self,$uri,$localname,$qname) = @_;


  #### If there's an object on the stack consider popping it off
  if (scalar @{$self->object_stack()}){

    #### If the top object on the stack is the correct one, pop it off
    #### else die bitterly
    if ($self->object_stack->[-1]->{name} eq "$localname") {
      pop(@{$self->object_stack});
    } else {
      die("STACK ERROR: Wanted to pop off an element fo type '$localname'".
        " but instead we found '".$self->object_stack->[-1]->{name}."'!");
    }

  } else {
    die("STACK ERROR: Wanted to pop off an element of type '$localname'".
        " but instead we found the stack empty!");
  }

}

###############################################################################

1;
