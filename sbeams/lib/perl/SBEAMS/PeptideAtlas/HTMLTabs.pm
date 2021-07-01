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

    my $current_tab=1;
    my $current_subtab=1;

    if ( ($PROG_NAME =~ /^main.cgi|buildDetails/) ||
	 ($PROG_NAME =~ /^main.cgi\?(\S+)/ ))
    {
       $current_tab=2;

    } elsif ( ($PROG_NAME =~ /^buildInfo/) ||
	      ($PROG_NAME =~ /buildInfo\?(\S+)/ ))
    {
       $current_tab=2;
       $current_subtab=2;

    } elsif ( ($PROG_NAME =~ /^defaultBuildsPepsProts/) ||
	      ($PROG_NAME =~ /defaultBuildsPepsProts\?(\S+)/ ))
    {
       $current_tab=2;
       $current_subtab=3;

    } elsif ( ($PROG_NAME =~ /^SearchProteins/) ||
	      ($PROG_NAME =~ /SearchProteins\?(\S+)/ ))
    {
       $current_tab=4;
       $current_subtab=5;

    } elsif( ($PROG_NAME =~ /^Search/) ||
	     ($PROG_NAME =~ /^Search\?(\S+)/ ))
    {
       $current_tab=1;

    } elsif( ($PROG_NAME =~ /^GetPeptides/) ||
	     ($PROG_NAME =~ /^GetPeptides\?(\S+)/ ))
    {
       $current_tab=4;

    } elsif ($PROG_NAME=~ /^GetNextProtChromMapping/ || 
	     $PROG_NAME =~ /^GetNextProtChromMapping\?(\S+)/ ) {
       $current_tab=4;
       $current_subtab=3;

     }elsif( ($PROG_NAME =~ /^GetPeptide/) ||
	     ($PROG_NAME =~ /^GetPeptide\?(\S+)/ ))
    {
       $current_tab=3;

    } elsif ( ($PROG_NAME =~ /^GetProteins/) ||
	      ($PROG_NAME =~ /GetProteins\?(\S+)/ ))
    {
       $current_tab=4;
       $current_subtab=2;

    } elsif ( ($PROG_NAME =~ /^CompareBuildsProteins/) ||
	      ($PROG_NAME =~ /CompareBuildsProteins\?(\S+)/ ))
    {
       $current_tab=4;
       $current_subtab=4;

    } elsif ( ($PROG_NAME =~ /^showPathways/) ||
	      ($PROG_NAME =~ /showPathways\?(\S+)/ ))
    {
       $current_tab=4;
       $current_subtab=6;

    } elsif ( ($PROG_NAME =~ /proteinList/) || ($PROG_NAME =~ /MapSearch/ )) {
       $current_tab=4;
       $current_subtab=7;

    } elsif ( ($PROG_NAME =~ /^GetTransitions/) ||
	      ($PROG_NAME =~ /ViewSRMList\?(\S+)/ ))
    {
       $current_tab=5;
       $current_subtab=1;

    } elsif ( ($PROG_NAME =~ /^quant_info/) ||
	      ($PROG_NAME =~ /ViewSRMList\?(\S+)/ ))
    {
       $current_tab=5;
       $current_subtab=1;

    } elsif ( ($PROG_NAME =~ /^GetProtein/) ||
	      ($PROG_NAME =~ /GetProtein\?(\S+)/ ))
    {
       $current_tab=3;
       $current_subtab=2;

    }elsif ( ($PROG_NAME =~ /^Summarize_Peptide/) ||
	     ($PROG_NAME =~ /Summarize_Peptide\?(\S+)/ ))
    {
       $current_tab=2;
       $current_subtab=4;

    }elsif ( ($PROG_NAME =~ /^viewOrthologs/) ||
	     ($PROG_NAME =~ /viewOrthologs\?(\S+)/ ))
    {
       $current_tab=2;
       $current_subtab=5;

    }elsif ( ($PROG_NAME =~ /^GetTransitionLists/) ||
	     ($PROG_NAME =~ /GetTransitionLists\?(\S+)/ ))
    {
       $current_tab=5;
       $current_subtab=2;
    }elsif ( ($PROG_NAME =~ /^ViewSRMBuild/) ||
	     ($PROG_NAME =~ /ViewSRMBuild\?(\S+)/ ))
    {
       $current_tab=5;
       $current_subtab=3;
    }elsif ( ($PROG_NAME =~ /^GetSELExperiments/) ||
	     ($PROG_NAME =~ /GetSELExperiments\?(\S+)/ ))
    {
       $current_tab=5;
       $current_subtab=4;
    }elsif ( ($PROG_NAME =~ /^GetSELTransitions/) ||
	     ($PROG_NAME =~ /GetSELTransitions\?(\S+)/ ))
    {
       $current_tab=5;
       $current_subtab=5;


    #### PeptideAtlas Submission System PASS tabs
    } elsif ($PROG_NAME =~ /^PASS_Summary/) {
       $current_tab=6;
       $current_subtab=1;
    } elsif ($PROG_NAME =~ /^PASS_Submit/) {
       $current_tab=6;
       $current_subtab=2;
    } elsif ($PROG_NAME =~ /^PASS_View/) {
       $current_tab=6;
       $current_subtab=3;
 

    #### SWATH Atlas tabs
    } elsif ($PROG_NAME =~ /DIA_library_download/) {
       $current_tab=7;
       $current_subtab=1;
    } elsif ($PROG_NAME =~ /DIA_library_subset/) {
       $current_tab=7;
       $current_subtab=2;
    } elsif ($PROG_NAME =~ /Upload_library/) {
       $current_tab=7;
       $current_subtab=3;
    } elsif ($PROG_NAME =~ /AssessDIALib/) {
       $current_tab=7;
       $current_subtab=4;

    } elsif ($PROG_NAME eq 'none') {
      $current_tab=99;
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
			 label => 'Browse neXtProt Proteins',
			 helptext => 'Browsing neXtProt Proteins Chromosome mapping and PeptideAtlas observabiligy',
			 url => "$CGI_BASE_DIR/PeptideAtlas/GetNextProtChromMapping"
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
			   label => 'Upload Library',
			   helptext => 'Uploading DIA spectral ion libraries at SWATHAtlas',
			   url => "http://www.swathatlas.org/uploadlibrary.php"
	);
    $tabmenu->addMenuItem( tablabel => 'SWATH/DIA',
			   label => 'Assess Library',
			   helptext => 'Assess physical properties of DIA Library',
			   url => "$CGI_BASE_DIR/SWATHAtlas/AssessDIALibrary"
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
