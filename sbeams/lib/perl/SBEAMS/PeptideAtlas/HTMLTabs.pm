package SBEAMS::PeptideAtlas::HTMLTabs;

###############################################################################
# Program     : SBEAMS::PeptideAtlas::HTMLTabs
# Author      : Nichole King <nking@systemsbiology.org>
#
# Description : This is part of the SBEAMS::WebInterface module.  It constructs
#               a tab menu to help select cgi pages.
###############################################################################

use 5.008;

use strict;

use vars qw(@ERRORS $q @EXPORT @EXPORT_OK);
use CGI::Carp qw(fatalsToBrowser croak);
use Exporter;
our @ISA = qw( Exporter );

use SBEAMS::Connection qw( $q );
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::Log;
use SBEAMS::Connection::TabMenu;

use SBEAMS::PeptideAtlas::Tables;


my $log = SBEAMS::Connection::Log->new();
my $sbeams;

##our $VERSION = '0.20'; can get this from Settings::get_sbeams_version


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
# printTabMenu
###############################################################################
sub printTabMenu {
  my $self = shift;
  my $tabMenu = $self->getTabMenu(@_);
  print $tabMenu->asHTML();
}


###############################################################################
# getTabMenu
###############################################################################
sub getTabMenu {
    my $self = shift;

    $sbeams = $self->getSBEAMS();

    my %args = @_;

    ## read in parameters, and store in a string to be use with url's
    my $parameters_ref = $args{parameters_ref};
    my %parametersHash = %{$parameters_ref};


    ## parse PROG_NAME to learn tab number
    my $PROG_NAME = $args{program_name};
    $PROG_NAME =~ s/\s+$//;

    #### Search, tab = 1
    #### All Builds, tab = 2
    #### Current Build, tab = 3
    #### Queries, tab = 4
    #### SRMAtlas, tab = 5
    #### PeptideAtlas Submission System PASS tabs, tab = 6
    #### SWATH tabs, tab = 7
    my %sub_tabs;
    my @html_tabs =("Search",
										"All Builds",
										"Current Build",
										"Queries",
										"SRMAtlas",
										"Submission",
										"SWATH/DIA"
										);
    
    %{$sub_tabs{"All Builds"}} = (
                       "buildDetails" => 1,
                       "main.cgi" => 1,
                       "buildInfo" => 2,
                       "defaultBuildsPepsProts" => 3,
                       "Summarize_Peptide" => 4,
                       "viewOrthologs" => 5                  
                       );
    %{$sub_tabs{"Current Build"}} = (
                       "GetPeptide" => 1,
                       "GetProtein" => 2,
                       );

   %{$sub_tabs{"Queries"}} = (
                       "GetPeptides" => 1,
                       "GetProteins" => 2,
                       "GetCoreProteomeMapping" => 3,
                       "GetPTMSummary" => 4,
                       "GetProteinsByExperiment" => 5, 
                       "CompareBuildsProteins" => 6,
                       "SearchProteins" => 7,
                       "showPathways" => 8,
                       "proteinList" => 9,
                       "MapSearch" => 9
                      );
  %{$sub_tabs{"SRMAtlas"}} = (
                       "GetTransitions" => 1,
                       "ViewSRMList" => 1,
                       "quant_info" => 1,
                       "GetTransitionLists" => 2,
                       "ViewSRMBuild" => 3,
                       "GetSELExperiments" => 4,
                       "GetSELTransitions" => 5
                     );
  %{$sub_tabs{"Submission"}} = (
                       "PASS_Summary" => 1,
                       "PASS_Submit" => 2,
                       "PASS_View" => 3,
                     );
  %{$sub_tabs{"SWATH/DIA"}} = (
                       "DIA_library_download" => 1,
                       "DIA_library_subset" => 2,
                       "AssessDIALibrary" => 3,
                       "Upload_library" => 4,
                     );

    my $current_tab=1;
    my $current_subtab=1;
    for (my $i; $i <= $#html_tabs; $i++){
       if ($PROG_NAME eq 'Search'){
         last;
       }elsif($PROG_NAME eq 'none') {
         $current_tab = 99;
         last;
       } 

       foreach my $sub_tab (keys %{$sub_tabs{$html_tabs[$i]}}){
          if ($PROG_NAME =~ /(\/$sub_tab|^$sub_tab)$/){
             $current_tab = $i+1;
             $current_subtab = $sub_tabs{$html_tabs[$i]}{$sub_tab};
          } 
       }
    }  


    ## set up tab structure:
    my $tabmenu = SBEAMS::Connection::TabMenu->
        new( %args,
             cgi => $q,
             activeColor   => 'f3f1e4',
             inactiveColor => 'd3d1c4',
             hoverColor => '22eceb',
             atextColor => '5e6a71', # ISB gray
             itextColor => 'ff0000', # red
             isDropDown => '1',
             extra_width => 650,
             # paramName => 'mytabname', # uses this as cgi param
             # maSkin => 1,   # If true, use MA look/feel
             # isSticky => 0, # If true, pass thru cgi params
             # boxContent => 0, # If true draw line around content
             # labels => \@labels # Will make one tab per $lab (@labels)
             # _tabIndex => 0,
             # _tabs => [ 'placeholder' ]
    );


    #### Search, tab = 1
    $tabmenu->addTab( label => 'Search',
                      helptext => 'Search PeptideAtlas by keyword',
                      URL => "$CGI_BASE_DIR/PeptideAtlas/Search"
                    );


    #### All Builds, tab = 2
    $tabmenu->addTab( label => 'All Builds' );

    $tabmenu->addMenuItem( tablabel => 'All Builds',
			   label => 'Select Build',
			   helptext => 'Select a preferred PeptideAtlas build',
			   url => "$CGI_BASE_DIR/PeptideAtlas/main.cgi"
			   );

    $tabmenu->addMenuItem( tablabel => 'All Builds',
			   label => 'Stats &amp; Lists',
			   helptext => 'Get stats, retrieve peptide and protein lists for all builds',
			   url => "$CGI_BASE_DIR/PeptideAtlas/buildInfo"
			   );

    $tabmenu->addMenuItem( tablabel => 'All Builds',
			   label => 'Peps &amp; Prots for Default Builds',
			   helptext => 'Retrieve peptide and protein lists for default builds',
			   url => "$CGI_BASE_DIR/PeptideAtlas/defaultBuildsPepsProts"
			   );

    $tabmenu->addMenuItem( tablabel => 'All Builds',
			   label => 'Summarize Peptide',
			   helptext => 'Browsing the basic information about a peptide',
			   url => "$CGI_BASE_DIR/PeptideAtlas/Summarize_Peptide"
			   );

    $tabmenu->addMenuItem( tablabel => 'All Builds',
			   label => 'View Ortholog Group',
			   helptext => 'View OrthoMCL orthologs group',
			   url => "$CGI_BASE_DIR/PeptideAtlas/viewOrthologs?use_default=1"
			   );

    #### Current Build, tab = 3
    $tabmenu->addTab( label => 'Current Build' );

    $tabmenu->addMenuItem( tablabel => 'Current Build',
			   label => 'Peptide',
			   helptext => 'View information about a peptide',
			   url => "$CGI_BASE_DIR/PeptideAtlas/GetPeptide"
			   );

    $tabmenu->addMenuItem( tablabel => 'Current Build',
			   label => 'Protein',
			   helptext => 'View information about a protein',
			   url => "$CGI_BASE_DIR/PeptideAtlas/GetProtein"
			   );


    #### Queries, tab = 4
    $tabmenu->addTab( label => 'Queries' );

    $tabmenu->addMenuItem( tablabel => 'Queries',
			   label => 'Browse Peptides',
			   helptext => 'Multi-constraint browsing of PeptideAtlas Peptides',
			   url => "$CGI_BASE_DIR/PeptideAtlas/GetPeptides"
			   );

    $tabmenu->addMenuItem( tablabel => 'Queries',
			   label => 'Browse Proteins',
			   helptext => 'Multi-constraint browsing of PeptideAtlas Proteins',
			   url => "$CGI_BASE_DIR/PeptideAtlas/GetProteins"
			   );
    $tabmenu->addMenuItem( tablabel => 'Queries',
			 label => 'Browse Core Proteome',
			 helptext => 'Browsing Core Proteome Chromosome mapping and PeptideAtlas observabiligy',
			 url => "$CGI_BASE_DIR/PeptideAtlas/GetCoreProteomeMapping"
			 );

    $tabmenu->addMenuItem( tablabel => 'Queries',
       label => 'Browse PTM Summary',
       helptext => 'Browsing PTM Summary Table in PTM Builds',
       url => "$CGI_BASE_DIR/PeptideAtlas/GetPTMSummary"
       );

    $tabmenu->addMenuItem( tablabel => 'Queries',
         label => 'Browse Protein By Experiment',
         helptext => 'Browsing proteins identfied in each expreiment',
         url => "$CGI_BASE_DIR/PeptideAtlas/GetProteinsByExperiment"
         );

    $tabmenu->addMenuItem( tablabel => 'Queries',
			   label => 'Compare Proteins in 2 Builds',
			   helptext => 'Display proteins identified in both of two specified PeptideAtlas builds',
			   url => "$CGI_BASE_DIR/PeptideAtlas/CompareBuildsProteins"
			   );

    $tabmenu->addMenuItem( tablabel => 'Queries',
			   label => 'Search Proteins',
			   helptext => 'Search for a list of proteins',
			   url => "$CGI_BASE_DIR/PeptideAtlas/SearchProteins"
			   );
    $tabmenu->addMenuItem( tablabel => 'Queries',
			   label => 'Pathways',
			   helptext => 'Show PeptideAtlas coverage for a KEGG pathway',
			   url => "$CGI_BASE_DIR/PeptideAtlas/showPathways"
			   );
    $tabmenu->addMenuItem( tablabel => 'Queries',
			   label => 'HPP Protein Lists',
			   helptext => 'HPP B/D Protein Lists',
			   url => "$CGI_BASE_DIR/PeptideAtlas/proteinListSelector"
			   );


    #### SRMAtlas, tab = 5
    $tabmenu->addTab( label => 'SRMAtlas' );

    $tabmenu->addMenuItem( tablabel => 'SRMAtlas',
			   label => 'Query Transitions',
			   helptext => 'Query for SRM Transitions',
			   url => "$CGI_BASE_DIR/PeptideAtlas/GetTransitions"
			   );

    $tabmenu->addMenuItem( tablabel => 'SRMAtlas',
			   label => 'Transition Lists',
			   helptext => 'Download and upload validated SRM transition lists',
			   url => "$CGI_BASE_DIR/PeptideAtlas/GetTransitionLists"
			   );

    $tabmenu->addMenuItem( tablabel => 'SRMAtlas',
			   label => 'SRMAtlas Builds',
			   helptext => 'View statistics on available SRMAtlas builds',
			   url => "$CGI_BASE_DIR/PeptideAtlas/ViewSRMBuild"
			   );


    $tabmenu->addMenuItem( tablabel => 'SRMAtlas',
			   label => 'PASSEL Experiments',
			   helptext => 'Browse SRM experiments',
			   url => "$CGI_BASE_DIR/PeptideAtlas/GetSELExperiments"
	);

    $tabmenu->addMenuItem( tablabel => 'SRMAtlas',
			   label => 'PASSEL Data',
			   helptext => 'View transition groups for SRM experiments',
			   url => "$CGI_BASE_DIR/PeptideAtlas/GetSELTransitions"
	);


    #### PeptideAtlas Submission System PASS tabs, tab = 6
    $tabmenu->addTab( label => 'Submission',
		      label => 'Submission',
		      helptext => 'Submit or access datasets',
		      url => "$CGI_BASE_DIR/PeptideAtlas/PASS_Submit"
	);
    $tabmenu->addMenuItem( tablabel => 'Submission',
			   label => 'Datasets Summary',
			   helptext => 'View/manage submitted datasets',
			   url => "$CGI_BASE_DIR/PeptideAtlas/PASS_Summary"
			   );
    $tabmenu->addMenuItem( tablabel => 'Submission',
			   label => 'Submit Dataset',
			   helptext => 'Submit a datasets to one of the PeptideAtlas resources',
			   url => "$CGI_BASE_DIR/PeptideAtlas/PASS_Submit"
			   );
    $tabmenu->addMenuItem( tablabel => 'Submission',
			   label => 'View Dataset',
			   helptext => 'View/access a previously submitted dataset',
			   url => "$CGI_BASE_DIR/PeptideAtlas/PASS_View"
			   );


    #### SWATH tabs, tab = 7
    $tabmenu->addTab( label => 'SWATH/DIA',
		      helptext => 'Resource for data independent analysis',
        );
    $tabmenu->addMenuItem( tablabel => 'SWATH/DIA',
			   label => 'Download Library',
			   helptext => 'Download libraries in various formats',
			   url => "$CGI_BASE_DIR/SWATHAtlas/GetDIALibs?mode=download_libs"
	);
    $tabmenu->addMenuItem( tablabel => 'SWATH/DIA',
			   label => 'Custom Library',
			   helptext => 'Generate custom subset libraries',
			   url => "$CGI_BASE_DIR/SWATHAtlas/GetDIALibs?mode=subset_libs"
	);
    $tabmenu->addMenuItem( tablabel => 'SWATH/DIA',
			   label => 'Assess Library',
			   helptext => 'Assess physical properties of DIA Library',
			   url => "$CGI_BASE_DIR/SWATHAtlas/AssessDIALibrary"
	);
    $tabmenu->addMenuItem( tablabel => 'SWATH/DIA',
			   label => 'Upload Library',
			   helptext => 'Uploading DIA spectral ion libraries at SWATHAtlas',
			   url => "http://www.swathatlas.org/uploadlibrary.php"
	);


    $tabmenu->setCurrentTab( currtab => $current_tab, currsubtab => $current_subtab );

    return($tabmenu);
}


###############################################################################
1;
__END__


###############################################################################
###############################################################################
###############################################################################
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

  HTMLTabs - module for tabs used by the PeptideAtlas cgi pages

=head1 SYNOPSIS

  use SBEAMS::PeptideAtlas;

=head1 ABSTRACT


=head1 DESCRIPTION


=head2 EXPORT

None by default.



=head1 SEE ALSO

GetPeptide, GetPeptides, GetProtein

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

Nichole King, E<lt>nking@localdomainE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 by Institute for Systems Biology

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
