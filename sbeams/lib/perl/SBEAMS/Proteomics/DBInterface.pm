package SBEAMS::Proteomics::DBInterface;

###############################################################################
# Program     : SBEAMS::Proteomics::DBInterface
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This is part of the SBEAMS::Proteomics module which handles
#               general communication with the database.
#
# SBEAMS is Copyright (C) 2000-2002 by Eric Deutsch
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################


use strict;
use vars qw(@ERRORS);
use CGI::Carp qw(fatalsToBrowser croak);
use DBI;



###############################################################################
# Global variables
###############################################################################


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
# 
###############################################################################

# Add stuff as appropriate




###############################################################################

1;

__END__
###############################################################################
###############################################################################
###############################################################################
