#!/usr/local/bin/perl

###############################################################################
# Program     : main.cgi
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This script authenticates the user, and then
#               displays the opening access page.
#
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################


###############################################################################
# Get the script set up with everything it will need
###############################################################################
use strict;
use vars qw ($q $sbeams $sbeamsMOD $PROG_NAME
             $current_contact_id $current_username);
use lib qw (../../lib/perl);
use CGI::Carp qw(fatalsToBrowser croak);
use Data::Dumper;

use SBEAMS::Connection qw($q $log);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TabMenu;

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;

use SBEAMS::PeptideAtlas::Get_glyco_seqs;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::PeptideAtlas;
$sbeamsMOD->setSBEAMS($sbeams);



###############################################################################
# Global Variables
###############################################################################
$PROG_NAME = 'main.cgi';
my $file_name    = $$ . "_glyco_predict.png";
my $tmp_img_path = "usr/images";
my $img_file     = "$PHYSICAL_BASE_DIR/$tmp_img_path/$file_name";
my $predicted_track_type = "Predicted";
my $id_track_type 		 = 'Identified';

main();


###############################################################################
# Main Program:
#
# Call $sbeams->Authentication and stop immediately if authentication
# fails else continue.
###############################################################################
sub main 
{ 
    #### Do the SBEAMS authentication and exit if a username is not returned
    exit unless ($current_username = $sbeams->Authenticate(
        permitted_work_groups_ref=>['PeptideAtlas_user','PeptideAtlas_admin',
        'PeptideAtlas_readonly'],
        #connect_read_only=>1,
        allow_anonymous_access=>1,
    ));


    #### Read in the default input parameters
    my %parameters;
    my $n_params_found = $sbeams->parse_input_parameters(
        q=>$q,
        parameters_ref=>\%parameters
        );


    ## get project_id to send to HTMLPrinter display
    my $project_id = $sbeamsMOD->getProjectID(
        #atlas_build_name => $parameters{atlas_build_name},
        #atlas_build_id => $parameters{atlas_build_id}
        );


    #### Process generic "state" parameters before we start
    $sbeams->processStandardParameters(parameters_ref=>\%parameters);
    #$sbeams->printDebuggingInfo($q);

    #### Decide what action to take based on information so far
    if ($parameters{action} eq "???") {

        # Some action
 
    } else {

        $sbeamsMOD->display_page_header(project_id => $project_id);

        handle_request(ref_parameters=>\%parameters);

        $sbeamsMOD->display_page_footer();

    }




} # end main


###############################################################################
# Show the main welcome page
###############################################################################
sub handle_request {

    my %args = @_;

    #### Process the arguments list
    my $ref_parameters = $args{'ref_parameters'}
        || die "ref_parameters not passed";

    my %parameters = %{$ref_parameters};
$log->debug(Dumper($ref_parameters));	
	##GET IPI SOMEHOW
	my $ipi_id = "IPI0000123";
	#go an query the db, add the peptide features and make into a big Bio::Seq object
	my $glyco_o = new SBEAMS::PeptideAtlas::Get_glyco_seqs(ipi_id => $ipi_id);
   
    make_image(glyco_o => $glyco_o);
    my $swiss_id = get_annotation(glyco_o   => $glyco_o,
								  anno_type => 'swiss_prot'
							     );
	my $html_protein_seq = $glyco_o->get_html_protein_seq(ref_parameters=>$ref_parameters);
	my $protein_name = get_annotation(glyco_o   => $glyco_o,
									  anno_type => 'protein_name'
									  );
    my $ipi_url = "<a href='http://foo?$ipi_id'>$ipi_id</a>";
    
    
    
### Print Out the HTML to Make Dispaly the info About the the Protein and all it's Glyco-Peptides
	print $q->table({boreder=>0},
			
	## Print out the protein Information
			$q->Tr(
				$q->td({class=>'grey_header', colspan=>2}, "Protein Info"),
			),
			 $q->Tr(
				$q->td({class=>'rev_gray'}, "IPI ID"),
				$q->td($ipi_url)
			  ),
			$q->Tr(
				$q->td({class=>'rev_gray'}, "Protein Name"),
				$q->td($protein_name)
			  ),
			$q->Tr(
				$q->td({class=>'rev_gray'}, "Protein Symbol"),
				$q->td(get_annotation(glyco_o   => $glyco_o,
									  anno_type => 'symbol'
									  )
					   )
			  ),
			 $q->Tr(
				$q->td({class=>'rev_gray'}, "Subcellular Location"),
				$q->td(get_annotation(glyco_o   => $glyco_o,
									  anno_type => 'cellular_location'
									  )
					   )
			  ),
			 $q->Tr(
				$q->td({class=>'rev_gray'}, "Swiss Prot ID"),
				$q->td("<a href='http://foo?$swiss_id'>$swiss_id</a>")
			  ),
			$q->Tr(
				$q->td({class=>'rev_gray'}, "Synonyms"),
				$q->td(get_annotation(glyco_o   => $glyco_o,
									  anno_type => 'synonyms'
									  )
					   )
			  ),
			$q->Tr(
				$q->td({class=>'rev_gray'}, "Protein Summary"),
				$q->td(get_annotation(glyco_o   => $glyco_o,
									  anno_type => 'summary'
									  )
					   )
			  ),
## Display the predicted Peptide info
		$q->Tr(
				$q->td({class=>'grey_header', colspan=>2}, "Predicted N-linked Proteotypic Glycopeptides"),
			),
		$q->Tr(
				$q->td({colspan=>2},$glyco_o->display_peptides('Predicted'))
			
			),
## Dispaly Identified Peptides
		$q->Tr(
				$q->td({class=>'grey_header', colspan=>2}, "Indentified N-linked Proteotypic Glycopeptides"),
			),
		$q->Tr(
				$q->td({colspan=>2},$glyco_o->display_peptides('Identified'))
			
			),

### Display the Protein peptide image ###
			$q->Tr(
				$q->td({class=>'grey_header', colspan=>2}, "Protein/Peptide Map"),
			),
			$q->Tr(
				$q->td({colspan=>2},"<img src='$HTML_BASE_DIR/$tmp_img_path/$file_name' alt='Sorry No Img'>")
			
			),
### Display the Amino Acid Sequence ###
			$q->Tr(
				$q->td({class=>'grey_header', colspan=>2}, "Protein/Peptide Sequence"),
			),
			$q->Tr(
				$q->td({colspan=>2, class=>'sequence_font'},">$ipi_url|$protein_name<br>$html_protein_seq")
			
			),
			
             $q->Tr(
                   $q->start_form(),
                   $q->td({colspan=>2, class=>'sequence_font'},
					   $q->table({border=>0},
					      $q->Tr(
					        $q->td({class=>'lite_blue_bg', colspan=>5}, "Click a button to highlight different sequence features")
					      ),
					      $q->Tr({class=>'sequence_font'},
					       	$q->td($q->submit({-name=>'Glyco Site',  -value=>'Glyco Site', class=>'glyco_site' })),
						 	$q->td($q->submit({-name=>'Predicted Peptide',  -value=>'Predicted Peptide', class=>'predicted_pep' })),
						 	$q->td($q->submit({-name=>'Indentified Peptide',  -value=>'Indentified Peptide', class=>'identified_pep' })),
							$q->td($q->submit({-name=>'Signal Sequence',  -value=>'Signal Sequence', class=>'sseq' })),
							$q->td($q->submit({-name=>'Trans Membrane Seq',  -value=>'Trans Membrane Seq', class=>'tmhmm' })),
					     ),
					   )#close sequencetable header
				   ),
				   $q->hidden(-name=>'ipi_id', -value=>$ipi_id, -override => 1),
				   $q->hidden(-name=>'redraw_protein_sequence', -value=>1),
				   $q->end_form()

             )
				
	
			);#end_table	
	
	#display_protein_info($glyco_o);




	

} #end handle request

######################################################
#make imgae
#
#####################################################
sub make_image {
	my %args = @_;
	my $glyco_o = $args{glyco_o};

	$glyco_o->get_protein_info(); 
   my $seq =  $glyco_o->seq_info();					
   
  
   my $wholeseq = Bio::SeqFeature::Generic->new(
	-start        =>1,
	-end          => $seq->length(),
	-display_name => $seq->display_id
	);

	my @features = $seq->all_SeqFeatures;
	
### partition features by their primary tags
	my %sorted_features;
	for my $f (@features) {
		my $tag = $f->primary_tag;
		#print "FEATURE PRIMARY TAG '$tag'\n<br>";
		push @{ $sorted_features{$tag} }, $f;
	}
	
	
	my $panel = Bio::Graphics::Panel->new(
		-length    => $seq->length,
		-key_style => 'between',
		-width     => 800,
		-pad_top   => 20,
		-pad_bottom => 20,
		-pad_left  => 20,
		-pad_right => 20,
	);
	#add the scale bar
	$panel->add_track(
		$wholeseq,
		-glyph  => 'arrow',
		-bump   => 0,
		-double => 1,
		-tick   => 2
	);
	
	$panel->add_track(
		$wholeseq,
		-glyph   => 'generic',
		-bgcolor => 'blue',
		-label   => 1,
	);
	
	##### Add Track for Identified Sequences
 ##Adjust score to Protein Prohet score
   
   if ($sorted_features{$id_track_type}) {
     $panel->add_track($sorted_features{$id_track_type},
                       -glyph       => 'graded_segments',
					   -bgcolor     => '#882222',
						-fgcolor     => 'black',
						-font2color  => '#882222',
						-key         => $id_track_type,
						-bump        => +1,
						-height      => 8,
						-label       => 1,
						-description => \&peptide_label,
						-min_score => 0,
	    				-max_score => 1,
                      );
    delete $sorted_features{$id_track_type};
   }
   
  ##### Add Track for Predicted Sequences
  ##### Adjust score to Prediction Score
   if ($sorted_features{$predicted_track_type}) {
     $panel->add_track($sorted_features{$predicted_track_type},
                       -glyph       => 'graded_segments',
					   -bgcolor     => 'orange',
						-fgcolor     => 'black',
						-font2color  => 'red',
						-key         => $predicted_track_type,
						-bump        => +1,
						-height      => 8,
						-label       => 1,
						-description => \&peptide_label,
						-min_score => 0,
	    				-max_score => 1, #Remember the score is reversed down below so 0 is the best score and boldest color
                      );
    delete $sorted_features{$predicted_track_type};
   } 




	# general case
	my @colors = qw(red green blue purple chartreuse magenta yellow aqua);
	my $idx    = 0;
	for my $tag ( sort keys %sorted_features ) {
		#print "SORTED TAG '$tag'\n";
		 
		#feature objects have the score tag built in which is mapped to inbetween the low and high
		my $features = $sorted_features{$tag};
		
		#make color gradient colors s
		my $track = $panel->add_track(
			$features,
			-glyph       => 'generic',
			-bgcolor     => $colors[ $idx++ % @colors ],
			-fgcolor     => 'black',
			-font2color  => 'red',
			-key         => "${tag}",
			-bump        => +1,
			-height      => 8,
			-label       => 1,
			-description => sub {my $feature = shift; return $feature->display_name},
			-min_score => 0,
		    -max_score => 10,
		);
	}
	
	
	open( OUT, ">$img_file" ) || die $!;
	binmode(OUT);
	
	print OUT $panel->png;
	close OUT;

}
#######################################################
#general_label
#######################################################
sub peptide_label {
     my $feature = shift;
     my $note = $feature->display_name();
     my $score = '';
    
     if ($feature->primary_tag eq $predicted_track_type){
     	#the GD graph score only maps from low to high.  Higher being better
     	#but the predicted glyco score is lower is better.  So re-map the score for the image
     	#but display the orginal score
     	$score = predicted_score($feature);
        $note .= sprintf(" GS = %01.2f",$score);
     }else{
     	#Identified score is peptide prophet
     	$score = $feature->score();
     	$note .= sprintf(" PP = %01.2f",$score);
     }
    
     
     
     
     return $note;
}

######################################################
#predicted_score
######################################################
sub predicted_score {
	my $feat_o = shift;
	my $score = $feat_o->score();
	my $mapped_score = 1-$score;
	
	$feat_o->score($mapped_score);
	return $score;
}

######################################################
#get_annotation
######################################################
sub get_annotation {
	
	my %args = @_;
	my $glyco_o = $args{glyco_o};
	my $anno_type = $args{anno_type};
	
	$glyco_o->get_protein_info(); 
    my $seq =  $glyco_o->seq_info();		
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
