package SBEAMS::Connection::PubMedFetcher;

###############################################################################
# Program     : SBEAMS::Connection::PubMedFetcher
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::Connection module which handles
#               getting data from NCBI's PubMed for a given PubMed ID.
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

  use vars qw($VERSION @ISA);
  use vars qw(@stack %info);

  @ISA = ();
  $VERSION = '0.1';



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
# getArticleInfo
###############################################################################
sub getArticleInfo {
  my $SUB_NAME = 'getArticleInfo';
  my $self = shift || die("$SUB_NAME: Parameter self not passed");
  my %args = @_;

  my $PubMedID = $args{'PubMedID'} || '';
  my $verbose = $args{'verbose'} || 0;


  #### Return if no PubMedID was supplied
  unless ($PubMedID) {
    print "$SUB_NAME: Error: Parameter PubMedID not passed\n" if ($verbose);
    return 0;
  }


  #### Return if supplied PubMedID isn't all digits
  unless ($PubMedID =~ /^\d+$/) {
    print "$SUB_NAME: Error: Parameter PubMedID '$PubMedID'not valid\n"
      if ($verbose);
    return 0;
  }


  #### Get the XML data from NCBI
  my $url = "http://www.ncbi.nlm.nih.gov/entrez/utils/pmfetch.fcgi?".
    "db=PubMed&id=$PubMedID&report=xml&mode=text";
  my $xml = getHTTPData($url);


  #### Return if no XML was returned
  unless ($xml) {
    print "$SUB_NAME: Error: No XML returned for PubMedID '$PubMedID'\n"
      if ($verbose);
    return 0;
  }


  #### Set up the XML parser and parse the returned XML
  my $parser = new XML::Parser(
			       Handlers => {
					    Start => \&start_element,
					    End => \&end_element,
					    Char => \&characters,
					   }
			      );
  $parser->parse($xml);


  #### Generate a synthetic PublicationName based on AuthorList
  if ($info{AuthorList} && $info{PublishedYear}) {
    my $publication_name = '';
    my @authors = split(', ',$info{AuthorList});
    my $n_authors = scalar(@authors);
    for (my $i=0; $i < $n_authors; $i++) {
      $authors[$i] =~ s/\ [A-Z]{1,4}$//;
    }
    $publication_name = $authors[0] if ($n_authors == 1);
    $publication_name = join(' & ',@authors) if ($n_authors == 2);
    $publication_name = $authors[0].', '.join(' & ',@authors[1..2])
      if ($n_authors == 3);
    $publication_name = $authors[0].' et al.' if ($n_authors > 3);
    $publication_name .= ' ('.$info{PublishedYear}.')';
    $info{PublicationName} = $publication_name;
  }


  #### If verbose mode, print out everything we gathered
  if ($verbose) {
    while (my ($key,$value) = each %info) {
      print "$key=$value=\n";
    }
  }

  return \%info;

}



###############################################################################
# start_element
###############################################################################
sub start_element {
  my $handler = shift;
  my $element = shift;
  my %attrs = @_;

  push(@stack,$element);

}



###############################################################################
# end_element
###############################################################################
sub end_element {
  my $handler = shift;
  my $element = shift;

  pop(@stack);

}



###############################################################################
# characters
###############################################################################
sub characters {
  my $handler = shift;
  my $string = shift;

  my $context = $handler->{Context}->[-1];

  my %element_type = (
    PMID => 'reg',
    ArticleTitle => 'reg',
    AbstractText => 'reg',
    Volume => 'reg',
    Issue => 'reg',
    MedlinePgn => 'reg',
    MedlineTA => 'reg',
    LastName => 'append(AuthorList), ',
    Initials => 'append(AuthorList) ',
  );

  if ($element_type{$context} eq 'reg') {
    $info{$context} = $string;
  }

  if ($element_type{$context} =~ /^append\((.+)\)(.*)$/) {
    my $prepend = $2 || '';
    if (defined($info{$1})) {
      $info{$1} .= $prepend;
    } else {
      $info{$1} = '';
    }
    $info{$1} .= $string;
  }

  if ($context eq 'Year' && $handler->{Context}->[-2] eq 'PubDate') {
    $info{PublishedYear} = $string;
  }



}



###############################################################################
# getHTTPData
###############################################################################
sub getHTTPData {
  my $url = shift || die("getHTTPData: Must supply the URL");

  #### Create a user agent object pretending to be Mozilla
  my $ua = new LWP::UserAgent;
  $ua->agent("Mozilla/5.0 (X11; U; Linux i686; en-US; rv:0.9.9)");

  #### Create a request object with the supplied URL
  my $request = HTTP::Request->new(GET=>$url);

  #### Pass request to the user agent and get a response back
  my $response = $ua->request($request);

  #### Return the data
  if ($response->is_success) {
    return $response->content;
  } else {
    return '';
  }

}

