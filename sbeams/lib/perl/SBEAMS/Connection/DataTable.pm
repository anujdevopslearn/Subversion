###############################################################################
# $Id$
#
# Description : Generic Table building mechanism designed for use with cgi
#               scripts.  Default export mode is HTML; can also export as 
#               TSV.
#
# SBEAMS is Copyright (C) 2000-2004 by Eric Deutsch
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################

package SBEAMS::Connection::DataTable;
use strict;
use overload ( '""', \&asHTML );

use SBEAMS::Connection;
use SBEAMS::Connection::Log;

use POSIX;

my $log = SBEAMS::Connection::Log->new();

##### Public Methods ###########################################################
#
# Module provides interface to build table, then render it in various fashions.
# Current rendering methods include asHTML, asCSV, and asTSV.  The stringify
# operator is overloaded to use the asHTML method, so if you create a table 
# object and refer to it in double quotes, it will stringify using the asHTML
# method

#+
# Constructor method.  Any name => value parameters passed will be appended
# as table attributes
#
sub new {
  my $class = shift;
  my $this = { @_,
               __rowvals => [],
               __colspecs => [],
               __rowspecs => [],
               __cellspecs => [],
               __maxlen => 0
             };
  bless $this, $class;
  return $this;
}

#+
# Method to set attributes for a given cell in the table.
# narg ROW required row number of cell, first row is 1
# narg COL required col number of cell, first col is 1
# 
# All other args are interpreted as NAME => VALUE attributes to 
# pass to the cell (<TD> tag).
# -
sub setCellAttr {
  my $this = shift;
  my %args = @_;

  for my $element ( 'ROW', 'COL' ) {
    die ( "Missing required field $element\n" ) if !defined $args{$element};
  }

  my $col = $args{COL};
  delete $args{COL};
  die "COL ($col) must be an integer > 0" if $col !~ /^[0-9][0-9]*$/;

  my $row = $args{ROW};
  delete $args{ROW};
  die "ROW must be an integer > 0" if $row !~ /^[0-9][0-9]*$/;

  for my $key ( keys %args ) {
    push @{$this->{__cellspecs}->[$row]->[$col]}, ( $key => $args{$key} );
  }
}

#+
# Method to set attributes one or more columns in the table. 
# narg COLS required ref to array of col numbers
# narg ROWS optional ref to array of row numbers
# 
# All other args are interpreted as NAME => VALUE attributes to 
# pass to the cell (<TD> tag) for each row in named 
# -
sub setColAttr {
  my $this = shift;
  my %args = @_;
  my ( @cols, @rows );

# Must provide columns
  die ( "Missing required field COLS\n" ) if !defined $args{COLS};
  die ( "COLS must be an array ref" ) if ref ( $args{COLS} ) ne 'ARRAY'; 
  for ( @{$args{COLS}} ) { 
    die "COLS must contain only int > 0" if $_ !~ /^[1-9][0-9]*$/;
    push @cols, ( $_ );
  }
  delete( $args{COLS} );

# Optionally provide rows
  if ( $args{ROWS} ) {
    die ( "ROWS must be an array ref" ) if ref ( $args{ROWS} ) ne 'ARRAY'; 
    for ( @{$args{ROWS}} ) { 
    die "ROWS must contain only int > 0" if $_ !~ /^[1-9][0-9]*$/;
    push @rows, ( $_ );
    delete( $args{ROWS} );
    }
  }

  if ( scalar @rows ) { # gonna apply this to only a select few...
    for my $key ( keys %args ) {
      foreach my $row ( @rows ) {
        foreach my $col ( @cols ) {
        push @{$this->{__cellspecs}->[$row]->[$col]}, $key, $args{$key};
        }
      }
    }
  } else { # Otherwise, add to all rows
# For the number of rows
# for each specified column
# push the specified attributes onto the the row->col colspecs array
    
  }
}

#+
#
#-
sub setHeaderAttr {
  my $this = shift;
  my %args = @_;
  $this->{_header} = \%args;
}

# Impelements alternating row background colors
sub alternateColors {
  my $this = shift;
  my %args = @_;
  for( qw( PERIOD FIRSTROW BGCOLOR ) ){
    unless ( $args{$_} ) {
      $log->warn( "Missing required param $_ in alternateColors" );
      return;
    }
  }
  $this->{_alternate_colors} = 1;
  $this->{_altc_first} = $args{FIRSTROW};
  $this->{_altc_period} = $args{PERIOD};
  $this->{_altc_bgcolor} = $args{BGCOLOR};
  $this->{_altc_defcolor} = $args{DEF_BGCOLOR} || '#FFFFFF';
}

#+
# Method to set attributes one or more rows in the table. 
# narg ROWS required ref to array of row numbers
# 
# All other args are interpreted as NAME => VALUE attributes to 
# pass to each row (<TR> tag)
# -
# 
sub setRowAttr {
  my $this = shift;
  my %args = @_;
  my ( @cols, @rows );

  die ( "Missing required field ROWS\n" ) if !defined $args{ROWS};
  die ( "ROWS must be an array ref" ) if ref ( $args{ROWS} ) ne 'ARRAY'; 
  for ( @{$args{ROWS}} ) { 
    die "ROWS must contain only int > 0" if $_ !~ /^[1-9][0-9]*$/;
    push @rows, ( $_ );
  }
  delete( $args{ROWS} );

  foreach my $row ( @rows ) {
    foreach my $key ( keys %args ) {
      push @{$this->{__rowspecs}->[$row]}, $key, $args{$key};
    }
  }
}

#+
# Method to get the number of rows currently defined
# -
sub getRowNum {
  my $this = shift;
  return( scalar(@{$this->{__rowvals}}) );
}

#+
# Method to add row to data structure.
# arg reference to array of data for row
sub addRow {
  my $this = shift;
  my $rowref = shift;
  my @row = @$rowref;
  $this->{__maxlen} = scalar( @row ) if scalar( @row ) > $this->{__maxlen};
  push @{$this->{__rowvals}}, \@row; 
}

#+
# Rendering method, returns table as tab-delimited scalar
#-
sub asTSV {
  my $this = shift;
  my $tsv = $this->_delimitData( "\t" );
  return $tsv;
}

#+
# Rendering method, returns table as comma-delimited scalar
#-
sub asCSV {
  my $this = shift;
  my $tsv = $this->_delimitData( "," );
  return $tsv;
}

#+
#
#-
sub formatHeader {
  my $this = shift;
  my $text = shift;
  return '' unless $text;

  my %format = %{$this->{_header}};
  $text = "<B>$text</B>" if $format{BOLD};
  $text = "<U>$text</U>" if $format{UNDERLINE};
  return $text;

}

#+
# Default rendering method, returns table as HTML, with row, col, and cell
# attributes expressed.
#-
sub asHTML {
  my $this = shift;
  my $html = $this->_getTable() . "\n";
  my $rnum = 1;
  foreach my $row ( @{$this->{__rowvals}} ) {
    my $cnum = 1;
    $html .= $this->_getTR( $rnum );

    foreach my $cell ( @$row ) {
      $cell = ( defined $cell ) ? $cell : '';
      $cell = $this->formatHeader( $cell ) if ( $rnum == 1 && $this->{_header} );
      $html .= $this->_getTD( $rnum, $cnum++ ) . "$cell</TD>\n"
    }
    $html .= "  </TR>\n";
    $rnum++;
  }
  $html .= "</TABLE>\n";
  return $html;
}

##### Private Methods #########################################################

#+
# Returns data delimited with passed delimiter
#-
sub _delimitData {
  my $this = shift;
  my $sep = shift || die( 'Must pass delimiter' );
  my $datafile = '';
  foreach my $row ( @{$this->{__rowvals}} ) {
    my $line = '';
    my $pad = '';
    foreach my $datum ( @$row ) {
      $datum =~ s/\n/\\n/gm;
      $line .=  $pad . $datum;
      $pad = $sep;
    }
    $datafile .= "$line\n";
  }
  return $datafile;
}

#+
# Returns <TABLE> element with attributes filled in </TABLE>
#-
sub _getTable {
  my $this = shift;
  my $tabdef = '<TABLE ';
  foreach my $att ( keys ( %$this ) ) {
  next if $att =~ /^__/;
    $tabdef .= "$att='$this->{$att}' ";
  }
  return $tabdef . '>';
}

#+
# Returns <TD> element with attributes filled in
#-
sub _getTD {
  my $this = shift;
  my $row = shift;
  my $col = shift;
  my $tag = '    <TD';

# merge column/cell defined characteristics, cell chars take precedence

  if ( defined @{$this->{__cellspecs}->[$row]->[$col]} ) {
    my %attrs = @{$this->{__cellspecs}->[$row]->[$col]};
    foreach my $key ( keys( %attrs ) ) {
      $tag .= " ${key}=$attrs{$key}";
    }
  }
  $tag .= '>';

  return $tag;
  return '    <TR>';
}

sub _getColor {
  my $this = shift;
  my $row = shift;
  $log->debug( "here we are, $this->{_altc_bgcolor}" );
  return '' if $row < $this->{_altc_first};
  my $s = POSIX::ceil( ($row + 1 - $this->{_altc_first})/$this->{_altc_period} );
  my $color = ( $s % 2 ) ? $this->{_altc_bgcolor} : $this->{_altc_defcolor};
  return "BGCOLOR=$color";
}

#+
# Returns <TR> element with attributes filled in
#-
sub _getTR {
  my $this = shift;
  my $row = shift;
  my $tag = '  <TR';

  if ( defined @{$this->{__rowspecs}->[$row]} ) {
    my %attrs = @{$this->{__rowspecs}->[$row]};
    foreach my $key ( keys( %attrs ) ) {
      $tag .= " ${key}=$attrs{$key}";
    }
  }
  my $bgcolor = ( $this->{_alternate_colors} ) ? $this->_getColor($row) : '';
  $tag .= " $bgcolor>\n";

  return $tag;
  return '    <TR>';
}

1;

