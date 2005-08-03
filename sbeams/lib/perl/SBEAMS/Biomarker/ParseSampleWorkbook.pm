zckage SBEAMS::Biomarker::ParseSampleWorkbook;

###############################################################################
#
# Description :   Library code for parsing sample workbook files
#
###############################################################################

use SBEAMS::Connection;

use strict;

#### Set up new variables
use vars qw(@ISA @EXPORT);

require Exporter;
@ISA = qw (Exporter);

@EXPORT = qw (
);

sub new {
  my $class = shift;
	my $this = {};
	bless $this, $class;
	return $this;
}

#+
# Based on file format as of 2005-08-01
#-
sub parseFile {
	my $this = shift;
	my %args = @_;

	die 'Missing required parameter wbook' unless $args{wbook};

  # Array of column headings
  my @headings;
  # column heading indicies
  my %idx;

  open( WBOOK, "<$args{wbook}" ) || die "unable to open $args{wbook}";
  while( my $line = <WBOOK> ){
    chomp $line;
    my @line = split( "\t", $line, -1 );
    unless( @headings ) {
      # Meaningful headings fingerprint?
      next unless ( $line[0] =~ /Sample Setup Order/ &&
                    $line[1] =~ /MS Sample Run Number/ &&
                    $line[1] =~ /ISB Sample ID/ );
      @headings = @line;
    }


  }

}
