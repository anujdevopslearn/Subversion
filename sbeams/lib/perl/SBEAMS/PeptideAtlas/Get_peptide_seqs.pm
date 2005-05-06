{package SBEAMS::PeptideAtlas::Get_peptide_seqs;
	

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
use SBEAMS::PeptideAtlas::Get_glyco_seqs;
use base qw(SBEAMS::PeptideAtlas::Get_glyco_seqs);		
use SBEAMS::PeptideAtlas::Test_glyco_data;

#my $fake_data_o = new SBEAMS::PeptideAtlas::Test_glyco_data();

##############################################################################
#constructor
###############################################################################
sub new {
    my $method = 'new';
    my $this = shift;
    my $class = ref($this) || $this;
    my %args = @_;
    
    my $glyco_obj = $args{glyco_obj};
#    $log->debug(__PACKAGE__ . "::$method NEW PEPTIDE OBJECT WITH GLYCO OBJ.". Dumper($glyco_obj));
		
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
	
		
		#data coming from fake data object
		my $modified_pep_seq = $href->{'peptide_seq'};
		
		my $peptide_id =  $href->{'peptide_id'};
		
		#$log->debug(__PACKAGE__ . "::$method MODIFED PEPTIDE SEQ '$modified_pep_seq' PEPID '$peptide_id'");
		
		
		if ($pep_type eq 'Predicted'){
			$self->add_glyco_site($href->{'glyco_site_location'});
		}
		
		
		my $pep_bioseq_o = $self->parse_modfied_pep_seq(pep_seq => $modified_pep_seq,
													  peptide_id => $peptide_id,
													  pep_type  => $pep_type
													  );
		$self->add_peptide_annotation(data =>$href,
									  seq  =>$pep_bioseq_o);
		
		
		$self->map_pep_to_protein(pep_bioseq => $pep_bioseq_o,
							      peptide_type =>$pep_type );
		
		
	
	}
	

}

sub add_peptide_annotation{
	my $mehtod = 'add_peptide_annotation';
	my $self = shift;
	my %args = @_;
	my $href = $args{data};
	my $seq  = $args{seq};
	
	
	my $number_tryptic_ends = new Bio::Annotation::SimpleValue(-value => $href->{'number_tryptic_peptides'});
	my $pep_prophet_score 	= new Bio::Annotation::SimpleValue(-value => $href->{'peptide_prophet_score'});
	my $peptide_mass 	= new Bio::Annotation::SimpleValue(-value => $href->{'peptide_mass'});
	my $tissues			= Bio::Annotation::Comment->new;
	
	my $glyco_score = new Bio::Annotation::SimpleValue(-value => sprintf("%01.2f",$href->{'glyco_score'}));
	my $db_hits = new Bio::Annotation::SimpleValue(-value => $href->{'database_hits'});
	my $db_hits_ids = Bio::Annotation::Comment->new;
	my $db_smilarity = new Bio::Annotation::SimpleValue(-value => $href->{'similarity'});
	my $predicted_mass = new Bio::Annotation::SimpleValue(-value => sprintf("%01.2f", $href->{'predicted_mass'}));
	
	
	$tissues->text($href->{'identifed_tissues'});
	
	$db_hits_ids->text($href->{'database_hits_ipi_ids'});
	
	

	my $coll = new Bio::Annotation::Collection();
	
	$coll->add_Annotation('number_tryptic_peptides', $number_tryptic_ends);
	$coll->add_Annotation('peptide_prophet_score', $pep_prophet_score);
	$coll->add_Annotation('peptide_mass', $peptide_mass);
	$coll->add_Annotation('tissues', $tissues);
	
	$coll->add_Annotation('glyco_score', $glyco_score);
	$coll->add_Annotation('database_hits', $db_hits);
	$coll->add_Annotation('database_hits_ipi_ids', $db_hits_ids);
	$coll->add_Annotation('similarity', $db_smilarity);
	$coll->add_Annotation('predicted_mass', $predicted_mass);
	
	
	
	$seq->annotation($coll);	
	$self->seq_info($seq);


}

#######################################
#parse_modfied_pep_seq
#pull apart the different modification a peptide sequence can have 
#Make the Bio::Seq Object and add the features
#
##########################
sub parse_modfied_pep_seq {
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
	
	for (my $i = 0; $i<=$#parts; $i ++){
		
		my $aa = $parts[$i];
		
		next if $aa =~ /\./; #skip the periods
		
		if ($i == 0){
			$start_aa = $aa;
			next;			
		}elsif($i == $#parts){
			$end_aa = $aa;
			next;
		}elsif($aa =~ /\*/) {#Oxidized Met
			#print "FOUND OX MET\n";
			my $new_i = _check_location(location => $i, type=>$pep_type);
			my $ox_met = Bio::SeqFeature::Generic->new(
								-start        => $new_i,
								-end          => $new_i,
								-primary 	  => "Oxidized Mets",
								-tag 		  =>{oxidized_met => 'ox_met'}
					);
			
			push @met_mods, $ox_met;
			next;
		}elsif($aa =~ /#/){	#Glyco Site
			#$log->debug("I SEE A GLYCO SITE");
			my $new_i = _check_location(location => $i, type =>$pep_type);
			my $glyco = Bio::SeqFeature::Generic->new(
								-start        => $new_i,
								-end          => $new_i + 2,
								-primary 	  => "Glyco N", 
								-tag 		  =>{Glyco_N_site => 'gly_n'
					 							 },
					);
			
			
			push @glyco_locations, $glyco;
			next;
		}
		
		push @clean_seq, $aa;
	}
	my $clean_seq_string = join "", @clean_seq;
	
	#$log->debug(__PACKAGE__ . "::$method CLEAN SEQ PEPTIDE SEQ '$clean_seq_string'");
	#jam the start and end aa into one feature, but they actually come before and after the start and of the 
	#clean pep sequence....
	my $start_end = Bio::SeqFeature::Generic->new(
	-start        =>1,
	-end          => length@clean_seq,
	-primary 	  => "Start_end_aa", 
	-tag 		  =>{start_aa => $start_aa,
					 end_aa   => $end_aa,
					},
	);
	
	my $seq = Bio::Seq->new(
        	-display_id => $peptide_id,
        	-seq        => $clean_seq_string,
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
#Map a peptdie to a protein. Attach the peptide Bio::Seqeunce to a 
#feature attached to the main protein Bio::Sequence
#######################################################
sub map_pep_to_protein {
	my $method = 'map_pep_to_protein';
	my $self = shift;
	my %args    = @_;
	
	my $pep_obj = $args{pep_bioseq};
	my $track_type = $args{peptide_type};
	
	
	confess(__PACKAGE__ . "::$method pep Bio::Seq object  \n") unless (ref($pep_obj));
	confess(__PACKAGE__ . "::$method track type Can Only be 'Predicted or Identified'  \n") unless ($track_type =~ /Pr|Id/);
	
	my $glyco_obj = $self->get_glyco_object();
	my $seq_obj = $glyco_obj->seq_info();
	
	#$log->debug(__PACKAGE__ . "::$method PROTEIN SEQ OBJECT". Dumper($seq_obj));
	
	#$log->debug( "PEP '" . $pep_obj->seq() . "' " ); #$seq_obj->seq() 

	my $pep_seq = $pep_obj->seq();
	if ( $seq_obj->seq() =~ /$pep_seq/ ) {
		#add one for the starting position since we want the start of the peptide location
		
		my $start_pos = length($`) +1;    
		my $stop_pos = $pep_obj->length() + $start_pos - 1 ;    #subtract 1 since we want the ture end 
		#$log->debug(" $pep_seq START '$start_pos' STOP '$stop_pos'");
		$self->add_peptide_to_sequence(
			peptide => $pep_obj,
			track_type => $track_type,
			start   => $start_pos,
			end     => $stop_pos
		);
	}else {
		print (__PACKAGE__ . "::$method Could not find peptide in protein seq\n");
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
	if ($track_type eq 'Predicted'){
		$score = $self->get_score(pep_object =>$pep_obj, 
								  score_type => 'glyco_score'
								  );
	}elsif($track_type eq 'Identified'){
		$score = $self->get_score(pep_object =>$pep_obj,
		 						  score_type => 'peptide_prophet_score'
		 						 );
	}else{
		$score = 'Unknown_score';
	}
	
	
	my $feature = Bio::SeqFeature::Generic->new(
	-start        =>$start,
	-end          => $end,
	-primary 	  => $track_type,
	-tag 		  =>{Pep_location => 'Peptide Location',
			     Peptide_seq_obj => $pep_obj},
	-score		  => $score	,
	
	);
	
	$feature->display_name('Pep_id_' . $pep_obj->display_name());
	
	#attach the pep_obj to the feature
	$feature->attach_seq($pep_obj);					
	
	#Add the peptide feature to the main protein sequence
	$seq_obj->add_SeqFeature($feature);
	#$log->debug(__PACKAGE__ . "::$method FEATURE DISPLAY NAME " . $feature->display_name());

	#$log->debug(Dumper($seq_obj));
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
		$info = $annotations[0]->hash_tree;
	}else{
		$info = 1;
	}
	#$info = sprintf("%Vf", $info);
	#$info =~ s/(\w{4})/$1/;
	#$log->debug("SCORE TYPE '$score_type' INFO'$info'");
	return $info
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
	my $location = shift;
	
	return 0 unless $location =~ /^\d/;
	
	my $glyco_obj = $self->get_glyco_object;
	my $seq_obj = $glyco_obj->seq_info;
	
	my $glyco = Bio::SeqFeature::Generic->new(
								-start        => $location,
								-end          => $location +2,
								-primary 	  => "Glyco N", 
								-tag 		  =>{Glyco_N_site => 'gly_n'
					 							 },
					);
	
	
	#add all the feature to the protein Bio::Seq object
	$seq_obj->add_SeqFeature($glyco);
	
	return 1;
}



} #end of package
1;
