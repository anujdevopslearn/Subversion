package SBEAMS::Connection::GenericXMLImporter;

###############################################################################
# Program     : SBEAMS::Connection::GenericXMLImporter
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::Connection module which attempts
#               to load arbitrary XML into matching relational tables.
#
# SBEAMS is Copyright (C) 2000-2002 by Eric Deutsch
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################

  use strict;
  use XML::Parser;
  use LWP::UserAgent;
  use FindBin;

  use vars qw($VERSION @ISA);
  use vars qw(@stack %datamodel $PARSEMODE %element_state $sbeams $DATABASE
              $VERBOSE $TESTONLY);

  @ISA = ();
  $VERSION = '0.1';

  require "$FindBin::Bin/generate_schema.pllib";



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
# createDataModel
###############################################################################
sub createDataModel {
  my $SUB_NAME = 'createDataModel';
  my $self = shift || die("$SUB_NAME: Parameter self not passed");
  my %args = @_;

  my $source_file = $args{'source_file'} || '';
  my $verbose = $args{'verbose'} || 0;
  my $schema_file = $args{'schema_file'}
    || die "schema_file not passed";
  my $destination_type = $args{'destination_type'}
    || die "destination_type not passed";


  #### Return if no source file name was supplied
  unless ($source_file) {
    print "$SUB_NAME: Error: Parameter source_file not passed\n" if ($verbose);
    return 0;
  }


  #### Return if file does not exist
  unless (-e $source_file) {
    print "$SUB_NAME: Error: File '$source_file' not found\n";
    return 0;
  }


  #### Open the file
  unless (open(INFILE,$source_file)) {
    print "$SUB_NAME: Error: Unable to open file '$source_file'\n";
    return 0;
  }



  #### If the schema file already exists, try to start from that
	my $modelfile = "${schema_file}_MODEL.pldump";
	my $have_previous_model = 0;
  if (-e $modelfile) {
    print "Found a previous model file.  Extending that with current file\n";
	  $have_previous_model = 1;

		#### Open the file
		unless (open(MODELFILE,$modelfile)) {
			print "$SUB_NAME: Error: Unable to open file '$modelfile'\n";
			return 0;
		}

    my $indata = "";
    while (<MODELFILE>) { $indata .= $_; }
    close(MODELFILE);
    #### eval the dump
    my $VAR1;
    eval $indata;
    %datamodel = %{$VAR1};

	#### Else set up a fresh model
  } else {
		$datamodel{first_tag} = '';
		$datamodel{entities} = {};
  }

  $PARSEMODE = 'LEARN';


  #### Set up the XML parser and parse the returned XML
  my $parser = new XML::Parser(
			       Handlers => {
					    Start => \&start_element,
					    End => \&end_element,
					    Char => \&characters,
					   }
			      );
  $parser->parse(*INFILE,ProtocolEncoding => 'ISO-8859-1');


  #### Close file
  close(INFILE);


  #### If verbose mode, print out everything we gathered
  if ($verbose) {
    while (my ($key,$value) = each %datamodel) {
      print "$key=$value=\n";
    }
  }
  print "\n";


  #### For all entities that have no children, turn them into attributes
  while (my ($key,$value) = each %{$datamodel{entities}}) {

    #### If the entity as no children or attributes of its own
    unless ( (defined($value->{has_children}) && %{$value->{has_children}}) ||
             (defined($value->{attributes}) && %{$value->{attributes}}) ) {

      #### Loop over all its parents
      while (my ($key2,$value2) = each %{$value->{has_parents}}) {

  	#### If this entity appears multiple times, this cannot be turned
  	#### into an attribute and, in fact, some fanciness needs to be
  	#### written here and elsewhere to handle this case
  	if (defined($datamodel{entities}->{$key2}->{has_children}->
                    {$key}->{max_count}) &&
  	    $datamodel{entities}->{$key2}->{has_children}->
              {$key}->{max_count} > 1) {
  	  print "WARNING: entity $key2 has child $key which itself has no ".
            "children, but yet appears multiple times so cannot be an ".
            "attribute.  Need special code to turn this into a table! ".
            "For now, duplicate entries will be overwritten!!!!!\n\n";
        }

        #### Create this element as an attribute and record its maximum
        #### length
        $datamodel{entities}->{$key2}->{attributes}->{$key}->{length} =
          $value->{length};
        #### Remove his element as a child of this parent
        delete($datamodel{entities}->{$key2}->{has_children}->{$key});
      }
      #### Remove this element as an entity; it's now an attribute
      delete($datamodel{entities}->{$key});

    #### Otherwise, check to see if there's data for this entity, and if
    #### so, create an attribute with its name to store the data
    } else {
      if (defined($value->{length}) && $value->{length} > 0) {
        $value->{attributes}->{$key}->{length} = $value->{length};
      }
    }

  }


  #### Create a single parent table xml_import
  if ($have_previous_model == 0 &&
			defined($datamodel{entities}->{xml_import})) {
    print "ERROR: There is a tag called xml_import and I can't handle that\n";
    exit;
  }

  $datamodel{entities}->{xml_import}->{attributes}->{source_file}->
    {length} = 255;
  $datamodel{entities}->{xml_import}->{attributes}->{source_file_date}->
    {type} = 'datetime';
  $datamodel{entities}->{xml_import}->{attributes}->{import_date}->
    {type} = 'datetime';
  $datamodel{entities}->{xml_import}->{count} = 1;


  #### For all entities that have no parents, set xml_import as parent
  while (my ($key,$value) = each %{$datamodel{entities}}) {

    #### If the entity as no parents, give it one
    unless (defined($value->{has_parents})) {

      #### Unless it's xml_import itself
      unless ($key eq 'xml_import') {
        $datamodel{entities}->{$key}->{has_parents}->{xml_import} = 1;
        #### FIXME The following might be a lie!  I'm not certain if
        #### well-formed xml can have > 1, but it could happen
        $datamodel{entities}->{xml_import}->{has_children}->{$key}->
          {max_count} = 1;
      }

    }

  }


  #### For all entities create table_property and table_column
  my $table_properties;
  $table_properties->{__ordered_list} = [ ];
  my $table_column;
  while (my ($key,$value) = each %{$datamodel{entities}}) {

    my $table_name = $key;
    my $index = 1;

    #### Define the PK column and ake sure it's not already there
    my $PKcolumn = "${table_name}_pk";
    if (defined($value->{attributes}->{$PKcolumn})) {
      print "ERROR: There is already a column '$PKcolumn'\n\n";
      exit;
    }

    #### Make sure there's only one parent
    if (defined($value->{has_parents}) &&
        scalar(keys %{$value->{has_parents}}) > 1) {
      print "ERROR: There multiple parents for '$key'  I cannot handle ".
        "this condition yet.  Need more programmers.\n\n";
      #exit;
    }


    push(@{$table_properties->{__ordered_list}},$table_name);
    my %data1 = (
      table_name => $table_name,
      category => $table_name,
      real_name => $table_name,
    );
    $table_properties->{$table_name} = \%data1;


    $table_column->{$table_name}->{__ordered_list} = [ $PKcolumn ];
    my @data2 = ( $table_name,$index,$PKcolumn,$PKcolumn,
      "int","4","0","N","","Y","","","","",
      "","","N","N","N","Primary Key","","" );
    $table_column->{$table_name}->{$PKcolumn} = \@data2;


    #### If it has a parent, add a fk column
    if (defined($value->{has_parents})) {
      my $n_parents = scalar(keys(%{$value->{has_parents}}));
      while (my ($key2,$value2) = each %{$value->{has_parents}}) {
        my $FKcolumn = "${key2}_fk";
        my $nullable = 'N';
        $nullable = 'Y' if ($n_parents > 1);
    	push(@{$table_column->{$table_name}->{__ordered_list}},$FKcolumn);
    	my @data2 = ( $table_name,$index,$FKcolumn,$FKcolumn,
    	  "int","4","0",$nullable,"","N",$key2,"${key2}_pk","","",
    	  "","","Y","Y","N","Foreign Key to $key2","","" );
    	$table_column->{$table_name}->{$FKcolumn} = \@data2;
      }
    }



    #### Loop over all its attributes, creating columns
    while (my ($key2,$value2) = each %{$value->{attributes}}) {
      my $column_name = $key2;
      #$column_name =~ s/\W//g;
      push(@{$table_column->{$table_name}->{__ordered_list}},$column_name);

      #### Set default type and length
      my $type = 'varchar';
      my $scale = $value2->{length} || 4;
      if (defined($value2->{type})) {
        $type = $value2->{type};
        $scale = 8 if ($type eq 'datetime');
      }
      if ($type eq 'varchar' && $scale > 1024) {
	$type = 'text';
	$scale = 16;
      }


      my @data = ( $table_name,$index,$column_name,$column_name,
        $type,$scale,"0","Y","","N","","","N","text",
        "50","","Y","Y","N",$column_name,"","" );
      $table_column->{$table_name}->{$column_name} = \@data;

    }
    $index++;

  }



  #### Generate the schema based on the input data
  print "Generating schema for $destination_type\n";
  writeSchema(
    table_properties => $table_properties,
    table_columns => $table_column,
    schema_file => $schema_file,
    destination_type => $destination_type,
  );

  print "Done.\n\n";


  #### Write out the data model for later use
  my $outfile = "${schema_file}_MODEL.pldump";
  open(OUTFILE,">$outfile") || die "Cannot open $outfile\n";
  printf OUTFILE Data::Dumper->Dump( [\%datamodel] );
  close(OUTFILE);


  #### If verbose mode, print out everything we gathered
  if ($verbose && 1) {
    while (my ($key,$value) = each %{$datamodel{entities}}) {
      print "$key (".$value->{count}." instances)\n";

      #### Print out parent information:
      if (defined($value->{has_parents})) {
        print "  Parents: ".join(",",keys(%{$value->{has_parents}}))."\n";
      } else {
        print "  NO PARENTS!\n";
      }

      #### Print out children information:
      if (defined($value->{has_children}) && %{$value->{has_children}}) {
        my @children = ();
        while ( my ($childname,$childhash) = each %{$value->{has_children}}) {
          my $tmp = $childname;
          if (defined($childhash->{max_count})) {
            $tmp .= "(".$childhash->{max_count}."x)";
          }
          push(@children,$tmp);
        }
        print "  Children: ".join(",",@children)."\n";
      } else {
        print "  NO CHILDREN!\n";
      }

      #### Print out attribute information:
      if (defined($value->{attributes})) {
        print "  Attributes: ";
        while (my ($key2,$value2) = each %{$value->{attributes}}) {
          print "$key2(".$value2->{length}."),";
        }
        print "\n";
      } else {
        print "  No attributes\n";
      }

      print "\n";
    }
  }



  return \%datamodel;

}


###############################################################################
# insertData
###############################################################################
sub insertData {
  my $SUB_NAME = 'insertData';
  my $self = shift || die("$SUB_NAME: Parameter self not passed");
  my %args = @_;

  my $source_file = $args{'source_file'} || '';
  my $schema_file = $args{'schema_file'}
    || die "schema_file not passed";
  my $db_connection = $args{'db_connection'}
    || die "db_connection not passed";
  $sbeams = $db_connection;
  $VERBOSE = $args{'verbose'} || 0;
  $TESTONLY = $args{'testonly'} || 0;
  $DATABASE = $args{'database_prefix'} || '';


  #### Return if no source file name was supplied
  unless ($source_file) {
    print "$SUB_NAME: Error: Parameter source_file not passed\n" if ($VERBOSE);
    return 0;
  }


  #### Return if file does not exist
  unless (-e $source_file) {
    print "$SUB_NAME: Error: File '$source_file' not found\n";
    return 0;
  }


  #### Open the file
  unless (open(INFILE,$source_file)) {
    print "$SUB_NAME: Error: Unable to open file '$source_file'\n";
    return 0;
  }


  #### If the data model is not in memory, try to read it from disk
  unless ($datamodel{entities}) {
    my $modelfile = "${schema_file}_MODEL.pldump";
    open(MODELFILE,"$modelfile") || die "Cannot open $modelfile\n";
    my $indata = "";
    while (<MODELFILE>) { $indata .= $_; }
    close(MODELFILE);
    #### eval the dump
    my $VAR1;
    eval $indata;
    %datamodel = %{$VAR1};
  }
  $PARSEMODE = 'INSERT';


#print Data::Dumper->Dump( [\%datamodel] );
#print "datamodel=".%datamodel."\n";
#while (my ($key2,$value2) = each %datamodel) {
#  print "  $key2=$value2\n";
#}
#print "PubmedArticleSet=".$datamodel{PubmedArticleSet}."\n";
#exit;


  #### Insert a record for this load
  my %rowdata = (
    source_file => $source_file,
    import_date => '2003-06-01',
  );
  my $returned_PK = $sbeams->updateOrInsertRow(
    insert=>1,
    table_name=>"${DATABASE}xml_import",
    rowdata_ref=>\%rowdata,
    PK_name=>'xml_import_pk',
    return_PK=>1,
    verbose=>$VERBOSE,
    testonly=>$TESTONLY,
  );

  #### Verify that the PK came back
  if ($returned_PK) {
    $element_state{xml_import}->{PK_value} = $returned_PK;
  } else {
     die("ERROR: Unable to get PK from database\n");
  }


  #### Set up the XML parser and parse the returned XML
  my $parser = new XML::Parser(
			       Handlers => {
					    Start => \&start_element,
					    End => \&end_element,
					    Char => \&characters,
					   }
			      );
  $parser->parse(*INFILE,ProtocolEncoding => 'ISO-8859-1');


  #### Close file
  close(INFILE);

  return;

}



###############################################################################
# start_element
#
# Internal SAX callback function to start tags
###############################################################################
sub start_element {
  my $handler = shift;
  my $element = shift;
  my %attrs = @_;

  #### Get the previous element on the stack
  my $context = $handler->{Context}->[-1];
  #print "start_element<$element>\n";
  #print ".";

  #### Fix any problems with the tags
  $element = fix_tag($element);
  $context = fix_tag($context);


  foreach my $key (keys(%attrs)) {
    my $newkey = $key;
    $newkey = fix_tag($newkey);
    if ($key ne $newkey) {
      $attrs{$newkey} = $attrs{$key};
      delete($attrs{$key});
    }
  }

  #### Push this element name onto a stack for later possible use
  push(@stack,$element);


  #### If we're in Learn mode, just collect information about the XML
  if ($PARSEMODE eq 'LEARN') {

    #### If this is the first element set it
    unless ($datamodel{first_tag}) {
      $datamodel{first_tag} = $element;
    }


    #### See if this element already has been seen
    if ($datamodel{entities}->{$element}) {
      $datamodel{entities}->{$element}->{count}++;

    #### Otherwise, add it to the list
    } else {
      $datamodel{entities}->{$element}->{count} = 1;
    }


    #### Store parental and child information information
    if ($context) {
      $datamodel{entities}->{$element}->{has_parents}->{$context} = 1;

      if (defined($datamodel{entities}->{$context}->{has_children}->
          {$element}->{current_count})) {
        $datamodel{entities}->{$context}->{has_children}->{$element}->
          {current_count}++;
      } else {
        $datamodel{entities}->{$context}->{has_children}->{$element}->
          {current_count} = 1;
      }
    }


    #### Initialize a string storage area to put a CDATA string
    $datamodel{entities}->{$element}->{CDATA} = '';


    #### Store attribute information
    if (%attrs) {
      while (my ($key,$value) = each %attrs) {
        if (defined($datamodel{entities}->{$element}->{attributes}->{$key})) {
          if (length($value) >
              $datamodel{entities}->{$element}->{attributes}->{$key}->
                {length}) {
            $datamodel{entities}->{$element}->{attributes}->{$key}->{length} =
              length($value);
          }

        } else {
          $datamodel{entities}->{$element}->{attributes}->{$key}->{length} =
            length($value);
        }
      }
    }

  }


  #### If Parse Mode is INSERT then actually INSERT data
  if ($PARSEMODE eq 'INSERT') {

    #### If there's no context, then set it to xml_import
    $context = 'xml_import' unless ($context);


    #### If this is element corresponds to a table
    if (defined($datamodel{entities}->{$element})) {
      my $PK_column_name = "${element}_pk";
      my $PK_value;

      #### Create the row data
      my %rowdata = %attrs;
      if ($datamodel{entities}->{$element}->{has_parents}) {
        die("ERROR: No context where there should be!") unless ($context);
        my $parent_PK = "${context}_fk";
        my $parent_PK_value = $element_state{$context}->{PK_value};
        $rowdata{$parent_PK} = $parent_PK_value;
      }

      #### INSERT the data
      my $returned_PK;
      my $insert = 1;
      my $update = 0;
      if ($insert + $update > 0) {
  	$returned_PK = $sbeams->updateOrInsertRow(
  	  insert=>$insert,
  	  update=>$update,
  	  table_name=>"${DATABASE}$element",
  	  rowdata_ref=>\%rowdata,
  	  PK_name=>$PK_column_name,
  	  PK_value=>$PK_value,
  	  return_PK=>1,
  	  verbose=>$VERBOSE,
  	  testonly=>$TESTONLY,
  	);
        print ".";

        #### Verify that the PK came back
        if ($returned_PK) {
          #print "INFO: Received PK $returned_PK back from database\n";
          $element_state{$element}->{PK_value} = $returned_PK;
        } else {
           die("ERROR: Unable to get PK from database\n");
        }

      }

    #### Otherwise if this element is really a tagged attribute
    } elsif (defined($datamodel{entities}->{$context}->{attributes}
             ->{$element})) {

      #### Add this entity as an attribute of its parent
      #### Although unfortunately we don't know the value yet
      $element_state{$context}->{needs_update} = 1;
      $element_state{$context}->{attributes}->{$element} = '';


    #### Otherwise the data model and the file don't match
    } else {
      die("Don't know what to do with element '$element'");
    }

  }


  return;

}



###############################################################################
# end_element
#
# Internal SAX callback function to end tags
###############################################################################
sub end_element {
  my $handler = shift;
  my $element = shift;

  my $context = $handler->{Context}->[-1];
  #### Fix any problems with the tags
  $element = fix_tag($element);
  $context = fix_tag($context);

  #### Just pop the top item off the stack.  It should be the current
  #### element, but we lazily don't check
  pop(@stack);

  #### If we're in Learn mode, just collect information about the XML
  if ($PARSEMODE eq 'LEARN') {

    #### Make the total length of the CDATA for this entity the maxlength
    my $len = length($datamodel{entities}->{$element}->{CDATA});
    delete($datamodel{entities}->{$element}->{CDATA});
    if (defined($datamodel{entities}->{$element}->{length})) {
      if ($len > $datamodel{entities}->{$element}->{length}) {
        $datamodel{entities}->{$element}->{length} = $len;
      }
    } else {
      $datamodel{entities}->{$element}->{length} = $len;
    }

    #### Update the information about the number of times each child appears
    while ( my ($child,$childhash) = each %{$datamodel{entities}->{$element}->
                                       {has_children}} ) {
      if (defined($childhash->{current_count})) {
  	my $this_count = $childhash->{current_count};
  	if (defined($childhash->{max_count})) {
  	  if ($this_count > $childhash->{max_count}) {
  	    $childhash->{max_count} = $this_count;
  	  }
  	} else {
  	  $childhash->{max_count} = $this_count;
  	}

        delete($childhash->{current_count});
      }

    }

  }

  #### If Parse Mode is INSERT then see if there's a need to UPDATE
  if ($PARSEMODE eq 'INSERT') {

    if (defined($element_state{$element}->{needs_update})) {

        my $PK_column_name = "${element}_pk";
        my $PK_value = $element_state{$element}->{PK_value};
        my %rowdata = %{$element_state{$element}->{attributes}};

  	my $result = $sbeams->updateOrInsertRow(
  	  update=>1,
  	  table_name=>"${DATABASE}$element",
  	  rowdata_ref=>\%rowdata,
  	  PK_name=>$PK_column_name,
  	  PK_value=>$PK_value,
  	  verbose=>$VERBOSE,
  	  testonly=>$TESTONLY,
  	);

    }

    delete($element_state{$element});

  }


  return;

}



###############################################################################
# characters
#
# Internal SAX callback function to handle character data between tags
###############################################################################
sub characters {
  my $handler = shift;
  my $string = shift;

  my $context = $handler->{Context}->[-1];

  #### Fix any problems with the tags
  $context = fix_tag($context);


  #### If we're in Learn mode, just collect information about the XML
  if ($PARSEMODE eq 'LEARN') {

    #### Strip off leading and trailing whitespace. FIXME Thi should be Opt
    $string =~ s/^\s+//;
    $string =~ s/\s+$//;

    #### Add the current string to the bin
    #### Note that some XML parsers return the CDATA line by line instead
    #### of one huge chunk
    if ($string gt '') {
      $datamodel{entities}->{$context}->{CDATA} .= $string;
    }

    # DEBUGGING
    #if ($context eq 'ENTRY') {
    #  print "string=$string=\n";
    #}

  }


  #### If Parse Mode is INSERT then store the character data
  if ($PARSEMODE eq 'INSERT') {

    #### If this is element corresponds to a table
    if (defined($datamodel{entities}->{$context})) {

      #### For those wanting to make life very difficult, it's possible
      #### that there is both CDATA and child elements.  Try to handle
      #### with the assumption that there's attribute with the element name
      unless ($string =~ /^\s*$/) {
        #print "ERROR: Expected empty space but got CDATA '$string' ".
        #  "instead!!\n";
        #die("  Rats!");

  	#### Strip off leading and trailing whitespace. FIXME Thi should be Opt
  	$string =~ s/^\s+//;
  	$string =~ s/\s+$//;

  	#### Store this information for later inserting
  	$element_state{$context}->{needs_update} = 1;
        if (defined($element_state{$context}->{attributes}->{$context})) {
    	  $element_state{$context}->{attributes}->{$context} .= $string;
	} else {
    	  $element_state{$context}->{attributes}->{$context} = $string;
	}
      }


    #### Otherwise this is attribute data and must be stored as attribute
    } else {

      #### Get this element's parent which is assumed to be the table
      #### which has attribute of element
      my $parent_context = $handler->{Context}->[-2];
      $parent_context = fix_tag($parent_context);

      unless ($parent_context) {
        die("ERROR: Unable to find element's parent.  This violates ".
            "an assumption.");
      }

      #### Strip off leading and trailing whitespace. FIXME Thi should be Opt
      $string =~ s/^\s+//;
      $string =~ s/\s+$//;

      #### Store this information for later inserting
      $element_state{$parent_context}->{needs_update} = 1;
      $element_state{$parent_context}->{attributes}->{$context} .= $string;

    }


  }


}



###############################################################################
# fix_tag
#
# A hack routine to fix strange tags into something different
###############################################################################
sub fix_tag {
  my $tag = shift;

  #### Strip out and funky characters
  $tag =~ s/\W//g;

  $tag = "identity_value" if ($tag eq "identity");
  $tag = "begin_loc" if ($tag eq "begin");
  $tag = "end_loc" if ($tag eq "end");
  $tag = "ENTRY_A" if ($tag eq "ENTRY");

  $tag = "goes_from" if ($tag eq "from");
  $tag = "goes_to" if ($tag eq "to");
  $tag = "alter_value" if ($tag eq "alter");

  return $tag;

}




###############################################################################

1;

__END__

###############################################################################
###############################################################################
###############################################################################

=head1 SBEAMS::Connection::GenericXMLImporter

SBEAMS module for importing arbitraty XML into a relational database.
There are methods for generating a database schema automatically by
examinging the XML file and also loading the XML into that schema.

=head2 SYNOPSIS

      use SBEAMS::Connection::GenericXMLImporter;
      my $importer = new SBEAMS::Connection::GenericXMLImporter;

      #### Create the database schema
      my $result = $importer->createDataModel(
        source_file => "example.xml",
        schema_file => "example",
        destination_type => "mssql",
      );

      #### Still need to create database and tables manually using the
      #### files just written example_CREATETABLES.mssql, etc.

      #### Load the XML data into the database
      my $result = $importer->insertData(
        source_file => "example.xml",
        schema_file => "example",
  	db_connection => $sbeams,
  	database_prefix => "testdb.dbo.",
      );


=head2 DESCRIPTION

This module provides a set of methods for importing arbitrary XML into
a relational database.  The createDataModel() method reads through an
XML file and generates a relational data model based on what it finds in
the XML file.  The insertData() method then inserts all the data from the
XML file into the database using standard SBEAMS tools.


=head2 METHODS

=over

=item * B<createDataModel( see key value input parameters below )>

    Given an XML file, generate a relational schema capable of holding
    the data.

    INPUT PARAMETERS:

      source_file => Name of the xml file to import

      schema_file => a file root after which "_CREATETABLE.sql", et al.
      are added.

      destination_type => Type of database to generate DDL for (e.g.,
      mysql, mssql, pgsql, oracle, etc.)

      verbose => Set to TRUE to print error, warning, and diagnostic
      information

    OUTPUT:

      Returns ?

      Several files "_CREATETABLES.sql", "_CREATECONSTRAINTS.sql", etc.
      are written.  These allow the users to easilt create the database
      structure before loading.


=item * B<insertData( $url )>

    Give an XML file, intsert all the data from it into a schema that
    corresponds to the XML structure

    INPUT PARAMETERS:

      source_file => Name of the xml file to import

      schema_file => a file root after which "_CREATETABLE.sql", et al.
      are expeced to be found.

      db_connection => An SBEAMS connection object to which the data
      can be sent to the RDBMS

      database_prefix => A database prefix to be appended before the
      entity/table names, e.g. "databasename.schemaname."

      verbose => Set to TRUE to print error, warning, and diagnostic
      information.

      verbose => Set to TRUE to generate all the SQL statements, but not
      actually send them to the RDBMS.

    OUTPUT:

      Returns ?

      All the data in XML file is written to the RDBMS.


=back

=head2 BUGS

There are several known deficiencies:

1) This program cannot yet handle entities existing under different
parent entities. For example, if the <PERSON> entity can be found under
both the <DEPARTMENT> entity and the <BOARD> entity (and <PERSON> is
an entity with attributes or subentities), this program will halt and
be unable to continue.  Modeling this type of relationship will require
a little for more on this program.

2) CREATE TABLE, etc. statements are written to a file but not sent to
the database.  This functionality should be added.

Please send bug reports to the author

=head2 AUTHOR

Eric Deutsch <edeutsch@systemsbiology.org>

=head2 SEE ALSO

SBEAMS::Connection

=cut

