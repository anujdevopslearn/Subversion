package SBEAMS::SolexaTrans::DBInterface;

###############################################################################
# Program     : SBEAMS::SolexaTrans::DBInterface
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id: DBInterface.pm 4504 2006-03-07 23:49:03Z edeutsch $
#
# Description : This is part of the SBEAMS::SolexaTrans module which handles
#               general communication with the database.
#
###############################################################################


use strict;
use vars qw(@ERRORS @ISA $dbh $log);
use CGI::Carp qw( croak);
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Log;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::DBInterface;
use Data::Dumper;

#@ISA = qw(SBEAMS::Connection);


###############################################################################
# Global variables
###############################################################################


###############################################################################
# Constructor
###############################################################################
sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;
    return($self);
}


###############################################################################
# 
###############################################################################

###############################################################################
# display_input_form
#
# Print the parameter input form for this particular table or query
###############################################################################
sub display_input_form {
  my $self = shift;
  my %args = @_;

  my $sbeams = $self->getSBEAMS();
  #### If the output mode is not html, then we don't want a form
  if ($sbeams->output_mode() ne 'html') {
    return;
  }


  #### Process the arguments list
  my $TABLE_NAME = $args{'TABLE_NAME'};
  my $CATEGORY = $args{'CATEGORY'};
  my $PROGRAM_FILE_NAME = $args{'PROGRAM_FILE_NAME'};
  my $apply_action = $args{'apply_action'};
  my $parameters_ref = $args{'parameters_ref'};
  my %parameters = %{$parameters_ref};
  my $input_types_ref = $args{'input_types_ref'};
  my %input_types = %{$input_types_ref};
  my $mask_user_context = $args{'mask_user_context'};
  my $allow_NOT_flags = $args{'allow_NOT_flags'};
  my $onSubmit = $args{onSubmit} || '';
  # masks (doesn't print) the query constraints button at the top of a form if you don't have minimum_detail settings
  my $mask_query_constraints = $args{'mask_query_constraints'};
  # masks (doesn't print) the form start tag in display_input_form
  my $mask_form_start = $args{'mask_form_start'};
  my $id = $args{"id"};
  # allows user to change form name (note that MainForm is the required name for code that uses refreshDocument)
  my $form_name = $args{"form_name"} || 'MainForm';

  if ($id) {
    $parameters{id} = $id;
  }
  # Set a sensible default
  my $detail_level = $parameters{input_form_format} || 'minimum_detail';


  #### Define popular variables
  my ($i,$element,$key,$value,$line,$result,$sql);
  my $PK_COLUMN_NAME;
  my ($row);


  #### Query to obtain column information about this table or query
  $sql = qq~
      SELECT column_name,column_title,is_required,input_type,input_length,
             is_data_column,is_display_column,column_text,
             optionlist_query,onChange
        FROM $TB_TABLE_COLUMN
       WHERE table_name='$TABLE_NAME'
         AND is_data_column='Y'
       ORDER BY column_index
  ~;
  my @cols_data = $sbeams->selectSeveralColumns($sql);
  my @columns_data;
  foreach my $inner (@cols_data) {
    push(@columns_data, [@$inner]);
  }

  for (my $i = 0; $i <= $#columns_data; $i++) {
    my @irow = @{$columns_data[$i]};
    my $column_name = $irow[0];
    if ($column_name =~ /\$parameters\{(\w+)\}/) {
      my $tmp = $parameters{$1};
      if (defined($tmp) && $tmp gt '') {
        unless ($tmp =~ /^[\d,]+$/) {
          my @tmp = split(',', $tmp);
          $tmp = '';
          foreach my $tmp_element (@tmp) {
            $tmp .= "'$tmp_element',";
          }
          chop($tmp);
        }
      } else {
        $tmp = "''";
      }
      my $new_name = $columns_data[$i]->[0];
      $new_name =~ s/\$parameters{$1}/$tmp/g;
      $columns_data[$i]->[0] = $new_name;
    }
  }

  # First just extract any valid optionlist entries.  This is done
  # first as opposed to within the loop below so that a single DB connection
  # can be used.
  # THIS IS LEGACY AND NO LONGER A USEFUL REASON TO DO SEPARATELY
  my %optionlist_queries;
  my $file_upload_flag = "";
#  foreach $row (@cols_data) {
  for (my $i = 0; $i <= $#cols_data; $i++) {
    my @row = @{$cols_data[$i]};
    my ($column_name,$column_title,$is_required,$input_type,$input_length,
        $is_data_column,$is_display_column,$column_text,
        $optionlist_query,$onChange) = @row;
    if (defined($optionlist_query) && $optionlist_query gt '') {
      #print "<font color=\"red\">$column_name</font><BR><PRE>$optionlist_query</PRE><BR>\n";
      $optionlist_queries{$column_name}=$optionlist_query;
      $optionlist_queries{$columns_data[$i]->[0]} = $optionlist_query if ($parameters{$columns_data[$i]->[0]});
      $input_types{$columns_data[$i]->[0]} = $input_types{$column_name} if ($parameters{$columns_data[$i]->[0]});
    }
    if ($input_type eq "file") {
      $file_upload_flag = "ENCTYPE=\"multipart/form-data\"";
    }
  }

  # There appears to be a Netscape bug in that one cannot [BACK] to a form
  # that had multipart encoding.  So, only include form type multipart if
  # we really have an upload field.  IE users are fine either way.
  $sbeams->printUserContext() unless ($mask_user_context);
  print qq!
      <P>
      <H2>$CATEGORY</H2>
      $LINESEPARATOR
      <FORM METHOD="post" ACTION="$PROGRAM_FILE_NAME" NAME="$form_name" $file_upload_flag $onSubmit>
      <TABLE BORDER=0>
  ! unless ($mask_form_start);


  # ---------------------------
  # Build option lists for each optionlist query provided for this table
  my %optionlists;
  foreach $element (keys %optionlist_queries) {
      # If "$contact_id" appears in the SQL optionlist query, then substitute
      # that with either a value of $parameters{contact_id} if it is not
      # empty, or otherwise replace with the $current_contact_id
      if ( $optionlist_queries{$element} =~ /\$contact_id/ ) {
        if ( $parameters{"contact_id"} eq "" ) {
          my $current_contact_id = $sbeams->getCurrent_contact_id();
          $optionlist_queries{$element} =~
              s/\$contact_id/$current_contact_id/g;
        } else {
          $optionlist_queries{$element} =~
              s/\$contact_id/$parameters{contact_id}/g;
        }
      }


      # If "$accessible_project_ids" appears in the SQL optionlist query,
      # then substitute it with a call to that function
      if ( $optionlist_queries{$element} =~ /\$accessible_project_ids/ ) {
        my @accessible_project_ids = $sbeams->getAccessibleProjects();
        my $accessible_project_id_list = join(',',@accessible_project_ids);
        $accessible_project_id_list = '-1'
          unless ($accessible_project_id_list gt '');
        $optionlist_queries{$element} =~
          s/\$accessible_project_ids/$accessible_project_id_list/g;
      }


      # If "$project_id" appears in the SQL optionlist query, then substitute
      # that with either a value of $parameters{project_id} if it is not
      # empty, or otherwise replace with the $current_project_id
      if ( $optionlist_queries{$element} =~ /\$project_id/ ) {
        if ( $parameters{"project_id"} eq "" ) {
          my $current_project_id = $sbeams->getCurrent_project_id();
          $optionlist_queries{$element} =~
              s/\$project_id/$current_project_id/g;
        } else {
          $optionlist_queries{$element} =~
              s/\$project_id/$parameters{project_id}/g;
        }
      }


      # If "$parameters{xxx}" appears in the SQL optionlist query,
      # then substitute that with either a value of $parameters{xxx}
      while ( $optionlist_queries{$element} =~ /\$parameters\{(\w+)\}/ ) {
        my $tmp = $parameters{$1};
        if (defined($tmp) && $tmp gt '') {
          unless ($tmp =~ /^[\d,]+$/) {
            my @tmp = split(',',$tmp);
            $tmp = '';
            foreach my $tmp_element (@tmp) {
              $tmp .= "'$tmp_element',";
            }
            chop($tmp);
          }
        } else {
          $tmp = "''";
        }

        $optionlist_queries{$element} =~
          s/\$parameters{$1}/$tmp/g;
      }


      #### Evaluate the $TBxxxxx table name variables if in the query
      if ( $optionlist_queries{$element} =~ /\$TB/ ) {
        my $tmp = $optionlist_queries{$element};

        #### If there are any double quotes, need to escape them first
        $tmp =~ s/\"/\\\"/g;
         $optionlist_queries{$element} = $sbeams->evalSQL($tmp);
        unless ($optionlist_queries{$element}) {
          print "<font color=\"red\">ERROR: SQL for field '$element' fails to resolve embedded \$TB table name variable(s)</font><BR><PRE>$tmp</PRE><BR>\n";


        }

      }

      my $method_options = '';
      #### Set the MULTIOPTIONLIST flag if this is a multi-select list
      if ($input_types{$element} eq "multioptionlist") {
        $method_options = "MULTIOPTIONLIST";
      }

      if ($input_types{$element} ne 'drag_drop') {
        #   Build the option list
        #print "<font color=\"red\">$element</font><BR><PRE>$optionlist_queries{$element}<BR>$method_options</PRE><BR>\n";

        $optionlists{$element}=$sbeams->buildOptionList(
              $optionlist_queries{$element},$parameters{$element},$method_options);

        #### If the user sent some invalid options, reset the list to the
        #### valid list.  This is a hack because buildOptionList() API is poor
        if ($optionlists{$element} =~ /\<\!\-\-(.*)\-\-\>/) {
          $parameters_ref->{$element} = $1;
        }
      }
  } # end foreach

  # Add CSS and javascript for popup column_text info (if configured) and full form fields show/hide toggle button
  print $sbeams->getPopupDHTML();

  unless ($mask_query_constraints) {
    print $sbeams->getFullFormDHTML();

    # ...add said button
    print qq!
      <TR>
      <TD><hr color="#ffffff" width="275"></TD>
      <TD colspan="2">
      <input type="button" id="form_detail_control" onClick="toggleFullForm()" value="Show All Query Constraints">
      </TD></TR>
      !;
  }

  # a flag to see if there's a drag_drop element here and we need to 
  # include the drag drop support javascript at the end
  my $drag_drop_present = 0;
  #### Now loop through again and write the HTML
#  foreach $row (@columns_data) {
  for (my $i = 0; $i <= $#columns_data; $i++) {
    my @row = @{$columns_data[$i]};
    my ($column_name,$column_title,$is_required,$input_type,$input_length,
        $is_data_column,$is_display_column,$column_text,
        $optionlist_query,$onChange) = @row;
    my $default_column_name;
    if ($parameters{$column_name}) {
      $default_column_name = $column_name;
    } else {
      $default_column_name = $cols_data[$i]->[0];
    }
    $onChange = '' unless (defined($onChange));

    #### Set the JavaScript onChange string if supplied
    if ($onChange gt '') {
      $onChange = " onChange=\"$onChange\"";
    }


    #### Set the NOT_clause if allowed
    my $NOT_clause = '';
    if ($allow_NOT_flags) {
      my $NOT_flag = '';
      $NOT_flag = 'CHECKED' if ($parameters{"NOT_$column_name"} eq 'NOT');
      $NOT_clause = qq~NOT<INPUT TYPE="checkbox" NAME="NOT_$column_name"
         VALUE="NOT" $NOT_flag>~;
    }


    #### If the action included the phrase HIDE, don't print all the options
    if ( defined $apply_action && $apply_action =~ /HIDE/i) {
      print qq!
        <TD><INPUT TYPE="hidden" NAME="$column_name"
         VALUE="$parameters{$default_column_name}"></TD>
      !;
      next;
    }

    if ($input_type eq 'hidden') {
      print qq~<INPUT TYPE="hidden" name="$column_name" value="$parameters{$default_column_name}">~;
      next;
    }

    #### If some level of detail is chosen, don't show (hide) this constraint if
    #### it doesn't meet the detail requirements
    if ( ($detail_level eq 'minimum_detail' && $is_display_column ne 'Y') ||
         ($detail_level eq 'medium_detail' && $is_display_column eq '2') ||
          $is_display_column eq 'N'
       ) {

      #### If there's a value in it, then display it
        if (defined $parameters{$column_name} && $parameters{$column_name} gt '') {
            print '<TR bgcolor="#efefef">';
        } else {
            print qq!
                <TR bgcolor="#efefef" name="full_detail_field" id="full_detail_field" class="rowhidden">
                !;
        }
    } else {
        print '<TR>';
    }

    # FIXME 'static conditional' for image link column text
    # Should/could be replaced by a user-configuration option
    use constant LINKHELP => 1;
    if ( LINKHELP ) {
      $column_text = &SBEAMS::Connection::DBInterface::linkToColumnText( $column_text, $default_column_name, $TABLE_NAME );
    }


    #### Write the parameter name, in red if required
    if ($is_required eq "N") {
      print qq!
        <TD><B>$column_title:</B></TD>
            <TD BGCOLOR="E0E0E0">$column_text</TD>
              !;
    } else {
      print qq!
        <TD><B><font color=red>$column_title:</font></B></TD>
            <TD BGCOLOR="E0E0E0">$column_text</TD>
              !;
    }


    if ($input_type eq "text") {
      print qq!
        <TD>$NOT_clause<INPUT TYPE="$input_type" NAME="$column_name"
         VALUE="$parameters{$default_column_name}" SIZE=$input_length $onChange></TD>
      !;
    }
    if ($input_type eq "file") {
      print qq!
        <TD><INPUT TYPE="$input_type" NAME="$column_name"
         VALUE="$parameters{$default_column_name}" SIZE=$input_length $onChange>!;
      if ($parameters{$column_name} && !$parameters{uploaded_file_not_saved}) {
        print qq!<A HREF="$DATA_DIR/$parameters{$column_name}">[view&nbsp;file]</A>
        !;
      }
      print qq!
         </TD>
      !;
    }


    if ($input_type eq "password") {

      # If we just loaded password data from the database, and it's not
      # a blank field, the replace it with a special entry that we'll
      # look for and decode when it comes time to UPDATE.
      if ($parameters{$PK_COLUMN_NAME} gt "" && $apply_action ne "REFRESH") {
        if ($parameters{$column_name} gt "") {
          $parameters{$column_name}="**********".$parameters{$column_name};
        }
      }

      print qq!
        <TD><INPUT TYPE="$input_type" NAME="$column_name"
         VALUE="$parameters{$default_column_name}" SIZE=$input_length></TD>
      !;
    }


    if ($input_type eq "fixed") {
      print qq!
        <TD><INPUT TYPE="hidden" NAME="$column_name"
         VALUE="$parameters{$default_column_name}">$parameters{$column_name}</TD>
      !;
    }

    if ($input_type eq "textarea") {
      print qq~
        <TD COLSPAN=2><TEXTAREA NAME="$column_name" rows=$input_length
          cols=80>$parameters{$default_column_name}</TEXTAREA></TD>
      ~;
    }
    if ($input_type eq "checkbox") {
      my $checked = ( $input_length ) ? 'checked' : '';
      print qq~
      <TD COLSPAN=2 HEIGHT=32><INPUT TYPE=CHECKBOX NAME="$column_name" $checked>$parameters{$default_column_name}</INPUT></TD>
      ~;
    }

    if ($input_type eq "textdate") {
      if ($parameters{$column_name} eq "") {
        my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time());
        $year+=1900; $mon+=1;
        $parameters{$column_name} = "$year-$mon-$mday $hour:$min";
      }
      print qq!
        <TD><INPUT TYPE="text" NAME="$column_name"
         VALUE="$parameters{$default_column_name}" SIZE=$input_length>
        <INPUT TYPE="button" NAME="${column_name}_button"
         VALUE="NOW" onClick="ClickedNowButton($column_name)">
         </TD>
      !;
    }

    if ($input_type eq "optionlist") {
      print qq~
        <TD><SELECT NAME="$column_name" $onChange>
          <!-- $parameters{$default_column_name} -->
        <OPTION VALUE=""></OPTION>
        $optionlists{$default_column_name}</SELECT></TD>
      ~;
    }

    if ($input_type eq "scrolloptionlist") {
      print qq!
        <TD><SELECT NAME="$column_name" SIZE=$input_length $onChange>
        <OPTION VALUE=""></OPTION>
        $optionlists{$default_column_name}</SELECT></TD>
      !;
    }

    if ($input_type eq "multioptionlist") {
      print qq!
        <TD>$NOT_clause<SELECT NAME="$column_name" MULTIPLE SIZE=$input_length $onChange>
        $optionlists{$default_column_name}
        <OPTION VALUE=""></OPTION>
        </SELECT></TD>
      !;
    }

    if ($input_type eq "radio" || $input_type eq "radioh" || $input_type eq "radiov") {

        # hack-ish replacement of optionlist html to generate radio button html
        $optionlists{$column_name} =~
            s/<OPTION VALUE=/
            <INPUT TYPE="radio" NAME="$column_name" $onChange VALUE=/g;

        $optionlists{$column_name} =~
            s/<OPTION SELECTED VALUE=/
            <INPUT TYPE="radio" NAME="$column_name" $onChange CHECKED="checked" VALUE=/g;

        if ($input_type eq "radioh" || $input_type eq "radio") {
          $optionlists{$column_name} =~
            s|</OPTION>|</INPUT>|g;
        } elsif ($input_type eq "radiov") {
          $optionlists{$column_name} =~
            s|</OPTION>|</INPUT><BR/>|g;
        }

      print qq~
        <TD>
          $optionlists{$column_name}</TD>
      ~;
    }

    if ($input_type eq "checkbox" || $input_type eq "checkboxh" || $input_type eq "checkboxv") {

        # hack-ish replacement of optionlist html to generate radio button html
        $optionlists{$column_name} =~
            s/<OPTION VALUE=/
            <INPUT TYPE="checkbox" NAME="$column_name" $onChange VALUE=/g;

        $optionlists{$column_name} =~
            s/<OPTION SELECTED VALUE=/
            <INPUT TYPE="checkbox" NAME="$column_name" $onChange CHECKED="checked" VALUE=/g;

        if ($input_type eq "checkboxh" || $input_type eq "checkbox") {
          $optionlists{$column_name} =~
            s|</OPTION>|</INPUT>|g;
        } elsif ($input_type eq "checkboxv") {
          $optionlists{$column_name} =~
            s|</OPTION>|</INPUT><BR/>|g;
        }

      print qq~
        <TD>
          $optionlists{$column_name}</TD>
      ~;
    }
    if ($input_type eq "current_contact_id") {
      my $username = "";
      my $current_username = $sbeams->getCurrent_username();
      my $current_contact_id = $sbeams->getCurrent_contact_id();
      if ($parameters{$column_name} eq "") {
          $parameters{$column_name}=$current_contact_id;
          $username=$current_username;
      } else {
          if ( $parameters{$column_name} == $current_contact_id) {
            $username=$current_username;
          } else {
            $username=$sbeams->getUsername($parameters{$column_name});
          }
      }
      # I'm not sure if this needs to be changed to $parameters{default_column_name} or not
      print qq!
        <TD><INPUT TYPE="hidden" NAME="$column_name"
         VALUE="$parameters{$column_name}">$username</TD>
      !;
    }

    if ($input_type eq 'drag_drop') {
      $drag_drop_present = 1;
      my ($drag_drop_contents, $drag_drop_selected) = $self->buildDragDrop(
          $optionlist_queries{$default_column_name}, $parameters{$default_column_name});

      print qq~
        <style type="text/css">
              body,th,td{
                font-family: Arial;
              }
              div.section {
                height: 100px;
                overflow: auto;
                width: 240px;
                background-color: #EFEFEF;
                padding: 5px;
                border: 1px solid black;
              }
              .left_drag {
                position: absolute;
                border: 1px solid black;
              }
              .right_drag {
                margin: 0 0 0 250px;
                padding: 0px;
                border: 1px solid black;
              }
              .dd_head {
                background-color: #CCCCCC;
                font-weight: bold;
                padding-left: 5px;
                border-bottom: 2px solid black;
              } 
              .draggable {
                background-color: #FFFFFF;
                padding: 2px;
              }

        </style>
      ~;

      print qq~
        <TD>
          <div id="DRAG_DROP_$column_name">
            <div class="left_drag">
              <div class="dd_head">Available:</div>
              <div id="AVAILABLE_$column_name" class="section" style="padding-right: 2px;">
                $drag_drop_contents
              </div>
            </div>
            <div class="right_drag">
              <div class="dd_head">Selected:</div>
              <div id="SELECTED_$column_name" class="section">
                $drag_drop_selected
              </div>
              <input type="hidden" id="$column_name" name="$column_name" value="test">
            </div>
          </div>
        </TD>
      ~;

      print qq~
        <script type="text/javascript">
            sections = ['SELECTED_$column_name', 'AVAILABLE_$column_name'];
            function createLineItemSortables() {
              for(var i = 0; i < sections.length; i++) {
                Sortable.create(sections[i],{tag:'div',dropOnEmpty: true, containment: sections,only:'draggable'});
              }
            }

            function destroyLineItemSortables() {
              for(var i = 0; i < sections.length; i++) {
                Sortable.destroy(sections[i]);
              }
            }

            Sortable.create("SELECTED_$column_name", {tag: 'div', dropOnEmpty: true, containment: sections, only:'draggable' });
            Sortable.create("AVAILABLE_$column_name", {tag: 'div', dropOnEmpty: true, containment: sections, only:'draggable'});
  
        </script>
      ~;
    }

    print "</TR>\n";

  } # end for loop

  if ($drag_drop_present) {
    print qq~ <script type="text/javascript">
            function setFormDragDrop() {
              var sectionElements = document.getElementsByClassName("section");
              var sections = \$A(sectionElements);
              sections.each(function(section) {
                if (section.id.match("SELECTED_")) {
                  var sectionID = section.id;
                  var order = Sortable.serialize(sectionID);
                  var inputName = new String(sectionID).replace(/SELECTED_/,'');
                  \$(inputName).value = Sortable.sequence(section);
                }
              });
              return false;
            }

           \$('SampleForm').observe('submit',function() {setFormDragDrop()});
          </script>
    ~;
    
  }


} # end display_input_form

###############################################################################

sub buildDragDrop {
  my $self = shift;
  my $sql_query = shift;
  my $selected_option = shift || '';

    my %selected_options;

    my @tmp = split(",",$selected_option);

    my $element;
    foreach $element (@tmp) {
      $selected_options{$element}=1;
    }

    my $sbeams = $self->getSBEAMS();
    #### Get the database handle
    $dbh = $sbeams->getDBHandle();

    #### Convert the SQL dialect if necessary
    $sql_query = $sbeams->translateSQL(sql=>$sql_query);

    ##for debugging:
    #$sbeams->display_sql(sql=>$sql_query);

    my $selected="";   # divs that are selected
    my $available="";  # divs that are not selected
    my $sth = $dbh->prepare("$sql_query") or croak $dbh->errstr;
    my $rv  = $sth->execute;
    unless( $rv ) {
        $log->printStack();
        $log->error( "DBI ERR:\n" . $dbh->errstr . "\nSQL: $sql_query" );
        $available = qq%--- NOT AVAILABLE ! ---\n%;
    } else {

        while (my @row = $sth->fetchrow_array) {
            if ($selected_options{$row[0]}) {
                delete($selected_options{$row[0]});
                $selected .= qq!<div id="draggable_$row[0]" class="draggable">$row[1]</div>\n!;
            } else {
              $available .= qq!<div id="draggable_$row[0]" class="draggable">$row[1]</div>\n!;
            }
        } # end while
    } # end else

    $sth->finish;
    #### Look through the list of requested id's and delete any that
    #### weren't in the list of available options
    my @valid_options = ();
    my $invalid_option_present = 0;
    foreach my $id (@tmp) {
      if ($selected_options{$id}) {
        $invalid_option_present = 1;
      } else {
        push(@valid_options,$id);
      }
    }
    #### If there were some invalid options, then append the list of valid
    #### ones.  This is an ugly hack. FIXME
    if ($invalid_option_present) {
      $available .= "<!--".join(',',@valid_options)."-->\n";
    }
    return $available, $selected;

}

###############################################################################

sub buildDraggables {
  my $self = shift;
  my $sql_query = shift;

  my $sbeams = $self->getSBEAMS();
  #### Get the database handle
  $dbh = $sbeams->getDBHandle();

  #### Convert the SQL dialect if necessary
  $sql_query = $sbeams->translateSQL(sql=>$sql_query);

  ##for debugging:
  #$sbeams->display_sql(sql=>$sql_query);

  my $draggables = '';
  my $sth = $dbh->prepare("$sql_query") or croak $dbh->errstr;
  my $rv  = $sth->execute;
  unless( $rv ) {
      $log->printStack();
      $log->error( "DBI ERR:\n" . $dbh->errstr . "\nSQL: $sql_query" );
      $draggables = qq%--- DRAGGABLES MALFUNCTION ---%;
  } else {
      while (my @row = $sth->fetchrow_array) {
        $draggables .= "new Draggable('draggable_$row[0]', {});\n";
      } # end while
  } # end else

  $sth->finish;

  return $draggables;
}

###############################################################################

1;

__END__
###############################################################################
###############################################################################
###############################################################################
