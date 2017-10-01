package SBEAMS::Proteomics::SpecViewer;

###############################################################################
# Program     : SBEAMS::Proteomics::SpecViewer
# Author      : Luis Mendoza <lmendoza (at) systemsbiology dot org>
# $Id$
#
# Description : Contains utilities to display spectra in the Lorikeet viewer
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

use SBEAMS::Proteomics::AminoAcidModifications;


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
# convertMods
#   returns a string of lorikeet-ready mods based on input peptide sequence
###############################################################################
sub convertMods { 
#    my $self = shift;
    my %args = @_;

    my $sequence = $args{'modified_sequence'} || '';

    my $AAmodifications = new SBEAMS::Proteomics::AminoAcidModifications;
    my %supported_modifications = %{$AAmodifications->{supported_modifications}};

    my $mass_type = 'monoisotopic';

    # Deal with terminal mods first
    my $nterm = 0;
    my $cterm = 0;

    if ($sequence =~ s/(n\[\d+\])//) {
			my $mod = $1;
			my $mass_diff = $supported_modifications{$mass_type}->{$mod};
			if (defined($mass_diff)) {
					$nterm = $mass_diff;
			} else {
					print STDERR "ERROR: N-terminal mass modification $mod is not supported yet\n";
					return(undef);
			}
    }

    if ($sequence =~ s/(c\[\d+\])//) {
			my $mod = $1;
			my $mass_diff = $supported_modifications{$mass_type}->{$mod};
			if (defined($mass_diff)) {
					$cterm = $mass_diff;
			} else {
					print STDERR "ERROR: C-terminal mass modification $mod is not supported yet\n";
					return(undef);
			}
    }

    # ...and now with the rest
    my $modstring = "[ ";
    while ($sequence =~ /\[/) {
			my $index = $-[0];
			if ($sequence =~ /([A-Znc]\[\d+\])/) {
				my $mod = $1;
				my $aa = substr($mod,0,1);
				my $mass_diff = $supported_modifications{$mass_type}->{$mod};
				if (defined($mass_diff)) {
					if ($modstring eq "[ "){
						 $modstring .= "{index: $index, modMass: $mass_diff, aminoAcid: \"$aa\"}";
					}else{
						 $modstring .= ", {index: $index, modMass: $mass_diff, aminoAcid: \"$aa\"}";
					}
					$sequence =~ s/[A-Z]\[\d+\]/$aa/;
				} else {
					print STDERR "ERROR: Mass modification $mod is not supported yet\n";
					return(undef);
				}
			} else {
	    print STDERR "ERROR: Unresolved mass modification in '$sequence'\n";
	    return(undef);
	}
    }

    #### Fail if imprecise AA's are present
    return(undef) if ($sequence =~ /[BZX]/);

    $modstring .= " ]";

    return ($sequence, $modstring, $nterm, $cterm);
}


###############################################################################
# generateSpectrum
#   returns a string of lorikeet spectrum code
###############################################################################
sub generateSpectrum { 
    my $self = shift;
    my %args = @_;

    my $html_id  = $args{'htmlID'} || 'lorikeet';
    my $charge   = $args{'charge'};
    my $massTolerance   = $args{'massTolerance'} || 0.5;
    my $peakDetect   = $args{'peakDetect'} || 'false';
    my $labelReporters   = $args{'labelReporters'} || 'true';
    my $showA    = $args{'a_ions'} || '[0,0,0]';
    my $showB    = $args{'b_ions'} || '[1,1,0]';
    my $showC    = $args{'c_ions'} || '[0,0,0]';
    my $showX    = $args{'x_ions'} || '[0,0,0]';
    my $showY    = $args{'y_ions'} || '[1,1,0]';
    my $showZ    = $args{'z_ions'} || '[0,0,0]';
    my $scanNum  = $args{'scan'} || '0';
    my $fileName = $args{'name'} || '';
    my $peakDetect = $args{'peakDetect'} || 'true';
    my $modified_sequence = $args{'modified_sequence'};
    my $precursorMz = $args{'precursor_mass'};
    my $spectrum_aref = $args{'spectrum'};
    my $jsArrayName = $args{'jsArrayName'} || 'ms2peaks';

    my ($sequence,$mods, $nmod, $cmod) = &convertMods(modified_sequence => $modified_sequence);

    my $lorikeet_resources = "$HTML_BASE_DIR/usr/javascript/lorikeet";

    my $lorikeet_html = qq%
	<!--[if IE]><script language="javascript" type="text/javascript" src="$lorikeet_resources/js/excanvas.min.js"></script><![endif]-->
	<script type="text/javascript" src="$lorikeet_resources/js/jquery.min.js"></script>
	<script type="text/javascript" src="$lorikeet_resources/js/jquery-ui.min.js"></script>
	<script type="text/javascript" src="$lorikeet_resources/js/jquery.flot.js"></script>
	<script type="text/javascript" src="$lorikeet_resources/js/jquery.flot.selection.js"></script>
	<script type="text/javascript" src="$lorikeet_resources/js/specview.js"></script>
	<script type="text/javascript" src="$lorikeet_resources/js/peptide.js"></script>
	<script type="text/javascript" src="$lorikeet_resources/js/aminoacid.js"></script>
	<script type="text/javascript" src="$lorikeet_resources/js/ion.js"></script>
	<link REL="stylesheet" TYPE="text/css" HREF="$lorikeet_resources/css/lorikeet.css">

	<div id="$html_id"></div>

	<script type="text/javascript">
	\$(document).ready(function () {

    %;

    if ( $sequence ) {
      $lorikeet_html .= qq%
	    \$("#$html_id").specview({"sequence":"$sequence",
				      "scanNum":$scanNum,
				      "charge":$charge,
				      "massError":$massTolerance,
				      "peakDetect":$peakDetect,
				      "showMassErrorPlot":true,
				      "massErrorPlotDefaultUnit":"ppm",
				      "precursorMz":$precursorMz,
				      "fileName":"$fileName",
				      "width": 650,
				      "height":400,
				      "showA":$showA,
				      "showB":$showB,
				      "showC":$showC,
				      "showX":$showX,
				      "showY":$showY,
				      "showZ":$showZ,
				      "peakDetect":$peakDetect,
				      "labelReporters":$labelReporters,
				      "variableMods":$mods,
				      "ntermMod":$nmod,
				      "ctermMod":$cmod,
				      "peaks":$jsArrayName});
	});
    %;

    } else {
      $lorikeet_html .= qq%
	    \$("#$html_id").specview({
				      "scanNum":$scanNum,
				      "precursorMz":$precursorMz,
				      "fileName":"$fileName",
				      "width": 650,
				      "height":400,
				      "peaks":$jsArrayName});
	});
    %;

    }
    $lorikeet_html .= "var $jsArrayName = [\n";
    for my $ar_ref (@{$spectrum_aref}) {
	my $mz = $ar_ref->[0];	
	my $in = $ar_ref->[1];
	$lorikeet_html .= "[$mz,$in],\n";
    }
    $lorikeet_html .= "];\n";

    $lorikeet_html .= "</script>\n";


    return $lorikeet_html;
}


###############################################################################

1;

__END__
###############################################################################
###############################################################################
###############################################################################

=head1 NAME

SBEAMS::Proteomics::SpecViewer

=head1 SYNOPSIS

  Methods to dispay spectra in Lorikeet Viewer (+others?)

    use SBEAMS::Proteomics::SpecViewer;


=head1 DESCRIPTION

    This module is new.  More info to come...someday.

=head1 METHODS

=item B<generateSpectrum()>

    Generate spectrum code (mostly javascript)

=item B<convertMods()>

    Returns a string of lorikeet-ready mods based on input peptide sequence

=head1 AUTHOR

Luis Mendoza <lmendoza (at) systemsbiology dot org>

=head1 SEE ALSO

perl(1).

=cut
