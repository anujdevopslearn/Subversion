{package SBEAMS::PeptideAtlas::Get_glyco_seqs;
	

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
use base qw(SBEAMS::PeptideAtlas);		


use SBEAMS::Connection::Tables;
use SBEAMS::PeptideAtlas::Test_glyco_data;
use SBEAMS::PeptideAtlas::Get_peptide_seqs;

my $fake_data_o = new SBEAMS::PeptideAtlas::Test_glyco_data();


##############################################################################
#constructor
###############################################################################
sub new {
    my $method = 'new';
    my $this = shift;
    my $class = ref($this) || $this;
    my %args = @_;
    
    my $ipi_id = $args{ipi_id};
    confess(__PACKAGE__ . "::$method Need to provide IPI id '$ipi_id' is not good  \n") 
    unless ($ipi_id =~ /IPI\d+$/);
    
    my $self = {_ipi_id => $ipi_id};
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
#get_ipi_id
###############################################################################
sub get_ipi_id {
    my $self = shift;
   
    return($self->{_ipi_id});
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
	my $ipi_id = $self->get_ipi_id();

	$self->get_ipi_data();
	
	$self->add_predicted_peptides();
	$self->add_identified_peptides();
	$self->add_signal_sequence();
	$self->add_cellular_location();
}
# ###########################################
#Given an IPI number query the database and return 
# Return 1 for completion or die;
# The Bio::seq object is accessible via the seq_info method
#########################################
sub get_ipi_data {
	my $method = 'get_protein_info';
	my $self = shift;
	my $ipi_id = $self->get_ipi_id();
	
	##TODO will need to add method to query the database and get the info 
	## out to put into the objects below.  Have fun ;-)

	my $seq = Bio::Seq->new(
        	-display_id => $ipi_id,
        	-seq        => $fake_data_o->{'aa_seq'},
	);
#Fake data example
#protein_name => "CD166 antigen precursor",
#		protein_symbol=> "ALCAM",
#		ipi_id		   => 'IPI00015102',
#		swiss_prot		=> 'Q13740',
#		synonyms	=> 'CD166 antigen precursor (Activated leukocyte-cell adhesion molecule) (ALCAM).',
#		trans_membrane_locations => "o528-550i",
#		numb_tm_domains => 1,
#		signal_sequence_info	=> "28 Y 0.988 Y",
		
	
		
	#add the annotation data
	my $protein_name = Bio::Annotation::Comment->new;
	my $symbol 		= new Bio::Annotation::SimpleValue(-value => $fake_data_o->{'protein_symbol'});
	my $swiss_prot 	= new Bio::Annotation::SimpleValue(-value => $fake_data_o->{'swiss_prot'});
	my $synonyms	= Bio::Annotation::Comment->new;
	my $summary		= Bio::Annotation::Comment->new;
	
	
	
	
	$protein_name->text($fake_data_o->{'protein_name'});
	$synonyms->text($fake_data_o->{'synonyms'});
	$summary->text($fake_data_o->{'summary'});
	

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
# ###########################################
#Add the predicted peptide to the sequence 
#########################################
sub add_signal_sequence {
	my $method = 'add_signal_sequence';
	my $self = shift;
	my $signal_sequence_info = $fake_data_o->{'signal_sequence_info'};
	if ($signal_sequence_info =~ /^(\d+).*Y$/){
		$log->debug(__PACKAGE__. "::$method FOUND SIGNAL SEQUENCE");
		my $seq_obj = $self->seq_info();
				
		my $sigseq = Bio::SeqFeature::Generic->new(
                                                                -start        =>1,
                                                                -end          =>$1 ,
                                                                -primary          => "Signal Sequence",
                                                                -tag              =>{Signal_sequence => 'signalsequence'
                                                                                                 },
                                        );

		$seq_obj->add_SeqFeature($sigseq);
	}
}

# ###########################################
#Add add the pepredicted peptide seqs to the seq obj
#########################################
sub add_predicted_peptides {
	my $mehtod= 'add_predicted_peptides';
	my $self = shift;
	my @array_hrefs = $fake_data_o->get_fake_predicted_seqs();
	my $pep_o = new SBEAMS::PeptideAtlas::Get_peptide_seqs(glyco_obj => $self);
	
	##TODO GOING TO NEED METHOD TO QUERY DB AND GET BACK DATA ABOUT PEPTIDE
	##HAVE ABLITITY TO INDICATE PREDICTED OR IDENTIFED PEPTIDES
	$pep_o->make_peptide_bio_seqs(data => \@array_hrefs,
								  type => 'Predicted',	
								);
	

}

# ###########################################
#Add add the identified peptide seqs to the seq obj
#########################################
sub add_identified_peptides {
	my $mehtod= 'add_identified_peptides';
	my $self = shift;
	my @array_hrefs = $fake_data_o->get_fake_identifed_seqs();
	my $pep_o = new SBEAMS::PeptideAtlas::Get_peptide_seqs(glyco_obj => $self);
	
	##TODO GOING TO NEED METHOD TO QUERY DB AND GET BACK DATA ABOUT PEPTIDE
	##HAVE ABLITITY TO INDICATE PREDICTED OR IDENTIFED PEPTIDES
	$pep_o->make_peptide_bio_seqs(data => \@array_hrefs,
								  type => 'Identified',	
								);
	

}

###############################################################################
#get_dbxref_accessor_urls
#Give nothing
#return results as a hash example  LocusLink => http://www.ncbi.nlm.nih.gov/LocusLink/ 
#
###############################################################################
sub get_dbxref_accessor_urls {
	my $self = shift;
	return $sbeams->selectTwoColumnHash("SELECT dbxref_tag, accessor
			    	    	     FROM $TB_DBXREF"
					   );
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
		
	#	$log->debug("$count UNSORTED FEATURE " . $f->primary_tag);
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
	
	my %args = @_;
	
	my $seq = $args{seq};
	my $ref_parameters = $args{'ref_parameters'};
	
#$log->debug(Dumper($seq));
	unless(ref($seq)){
		 $seq = $self->seq_info();
	}	
		
	my $aa_seq = $seq->seq();
	 my @array_of_arrays = $self->make_array_of_arrays($seq);

    
        my @sorted_features = $self->sorted_freatures($seq->all_SeqFeatures);# descend into sub features
        
        #$log->debug(@sorted_features);
        for my $f (@sorted_features) {
			my $tag = $f->primary_tag;
			
			
            #subtract one since we are indexing into a zero based array
            my $start =  $f->start - 1;
            my $end =  $f->end - 1;
            
            my ($css_class, $title) = _choose_css_type(tag => $tag,
														ref_parameters=>$ref_parameters,
													   	start => $start,
													   );
                
			if ($css_class){
	                	my $start_tag = "<span class='$css_class' $title>";
	                	my $end_tag   = "</span>";
	                	unshift @{$array_of_arrays[$start]}, $start_tag;
	                	push @{$array_of_arrays[$end]}, $end_tag;
			}
			
        }
       # $log->debug( Dumper(\@array_of_arrays));
        my $string = $self->flatten_array_of_arrays(@array_of_arrays);
        return  $string;

}
#########################################
#_choose_css_type
#########################################
sub _choose_css_type {
	my %args = @_;
	
	my $ref_parameters = $args{'ref_parameters'};
	my $tag = $args{tag};
	my $start = $args{start};
	my $css_class = '';
	my $title = '';
	my %parameters = ();
	
	
#If we have some parameters, only return a css_class for the one in the parameter hash
#Glyco N sites will always displayed
	if ($ref_parameters->{'redraw_protein_sequence'} == 1){
		%parameters = %{$ref_parameters};
		$log->debug("REDRAW PROTEIN '$tag'".  Dumper(\%parameters));
		if ($tag eq 'Predicted' && exists $parameters{'Predicted Peptide'}){
			$css_class='predicted_pep';
	           $log->debug("REDRAW PROTEIN I HAVE PREDICTED");     	
		}elsif($tag eq 'Identified' && exists $parameters{'Indentified Peptide'}){
			$css_class='identified_pep';
			
		}elsif($tag eq 'Signal Sequence' && exists $parameters{'Signal Sequence'}){
			$css_class='sseq';
		}elsif($tag eq 'Trans Membrane Predictions' && exists $parameters{'Trans Membrane Seq'}){
			$css_class='tmhmm';
		}elsif($tag eq 'Glyco N'){
			$css_class='glyco_site';
			$title = "title='Glyco Site $start'";
		}
	}else{
	
	
		if ($tag eq 'Predicted'){
			$css_class='predicted_pep';
	                		
		}elsif($tag eq 'Identified'){
			$css_class='identified_pep';
			
		}elsif($tag eq 'Signal Sequence'){
			$css_class='sseq';
		}elsif($tag eq 'Trans Membrane Predictions'){
			$css_class='tmhmm';
		}elsif($tag eq 'Glyco N'){
			$css_class='glyco_site';
			$title = "title='Glyco Site $start'";
		}
	}
	#$log->debug( __PACKAGE__ . "::$method FEATURE PRIMARY TAG '$tag' CLASS '$css_class'\n");
                

	return ($css_class, $title);
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
                push @flat_array, @{$aref};
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
	
	my $subcellular_info = $fake_data_o->{'cellular_location'};
	my $seq_obj = $self->seq_info();
	
	my $location = '';
	if ($subcellular_info eq 'S'){
		$location = "Secreted";
	}elsif($subcellular_info eq 'TM' ){
		$location = "Trans Membrane";
	}elsif($subcellular_info == 0){
		$location = "Unknown";
	}else{
		$location = 'No Data';
	}
	my $coll = $seq_obj->annotation();
	my $cellualar_loc_obj 	= new Bio::Annotation::SimpleValue(-value => $location);	
	 
	$coll->add_Annotation('cellular_location', $cellualar_loc_obj);
	$seq_obj->annotation($coll);
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
	
	if ($type eq 'Predicted'){
		$html .= $self->predicted_pep_html($sorted_features{$type});
	}elsif($type eq 'Identified'){
		$html .= $self->identified_pep_html($sorted_features{$type});
	}
	
	
	return $html;
}

###############################################
#predicted_pep_html
##############################################
sub predicted_pep_html{
    my $method = 'predicted_pep_html';
    my $self = shift;
	my $features_aref = shift;
	my $html = <<"END";
			<table >
			 <tr class='rev_gray'>
			   <td>NXS/T<br>Location</td>
			   <td>Predicted Sequence</td>
			   <td>NXS/T Score</td>
			   <td>Predicted Mass</td>
			   <td>Detection Probability</td>
			   <td>Number Other Proteins<br>with Peptide</td>
			 
			 </tr>
			
END
  
			      
	foreach my $f (@{$features_aref}){
		my $start = $f->start;
		my $seq = $f->seq;
		
		my $id = '';
		my $first_aa = 'X';
		my $end_aa = 'X';
		my $html_seq = '';
		my $detection_prop = '0.78';
		my $database_hits = '-1';
		my $ipi_hits = '-1';
		my $ipi_ids = '--';
		my $protein_sim = '1';
		my $predicted_mass = 0;
		my $glyco_score = 0;
		
		
		
		if ($f->has_tag('Peptide_seq_obj')){

            my $pep_seq_obj = $self->extract_first_val(feature => $f, tag => 'Peptide_seq_obj');
            $id = $pep_seq_obj->display_id;
            #	$log->debug(Dumper($pep_seq_obj));
			my @all_peptide_features = $pep_seq_obj->all_SeqFeatures;
			my $feature_href = $self->make_features_hash(@all_peptide_features);
			if (exists $feature_href->{'Start_end_aa'}){
				#$log->debug("I SEE FIRST AA");
				$first_aa = $self->extract_first_val(feature => $feature_href->{'Start_end_aa'}->[0], 
													 tag => 'start_aa');
				$end_aa = $self->extract_first_val(feature => $feature_href->{'Start_end_aa'}->[0], 
												   tag => 'end_aa');
			
			}
			
			$html_seq = $self->get_html_protein_seq(seq => $pep_seq_obj);
			$glyco_score = $self->get_annotation(seq_obj =>$pep_seq_obj, 
									 anno_type => 'glyco_score');
			#$detection_prop = $self->get_annotation(seq_obj =>$pep_seq_obj, 
			#						 anno_type => 'detection_probability');
			$database_hits = $self->get_annotation(seq_obj =>$pep_seq_obj, 
									 anno_type => 'database_hits');
			$ipi_ids = $self->get_annotation(seq_obj =>$pep_seq_obj, 
									 anno_type => 'database_hits_ipi_ids');
			$predicted_mass = $self->get_annotation(seq_obj =>$pep_seq_obj, 
									 anno_type => 'predicted_mass');
			$protein_sim = $self->get_annotation(seq_obj =>$pep_seq_obj, 
									 anno_type => 'similarity');
					
		}
## Detmine what to do wiht the number of other protein database hits
		my $hit_link = '---';
		if ($database_hits > 1){
			$hit_link = "<a href='fake_url/$ipi_ids'>$database_hits</a>?";
		}
		
### Start writing some html that can be returned

		 $html .= $q->Tr(
				$q->td($id),
				$q->td("$first_aa.$html_seq.$end_aa"),
				$q->td({align=>'center'}, $glyco_score),
				$q->td({align=>'center'},$predicted_mass),
				$q->td({align=>'center'},$detection_prop),
				$q->td({align=>'center'},$hit_link),
				
			     );
		}
	$html .= "</table>";
	return $html;
}


###############################################
#identified_pep_html
##############################################
sub identified_pep_html{
        my $method = 'identified_pep_html';
        my $self = shift;
	my $features_aref = shift;
	my $html = <<"END";
			<table >
			 <tr class='rev_gray'>
			   <td>NXS/T<br>Location</td>
			   <td>Identifed Sequence</td>
			   <td>Peptide ProPhet Score</td>
			   <td>Tryptic Ends</td>
			   <td>Peptide Mass</td>
			   <td>Tissues</td>
			 </tr>
			
END
  
			    

			      
	foreach my $f (@{$features_aref}){
		my $start = $f->start;
		my $seq = $f->seq;
		
		my $id = '';
		my $first_aa = 'X';
		my $end_aa = 'X';
		my $html_seq = '';
		my $number_tryptic_peptides = '-1';
		my $peptide_prophet_score = '-1';
		my $peptide_mass = '1';
		my $tissues = 'None';
		
		
		
		if ($f->has_tag('Peptide_seq_obj')){

            my $pep_seq_obj = $self->extract_first_val(feature => $f, tag => 'Peptide_seq_obj');
            #	$log->debug(Dumper($pep_seq_obj));
            $id = $pep_seq_obj->display_id;
			my @all_peptide_features = $pep_seq_obj->all_SeqFeatures;
			my $feature_href = $self->make_features_hash(@all_peptide_features);
			
			if (exists $feature_href->{'Start_end_aa'}){
			#	$log->debug("I SEE FIRST AA");
				$first_aa = $self->extract_first_val(feature => $feature_href->{'Start_end_aa'}->[0], 
													 tag => 'start_aa');
				$end_aa = $self->extract_first_val(feature => $feature_href->{'Start_end_aa'}->[0], 
												   tag => 'end_aa');
			}
			
			$html_seq = $self->get_html_protein_seq(seq => $pep_seq_obj);
			$number_tryptic_peptides = $self->get_annotation(seq_obj =>$pep_seq_obj, 
									 anno_type => 'number_tryptic_peptides');
			$peptide_prophet_score = $self->get_annotation(seq_obj =>$pep_seq_obj, 
									 anno_type => 'peptide_prophet_score');
			$peptide_mass = $self->get_annotation(seq_obj =>$pep_seq_obj, 
									 anno_type => 'peptide_mass');
			$tissues = $self->get_annotation(seq_obj =>$pep_seq_obj, 
									 anno_type => 'tissues');
					
		}
### Start writing some html that can be returned

		 $html .= $q->Tr(
				$q->td($id),
				$q->td("$first_aa.$html_seq.$end_aa"),
				$q->td($peptide_prophet_score),
				$q->td($number_tryptic_peptides),
				$q->td($peptide_mass),
				$q->td($tissues),
			     );
		}
	$html .= "</table>";
	return $html;
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
        #$log->debug(Dumper($hold_vals[0])); 
	return $hold_vals[0];

}

################################
#
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

        #$log->debug(Dumper(\@annotations));

        return $info;
}



} #end of package
1;
