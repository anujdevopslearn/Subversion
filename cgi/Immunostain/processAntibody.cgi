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
# Set up all needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;

use lib "$FindBin::Bin/../../lib/perl";
use vars qw ($sbeams $sbeamsMOD $q $current_contact_id $current_username
             %hash_to_sort $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG
             $DATABASE $TABLE_NAME $PROGRAM_FILE_NAME $CATEGORY $DB_TABLE_NAME
             @MENU_OPTIONS );

use SBEAMS::Connection qw($q $log);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::DataTable;

use SBEAMS::Immunostain;
use SBEAMS::Immunostain::Settings;
use SBEAMS::Immunostain::Tables;

$sbeams = new SBEAMS::Connection;
$sbeamsMOD = new SBEAMS::Immunostain;
$sbeamsMOD->setSBEAMS($sbeams);


{
		
  # Authenticate
  $current_username = $sbeams->Authenticate( allow_anonymous_access => 1,
                                             permitted_work_groups_ref => 
  ['Immunostain_user','Immunostain_admin', 'Immunostain_readonly','Admin']
  ) || die "Invalid authentication information";

  # Read input parameters
  my %params;
  $sbeams->parse_input_parameters( q => $q, parameters_ref=>\%params );
  
#  $sbeams->printCGIParams( $q );

  # Process parameters before we start.  Passed as ref so we may alter.
  processParams( \%params );

  my $content = '';

  # What are we supposed to do?
  if ($params{action} eq "ab_details") {
    $content = getAbDetails( %params );

  } elsif ($params{action} eq "ab_list") {
    $content = getAbList( %params );

  } else {
    $content = "Invalid action specified ($params{action}), unable to proceed";
    
  }

  # normal handling for anything else			
	$sbeamsMOD->display_page_header();
  print $content;
  $sbeamsMOD->printPageFooter();
  
exit(0);

} # end main code block

################################################################################
sub getAbDetails {

  my %params = @_;
  my $resultset_ref = {};

  # Which Antibody? 
  die( 'Missing required parameter antibody_id' ) unless $params{antibody_id};

  # Useful HTML
  my $pad = '&nbsp;&nbsp;';
  my $lbase = "<A HREF=ManageTable.cgi?ShowEntryForm=1;TABLE_NAME=";

### Summary Block: 
  

  # Build SQL to fetch summary information for antibody.
	my $sumSQL = getSummarySQL( $params{antibody_id} );

  # Fetch results from database
	my @results = $sbeams->selectSeveralColumns($sumSQL);
	
  # Build table to display overview data.
  my $sumtable = SBEAMS::Connection::DataTable->new( BORDER => 0 );

	unless ( scalar(@results) ) { # If no results, print message and bail
    $log->warn( "No data found for antibody $params{antibody_id}: $sumSQL" );
    return "<H3><FONT COLOR=#D60000> Specified antibody (ID: $params{antibody_id}) not found in the database</FONT></H3>";
  }

  # We have data, set up display with first row
  my $row = $results[0];

  # Build links
  my $oparm = ($$row[5] eq 'Mouse') ? 'org=Mouse&db=mm5' : 'org=Human&db=hg16';
  my $ab =<<"  END";
  <A HREF=SummarizeStains?action=QUERYHIDE&antibody_id=$params{antibody_id}&display_options=MergeLevelsAndPivotCellTypes>
  $$row[0]</A>
  END
  my $loclink = "<A HREF=$$row[4]LocRpt.cgi?l=$$row[2]>$$row[2]</A>";
  my $coord   = "<A HREF=http://genome.ucsc.edu/cgi-bin/hgTracks?$oparm&position=$$row[3]>$$row[3]</A>";

  # Add rows to table
  $sumtable->addRow( [ "<H3><B>$ab</B></H3>" ] );
  $sumtable->addRow( [ "$pad <B>Alternate Names:</B>", "$pad $$row[1]" ] );
  $sumtable->addRow( [ "$pad <B>Locus Link:</B>", "$pad $loclink" ] );
  $sumtable->addRow( [ "$pad <B>Genome Coordinates:</B>", "$pad $coord" ] );

  # Set up formatting
  $sumtable->setColAttr( ROWS => [2..$sumtable->getRowNum()], 
                       COLS => [ 1 ], ALIGN => 'LEFT', NOWRAP => 1 );
  $sumtable->setColAttr( ROWS => [2..$sumtable->getRowNum()], 
                       COLS => [ 2 ], ALIGN => 'LEFT' );
  $sumtable->setCellAttr( ROW => 1, COL => 1, ALIGN => 'LEFT', COLSPAN => 2 );

  # Need to get number of assays from later query and append to the summary table below.
  
### End Summary Block:

### Expression Block:

  # Overly elaborate, pare if possible?
  # The reason we had to join so many table is we need to adjust the structural 
  # unit sort order based on tissue type, a table that is only distantly 
  # ( 7 tables away ) related.  Doh!
  my $exprSQL =<<"  END_SQL";
  SELECT su1.structural_unit_name,tt.tissue_type_name,
        CASE WHEN ( tissue_type_name LIKE '%Bladder%' 
              AND su1.structural_unit_name = 'Stromal endothelial cells' )
             THEN su1.sort_order - 75 
             WHEN ( tissue_type_name LIKE '%Prostate%' 
               AND su1.structural_unit_name = 'Basal epithelial cells' )
             THEN su1.sort_order + 110
             ELSE su1.sort_order 
        END AS sort_order,
        AVG(CASE WHEN aue1.at_level_percent IS NULL 
                 THEN 0 ELSE aue1.at_level_percent 
                 END ) AS none, 
        AVG(CASE WHEN aue2.at_level_percent IS NULL 
                 THEN 0 ELSE aue2.at_level_percent 
                 END ) AS equivocal, 
        AVG(CASE WHEN aue3.at_level_percent IS NULL 
                 THEN 0 ELSE aue3.at_level_percent 
                 END ) AS intense,
        COUNT(*) AS total_assays, su1.structural_unit_id
        FROM $TBIS_ASSAY_CHANNEL ac
        JOIN $TBIS_ANTIBODY ab 
             ON ac.antibody_id = ab.antibody_id
        JOIN $TBIS_ASSAY ss 
             ON ac.assay_id = ss.assay_id
        JOIN $TBIS_SPECIMEN_BLOCK sb
             ON ss.specimen_block_id = sb.specimen_block_id
        JOIN $TBIS_SPECIMEN sp
             ON sb.specimen_id = sp.specimen_id
        JOIN $TBIS_TISSUE_TYPE tt 
             ON sp.tissue_type_id = tt.tissue_type_id
        JOIN $TBIS_ASSAY_UNIT_EXPRESSION aue1 
             ON ac.assay_channel_id = aue1.assay_channel_id
        JOIN $TBIS_ASSAY_UNIT_EXPRESSION aue2 
             ON ac.assay_channel_id = aue2.assay_channel_id
        JOIN $TBIS_ASSAY_UNIT_EXPRESSION aue3 
             ON ac.assay_channel_id = aue3.assay_channel_id
        JOIN $TBIS_STRUCTURAL_UNIT su1 
             ON aue1.structural_unit_id = su1.structural_unit_id
        JOIN $TBIS_STRUCTURAL_UNIT su2 
             ON aue2.structural_unit_id = su2.structural_unit_id
        JOIN $TBIS_STRUCTURAL_UNIT su3 
             ON aue3.structural_unit_id = su3.structural_unit_id
        WHERE ab.antibody_id = $params{antibody_id}
        AND su1.structural_unit_id = su2.structural_unit_id
        AND su3.structural_unit_id = su2.structural_unit_id
        AND aue3.expression_level_id = 1
        AND aue2.expression_level_id = 2
        AND aue1.expression_level_id = 3
        GROUP BY su1.structural_unit_name, su1.sort_order,
                 tt.tissue_type_name, su1.structural_unit_id
        ORDER BY sort_order
  END_SQL

  my $exptable = SBEAMS::Connection::DataTable->new( BORDER => 1, 
                                                     CELLPADDING => 1, 
                                                     CELLSPACING => 1 );
  $exptable->addRow( ['<B>Tissue type</B>', '<B>Cell type</B>',
                      '<B>% Intense</B> ', '<B>% Equivocal</B>', 
                      '<B>% None</B>', '<B># Assays</B>'] );

  my $sHREF = "SummarizeStains?action=QUERY;antibody_id=$params{antibody_id};display_options=MergeLevelsAndPivotCellTypes";

  my $prev_tissue = '';
  my @new_tissue_index;
  my @repeat_tissue_index;
  my @expr = $sbeams->selectSeveralColumns( $exprSQL );
  foreach my $row ( @expr ){
    $row->[1] =~ s/Bladder/Urinary Bladder/; 
    $row->[0] = "<A HREF=${sHREF};structural_unit_id=$row->[7]>$row->[0]</A>";

    # Round average percentage, don't introduce artificial precision.
    for my $num ( @$row[3..5] ) {
      $num = ( $num - int($num) >= 0.5 ) ? int( $num ) + 1 : int( $num ); 
#      $num = sprintf( '%.2f', $num );
#      $num =~ s/\.00$//;
    }
    if ( $prev_tissue eq $row->[1] ) {
      $exptable->addRow( [ @$row[0, 5, 4, 3, 6] ] );
      unshift @repeat_tissue_index, $exptable->getRowNum();
    } else {
      $exptable->addRow( [ @$row[1, 0, 5, 4, 3, 6] ] );
      unshift @new_tissue_index, $exptable->getRowNum();
    }
    $prev_tissue = $row->[1];
  }

  my $total = $exptable->getRowNum();
  $exptable->setColAttr( ROWS => \@repeat_tissue_index, COLS => [2..4], ALIGN => 'RIGHT' );
  $exptable->setColAttr( ROWS => \@repeat_tissue_index, COLS => [5], ALIGN => 'CENTER' );
  $exptable->setColAttr( ROWS => \@new_tissue_index, COLS => [3..5], ALIGN => 'RIGHT' );
  $exptable->setColAttr( ROWS => \@new_tissue_index, COLS => [6], ALIGN => 'CENTER' );

  for my $index ( @new_tissue_index ) {
    my $span = ( $total - $index ) + 1;
    $exptable->setCellAttr( ROW => $index, COL => 1, 
                           VALIGN => 'TOP',  NOWRAP => 0, ALIGN => 'CENTER',
                           ROWSPAN => ( $span ), BGCOLOR => '#DDDDDD' );
 #   $exptable->setCellAttr( ROW => $index, COL => 1, NOWRAP => 0, VALIGN => 'TOP',
  #                          ALIGN => 'LEFT', ROWSPAN => ( $span ) );
    $total -= $span;
  }
  $exptable->setRowAttr( ROWS => [1], COLS => [1..6], ALIGN => 'CENTER' );
  
# End Expression Block:

# Assay Block:
#
  # Set up links for rendering later  
  my $plus = "<IMG SRC=../../images/greyplus.gif BORDER=0>";
  my $addAssay = "<SPAN TITLE='Add new assay'>${lbase}IS_assay>$plus</A></SPAN>";

  my $assay =<<"  END";
  <SPAN TITLE='View summary of this assay'>
  <A HREF=main.cgi?action=_processStain;stained_slide_id=ASSAY_ID>
  ASSAY_NAME</A>
  </SPAN>
  END
  my $image =<<"  END";
  <SPAN TITLE='View image'>
  ${lbase}IS_assay_image;assay_image_id=IMG_ID;GetFile=IS_PROC>
  IMG_MAGx &nbsp;</A>
  </SPAN>
  END
  my $channel =<<"  END";
  <SPAN TITLE='Edit assay channel'>
  ${lbase}IS_assay_channel;assay_channel_id=AC_ID;ShowEntryForm=1>
  AC_NAME</A>
  </SPAN>
  END
  my $addImg =<<"  END";
  <SPAN TITLE='Add new image to this assay channel'>
  ${lbase}IS_assay_image;assay_channel_id=AC_ID>
  LINKNAME</A>
  </SPAN>
  END
  my $addChan =<<"  END";
  <SPAN TITLE='Add new assay channel to this assay'>
  ${lbase}IS_assay_channel;assay_id=ASSAY_ID;channel_index=AC_IDX;antibody_id=$params{antibody_id}>
  LINKNAME</A>
  </SPAN>
  END

  # Build SQL to fetch image/channel info for each assay
  my $assaySQL =<<"  END";
  SELECT ss.assay_name, ss.assay_id, si.assay_image_id,
         si.image_magnification, ac.assay_channel_id,
         CASE WHEN si.processed_image_file IS NULL 
              THEN 'raw_image_file'
              ELSE 'processed_image_file'
              END AS image_file,
         CASE WHEN ac.assay_channel_name IS NULL 
              THEN ss.assay_name + ' - chan ' + cast(ac.channel_index as varchar)
              ELSE ac.assay_channel_name
              END AS assay_channel_name
	FROM $TBIS_ASSAY ss
	LEFT JOIN $TBIS_ASSAY_CHANNEL ac on ss.assay_id = ac.assay_id
	LEFT JOIN $TBIS_ASSAY_IMAGE si on ac.assay_channel_id =  si.assay_channel_id
	WHERE ac.antibody_id = $params{antibody_id} 
  ORDER BY ss.assay_id, ac.assay_channel_id, si.assay_image_id
  END
  
  # Fetch data
  my @assays = $sbeams->selectSeveralColumns( $assaySQL );

  # Also want to fetch characterizations for the various channesl.  Doing
  # as a separate query because the groupings interfere with the above query
  my $charSQL =<<"  END";
  SELECT assay_channel_id, structural_unit_id, 
         COUNT(*) as Characterizations 
  FROM $TBIS_ASSAY_UNIT_EXPRESSION 
  GROUP BY assay_channel_id, structural_unit_id
  END

  my %characterizations;
  my @rows = $sbeams->selectSeveralColumns( $charSQL );
  foreach my $row ( @rows ) {
    $characterizations{$row->[0]}++;
  }

  
  # Create display table, add headings 
  my $assaytable = SBEAMS::Connection::DataTable->new( BORDER => 0, 
                                                       CELLPADDING => 2, 
                                                       CELLSPACING => 2 );
  $assaytable->addRow( ["<B>Assay Name $addAssay $pad</B>", 
                        "<B>Channel Name $pad</B>", 
                        "<B>Characterizations $pad</B>", 
                        "<B>Available Images $pad </B>" ] );

#$assaytable->addRow( ["<B>Assay $plus &nbsp;</B>", '<B>Channel &nbsp;</B>',
#                      '<B>Add</B>', '<B>Images &nbsp;</B>', '<B>Add</B>' ] );
  

  my %assayhash;     # counts total number of assays, and channels within them
  my %achash;        # Hash to store info for an assay channel

  # The number of adjacent image links to display per line.
  my $img_per_line = 7;

  foreach my $row ( @assays ) {
    my $img = '';
    if ( $row->[2] ) {
      ( $img = $image ) =~ s/IMG_ID/$row->[2]/g; 
      $img =~ s/IS_PROC/$row->[5]/g; 
      $img =~ s/IMG_MAG/$row->[3]/g; 
    }

    if ( !defined $achash{$row->[4]} ) { # new one
      $assayhash{$row->[1]}->{$row->[4]}++;  # Count channels, (and assays)
      $achash{$row->[4]} = { name       => $row->[6],
                             assay_id   => $row->[1],
                             assay_name => $row->[0],
                             image      => $img };
    } else { # Seen it, append the image and move on.
      $achash{$row->[4]}->{imagecnt}++;
      $achash{$row->[4]}->{image} .= '&nbsp;<BR>' 
                          unless $achash{$row->[4]}->{imagecnt} % $img_per_line;
      $achash{$row->[4]}->{image} .= $img;
    }
  }
  my $total_assays = scalar( keys( %assayhash ) );
  $sumtable->addRow( [ "$pad <B>Total Assays:</B>", "$pad $total_assays" ] );
#  $sumtable->setColAttr( ROWS => [2..$sumtable->getRowNum()], 
#                       COLS => [ 2 ], ALIGN => 'LEFT' );
#
#

  foreach my $id ( keys( %achash ) ) {
    
    # Create link from assay name 
    ( my $alink = $assay ) =~ s/ASSAY_ID/$achash{$id}->{assay_id}/;
    $alink =~ s/ASSAY_NAME/$achash{$id}->{assay_name}/;


    # Create link from channel name 
    ( my $chan = $channel ) =~ s/AC_ID/$id/;
    $chan =~ s/AC_NAME/$achash{$id}->{name}/;

    # Set up add channel link
#    ( my $add_ch = $addChan ) =~ s/LINKNAME/[add]/g;
    ( my $add_ch = $addChan ) =~ s/LINKNAME/$plus/g;
    my $idx = $assayhash{$achash{$id}->{assay_id}}->{$id} + 1;
    $add_ch =~ s/AC_IDX/$idx/;
    $add_ch =~ s/ASSAY_ID/$achash{$id}->{assay_id}/g;

    # Set up add image link
    ( my $add_im = $addImg ) =~ s/LINKNAME/$plus/g;
    $add_im =~ s/AC_ID/$id/g;

    
    # Merge characterization info
    my $chars = $characterizations{$id} || '&nbsp;';
    
    $assaytable->addRow( [ $alink,
                           $chan . '&nbsp;',
                           $add_ch,
                           "$chars $pad",
                           $achash{$id}->{image} . '&nbsp;',
                           $add_im
                         ] 
                       );
                           
  }
  $assaytable->setRowAttr( ROWS => [1], COLS => [1..4], ALIGN => 'CENTER', NOWRAP => 1 );
  $assaytable->setColAttr( COLS => [2, 4], ROWS => [1], COLSPAN => 2 );

  $assaytable->setColAttr( COLS => [1..6], ROWS => [2..$assaytable->getRowNum()],
                           NOWRAP => 1, ALIGN => 'RIGHT' );
  $assaytable->alternateColors( PERIOD => 1, FIRSTROW => 2, 
                                BGCOLOR => '#EEEEEE' );
#  $assaytable->setColAttr( COLS => [1], ROWS => [2..$assaytable->getRowNum()],
#                           NOWRAP => 1, ALIGN => 'LEFT' );
  
# End Assay Block;

# Return HTML;

  return <<"  END";
  <CENTER><H2><FONT COLOR=#D60000>Antibody Summary</FONT></H2></CENTER>
    $sumtable
    <BR>
    $exptable
    <BR><BR>
    $assaytable
  END
}

sub getSummarySQL {
  my $ab = shift;
  my $abclause = ( $ab eq 'ALL' ) ? '' : " antibody_id IN ( $ab )";
  return <<"  END_SQL";
  SELECT antibody_name, alternate_names, biosequence_accession, 
         genome_location + genome_strand, accessor, organism_name
  FROM $TBIS_ANTIBODY ab
  LEFT JOIN $TBIS_ANTIGEN an 
         ON ab.antigen_id = an.antigen_id
  LEFT JOIN $TBIS_BIOSEQUENCE bs 
         ON an.biosequence_id = bs.biosequence_id
  LEFT JOIN $TBIS_GENOME_COORDINATES gc 
         ON bs.biosequence_accession = gc.locus_link_id
  LEFT JOIN $TBIS_BIOSEQUENCE_SET bss 
         ON bs.biosequence_set_id = bss.biosequence_set_id
  LEFT JOIN $TB_ORGANISM sbo 
         ON bss.organism_id = sbo.organism_id
  LEFT JOIN $TBIS_DBXREF dbx 
         ON bs.dbxref_id = dbx.dbxref_id 
  WHERE $abclause
  -- Removed these constraints Jan-25-2005
  --set_Name LIKE 'LocusLink%'
  --AND dbxref_name = 'LocusLink'
  END_SQL

}

sub getAbSummary {
  my %params = @_;
  my $sql = getSummarySQL( $params{antibody_id} );


  return "Coming soon";
}

sub processParams {
  my $params = shift;
  unless( $params->{antibody_id} ) {
    die ( "Missing required parameter antibody_id" );
  }
  
  # If more than one ab_id is defined (explicitly or with all) go to list mode.
  if( $params->{antibody_id} =~ /\,/ || $params->{antibody_id} =~ /\,/ ) {
    $params->{action} =~ s/ab_details/ab_list/;
  }
  # ab_details is the default action
  $params->{action} ||= 'ab_details';
}

