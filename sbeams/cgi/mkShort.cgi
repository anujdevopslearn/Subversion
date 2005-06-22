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

  if ( $params{url} ) {
    my $id = $sbeams->setShortURL( $params{url} );
    my $shorty = $q->url();
    $shorty =~ s/mkShort\.cgi/shortURL/;
    $extra = "$shorty?key=$id";
  } else { 

    my $page = SBEAMS::Connection::SBPage->new( user_context => 1,
                                                      sbeams => $sbeams );
  }

  my $page = SBEAMS::Connection::SBPage->new( user_context => 1,
                                                    sbeams => $sbeams );
    $page->addContent( <<"    END" );
    $extra
    <FORM METHOD=POST>
     URL: <INPUT TYPE=TEXT NAME=url></INPUT>
    <INPUT TYPE=SUBMIT NAME='ShortIt'></INPUT>
    </FORM>
    END
    $page->printPage(); 

} # end main


