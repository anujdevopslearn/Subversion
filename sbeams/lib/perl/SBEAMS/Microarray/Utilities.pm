package SBEAMS::Microarray::Utilities;

###############################################################################
# Program     : SBEAMS::Microarray::Utilities
# $Id: Utilities.pm 3844 2005-09-02 18:39:07Z dcampbel $
#
# Description : Utility methods for Microarray module.
#
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################


use strict;

use SBEAMS::Connection::Settings;
use SBEAMS::Connection::TableInfo;

use SBEAMS::Microarray::Settings;

my $sbeams = SBEAMS::Connection->new();


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

sub copyDataLoaderTemplate {
  my $self = shift;
  my %args = @_;

  my $baseurl = $args{cgi}->url( -base => 1 );
  
  my $token = $args{token} || die "missing required token";
  open FIL, "$PHYSICAL_BASE_DIR/lib/meta_data_loader/Microarray/GetExpression/MetaDataLoaderTemplate.jnlp";
  open OUTFIL, ">$PHYSICAL_BASE_DIR/tmp/Microarray/dataLoader/Affy/$token.jnlp";
  {
    undef local $/;
    my $temp = <FIL>;
    close FIL;
    $temp =~ s/SERVER_ROOT/$baseurl/g;
    $temp =~ s/TOKEN_NAME/$token/g;
    print OUTFIL $temp;
    close OUTFIL;
  }

}

sub get_cytoscape_makefile {
  my $self = shift;
  my $jar_cmd = $sbeams->get_jar_create_cmd( 'data.jar' );
  my $jsign_cmd = $sbeams->get_jar_signing_cmd( 'data.jar' );
  return qq~
jar:
     $jar_cmd \
       cytoscape.props \
       project-jnlp \
       vizmap.props \
       network.sif \
       biosequence_name.noa \
       reporter_name.noa \
       common_name.noa \
       external_identifier.noa\
       gene_name.noa \
       second_name.noa \
       full_name.noa \
       NodeType.noa \
       Expression_edges.eda \
       Significance_edges.eda 

     $jsign_cmd 
  ~;
}

# Routine determines if current project is writable ( should allow bioconductor
# pipeline usage 
sub is_pipeline_project {
  my $self = shift;
  my $sbeams = $self->getSBEAMS();
  my $project = $self->getCurrent_project_id();
  
  for my $writable ( $self->getWritableProjects() ) {
    return 1 if $writable == $project;
  }
  return 0;
}
