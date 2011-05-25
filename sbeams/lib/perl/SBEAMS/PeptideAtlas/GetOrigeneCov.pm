package SBEAMS::PeptideAtlas::GetOrigeneCov;
###############################################################################
# Program     : GetOrigeneCov
# Description : Prints summary of a given protein given selection
#               atlas build and protein name.
#
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################


###############################################################################
# Set up all needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use CGI qw(:standard *table :nodebug);
use FindBin;
$|++;
use XML::Xerces;
use lib "$FindBin::Bin/../../lib/perl";
use vars qw ($sbeams $sbeamsMOD $q $current_contact_id $current_username
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $DATABASE
             $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
             @MENU_OPTIONS);

use SBEAMS::Connection qw($q $log);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TabMenu;
$sbeams = new SBEAMS::Connection;

use SBEAMS::BioLink;
my $biolink = SBEAMS::BioLink->new();
$biolink->setSBEAMS($sbeams);

use SBEAMS::BioLink;
my $biolink = new SBEAMS::BioLink;

use SBEAMS::PeptideAtlas::KeySearch;
my $keySearch = new SBEAMS::PeptideAtlas::KeySearch;
$keySearch->setSBEAMS($sbeams);

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;

$sbeamsMOD = new SBEAMS::PeptideAtlas;
$sbeamsMOD->setSBEAMS($sbeams);
$sbeams->setSBEAMS_SUBDIR($SBEAMS_SUBDIR);


use SBEAMS::PeptideAtlas::BestPeptideSelector;
my $bestPeptideSelector = new SBEAMS::PeptideAtlas::BestPeptideSelector;
$bestPeptideSelector->setSBEAMS($sbeams);
$bestPeptideSelector->setAtlas($sbeamsMOD);
my @methods =  qw(ITCID FTCID ITETD FTETD HCD);
my $max_intensity = 1;
my %coverage=();
my $NUM_STEPS = 50;

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;
    return($self);
} # end new



sub get_sequence_graphic {
  my $self = shift || die ("self not passed");
  my %args = @_;
  my $protseq = $args{protein_data}->{biosequence_seq};
  my $protlen = length( $protseq );
  my $obs_peps = $args{peptide};
  my ($biosequence) =  $protseq;

  my %colors=();
  my @obs_color = qw(red green yellow purple blue);
  my $style = "<STYLE>\n";
  for (my $i = 0; $i < 5; $i++){
    $colors{Observed}{$i} = $obs_color[$i];
    $style .= ".lgnd_obs_sing_$i { background-color: $colors{Observed}{$i} ;border-style: solid; border-color:gray; border-width: 1px  }\n"
    
  }

  # Define CSS classes
  my $sp = '&nbsp;' x 4;
  $style = "$style\n</STYLE>";


  my $panel = Bio::Graphics::Panel->new( -length    => $protlen + 2,
                                         -key_style => 'between',
                                         -width     => 800,
                                      -empty_tracks => 'suppress',
                                         -pad_top   => 5,
                                        -pad_bottom => 5,
                                         -pad_left  => 10,
                                         -pad_right => 50 );

  my $ruler = Bio::SeqFeature::Generic->new( -end => $protlen,
                                           -start => 2,
                                    -display_name => 'Sequence Position');

  my $sequence = Bio::SeqFeature::Generic->new( -end => $protlen,
                                              -start => 1,
                                       -display_name => 'Sequence Position');

  
      # Loop over peptides
  my ( $multi, $single );
  my $acc =1;
  my %peptides;
  my %coverage_method;
  my %pep_info =();
  foreach my $method(@methods){
    for my $idx ( 1..$protlen ) { $coverage_method{$method}{$idx} = 0; }
  }

  foreach my $method(@methods){
		foreach my $pep (keys %{$obs_peps->{$method}}) {
			my $pepseq  =  $pep;
			my $score = $obs_peps->{$method}{$pep};
			my $proteinseq = $biosequence;
			my $str = $proteinseq;
			$str =~ s/$pepseq.*//g;
			my $start =  length($str);
			my $stop  =  length($str)+length($pepseq);

      my $mod_score; 
      if($max_intensity > 1){
          $mod_score = sprintf("%.2f", $score/$max_intensity);
      }
      else{
         $mod_score = 1;
      }
			# accession isn't necessarily unique, need compound key...
			my $ugly_key = $acc . '::::' . $start . $stop; 
			my $f = Bio::SeqFeature::Generic->new(
															 -start => $start, 
																 -end => $stop,
														 -primary => $acc,
												-display_name => $ugly_key,
															 -score => $mod_score );

			push @{$peptides{$method}}, $f;

			# Record the coverage for this peptide
			for my $idx ( $start..$stop ) { $coverage_method{$method}{$idx}++; }

			# count peptide type, to build appropriate legend 
  		if ( $score ) {
				$single++; 
			} else {
				$multi++;
			}
			$acc++;
      $proteinseq =~ /(\w)$pepseq(\w)/;
      $pep_info{$ugly_key} = "$1.$pepseq.$2, Normalized Intensity: ". $mod_score*100;
   }
 }

  # Calculate the coverage 'domains' 
  # Made this global to use elsewhere...
  my @uncovered;
  # What is 1-based index of first observed aa, used for expected coverage.
  my $min_covered_aa = 0;

  foreach my $method(@methods){
    # Keep track of coverage coordinates
    my $cstart = 1;
    my $cend = 0;

    # Also keep track of non-coverage coordinates
    my $ncstart = 1;
    my $ncend = 1;

    # Not in coverage to begin with
    my $in_coverage = 0;

    # %coverage is hash of seq depth keyed by coordinate
    my $last_key;
    $min_covered_aa = 0;
		for my $key ( sort{ $a <=> $b } keys %{$coverage_method{$method}} ) {
			# Cache min covered aa if not yet set and index is covered
			$min_covered_aa = $key if ( !$min_covered_aa && $coverage_method{$method}{$key} );
			if ( !$in_coverage ) { # Not in coverage
				if ( $coverage_method{$method}{$key} ) {
					$cstart = $key;
					$cend = $key;
					$in_coverage = 1;

					# Store non-coverage info
					$ncend = $key - 1;
					push @uncovered, { start => $ncstart, end => $ncend } if $ncstart && $ncend;

				} else {
					$in_coverage = 0;
					# No-op
				}
			} else { # Already in coverage
				if ( $coverage_method{$method}{$key} ) {
					# Start stays the same, increment end
					$cend = $key;
					$in_coverage = 1;
				} else {
					$in_coverage = 0;
					# Its showtime!
					my $f = Bio::SeqFeature::Generic->new( -start   => $cstart,
																								 -end     => $cend,
																								 -primary => 'Coverage',
																								 -display_name => 'Coverage' );
					push @{$coverage{$method}}, $f;
          #print "$method $cstart $cend\n";
					$cstart = 1;
					$cend = 0;

					# Dropped out of coverage, cache ncstart 
					$ncstart = $key;
				}
			}
			$last_key = $key;
		}

		if ( !$in_coverage ) {
			push @uncovered, { start => $ncstart, end => $last_key } if $ncstart && $last_key;
		}
		
		if ( $cend ) {
			my $f = Bio::SeqFeature::Generic->new( -start   => $cstart,
																						 -end     => $cend,
																						 -primary => 'Coverage',
																				-display_name => 'Coverage' );
			push @{$coverage{$method}}, $f;
		}
  }
  
  ## Add all the tracks to the panel ##

  $panel->add_track( $ruler,
	                 	-glyph  => 'anchored_arrow',
                    -tick   => 2,
                    -height => 8,
                    -key  => 'Sequence Position' );

  # Add observed peptide track
  my $i=0;
  foreach my $method (@methods){
    $panel->add_track( \@{$peptides{$method}},
                      -glyph       => 'graded_segments',
                      -bgcolor     => $colors{Observed}{$i},
                      -fgcolor     => 'black',
                      -font2color  => '#882222',
                      -key         => "$method",
                      -bump        => 1,
                      -height      => 8,
                      -label       => sub { my $f = shift; my $n = $f->display_name(); $n = ''; return $n },
                      -min_score   => 0,
                      -max_score   => 1,
                      -sort_order     => 'high_score',
                     );
    $i++;
  }


         

  my @legend; 
  my $i = 0;
  foreach my $method (@methods){
    push @legend, "<TR> <TD CLASS=lgnd_obs_sing_$i>$sp</TD> <TD class=sm_txt><SPAN TITLE='$method'>$method</SPAN></TD> </TR>\n";
    $i++;
  }


  my $legend = '';
  foreach my $item ( @legend ) {
    $legend .= $item;
  }

  my @legend_color_scale=();
  my %title_clr=();
  
  my $interval = int($max_intensity/10)+1;
  my $i;
  my $idx=0;
  for (my $i = 0; $i<$max_intensity;$i+=$interval){
    my $num = $i+$interval;
    my $m = sprintf("%.2E", $num);
    my $n = sprintf("%.2E",$i) ;
    if($i == 0){$n =0;}
    $title_clr{$idx} = "($n, $m)";
    $idx++;
  }

  # Create image map from panel objects. 
  # links and mouseover coords for peptides, mouseover coords only for others
  my $baselink = "$CGI_BASE_DIR/PeptideAtlas/GetPeptide?_tab=3&atlas_build_id=$args{build_id}&searchWithinThis=Peptide+Name&searchForThis=_PA_Accession_&action=QUERY";
  my $pid = $$;
  my @objects = $panel->boxes();
  my $mapname = $pid."_OrigeneCov";
 
  my $map = "<MAP NAME='$mapname'>\n";
  for my $obj ( @objects ) {
    $log->debug( join( "-", @$obj) );
    my $hkey_name = $obj->[0]->display_name();
    my $f = $obj->[0];
    my $coords = join( ", ", @$obj[1..4] );
    $map .= "<AREA SHAPE='RECT' COORDS='$coords' TITLE='$pep_info{$hkey_name}'>\n";
  }
  $map .= '</MAP>';
  # Create image in tmp space 
  my $file_name    = $pid . "_origenecov.png";
  my $tmp_img_path = "images/tmp";
  my $img_file     = "$PHYSICAL_BASE_DIR/$tmp_img_path/$file_name";

 	open( OUT, ">$img_file" ) || die "$!: $img_file";
	binmode(OUT);
	print OUT $panel->png;
	close OUT;

  ## color gradient
  grad_output_html($pid,$protlen);
  my $legend_clr_file = $img_file;
  $legend_clr_file =~ s/$PHYSICAL_BASE_DIR/$HTML_BASE_DIR/;
  $legend_clr_file =~ s/origenecov/gradient/;

  my $tr = $args{tr_info} || '';
#  my $tr_link =  "<TR><TD>$link</TD></TR>";
  # Generate and return HTML for graphic
  my $graphic =<<"  EOG";
  <TABLE width='800'>
   <TR>
   <TD>
 	      <img src='$HTML_BASE_DIR/$tmp_img_path/$file_name' ISMAP USEMAP='#$mapname' alt='Sorry No Img' BORDER=0>
  $map
      </TD>
      <TD COLSPAN=2 ALIGN=RIGHT>
        <TABLE BORDER=0 class=lgnd_outline>
        $legend
        </TABLE>
      </TD>
    </TR>
   <TR>
     <TD >
        <img src='$legend_clr_file'  alt='Sorry No Img' BORDER=0>
      </TD>
    </TR>
      </TABLE>
  </TABLE>
  $style
  EOG

  return $graphic;
}
sub grad_output_html {
  my $pid = shift;
  my $protlen = shift;

  my $panel = Bio::Graphics::Panel->new( -length    => 99,
                                         -key_style => 'between',
                                         -width     => 800,
                                      -empty_tracks => 'suppress',
                                         -pad_top   => 0,
                                        -pad_bottom => 0,
                                         -pad_left  => 10,
                                         -pad_right => 50 );

  my $ruler = Bio::SeqFeature::Generic->new( -end => 99,
                                           -start => 0,
                                    -display_name => 'Color Gradient');

  $panel->add_track( $ruler,
                    -glyph  => 'arrow',
                    -tick   => 1,
                    -height => 8,
                    -key  => 'Color Gradient' );


  my @score = ();

  my $unit = 100/$NUM_STEPS;
  my ($cstart,$cend);
  $cstart  = 1;
  $cend = 1;
  for (my $i=0; $i < $NUM_STEPS; $i++) {
    $cstart = $cend ;
    $cend = $cstart  + $unit;
    if($cend > 100){$cend = 100;}
    my $f = Bio::SeqFeature::Generic->new( -start   => $cstart,
                                             -end     => $cend,
                                         -score => $cend );

    push @score, $f;
  }
  my @obs_color = qw(red green yellow purple blue);
  foreach my $color(@obs_color){
    $panel->add_track( \@score,
                      -glyph       => 'graded_segments',
                      -bgcolor     => $color,
                      -fgcolor     => 'white',
                      -bump        => 0,
                      -height      => 8,
                      -min_score   => 0,
                      -max_score   => 100,
                      -sort_order     => 'high_score',
                     );
    
  }
  my @objects = $panel->boxes();
  # Create image in tmp space
  my $file_name    = $pid . "_gradient.png";
  my $tmp_img_path = "images/tmp";
  my $img_file     = "$PHYSICAL_BASE_DIR/$tmp_img_path/$file_name";

  open( OUT, ">$img_file" ) || die "$!: $img_file";
  binmode(OUT);
  print OUT $panel->png;
  close OUT;

}



sub getPeptideCount {
  my %args = @_;
  my $SUB_NAME = $sbeams->get_subname();

  #### Decode the argument list
  my $resultset_ref = $args{'resultset_ref'}
   || die "ERROR[$SUB_NAME]: resultset_ref not passed";
  my $biosequence = $args{'biosequence'}
   || die "ERROR[$SUB_NAME]: biosequence not passed";
  my $line_length = $args{'line_length'} || 70;
  my $word_length = $args{'word_length'} || 10;
  my $enzyme = $args{'enzyme'} || '';
  my $protein_structure = $args{'protein_structure'};
  my $total_observations = $args{'total_observations'};

  # removed DSC 2008-03 - let caller decide if it should be displayed
  #### Don't display unless HTML
#  return unless ($sbeams->output_mode() eq 'html');

  #### Get the hash of indices of the columns
  my %col = %{$resultset_ref->{column_hash_ref}};

  #### Loop over all the peptides
  my $data_ref = $resultset_ref->{data_ref};
  my @peptides = ();
  foreach my $row (@{$data_ref}) {
    push(@peptides,$row->[$col{peptide_sequence}]);
   $total_observations += $row->[$col{n_observations}];
  }
  return( $total_observations, \@peptides );
}

###############################################################################
# displayAnnotatedSequence
###############################################################################
sub displayAnnotatedSequence {
  my $self = shift || die ("self not passed");
  my %args = @_;
  my $SUB_NAME = 'displayAnnotatedSequence';

  #### Decode the argument list
  my $biosequence = $args{'biosequence'}
   || die "ERROR[$SUB_NAME]: biosequence not passed";
  my $obs_peptides = $args{peptides};
  my $method = $args{method};
  #### Don't display unless HTML
  return unless ($sbeams->output_mode() eq 'html');

  my $sequence = $biosequence->{biosequence_seq};
  my %start_positions;
  my %end_positions;

  foreach my $label_peptide (keys %$obs_peptides) {
    if ($label_peptide) {
      my $pos = -1;
      while (($pos = index($sequence,$label_peptide,$pos)) > -1) {
    	$start_positions{$pos}++;
	    $end_positions{$pos+length($label_peptide)}++;
     	$pos++;
      }
    }
  }


  my $seq_length = length($sequence);
  my $i = 0;
  my $color_level = 0;
  my $observed_residues = 0;
  my @annotation_lines;

  while ($i < $seq_length) {
    if (defined $end_positions{$i}) {
      $color_level -= $end_positions{$i} unless ($color_level == 0);
    }
    if (defined $start_positions{$i}) {
      $color_level += $start_positions{$i};
    }
    if ($color_level) {
      $observed_residues++;
    }
    $i++;
  }

  my $cnt = 0;
  for my $frag ( @{$biosequence->{_non_coverage}} ) {
    $cnt += length( $frag->{seq} );
  }
  
  my %observed = (    start => [],
                        end => [],
                      class => 'pa_observed_sequence',
                     number => 0 );
  
  for my $f ( @{$coverage{$method}} ) {
    #print "coverage starts at " . $f->start() . " and ends at " . $f->end() ,"<BR>\n";
    push @{$observed{start}}, $f->start() ;
    push @{$observed{end}}, $f->end()-1 ;
    $observed{number}++;
    #print " $observed{number} <BR>";
  }
  my $tags = $sbeamsMOD->make_tags( \%observed );
  my $coverage = sprintf ("%.1f", ($observed_residues/$seq_length)*1000/10) ;
  $coverage .= '%';
  return ( $sequence, $tags, $coverage);

} # end displayAnnotatedSequence


sub get_html_seq {
  my $self = shift;
  my %args = @_;
  my $seq = $args{sequence};
  my $tags = $args{tags};
  my $method = $args{method};
  my $coverage = $args{coverage};
  my @values = ( ['<PRE><SPAN CLASS=pa_sequence_font>'] );
  if($method eq 'HCD'){
    push @values, ["  $method"."[$coverage]:"];
  }
  else{ push @values, ["$method"."[$coverage]:"];}

  my $cnt = 0;
  for my $aa ( split( "", $seq ) ) {
    my @posn;
    if ( $tags->{$cnt} && $tags->{$cnt} ne '</SPAN>' ) {
      push @posn, $tags->{$cnt};
    }
    push @posn, $aa;
    if ( $tags->{$cnt} && $tags->{$cnt} eq '</SPAN>' ) {
      push @posn, $tags->{$cnt};

    }

    $cnt++;

    unless ( $cnt % 50 ) {
      push @posn, '<SPAN CLASS=white_bg>&nbsp;</SPAN>';
    }
    push @values, \@posn;
  }
  push @values, ['</SPAN></PRE>'];
  my $str = '';
  for my $a ( @values ) {
    $str .= join( "", @{$a} );
  }
  return $str;
}


# getProteinStructure
###############################################################################
sub getProteinStructure {
  my %args = @_;
  my $SUB_NAME = 'getProteinStructure';


  #### Decode the argument list
  my $biosequence_id = $args{'biosequence_id'}
   || die "ERROR[$SUB_NAME]: biosequence_id not passed";

  #### Define query to get information
  my $sql = qq~
    SELECT n_transmembrane_regions,transmembrane_class,transmembrane_topology,
           has_signal_peptide,has_signal_peptide_probability,
           signal_peptide_length,signal_peptide_is_cleaved
      FROM $TBAT_BIOSEQUENCE_PROPERTY_SET
     WHERE biosequence_id = $biosequence_id
  ~;

  my @rows = $sbeams->selectHashArray($sql);

  if (scalar(@rows) != 1) {
    my %tmp = ();
    return(\%tmp);
  }

  return($rows[0]);

}

sub get_plot_help {
  my $self = shift;
  my %arg =@_;
  my $name = $arg{name};
  return '' unless $name;
  my @entries;
  my $hidetext;
  my $showtext;
  my $heading='';
  my $description='';
  $showtext = 'show plot descriptions';
  $hidetext = 'hide plot descriptions';
  @entries = (
    {key => 'Sequence Coverage', value => 'This plot shows all peptides identified with probability >= 0.9 by each fragementation methods. <BR>It is possible that this plot shows more or less peptides than what is shown on "Sequence Motifs" plot, <BR>because they use different peptide probability cutoff.'},
    {key=> 'Color Gragident', value => 'The "Sequence Coverage" plot is color coded using peak intensity calculated using label free method.'}, 
  );
  my $help = $sbeamsMOD -> get_table_help_section( 
  name => $name,
  description => $description,
  heading => $heading,
  entries => \@entries,
  showtext => $showtext,
  hidetext => $hidetext  );
  return $help;
    
} # end get_table_help




sub getPeptides {
  my $self = shift || die ("self not passed");
  my %arg = @_;
  my $ref_parameter = $arg{ref_parameters}       || die "ref_parameters not passed";
  my $proteinProphetfile = $arg{ProteinProphetfile} || die "proteinProphetfile not passed";
  my $expectedProtein = $arg{protein_name}         || die "expectedProtein not passed";
  my $decoyString = 'DECOY';
  my $P_threshold_protein =  "0.9";
  my $P_threshold_peptide = "0.9";

  #print "$P_threshold_protein -- $P_threshold_peptide <BR>"; #zhi
  my $groupNumber;
  my %groupCounts;
  my $groupProbability;
  my %peptides = ();
  my %proteins =();
  my $preProtein = '';
  my $protein_name ='';
  if ($proteinProphetfile && open(INFILE,$proteinProphetfile)) {
    my $line;
    LOOP:while ($line = <INFILE>) {

      if ($line =~ /protein_group group_number="(\d+)".+probability="([\d\.]+)"/) {
        $groupNumber = $1;
        $groupProbability = $2;
      }
      if ($line =~ /protein_name="(.+)" n_indistinguishable_proteins="\d+" probability="([\d\.]+)"/) {
        $protein_name = $1;

        #if($protein_name =~ /DECOY/){$preProtein = $protein_name; next;}
        if($protein_name =~ /sp\|(\S+)\|/ && $protein_name !~ /DECOY/){

          $protein_name = $1;
        }
        my $probability = $2;

        #if ( $preProtein eq $expectedProtein) {print join("<BR>", @peptides) }
        if ( $preProtein eq $expectedProtein){last LOOP;}
        #### If we're aggressively coalescing, fix the protein probability to the group's
        if ($groupProbability > $probability) {
          if ($line =~ /group_sibling_id="(\w+)"/) {
          #if ($1 eq 'a') {
            #print "WARNING: Updating $protein_name prob $probability to its group probability $groupProbability\n";
            $probability = $groupProbability;
               #$protein_name .= "($1)";
         # }
          }
        }
        if ($probability < $P_threshold_protein && $protein_name eq $expectedProtein){
           last LOOP;
        }
        if ($probability >= $P_threshold_protein){
          $proteins{$protein_name}->{probability} = $probability;
          if ($line =~ /protein_name="(.+)" n_indistinguishable_proteins="\d+" probability="([\d\.]+)".+unique_stripped_peptides="([A-Z\+]+)".+group_sibling_id="(\w+)" total_number_peptides="([\d\.]+)"/) {
         $proteins{$protein_name}->{group_number} = $groupNumber;
         $proteins{$protein_name}->{group_sibling_id} = $4;
         $proteins{$protein_name}->{total_spectra} = $5;
         $proteins{$protein_name}->{percent_spectra} = $6;
         my $unique_stripped_peptides = $3;
         my $npeptides = ( $unique_stripped_peptides =~ tr/+/+/ ) + 1;
         $proteins{$protein_name}->{distinct_peptides} = $npeptides;

          }
        }

        $preProtein = $protein_name;

      }
         #### For getting global counts
     if ($line =~ /peptide peptide_sequence="([A-Z]+)".+nsp_adjusted_probability="([\d\.]+)".+weight="([\d\.]+)".+n_instances="([\d\.]+)"/
        and $protein_name eq $expectedProtein ) {
        if ($2 >= $P_threshold_peptide ) {
            $peptides{$1} = 1;
        }

     }

    }
      close(INFILE);
    } else {
      print "ERROR: No suitable input ProteinProphet file found here.\n";
    }

    my $peptideProphetFile = $proteinProphetfile;
    chomp $peptideProphetFile;
    $peptideProphetFile =~ s/ipro.prot/prob.pep/;


    if( -e $peptideProphetFile) {
			my $validate = $XML::Xerces::SAX2XMLReader::Val_Never;
			my $parser = XML::Xerces::XMLReaderFactory::createXMLReader();
			$parser->setFeature("http://xml.org/sax/features/namespaces", 0);
			$parser->setFeature("http://xml.org/sax/features/validation", 0);
			$parser->setFeature("http://apache.org/xml/features/validation/schema",0);
			my $error_handler = XML::Xerces::PerlErrorHandler->new();
			$parser->setErrorHandler($error_handler);
			my $CONTENT_HANDLER = MyContentHandler->new();
			$parser->setContentHandler($CONTENT_HANDLER);
			$CONTENT_HANDLER->setVerbosity($VERBOSE);
			$CONTENT_HANDLER->{pep_identification_list} = [];
			$parser->parse (XML::Xerces::LocalFileInputSource->new($peptideProphetFile));

      foreach my $row (@{$CONTENT_HANDLER->{pep_identification_list}}){
        my $peptide = $row->[0];
        my $probability = $row->[1];
        my $intensity = $row->[2];
        if( $probability >= 0.9){
          if(defined $peptides{$peptide} && $peptides{$peptide} < $intensity){
           $peptides{$peptide} = $intensity;
            if($intensity > $max_intensity){
              $max_intensity = $intensity;
            }
         }
        }
      }
  }
  return %peptides;
}



package MyContentHandler;


use strict;
use Date::Manip;
use vars qw(@ISA $VERBOSE);
@ISA = qw(XML::Xerces::PerlContentHandler);
$VERBOSE = 0;

###############################################################################
# new
###############################################################################
sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;
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
# pepXML_start_element
###############################################################################
sub start_element {
  my ($self,$uri,$localname,$qname,$attrs) = @_;


  #### Make a hash to of the attributes
  my %attrs = $attrs->to_hash();

  #### Convert all the values from hashref to single value
  while (my ($aa1,$aa2) = each (%attrs)) {
    $attrs{$aa1} = $attrs{$aa1}->{value};
  }

  #### If this is the search_hit, then store some attributes
  #### Note that this whole logic will break if there's more than one
  #### search_hit, which shouldn't be true so far
  if ($localname eq 'search_hit' ){
    die("ERROR: Multiple search_hits not yet supported!")
      if (exists($self->{pepcache}->{peptide}));
    $self->{pepcache}->{peptide} = $attrs{peptide};
  }

  #### If this is the peptideProphet probability score, store some attributes
  if ($localname eq 'peptideprophet_result') {
    $self->{pepcache}->{scores}->{probability} = $attrs{probability};
  }

  if ($localname eq 'xpresslabelfree_result') {
    $self->{pepcache}->{peak_intensity} = $attrs{peak_intensity};
  }

  if ($localname eq 'interprophet_result') {
    $self->{pepcache}->{scores}->{probability} = $attrs{probability};
  }


} # end pepXML_start_element
###############################################################################
# pepXML_end_element
###############################################################################
sub end_element {
  my ($self,$uri,$localname,$qname) = @_;

  #### If this is the end of the spectrum_query, store the information if it
  #### passes the threshold
  if ($localname eq 'spectrum_query') {
    my $probability = $self->{pepcache}->{scores}->{probability};
    if($probability >= 0.9){
      push @{$self->{pep_identification_list}}, [
        $self->{pepcache}->{peptide},
        $self->{pepcache}->{scores}->{probability},
        $self->{pepcache}->{peak_intensity},
      ];
    }
    #### Clear out the cache
    delete($self->{pepcache});
    #### Increase the counters and print some progress info
    $self->{counter}++;
    print "$self->{counter}..." if ($self->{counter} % 1000 == 0);
  }



}
1;
