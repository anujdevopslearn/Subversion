#!/usr/local/bin/perl

###############################################################################
# Program     : load_BioSapOut.pl
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This script loads a BioSap output XML file into the database
#
###############################################################################

use strict;
use Getopt::Long;
use XML::Xerces;
use Data::Dumper;
use Benchmark;

use vars qw ($sbeams
             $PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $DEBUG
             $current_contact_id $current_username);
use FindBin;
use lib "$FindBin::Bin/../../perl";

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TableInfo;

$sbeams = new SBEAMS::Connection;


###############################################################################
# Read and validate command line args
###############################################################################
my $VERSION = q[$Id$ ];

my $PROG_NAME = "load_BioSapOut.pl";
my $USAGE = <<EOU;
USAGE: $PROG_NAME [-v=xxx][-n] file_to_load
Options:
    -x=XXXXX    XML validation scheme [always | never | auto*]
    -n          Enable namespace processing. Defaults to off.
    -s          Enable schema processing. Defaults to off.
    --quiet     If set, then no dots are printed during loading
    -v=N        Verbosity Level. Defaults to 0.

  * = Default if not provided explicitly

EOU


my %OPTIONS;
my $rc = GetOptions(\%OPTIONS,
		    'x=s',
		    'n',
		    's',
		    'quiet',
		    'v=i');

unless ($rc) {
  print "$USAGE";
  exit 0;
}


my $file = $ARGV[0];
unless ($file) {
  print "$USAGE";
  exit 0;
}


unless (-f $file) {
  die "File '$file' does not exist!\n";
}


my $validate = $OPTIONS{x} || 'auto';
my $namespace = $OPTIONS{n} || 0;
my $schema = $OPTIONS{s} || 0;
my $VERBOSE = $OPTIONS{v} || 0;
my $QUIET = $OPTIONS{quiet} || 0;


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
use vars qw(@ISA);
@ISA = qw(XML::Xerces::PerlContentHandler);


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
  print "(object_stack = ",$_[0],")\n" if ($VERBOSE > 1);
  if (scalar @_) {
    $self->{OBJ_STACK} = shift;
  }
  return $self->{OBJ_STACK};
}


###############################################################################
# unhandled
###############################################################################
sub unhandled {
  my $self = shift;
  print "(unhandled = ",$_[0],")\n" if ($VERBOSE > 1);
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

  my %attrs = $attrs->to_hash();

  #### Top level is BioSapRun.
  if ($localname eq 'BioSapRun') {
    print "<$localname> Begin the BioSapRun document\n";

    #### Store the attributes in the table
    %attrs = main::make_brazen_assumptions(\%attrs);
    $attrs{search_username} = "unknown" unless ($attrs{search_username});
    my $biosap_search_id = main::insert_attrs(table_name=>"biosap_search",
      attrs_ref=>\%attrs,PK=>"biosap_search_id",return_PK=>1);
    $self->{biosap_search_id} = $biosap_search_id;


  #### Parse FeaturamaParameters
  } elsif ($localname eq 'FeaturamaParameters') {
    print "\n<$localname>\n" if ($VERBOSE > 0);


    #### Obtain the biosequence_set_id and the biosequence_id hash
    my %biosequence_data = main::get_biosequence_data(
      gene_library => $attrs{gene_library}->{value});
    $self->{biosequence_set_id} = $biosequence_data{biosequence_set_id};
    $self->{biosequence_ids} = $biosequence_data{biosequence_ids};


    #### Need to also get the biosequence_set_id for the BLAST library
    my $FIXME = main::get_blast_library_name();
    my %blast_biosequence_data =
      main::get_biosequence_data(gene_library => $FIXME);
    $self->{blast_biosequence_set_id} =
      $blast_biosequence_data{biosequence_set_id};
    $self->{blast_biosequence_ids} = $blast_biosequence_data{biosequence_ids};


    #### Store the attributes in the table
    $attrs{biosap_search_id} = $self->{biosap_search_id};
    main::insert_attrs(table_name=>"featurama_parameter",
      attrs_ref=>\%attrs);


  #### Parse FeaturamaStatistics
  } elsif ($localname eq 'FeaturamaStatistics') {
    print "\n<$localname>\n" if ($VERBOSE > 0);

    #### Store the attributes in the table
    $attrs{biosap_search_id} = $self->{biosap_search_id};
    main::insert_attrs(table_name=>"featurama_statistic",
      attrs_ref=>\%attrs);


  #### Container FilteredBlastResults.  Just print it out
  } elsif ($localname eq 'FilteredBlastResults') {
    print "\n<$localname> Begin the FilteredBlastResult container\n"
      if ($VERBOSE > 0);


  #### Parse Feature
  } elsif ($localname eq 'Feature') {
    print "<$localname gene_name=",$attrs{gene_name}->{value},">\n"
      if ($VERBOSE > 0);

    #### Determine the relevant biosequence_id
    my $biosequence_name = $attrs{gene_name}->{value};
    my $biosequence_id = $self->{biosequence_ids}->{$biosequence_name};
    unless ($biosequence_id) {
      print "ERROR: Unable to find a matching biosequence_id for '$biosequence_name'\n";
      exit(0);
    }

    #### Store the attributes in the table
    $attrs{biosap_search_id} = $self->{biosap_search_id};
    $attrs{biosequence_id} = $biosequence_id;
    delete $attrs{gene_name};
    delete $attrs{gene_description};
    $attrs{feature_sequence} = $attrs{sequence};
    delete $attrs{sequence};
    my $feature_id = main::insert_attrs(table_name=>"feature",
      attrs_ref=>\%attrs,PK=>"feature_id",return_PK=>1);
    $self->{feature_id} = $feature_id;

    print "." unless ($QUIET);


  #### Parse Hit
  } elsif ($localname eq 'Hit') {
    print "\n<$localname>\n" if ($VERBOSE > 0);

    #### Determine the relevant biosequence_id
    my $biosequence_name = $attrs{gene_name}->{value};
    my $biosequence_id = $self->{blast_biosequence_ids}->{$biosequence_name};
    unless ($biosequence_id) {

      #### This is a terrible hack to work around apparent truncation of
      #### gene names in BLAST output
      my $tmp_str = $biosequence_name;
      $tmp_str =~ s/\|/\\\|/g;
      my @matches = grep { /$tmp_str/ }
        (keys %{$self->{blast_biosequence_ids}});
      my $n_matches = @matches;
      if ($n_matches == 1) {
	$biosequence_id = $self->{blast_biosequence_ids}->{$matches[0]};
        print "WARNING: There is no '$biosequence_name', but I found ".
	  "'$matches[0]' which I am assuming is the real name..\n";
      } elsif ($n_matches == 0 ) {
        print "ERROR: Unable to find a matching biosequence_id for ".
          "'$biosequence_name'.  This should never happen.  I am going".
          "to just pretend I never saw this hit.  Follow up on this!\n";
      } else {
        print "ERROR: There is no '$biosequence_name', and I found ".
	  "several possible matches (".join(" , ",@matches).").  I do not ".
	  "have what it takes to continue.. leave me behind.";
      }

    }

    #### Store the attributes in the table
    if ($biosequence_id) {
      $attrs{feature_id} = $self->{feature_id};
      $attrs{biosequence_id} = $biosequence_id;
      delete $attrs{gene_name};
      main::insert_attrs(table_name=>"feature_hit",,
        attrs_ref=>\%attrs);
    }


  #### Parse FilteredBlastStatistics
  } elsif ($localname eq 'FilteredBlastStatistics') {
    print "\n<$localname>\n" if ($VERBOSE > 0);
    $attrs{biosap_search_id} = $self->{biosap_search_id};
    main::insert_attrs(table_name=>"filterblast_statistic",
      attrs_ref=>\%attrs);


  #### Otherwise, confess we don't know what to do
  } else {
    print "<$localname> Don't know what to do with <$localname> yet\n";
  }

}


###############################################################################
# end_element
###############################################################################
sub end_element {
  my ($self,$uri,$localname,$qname) = @_;

  #### If there's an object on the stack consider popping it off
  if (scalar @{$self->object_stack()}){

    #### If the top object on the stack is the correct one, pop it off
    if ($self->object_stack->[-1]->class_name eq "$localname") {
      pop(@{$self->object_stack});
    }

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
    $sbeams->Authenticate(work_group=>'BioSap_user'));
  my $DATABASE = $OPTIONS{"database"} || $sbeams->getBIOSAP_DB();


#### Print the header, do what the program does, and print footer
$| = 1;
$sbeams->printTextHeader();
main();
$sbeams->printTextFooter();


###############################################################################
# Main part of the script
###############################################################################
sub main { 

    $sbeams->printUserContext(style=>'TEXT');
    print "\n";

    my $parser = XML::Xerces::XMLReaderFactory::createXMLReader();

    $parser->setFeature("http://xml.org/sax/features/namespaces", $namespace);

    if ($validate eq $XML::Xerces::SAX2XMLReader::Val_Auto) {
      $parser->setFeature("http://xml.org/sax/features/validation", 1);
      $parser->setFeature("http://apache.org/xml/features/validation/dynamic", 1);

    } elsif ($validate eq $XML::Xerces::SAX2XMLReader::Val_Never) {
      $parser->setFeature("http://xml.org/sax/features/validation", 0);

    } elsif ($validate eq $XML::Xerces::SAX2XMLReader::Val_Always) {
      $parser->setFeature("http://xml.org/sax/features/validation", 1);
      $parser->setFeature("http://apache.org/xml/features/validation/dynamic", 0);
    }

    $parser->setFeature("http://apache.org/xml/features/validation/schema", $schema);

    my $error_handler = XML::Xerces::PerlErrorHandler->new();
    $parser->setErrorHandler($error_handler);

    my $CONTENT_HANDLER = MyContentHandler->new();
    $parser->setContentHandler($CONTENT_HANDLER);


    my $t0 = new Benchmark;
    $parser->parse (XML::Xerces::LocalFileInputSource->new($file));
    my $t1 = new Benchmark;
    my $td = timediff($t1, $t0);


    #### Write out information about the objects we've loaded
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
      } elsif ($key eq "biosequence_ids" ||$key eq "blast_biosequence_ids" ) {
        my $tmpcnt = 0;
        while (($key2,$value2) = each %{$CONTENT_HANDLER->{$key}}) {
          print "  $key2 = $value2\n";
          $tmpcnt++;
          last if ($tmpcnt > 20);
        }
      } else {
        if (ref($CONTENT_HANDLER->{$key})) {
          foreach $key2 (@{$CONTENT_HANDLER->{$key}}) {
            print "  $key2\n";
          }
        }
      }

    }


print "\n\n";

}


###############################################################################
# insert_attrs
###############################################################################
sub insert_attrs { 
  my %args = @_;
  my $table_name = $args{'table_name'} || die "ERROR: table_name not passed";
  my $attrs_ref = $args{'attrs_ref'} || die "ERROR: attrs_ref not passed";
  my $PK = $args{'PK'} || "";
  my $return_PK = $args{'return_PK'} || 0;


  my $returned_PK = $sbeams->insert_update_row(insert=>1,
     table_name=>"${DATABASE}$table_name",
     rowdata_ref=>$attrs_ref,PK=>$PK,return_PK=>$return_PK);


  return $returned_PK;

}



###############################################################################
# get_biosequence_data
###############################################################################
sub get_biosequence_data { 
  my %args = @_;
  my $gene_library = $args{'gene_library'};
  unless ($gene_library) {
    print "ERROR: featurama_parameter:gene_library is empty!  Cannot load ".
      "without it!\n";
    exit(0);
  }

  my @biosequence_set_ids = $sbeams->selectOneColumn(
    "SELECT biosequence_set_id FROM ${DATABASE}biosequence_set WHERE set_path = '$gene_library' AND record_status != 'D'");

  my $n_ids = scalar(@biosequence_set_ids);

  unless ($n_ids) {
    print "ERROR: Unable to find any biosequence_sets in the database\n".
      "matching '$gene_library.  You must load the appropriate\n".
      "biosequence_set first.\n";
    exit(0);
  }

  if ($n_ids > 1) {
    print "ERROR: Found $n_ids biosequence_sets in the database\n".
      "that match '$gene_library.  This should not happen and I\n".
      "don't know which biosequence set it the pertinent one here.\n";
    exit(0);
  }

  my $biosequence_set_id = $biosequence_set_ids[0];
  my %biosequence_ids = $sbeams->selectTwoColumnHash(
    "SELECT biosequence_name,biosequence_id FROM ${DATABASE}biosequence".
    " WHERE biosequence_set_id = $biosequence_set_id");

  my %result;
  $result{biosequence_set_id} = $biosequence_set_id;
  $result{biosequence_ids} = \%biosequence_ids;

  return %result;

}


###############################################################################
# make_brazen_assumptions: assume some values about the BioSap search if
#                          haven't been supplied
###############################################################################
sub make_brazen_assumptions { 
  my $attrs_ref = shift || die "ERROR: attribute reference not passed";
  my %attrs = %$attrs_ref;

  my $dirpart = $file;
  $dirpart = "" unless ($dirpart =~ /\//);
  $dirpart =~ s/\/[\w-\.]*$//;

  my $filepart = $file;
  $filepart =~ s/^.*\///;

  my $assumed_idcode;
  if ($dirpart =~ /\w/) {
    $assumed_idcode = $dirpart;
    $assumed_idcode =~ s/^.*\///;
  } else {
    use Cwd;
    $assumed_idcode = cwd();
    $assumed_idcode =~ s/^.*\///;
  }

  $attrs{biosap_search_idcode} = $assumed_idcode unless ($attrs{biosap_search_idcode});

  #### HACK ON TOP OF HACK FIXME
  $attrs{search_username} = get_user_name() unless ($attrs{search_username});

  $attrs{search_username} = $ENV{USER} unless ($attrs{search_username});

  my ($key,$value);
  print "  Assuming:\n";
  while ( ($key,$value) = each %attrs ) {
    print "	$key = $value\n";
  }

  return %attrs;

}


###############################################################################
# get_blast_library_name: Get the blast_library_name from the blast.params
#                         file.  This is a hack around something done
#                         improperly.  FIXME!
###############################################################################
sub get_blast_library_name {

  my $library_name = "";

  my $source_dir = $file;
  if ($source_dir =~ /\//) {
    $source_dir =~ s/\/[\w-\.]*$//;
    $source_dir .= "/";
  } else {
    $source_dir = "";
  }

  my ($line,$key,$value);

  my $params_file = "${source_dir}blast.params";
  open(INFILE,$params_file) || die "Unable to open $params_file\n";
  while ($line = <INFILE>) {
    chomp $line;
    ($key,$value) = split("=",$line);
    $library_name = $value if ($key eq "blast_library");
  }
  close INFILE;

  die "Unable to find 'blast_library' in $params_file\n" unless $library_name;

  return $library_name;

}


###############################################################################
# get_user_name: Get user_name from the featurama.params
#                file.  This is a hack around something done
#                improperly.  FIXME!
###############################################################################
sub get_user_name {

  my $user_name = "";

  my $source_dir = $file;
  if ($source_dir =~ /\//) {
    $source_dir =~ s/\/[\w-\.]*$//;
    $source_dir .= "/";
  } else {
    $source_dir = "";
  }

  my ($line,$key,$value);

  my $params_file = "${source_dir}featurama.params";
  open(INFILE,$params_file) || die "Unable to open $params_file\n";
  while ($line = <INFILE>) {
    chomp $line;
    ($key,$value) = split("=",$line);
    $user_name = $value if ($key eq "user_name");
  }
  close INFILE;

  die "Unable to find 'user_name' in $params_file\n" unless $user_name;

  return $user_name;

}
