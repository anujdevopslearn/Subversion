package SBEAMS::Connection;

###############################################################################
# Program     : SBEAMS::Connection
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : Perl Module to handle all SBEAMS connection issues, including
#               authentication and DB connections.
#
###############################################################################


use strict;
use vars qw($VERSION @ISA);

use vars qw($invocation_mode $output_mode $output_stage $table_nest_level
           );


use SBEAMS::Connection::Authenticator;
use SBEAMS::Connection::DBConnector;
use SBEAMS::Connection::DBInterface;
use SBEAMS::Connection::HTMLPrinter;
use SBEAMS::Connection::TableInfo;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::ErrorHandler;
use SBEAMS::Connection::Utilities;
use SBEAMS::Connection::Permissions;


@ISA = qw(SBEAMS::Connection::Authenticator 
          SBEAMS::Connection::DBConnector
          SBEAMS::Connection::DBInterface 
          SBEAMS::Connection::HTMLPrinter
          SBEAMS::Connection::TableInfo
          SBEAMS::Connection::Settings
          SBEAMS::Connection::ErrorHandler
          SBEAMS::Connection::Utilities
          SBEAMS::Connection::Permissions
         );


###############################################################################
# Global Variables
###############################################################################
$VERSION = '0.02';


###############################################################################
# Constructor
###############################################################################
sub new {
  my $this = shift;
  my $class = ref($this) || $this;
  my $self = {};
  bless($self,$class);
  $self->register_sbeams($self);
  return($self);

} # end new


###############################################################################
# Getter/setter for invocation_mode
###############################################################################
sub invocation_mode {
  my $self = shift;
  my $new_value = shift;

  my $METHOD_NAME = "invocation_mode()";

  #### If a new value was supplied, set it
  if ($new_value) {
    die "$METHOD_NAME: Illegal value '$new_value'"
      unless ($new_value eq 'http' || $new_value eq 'user');
    $invocation_mode = $new_value;

  #### Otherwise, verify that we have a value or set a blank
  } else {
    #die "$METHOD_NAME: value has not yet been set!"
    $invocation_mode = ""
      unless ($invocation_mode);
  }

  #### Return the current value in either case
  return $invocation_mode;

} # end invocation_mode


###############################################################################
# Getter/setter for output_mode
###############################################################################
sub output_mode {
  my $self = shift;
  my $new_value = shift;

  my $METHOD_NAME = "output_mode()";

  #### If a new value was supplied, set it
  if ($new_value) {
    die "$METHOD_NAME: Illegal value '$new_value'"
      unless ($new_value eq 'html' || $new_value eq 'interactive' ||
              $new_value eq 'tsv' || $new_value eq 'xml' ||
              $new_value eq 'boxtable' || $new_value eq 'excel'
      );
    $output_mode = $new_value;

  #### Otherwise, verify that we have a value
  } else {
    unless ($output_mode) {
      print "$METHOD_NAME: value has not yet been set!  This should never ".
        "happen, but I will set it to interactive just to see where this ".
        "ends up.  It is almost surely a bug that needs ".
        "to be reported.<BR><BR>\n\n";
      $output_mode = $self->output_mode('interactive');
    }
  }

  #### Return the current value in either case
  return $output_mode;

} # end output_mode


###############################################################################
# Getter/setter for output_stage
###############################################################################
sub output_stage {
  my $self = shift;
  my $new_value = shift;

  my $METHOD_NAME = "output_stage()";

  #### If a new value was supplied, set it
  if ($new_value) {
    die "$METHOD_NAME: Illegal value '$new_value'"
      unless ($new_value eq 'no_header_yet' || $new_value eq 'form_stage' ||
              $new_value eq 'data_stage' || $new_value eq 'footer_complete'
      );
    $output_stage = $new_value;

  #### Otherwise, verify that we have a value
  } else {
    die "$METHOD_NAME: value has not yet been set!"
      unless ($output_stage);
  }

  #### Return the current value in either case
  return $output_stage;

} # end output_stage


###############################################################################
# Getter/setter for table_nest_level
###############################################################################
sub table_nest_level {
  my $self = shift;
  my $new_value = shift;

  my $METHOD_NAME = "table_nest_level()";

  #### If a new value was supplied, set it
  if ($new_value) {
    die "$METHOD_NAME: Illegal value '$new_value'"
      unless ($new_value >= 0);
    $table_nest_level = $new_value;

  #### Otherwise, verify that we have a reasonable value
  } else {
    $table_nest_level = 0 unless ($table_nest_level);
  }

  #### Return the current value in either case
  return $table_nest_level;

} # end table_nest_level







###############################################################################

1;

__END__
###############################################################################
###############################################################################
###############################################################################
