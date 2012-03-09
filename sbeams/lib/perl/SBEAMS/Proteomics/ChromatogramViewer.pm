package SBEAMS::Proteomics::ChromatogramViewer;

###############################################################################
# Program     : SBEAMS::Proteomics::ChromatogramViewer
# Author      : Terry Farrah <tfarrah (at) systemsbiology dot org>
# $Id$
#
# Description : Contains utilities to display spectra in the chromavis viewer
#
# SBEAMS is Copyright (C) 2000-2011 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################


use strict;
use vars qw($sbeams
           );

use SBEAMS::Connection::DBConnector;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::TableInfo;
use JSON;

#use SBEAMS::Proteomics::AminoAcidModifications;


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
# generateChromatogram
#   returns a string of chromavis chromatogram HTML code
###############################################################################
sub generateChromatogram { 
    my $self = shift;
    my %args = @_;

    my $chromatogram_id = $args{'chromatogram_id'} || '\'\'';
    my $chromatogram_pathname = $args{'chromatogram_pathname'};
    my $mzml_pathname = $args{'mzml_pathname'};
    my $precursor_neutral_mass = $args{'precursor_neutral_mass'};
    my $precursor_charge = $args{'precursor_charge'};
    my $seq = $args{'seq'} || '';
    my $precursor_rt = $args{'precursor_rt'};
    my $best_peak_group_rt = $args{'best_peak_group_rt'};
    my $m_score = $args{'m_score'};
    my $json_string = $args{'json_string'};
		$args{default_smoothing_factor} ||= 3;

    # Read the HTML code for the viewer from a template file.
    open(HTML, "$PHYSICAL_BASE_DIR/usr/javascript/chromavis/index.html");
    my @chromavis_html = <HTML>;
    my $chromavis_html = join('', @chromavis_html);

    if ( $args{expand_timeframe} ) {
      my $json_exp = $self->expand_json_timeframe( $json_string, $args{expand_timeframe} );
      $json_string = $json_exp;
#			die $json_exp;
		}

    # Insert json string
    $chromavis_html =~ s/JSON_PLACEHOLDER/${json_string}/;
    $chromavis_html .= qq~
    <script language="javascript">
    var chromatogram_id = $chromatogram_id;
    </script>
    ~;

		$chromavis_html =~ s/DEFAULT_SMOOTHING_PH/$args{default_smoothing_factor}/;
		my $smoothing_select = $self->get_smoothing_select( %args );
		$chromavis_html =~ s/SMOOTHING_SELECT_PH/$smoothing_select/;
		$chromavis_html =~ s/Smoothing width/Data smoothing/ if $args{limit_smoothing_options};

    return $chromavis_html;
}

sub expand_json_timeframe {
	my $self = shift;
	my $json_string = shift;

  my $json = new JSON;
  my $pjson = $json->decode( $json_string );

	my $expand_by = shift || 25;

	my $max_inten = 0;
	my $max_time = 0;
	my $min_inten = 1000000;
	for my $data ( @{$pjson->{data_json}} ) {
    for my $row ( @{$data->{data}} ) {
      if ( $row->{intensity} > $max_inten ) {
				$max_inten = $row->{intensity};
				$max_time = $row->{'time'};
	    }
      if ( $row->{intensity} < $min_inten ) {
		  	$min_inten = $row->{intensity};
		  }
    }
	}

#	print "Saw max intensity $max_inten at $max_time seconds\n";
	my $start_time = $max_time - $expand_by;
	$start_time = 0.0 if $start_time < 0;
	my $end_time = $max_time + $expand_by;
	$min_inten ||= 10;
#	die "max is $max_time, start is $start_time, end is $end_time, max is $max_inten and min is $min_inten\n";;

  my $start_data = { 'time' => $start_time, intensity => $min_inten };
  my $end_data = { 'time' => $end_time, intensity => $min_inten };
	for my $entry ( @{$pjson->{data_json}} ) {
    unshift @{$entry->{data}}, $start_data;
    push @{$entry->{data}}, $end_data;
  }

  return $json->encode( $pjson );
}

sub get_smoothing_select {
	my $self = shift;
	my %args = @_;
  my @s_values = ( 1 );
	if ( $args{limit_smoothing_options} ) {
		push @s_values, $args{default_smoothing_factor}
	} else {
		push @s_values, 3, 5, 7, 9, 11, 13, 15, 17, 19, 21;
	}
	my $select = '<select id="smoothFactor" onChange="renderChromatogram(parseInt(value))">' . "\n";
	for my $sval ( @s_values ) {
		my $s_display = ( $sval == 1 ) ? 'none' : $sval;
		my $selected = ( $sval == $args{default_smoothing_factor} ) ? ' selected' : '';
    if ( $selected && $args{limit_smoothing_options} ) {
			$s_display = 'smoothed';
			$select =~ s/none/unsmoothed/;
		}
		$select .= "<option value=$sval $selected>$s_display</option>\n";
	}
	$select .= "</select>\n";

}

###############################################################################

1;

__END__
###############################################################################
###############################################################################
###############################################################################

=head1 NAME

SBEAMS::Proteomics::ChromatogramViewer

=head1 SYNOPSIS

  Methods to dispay chromatograms in chromavis Viewer

    use SBEAMS::Proteomics::ChromatogramViewer;


=head1 DESCRIPTION

    This module is new.  More info to come...someday.

=head1 METHODS

=item B<generateChromatogram()>

    Generate chromatogram code (mostly javascript)

=head1 AUTHOR

Terry Farrah <tfarrah (at) systemsbiology dot org>

=head1 SEE ALSO

perl(1).

=cut
