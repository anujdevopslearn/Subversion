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
use vars qw(@ISA $VERBOSE $sbeams $sbeamsMOD $massCalculator $SSRCalculator);
@ISA = qw(XML::Xerces::PerlContentHandler);
$VERBOSE = 0;
use lib "$FindBin::Bin/../../perl";
#### Set up SBEAMS core module
use SBEAMS::Connection qw($q $log);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;

use SBEAMS::Proteomics;
use SBEAMS::Proteomics::Settings;
use SBEAMS::Proteomics::Tables;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::PeptideAtlas;

use SSRCalculator;
$SSRCalculator = new SSRCalculator;
$SSRCalculator->initializeGlobals3();
$SSRCalculator->ReadParmFile3();

use SBEAMS::Proteomics::PeptideMassCalculator;
$massCalculator = new SBEAMS::Proteomics::PeptideMassCalculator;


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
    print "pi: $self->{pi_counter} ..." if ($self->{pi_counter} %100 ==0);
    #### Create a list of sample_ids, using proteomics sbid
    my @search_batch_ids = split(",",$attrs{search_batch_ids});

    my @sample_ids;

    my @atlas_search_batch_ids;
    if ($self->{peptide_accession} && $self->{peptide_accession} eq $attrs{peptide_accession}){
       print "loading start from $self->{peptide_accession}\n";
    }
		if ($attrs{peptide_sequence} =~ /[BZXU]/){
			 print "skip $attrs{peptide_sequence}, invalid AA\n";
			 goto SKIP;
 
		}

       
    foreach my $search_batch_id ( @search_batch_ids )
    {
        push(@sample_ids,
            $self->{sbid_asbid_sid_hash}->{$search_batch_id}->{sample_id});
        if (! $self->{sbid_asbid_sid_hash}->{$search_batch_id}->{sample_id}){
           die "ERROR no sample id for PR search_batch_id=$search_batch_id\n";
        }
        push(@atlas_search_batch_ids,
            $self->{sbid_asbid_sid_hash}->{$search_batch_id}->{atlas_search_batch_id});
    }

    my $sample_ids = join(",",@sample_ids);

    my $n_samples = $#sample_ids + 1;

    $attrs{atlas_search_batch_ids} = join(",",@atlas_search_batch_ids);

    my $pr_search_batch_ids = $attrs{search_batch_ids};

    
    # Hackish attempt to fix data truncation error.  I don't know the side 
    # effects of changing $attrs{search_batch_ids), so I am using a proxy 
    # variable.  This may just postpone an issue that will end up in  
    # mod_pep_instance...  Also unsure why we are storing search_batch_ids (pr)
    # rather than atlas_search_batch_ids (pa)  DSC 2008-05
    if ( length($attrs{search_batch_ids}) > 255 ) {
#      print STDERR "Invoking sb length limit: " . length( $pr_search_batch_ids ) . "\n";
      my $sep = '';
      $pr_search_batch_ids = '';
      for my $sbid ( @search_batch_ids ) {
        my $tmp = $pr_search_batch_ids;
        $tmp = $tmp . $sep . $sbid;
        last if length($tmp) > 255;
        $sep = ',';
        $pr_search_batch_ids = $tmp;
      }
#      print STDERR "Fixed sb length limit?: " . length( $pr_search_batch_ids ) . "\n";
    }

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
      $peptide_id = $self->insert_peptide( rowdata_ref=>\%rowdata );
        ## add new peptide_id to hash:
        $self->{peptide_acc_id_hash}->{$attrs{peptide_accession}} = $peptide_id;
    }

    my $sample_ids_cp = $sample_ids;
    if(length($sample_ids) >  255){
       #print "$sample_ids\n";
       $sample_ids =~ s/(.{255}).*/$1/;
       $sample_ids =~ s/(.*),(.*)/$1/;
       #print "truncate sample_ids to:\n$sample_ids\n";
    }

    if(length($pr_search_batch_ids) >  255){
       #print "$pr_search_batch_ids\n";
       $pr_search_batch_ids =~ s/(.{255}).*/$1/;
       $pr_search_batch_ids =~ s/(.*),(.*)/$1/;
       #print "truncate pr_search_batch_ids to:\n$pr_search_batch_ids\n";
    }
    ## print tables
    if ($self->{fh}->{peptide_instance}){
      #### Create the peptide_instance record itself
			my $fh = $self->{fh}->{peptide_instance};
			#$self->{peptide_instance}->{$attrs{peptide_sequence}} =  $self->{pk_counter}{peptide_instance};
      $self->{peptide_instance_id} = $self->{pk_counter}{peptide_instance};
			print  $fh "$self->{pk_counter}{peptide_instance}\t".
								 "$self->{atlas_build_id}\t".
								 "$peptide_id\t".
								 "$attrs{peptide_prev_aa}\t$attrs{peptide_next_aa}\t".
								 "$attrs{original_protein_name}\t$attrs{best_probability}\t".
								 "$attrs{best_adjusted_probability}\t$attrs{n_observations}\t".
								 "-1\t$sample_ids\t?\t-1\t$pr_search_batch_ids\t\t$n_samples\t\t".
								 "\t\t$attrs{n_adjusted_observations}\t$attrs{n_sibling_peptides}\t".
								 "\t\t\t$attrs{enzyme_ids}\t\t\n";

			#### Create peptide_instance_sample records
			$fh = $self->{fh}{peptide_instance_sample};
      foreach my $sample_id (split(",", $sample_ids_cp)) {
			  print  $fh "$self->{pk_counter}{peptide_instance_sample}\t".
								 "$self->{pk_counter}{peptide_instance}\t$sample_id\t".
								 $sbeamsMOD->get_current_timestamp() ."\t$self->{current_contact_id}\t".
								 $sbeamsMOD->get_current_timestamp() ."\t$self->{current_contact_id}\t" .
								 "$self->{current_work_group_id}\tN\t\n";  
			  $self->{pk_counter}{peptide_instance_sample}++;
      }

			#### Create peptide_instance_search_batch records
			$fh = $self->{fh}{peptide_instance_search_batch};
      foreach my $atlas_search_batch_id (split(",", $attrs{atlas_search_batch_ids})){
			  print  $fh "$self->{pk_counter}{peptide_instance_search_batch}\t".
								 "$self->{pk_counter}{peptide_instance}\t$atlas_search_batch_id\t". 
								 $sbeamsMOD->get_current_timestamp() ."\t$self->{current_contact_id}\t". 
								 $sbeamsMOD->get_current_timestamp() ."\t$self->{current_contact_id}\t" .
								 "$self->{current_work_group_id}\tN\t$self->{inst_obs}{$attrs{peptide_sequence}}{$atlas_search_batch_id}\n";
			  $self->{pk_counter}{peptide_instance_search_batch}++;
      }
			$self->{pk_counter}{peptide_instance}++;
    }else{
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
				search_batch_ids => $pr_search_batch_ids,
				protease_ids => $attrs{enzyme_ids},
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
				sample_ids => $sample_ids_cp,
			);
			#### Create peptide_instance_search_batch records
			&main::insert_peptide_instance_search_batches(
				peptide_instance_id => $peptide_instance_id,
				atlas_search_batch_ids => $attrs{atlas_search_batch_ids},
			);

    }
  }


  ##########################################################################
  #### If this is the peptide_instance, store it
  if ($localname eq 'modified_peptide_instance') {
    if ($attrs{peptide_string} =~ /[BZXU]/){
      print "skip $attrs{peptide_string}, invalid AA\n";
      goto SKIP;
    }

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
    my $modified_peptide_sequence = $attrs{peptide_string};
    my $peptide_sequence = $modified_peptide_sequence;
    $peptide_sequence =~ s/[\[\]nc\d]+//g;
    my $peptide_instance_id = $self->{peptide_instance_id} or 
      die("ERROR: Unable to find a valid peptide_instance_id for $peptide_sequence in the ".
	  "content handler.\n");
    if(length($sample_ids) >  255){
       $sample_ids =~ s/(.{255}).*/$1/;
       $sample_ids =~ s/(.*),(.*)/$1/;
    }

    if(length($attrs{atlas_search_batch_ids}) >  255){
       $attrs{atlas_search_batch_ids} =~ s/(.{255}).*/$1/;
       $attrs{atlas_search_batch_ids} =~ s/(.*),(.*)/$1/;
    }
    if(length($attrs{search_batch_ids}) >  255){
       $attrs{search_batch_ids} =~ s/(.{255}).*/$1/;
       $attrs{search_batch_ids} =~ s/(.*),(.*)/$1/;
    }

    if ($self->{fh}{modified_peptide_instance}){
      #### print to file
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
				fh => $self->{fh}{modified_peptide_instance},
				modified_peptide_instance_id=> $self->{pk_counter}{modified_peptide_instance},
			);
			insert_modified_peptide_instance(
				rowdata_ref=>\%rowdata,
			);

			#### Create modified_peptide_instance_sample records
			my @sample_ids = split(/,/,$sample_ids);
			my $fh = $self->{fh}{modified_peptide_instance_sample};
			foreach my $sample_id ( @sample_ids ) {
				print $fh "$self->{pk_counter}{modified_peptide_instance_sample}\t".
									"$self->{pk_counter}{modified_peptide_instance}\t$sample_id\t".
									$sbeamsMOD->get_current_timestamp()  .
									"\t$self->{current_contact_id}\t".
									$sbeamsMOD->get_current_timestamp() .
									"\t$self->{current_contact_id}\t" .
									"$self->{current_work_group_id}\tN\t\n";
				$self->{pk_counter}{modified_peptide_instance_sample}++;
			}
			#### Create modified_peptide_instance_search_batch records
			my @atlas_search_batch_id_array = split(/,/,$attrs{atlas_search_batch_ids});

			$fh = $self->{fh}{modified_peptide_instance_search_batch};
			foreach my $atlas_search_batch_id ( @atlas_search_batch_id_array ){
					print $fh "$self->{pk_counter}{modified_peptide_instance_search_batch}\t".
										"$self->{pk_counter}{modified_peptide_instance}\t".
										"$atlas_search_batch_id\t".
										$sbeamsMOD->get_current_timestamp() .
										"\t$self->{current_contact_id}\t".
										$sbeamsMOD->get_current_timestamp() .
										"\t$self->{current_contact_id}\t" .
										"$self->{current_work_group_id}\tN\t$self->{inst_obs}{$attrs{peptide_string}}{$atlas_search_batch_id}\n";
				 $self->{pk_counter}{modified_peptide_instance_search_batch}++;   
			}
			$self->{pk_counter}{modified_peptide_instance}++;
    }else{
      #### insert to db
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
  }
  #### Increase the counters, commit, and print progress info
  $self->{counter}++;
  SKIP:
  if ($self->{counter} % 100 == 0) {
    print $self->{counter} . '...';
    if (! $self->{fh}{modified_peptide_instance}){
      &main::commit_transaction();
    }
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
# insert_modified_peptide_instance
###############################################################################
sub insert_modified_peptide_instance {
  my %args = @_;

  my $rowdata_ref = $args{'rowdata_ref'} or die("need rowdata_ref");
  my $fh = $rowdata_ref->{fh};
  # Some peptides lack sibling peptide, convert nan => 0 to keep db happy
  if ( $rowdata_ref->{n_sibling_peptides} && $rowdata_ref->{n_sibling_peptides} =~ /nan|inf/ ) {
    $rowdata_ref->{n_sibling_peptides} = 0;
  }


  #### Calculate some mass values based on the sequence
  my $modified_peptide_sequence = $rowdata_ref->{modified_peptide_sequence};
  my $peptide_charge = $rowdata_ref->{peptide_charge};

  $rowdata_ref->{monoisotopic_peptide_mass} =
    $massCalculator->getPeptideMass(
            sequence => $modified_peptide_sequence,
            mass_type => 'monoisotopic',
           );

  $rowdata_ref->{average_peptide_mass} =
    $massCalculator->getPeptideMass(
            sequence => $modified_peptide_sequence,
            mass_type => 'average',
           );

  $rowdata_ref->{monoisotopic_parent_mz} =
    $massCalculator->getPeptideMass(
            sequence => $modified_peptide_sequence,
            mass_type => 'monoisotopic',
            charge => $peptide_charge,
           );

  $rowdata_ref->{average_parent_mz} =
    $massCalculator->getPeptideMass(
            sequence => $modified_peptide_sequence,
            mass_type => 'average',
            charge => $peptide_charge,
           );

  #### INSERT the record
  print $fh "$rowdata_ref->{modified_peptide_instance_id}\t".
						"$rowdata_ref->{peptide_instance_id}\t".
						"$modified_peptide_sequence\t$peptide_charge\t".
						"$rowdata_ref->{monoisotopic_peptide_mass}\t".
						"$rowdata_ref->{average_peptide_mass}\t".
						"$rowdata_ref->{monoisotopic_parent_mz}\t".
						"$rowdata_ref->{average_parent_mz}\t".
						"$rowdata_ref->{best_probability}\t".
						"$rowdata_ref->{best_adjusted_probability}\t" .
						"$rowdata_ref->{n_observations}\t" .
						"$rowdata_ref->{sample_ids}\t" .
						"$rowdata_ref->{search_batch_ids}\t" .
						"$rowdata_ref->{n_adjusted_observations}\t" .
						"$rowdata_ref->{n_sibling_peptides}\t\t\t\n"; 

} # end insert_modified_peptide_instance


###############################################################################
# insert_peptide
###############################################################################
sub insert_peptide {
  my $self = shift;
  my %args = @_;

  my $rowdata_ref = $args{'rowdata_ref'} or die("need rowdata_ref");

  my $sequence = $rowdata_ref->{peptide_sequence};
  my $mw =  $massCalculator->getPeptideMass( mass_type => 'monoisotopic',
                                              sequence => $sequence );

  my $pI = $sbeamsMOD->calculatePeptidePI( sequence => $sequence );

  my $hp;
  if ($SSRCalculator->checkSequence($sequence)) {
    $hp = $SSRCalculator->TSUM3($sequence);
  }

  $rowdata_ref->{molecular_weight} = $mw;
  $rowdata_ref->{peptide_isoelectric_point} = $pI;
  $rowdata_ref->{SSRCalc_relative_hydrophobicity} = $hp;

  my $peptide_id = $sbeams->updateOrInsertRow(
    insert=>1,
    table_name=>$TBAT_PEPTIDE,
    rowdata_ref=>$rowdata_ref,
    PK => 'peptide_id',
    return_PK => 1,
  );

  return($peptide_id);

} # end insert_peptide



1;
