package SBEAMS::Biomarker::HTMLPrinter;

###############################################################################
# Program     : SBEAMS::Biomarker::HTMLPrinter
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::WebInterface module which handles
#               standardized parts of generating HTML.
#
#		This really begs to get a lot more object oriented such that
#		there are several different contexts under which the a user
#		can be in, and the header, button bar, etc. vary by context
###############################################################################


use strict;
#use vars qw( $sbeams );
#             $current_work_group_id $current_work_group_name
#             $current_project_id $current_project_name $current_user_context_id);

#use SBEAMS::Connection::DBConnector;
#use SBEAMS::Connection::TableInfo;
use SBEAMS::Connection qw($log);
use SBEAMS::Connection::Settings;

use SBEAMS::Biomarker::Settings;
use SBEAMS::Biomarker::Tables;


###############################################################################
# printPageHeader
###############################################################################
sub printPageHeader {
  my $this = shift;
  $this->display_page_header(@_);
}


###############################################################################
# display_page_header
###############################################################################
sub display_page_header {
    my $this = shift;
    my %args = @_;

    my $navigation_bar = $args{'navigation_bar'} || "YES";

    #### If the output mode is interactive text, display text header
    my $sbeams = $this->getSBEAMS();
    if ($sbeams->output_mode() eq 'interactive') {
      $sbeams->printTextHeader();
      return;
    }


    #### If the output mode is not html, then we don't want a header here
    if ($sbeams->output_mode() ne 'html') {
      return;
    }


    #### Obtain main SBEAMS object and use its http_header
    $sbeams = $this->getSBEAMS();
    my $http_header = $sbeams->get_http_header();

    print qq~$http_header
	<HTML><HEAD>
	<TITLE>$DBTITLE - $SBEAMS_PART</TITLE>
    ~;


    $this->printJavascriptFunctions();
    $this->printStyleSheet();


    #### Determine the Title bar background decoration
    my $header_bkg = "bgcolor=\"$BGCOLOR\"";
    $header_bkg = "background=\"/images/plaintop.jpg\"" if ($DBVERSION =~ /Primary/);

    print qq~
	<!--META HTTP-EQUIV="Expires" CONTENT="Fri, Jun 12 1981 08:20:00 GMT"-->
	<!--META HTTP-EQUIV="Pragma" CONTENT="no-cache"-->
	<!--META HTTP-EQUIV="Cache-Control" CONTENT="no-cache"-->
	</HEAD>

	<!-- Background white, links blue (unvisited), navy (visited), red (active) -->
	<BODY BGCOLOR="#FFFFFF" TEXT="#000000" LINK="#0000FF" VLINK="#000080" ALINK="#FF0000" TOPMARGIN=0 LEFTMARGIN=0 OnLoad="self.focus();">
	<table border=0 width="100%" cellspacing=0 cellpadding=1>

	<!------- Header ------------------------------------------------>
	<a name="TOP"></a>
	<tr>
	  <td bgcolor="$BARCOLOR"><a href="http://db.systemsbiology.net/"><img height=64 width=64 border=0 alt="ISB DB" src="$HTML_BASE_DIR/images/dbsmltblue.gif"></a><a href="https://db.systemsbiology.net/sbeams/cgi/main.cgi"><img height=64 width=64 border=0 alt="SBEAMS" src="$HTML_BASE_DIR/images/sbeamssmltblue.gif"></a></td>
	  <td align="left" $header_bkg><H1>$DBTITLE - $SBEAMS_PART<BR>$DBVERSION</H1></td>
	</tr>

    ~;

    #print ">>>http_header=$http_header<BR>\n";

    if ($navigation_bar eq "YES") {
		  my $pad = "<NOBR>&nbsp;&nbsp;&nbsp;";
      print qq~
	<!------- Button Bar -------------------------------------------->
	<tr><td bgcolor="$BARCOLOR" align="left" valign="top">
	<table border=0 width="120" cellpadding=2 cellspacing=0>

	<tr><td><a href="$CGI_BASE_DIR/main.cgi">$DBTITLE Home</a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_PART/main.cgi">$SBEAMS_PART Home</a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/logout.cgi">Logout</a></td></tr>
	<tr><td>&nbsp;</td></tr>
	<tr><td>Lab Workflow:</td></tr>
	<tr><td><a href="main.cgi">$pad View experiments</nobr></a></td></tr>
	<tr><td><a href="upload_workbook.cgi">$pad Upload samples</nobr></a></td></tr>
	<tr><td><a href="treatment.cgi">$pad Add glycopture prep</nobr></a></td></tr>
	<tr><td><a href="lc_ms.cgi">$pad Add LC/MS run</nobr></a></td></tr>
	<tr><td>&nbsp;</td></tr>
	<tr><td>Manage Tables:</td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=BM_Analysis_file">$pad Analysis_file</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=BM_Attribute">$pad Attribute</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=BM_Attribute_type">$pad Attribute_type</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=BM_Biosample">$pad Biosample</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=BM_Biosource">$pad Biosource</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=BM_Disease">$pad Disease</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=BM_Disease_type">$pad Disease_type</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=BM_Experiment">$pad Experiment</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=BM_Storage_location">$pad Storage_location</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=BM_Treatment">$pad Treatment</nobr></a></td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/ManageTable.cgi?TABLE_NAME=BM_Treatment_type">$pad Treatment_type</nobr></a></td></tr>
	<tr><td>&nbsp;</td></tr>
	<tr><td>Browse Data:</td></tr>
	<tr><td><a href="$CGI_BASE_DIR/$SBEAMS_SUBDIR/BrowseBioSequence.cgi"><nobr>&nbsp;&nbsp;&nbsp;Browse BioSeqs</nobr></a></td></tr>
	</table>
	</td>

	<!-------- Main Page ------------------------------------------->
	<td valign=top>
	<table border=0 bgcolor="#ffffff" cellpadding=4>
	<tr><td>

    ~;
    } else {
      print qq~
	</TABLE>
      ~;
    }

}

# 	<table border=0 width="680" bgcolor="#ffffff" cellpadding=4>


###############################################################################
# printStyleSheet
#
# Print the standard style sheet for pages.  Use a font size of 10pt if
# remote client is on Windows, else use 12pt.  This ends up making fonts
# appear the same size on Windows+IE and Linux+Netscape.  Other tweaks for
# different browsers might be appropriate.
###############################################################################
sub printStyleSheet {
    my $this = shift;
    #### Obtain main SBEAMS object and use its style sheet
    my $sbeams = $this->getSBEAMS();
    $sbeams->printStyleSheet();
}


###############################################################################
# printJavascriptFunctions
#
# Print the standard Javascript functions that should appear at the top of
# most pages.  There probably should be some customization allowance here.
# Not sure how to design that yet.
###############################################################################
sub printJavascriptFunctions {
    my $this = shift;
    my $javascript_includes = shift;


    print qq~
	<SCRIPT LANGUAGE="JavaScript">
	<!--

	function refreshDocument() {
            //confirm( "apply_action ="+document.MainForm.apply_action.options[0].selected+"=");
            document.MainForm.apply_action_hidden.value = "REFRESH";
            document.MainForm.action.value = "REFRESH";
	    document.MainForm.submit();
	} // end refreshDocument


	function showPassed(input_field) {
            //confirm( "input_field ="+input_field+"=");
            confirm( "selected option ="+document.forms[0].slide_id.options[document.forms[0].slide_id.selectedIndex].text+"=");
	    return;
	} // end showPassed



        // -->
        </SCRIPT>
    ~;

}


###############################################################################
# printPageFooter
###############################################################################
sub printPageFooter {
  my $this = shift;
  $this->display_page_footer(@_);
}


###############################################################################
# display_page_footer
###############################################################################
sub display_page_footer {
  my $this = shift;
  my %args = @_;


  #### If the output mode is interactive text, display text header
  my $sbeams = $this->getSBEAMS();
  if ($sbeams->output_mode() eq 'interactive') {
    $sbeams->printTextHeader(%args);
    return;
  }


  #### If the output mode is not html, then we don't want a header here
  if ($sbeams->output_mode() ne 'html') {
    return;
  }


  #### Process the arguments list
  my $close_tables = $args{'close_tables'} || 'YES';
  my $display_footer = $args{'display_footer'} || 'YES';
  my $separator_bar = $args{'separator_bar'} || 'NO';


  #### If closing the content tables is desired
  if ($close_tables eq 'YES') {
    print qq~
	</TD></TR></TABLE>
	</TD></TR></TABLE>
    ~;
  }


  #### If displaying a fat bar separtor is desired
  if ($separator_bar eq 'YES') {
    print "<BR><HR SIZE=5 NOSHADE><BR>\n";
  }


  #### If finishing up the page completely is desired
  if ($display_footer eq 'YES') {
    #### Default to the Core footer
    $sbeams->display_page_footer(display_footer=>'YES');
  }

}

## Interface routines ##

sub get_treatment_sample_select {
  my $this = shift;
  my %args = @_;
  my $params = $args{params} || die "missing required 'params' hashref";
  my $type = $args{types} || die "missing required parameter types";

  $params->{experiment_id} ||= $this->get_first_experiment_id(@_);
  
  die "Must pass type as an arrayref" unless (ref($type) eq 'ARRAY');


  my $sbeams = $this->getSBEAMS();
  my $pid = $sbeams->getCurrent_project_id || die("Can't determine project_id");
  my @acc = $sbeams->getAccessibleProjects();
  my $table = SBEAMS::Connection::DataTable->new( BORDER => 1 );
  my $sql =<<"  END";
  SELECT biosample_id, biosample_name || ' - ' || bio_group_name AS sample
  FROM $TBBM_BIOSAMPLE BS 
  JOIN $TBBM_BIO_GROUP BG ON BS.biosample_group_id = BG.bio_group_id
  WHERE BS.experiment_id = $params->{experiment_id}
  AND BS.record_status <> 'D'
  AND BG.record_status <> 'D'
  ORDER BY biosample_group_id ASC, biosample_id ASC
  END

  my @current = split /,/, $params->{biosample_id};
  
  my $options = $sbeams->buildOptionList($sql, $params->{biosample_id}, 'MULTIOPTIONLIST' );
  my $select = "<SELECT MULTIPLE SIZE=6 NAME=biosample_id>$options</SELECT>";
  return $select;
  
## Deprecated in favor of a multi-select list

  for my $row ( $sbeams->selectSeveralColumns( $sql ) ) {
    $row->[0] = get_ts_checkbox( $row->[0] );
    $table->addRow( $row );
  }
  
  $table->alternateColors( PERIOD => 3,
                           BGCOLOR => '#FFFFFF',
                           DEF_BGCOLOR => '#E0E0E0',
                           FIRSTROW => 0 ); 
  $table->setColAttr( ROWS => [ 2..$table->getRowNum() ], 
                      COLS => [ 1,2 ], 
                      ALIGN => 'RIGHT' );
  $table->setColAttr( ROWS => [ 1 ], 
                      COLS => [ 1..2], 
                      ALIGN => 'CENTER' );
  my $list = $table->asHTML();
  return $list;
}

sub get_ts_checkbox {
  my $val = shift;
  return "<INPUT TYPE=CHECKBOX NAME=biosample_id VALUE=$val></INPUT>";
}

#+ 
# Routine builds a list of experiments/samples within.
#-
sub get_experiment_overview {
  my $this = shift;
  my $sbeams = $this->getSBEAMS();
  my $pid = $sbeams->getCurrent_project_id || die("Can't determine project_id");

  my %msruns = $sbeams->selectTwoColumnHash( <<"  END" );
  SELECT e.experiment_id, COUNT(msrs.biosample_id)
  FROM $TBBM_EXPERIMENT e 
  LEFT OUTER JOIN $TBBM_BIOSAMPLE b
  ON e.experiment_id = b.experiment_id
  LEFT OUTER JOIN $TBBM_MS_RUN_SAMPLE msrs
  ON b.biosample_id = msrs.biosample_id
--  JOIN $TBBM_MS_RUN msr
--  ON e. = msrs.ms_run_id = msr.ms_run_id
  WHERE project_id = $pid
  -- Just grab the 'primary' samples 
  GROUP BY e.experiment_id
  END

  my $sql =<<"  END";
  SELECT e.experiment_id, experiment_name, experiment_tag, 
  experiment_type, experiment_description, COUNT(biosample_id)
  FROM $TBBM_EXPERIMENT e 
  LEFT OUTER JOIN $TBBM_BIOSAMPLE b
  ON e.experiment_id = b.experiment_id
--  JOIN $TBBM_MS_RUN_SAMPLE msrs
--  ON e. = b.biosample_id = msrs.biosample_id
--  JOIN $TBBM_MS_RUN msr
--  ON e. = msrs.ms_run_id = msr.ms_run_id
  WHERE project_id = $pid
  -- Just grab the 'primary' samples 
  AND parent_biosample_id IS NULL
  GROUP by experiment_name, experiment_description, 
           experiment_type, e.experiment_id, experiment_tag
  ORDER BY experiment_name ASC
  END
  $log->error( $sql );
  
  my $table = SBEAMS::Connection::DataTable->new( WIDTH => '100%' );
  $table->addResultsetHeader( ['Experiment Name', 'Tag', 'Type', 'Description', 
                         '# samples', '# ms runs' ] );

  for my $row ( $sbeams->selectSeveralColumns($sql) ) {
    my @row = @$row;
    my $id = shift @row;
    $row[3] = ( length $row[3] <= 50 ) ? $row[3] : shortlink($row[3], 50);
    $row[0] =<<"    END";
    <A HREF=experiment_details.cgi?experiment_id=$id>$row[0]</A>
    END
    push @row, $msruns{$id};
    $table->addRow( \@row )
  }
  $table->alternateColors( PERIOD => 1,
                           BGCOLOR => '#FFFFFF',
                           DEF_BGCOLOR => '#E0E0E0',
                           FIRSTROW => 0 ); 
  $table->setColAttr( ROWS => [ 2..$table->getRowNum() ], 
                      COLS => [ 4, 5 ], 
                      ALIGN => 'RIGHT' );
  $table->setColAttr( ROWS => [ 1 ], 
                      COLS => [ 1..6 ], 
                      ALIGN => 'CENTER' );
  return $table;
}
#+
#
#-
sub get_storage_loc_select {
  my $this = shift;
  my %args = @_;

  # Select currval?
  if ( $args{current} && ref($args{current} eq 'ARRAY') ) {
    # stringify args if we were passed an arrayref
    $args{current} = join ",", @{$args{current}};
  }

  my $sbeams = $this->getSBEAMS();

  my $sql =<<"  END";
  SELECT storage_location_id, location_name
  FROM $TBBM_STORAGE_LOCATION
  WHERE record_status <> 'D'
  ORDER BY location_name ASC
  END

  my $options = $sbeams->buildOptionList( $sql, $args{current} );

  my $select_name = $args{name} || 'storage_location_id';
  my $select = "<SELECT NAME=$select_name>$options</SELECT>";
  return $select;
}


#+
#
#-
sub get_treatment_type_select {
  my $this = shift;
  my %args = @_;

  # Select currval?
  if ( $args{current} && ref($args{current} eq 'ARRAY') ) {
    # stringify args if we were passed an arrayref
    $args{current} = join ",", @{$args{current}};
  }

  my $sbeams = $this->getSBEAMS();

  my $sql =<<"  END";
  SELECT treatment_type_id, treatment_type_name
  FROM $TBBM_TREATMENT_TYPE
  WHERE record_status <> 'D'
  ORDER BY treatment_type_name ASC
  END

  my $options = $sbeams->buildOptionList( $sql, $args{current} );

  my $select_name = $args{name} || 'treatment_type_id';
  my $select = "<SELECT NAME=$select_name>$options</SELECT>";
  return $select;

  # deprecated
  my @rows = $sbeams->selectSeveralColumns( $sql );
  for my $row ( @rows ) {
    $select .= "<OPTION VALUE=$row->[0]> $row->[1]";
  }

  return $select;
}

#+
# Routine returns a select list of input biosample types, constrained 
# by include and/or exclude lists
#-
sub get_sample_type_select {
  my $this = shift;
  my $sbeams = $this->getSBEAMS();
  my %args = @_;

  # Select currval?
  if ( $args{current} && ref($args{current} eq 'ARRAY') ) {
    # stringify args if we were passed an arrayref
    $args{current} = join ",", @{$args{current}};
  }

  my $limit_clause = '';
  if ($args{include_types} && ref $args{include_types} eq 'ARRAY' ) {
    my $qlist = $sbeams->get_quoted_list( $args{include_types} );
    $limit_clause = "WHERE biosample_type_name IN ( $qlist )" if $qlist;
  }
  if ($args{exclude_types} && ref $args{exclude_types} eq 'ARRAY' ) {
    my $qlist = $sbeams->get_quoted_list( $args{exclude_types} );
    my $type = ( $limit_clause ) ? 'AND' : 'WHERE';
    $limit_clause = " $type biosample_type_name NOT IN ( $qlist )" if $qlist;
  }

  $log->debug( "with $args{name}, where is $limit_clause\n" );
  $log->debug( "Args are $args{include_types}" );
  $log->debug( "Args are $args{exclude_types}" );

  my $sbeams = $this->getSBEAMS();

  my $sql =<<"  END";
  SELECT biosample_type_id, biosample_type_name 
  FROM $TBBM_BIOSAMPLE_TYPE
  $limit_clause
  ORDER BY biosample_type_name ASC
  END

  my $options = $sbeams->buildOptionList( $sql, $args{current} );

  my $select_name = $args{name} || 'sample_type';
  my $select = "<SELECT NAME=$select_name>$options</SELECT>";
  return $select;

  # deprecated
  my @rows = $sbeams->selectSeveralColumns( $sql );
  for my $row ( @rows ) {
    $select .= "<OPTION VALUE=$row->[0]> $row->[1]";
  }

  return $select;
}
#+
#-
sub get_protocol_select {
  my $this = shift;
  my %args = @_;

  # Select currval?
  if ( $args{current} && ref($args{current} eq 'ARRAY') ) {
    # stringify args if we were passed an arrayref
    $args{current} = join ",", @{$args{current}};
  }

  my $sbeams = $this->getSBEAMS();

  my $sql =<<"  END";
  SELECT protocol_id, P.name
  FROM $TB_PROTOCOL P JOIN $TB_PROTOCOL_TYPE PT
  ON PT.protocol_type_id = P.protocol_type_id
  WHERE PT.name = 'glycocapture' 
  AND PT.record_status <> 'D'
  AND PT.record_status <> 'D'
  ORDER BY P.name ASC
  END

  my $options = $sbeams->buildOptionList( $sql, $args{current} );

  my $select_name = $args{name} || 'protocol_id';
  my $select = "<SELECT NAME=$select_name>$options</SELECT>";
  return $select;

  # deprecated
  my @rows = $sbeams->selectSeveralColumns( $sql );
  for my $row ( @rows ) {
    $select .= "<OPTION VALUE=$row->[0]> $row->[1]";
  }

  return $select;
}
#+
# Returns array of HTML form buttons
#
# arg types    arrayref, required, values of submit, back, reset
# arg name     name of submit button (if any)
# arg value    value of submit button (if any)
# arg back_name     name of submit button (if any)
# arg back_value    value of submit button (if any)
# arg reset_value    value of reset button (if any)
#-
sub get_form_buttons {
  my $this = shift;
  my %args = @_;
  $args{name} ||= 'Submit';
  $args{value} ||= 'Submit';
  $args{onclick} ||= '';

  $args{back_name} ||= 'Back';
  $args{back_value} ||= 'Back';
  $args{back_onclick} ||= '';

  $args{reset_value} ||= 'Reset';
  $args{reset_onclick} ||= '';

  for ( qw( reset_onclick back_onclick onclick ) ) {
    $args{$_} = "onClick=$args{$_}" if $args{$_};
  }
  
  $args{types} ||= [];

  my @b;

  for my $type ( @{$args{types}} ) {
    push @b, <<"    END" if $type =~ /^submit$/i; 
    <INPUT TYPE=SUBMIT NAME=$args{name} VALUE=$args{value} $args{onclick}>
    END
    push @b, <<"    END" if $type =~ /^back$/i; 
    <INPUT TYPE=SUBMIT NAME=$args{back_name} VALUE=$args{back_value} $args{back_onclick}>
    END
    push @b, <<"    END" if $type =~ /^reset$/i; 
    <INPUT TYPE=RESET VALUE=$args{reset_value} $args{reset_onclick}>
    END
  }
  return @b;
}


#+
#-
sub get_replicate_names_select {
  my $this = shift;
  my %args = @_;
  return <<"  END";
  <SELECT NAME=replicate_names>
   <OPTION VALUE=abc>a,b,c</OPTION>
   <OPTION VALUE=123>1,2,3</OPTION>
  </SELECT>
  END

}


#+
#-
sub get_experiment_select {
  my $this = shift;
  my %args = @_;

  # Select currval?
  if ( $args{current} && ref($args{current}) eq 'ARRAY' ) {
    # stringify args if we were passed an arrayref
    $args{current} = join ",", @{$args{current}};
    $log->debug( "PARAM: $args{current}" . ref( $args{current} ) );
  }

  my $sbeams = $this->getSBEAMS();
  my $project_id = $sbeams->getCurrent_project_id();

  my $project_list;
  if ( $args{writeable} ) {
    $project_list = join( ',', $sbeams->getWritableProjects() ) || '';
  } elsif ( $args{accessible} ) {
    $project_list = join( ',', $sbeams->getAccessibleProjects() ) || '';
  }
  my $project_list ||= $project_id;

  my $project_constraint = "WHERE project_id IN ( $project_list )";

  my $sql =<<"  END";
  SELECT experiment_id, experiment_name
  FROM $TBBM_EXPERIMENT
  $project_constraint
  ORDER BY experiment_name ASC
  END

  return ($sql) if $args{sql_only};

  my $options = $sbeams->buildOptionList( $sql, $args{current} );

  my $select_name = $args{name} || 'experiment_id';
  return ( <<"  END" );
  <SELECT NAME=$select_name ONCHANGE=switchExperiment()>
  $options
  </SELECT>
  END

  # deprecated
  my $select;
  my @rows = $sbeams->selectSeveralColumns( $sql );
  for my $row ( @rows ) {
    $select .= "<OPTION VALUE=$row->[0]> $row->[1]";
  }

  return $select;
}

#+
# Odd routine to get first experiment_id from list get_expt_select, for first
# load.
#-
sub get_first_experiment_id {
  my $this = shift;
  my $sql = $this->get_experiment_select( sql_only => 1,
                                          writable => 1 );
  my $sbeams = $this->getSBEAMS();
  my @rows = $sbeams->selectSeveralColumns( $sql );
  return $rows[0]->[0];
}

#+
# Routine builds a list of experiments/samples within.
#-
sub get_experiment_samples {
  my $this = shift;
  my $expt_id = shift;
  my $sbeams = $this->getSBEAMS();
  my $pid = $sbeams->getCurrent_project_id || die("Can't determine project_id");

  my $sql =<<"  END";
  SELECT biosample_id, biosample_name, tissue_type_name, 
         original_volume, location_name, 'glycocapture' AS glyco, 
         'msrun' AS msrun, 'mzXML' AS mzXML, 'pep3D' AS pep3D  
  FROM $TBBM_BIOSAMPLE b 
   JOIN $TBBM_BIOSOURCE r ON r.biosource_id = b.biosource_id
   JOIN $TBBM_TISSUE_TYPE t ON r.tissue_type_id = t.tissue_type_id
   JOIN $TBBM_STORAGE_LOCATION s ON s.storage_location_id = b.storage_location_id
  WHERE experiment_id = $expt_id
  ORDER BY biosample_name ASC
  END
       
  my $table = SBEAMS::Connection::DataTable->new( WIDTH => '80%' );
  $table->addResultsetHeader( ['Sample Name', 'Tissue', 'Vol (&#181;l)',
                       'Storage location', 'Glycocap', 'MS_run', 'mzXML', 'pep3D' ] );

  my $cnt = 0;
  for my $row ( $sbeams->selectSeveralColumns($sql) ) {
    my @row = @$row;
    my $id = shift @row;
    $row[3] = ( length $row[3] <= 30 ) ? $row[3] :
                                         substr( $row[3], 0, 27 ) . '...';
    $row[2] = ( $row[2] ) ? $row[2]/1000 : 0;
    $row[0] =<<"    END";
    <A HREF=sample_details.cgi?sample_id=$id>$row[0]</A>
    END
    if ( $cnt > 5 ) {
      $row[7] = undef;
      $row[6] = undef;
    } else {
      $row[6] = 'Yes';
      $row[7] = '<A HREF=/tmp/pep3d.gif>Yes</A>';
    }
    if ( $cnt > 11 ) {
      $row[5] = undef;
    } else {
      $row[5] = '<A HREF=/tmp/pep3d.gif>Yes</A>';
    }
    if ( $cnt > 108 ) {
      $row[4] = undef;
    } else {
      $row[4] = '<A HREF=/tmp/pep3d.gif>Yes</A>';
    }
    $cnt++;
    $table->addRow( \@row )
  }
  $table->alternateColors( PERIOD => 3,
                           BGCOLOR => '#F3F3F3',
                           DEF_BGCOLOR => '#E0E0E0' ); 
  $table->setColAttr( ROWS => [ 2..$table->getRowNum() ], 
                      COLS => [ 2,4..8 ], 
                      ALIGN => 'CENTER' );
  $table->setColAttr( ROWS => [ 2..$table->getRowNum() ], 
                      COLS => [ 3 ], 
                      ALIGN => 'RIGHT' );
  $table->setColAttr( ROWS => [ 1 ], 
                      COLS => [ 1..8 ], 
                      ALIGN => 'CENTER' );
  return $table;
}


#+
# Routine shows the details of a given experiment, with a listing
# of samples therein.
#-
sub get_experiment_details {
  my $this = shift;
  my $expt_id = shift;
  return '';
  my $sbeams = $this->getSBEAMS();
  my $pid = $sbeams->getCurrent_project_id || die("Can't determine project_id");

  my $sql =<<"  END";
  SELECT e.experiment_id, experiment_tag, experiment_name, experiment_type, 
  experiment_description, COUNT(biosample_id) AS total_biosamples
  FROM $TBBM_EXPERIMENT e 
  LEFT OUTER JOIN $TBBM_BIOSAMPLE b
  ON e.experiment_id = b.experiment_id
--  JOIN $TBBM_MS_RUN_SAMPLE msrs
--  ON e. = b.biosample_id = msrs.biosample_id
--  JOIN $TBBM_MS_RUN msr
--  ON e. = msrs.ms_run_id = msr.ms_run_id
  WHERE project_id = $pid
  -- Just grab the 'primary' samples 
  AND parent_biosample_id IS NULL
  GROUP by experiment_name, experiment_description, 
           experiment_type, e.experiment_id
  ORDER BY experiment_name ASC
  END

  my ($expt) = $sbeams->selectrow_hashref($sql);
  my $table = '<TABLE>';
  for my $key ( qw(experiment_name experiment_tag experiment_type 
                   experiment_description total_biosamples) ) {
    my $ukey = ucfirst( $key );
    $table .= "<TR><TD ALIGN=RIGHT><B>$ukey:</B></TD><TD>$expt->{$key}</TD></TR>";
  }
  $table .= '</TABLE>';
       
  return $table;
}

sub get_treatment_select {
  my $this = shift;
  my $sbeams = $this->getSBEAMS();
  my $select = $sbeams->buildOptionList( <<"  END" );
  SELECT treatment_name, treatment_id
  FROM $TBBM_TREATMENT
  WHERE record_status != 'D'
  END
  return $select;
 
}

sub get_back_button_js {
  return ( <<"  END" );
	<SCRIPT LANGUAGE="JavaScript">
  function send_back(){
    document.verify_samples.apply_action.value = "REFRESH";
    document.verify_samples.submit();
  }
  </SCRIPT>
  END
}

#+
sub get_experiment_change_js {
  return ( <<"  END" );
	<SCRIPT LANGUAGE="JavaScript">
  function switchExperiment(){
    var experiment_id = document.sample_treatment.experiment_id;
    var value = experiment_id.options[experiment_id.selectedIndex].value;
    document.sample_treatment.apply_action_hidden.value = "REFRESH";
    document.sample_treatment.submit();
  }
  </SCRIPT>
  END
}


#+
# Returns HTML summary of mapping between old and new samples for a given 
# treatment
#-
sub treatment_sample_content {
  my $this = shift;
  my %args = @_;
  for my $arg ( qw( sample_map p_ref ) ) {
    die( "Missing required arguement $arg" ) unless defined $args{$arg};
  }

  my $back_js = get_back_button_js();

  # Cache all the existing parameters (gotcha?)
  my $hidden =<<"  END";
  <INPUT TYPE=HIDDEN NAME=apply_action VALUE='process_treatment'></INPUT>
  END
 
  my %params = %{$args{p_ref}};

  for my $key ( keys ( %params ) ) {
    next if $key =~ /action/;
    $hidden .=<<"    END";
    <INPUT TYPE=HIDDEN NAME=$key VALUE='$params{$key}'></INPUT>
    END
  }
  
  # There must be at least one biosample_id
  my @samples = split ",", $params{biosample_id};
  return undef unless scalar( @samples );

  # Avoid dref hell
  my %parents = %{$args{sample_map}->{parents}};
  my %children = %{$args{sample_map}->{children}};

  my $table = SBEAMS::Connection::DataTable->new( BORDER => 1 );
  my @buttons = $this->get_form_buttons( name => 'process_samples', 
                                        value => 'Process_samples',
                                   back_value => 'Review_form',
                                 back_onclick => 'send_back();',
                                        types => [ qw(submit back) ] );
  $table->addRow( [join "&nbsp;", @buttons] );

  for my $id ( @samples ) {
    my $name = $parents{$id}->{biosample_name};
    for my $child ( @{$children{$id}} ) {
      $table->addRow( [ $name, '=>', $child->{biosample_name} ] );
      $name = '"&nbsp;&nbsp;&nbsp;';
    }
  }
  my $end = $table->getRowNum();
  $table->alternateColors( PERIOD => $params{num_replicates},
                           BGCOLOR => '#FFFFFF',
                           DEF_BGCOLOR => '#E0E0E0',
                           FIRSTROW => 0 ); 
  $table->setColAttr( ROWS => [1] ,COLS => [1], COLSPAN => 3, ALIGN => 'CENTER' );
  $table->setColAttr( ROWS => [2..$end] ,COLS => [1], ALIGN => 'RIGHT');
  $table->setColAttr( ROWS => [2..$end] ,COLS => [2], ALIGN => 'CENTER');
  $table->setColAttr( ROWS => [2..$end] ,COLS => [3], ALIGN => 'LEFT');

  # Caller will supply form tags
  return <<"  END_RETURN";
  $back_js
  $table
  $hidden
  END_RETURN
  
  
}

## Utility routines

sub shortlink {
  my $val = shift;
  my $len = shift;
  return "<DIV title='$val'> ". substr( $val, 0, $len - 3 ) . '...</DIV>';
}



###############################################################################

1;

__END__
###############################################################################
###############################################################################
###############################################################################

=head1 NAME

SBEAMS::WebInterface::HTMLPrinter - Perl extension for common HTML printing methods

=head1 SYNOPSIS

  Used as part of this system

    use SBEAMS::WebInterface;
    $adb = new SBEAMS::WebInterface;

    $adb->printPageHeader();

    $adb->printPageFooter();

    $adb->getGoBackButton();

=head1 DESCRIPTION

    This module is inherited by the SBEAMS::WebInterface module,
    although it can be used on its own.  Its main function 
    is to encapsulate common HTML printing routines used by
    this application.

=head1 METHODS

=item B<printPageHeader()>

    Prints the common HTML header used by all HTML pages generated 
    by theis application

=item B<printPageFooter()>

    Prints the common HTML footer used by all HTML pages generated 
    by this application

=item B<getGoBackButton()>

    Returns a form button, coded with javascript, so that when it 
    is clicked the user is returned to the previous page in the 
    browser history.

=head1 AUTHOR

Eric Deutsch <edeutsch@systemsbiology.org>

=head1 SEE ALSO

perl(1).

=cut
