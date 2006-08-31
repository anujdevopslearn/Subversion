#!/usr/local/bin/perl

###############################################################################
# $Id$
#
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
###############################################################################


###############################################################################
# Get the script set up with everything it will need
###############################################################################
use strict;
use vars qw ($q $sbeams $sbeamsMOD $PROG_NAME
             $current_contact_id $current_username $glyco_query_o);
use lib qw (../../lib/perl);
use CGI::Carp qw(fatalsToBrowser croak);
use Data::Dumper;

use SBEAMS::Connection qw($q $log);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TabMenu;

use SBEAMS::Glycopeptide;
use SBEAMS::Glycopeptide::Settings;
use SBEAMS::Glycopeptide::Tables;

use SBEAMS::Glycopeptide::Get_glyco_seqs;
use SBEAMS::Glycopeptide::Glyco_query;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::Glycopeptide;
$sbeamsMOD->setSBEAMS($sbeams);


$glyco_query_o = new SBEAMS::Glycopeptide::Glyco_query;
$glyco_query_o->setSBEAMS($sbeams);


###############################################################################
# Global Variables
###############################################################################
$PROG_NAME = 'main.cgi';
my $file_name    = $$ . "_glyco_predict.png";
my $tmp_img_path = "images/tmp";
my $img_file     = "$PHYSICAL_BASE_DIR/$tmp_img_path/$file_name";

my $predicted_track_type = "Predicted Peptides";
my $id_track_type 		 = 'Identified Peptides';
my $glyco_site_track = "N-Glyco Sites";
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);
my $base_url = "$CGI_BASE_DIR/$SBEAMS_SUBDIR/Glyco_prediction.cgi";

my @search_types = ('Gene Symbol',
					'Gene Name/Alias',
					'Swiss Prot Accession Number',
					'IPI Accession Number',
          'GeneID'
					  );


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
       permitted_work_groups_ref=>['Glycopeptide_user','Glycopeptide_admin', 'Glycopeptide_readonly'],
        # connect_read_only=>1,
        allow_anonymous_access=>1,
    ));

    for my $p ( $q->param() ) { $log->info( "$p => " . $q->param( $p ) ); }

    #### Read in the default input parameters
    my %parameters;
    my $n_params_found = $sbeams->parse_input_parameters(
        q=>$q,
        parameters_ref=>\%parameters
        );
#    $sbeams->printCGIParams($q);


    ## get project_id to send to HTMLPrinter display
    my $project_id = $sbeams->getCurrent_project_id();


    #### Process generic "state" parameters before we start
    $sbeams->processStandardParameters(parameters_ref=>\%parameters);
    #$sbeams->printDebuggingInfo($q);

    #### Decide what action to take based on information so far
    $sbeamsMOD->display_page_header(project_id => $project_id);
    $sbeams->printStyleSheet();
    if ($parameters{action} eq "Show_detail_form" || $parameters{redraw_protein_sequence} == 1) {
		
		 clean_params(\%parameters);
		
		 my $ipi_data_id = $parameters{'ipi_data_id'};
		
    print $sbeams->getGifSpacer(800);
		print $sbeams->getPopupDHTML();
		display_detail_form(ref_parameters=>\%parameters,
							ipi_data_id => $ipi_data_id,
							);
		
		
	}elsif($parameters{action} eq 'Show_hits_form'){
		
#		 $sbeamsMOD->display_page_header(project_id => $project_id);
    print $sbeams->getGifSpacer(800);
		print $sbeams->getPopupDHTML();
		
		display_hits_form(ref_parameters=>\%parameters);
#		$sbeamsMOD->display_page_footer();
    
    } else {

#        $sbeamsMOD->display_page_header(project_id => $project_id);
    print $sbeams->getGifSpacer(800);
		handle_request(ref_parameters=>\%parameters);
#		$sbeamsMOD->display_page_footer();

    }

		$sbeamsMOD->display_page_footer();



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
	
	print 
	$q->table({class=>'table_setup'},
          $q->Tr({class=>'rev_gray_head'},
	     $q->td({colspan=>2, class=>'rev_gray_head'}, $q->h2("ISB N-glycosylation peptide prediction server")),
	  	 
	  ),
	  $q->Tr(
 	     $q->td({colspan=>2}, "The ISB N-Glyco prediction server shows all the N-linked glycosylation site contained 
		    within predicted and identified tryptic peptides.  
		    The Glyco score indicates how likely the site is glycosylated and the detection score
		    is an indication on how likely the glycosylated peptide will be detected in a MS/MS run.  This is 
		   useful for quantitating proteins of interest. 
		   <br>
		   Click <a href='http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?cmd=Retrieve&db=pubmed&dopt=Abstract&list_uids=15637048'>here</a>
		   for more information."
	     )
	 ), 
	$q->Tr(
	   $q->td({colspan=>2},'&nbsp; <br> &nbsp;') 
	 ),	    
	 $q->Tr({class=>'rev_gray_head'},
	   $q->td({colspan=>2, class=>'rev_gray_head'}, $q->h2("Text Search"))
	 ),
	 $q->Tr(
	   $q->td({class=>'grey_bg'}, "Choose Search option"),
	   $q->td(
	      $q->start_form(),
	      $q->popup_menu(-name=>'search_type',
                                -values=>\@search_types,
                                -default=>['Gene Symbol'],
                                -size=>1,      
	   			)
	   )
	 ),
	 $q->Tr(
	  $q->td({class=>'grey_bg'},'Search Term'),
	  $q->td(
	     $q->textfield(-name=>'search_term',
                           -value=>'',
                           -size=>50,
                           -maxlength=>80)
	  )  
	 ),
	 $q->Tr(
 	   $q->td({class=>'blue_bg_glyco', colspan=>2}, "Wildcard character '%' can be used to broaden the search")
	 ),
	
	 $q->Tr(
	   $q->td({colspan=>2}, " <B>-- or --</B> <br>")
	 ), 
	 $q->Tr({class=>'rev_gray_head'},
	   $q->td({colspan=>2, class=>'rev_gray_head'}, $q->h2("Sequence Search") )
	 ), 
	 
	 $q->Tr(
	    $q->td({class=>'grey_bg'}, "Search by Protein Sequence"),
	    $q->td(
	       $q->textarea(-name=>'sequence_search',
                          -default=>'',
                          -rows=>8,
                          -columns=>50)
	    )
	 ),
	 $q->Tr(
	    $q->td({class=>'blue_bg_glyco', colspan=>2}, "Sequence search wildcard is also '%', sequences will be truncated at 500 residues.")
	 ),
	

	),#end table
	
	$q->submit(), 
	$q->reset(),
	$q->hidden(-name=>'action',
               -default=>['Show_hits_form']),
	$q->endform();

### add an Example table
	my $cgi_url = "$base_url?action=Show_hits_form&search_type";
	print 
	"<br><br>",
	$q->table(
	   $q->Tr(
	      $q->td({class=>'rev_gray_head', colspan=>2}, $q->h2("Examples"))
	   ),
	   $q->Tr(
              $q->td({class=>'grey_bg'}, "Gene Name"),
              $q->td($q->a({href=>"$cgi_url=Gene Symbol&search_term=ALCAM"}, "ALCAM") )
	   ),
	   $q->Tr(
              $q->td({class=>'grey_bg'}, "Wild Card Gene Name"),
              $q->td($q->a({href=>"$cgi_url=Gene Name/Alias&search_term=CD%"}, "CD%") )
	   ),
	   $q->Tr(
              $q->td({class=>'grey_bg'}, "IPI Accession Number"),
              $q->td($q->a({href=>"$cgi_url=IPI Accession Number&search_term=IPI00015102"}, "IPI00015102") )
	   ),
	   $q->Tr(
              $q->td({class=>'grey_bg'}, "Protein Sequence"),
              $q->td(">IPI00015102|Partial protein sequence|Cut and paste into sequence search window<br>MESKGASSCRLLFCLLISATVFRPGLGWYTVNSAYGDTIIIPCRLDVPQNLMF") 
	   ),
	   $q->Tr(
              $q->td({class=>'grey_bg'}, "Gene ID"),
              $q->td($q->a({href=>"$cgi_url=GeneID&search_term=214"}, "214") )
	   ),
	);
}
###############################################################################
# Show hits form
###############################################################################
sub display_hits_form {
 	my %args = @_;

  #### Process the arguments list
  my $params = $args{'ref_parameters'} || die "ref_parameters not passed";
  my $sql_data = find_hits($params);

}

###############################################################################
#find_hits
#Check the parameter and figure out what query to run
###############################################################################
sub find_hits{
	my $method = 'find_hits';
	
	my $ref_parameters = shift;
	my %parameters = %{$ref_parameters};
	
				  
	#check to see if this is a sequence or text search
	my $type = check_search_params($ref_parameters);
	my @results_set = ();
	
  if ($type eq 'text'){
    if ($parameters{search_type} eq 'Gene Symbol'){
      @results_set = $glyco_query_o->gene_symbol_query($parameters{search_term});	
    }elsif($parameters{search_type} eq 'Gene Name/Alias'){
      @results_set = $glyco_query_o->gene_name_query($parameters{search_term});	
    }elsif($parameters{search_type} eq 'Swiss Prot Accession Number'){
      @results_set = $glyco_query_o->swiss_prot_query($parameters{search_term});	
    }elsif($parameters{search_type} eq 'IPI Accession Number'){
      @results_set = $glyco_query_o->ipi_accession_query($parameters{search_term});	
    }elsif($parameters{search_type} eq 'GeneID'){
      @results_set = $glyco_query_o->gene_id_query($parameters{search_term});	
    }else{
      print_error("Cannot find correct textsearch to run");
    }
  }elsif($type eq 'sequence_search'){
    @results_set = $glyco_query_o->protein_seq_query($parameters{sequence_search});	
  }else{
    print_error("Cannot find correct search type to run '$type'");
  }
	
	
	
    if (@results_set){
    	
    	if (scalar(@results_set) == 1 ){
			#pull out the ipi_id and directly dispaly the details page since there is only one hit
			my $href_results_info = $results_set[0];
			my $ipi_data_id = $href_results_info->{'ipi_data_id'};
			display_detail_form(ipi_data_id 	=> $ipi_data_id, 
								ref_parameters 	=> $ref_parameters);
		}else{
			print_out_hits_page(results_set_aref =>\@results_set,
					     ref_parameters  => $ref_parameters);
    	}
	}else{
		my $term = $parameters{search_term} ?$parameters{search_term}:$parameters{sequence_search};
		print $q->h3("Sorry No Hits were found for the query '$term'
		");
	}

}
###############################################################################
#print_out_hits_page
#
###############################################################################
sub print_out_hits_page{
	
	my %args = @_;

	my @results_set = @{ $args{results_set_aref} };
	my %parameters = %{ $args{ref_parameters} };
  my $html;

	if (exists $parameters{similarity_score} && defined $parameters{similarity_score}){
		$html .= $q->p(
			$q->h3("Protein Similarity Score (Percent Match) <span class='lite_blue_bg'>" . $parameters{similarity_score} . "</span>"),
		);
	}
	
	$html .= $q->start_table();
  $html .= $q->Tr({class=>'rev_gray_head'},
			  $q->td('IPI ID'),
			  $q->td('Protein Name'),
			  $q->td('Protein Symbol'),
			  $q->td('Identified Peptides')
			);
  $log->info( $html );
	my $cgi_url = "$base_url?action=Show_detail_form&ipi_data_id";
  my $protcnt = 0;
  my $pepprotcnt = 0;
  my $cutoff = $sbeamsMOD->get_current_prophet_cutoff();
  my $pepcnt = 0;
	foreach my $h_ref (@results_set){
		my $ipi_id = $h_ref->{ipi_data_id};
		my $num_identified = $h_ref->{num_identified};
		my $ipi_acc = $h_ref->{ipi_accession_number};
		my $protein_name = nice_term_print($h_ref->{protein_name});
		my $protein_sym = $h_ref->{protein_symbol};
    $protcnt++;
    $pepprotcnt++ if $num_identified;
    $pepcnt += $num_identified;
		$html .= $q->Tr(
			    $q->td(
			    	$q->a({href=>"$cgi_url=$ipi_id"},$ipi_acc)
			    ),
			    $q->td($protein_name),
			    $q->td($protein_sym),
			    $q->td({ALIGN=>'right'},$num_identified)
			  );
	}
	$html .= "</table>";

  my $type = ( check_search_params(\%parameters) eq 'text' ) ? 
                                                      $parameters{search_type} :
                                                       'sequence';
  my $value = '';
  if ($type eq 'sequence') {
    $value = $parameters{sequence_search};
    if ( length($value) > 12 ) {
      $value = substr($value, 0, 12) . '...';
    }
  } else {
    $value = $parameters{search_term};
  }

  my $ofwhich = "of which $pepprotcnt";
  my $contain = ( $pepprotcnt > 1 ) ? 'contain' : 'contains';
  if ( $pepprotcnt == $protcnt || $pepcnt == 0 ) {
    $ofwhich = 'which';
  }

  my $stats = qq~
  <BR><FONT COLOR=GREEN>
  Your search for proteins with $type = 
  '$value'  found  $protcnt proteins $ofwhich $contain
  a total of $pepcnt peptides at a prophet cutoff of $cutoff
  </FONT>
  <BR>
  <BR>
  ~;
  print "$stats $html";
}

###############################################################################
#nice_term_print
#put breaks into long lines
###############################################################################
sub nice_term_print{
	my $info = shift;
	my @html = ();
	
	my $info = substr($info, 0, 75, '...'); #chop things down to 75 or less
	my @hold = split /\s/, $info;
	
	my $count = 0;
	foreach my $term(@hold){
		if ($count <= 5){
			push @html, $term;
		}else{
			$count == 0;
			push @html, "$term<br>";
		}
	
	}
	return join " ", @html;
}

###############################################################################
#print_error
#print a simple error message
###############################################################################
sub print_error{
	my $error = shift;
	
	print $q->header,
	$q->start_html,
	$q->p($q->h3($error)),
	$q->end_html;
	
	exit;
	
}

###############################################################################
#check_search_params
#Make sure that the params only have a text search or sequence not both
###############################################################################
sub check_search_params{
	my $ref_parameters = shift;
	
	if ($ref_parameters->{search_term} =~ /\w/){
		if ($ref_parameters->{sequence_search} =~ /\w/ ){
			print_error("Cannot have a Text Search and Sequence Search in the same query");
		}
	}elsif($ref_parameters->{sequence_search} =~ /\w/ ) {
		return ('sequence_search');
	}
	return 'text';

}

###############################################################################
#clean_params
#foreach param this script knows about make sure nothing bad is comming in from the outside
###############################################################################
sub clean_params{
	my $ref_parameters = shift;
	
	KEY:foreach my $k (keys %{$ref_parameters}){

		if ($k eq 'action'){
			$ref_parameters->{$k} = clean_action($ref_parameters->{$k});
		}elsif($k eq 'search_type' ){
		
			next KEY if ( $ref_parameters->{'sequence_search'} );# ignore if this is a sequnce search
			
			($ref_parameters->{$k},$ref_parameters->{'search_term'} ) = 
				check_search_term(type=>$ref_parameters->{$k},
							      term =>$ref_parameters->{'search_term'});
			
		
		}elsif($k eq 'search_term'){
		 	next; #already scaned above
		
		}elsif($k eq 'sequence_search'){
			$ref_parameters->{$k} = clean_seq($ref_parameters->{$k});
		}elsif($k eq 'ipi_data_id'){
			$ref_parameters->{$k} = clean_term($ref_parameters->{$k});
		}elsif($k eq 'similarity_score'){
			 $ref_parameters->{$k} = clean_term($ref_parameters->{$k});
##Parameters for re-drawing the protien map
		}elsif($k eq 'Glyco Site'){
			$ref_parameters->{$k} = clean_term($ref_parameters->{$k});
		}elsif($k eq 'Predicted Peptide'){
			$ref_parameters->{$k} = clean_term($ref_parameters->{$k});
		}elsif($k eq 'Identified Peptide'){
			$ref_parameters->{$k} = clean_term($ref_parameters->{$k});
		}elsif($k eq 'Signal Sequence'){
			$ref_parameters->{$k} = clean_term($ref_parameters->{$k});
		}elsif($k eq 'Trans Membrane Seq'){
			$ref_parameters->{$k} = clean_term($ref_parameters->{$k});
		}elsif($k eq 'redraw_protein_sequence'){
			$ref_parameters->{$k} = clean_term($ref_parameters->{$k});
		}else{
# Doesn't allow std sbeams params through
#print_error("Unknown Paramater passed in '$k' ")
		}	
   
	}
	return $ref_parameters;
}
###############################################################################
#clean_seq
#Clean the sequence to a single clean AA string, but allow wild cards to pass
###############################################################################
sub clean_seq{
	my $seq = shift;
	
  # Does this work on winders?
  my @seq_lines = split/\n/, $seq;
  chomp @seq_lines;

	my @clean_seq = ();
	
	foreach my $line (@seq_lines){
		next if( $line =~ /^>/);
		$line =~ s/[^A-Z\%]//g;
		push @clean_seq, $line
	}
	my $seq_line = join '', @clean_seq;
	$seq_line = substr($seq_line, 0, 500);
	return $seq_line;
}


###############################################################################
#check_search_term
#Make sure the search term is appropriate for the search type
###############################################################################
sub check_search_term{
	my %args = @_;
	my $type = $args{type};
	my $term = $args{term};
	
	print_error("Must Supply A Serch Type, you gave '$type'") unless ($type);
	print_error("Must Supply A Serch Term, you gave '$term'") unless ($term);
	
	
	unless ( (grep {$_ eq $type} @search_types) ){
		print_error("Search Type '$type' is Not vaild, please fix the problem") unless ($type);
	}
	
	my $clean_term = clean_term($term);
	
	##Look at the different search terms and make sure the data looks ok
	if ($type eq 'Gene Symbol'){
		if ($clean_term =~ /\s/){
			print_error("Gene Symobols Cannot have any spaces '$clean_term'");
		}
	}elsif($type eq 'Swiss Prot Accession Number'){
		
		unless($clean_term =~ /^\w/){
			print_error("Swiss Prot Accession Does not look good '$clean_term'");
		}
	}elsif($type eq 'IPI Accession Number'){
		
		unless($clean_term =~ /^IPI\d+/){
			print_error("IPI Accession Number does not look good '$clean_term'");
		}
		
	}
	return ($type, $clean_term);
	
}

###############################################################################
#clean_term
#remove any bad characters
###############################################################################
sub clean_term{
	my $term = shift;
	
	$term =~ s/["'*.]//g; #Remove quotes, "*",  "."
	$term =~ s/^\s+//g; 		#Remove white space at the start
	$term =~ s/\s+$//g;		#Remove white space at the end
	
	if ($term =~ /^\%$/){ #check for just a wild car search
		print_error("Must provide more then just a wild card '$term' ") unless ($term);
	}
	unless ( (grep {$_ eq $term} @search_types) ){
		print_error("Search Term '$term' HAS BEEN DELTED") unless ($term);
	}
	return $term;
}

###############################################################################
#clean_action
#Make sure this is a param we know about
#Print error if not a good param
###############################################################################
sub clean_action{
	my $action_param = shift;
	
	#Add all the possible action parameters here
	my @good_actions = qw(Show_hits_form
						  Show_detail_form
						);
	if ( (grep {$_ eq $action_param} @good_actions) ){
		return $action_param;
	}else{
		print_error("ACTION PARAMETER '$action_param' IS NOT VALID");
	}

}




###############################################################################
#display_detail_form
###############################################################################
sub display_detail_form{

  my %args = @_;
  
  my %parameters = %{$args{ref_parameters}};
  my $ipi_data_id = $args{ipi_data_id}; 
    
  print_error("Must provide a ipi_id to display Glyco Info. '$ipi_data_id' is not valid")unless 
  ($ipi_data_id =~ /^\d+$/);
	
  #go an query the db, add the peptide features and make into a big Bio::Seq object
  my $glyco_o = new SBEAMS::Glycopeptide::Get_glyco_seqs( ipi_data_id => $ipi_data_id,
                                                              _sbeams => $sbeams );
  
  make_image(glyco_o => $glyco_o);
  my $swiss_id = get_annotation(glyco_o   => $glyco_o,
								  anno_type => 'swiss_prot'
							     );
  my $html_protein_seq = $glyco_o->get_html_protein_seq(ref_parameters=>\%parameters);
  my $protein_name = get_annotation(glyco_o   => $glyco_o,
									  anno_type => 'protein_name'
									  );
  my $ipi_acc = $glyco_o->ipi_accession();
    
  my $ipi_url = $glyco_o->make_url(term=> $glyco_o->ipi_accession(),
				     dbxref_tag => 'EBI_IPI'
  );
    
  my $swiss_prot_url = $glyco_o->make_url(term=>$swiss_id, 
                                     dbxref_tag => 'SwissProt'
                                    );
 

###
### Display the Protein peptide image ###
    my $protein_map = join( " ", 
			$q->Tr(
				$q->td({class=>'grey_header', colspan=>2}, "Protein/Peptide Map"),
			),
			$q->Tr(
				$q->td({colspan=>2},"<img src='$HTML_BASE_DIR/$tmp_img_path/$file_name' alt='Sorry No Img'>")
			
			),
			$q->Tr(
				$q->td({colspan=>2},
					#make a table to describe what is in the table
					$q->table(
						$q->Tr({class=>'small_text'},
							$q->td({class=>'blue_bg'}, "Track Name"),
							$q->td({class=>'blue_bg'}, "Description"),
						),
						$q->Tr({class=>'small_cell'},
							$q->td("Identified Peptides"),
							$q->td( "Glyco Site Location (Protein Prophet Score).  Color is scaled based on prophet score, light to dark between 0.5 and 1.0" ),
						),
						$q->Tr({class=>'small_cell'},
							$q->td("N-Glyco Sites"),
							$q->td( "Location of all theoretical NXS/T-motif Glycosylation sites"),
						),
						$q->Tr({class=>'small_cell'},
							$q->td("Signal Sequence"),
							$q->td( "Location of the Signal or Anchor sequence as predicted by Signal P"),
						),
            $q->Tr({class=>'small_cell'},
              $q->td("Transmembrane"),
              $q->td( "Predicted as a transmembrane domain by TMHMM"),
            ),
            $q->Tr({class=>'small_cell'},
              $q->td("Intracellular"),
              $q->td( "Predicted as intracellular by TMHMM"),
            ),
            $q->Tr({class=>'small_cell'},
              $q->td("Extracellular"),
              $q->td( "Predicted as Extracellular by TMHMM"),
            ),
					)
				
				
				)
			
			)
    );
    $protein_map = "<TABLE WIDTH=100%>$protein_map</TABLE>\n";

# $q->Tr({class=>'small_cell'},
# $q->td("Predicted Peptides"),
# $q->td( "Glyco Site Location, GS = N-Glycosylation Score. 1 low, 0 high probability of N linked Glycosylation site"),
# ),
# $q->Tr({class=>'small_cell'},
# $q->td("Identified/Predicted Peptides"),
# $q->td( "Peptides are color coded according to scores assoicated with each track.  More intense color means better score"),
# ),
    my $hidetext = '<B>Hide protein map</B>';
    my $showtext = '<B>Show protein map</B>';

    my $protein_url = $glyco_o->get_atlas_link( name => $glyco_o->ipi_accession(), 
                                                type => 'image',
                                              onmouseover => 'View Peptide Atlas information' );

    $protein_map = $sbeams->make_toggle_section ( content => $protein_map,
                                                  visible => 1,
                                                 textlink => 1,
                                                   sticky => 1,
                                                  imglink => 1,
                                                 hidetext => $hidetext,
                                                 showtext => $showtext,
                                              neutraltext => '',
                                                     name => '_glycopep_protein_map',);
    
    
  my $spacer = $sbeams->getGifSpacer( 600 );
			
	## Print out the protein Information
  my $prot_info = join( "\n", 
    $q->Tr(
      $q->td({class=>'grey_header', colspan=>2}, "Protein Info"),),
    $q->Tr(
      $q->td({class=>'rev_gray_head'}, "IPI ID"),
      $q->td("$ipi_url  [ View in Peptide Atlas: $protein_url ]")),
    $q->Tr(
      $q->td({class=>'rev_gray_head', nowrap=>1}, "Protein Name"),
      $q->td( $protein_name )),

    $q->Tr(
      $q->td({class=>'rev_gray_head', nowrap=>1}, 
              $glyco_o->linkToColumnText(display => "Protein Symbol",
                                         title   => "Protein Symbol Info", 
                                         column  => "protein_symbol", 
                                         table   => "GP_ipi_data" 
                 
                                   )),
      $q->td(get_annotation(glyco_o   => $glyco_o,
									  anno_type => 'symbol'
									  ) . $spacer
					   )
			  ),

    $q->Tr(
      $q->td({class=>'rev_gray_head', nowrap=>1}, 
				$glyco_o->linkToColumnText(display => "Subcellular Location",
								 title   =>"Find More Info About the Subcellular Location Call", 
								 column  =>"cellular_location_id", 
								 table   => "GP_ipi_data" 
								 
								)),
				
      $q->td(get_annotation(glyco_o   => $glyco_o,
	        								  anno_type => 'cellular_location' ) )
			    ),

    $q->Tr(
      $q->td({class=>'rev_gray_head', nowrap=>1}, "Swiss Prot ID"),
      $q->td($swiss_prot_url)
			  ),
    $q->Tr(
      $q->td({class=>'rev_gray_head'}, 
				$glyco_o->linkToColumnText(display => "Synonyms",
								 title   =>"Synonyms Info", 
								 column  =>"synonyms", 
								 table   => "GP_ipi_data" 
								 
								)),
      $q->td(get_annotation(glyco_o   => $glyco_o,
									  anno_type => 'synonyms'
									  )
					   )
			  ),
    $q->Tr(
      $q->td({class=>'rev_gray_head', nowrap=>1}, "Protein Summary"),
      $q->td(get_annotation(glyco_o   => $glyco_o, anno_type => 'summary') )
			    ) 
    );  # End prot_info

## Display the predicted Peptide info
    
  my $predicted_info = join( "\n", 
		$q->Tr(
				$q->td({class=>'grey_header', colspan=>2}, "Predicted N-linked Glycopeptides"),
			),
		$q->Tr(
				$q->td({colspan=>2},$glyco_o->display_peptides('Predicted Peptides'))
			
			)
    ); # End predicted info

    my $hidepred = '<B>Hide predicted peptides</B>';
    my $showpred = '<B>Show predicted peptides</B>';

    my $predicted_info_toggle = $sbeams->make_toggle_section ( content => $predicted_info,
                                                  visible => 1,
                                                 textlink => 1,
                                                   sticky => 1,
                                                  imglink => 1,
                                                 hidetext => $hidepred,
                                                 showtext => $showpred,
                                              neutraltext => '',
                                                     name => '_glycoprotein_prediced_peptides',);
## Display Identified Peptides
  my $identified_info = join( "\n", 
		$q->Tr(
				$q->td({class=>'grey_header', colspan=>2}, "Identified N-linked Glycopeptides"),
			),
		$q->Tr(
				$q->td({colspan=>2},$glyco_o->display_peptides('Identified Peptides'))
			
			),
    ); # End identified info

### Display the Amino Acid Sequence ###
    
  my $prot_seq = join( "\n", 
			$q->Tr(
				$q->td({class=>'grey_header', colspan=>2}, 
				"Protein/Peptide Sequence"),
			),
			$q->Tr(
				$q->td({colspan=>2, class=>'sequence_font'},">$ipi_url|$protein_name<br>$html_protein_seq")
			
			),
    ); # End identified info

  my %chk = ( predicted_pep => '',identified_pep => '',sseq => '',tmhmm => '' );

  if ( $parameters{redraw_protein_sequence} ) {
    for my $tag ( keys(%chk) ) {
      $chk{$tag} = 'checked' if $parameters{$tag};
    }
  }

# FIXME change to javascript/DHTML
  my $sp = '&nbsp;';
  my $display_form = join( "\n", 
    $q->start_form(-action=>$q->script_name().'#protein_sequence'),
    $q->table( {border=>0, width=>'40%'},
    $q->Tr( 
    $q->Tr( 
      $q->td( {class=>'predicted_pep', nowrap => 1 }, "$sp Predicted <INPUT TYPE=CHECKBOX NAME=predicted_pep $chk{predicted_pep}></INPUT>" ),
      $q->td( {class=>'identified_pep', nowrap => 1  },"$sp Identified <INPUT TYPE=CHECKBOX NAME=identified_pep $chk{identified_pep}></INPUT>" ),
      $glyco_o->has_signal_sequence() ?  $q->td( {class=>'sseq', nowrap => 1 },"$sp Signal Sequence <INPUT TYPE=CHECKBOX NAME=sseq $chk{sseq}></INPUT>" ) : '',
      $glyco_o->has_transmembrane_seq() ? $q->td( {class=>'tmhmm', nowrap => 1  },"$sp Transmembrane <INPUT TYPE=CHECKBOX NAME=tmhmm $chk{tmhmm}></INPUT>" ) : '',
          ),
      $q->hidden(-name=>'ipi_data_id', -value=>$ipi_data_id, -override => 1),
      $q->hidden(-name=>'redraw_protein_sequence', -value=>1),
      $q->td( {colspan=>4, class=>'instruction_text',nowrap=>1 }, 
              "<INPUT TYPE=SUBMIT NAME='redisplay' VALUE='Update Display'></INPUT> Select items above to customize displayed sequence annotations " ),
          ),
    $q->end_form()
    ) # End table
  ); # End identified info
			
#       $q->Tr(
#       $q->start_form(-action=>$q->script_name()."#protein_sequence"),
#       $q->td({colspan=>2, class=>'sequence_font'},
#       $q->table({border=>0},
#       $q->Tr(
#       $q->td({class=>'blue_bg', colspan=>5}, "Click a button to highlight different sequence features")
#       ),
#       $q->Tr({class=>'sequence_font'},
#       $q->td($q->submit({-name=>'Glyco Site',  -value=>'Glyco Site', class=>'glyco_site' })),
#       $q->td($q->submit({-name=>'Predicted Peptide',  -value=>'Predicted Peptide', class=>'predicted_pep' })),
#       $q->td($q->submit({-name=>'Identified Peptide',  -value=>'Identified Peptide', class=>'identified_pep' })),
#       $glyco_o->has_signal_sequence()? $q->td($q->submit({-name=>'Signal Sequence',  -value=>'Signal Sequence', class=>'sseq' })):"",
#       $glyco_o->has_transmembrane_seq()  ?$q->td($q->submit({-name=>'Trans Membrane Seq',  -value=>'Trans Membrane Seq', class=>'tmhmm' })):"",
#       ),
#       )#close sequencetable header
#       ),
#       $q->hidden(-name=>'ipi_data_id', -value=>$ipi_data_id, -override => 1),
#       $q->hidden(-name=>'redraw_protein_sequence', -value=>1),
#       
#       $q->end_form()

#             ),
	     #add in an anchor id tag to make protein higlights come back here
	    
	
### Print Out the HTML to Make Dispaly the info About the the Protein and all it's Glyco-Peptides
  print $q->table({border=>0},
           $prot_info,
           $predicted_info,
           $identified_info,
           $prot_seq,
           $display_form,
				);#end_table	
		
	print "$protein_map\n";	
	print $q->a({id=>'protein_sequence'});
	
	



	

} #end handle request

######################################################
#make imgae
#
#####################################################
sub make_image {
	my %args = @_;
	my $glyco_o = $args{glyco_o};

	
   my $seq =  $glyco_o->seq_info();					
   
  
   my $wholeseq = Bio::SeqFeature::Generic->new(
	-start        => 1,
	-end          => $seq->length(),
	-display_name => $seq->display_id
	);

	my @features = $seq->all_SeqFeatures;
	
### partition features by their primary tags
	my %sorted_features;
	for my $f (@features) {
		my $tag = $f->primary_tag;
	#	print "FEATURE PRIMARY TAG '$tag'\n<br>";
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
	
	$panel->add_track(
		$wholeseq,
		-glyph   => 'generic',
		-bgcolor => 'blue',
		-label   => 0
	);
	
	##### Add Track for Identified Sequences
 ##Adjust score to Protein Prohet score
   if ($sorted_features{$id_track_type}) {
     use Data::Dumper;
     
# my $sequence = ${sorted_features{$id_track_type}}->seq();
     my %seen;
     my @non_redundant;
     for my $f ( @{$sorted_features{$id_track_type}} ) {
       push @non_redundant, $f unless $seen{$f->seq()->seq()};
       $seen{$f->seq()->seq()}++;
     }
#     $log->debug( Dumper( ${sorted_features{$id_track_type}} ) );
     $panel->add_track( \@non_redundant,
            -glyph       => 'graded_segments',
					  -bgcolor     => 'goldenrod',
						-fgcolor     => 'black',
						-font2color  => '#882222',
						-key         => $id_track_type,
						-bump        => 1,
            -bump_limit  => 3,
						-height      => 8,
						-label => \&peptide_label,
						-min_score => 0.5,
	    				-max_score => 1,
                      );
    delete $sorted_features{$id_track_type};
   }
   
  ##### Add Track for Predicted Sequences  -- taken out for now
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
                      ) if 0;
    delete $sorted_features{$predicted_track_type};
   } 

   if ($sorted_features{$glyco_site_track}) {
     $panel->add_track($sorted_features{$glyco_site_track},
            -glyph       => 'segments',
            -bgcolor     => 'salmon',
            -fgcolor     => 'black',
            -font2color  => 'red',
            -key         => $glyco_site_track,
            -bump        => 1,
            -bump_limit  => 2,
            -height      => 8,
						-label       =>  sub {my $feature = shift; return $feature->start},
						-description => '',
                      );
    delete $sorted_features{$glyco_site_track};
   } 

#  my $cmap = "\n"; for my $c ( $panel->color_names() ) { $cmap .= "$c\n"; } $log->debug( $cmap );

	# general case
# my @colors = qw( cornflowerblue greenyellow green coral purple aqua);
  my %colors = (  'Signal Sequence' => 'cornflowerblue',
                     Transmembrane => 'greenyellow',
                     intracellular => 'coral',
                     extracellular => 'green' );

	for my $tag ( sort keys %sorted_features ) {
		#print "SORTED TAG '$tag'\n";
		 
		#feature objects have the score tag built in which is mapped to inbetween the low and high
		my $features = $sorted_features{$tag};
		
		#make color gradient colors s
		my $track = $panel->add_track(
			$features,
			-glyph       => 'segments',
			-bgcolor     => $colors{$tag},
			-fgcolor     => 'black',
			-font2color  => 'red',
			-key         => "${tag}",
			-bump        => +1,
			-height      => 8,
      -legend      => 1,
			-label       => 1,
			-description => sub {my $feature = shift; return $feature->display_name},
			-min_score => 0,
	    -max_score => 10,
		);
	}
	
	#add the scale bar
	$panel->add_track(
		$wholeseq,
		-glyph  => 'arrow',
		-bump   => 0,
		-double => 1,
		-tick   => 2
	);
	
	open( OUT, ">$img_file" ) || die "$!: $img_file";
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
     	$note .= ' (' . sprintf("%01.2f",$score) . ')';
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
	
	#$glyco_o->get_protein_info(); 
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


       # permitted_work_groups_ref=>['Glycopeptide_user','Glycopeptide_admin',
