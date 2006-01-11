package SBEAMS::Proteomics::XMLUtilities;

###############################################################################
# Program     : SBEAMS::Proteomics::XMLUtilities
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::Proteomics module which
#               provides functions for reading pepXML
#
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################


use strict;
use XML::Xerces;


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



#### main package continues below after MyContentHandler package

###############################################################################
# readXInteractFile Content Handler
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

  #### If this is the start of a search_result, remember the name
  if ($localname eq 'spectrum_query') {
    my $spectrum = $attrs{spectrum}
      || die("ERROR: No spectrum attribute for this spectrum_query");
    $self->{current_search_result} = $attrs{spectrum};
    #print "  \nspectrum=$spectrum\n";
  }

  #### If this is the start of a search_result, remember the name
  if ($localname eq 'search_result') {
    my $spectrum = $attrs{spectrum};
      #### Later formats of pepXML have "spectrum" in <spectrum_query>
      #|| die("ERROR: No spectrum attribute for this search_result");
    $self->{current_search_result} = $spectrum if ($spectrum);
  }

  #### If this is the peptideprophet_result, store the probability
  if ($localname eq 'peptideprophet_result') {
    my $probability = $attrs{probability};
    unless (defined($probability)) {
      die("ERROR: No probability attribute for peptideprophet_result: ".
          join(",",%attrs));
    }
    #print "  \nprobability=$probability\n";

    my $current_search_result = $self->{current_search_result};
    unless ($current_search_result) {
      print("ERROR: Found a peptideprophet_result without knowing the ".
	     "current_search_result.");
      return;
    }
    $current_search_result .= ".out";
    $self->{files}->{$current_search_result}->{probability} =
      $attrs{probability};
    $self->{current_search_result} = undef;

    #### Increase the counters and print some progress info
    $self->{counter}++;
    print $self->{counter}."..." if ($self->{counter} % 100 == 0);
  }

}



###############################################################################
# end_element
###############################################################################
sub end_element {
  my ($self,$uri,$localname,$qname) = @_;


  #### Nothing to do


}


###############################################################################
# continuation of main package
package SBEAMS::Proteomics::XMLUtilities;

###############################################################################
# readXInteractFile
###############################################################################
sub readXInteractFile {
  my $self = shift;
  my %args = @_;


  #### Decode the argument list
  my $source_file = $args{'source_file'} || '';
  my $VERBOSE = $args{'verbose'} || '';
  my $validate = $args{validate} || 'never';
  my $namespace = $args{namespaces} || 0;
  my $schema = $args{schema} || 0;


  #### Check to make sure the file exists
  unless (-f $source_file) {
    die "File '$source_file' does not exist!\n";
  }


  if (uc($validate) eq 'ALWAYS') {
    $validate = $XML::Xerces::SAX2XMLReader::Val_Always;
  } elsif (uc($validate) eq 'NEVER') {
    $validate = $XML::Xerces::SAX2XMLReader::Val_Never;
  } elsif (uc($validate) eq 'AUTO') {
    $validate = $XML::Xerces::SAX2XMLReader::Val_Auto;
  } else {
    die("Unknown value for validate: $validate\n");
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


  #### Process the whole document
  print "INFO: Loading...\n" if ($VERBOSE);
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

      if ($key eq "files") {
        while (($key2,$value2) = each %{$CONTENT_HANDLER->{$key}}) {
          print "  $key2 = $value2\n";
        }
      }

    } # end while

  } # end if

  print "\n\n" if ($VERBOSE);

  return($CONTENT_HANDLER);

} # end readXInteractFile



###############################################################################

1;

__END__
###############################################################################
###############################################################################
###############################################################################

=head1 NAME

SBEAMS::Proteomics::XMLUtilities - Module-specific XML utilities

=head1 SYNOPSIS

  Used as part of this system

    use SBEAMS::Connection;
    use SBEAMS::Proteomics::XMLUtilties;


=head1 DESCRIPTION

    This module is inherited by the SBEAMS::Proteomics module,
    although it can be used on its own.  Its main function
    is to encapsulate XML-specific functionality.

=head1 METHODS

=item B<readXInteractFile()>

    Read a interact.xml file generated by xinteract

=head1 AUTHOR

Eric Deutsch <edeutsch@systemsbiology.org>

=head1 SEE ALSO

perl(1).

=cut
