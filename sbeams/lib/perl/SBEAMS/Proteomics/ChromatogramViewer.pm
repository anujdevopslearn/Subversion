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

    # Read the HTML code for the viewer from a template file.
    open(HTML, "$PHYSICAL_BASE_DIR/usr/javascript/chromavis/index.html");
    my @chromavis_html = <HTML>;
    my $chromavis_html = join('', @chromavis_html);
    #Attempt to not have to call mzML2json from index.html
    $chromavis_html =~ s/JSON_PLACEHOLDER/${json_string}/;
    $chromavis_html .= qq~
    <script language="javascript">
    var chromatogram_id = $chromatogram_id;
    </script>
    ~;

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
