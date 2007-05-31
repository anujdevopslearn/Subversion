{package SBEAMS::Glycopeptide::Get_glyco_seqs;
	

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

use Bio::Graphics;
use Bio::SeqIO;
use Bio::SeqFeature::Generic;
use Bio::Annotation::Collection;
use Bio::Annotation::Comment;
use Bio::Annotation::SimpleValue;

use Data::Dumper;

use SBEAMS::Glycopeptide::Glyco_query;

use base qw(SBEAMS::Glycopeptide::Glyco_query);		

use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::PeptideAtlas::Tables;
use SBEAMS::Glycopeptide;
use SBEAMS::Glycopeptide::Tables;
use SBEAMS::Glycopeptide::Test_glyco_data;
use SBEAMS::Glycopeptide::Get_peptide_seqs;

my $glyco = SBEAMS::Glycopeptide->new();

##############################################################################
#constructor
###############################################################################
sub new {
  my $method = 'new';
  my $this = shift;
  my $class = ref($this) || $this;
  my %args = @_;
    
  my $ipi_data_id = $args{ipi_data_id};
  die( "Must provide IPI data id ('$ipi_data_id')") if !$ipi_data_id;
    
  my $self = {_ipi_data_id => $ipi_data_id};
  bless $self, $class;

  # global $sbeams NMF, but not able to deal with it now...
  $sbeams ||= $self->getSBEAMS();

  $self->get_protein_info(); 
  return($self);
}

###############################################################################
# Receive the main SBEAMS object
###############################################################################
sub setSBEAMS {
    my $self = shift;
    my $sbeams = shift;
    $self->{_sbeams} = $sbeams;
    return($sbeams);
}


###############################################################################
# Provide the main SBEAMS object
###############################################################################
sub getSBEAMS {
    my $self = shift;
    return $self->{_sbeams} || SBEAMS::Connection->new();
}
###############################################################################
#get_ipi_data_id
###############################################################################
sub get_ipi_data_id {
    my $self = shift;
    
    return $self->{_ipi_data_id};
}

###############################################################################
#ipi_accession
###############################################################################
sub ipi_accession {
  my $method = 'ipi_accession';
  my $self = shift;
  my $accession = shift;
    
  if ($accession){# it's a setter
      # it's a good setter.  it should be like IPI001234
#    	if ($accession =~ /^IPI\d+$/){
    $self->{_ipi_accession_number} = $accession;
#    	}else{
#    		confess(__PACKAGE__ . "::$method BAD IPI ACCESSION NUMBER '$accession'\n"); 
#   	}
    
  }else{#it's a getter
    return $self->{_ipi_accession_number}
  } 
  
}

###############################################################################
#seq_info
#get/set the Bio::Seq Obj for this glyco object
###############################################################################
sub seq_info {
    my $method = 'seq_info';
    my $self = shift;
    my $seq_obj = shift;
    if ($seq_obj){# it's a setter
    	if (ref($seq_obj)){#it's a good setter.  it should be a bio::seq object
    		$self->{_seq_info} = $seq_obj;
    	}else{
    		confess(__PACKAGE__ . "::$method Need Seq Object '$seq_obj' is not  \n"); 
    	}
    
    }else{#it's a getter
    	return $self->{_seq_info}
   } 
}


###########################################
#Given an IPI number produce a Bio::Seq object and make it accessible via the seq_info method
# All the predicted peptides, identified peptides, TM, Signal
# Features Mapped on.  Also Have annotation put into the seq object
##########################################
sub get_protein_info {
	my $method = 'get_protein_info';
	my $self = shift; 
	my %args = @_;
	
	$self->get_ipi_data();
	
	$self->add_predicted_peptides();
#	$self->add_identified_peptides();
	$self->add_observed_peptides();
	$self->add_signal_sequence();
	$self->add_transmembrane_domains();
	$self->add_cellular_location();
  if ( $glyco->get_current_motif_type() eq 'glycopeptide' ) {
	  $self->add_glyco_site();
  } else {
	  $self->add_phospho_site();
  }
  return;
}



############################################
#Given an IPI number query the database and return 
# Return 1 for completion or die;
# The Bio::seq object is accessible via the seq_info method
#########################################
sub get_ipi_data {
	my $method = 'get_ipi_data';
	my $self = shift;
	my $ipi_acc = $self->ipi_accession();
	
	my $ipi_data_id = $self->get_ipi_data_id;
	my $results_set_href = $self->query_ipi_data($ipi_data_id);
	$self->add_query_results($results_set_href);
	
	
	my $seq = Bio::Seq->new(
        	-display_id => $ipi_acc,
        	-seq        => $self->raw_protein_sequence,
	);
	
		
	#add the annotation data
	my $protein_name = Bio::Annotation::Comment->new;
	my $symbol 		= new Bio::Annotation::SimpleValue(-value => $self->protein_symbol);
	my $swiss_prot 	= new Bio::Annotation::SimpleValue(-value => $self->swiss_prot_acc);
	my $synonyms	= Bio::Annotation::Comment->new;
	my $summary		= Bio::Annotation::Comment->new;
	
	
	
	
	$protein_name->text($self->protein_name);
	$synonyms->text($self->synonyms);
	$summary->text($self->protein_summary);
	

	my $coll = new Bio::Annotation::Collection();
	$coll->add_Annotation('protein_name', $protein_name);
	$coll->add_Annotation('symbol', $symbol);
	$coll->add_Annotation('swiss_prot', $swiss_prot);
	$coll->add_Annotation('synonyms', $synonyms);
	
	$coll->add_Annotation('summary', $summary);
	
	

	$seq->annotation($coll);	
	$self->seq_info($seq);
	
	return 1;

}

#######################################################
# Given a peptide_obj, get the main protein bioseq and add 
# the position for the predicted N-link glyco site.
#this method is here because of the way the data was setup
#return 1 for success 0 for everything else
#######################################################
sub add_phospho_site{
	my $method = 'add_phospho_site';
	my $self = shift;
	my $ipi_data_id = $self->get_ipi_data_id;
	my $seq_obj = $self->seq_info;
  my $sequence = $seq_obj->seq();
	
  if ( 0 ) {
    my $sites = $glyco->get_site_positions(    pattern => 'S|T|Y',
                                            index_base => 1,
                                                   seq => $sequence );
  		
    for my $site ( @$sites ) {
  		my $feature = Bio::SeqFeature::Generic->new( -start => $site,
                                                   -end   => $site,
                                                   -primary => "Phosphorylation Sites" );
  		
  		#add all the feature to the protein Bio::Seq object
  		$seq_obj->add_SeqFeature($feature);
    }
  } else {
    my @peptides = $self->get_observed_phosphopeptides($ipi_data_id);
#    for my $peptide ( @peptides ) { for my $k (keys(%$peptide) ) { $log->debug( "$k => $peptide->{$k}" ); } die; }
    for my $peptide ( @peptides ) { 

      # Temporary, will break if we have both a certain and an ambiguous site
      # in the same peptide
      my $motif_type;
      if ( $peptide->{observed_peptide_sequence} =~ /\*/ ) {
        $motif_type = '\*';
      } else {
        $motif_type = '\&';
      }
      my $site_in_pep = $glyco->get_site_positions( pattern => $motif_type,
                                                       seq => $peptide->{observed_peptide_sequence} );

#      $log->debug( "for sequence $peptide->{observed_peptide_sequence}, we see " . join( ', ', @$site_in_pep ) );
      $peptide->{observed_peptide_sequence} =~ s/$motif_type//g;
      my $pep_in_prot =  $glyco->get_site_positions( pattern => $peptide->{observed_peptide_sequence},
                                                         seq => $sequence );
      my $dec = 0;
      my $tag_type = ( $motif_type =~ /\*/ ) ? 'Phosphorylation Sites' : 'Ambiguous Phosphorylation Sites';
#      $log->debug( "Tag type is $tag_type for $peptide" );
      foreach my $pip ( @$pep_in_prot ) {
#        $log->debug( "peptide maps at $pip" );
        foreach my $sip ( @$site_in_pep ) {
#          $log->debug( "site maps at $sip" );
          my $coord = $pip + $sip - $dec;
#          $log->debug( "Site at $coord, the amino acid is " . substr( $sequence, $coord, 1 ) );
  		    my $feature = Bio::SeqFeature::Generic->new( -start => $coord,
                                                       -end   => $coord,
                                                     -primary => $tag_type );
  		
      		#add all the feature to the protein Bio::Seq object
          $seq_obj->add_SeqFeature($feature);
          $dec++;
        }
      }
    }
  }
}
  
  
#######################################################
#add_glyco_site
# Given a peptide_obj, get the main protein bioseq and add 
# the position for the predicted N-link glyco site.
#this method is here because of the way the data was setup
#return 1 for success 0 for everything else
#######################################################
sub add_glyco_site{
	my $method = 'add_glyco_site';
	my $self = shift;
	my $ipi_data_id = $self->get_ipi_data_id;
	my @array_hrefs = $self->get_glyco_sites($ipi_data_id);
	return 0 unless @array_hrefs;
	my $seq_obj = $self->seq_info;
	
	foreach my $href (@array_hrefs){ 
		
		
		my $location = $href->{'protein_glycosite_position'};
		my $glyco_score = $href->{'glyco_score'};
		
		my $glyco = Bio::SeqFeature::Generic->new(
									-start        => $location,
									-end          => $location +2,
									-primary 	  => "N-Glyco Sites", 
									-tag 		  =>{glyco_score => sprintf("%01.2f",$glyco_score)
						 							 },
						);
		
		
		#add all the feature to the protein Bio::Seq object
		$seq_obj->add_SeqFeature($glyco);
	}
	return 1;
}

# ###########################################
#Add the predicted peptide to the sequence 
#########################################
sub add_signal_sequence {
	my $method = 'add_signal_sequence';
	my $self = shift;
	my $signal_sequence_info = $self->signal_sequence_info;
# 42 N 0.002 N
	$signal_sequence_info =~ /(\d+) (\w) (\d\.\d+) (\w)/;
  my $end = $1;
  my $cleaved = $2;
  my $signal = $4;
  return if $signal =~ /N/i;
  my $type = ( $cleaved =~ /Y/i ) ? 'Signal Sequence' : 'Anchor';
  
  my $sigseq = Bio::SeqFeature::Generic->new( -start        => 1,
                                              -end          => $end,
                                              -display_name => $type ,
                                              -primary      => $type,
                                              -tag          => { $type => $type } 
                                        );

  $self->seq_info()->add_SeqFeature($sigseq);
}
# ###########################################
#Add the transmembrane domains sequence 
#########################################
sub add_transmembrane_domains {
	my $method = 'add_transmembrane_domains';
	my $self = shift;
	my $tmhmm_info = $self->transmembrane_info();
	my $seq = $self->raw_protein_sequence();
	
	#examples o528-550i, 'o408-430i447-469o555-577i584-606o652-674i785-807o', 'o'
  my $tm_sites = $glyco->get_transmembrane_info( tm_info => $tmhmm_info, end => length( $seq ) );
	
	my $seq_obj = $self->seq_info();
	
  foreach my $region (@$tm_sites) {
    my $primary = ( $region->[0] eq 'tm' ) ? 'Transmembrane' : $region->[0];
    my $tag = ( $region->[0] eq 'tm' ) ? 'TMHMM' : $region->[0];
		
    my $tmhmm_f = Bio::SeqFeature::Generic->new(
                                 -start        => $region->[1],
                                 -end          => $region->[2] ,
                                 -primary          => $primary,
                                 -tag              => { $primary => $tag }
                                               );

		$seq_obj->add_SeqFeature($tmhmm_f);

	}
	
	
	
		
	
}

############################################
#Add add the pepredicted peptide seqs to the seq obj
#########################################
sub add_predicted_peptides {
	my $method= 'add_predicted_peptides';
	my $self = shift;
	my $ipi_data_id = $self->get_ipi_data_id;
	my @array_hrefs = $self->get_predicted_peptides($ipi_data_id);
	
	
	my $pep_o = new SBEAMS::Glycopeptide::Get_peptide_seqs(glyco_obj => $self);
	

	$pep_o->make_peptide_bio_seqs(data => \@array_hrefs,
								  type => 'Predicted Peptides',	
								);
	

}

# ###########################################
#Add add the identified peptide seqs to the seq obj
#########################################
sub add_identified_peptides {
	my $method= 'add_identified_peptides';
	my $self = shift;
	my $ipi_data_id = $self->get_ipi_data_id;
	my @array_hrefs = $self->get_identified_peptides($ipi_data_id);
	
	my $pep_o = new SBEAMS::Glycopeptide::Get_peptide_seqs(glyco_obj => $self);
	
#  $pep_o->make_peptide_bio_seqs( data => \@array_hrefs,
#                                 type => 'Identified Peptides' );
 
  die ( 'Should not be here' );
  $pep_o->make_peptide_bio_seqs( data => \@array_hrefs,
                                 type => 'Observed Peptides' );
}

sub add_observed_peptides {
	my $self = shift;
	my $ipi_data_id = $self->get_ipi_data_id;
	my @array_hrefs;
	my $pep_o = new SBEAMS::Glycopeptide::Get_peptide_seqs(glyco_obj => $self);
  
  if ( $glyco->get_current_motif_type() =~ /glyco/ ) {
    @array_hrefs = $self->get_observed_peptides($ipi_data_id);
  } else {
    @array_hrefs = $self->get_observed_phosphopeptides($ipi_data_id);
  }

  $pep_o->make_peptide_bio_seqs( data => \@array_hrefs, type => 'Observed Peptides' );
	
  return;
}


#########################################################
#make_url
#Give key value pairs term => $serach_term, dbxref_tag => tag_val
#return a url composed of <accessor>$search_term<accessor_suffix>
#######################################################
sub make_url {
  my $self = shift;
  my %args = @_;
  my $term = $args{'term'};
  my $xref_tag = $args{'dbxref_tag'};

  return 0 unless($term && $xref_tag);

  my $sql = qq~   SELECT accessor, accessor_suffix
                  FROM $TB_DBXREF
                  WHERE dbxref_tag = '$xref_tag'
  ~;
  my ($href) = $sbeams->selectHashArray($sql);
  my $url = $href->{accessor} . $term . $href->{accessor_suffix};
  $url =~ s/ /+/g;	#repalce any spaces with a plus.  Needed for EBI_IPI to work
  $url = "<a href='$url'>$term</a>";

}

###############################################################################
#sorted_freatures
#Sort and array of features based on their primary tag
###############################################################################
sub sorted_freatures {
	my $method = 'sorted_freatures';
	my $self = shift;
	
	my $count = 0;
	#foreach my $f (@_){
		
	#	$count ++;
	#}
	
	my @sorted_features =  map { $_->[0] }
						   sort { $a->[1] cmp $b->[1]
						   				||
								$a->[2] <=> $b->[2]
                           } 
                          map { [$_, $_->primary_tag, $_->seq_id] } @_;
    
    my $count = 0;

    
    return @sorted_features;
 
}
###############################################################################
#get_html_protein_seq
#make a nice protein sequence suitable to print out
###############################################################################
sub get_html_protein_seq {
  my $method = 'get_html_protein_seq';
  my $self = shift;

  my $motif = $glyco->get_current_motif_type();
  my %args = @_;
	
  my $seq = $args{seq};
  my $ref_parameters = $args{'ref_parameters'};
	
  unless(ref($seq)){
    $seq = $self->seq_info();
  }	

  my $aa_seq = $seq->seq();
  my @array_of_arrays = $self->make_array_of_arrays($seq);

    
  my @sorted_features = $self->sorted_freatures($seq->all_SeqFeatures);# descend into sub features
        
  for my $f (@sorted_features) {
    my $tag = $f->primary_tag;
			
    #subtract one since we are indexing into a zero based array
    my $start =  $f->start - 1;
    my $end =  $f->end - 1;

    # FIXME FIXME FIXME - cruel hack for the sake of time

    if ( $glyco->get_current_motif_type() =~ /phospho/ && $tag !~ /Phosphor/ ) {
      $start -= 1;
      $end += 1; 
    }
      
            
    my ($name, $title) = _choose_css_type( tag  => $tag,
                                         params => $ref_parameters,
                                          start => $start );
    next unless $name;
    $log->debug( "Tag is $tag, starts at " . $f->start() . ", ends at " . $f->end() );

    if ( !$title ) {
      $title = $tag;
      $title =~ s/s$//;
      if ( $f->start() ) {
        $title .= " " . $f->start() . '-' . $f->end();
      }
    }

    my $css_class = $name || 'sequence_font';

    if ( $args{prechecked} ) {
      $css_class = 'sequence_font' if !grep( /$name/i, @{$args{prechecked}} )
    }

    my $start_tag = "<span class='$css_class' TITLE='$title' NAME=$name ID=$name>";
    my $end_tag   = "</span>";
    unshift @{$array_of_arrays[$start]}, $start_tag;
    push @{$array_of_arrays[$end]}, $end_tag;
  
  }
  #print( Dumper(\@array_of_arrays));
  my $string = $self->flatten_array_of_arrays(@array_of_arrays);
  return  $string;
}

#########################################
#_choose_css_type
#########################################
sub _choose_css_type {
	my %args = @_;
	
	my $params = $args{'params'};
	my $start = $args{start} + 1;

  my %classes = ( 'Predicted Peptides'  => 'predicted_pep',
                  'Identified Peptides' => 'identified_pep',
                  'Observed Peptides' => 'observed_pep',
                  'N-Glyco Sites'       => 'glyco_site',
                  'Phosphorylation Sites' => 'phospho',
                  'Ambiguous Phosphorylation Sites' => 'ambiphospho',
                  'Signal Sequence'     => 'sseq',
                  'Transmembrane'       => 'tmhmm',
                  intracellular         => '',
                  extracellular         => '',
                );

  if ( $args{tag} =~ /Predicted/ ) {
   return ( '','' ) if $glyco->get_current_motif_type() =~ /phospho/;
  }

	my $tag = $classes{$args{tag}};
	my %title = ( glyco_site => "Glyco Site $start" );
	
  if ( $args{tag} eq 'N-Glyco Sites' ) {
    return ($tag, $title{$tag} );
  } elsif ( $params->{redraw_protein_sequence} ) {
    return ( '', '' ) unless $params->{$classes{$args{tag}}};
  }
	return ($tag, $title{$tag} );

}

#################################################
#make_array_of_arrays
#################################################
sub make_array_of_arrays {
        my $self = shift;
	my $seq_o = shift;
	unless (ref($seq_o)){
	   $seq_o = $self->seq_info();
        }
	my @aa_seq = split //, $seq_o->seq;
        my @array_of_arrays = ();
        my $fsa_char_count = 60; #also break up sequence into 60 char lines
        my $count = 0;
        foreach my $aa (@aa_seq){
                if ($count == $fsa_char_count){
                        $count = 0;

                        push @array_of_arrays, ['<br>', $aa];
                }else{
                        push @array_of_arrays, [$aa];
                }
		$count ++;
        }
        #print Dumper(\@array_of_arrays);

        return @array_of_arrays;
}

###############################################
#flatten_array_of_arrays
##############################################
sub flatten_array_of_arrays{
        my $self = shift;
	my @array_of_arrays = @_;
        my @flat_array = ();
        foreach my $aref ( @array_of_arrays){
              # if (ref($aref)){ #for some reason undef elements are finding their way into the array this does not seem good and needs to be fixed
		push @flat_array, @{$aref} if ref( $aref); #FIX ME IF THE GLYCO SITE EXTENTS BEYOND THE TRYPTIC SITE WE HAVE AN ERROR
	#	}
        }
        my $string = join "", @flat_array;
        return $string;
}
###############################################
#add_cellular_location
##############################################
sub add_cellular_location{
	my $method = 'add_cellular_location';
	my $self = shift;
	my $seq_obj = $self->seq_info;
	
	my $location = $self->cellular_location_name;
	
	my $coll = $seq_obj->annotation();
	my $cellualar_loc_obj 	= new Bio::Annotation::SimpleValue(-value => $location);	
	 
	$coll->add_Annotation('cellular_location', $cellualar_loc_obj);
	$seq_obj->annotation($coll);
}

##############################################
#add_query_results
#given a href from a sql query add the data to the object
##############################################
sub add_query_results{
	my $method = 'add_query_results';
	my $self = shift;
	my $href = shift;
	
	$self->ipi_accession($href->{'ipi_accession_number'});
    $self->protein_name($href->{'protein_name'});
    $self->protein_symbol($href->{'protein_symbol'});
    $self->swiss_prot_acc($href->{'swiss_prot_acc'});
    $self->cellular_location_name($href->{'cellular_location_name'});
    $self->protein_summary($href->{'protein_summary'});
    $self->raw_protein_sequence($href->{'protein_sequence'});
    $self->transmembrane_info($href->{'transmembrane_info'});
    $self->signal_sequence_info($href->{'signal_sequence_info'});
    $self->synonyms($href->{'synonyms'});
   
}

##############################################
#get/set 
#protein_name
##############################################
sub protein_name {
    my $method = 'protein_name';
    my $self = shift;
    my $info = shift;
    if ($info){# it's a setter
    	$self->{_protein_name} = $info;
    }else{#it's a getter
    	return $self->{_protein_name};
   } 
}

##############################################
#get/set 
#protein_symbol
##############################################
sub protein_symbol {
    my $method = 'protein_symbol';
    my $self = shift;
    my $info = shift;
    if ($info){# it's a setter
    	$self->{_protein_symbol} = $info;
    }else{#it's a getter
    	return $self->{_protein_symbol};
   } 
}
##############################################
#get/set 
#swiss_prot_acc
##############################################
sub swiss_prot_acc {
    my $method = 'swiss_prot_acc';
    my $self = shift;
    my $info = shift;
    if ($info){# it's a setter
    	$self->{_swiss_prot_acc} = $info;
    }else{#it's a getter
    	return $self->{_swiss_prot_acc};
   } 
}
##############################################
#get/set 
#cellular_location_name
##############################################
sub cellular_location_name {
    my $method = 'cellular_location_name';
    my $self = shift;
    my $info = shift;
    if ($info){# it's a setter
    	$self->{_cellular_location_name} = $info;
    }else{#it's a getter
    	return $self->{_cellular_location_name};
   } 
}
##############################################
#get/set 
#protein_summary
##############################################
sub protein_summary {
    my $method = 'protein_summary';
    my $self = shift;
    my $info = shift;
    if ($info){# it's a setter
    	$self->{_protein_summary} = $info;
    }else{#it's a getter
    	return $self->{_protein_summary};
   } 
}
##############################################
#get/set 
#raw_protein_sequence
##############################################
sub raw_protein_sequence {
    my $method = 'raw_protein_sequence';
    my $self = shift;
    my $info = shift;
    if ($info){# it's a setter
    	$self->{_raw_protein_sequence} = $info;
    }else{#it's a getter
    	return $self->{_raw_protein_sequence};
   } 
}
##############################################
#get/set 
#transmembrane_info
##############################################
sub transmembrane_info {
    my $method = 'transmembrane_info';
    my $self = shift;
    my $info = shift;
    if ($info){# it's a setter
    	$self->{_transmembrane_info} = $info;
    }else{#it's a getter
	return $self->{_transmembrane_info};
	
   } 
}
#############################################
#has_transmembrane_seq
##############################################
sub has_transmembrane_seq {
    my $method = 'has_transmembrane_seq';
    my $self = shift;
    if($self->{_transmembrane_info} eq 'o'){
	return 0;
    }else{
	return 1;

   }
}

##############################################
#get/set 
#signal_sequence_info
##############################################
sub signal_sequence_info {
    my $method = 'signal_sequence_info';
    my $self = shift;
    my $info = shift;
    if ($info){# it's a setter
    	$self->{_signal_sequence_info} = $info;
    }else{#it's a getter
    	return $self->{_signal_sequence_info};
   } 
}
##############################################
#has_signal_sequence
##############################################
sub has_signal_sequence {
    my $method = 'has_signal_sequence';
    my $self = shift;
    if($self->{_signal_sequence_info} =~ m/Y$/ ){
	return 1;		
    }else{
	return 0;
   }
}


##############################################
#get/set 
#synonyms
##############################################
sub synonyms {
    my $method = 'synonyms';
    my $self = shift;
    my $info = shift;
    if ($info){# it's a setter
    	$self->{_synonyms} = $info;
    }else{#it's a getter
    	return $self->{_synonyms};
   } 
}



###############################################
#display_peptides
##############################################
sub display_peptides{
  my $method = 'display_peptides';
  my $self = shift;
	my $type = shift;
	
	my $html = '';
	my $seq_obj = $self->seq_info;

	my @features = $seq_obj->all_SeqFeatures;

### partition features by their primary tags
        my %sorted_features;
        for my $f (@features) {
                my $tag = $f->primary_tag;
                #print "FEATURE PRIMARY TAG '$tag'\n<br>";
                push @{ $sorted_features{$tag} }, $f;
        }
	
	if ($type eq 'Predicted Peptides'){
		$html .= $self->predicted_pep_html($sorted_features{$type});
	}elsif($type eq 'Observed Peptides'){
		if (exists $sorted_features{$type}){
			$html .= $self->identified_pep_html($sorted_features{$type});
		}else{
			$html .= $self->nothing_found_html($type);
		}
		
	}elsif($type eq 'Observed Phosphopeptides'){
		if (exists $sorted_features{'Observed Peptides'}){
			$html .= $self->phospho_pep_html($sorted_features{'Observed Peptides'});
		}else{
			$html .= $self->nothing_found_html($type);
		}
		
	}
	
	return $html;
}

###############################################
#nothing_found_html
##############################################
sub nothing_found_html{
    my $method = 'nothing_found_html';
    my $self = shift;
	my $type = shift;
	
	my $info = "-- No Data found for <i>$type</i> --";
	return $info;
}

###############################################
#predicted_pep_html
##############################################
sub predicted_pep_html{
    my $method = 'predicted_pep_html';
    my $self = shift;
	my $features_aref = shift;
	my $synth = ( $sbeams->isGuestUser() ) ? '' : $q->td( text_class("Synthesized Peptide") );
	
	my $html  = "<table>";
	$html .= join( "\n", $q->Tr({class=>'rev_gray_head'},
			       $q->td( {NOWRAP => 1}, $self->linkToColumnText(
			       				display => "NXS/T Location",
						    		title   =>"Glyco Site Location within the protein", 
								    column  =>"protein_glyco_site_position", 
							    	table   => "AT_glyco_site" )
					         ),
			       $q->td( text_class("Predicted Sequence")),
			     	 $q->td(text_class("Predicted Mass")),
			     	 $q->td( {NOBR => 1}, text_class("# Proteins with Peptide")),
             $synth )
			     );

my $foo=<<'  END';
			     	$q->td($self->linkToColumnText(
			       				display => "NXS/T Score",
								title   => "Likelihood of NXS/T sequon", 
								column  => "glyco_score", 
								table   => "AT_glyco_site" ,
								),
					),
					),
			     	  $q->td($self->linkToColumnText(
			     			display => "Detection Probability",
								title   => "Likelihoop of detecting peptide in MS", 
								column  => "detection_probability", 
								table   => "AT_predicted_peptide", 
								),
  END
	
	foreach my $f (@{$features_aref}){
		my $start = $f->start;
		my $seq = $f->seq;
		
		my $id = '';
		my $first_aa = 'X';
		my $end_aa = 'X';
		my $html_seq = '';
		my $detection_prop = '-1';
		my $database_hits = '-1';
		my $ipi_hits = '-1';
		my $ipi_ids = '--';
		my $protein_sim = '1';
		my $predicted_mass = 0;
		my $glyco_score = 0;
		my $protein_glyco_site = 1;		
		my $synthesized_seq = '';		
		
		
		if ($f->has_tag('Peptide_seq_obj')){

            my $pep_seq_obj = $self->extract_first_val(feature => $f, tag => 'Peptide_seq_obj');
            $id = $pep_seq_obj->display_id;
			my @all_peptide_features = $pep_seq_obj->all_SeqFeatures;
			my $feature_href = $self->make_features_hash(@all_peptide_features);
			if (exists $feature_href->{'Start_end_aa'}){
				$first_aa = $self->extract_first_val(feature => $feature_href->{'Start_end_aa'}->[0], 
													 tag => 'start_aa');
				$end_aa = $self->extract_first_val(feature => $feature_href->{'Start_end_aa'}->[0], 
												   tag => 'end_aa');
			
			}
			
			$html_seq = $self->get_html_protein_seq(seq => $pep_seq_obj);
			$glyco_score = $self->get_annotation(seq_obj =>$pep_seq_obj, 
									 anno_type => 'glyco_score');
			$protein_glyco_site =  $self->get_annotation(seq_obj =>$pep_seq_obj,
                                                   anno_type => 'protein_glyco_site');
			$detection_prop = $self->get_annotation(seq_obj =>$pep_seq_obj, 
									 anno_type => 'detection_probability');
			$database_hits = $self->get_annotation(seq_obj =>$pep_seq_obj, 
									 anno_type => 'number_proteins_match_peptide');
			$ipi_ids = $self->get_annotation(seq_obj =>$pep_seq_obj, 
									 anno_type => 'database_hits_ipi_ids');
			$predicted_mass = $self->get_annotation(seq_obj =>$pep_seq_obj, 
									 anno_type => 'predicted_mass');
			$protein_sim = $self->get_annotation(seq_obj =>$pep_seq_obj, 
									 anno_type => 'protein_similarity_score');
			$synthesized_seq = $self->get_annotation( seq_obj =>$pep_seq_obj, 
									                        anno_type => 'synthesized_seq') unless $sbeams->isGuestUser();
#      use Data::Dumper;
#      my $dump = Dumper( $feature_href );
#      $dump =~ s/\n/\<BR\>/g;
#      print $dump;
#      exit;
					
		}
## Detmine what to do with the number of other protein database hits
	
		my $hit_link = '1';
		if ($database_hits > 1){
			my $script = $q->script_name();
			$hit_link = "<a href='$script?action=Show_hits_form&search_type=IPI Accession Number&search_term=$ipi_ids&similarity_score=$protein_sim'>$database_hits Hits</a>";
		}
		
### Start writing some html that can be returned
				#$q->td({align=>'center'}, $glyco_score),

		 $html .= join( "\n", $q->Tr(
				$q->td($protein_glyco_site),
				$q->td("$first_aa.$html_seq.$end_aa"),
				$q->td({align=>'center'},$predicted_mass),
				$q->td({align=>'center'},$hit_link),
				$q->td({align=>'center'},$synthesized_seq),
        )
			     );

		}
    my $excess =<<'      END';
				$q->td({align=>'center'},$detection_prop),
      END
	$html .= "</table>";
	return $html;
}


sub text_class {
  my $text = shift;
  return "<SPAN CLASS=rev_gray_head>$text</SPAN>";
}

###############################################
#phospho_pep_html
##############################################
sub phospho_pep_html{
        my $method = 'phospho_pep_html';
        my $self = shift;
	my $features_aref = shift;
	
	#start the HTML
	my $html  = "<table>\n";
  $html .= join( "\n", $q->Tr( {class=>'rev_gray_head'},
			        $q->td(text_class("Identifed Sequence")),
			     	$q->td($self->linkToColumnText(
			       				display => "PeptideProphet",
								title   => "PeptideProphet Score: 1 Best, 0 Worst", 
								column  => "peptide_prohet_score", 
								table   => "AT_identified_peptide" 
								)
			     	
			     	),
			     	$q->td(text_class("Tryptic Ends")),
			     	$q->td(text_class("Peptide Mass")),
			     	$q->td(text_class("DeltaCN")),
			     	$q->td(text_class("# Obs")),
			     	$q->td(text_class("Links")),
              ) # End Tr
			     ); # End join
				 
	
  my $cutoff = $self->get_current_prophet_cutoff();
			      
	foreach my $f (@{$features_aref}){
		my $start = $f->start;
		my $seq = $f->seq;
		
		my $id = '';
		my $first_aa = 'X';
		my $end_aa = 'X';
		my $html_seq = '';
		my $tryptic_end = '-1';
		my $peptide_prophet_score = '-1';
		my $peptide_mass = '1';
		my $observed_seq = '1';
		my $num_obs = '1';
		my $delta_cn = 0;
		my $protein_glyco_site = 1;
		
    my $gb = '';
    my $ge = '';
		
    my $atlas_link = '';
    my $spectrum_link = '';

		if ($f->has_tag('Peptide_seq_obj')){

      my $pep_seq_obj = $self->extract_first_val( feature => $f, 
                                                  tag => 'Peptide_seq_obj');

      my $pp_value = $self->extract_data_value( obj => $pep_seq_obj,
                                                tag => 'peptide_prophet_score' );

      $gb = ( $pp_value >= $cutoff ) ? '' : '<I><FONT COLOR=#AAAAAA>';
      $ge = ( $pp_value >= $cutoff ) ? '' : '</FONT></I>';


      $id = $pep_seq_obj->display_id;
			my @all_peptide_features = $pep_seq_obj->all_SeqFeatures;
			my $feature_href = $self->make_features_hash(@all_peptide_features);
			
			if (exists $feature_href->{'Start_end_aa'}){
				$first_aa = $self->extract_first_val(feature => $feature_href->{'Start_end_aa'}->[0], 
													 tag => 'start_aa');
				$end_aa = $self->extract_first_val(feature => $feature_href->{'Start_end_aa'}->[0], 
												   tag => 'end_aa');
			}
			
			$html_seq = $self->get_html_protein_seq(seq => $pep_seq_obj);

      # Get link to peptide atlas
      my $aa_value = $html_seq;
      $aa_value =~ s/<[^>]+>//g;

      $atlas_link = $self->get_atlas_link( seq => $aa_value, onmouseover => "Search for peptide in Peptide Atlas" );

			$protein_glyco_site =  $self->get_annotation(seq_obj =>$pep_seq_obj,
                                                                         anno_type => 'protein_glyco_site');
			$tryptic_end = $self->get_annotation(seq_obj =>$pep_seq_obj, 
									 anno_type => 'tryptic_end');
			$peptide_prophet_score = $self->get_annotation(seq_obj =>$pep_seq_obj, 
									 anno_type => 'peptide_prophet_score');
			$peptide_mass = $self->get_annotation(seq_obj =>$pep_seq_obj, 
									 anno_type => 'peptide_mass');
			$delta_cn = $self->get_annotation(seq_obj =>$pep_seq_obj, 
									 anno_type => 'delta_cn');
			$num_obs = $self->get_annotation(seq_obj =>$pep_seq_obj, 
									 anno_type => 'number_obs');
			$observed_seq = $self->get_annotation(seq_obj =>$pep_seq_obj, 
									 anno_type => 'observed_seq');
      my $spectrum_seq = $observed_seq;
      $spectrum_seq =~ s/\&/\*/g;
      $spectrum_link = '<A HREF="showSpectrum.cgi?query_peptide_seq=' . $spectrum_seq . '" TITLE="Lookup consensus spectrum" >spectrum</A>';
      $observed_seq = get_phospho_html( seq => $observed_seq );


					
		}
### Start writing some html that can be returned
#		 $tissues = ( $tissues =~ /^serum$/ ) ? 'serum' :
#		            ( $tissues =~ /serum/ ) ? 'serum, other' :
#		            ( $tissues =~ /\w/ ) ? 'other' : '';

    my $sp = '&nbsp;';
		 $html .= join( "\n", $q->Tr(
				$q->td("$gb$first_aa.$observed_seq.$end_aa$ge"),
				$q->td({ALIGN=>'right'},$gb.$peptide_prophet_score.$ge),
				$q->td({ALIGN=>'right'},$gb.$tryptic_end.$ge),
				$q->td({ALIGN=>'right'},$gb.$peptide_mass.$ge),
				$q->td({ALIGN=>'right'},$gb.$delta_cn.$ge),
				$q->td({ALIGN=>'right'},$gb.$num_obs.$ge),
#				$q->td({VALIGN=>'CENTER'},$sp.$sp.$atlas_link.$sp.'|'.$sp.$spectrum_link.$sp),
				$q->td({VALIGN=>'CENTER'},$sp.$sp.$spectrum_link.$sp),
			     )  # End Tr
         ); # End join
		}
	$html .= "</table>";
	return $html;
}

sub get_phospho_html {
  my %args = @_;
  return '' unless $args{seq};
  $args{seq} =~ s/([STY]\*)/\<SPAN class=phospho NAME=phospho ID=phospho\>$1\<\/SPAN\>/g;
  $args{seq} =~ s/([STY])\&/\<SPAN class=ambiphospho NAME=ambiphospho ID=ambiphospho\>$1\*\<\/SPAN\>/g;
  return $args{seq};
}
###############################################
#identified_pep_html
##############################################
sub identified_pep_html{
        my $method = 'identified_pep_html';
        my $self = shift;
	my $features_aref = shift;
	
	#start the HTML
	my $html  = "<table>\n";
  $html .= join( "\n", $q->Tr( {class=>'rev_gray_head'},
			       $q->td( { NOWRAP => 1 }, $self->linkToColumnText(
	       				display => "NXS/T Location",
								title   =>"Glyco Site Location within the protein", 
								column  =>"protein_glycosite_position", 
								table   => "AT_glyco_site" 
								 
								)
					),
			        $q->td(text_class("Identifed Sequence")),
			     	$q->td($self->linkToColumnText(
			       				display => "PeptideProphet Score",
								title   => "PeptideProphet Score: 1 Best, 0 Worst", 
								column  => "peptide_prohet_score", 
								table   => "AT_identified_peptide" 
								)
			     	
			     	),
			     	$q->td(text_class("Tryptic Ends")),
			     	$q->td(text_class("Peptide Mass")),
			     	$q->td(text_class("Tissues")),
			     	$q->td(text_class("# Obs")),
			     	$q->td(text_class("Atlas")),
              ) # End Tr
			     ); # End join
				 
	
  my $cutoff = $self->get_current_prophet_cutoff();
			      
	foreach my $f (@{$features_aref}){
		my $start = $f->start;
		my $seq = $f->seq;
		
		my $id = '';
		my $first_aa = 'X';
		my $end_aa = 'X';
		my $html_seq = '';
		my $tryptic_end = '-1';
		my $peptide_prophet_score = '-1';
		my $peptide_mass = '1';
		my $num_obs = '1';
		my $tissues = 'None';
		my $protein_glyco_site = 1;
		
    my $gb = '';
    my $ge = '';
		
    my $atlas_link = '';
		if ($f->has_tag('Peptide_seq_obj')){

      my $pep_seq_obj = $self->extract_first_val( feature => $f, 
                                                  tag => 'Peptide_seq_obj');

      my $pp_value = $self->extract_data_value( obj => $pep_seq_obj,
                                                tag => 'peptide_prophet_score' );

      $gb = ( $pp_value >= $cutoff ) ? '' : '<I><FONT COLOR=#AAAAAA>';
      $ge = ( $pp_value >= $cutoff ) ? '' : '</FONT></I>';


      $id = $pep_seq_obj->display_id;
			my @all_peptide_features = $pep_seq_obj->all_SeqFeatures;
			my $feature_href = $self->make_features_hash(@all_peptide_features);
			
			if (exists $feature_href->{'Start_end_aa'}){
				$first_aa = $self->extract_first_val(feature => $feature_href->{'Start_end_aa'}->[0], 
													 tag => 'start_aa');
				$end_aa = $self->extract_first_val(feature => $feature_href->{'Start_end_aa'}->[0], 
												   tag => 'end_aa');
			}
			
			$html_seq = $self->get_html_protein_seq(seq => $pep_seq_obj);

      # Get link to peptide atlas
      my $aa_value = $html_seq;
      $aa_value =~ s/<[^>]+>//g;
      $atlas_link = $self->get_atlas_link( seq => $aa_value );

			$protein_glyco_site =  $self->get_annotation(seq_obj =>$pep_seq_obj,
                                                                         anno_type => 'protein_glyco_site');
			$tryptic_end = $self->get_annotation(seq_obj =>$pep_seq_obj, 
									 anno_type => 'tryptic_end');
			$peptide_prophet_score = $self->get_annotation(seq_obj =>$pep_seq_obj, 
									 anno_type => 'peptide_prophet_score');
			$peptide_mass = $self->get_annotation(seq_obj =>$pep_seq_obj, 
									 anno_type => 'peptide_mass');
			$tissues = $self->get_annotation(seq_obj =>$pep_seq_obj, 
									 anno_type => 'tissues');
			$num_obs = $self->get_annotation(seq_obj =>$pep_seq_obj, 
									 anno_type => 'number_obs');
					
		}
### Start writing some html that can be returned
#		 $tissues = ( $tissues =~ /^serum$/ ) ? 'serum' :
#		            ( $tissues =~ /serum/ ) ? 'serum, other' :
#		            ( $tissues =~ /\w/ ) ? 'other' : '';

		 $html .= join( "\n", $q->Tr(
				$q->td($gb.$protein_glyco_site.$ge),
				$q->td("$gb$first_aa.$html_seq.$end_aa$ge"),
				$q->td($gb.$peptide_prophet_score.$ge),
				$q->td($gb.$tryptic_end.$ge),
				$q->td($gb.$peptide_mass.$ge),
				$q->td($gb.$tissues.$ge),
				$q->td($gb.$num_obs.$ge),
				$q->td({ALIGN=>'CENTER'},$gb.$atlas_link.$ge),
			     )  # End Tr
         ); # End join
		}
	$html .= "</table>";
	return $html;
}

################################
#gene_symbol_query
###############################
sub gene_symbol_query{
	my $self = shift;
	my $term = shift;
	
	my $sql = qq~ SELECT ipi_data_id, protein_name, protein_symbol 
				  FROM $TBGP_IPI_DATA 
				  WHERE protein_symbol like '$term'
		  qq~;
	return $sbeams->selectHashArray($sql);


}

#+
# get_atlas_link
#-
sub get_atlas_link {
  my $self = shift;
  my %args = @_;
  return undef unless $args{seq} || $args{name};
  my $type = $args{type} || 'image';

  my $url = '';
  if ( $args{seq} ) {
    my $key = '%' . $args{seq} . '%';
    $key = $q->escape($key);
    $url = "../PeptideAtlas/Search?organism_name=Human;search_key=$key;action=GO";
  }
  my $link;
  if ( $type eq 'image' ) {
    $link = "<A HREF='$url' TARGET=_atlas TITLE='$args{onmouseover}'><IMG BORDER=0 SRC='$HTML_BASE_DIR/images/pa_tiny.png' ALT=search></A>";
  } else {
    $link = "<A HREF='$url' TARGET=_atlas><B>S</B></A>";
  }
  return $link;
}

################################
#gene_name_query
###############################
sub gene_name_query{
	my $self = shift;
	my $term = shift;
	my $sql = qq~ SELECT ipi_data_id, protein_name, protein_symbol 
				  FROM $TBGP_IPI_DATA 
				  WHERE protein_name like '$term'
		  qq~;
	return $sbeams->selectHashArray($sql)
}

################################
#ipi_accession_query
###############################
sub ipi_accession_query{
	my $self = shift;
	my $term = shift;
	my $sql = qq~ SELECT ipi_data_id, protein_name, protein_symbol 
				  FROM $TBGP_IPI_DATA 
				  WHERE ipi_accession like '$term'
		  qq~;
	return $sbeams->selectHashArray($sql)
}

################################
#protein_seq_query
###############################
sub protein_seq_query{
	my $self = shift;
	my $seq = shift;
	
	my $sql = qq~ SELECT ipi_data_id, protein_name, protein_symbol 
				  FROM $TBGP_IPI_DATA 
				  WHERE protein_name like '%$seq%'
		  qq~;
	return $sbeams->selectHashArray($sql)
}


################################
#extract_first_val
###############################
sub extract_first_val{
	my $self = shift;
	my %args = @_;
	my $f = $args{'feature'};
	my $tag = $args{tag};

	 my @hold_vals = $f->get_tag_values($tag);
	return $hold_vals[0];

}

#+
# Klugy method to extract a data value from a bioperl annotation object.
sub extract_data_value {
  my $self = shift;
  my %args = @_;
  my $obj = $args{obj};
  my $a = $obj->{_annotation}->{_annotation};
#  for my $k ( keys( %$a ) ) { $log->info( "$k => $a->{$k}" ); }
  return $obj->{_annotation}->{_annotation}->{$args{tag}}->[0]->{value}; 
}

################################
#make_features_hash
################################
sub make_features_hash {
	my $self = shift;
	my @features = @_;
	my %sorted_features;	
	 for my $f (@features) {
                my $tag = $f->primary_tag;
                #print "FEATURE PRIMARY TAG '$tag'\n<br>";
                push @{ $sorted_features{$tag} }, $f;
        }

	return \%sorted_features;
}

######################################################
#get_annotation
######################################################
sub get_annotation {
	my $self = shift;
        my %args = @_;
        my $seq = $args{seq_obj};
	my $anno_type = $args{anno_type};

    my $info = '';

    #get an AnnotationCollectionI
        my $ac = $seq->annotation();

        #retrieves all the Bio::AnnotationI objects for one or more specific key(s).
        my @annotations = $ac->get_Annotations($anno_type);

        if ($annotations[0]){
                $info = $annotations[0]->hash_tree;
        }else{
                $info = "Cannot find Info for '$anno_type'";
        }


        return $info;
}

###############################################################################
# linkToColumnText: Creates link to popup window with column info text inside
#copied from ManageTable.pllib
# arg column text for display in popup window
# arg column name
# arg table name
# 
###############################################################################
sub linkToColumnText {
  
 
  my $self = shift;
  my %args = @_;
  my $text = $args{title};
  my $col = $args{column};
  my $table = $args{table};
  my $display_name = $args{display};
  
  
  $text = $q->escapeHTML( $text );
  my $url = "'$HTML_BASE_DIR/cgi/help_popup.cgi?column_name=$col&table_name=$table'";
  my $link =<<"  END_LINK";
  <SPAN title="$text" class="white_text" ONCLICK="popitup($url);">$display_name</SPAN>

  END_LINK
  return( $link );
} # End linkToColumnText

} #end of package
1;
