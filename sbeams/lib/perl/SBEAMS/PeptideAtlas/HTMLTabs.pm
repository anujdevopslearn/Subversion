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

##our $VERSION = '0.20'; can get this from Settings::get_sbeams_version


###############################################################################
# Constructor
###############################################################################
sub new 
{
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
sub getTabMenu
{

    my $self = shift;

    my $sbeams = $self->getSBEAMS();

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

    } elsif ( ($PROG_NAME =~ /^SearchProteins/) ||
    ($PROG_NAME =~ /SearchProteins\?(\S+)/ ))
    {
       $current_tab=4;
       $current_subtab=3;

    } elsif( ($PROG_NAME =~ /^Search/) ||
    ($PROG_NAME =~ /^Search\?(\S+)/ ))
    {
       $current_tab=1;

    } elsif( ($PROG_NAME =~ /^GetPeptides/) ||
    ($PROG_NAME =~ /^GetPeptides\?(\S+)/ ))
    {
       $current_tab=4;

    } elsif( ($PROG_NAME =~ /^GetPeptide/) ||
    ($PROG_NAME =~ /^GetPeptide\?(\S+)/ ))
    {
       $current_tab=3;

    } elsif ( ($PROG_NAME =~ /^GetProteins/) ||
    ($PROG_NAME =~ /GetProteins\?(\S+)/ ))
    {
       $current_tab=4;
       $current_subtab=2;

    } elsif ( ($PROG_NAME =~ /^showPathways/) ||
    ($PROG_NAME =~ /showPathways\?(\S+)/ ))
    {
       $current_tab=4;
       $current_subtab=4;

    } elsif ( ($PROG_NAME =~ /^GetTransitions/) ||
    ($PROG_NAME =~ /ViewMRMList\?(\S+)/ ))
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
       $current_subtab=2;

    }elsif ( ($PROG_NAME =~ /^GetTransitionLists/) ||
    ($PROG_NAME =~ /GetTransitionLists\?(\S+)/ ))
    {
       $current_tab=5;
       $current_subtab=2;
    }elsif ( ($PROG_NAME =~ /^ViewMRMBuild/) ||
    ($PROG_NAME =~ /ViewMRMBuild\?(\S+)/ ))
    {
       $current_tab=5;
       $current_subtab=3;
    }




    ## set up tab structure:
    my $tabmenu = SBEAMS::Connection::TabMenu->
        new( cgi => $q,
             activeColor => 'f3f1e4',
             inactiveColor   => 'c6c1b8',
             hoverColor => 'f3f1e4',
             atextColor => '000000', # black
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


    $tabmenu->addTab( label => 'Search',
                      helptext => 'Search PeptideAtlas by keyword',
                      URL => "$CGI_BASE_DIR/PeptideAtlas/Search"
                    );


    $tabmenu->addTab( label => 'All Builds' );

    $tabmenu->addMenuItem( tablabel => 'All Builds',
			   label => 'Select Build',
			   helptext => 'Select a preferred PeptideAtlas build',
			   url => "$CGI_BASE_DIR/PeptideAtlas/main.cgi"
			   );

    $tabmenu->addMenuItem( tablabel => 'All Builds',
			   label => 'Summarize Peptide',
			   helptext => 'Browsing the basic information about a peptide',
			   url => "$CGI_BASE_DIR/PeptideAtlas/Summarize_Peptide"
			   );

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
			   label => 'Search Proteins',
			   helptext => 'Search for a list of proteins',
			   url => "$CGI_BASE_DIR/PeptideAtlas/SearchProteins"
			   );

    $tabmenu->addMenuItem( tablabel => 'Queries',
			   label => 'Pathways',
			   helptext => 'Show PeptideAtlas coverage for a KEGG pathway',
			   url => "$CGI_BASE_DIR/PeptideAtlas/showPathways"
			   );

    $tabmenu->addTab( label => 'MRM Atlas' );

    $tabmenu->addMenuItem( tablabel => 'MRM Atlas',
			   label => 'Query Transitions',
			   helptext => 'Query for MRM Transitions',
			   url => "$CGI_BASE_DIR/PeptideAtlas/GetTransitions"
			   );

    $tabmenu->addMenuItem( tablabel => 'MRM Atlas',
			   label => 'Transition Lists',
			   helptext => 'Download and upload validated MRM transition lists',
			   url => "$CGI_BASE_DIR/PeptideAtlas/GetTransitionLists"
			   );

    $tabmenu->addMenuItem( tablabel => 'MRM Atlas',
			   label => 'MRM Atlas Builds',
			   helptext => 'View statistics on available MRM Atlas builds',
			   url => "$CGI_BASE_DIR/PeptideAtlas/ViewMRMBuild"
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
