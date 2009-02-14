{package SBEAMS::Glycopeptide::Get_peptide_seqs;
	

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

use SBEAMS::Connection qw($log);

use Bio::Graphics;
use Bio::SeqIO;
use Bio::SeqFeature::Generic;
use Bio::Annotation::Collection;
use Bio::Annotation::Comment;
use Bio::Annotation::SimpleValue;

use Data::Dumper;
use SBEAMS::Glycopeptide::Get_glyco_seqs;
use SBEAMS::Glycopeptide;
use base qw(SBEAMS::Glycopeptide::Get_glyco_seqs);		

my $glyco = SBEAMS::Glycopeptide->new();



##############################################################################
#constructor
###############################################################################
sub new {
    my $method = 'new';
    my $this = shift;
    my $class = ref($this) || $this;
    my %args = @_;
    
    my $glyco_obj = $args{glyco_obj};
		
    confess(__PACKAGE__ . "::$method Must have Bio::Seq object  \n") unless ref($glyco_obj);
    
    
    my $self = {_glyco_obj => $glyco_obj};
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


###############################################################################
#get_protein_object
###############################################################################
sub get_glyco_object {
    my $self = shift;
   
    return($self->{_glyco_obj});
}


#######################################
#make_peptide_bio_seqs
##########################
sub make_peptide_bio_seqs {
	my $method = 'make_peptide_bio_seqs';
	my $self = shift;
	
	my %args = @_;
	my $data_aref = $args{data};
	my $pep_type = $args{type};

	foreach my $href (@{$data_aref}){
    next unless %$href;
#    $log->debug( "Made a $pep_type" );
#    $log->debug( join ",", keys(  %$href ) );
#    $log->debug( join ",", values(  %$href ) );
		
		my $modified_pep_seq = '';
		my $peptide_id = '';
		my $identified_tissues = '';

#    $log->printStack( 'debug' );

	#pull out the sequence and id for the different types of peptides 
   if ($pep_type eq 'Identified Peptides'){
			$modified_pep_seq = $href->{'identified_peptide_sequence'};
			$peptide_id =  $href->{'identified_peptide_id'};
			$identified_tissues = $self->identified_tissues($peptide_id);
   } elsif ($pep_type eq 'Observed Peptides'){
#    $log->debug( "Obs is $href->{observed_peptide_sequence}, match is $href->{matching_sequence}" );
			$modified_pep_seq = $href->{'observed_peptide_sequence'};
      
      # BioPerl doesn't like '&' characters in sequences.  Who knew!
      $modified_pep_seq =~ s/\&/\?/g;
      
			$peptide_id =  $href->{'observed_peptide_id'};
			$identified_tissues = $self->observed_tissues($href->{matching_sequence});
		} elsif ($pep_type eq 'Predicted Peptides'){
#    $log->debug( "Pred is $href->{predicted_peptide_sequence}, match is $href->{matching_sequence}" );
			$modified_pep_seq = $href->{'predicted_peptide_sequence'};
			$peptide_id =  $href->{'predicted_peptide_id'};
		}	
		#$log->debug(__PACKAGE__ . "::$method MODIFED PEPTIDE SEQ '$modified_pep_seq' PEPID '$peptide_id'");
		
	
		my $pep_bioseq_o = $self->parse_modified_pep_seq(pep_seq => $modified_pep_seq,
													  peptide_id => $peptide_id,
													  pep_type  => $pep_type,
                            data => $href 
													  );
		$self->add_peptide_annotation(data =>$href,
									  seq  =>$pep_bioseq_o,
									  tissue_info =>$identified_tissues);
		
		
		$self->map_pep_to_protein(pep_bioseq => $pep_bioseq_o,
							      peptide_type =>$pep_type );
		
		
	
	}
	

}
#####################################################################
#add_peptide_annotation
####################################################################
sub add_peptide_annotation{
	my $self = shift;
	my %args = @_;
#  $log->printStack();
#  $log->debug( "Called with args: " . join( ", ", keys %args ) );
	my $href = $args{data};
	my $seq  = $args{seq};
	my $tissue_info = $args{tissue_info};	

#annotation specific for identified peptides
	my $pep_prophet_score 	= new Bio::Annotation::SimpleValue(-value => sprintf("%01.2f", $href->{'peptide_prophet_score'}));
	my $peptide_mass 		= new Bio::Annotation::SimpleValue(-value => sprintf("%01.2f",$href->{'peptide_mass'}));
	my $tissues				= Bio::Annotation::Comment->new;
	
	my $number_tryptic_ends = new Bio::Annotation::SimpleValue(-value => $href->{'tryptic_end'});
	my $number_obs = new Bio::Annotation::SimpleValue(-value => $href->{'n_obs'});

  my $mappings = "<SPAN TITLE='Maps to $href->{acc_mapped} gene model(s) / $href->{gm_mapped} transcript(s)'>$href->{acc_mapped}/$href->{gm_mapped}</SPAN>";
	my $num_mappings = new Bio::Annotation::SimpleValue(-value => $mappings);
	my $gm_mappings = new Bio::Annotation::SimpleValue(-value => $href->{gm_mapped});
	my $acc_mappings = new Bio::Annotation::SimpleValue(-value => $href->{acc_mapped});

#annotation specific for predicted peptides	
	my $db_hits 	= new Bio::Annotation::SimpleValue(-value => $href->{'number_proteins_match_peptide'});
	my $db_hits_ids = Bio::Annotation::Comment->new;
	my $db_smilarity 	= new Bio::Annotation::SimpleValue(-value => sprintf("%d\%",$href->{'protein_similarity_score'} * 100));
	my $predicted_mass 	= new Bio::Annotation::SimpleValue(-value => sprintf("%01.2f", $href->{'predicted_peptide_mass'}));
#annotation in both predicted and identified
	my $detection_probability		= new Bio::Annotation::SimpleValue(-value => sprintf("%01.2f", $href->{'detection_probability'}));	
	my $delta_cn		= new Bio::Annotation::SimpleValue(-value => sprintf("%01.2f", $href->{'delta_cn'}));	
#	my $synthesized_seq	= new Bio::Annotation::SimpleValue(-value => 'Yes' );	
	my $synthesized_seq	= new Bio::Annotation::SimpleValue(-value => $href->{'synthesized_sequence'} );	
	my $glyco_score		= new Bio::Annotation::SimpleValue(-value => sprintf("%01.2f", $href->{'glyco_score'}));	
	my $protein_glyco_position   = new Bio::Annotation::SimpleValue(-value =>  $href->{'protein_glycosite_position'});
	my $observed_seq   = new Bio::Annotation::SimpleValue(-value =>  $href->{'observed_peptide_sequence'});
	
	$tissues->text($tissue_info);
	
	$db_hits_ids->text($href->{'matching_protein_ids'});
	
	
#$log->debug("GLYCOSITE ". $href->{'protein_glyco_site_position'});
	my $coll = new Bio::Annotation::Collection();
	
	$coll->add_Annotation('tryptic_end', $number_tryptic_ends);
	$coll->add_Annotation('observed_seq', $observed_seq);
	$coll->add_Annotation('peptide_prophet_score', $pep_prophet_score);
	$coll->add_Annotation('peptide_mass', $peptide_mass);
	$coll->add_Annotation('detection_probability', $detection_probability);
	$coll->add_Annotation('tissues', $tissues);
	$coll->add_Annotation('number_obs', $number_obs);
	$coll->add_Annotation('num_mappings', $num_mappings);
	$coll->add_Annotation('acc_mappings', $acc_mappings);
	$coll->add_Annotation('gm_mappings', $gm_mappings);
	$coll->add_Annotation('synthesized_seq', $synthesized_seq);
	
	
	$coll->add_Annotation('number_proteins_match_peptide', $db_hits);
	$coll->add_Annotation('database_hits_ipi_ids', $db_hits_ids);
	$coll->add_Annotation('protein_similarity_score', $db_smilarity);
	$coll->add_Annotation('predicted_mass', $predicted_mass);
	
	$coll->add_Annotation('protein_glyco_site', $protein_glyco_position);
	$coll->add_Annotation('glyco_score', $glyco_score);
	$coll->add_Annotation('delta_cn', $delta_cn);

	
	$seq->annotation($coll);	
	$self->seq_info($seq);


}

#######################################
#parse_modified_pep_seq
#pull apart the different modifications a peptide sequence can have 
#Make the Bio::Seq Object and add the features
#
##########################
sub parse_modified_pep_seq {
	my $method = '';
	my $self = shift;
	my %args= @_;
	
	my $aa_seq = $args{pep_seq};
	my $peptide_id = $args{peptide_id};
	my $pep_type = $args{pep_type};
	
	confess(__PACKAGE__ . "::$method Need AA Seq  \n") unless $aa_seq;
	my @parts = split //, $aa_seq;
	
	my $start_aa = '';
	my $end_aa = '';
	my @met_mods = ();
	my @glyco_locations = ();
	my @clean_seq  = ();
	
	my $pep_features = ();
	#examples
	#  -.M*ALNN#VSLSSGDQRSR.V
	#  R.AN#LTNFPEN#GTFVVNIAQLSQDDSGR.Y
	#  M.GAAVTLKN#LTGLNQRR.-
	
  # Added multi-offset 3-14-2006, a terrible hack to patch a curious algorithm.
  # It is trying to get accurate motif indexes into a sequence that has leading
  # and lagging characters that will later be shorn, as well as internal motifs
  # labeled by characters (#, *) that will also be eliminated.  FIXME!
  my $multi_offset = 0;

  my $go = $self->get_glyco_object();
  my $seq = $go->seq_info->seq();

	for (my $i = 0; $i<=$#parts; $i ++){
    my $cnt = $i - $multi_offset;
		
		my $aa = $parts[$i];
		
		next if $aa =~ /\./; #skip the periods
		
		if ($i == 0){
			$start_aa = $aa;
			next;			
		}elsif($i == $#parts){
			$end_aa = $aa;
			next;
		}elsif($aa =~ /\*/) {#Oxidized Met
      $multi_offset++;
			#print "FOUND OX MET\n";
			my $new_i = _check_location(location => $cnt, type=>$pep_type);
			my $ox_met = Bio::SeqFeature::Generic->new(
								-start        => $new_i,
								-end          => $new_i,
								-primary 	  => "Oxidized Mets",
								-tag 		  =>{oxidized_met => 'ox_met'}
					);
			
			push @met_mods, $ox_met;
			next;
		}elsif($aa =~ /#/){	#Glyco Site
      $multi_offset++;
			my $new_i = _check_location(location => $cnt, type =>$pep_type);
			my $glyco = Bio::SeqFeature::Generic->new(
								-start        => $new_i,
								-end          => $new_i + 2,
								-primary 	  => "N-Glyco Sites", 
								-tag 		  =>{Glyco_N_site => 'gly_n'
					 							 },
					);
			
			
			push @glyco_locations, $glyco;
			next;
		}elsif($aa =~ /\?/){	#Ambiguous phospho Site
#      $log->debug( "in ambiguous loop with $aa" );
      $multi_offset++;
			my $new_i = _check_location(location => $cnt, type =>$pep_type);
			my $glyco = Bio::SeqFeature::Generic->new(
								-start        => $new_i,
								-end          => $new_i + 2,
								-primary 	  => "", 
								-tag 		  =>{phospho_site => 'phos'
					 							 },
					);
			
			
			push @glyco_locations, $glyco;
			next;
		}
		
		push @clean_seq, $aa;
	}
	my $clean_seq_string = join "", @clean_seq;
	
  if ( $glyco->get_current_motif_type =~ /phospho/ ) {

    # This is calculated improperly for phospho motifs
	  my $clean_aa_seq = $aa_seq;
    $clean_aa_seq =~ s/\*|\?//g;

    my $posn = $glyco->get_site_positions( pattern => $clean_aa_seq, seq => $seq );
    my $start_idx = $posn->[0] - 1;
    my $end_idx = $posn->[0] + length($clean_aa_seq);
    $start_aa = substr( $seq, $start_idx, 1 );
    $end_aa = substr( $seq, $end_idx, 1 );
    my $ntt = 0;
    if ( !$start_aa || $start_aa =~ /R|K/ ) {
      $ntt++;
    } 
    if ( !$end_aa || $aa_seq =~ /R$/ || $aa_seq =~ /K$/ ) {
      $ntt++;
    }
    $start_aa ||= '-';
    $end_aa ||= '-';
    $args{data}->{tryptic_end} = $ntt;
  }
	#$log->debug(__PACKAGE__ . "::$method CLEAN SEQ PEPTIDE SEQ '$clean_seq_string'");
	#jam the start and end aa into one feature, but they actually come before and after the start and of the 
	#clean pep sequence....
	my $start_end = Bio::SeqFeature::Generic->new(
	-start        =>1,
	-end          => length(@clean_seq),
	-primary 	  => "Start_end_aa", 
	-tag 		  =>{start_aa => $start_aa,
					 end_aa   => $end_aa,
					},
	);
	

#  use SBEAMS::Glycopeptide;
#  my $gp = SBEAMS::Glycopeptide->new();
#  my $motif = $gp->get_current_motif_type();
  my $motif = 'glyco';
  my $dseq = ( $motif =~ /phospho/ ) ? $aa_seq : $clean_seq_string;

	my $seq = Bio::Seq->new(
        	-display_id => $peptide_id,
        	-seq        => $dseq,
	);
	#add all the features to the peptide Bio::Seq object
	$seq->add_SeqFeature($start_end,@met_mods, @glyco_locations );
	return $seq;
	
}
#######################################################
#_check_location.
#check to make sure start site is not negative
#remember to subract 2 one for the first aa and one for the period
#######################################################
sub _check_location {
	my %args = @_;
	my $i = $args{location};
	my $type = $args{type};

		if ($i - 2 <= 0){
			return 1;
		}else{
			return $i - 2;
		}
	
}

#######################################################
#Map a peptide to a protein. Attach the peptide Bio::Seqeunce to a 
#feature attached to the main protein Bio::Sequence
#######################################################
sub map_pep_to_protein {
	my $method = 'map_pep_to_protein';
	my $self = shift;
	my %args    = @_;
	
	my $pep_obj = $args{pep_bioseq};
	my $track_type = $args{peptide_type};
	
	
	confess(__PACKAGE__ . "::$method pep Bio::Seq object  \n") unless (ref($pep_obj));
	
	my $glyco_obj = $self->get_glyco_object();
	my $seq_obj = $glyco_obj->seq_info();
	
	#$log->debug(__PACKAGE__ . "::$method PROTEIN SEQ OBJECT". Dumper($seq_obj));
	
	#$log->debug( "PEP '" . $pep_obj->seq() . "' " ); #$seq_obj->seq() 

	my $pep_seq = uc($pep_obj->seq());
#  $log->debug( "got an error with $pep_seq here boss!" );
	if ( $seq_obj->seq() =~ /$pep_seq/ ) {
		#add one for the starting position since we want the start of the peptide location
		
		my $start_pos = length($`) +1;    
		my $stop_pos = $pep_obj->length() + $start_pos - 1 ;    #subtract 1 since we want the ture end 
#  $log->debug( "Adding a $track_type object starting at $start_pos, ending at $stop_pos" );
		#$log->debug(" $pep_seq START '$start_pos' STOP '$stop_pos'");
		$self->add_peptide_to_sequence(
			peptide => $pep_obj,
			track_type => $track_type,
			start   => $start_pos,
			end     => $stop_pos
		);
	}else {
    $log->error( "failed to map peptide to protein: $pep_seq " . $seq_obj->seq() );

	}

}

#######################################################
#add_peptide_to_sequence
#######################################################
sub add_peptide_to_sequence {
	my $method = 'add_peptide_to_sequence';
	my $self = shift;
	my %args = @_;
	
	my $pep_obj = $args{peptide};
	my $start   = $args{start};
	my $end     = $args{end};
	my $track_type = $args{track_type};
	
	my $glyco_obj  = $self->get_glyco_object();
	my $seq_obj 	= $glyco_obj->seq_info();
	confess(__PACKAGE__ . "::$method pep Bio::Seq object  \n") unless (ref($pep_obj));
	
	
	
	my $score = '';
	if ($track_type eq 'Predicted Peptides'){
		$score = $self->get_score(pep_object =>$pep_obj, 
								  score_type => 'glyco_score'
								  );
	}elsif($track_type eq 'Identified Peptides'){
		$score = $self->get_score(pep_object =>$pep_obj,
		 						  score_type => 'peptide_prophet_score'
		 						 );
	}else{
		$score = $self->get_score(pep_object =>$pep_obj,
		 						  score_type => 'number_obs'
		 						 );
	}
	
	
	my $feature = Bio::SeqFeature::Generic->new(
	-start        =>$start,
	-end          => $end,
	-primary 	  => $track_type,
	-tag 		  =>{Pep_location => 'Peptide Location',
			     Peptide_seq_obj => $pep_obj},
	-score		  => $score	,
	
	);
	
##Pull out the position of the glyco_site on the protein to use as the title 
 	 my $ac = $pep_obj->annotation();

        #retrieves all the Bio::AnnotationI objects for one or more specific key(s).
        my @annotations = $ac->get_Annotations('protein_glyco_site');

        my  $info = $annotations[0]->hash_tree()->{value};
#	$log->debug(Dumper($info));
	$log->debug($info);
	
	#$feature->display_name('Pep_id_' . $pep_obj->display_name());
	$feature->display_name($info);
	
	#attach the pep_obj to the feature
	$feature->attach_seq($pep_obj);					
	
	#Add the peptide feature to the main protein sequence
	$seq_obj->add_SeqFeature($feature);
	#$log->debug(__PACKAGE__ . "::$method FEATURE DISPLAY NAME " . $feature->display_name());

	#$log->debug(Dumper($seq_obj));
}

#######################################################
#identified_tissues
# give identified_peptide_id
# return a comma delimited string of all the tissues the 
#peptide has been identified in
#######################################################
sub identified_tissues {
	my $method = 'identified_tissues';
	my $self = shift;
	my $identified_peptide_id = shift;
	
	confess(__PACKAGE__ . "::$method NEED identified_peptide_id '$identified_peptide_id'  \n") unless ($identified_peptide_id =~ /^\d+$/); 
	my $tissues = $self->get_identified_tissues($identified_peptide_id);
	
	return join ",", @$tissues;
}

sub observed_tissues {
	my $self = shift;
	my $seq = shift;
	
	my $tissues = $self->get_observed_tissues($seq);
	
	return join ",", @$tissues;
}
#######################################################
#get_score
# Given a Bio::Seq object look in the annotation features
# for a specific key and return the score value
#######################################################
sub get_score {
	my $method = 'get_glyco_prediction_score';
	my $self = shift;
	my %args = @_;
	
	my $pep_obj 	= $args{pep_object};
	my $score_type  = $args{score_type};
				  
	my $info = '';
	#get an AnnotationCollectionI
	my $ac = $pep_obj->annotation();
	
	#retrieves all the Bio::AnnotationI objects for one or more specific key(s).
	my @annotations = $ac->get_Annotations($score_type);
	
	if ($annotations[0]){
		$info = $annotations[0]->hash_tree()->{value};
	}else{
		$info = 1;
	}
	#$info = sprintf("%Vf", $info);
	#$info =~ s/(\w{4})/$1/;
	#$log->debug("SCORE TYPE '$score_type' INFO'$info'");
	return $info
}




} #end of package
1;
