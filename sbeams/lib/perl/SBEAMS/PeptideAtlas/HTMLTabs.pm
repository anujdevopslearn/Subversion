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
# 
###############################################################################
sub printTabMenu 
{

    my $self = shift;

    my $sbeams = $self->getSBEAMS();

    my %args = @_;

    ## read in parameters, and store in a string to be use with url's
    my $parameters_ref = $args{parameters_ref};

    my %parametersHash = %{$parameters_ref};

    ## parse PROG_NAME to learn tab number
    my $PROG_NAME = $args{program_name};
    ##print "PROG_NAME:$PROG_NAME<BR>";

    my $current_tab=1;
    
    if ( ($PROG_NAME =~ /^GetPeptides/) || 
    ($PROG_NAME =~ /^GetPeptides\?(\S+)/ ))
    {
       $current_tab=2;

    } elsif( ($PROG_NAME =~ /^GetPeptide/) || 
    ($PROG_NAME =~ /^GetPeptide\?(\S+)/ ))
    {
       $current_tab=3;

    } elsif ( ($PROG_NAME =~ /^GetProtein/) ||
    ($PROG_NAME =~ /GetProtein\?(\S+)/ ))
    {
       $current_tab=4;

    }

    my $paramString = "\?_tab=$current_tab";
    ##print "PARAM_STRING:$paramString<BR>";

    ## add parameters to tail of string for url
    foreach my $key (%parametersHash)
    {

        my $value = $parametersHash{$key};

        unless ($value eq '')
        {
            unless ($value eq '' || $key eq "_tab")
            {
               ##print "&nbsp;&nbsp;&nbsp;KEY:&nbsp;$key&nbsp;=&nbsp;$value<BR>";
               $paramString = "$paramString&$key=$value";
            }
        }
    }
     

    ## set up tab structure:
    my $tabmenu = SBEAMS::Connection::TabMenu->
        new( cgi => $q,
             activeColor => 'ffcc99',
             inactiveColor   => 'cccccc',
             hoverColor => 'ffff99',
             atextColor => '000000', # black
             itextColor => 'ff0000', # black
             # paramName => 'mytabname', # uses this as cgi param
             # maSkin => 1,   # If true, use MA look/feel
             # isSticky => 0, # If true, pass thru cgi params
             # boxContent => 0, # If true draw line around content
             # labels => \@labels # Will make one tab per $lab (@labels)
             # _tabIndex => 0,
             # _tabs => [ 'placeholder' ]
    );

    $tabmenu->addTab( label => 'Select PeptideAtlas',
                      helptext => 'Select a PeptideAtlas to be used in neighboring tabs',
                      URL => "$CGI_BASE_DIR/PeptideAtlas/main.cgi$paramString" 
                    );

    $tabmenu->addTab( label => 'Browse Peptides',
                      helptext => 'Multi-constraint browsing of PeptideAtlas',
                      URL => "$CGI_BASE_DIR/PeptideAtlas/GetPeptides$paramString" 
                    );

    $tabmenu->addTab( label => 'Get Peptide',
                      helptext => 'Look-up info on a peptide by sequence or name',
                      URL => "$CGI_BASE_DIR/PeptideAtlas/GetPeptide$paramString"
                    );

#   $tabmenu->addTab( label => 'Browse Proteins',
#                     helptext => 'Not implemented yet',
#                     URL => "$CGI_BASE_DIR/PeptideAtlas/main.cgi"
#                     );

    $tabmenu->addTab( label => 'Get Protein',
                      helptext => 'Get an observation summary of a protein',
                      URL => "$CGI_BASE_DIR/PeptideAtlas/GetProtein$paramString"
                    );

    $tabmenu->setCurrentTab( currtab => $current_tab );

    my $content;

    if ( $tabmenu->getActiveTabName() eq 'Browse Proteins' ){

        $content = "<BR><BR>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<b>"
           ."[coming soon, not implemented yet]<B><BR><BR>";

    }

    $tabmenu->addHRule();

    $tabmenu->addContent( $content );

    ##print "ACTIVE_TAB:".$tabmenu->getActiveTab()."<BR>";
    ##print "paramString:$paramString<BR>";
    print "$tabmenu";

    return $paramString;

}

1;
__END__
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
