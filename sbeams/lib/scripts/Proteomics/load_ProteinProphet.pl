#!/usr/local/bin/perl

###############################################################################
# Program     : load_ProteinProphet.pl
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This script loads a ProteinProphet XML file into the database
#
# SBEAMS is Copyright (C) 2000-2002 by Eric Deutsch
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################

use strict;
use Getopt::Long;
use XML::Xerces;
use FindBin;
use lib "$FindBin::Bin/../../perl";
#use lib '/home/deutsch/eric/isb/sbeams/v2/sbeams/lib/perl';

use vars qw ($sbeams $sbeamsMOD $q
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG $TESTONLY
             $DATABASE $current_contact_id $current_username
            );

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TableInfo;

$sbeams = new SBEAMS::Connection;


###############################################################################
# Read and validate command line args
###############################################################################
my $VERSION = q[$Id$ ];
$PROG_NAME = $FindBin::Script;
my $USAGE = <<EOU;
USAGE: $PROG_NAME [OPTIONS] source_file
Options:
  --verbose n         Set verbosity level.  default is 0
  --quiet             Set flag to print nothing at all except errors
                      This masks the printing of progress information
  --debug n           Set debug level.  default is 0
  --testonly          If set, nothing is actually inserted into the database,
                      but we just go through all the motions.  Use --verbose
                      to see all the SQL statements that would occur
  --validate=XXXXX    XML validation scheme [always | never | auto]
  --namespaces        Enable namespace processing. Defaults to off.
  --schemas           Enable schema processing. Defaults to off.
  --biosequence_set_tag XXXXX  (required)
                      Provide the biosequence_set_tag to which this
                      data file should be associated
  --search_batch_id n Provide the search_batch_id to which these
                      data should be associated
  --delete_existing   If there is already data for this search_batch_id,
                      try to delete it and then load instead of giving up
  --purge_protein_summary_id nnn
                      Purges protein_summary_id nnn without loading anything

 e.g.:  $PROG_NAME --verbose 2 --testonly --bio HuNCI ProteinProphet.xml

EOU


#### If no parameters are given, print usage information
unless ($ARGV[0]){
  print "$USAGE";
  exit;
}


#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","debug:s","testonly",
  "validate=s","namespaces","schemas",
  "biosequence_set_tag:s","search_batch_id:s","delete_existing",
  "purge_protein_summary_id:i",
  )) {
  print "$USAGE";
  exit;
}

$VERBOSE = $OPTIONS{"verbose"} || 0;
$QUIET = $OPTIONS{"quiet"} || 0;
$DEBUG = $OPTIONS{"debug"} || 0;
$TESTONLY = $OPTIONS{"testonly"} || 0;
if ($DEBUG) {
  print "Options settings:\n";
  print "  VERBOSE = $VERBOSE\n";
  print "  QUIET = $QUIET\n";
  print "  DEBUG = $DEBUG\n";
  print "  TESTONLY = $TESTONLY\n";
}


#### Get the search_batch_id parameter
my $search_batch_id = $OPTIONS{search_batch_id} || '';
my $delete_existing = $OPTIONS{delete_existing} || '';
my $purge_protein_summary_id = $OPTIONS{purge_protein_summary_id} || '';


#### Set the $DATABASE name
my $module = 'Proteomics';
$DATABASE = $DBPREFIX{$module};


#### Get the source_file from the command line
my $source_file = $ARGV[0];

#### If it was not provided
unless ($source_file) {

  if ($search_batch_id) {
    $source_file = guess_source_file(
      search_batch_id => $search_batch_id,
    );
  }

  unless ($source_file || $purge_protein_summary_id) {
    print "$USAGE";
    exit 0;
  }
}


#### Process program-specific options
my $biosequence_set_tag = $OPTIONS{biosequence_set_tag} || '';
#unless ($biosequence_set_tag || $purge_protein_summary_id) {
#  print "ERROR: You must provide the --biosequence_set_tag option";
#  print "$USAGE";
#  exit 0;
#}


#### Check to make sure the file exists
unless (-f $source_file || $purge_protein_summary_id) {
  die "File '$source_file' does not exist!\n";
}


#### Process parser options
my $validate = $OPTIONS{validate} || 'auto';
my $namespace = $OPTIONS{namespaces} || 0;
my $schema = $OPTIONS{schemas} || 0;


if (uc($validate) eq 'ALWAYS') {
  $validate = $XML::Xerces::SAX2XMLReader::Val_Always;
} elsif (uc($validate) eq 'NEVER') {
  $validate = $XML::Xerces::SAX2XMLReader::Val_Never;
} elsif (uc($validate) eq 'AUTO') {
  $validate = $XML::Xerces::SAX2XMLReader::Val_Auto;
} else {
  die("Unknown value for -v: $validate\n$USAGE");
}


#### main package continues below after MyContentHandler package



###############################################################################
###############################################################################
###############################################################################
# MyContentHandler package: SAX parser callback routines
#
# This MyContentHandler package defines all the content handling callback
# subroutines used the SAX parser
###############################################################################
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
  my $class = shift;
  my $self = $class->SUPER::new();
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
# start_element
###############################################################################
sub start_element {
  my ($self,$uri,$localname,$qname,$attrs) = @_;

  #### Make a hash to of the attributes
  my %attrs = $attrs->to_hash();

  #### Convert all the values from hashref to single value
  while (my ($aa1,$aa2) = each (%attrs)) {
    $attrs{$aa1} = $attrs{$aa1}->{value};
  }


  #### Set the legal elements to process generically
  my %regular_elements = (
    protein_summary => 1,
    protein_summary_header => 1,
    protein_summary_data_filter => 1,
    nsp_information => 1,
    nsp_distribution => 1,
    protein_group => 1,
    protein => 1,
    indistinguishable_protein => 1,
    peptide => 1,
    peptide_parent_protein => 1,
    indistinguishable_peptide => 1,
    ASAPRatio => 'summary_quantitation',
  );


  #### Define the parent IDs
  my %parent_ids = (
    protein_summary => '',
    protein_summary_header => 'protein_summary_id',
    protein_summary_data_filter => 'protein_summary_header_id',
    nsp_information => 'protein_summary_header_id',
    nsp_distribution => 'nsp_information_id',
    protein_group => 'protein_summary_id',
    protein => 'protein_group_id',
    indistinguishable_protein => 'protein_id',
    peptide => 'protein_id',
    peptide_parent_protein => 'peptide_id',
    indistinguishable_peptide => 'peptide_id',
    ASAPRatio => '',
  );


  #### Define some variables we'll need to see later
  my $PK;


  #### Process the regular elements
  if ($regular_elements{$localname}) {
    print "\n<$localname>\n" if ($VERBOSE > 0);


    #### If this element has a parent, get its key
    if ($parent_ids{$localname}) {
      my $parent_key = $self->{id_cache}->{$parent_ids{$localname}};
      unless ($parent_key) {
        die("INTERNAL ERROR: Unable to get parental key '".
          $parent_ids{$localname}."' while processing '$localname'.");
      }
      $attrs{$parent_ids{$localname}} = $parent_key;
    }


    #### If there's a biosequence_name attribute, also get the biosequence_id
    if ($attrs{protein_name}) {

      my $biosequence_id = $self->{biosequence_ids}->{$attrs{protein_name}};
      if (defined($biosequence_id) && $biosequence_id > 0) {
        $attrs{biosequence_id} = $biosequence_id;
      } else {
        print "WARNING: Unable to determine biosequence_id for protein_name '".
          $attrs{protein_name}."'\n";
        $attrs{biosequence_id} = 0;
        #die("bummer");
      }
    }


    #### Since someone changes the XML format regularly without telling
    #### anyone else, provide a facility to kill some attributes while trying
    #### to load
    my %attrs_to_drop = (
      group_sibling_id => 1,
      unique_stripped_peptides => 1,
      is_contributing_evidence => 1,
      source_files_alt => 1,
      run_options => 1,
      output_file => 1,
      num_input_1_spectra => 1,
      num_input_2_spectra => 1,
      num_input_3_spectra => 1,
      num_predicted_correct_prots => 1,
      initial_min_peptide_prob => 1,
      initial_peptide_wt_iters => 1,
      final_peptide_wt_iters => 1,
      nsp_distribution_iters => 1,
      source_file_xtn => 1,
      predicted_num_correct => 1,
      predicted_num_incorrect => 1,
      total_number_peptides => 1,
      index => 1,
      organism => 1,
      alt_pos_to_neg_ratio => 1,
      pound_subst_peptide_sequence => 1,
      adj_ratio_mean => 1,
      status => 1,
      decimal_pvalue => 1,
      pvalue => 1,
      adj_ratio_standard_dev => 1,
      total_no_spectrum_ids => 1,
      pct_spectrum_ids => 1,
      subsuming_protein_entry => 1,
    );
    foreach my $attr (keys(%attrs_to_drop)) {
      if (exists($attrs{$attr})) {
        print "!";
        delete $attrs{$attr};
      }
    }


    #### If there's a execution_date attribute, then convert format
    if ($attrs{execution_date}) {
      my $date0 = ParseDate($attrs{execution_date});
      if ($date0) {
        $attrs{execution_date} = UnixDate($date0,"%Y-%m-%d %H:%M:%S");
      }
    }


    #### If this is the nsp_distribution object, fix any "inf" attributes
    if ($localname eq 'nsp_distribution') {
      while ( my ($k,$v) = each %attrs ) {
        $attrs{$k} = 1e35 if ($v eq 'inf');
      }
    }


    #### Determine the table name into which the data go
    my $table_name = $localname;
    if ($regular_elements{$localname} gt '1') {
      $table_name = $regular_elements{$localname};
    }


    #### Store the attributes in the table
    $PK = main::insert_attrs(
      table_name=>$table_name,
      attrs_ref=>\%attrs,
      PK=>"${table_name}_id",
      return_PK=>1,
    );

    #### Store the returned PK
    $self->{id_cache}->{"${table_name}_id"} = $PK;


    #### If this is a reverse referring object, then update the parent
    if ($localname eq 'ASAPRatio') {
      my $parent_PK = $self->object_stack->[-1]->{PK_value};

      #### Determine the table name into which the data go
      my $parent_table_name = $self->object_stack->[-1]->{name};
      if ($regular_elements{$parent_table_name} gt '1') {
        $parent_table_name = $regular_elements{$parent_table_name};
      }

      main::update_row(
        table_name=>$parent_table_name,
        attrs_ref=>{"${table_name}_id"=>$PK},
        PK=>"${parent_table_name}_id",
        PK_value=>$self->object_stack->[-1]->{PK_value},
      );
    }


    #### If this is the top object and we have a search_batch_id, add that
    if ($localname eq 'protein_summary') {

      #### If a search_batch was supplied
      if ($self->{search_batch_id}) {
        my $tmp = {
          protein_summary_id=>$PK,
          search_batch_id=>$self->{search_batch_id},
#          comment=>'fix non NULLabilty',
        };
        main::insert_attrs(
          table_name=>'search_batch_protein_summary',
          attrs_ref=>$tmp,
          PK=>"search_batch_protein_summary_id",
        );

      #### Otherwise complain, but go on
      } else {
        print "WARNING: NO search_batch_id was supplied, so this protein ".
          "summary will not be linked to an existing search_batch!!\n";
      }
    }


    #### If this is the start of a new protein, then reset the counter
    #### for the number of peptides
    if ($localname eq 'protein') {
      $self->{n_peptides} = 0;
    }


    #### If this is a pepetide, then update the number of peptides
    if ($localname eq 'peptide') {
      $self->{n_peptides} += $attrs{n_instances};
    }


  #### Otherwise, drop it or confess we don't know what to do
  } else {

    my %ignored_elements = ( annotation => 1 );
    if ($ignored_elements{$localname}) {
      #### Just ignore it
    } else {
      print "\nSKIP: Don't know what to do with <$localname> yet\n";
    }

  }


  #### Push information about this element onto the stack
  my $tmp;
  $tmp->{name} = $localname;
  $tmp->{PK_value} = $PK;
  push(@{$self->object_stack},$tmp);


  #### Increase the counters and print some progress info
  $self->{counter}++;
  print $self->{counter}."..." if ($self->{counter} % 100 == 0);

}



###############################################################################
# end_element
###############################################################################
sub end_element {
  my ($self,$uri,$localname,$qname) = @_;


  #### If this the end of a protein, update the number of peptides
  if ($localname eq 'protein') {
    main::update_row(
      table_name=>$localname,
      attrs_ref=>{ n_peptides=>$self->{n_peptides} },
      PK=>"${localname}_id",
      PK_value=>$self->object_stack->[-1]->{PK_value},
    );
  }


  #### If there's an object on the stack consider popping it off
  if (scalar @{$self->object_stack()}){

    #### If the top object on the stack is the correct one, pop it off
    #### else die bitterly
    if ($self->object_stack->[-1]->{name} eq "$localname") {
      pop(@{$self->object_stack});
    } else {
      die("STACK ERROR: Wanted to pop off an element fo type '$localname'".
        " but instead we found '".$self->object_stack->[-1]->{name}."'!");
    }

  } else {
    die("STACK ERROR: Wanted to pop off an element of type '$localname'".
        " but instead we found the stack empty!");
  }

}




###############################################################################
###############################################################################
###############################################################################
# continuation of main package
###############################################################################
package main;


#### Do the SBEAMS authentication and exit if a username is not returned
exit unless ($current_username =
    $sbeams->Authenticate(work_group=>'Proteomics_admin'));


#### Print the header, do what the program does, and print footer
$| = 1;
$sbeams->printPageHeader();
main();
$sbeams->printPageFooter();


###############################################################################
# Main part of the script
###############################################################################
sub main {

  #### Print out the header
  unless ($QUIET) {
    $sbeams->printUserContext();
    print "\n";
  }


  #### Set up the Xerces parser
  my $parser = XML::Xerces::XMLReaderFactory::createXMLReader();

  $parser->setFeature("http://xml.org/sax/features/namespaces", $namespace);

  if ($validate eq $XML::Xerces::SAX2XMLReader::Val_Auto) {
    $parser->setFeature("http://xml.org/sax/features/validation", 1);
    $parser->setFeature("http://apache.org/xml/features/validation/dynamic",1);

  } elsif ($validate eq $XML::Xerces::SAX2XMLReader::Val_Never) {
    $parser->setFeature("http://xml.org/sax/features/validation", 0);

  } elsif ($validate eq $XML::Xerces::SAX2XMLReader::Val_Always) {
    $parser->setFeature("http://xml.org/sax/features/validation", 1);
    $parser->setFeature("http://apache.org/xml/features/validation/dynamic",0);
  }

  $parser->setFeature("http://apache.org/xml/features/validation/schema",
    $schema);


  #### Create the error handler and content handler
  my $error_handler = XML::Xerces::PerlErrorHandler->new();
  $parser->setErrorHandler($error_handler);

  my $CONTENT_HANDLER = MyContentHandler->new();
  $parser->setContentHandler($CONTENT_HANDLER);

  $CONTENT_HANDLER->setVerbosity($VERBOSE);
  $CONTENT_HANDLER->{counter} = 0;


  #### If the user asked to purge_protein_summary_id, then do it and return
  if ($purge_protein_summary_id) {
    print "Purging protein_summary_id $purge_protein_summary_id...\n"
      unless ($QUIET);
    deleteProteinSummary(protein_summary_id=>$purge_protein_summary_id);
    print "\n\n" unless ($QUIET);
    return;
  }


  #### Get the biosequence information and put it in the content handler
  my %biosequence_data = get_biosequence_data(
    biosequence_set_tag => $biosequence_set_tag,
    search_batch_id => $search_batch_id,
  );
  $CONTENT_HANDLER->{biosequence_set_id}=$biosequence_data{biosequence_set_id};
  $CONTENT_HANDLER->{biosequence_ids} = $biosequence_data{biosequence_ids};


  #### Put the search_batch_id in the content handler for later use
  $CONTENT_HANDLER->{search_batch_id}=$search_batch_id;

  #### If the user did specify a search_batch_id, make sure there is not
  #### already a record for this search_batch_id
  if ($search_batch_id) {
    my $sql = "
       SELECT search_batch_id
       FROM ${DATABASE}search_batch_protein_summary
       WHERE search_batch_id = '$search_batch_id'
    ";
    my ($existing) = $sbeams->selectOneColumn($sql);
    if ($existing) {
      print "\nWARNING: There is already a protein_summary for this ".
        "search_batch_id.\n";
      if ($delete_existing) {
        print "INFO: Deleting existing data...\n";
	deleteProteinSummary(search_batch_id=>$search_batch_id);

      } else {
        print "  Cannot continue.  Either specify --delete_existing or ".
          "or re-evaluate your command.\n";
        exit;
      }
    }
  }


  #### Process the whole document
  print "INFO: Loading...\n" unless ($QUIET);
  $parser->parse (XML::Xerces::LocalFileInputSource->new($source_file));


  #### Write out information about the objects we've loaded if verbose
  if ($VERBOSE) {
    print "\n-------------------------------------------------\n";
    my ($key,$value);
    my ($key2,$value2);

    print "CONTENT_HANDLER:\n";
    while (($key,$value) = each %{$CONTENT_HANDLER}) {
      print "CONTENT_HANDLER->{$key} = $value:\n";
    }

    print "\n";
    while (($key,$value) = each %{$CONTENT_HANDLER}) {
      print "CONTENT_HANDLER->{$key}\n";

      if ($key eq "ID" or $key eq "UNHANDLED") {
        while (($key2,$value2) = each %{$CONTENT_HANDLER->{$key}}) {
          print "  $key2 = $value2\n";
        }
      } elsif ($key eq "OBJ_STACK") {
        foreach $key2 (@{$CONTENT_HANDLER->{$key}}) {
          print "  $key2\n";
        }
      } elsif ($key eq "biosequence_ids" || $key eq "id_cache" ) {
        my $tmpcnt = 0;
        while (($key2,$value2) = each %{$CONTENT_HANDLER->{$key}}) {
          print "  $key2 = $value2\n";
          $tmpcnt++;
          if ($tmpcnt > 20) {
            print "  etc...\n";
            last;
          }
        }
      } else {
        if (ref($CONTENT_HANDLER->{$key})) {
          foreach $key2 (@{$CONTENT_HANDLER->{$key}}) {
            print "  $key2\n";
          }
        }
      }

    } # end while

  } # end if


  print "\n\n" unless ($QUIET);


} # end main



###############################################################################
###############################################################################
###############################################################################
###############################################################################



###############################################################################
# insert_attrs
###############################################################################
sub insert_attrs {
  my %args = @_;
  my $table_name = $args{'table_name'} || die "ERROR: table_name not passed";
  my $attrs_ref = $args{'attrs_ref'} || die "ERROR: attrs_ref not passed";
  my $PK = $args{'PK'} || "";
  my $return_PK = $args{'return_PK'} || 0;


  my $returned_PK = $sbeams->insert_update_row(
    insert=>1,
    table_name=>"${DATABASE}$table_name",
    rowdata_ref=>$attrs_ref,
    PK=>$PK,
    return_PK=>$return_PK,
    verbose=>$VERBOSE,
    testonly=>$TESTONLY,
  );

  print "-->Returned PK = $returned_PK\n" if ($VERBOSE > 1);
  return $returned_PK;

}



###############################################################################
# update_row
###############################################################################
sub update_row {
  my %args = @_;
  my $table_name = $args{'table_name'} || die "ERROR: table_name not passed";
  my $attrs_ref = $args{'attrs_ref'} || die "ERROR: attrs_ref not passed";
  my $PK_name = $args{'PK'} || die "ERROR: PK_name not passed";
  my $PK_value = $args{'PK_value'} || die "ERROR: PK_value not passed";


  my $result = $sbeams->insert_update_row(
    update=>1,
    table_name=>"${DATABASE}$table_name",
    rowdata_ref=>$attrs_ref,
    PK=>$PK_name,
    PK_value=>$PK_value,
    verbose=>$VERBOSE,
    testonly=>$TESTONLY,
  );


  return $result;

}



###############################################################################
# get_biosequence_data
###############################################################################
sub get_biosequence_data {
  my %args = @_;
  my $biosequence_set_tag = $args{'biosequence_set_tag'};
  my $search_batch_id = $args{'search_batch_id'};


  my ($sql,@biosequence_set_ids);


  #### If a search_batch_id was provided
  if (defined($search_batch_id) && $search_batch_id > 0) {

    #### Query to find the biosequence_set_id for this tag
    $sql = qq~
      SELECT biosequence_set_id
        FROM ${DATABASE}search_batch
       WHERE search_batch_id = '$search_batch_id'
    ~;
    print "$sql\n" if ($VERBOSE);

    @biosequence_set_ids = $sbeams->selectOneColumn($sql);


  #### Else if a biosequence_set_tag was provided
  } elsif ($biosequence_set_tag) {

    #### Query to find the biosequence_set_id for this tag
    $sql = qq~
      SELECT biosequence_set_id
        FROM ${DATABASE}biosequence_set
       WHERE set_tag = '$biosequence_set_tag'
         AND record_status != 'D'
    ~;
    print "$sql\n" if ($VERBOSE);

    @biosequence_set_ids = $sbeams->selectOneColumn($sql);

  #### Else die
  } else {
    die("ERROR: biosequence_set_tag not provided!  Cannot load ".
      "without it!  Also no search_batch_id.");
  }


  my $n_ids = scalar(@biosequence_set_ids);


  #### If nothing returned, die
  unless ($n_ids) {
    die("ERROR: Unable to find any biosequence_sets in the database\n".
      "matching '$biosequence_set_tag' with $sql  You must specify a valid\n".
      "biosequence_set_tag.\n");
  }


  #### If more than one row was returned, die also
  if ($n_ids > 1) {
    die("ERROR: Found $n_ids biosequence_sets in the database\n".
      "that match '$biosequence_set_tag' with $sql  This should not happen\n".
      "and I don't know which biosequence set is the pertinent one here.\n");
  }


  #### Load all the biosequence_id's into a hash
  my $biosequence_set_id = $biosequence_set_ids[0];
  $sql = qq~
    SELECT biosequence_name,biosequence_id
      FROM ${DATABASE}biosequence
     WHERE biosequence_set_id = '$biosequence_set_id'
  ~;

  my %biosequence_ids = $sbeams->selectTwoColumnHash($sql);


  #### Prepare a result hash and return it
  my %result;
  $result{biosequence_set_tag} = $biosequence_set_tag;
  $result{biosequence_set_id} = $biosequence_set_id;
  $result{biosequence_ids} = \%biosequence_ids;

  return %result;

}



###############################################################################
# deleteProteinSummary
###############################################################################
sub deleteProteinSummary {
  my %args = @_;

  my $search_batch_id = $args{'search_batch_id'};
  my $protein_summary_id = $args{'protein_summary_id'};

  #### Define the inheritance path:
  ####  (C) means Child that directly links to the parent
  ####  (A) means Association from parent to this table and requires delete
  ####  (L) means Linking table from child to parent
  my %table_child_relationship = (
    protein_summary => 'protein_summary_header(C),protein_group(C),'.
      'search_batch_protein_summary(C)',
    protein_summary_header => 'protein_summary_data_filter(C)',
    protein_group => 'protein(C)',
    protein => 'peptide(C),indistinguishable_protein(C),'.
      'summary_quantitation(A)',
    peptide => 'peptide_parent_protein(C),indistinguishable_peptide(C)',
  );


  #### Find out which record to delete
  my @ids;
  if ($search_batch_id) {
    my $sql = "
      SELECT protein_summary_id
        FROM ${DATABASE}search_batch_protein_summary
       WHERE search_batch_id = '$search_batch_id'
    ";
    @ids = $sbeams->selectOneColumn($sql);
  } elsif ($protein_summary_id) {
    @ids = ( $protein_summary_id );
  } else {
    die("ERROR: Neither search_batch_id nor protein_summary_id specified");
  }


  foreach my $element (@ids) {
    my $result = $sbeams->deleteRecordsAndChildren(
      table_name => 'protein_summary',
      table_child_relationship => \%table_child_relationship,
      delete_PKs => [ $element ],
      delete_batch => 10000,
      database => $DATABASE,
      verbose=>$VERBOSE,
      testonly=>$TESTONLY,
    );
  }


  return 1;

}


###############################################################################
# guess_source_file
###############################################################################
sub guess_source_file {
  my %args = @_;
  my $search_batch_id = $args{'search_batch_id'};

  my ($sql,@biosequence_set_ids);

  #### If a search_batch_id was provided
  unless (defined($search_batch_id) && $search_batch_id > 0) {
    return;
  }


  #### Query to find the biosequence_set_id for this tag
  $sql = qq~
    SELECT data_location
      FROM ${DATABASE}search_batch
     WHERE search_batch_id = '$search_batch_id'
  ~;
  print "$sql\n" if ($VERBOSE);

  my ($data_location) = $sbeams->selectOneColumn($sql);

  if ($data_location) {
    unless ($data_location =~ /^\//) {
      $data_location = "$RAW_DATA_DIR{Proteomics}/$data_location";
    }
    return "$data_location/interact-prob-prot.xml";
  }

  return;

}


