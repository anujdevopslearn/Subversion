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

    my $chromatogram_pathname = $args{'chromatogram_pathname'};
    my $mzml_pathname = $args{'mzml_pathname'};
    my $precursor_neutral_mass = $args{'precursor_neutral_mass'};
    my $precursor_charge = $args{'precursor_charge'};
    my $seq = $args{'seq'} || '';
    my $precursor_rt = $args{'precursor_rt'};
    my $best_peak_group_rt = $args{'best_peak_group_rt'};
    my $m_score = $args{'m_score'};

    # Read the HTML code for the viewer from a template file.
    open(HTML, "$PHYSICAL_BASE_DIR/usr/javascript/chromavis/index.html");
    my @chromavis_html = <HTML>;
    my $chromavis_html = join('', @chromavis_html);
    # Substitute in the filename of the chromatogram
    $chromavis_html =~ s:js/data/test.json:$chromatogram_pathname:g;
    # Substitute in the location of the chromavis code
    my $chromavis_resources = "$HTML_BASE_DIR/usr/javascript/chromavis";
    $chromavis_html =~ s:src="js:src="$chromavis_resources/js:g;

    # Add extra stuff at bottom.
#--------------------------------------------------
#     $precursor_neutral_mass = sprintf "%0.3f", $precursor_neutral_mass;
#     $chromavis_html =~ s:</body>:<p>$seq ($precursor_neutral_mass Daltons calculated from +$precursor_charge precursor m/z)\n</body>:;
#     $chromavis_html =~ s:</body>:<br>Spectrum file\: $mzml_pathname\n</body>:;
#     if ($precursor_rt) {
#       $precursor_rt = sprintf "%0.3f", $precursor_rt;
#       $chromavis_html =~ s:</body>:<br>Precursor RT\: $precursor_rt\n</body>:;
#     }
#     if ($m_score) {
#       $best_peak_group_rt = sprintf "%0.3f", $best_peak_group_rt;
#       $chromavis_html =~ s:</body>:<br>mProphet best peakgroup RT\: $best_peak_group_rt\n</body>:;
#       $m_score = sprintf "%0.3f", $m_score;
#       $chromavis_html =~ s:</body>:<br>mProphet m_score\: $m_score\n</body>:;
#     }
#-------------------------------------------------- 

    return $chromavis_html;
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
