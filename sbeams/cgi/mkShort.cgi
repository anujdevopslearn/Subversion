#!/usr/local/bin/perl

###############################################################################
# Program     : main.cgi
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : implements caching of (potentially long) urls and retrieval
# via 10 character alphanumeric 'url_key'
#
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
###############################################################################


use strict;
use FindBin;
use lib "$FindBin::Bin/../lib/perl";
use SBEAMS::Connection qw($q $log);
use SBEAMS::Connection::SBPage;
use SBEAMS::Connection::Tables;

{  # 'Main' block

  my $sbeams = new SBEAMS::Connection;
  my $username = $sbeams->Authenticate();
  exit unless $username;

  # Read cgi parameters
  my %params;
  $sbeams->parse_input_parameters( q => $q, parameters_ref => \%params );
  
  my $extra = '';

  my $id;
  if ( $params{url} ) {
    my $id = $sbeams->setShortURL( $params{url} );
    my $shorty = $q->url();
    $shorty =~ s/mkShort\.cgi/shortURL/;
    my $url = "$shorty?key=$id";
    my $olen = length($params{url});
    my $nlen = length($url);
    $extra = qq~
    Original URL was $olen characters long, new URL is $nlen characters long.
    Short URL: $url<BR>
    Try link: <A HREF=$url target=_blank> $id </A><BR><BR>
    ~;
  } else { 

    my $page = SBEAMS::Connection::SBPage->new( user_context => 1,
                                                      sbeams => $sbeams );
  }

  my $size = $params{pagesize};
  $size ||= 50;
  my $limit = $sbeams->buildLimitClause( row_limit => $size );

  my $sql = "select $limit->{top_clause} url, url_key FROM $TB_SHORT_URL WHERE url NOT LIKE '%ManageTable%' $limit->{trailing_limit_clause} ORDER BY url_id DESC";
  my @rows = $sbeams->selectSeveralColumns( $sql );
  my $examples = '<TABLE BORDER=1 BGCOLOR="#F0F0F0">';
  my $params;
  foreach my $row ( @rows ) {
    my $url_tokens = parseURL( $row->[0] );
    if ( $url_tokens->[2] ) {
      my @ps = split "=", $url_tokens->[2];
      $params = scalar(@ps) . ' params';
    }
    $examples .= "<TR><TD><A HREF=shortURL?key=$row->[1] TARGET=_shorty>$row->[1]</A></TD><TD>$url_tokens->[0]</TD><TD>$url_tokens->[1]</TD><TD>$params</TD></TR>\n";
  }
  $examples .= '</TABLE>';

  my $more = "<A HREF=mkShort.cgi?pagesize=" . $size * 2 . ">more</A>";
  my $less = int( $size/2 ) || 1;
  $less = "<A HREF=mkShort.cgi?pagesize=$less>fewer</A>";

  my $sp = '&nbsp;';
  my $page = SBEAMS::Connection::SBPage->new( user_context => 1,
                                                    sbeams => $sbeams );
    $page->addContent( <<"    END" );
    $extra
    <FORM METHOD=POST>
     URL: <INPUT TYPE=TEXT NAME=url></INPUT>
    <INPUT TYPE=SUBMIT NAME='ShortIt'></INPUT>
    </FORM>
    <BR><BR>
    $sp $more $sp | $sp $less
    $examples
    END
    $page->printPage(); 

} # end main

sub parseURL {
  my $url = shift;
  my ( $base, $params ) = split /\?/, $url;
  my @tokens = split "/", $base;

  $params = '' if !defined $params;
  my $host = '';
  my $script = '';
  
  if ( $tokens[0] ) {
    if ( $#tokens ) {
      $host = join "", @tokens[0,1,2];
      $script = $tokens[$#tokens];
    } else {
      $script = $tokens[0];
    }
  } else {
    $host = $tokens[1];
      $script = $tokens[$#tokens];
  }
  return [ $host, $script, $params ];
}

