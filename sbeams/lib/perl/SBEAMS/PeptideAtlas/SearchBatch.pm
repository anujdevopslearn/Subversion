package SBEAMS::PeptideAtlas::SearchBatch;

###############################################################################
# Class       : SBEAMS::PeptideAtlas::SearchBatch
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
#
=head1 SBEAMS::PeptideAtlas::SearchBatch

=head2 SYNOPSIS

  SBEAMS::PeptideAtlas::SearchBatch

=head2 DESCRIPTION

This is part of the SBEAMS::PeptideAtlas module which handles
search batch related things.

=cut
#
###############################################################################

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
require Exporter;
@ISA = qw();
$VERSION = q[$Id$];
@EXPORT_OK = qw();

use SBEAMS::Connection qw( $log );
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::Settings;
use SBEAMS::PeptideAtlas::Tables;

use XML::Parser;

my $sbeams = SBEAMS::Connection->new();
my %spectra;

###############################################################################
# Global variables
###############################################################################
use vars qw($VERBOSE $TESTONLY $sbeams);


###############################################################################
# Constructor
###############################################################################
sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;
    $sbeams = $self->getSBEAMS();
    return($self);
} # end new


###############################################################################
# setSBEAMS: Receive the main SBEAMS object
###############################################################################
sub setSBEAMS {
    my $self = shift;
    $sbeams = shift;
    return($sbeams);
} # end setSBEAMS



###############################################################################
# getSBEAMS: Provide the main SBEAMS object
###############################################################################
sub getSBEAMS {
    my $self = shift;
    return $sbeams || SBEAMS::Connection->new();
} # end getSBEAMS

# convenience method to look up hash of proteomics search batch to atlas SB
sub getProtSB2AtlasSB {
	my $self = shift;
	my %args = @_;
	my $where = '';
	if ( $args{build_id} ) {
		if ( ref $args{build_id} ne 'ARRAY' ) {
			die "build_id must be an array reference, not a " . ref $args{build_id};
		}
		$where = "WHERE atlas_build_id IN ( " . join( ',', @{$args{build_id}} ) . ' )';
	}
  my $sql = qq~
    SELECT DISTINCT proteomics_search_batch_id, ASB.atlas_search_batch_id
    FROM $TBAT_ATLAS_SEARCH_BATCH ASB
		JOIN $TBAT_ATLAS_BUILD_SEARCH_BATCH ABSB
	    ON ASB.atlas_search_batch_id = ABSB.atlas_search_batch_id
	  $where
  ~;

  my $sth = $sbeams->get_statement_handle( $sql );
  
  my %mapping;
  while( my $row = $sth->fetchrow_arrayref() ) {
    if ( $mapping{$row->[0]} ) {
      $log->warn( "Doppelganger! more than one Atlas SB for Prot SB $row->[0]\n" );
    }
    $mapping{$row->[0]} = $row->[1];
  }
  return \%mapping;
}


#+
# method to look up hash atlas SB to peptide_source_type
#-
sub getAtlasSB2PeptideSrcType {
	my $self = shift;
	my %args = @_;
	my $where = '';
	if ( $args{build_id} ) {
		if ( ref $args{build_id} ne 'ARRAY' ) {
			die "build_id must be an array reference, not a " . ref $args{build_id};
		}
		$where = "WHERE atlas_build_id IN ( " . join( ',', @{$args{build_id}} ) . ' )';
	}
  my $sql = qq~
    SELECT DISTINCT ASB.atlas_search_batch_id, S.peptide_source_type
    FROM $TBAT_ATLAS_SEARCH_BATCH ASB
		JOIN $TBAT_SAMPLE S
	    ON ASB.sample_id = S.sample_id
	  $where
  ~;

  my $sth = $sbeams->get_statement_handle( $sql );
  
  my %mapping;
  while( my $row = $sth->fetchrow_arrayref() ) {
    $mapping{$row->[0]} = $row->[1];
  }
  return \%mapping;
}


# convenience method to look up hash of proteomics search batch to sample
sub getSearchBatch2Sample {
	my $self = shift;
	my %args = @_;
	my $where = '';
	if ( $args{build_id} ) {
		if ( ref $args{build_id} ne 'ARRAY' ) {
			die "build_id must be an array reference, not a " . ref $args{build_id};
		}
		$where = "WHERE atlas_build_id IN ( " . join( ',', @{$args{build_id}} ) . ' )';
	}
  my $sql = qq~
    SELECT DISTINCT proteomics_search_batch_id, ASB.sample_id
    FROM $TBAT_ATLAS_SEARCH_BATCH ASB
		JOIN $TBAT_ATLAS_BUILD_SEARCH_BATCH ABSB
	    ON ASB.atlas_search_batch_id = ABSB.atlas_search_batch_id
	  $where
  ~;
#	print "$sql\n";

  my $sth = $sbeams->get_statement_handle( $sql );
  
  my %mapping;
  while( my $row = $sth->fetchrow_arrayref() ) {
    if ( $mapping{$row->[0]} ) {
      $log->warn( "Doppelganger! more than one sample_id for prot_search_batch $row->[0]\n" );
    }
    $mapping{$row->[0]} = $row->[1];
  }
  return \%mapping;
}

sub getBuildSearchBatches {
	my $self = shift;
	my %args = @_;
	my $where = '';
	unless ( $args{build_id} ) {
		die "Missing required parameter build_id";
	}
	my $batch_clause = $args{batch_clause} || '';
  my $sql = qq~
  SELECT DISTINCT proteomics_search_batch_id, ASB.sample_id, 
	                data_location, ASB.atlas_search_batch_id,
									search_batch_subdir
  FROM $TBAT_ATLAS_SEARCH_BATCH ASB
  JOIN $TBAT_ATLAS_BUILD_SEARCH_BATCH ABSB
    ON ASB.atlas_search_batch_id = ABSB.atlas_search_batch_id
  WHERE atlas_build_id = $args{build_id}
	$batch_clause
	ORDER BY proteomics_search_batch_id DESC
  ~;

  my $sth = $sbeams->get_statement_handle( $sql );
  
  my @batches;
  while( my @row = $sth->fetchrow_array() ) {

		my $data_location = $RAW_DATA_DIR{Proteomics} . '/' . $row[2] . '/' . $row[4];
		push @batches, { proteomics_search_batch_id => $row[0],
		                sample_id => $row[1], 
	                  data_location => $data_location,
										atlas_search_batch_id => $row[3] };
  }                  
	return \@batches
}

#+
#  Routine to find appropriate pepXML file.
#  @narg search_path       Required, path to search directory
#  @narg preferred_names   Optional, array_ref to list of file names to search preferentially.
#
#-
sub findPepXMLFile  {
	my $self = shift;
  my %args = @_;

  for my $arg ( qw( search_path ) ) {
	  $sbeams->missing_constraint( constraint => 'search_path' ) unless $args{$arg};
	}
                                                                                                          
	unless ( $args{search_path} =~ /\/$/ ) {
	  $args{search_path} .= '/';
	}

  # First prepend any caller-preferred names
  my @possible_names;
	if ( $args{preferred_names} ) {
		if ( ref( $args{preferred_names} ) eq 'ARRAY' ) {
			@possible_names = @{$args{preferred_names}};
		} elsif ( $args{preferred_names} ) {
			push @possible_names, $args{preferred_names};
		}
	}

        # prefer iProphet output over PeptideProphet
	push @possible_names,
                        'interact-combined.pep.xml',  #iProphet
                        'interact-ipro.pep.xml',      #iProphet
                        'interact-ipro.pep.xml.gz',
                        'interact-prob.pep.xml',
                        'interact-prob.xml',
                        'interact.pep.xml',
                        'interact.xml',
                        'interact-specall.xml',
                        'interact-spec.xml',
                        'interact-spec.pep.xml';

  
	my $pepXMLfile = '';

	for my $name ( @possible_names ) {
		if ( -e $args{search_path} . $name ) {
			$pepXMLfile = $args{search_path} . $name;
			last;
		}
	}

  if ( ! $pepXMLfile ) {
    print STDERR "Unable to find pep xml file: $args{search_path}\n";
		return;
  }
	return $pepXMLfile;
  
}

#######################################################################
# getNSpecFromFlatFiles
# @param search_batch_path
# @return number of spectra with P>=0 for search_batch
#######################################################################
sub getNSpecFromFlatFiles {
	my $self = shift;
  my %args = @_;
	$args{search_path} ||= $args{search_batch_path};

  my $pepXMLfile = $self->findPepXMLFile( %args ) || return '';
  
	#%spectra = ();
  #if (-e $pepXMLfile) {
	  print STDERR "parsing XML file: $pepXMLfile!\n";

  #  my $parser = new XML::Parser( );
  #  $parser->setHandlers(Start => \&local_start_handler);
  #  $parser->parsefile($pepXMLfile);
  #}
  #my $n0 = keys %spectra;
  my $cmd = 'perl -ne \'/.*spectrum="([^"]+)(\.\d+)\.\d+.\d+".*/;$scan{$1} =1; $spec{"$1$2"}=1; END {print scalar keys %scan ; print "," . scalar keys %spec ; print "\n"}\'';
  my $n0;
  if ($pepXMLfile =~ /.gz$/){
    $n0 = `zgrep '<spectrum_query' $pepXMLfile|$cmd`;
  }else{
    $n0 = `grep '<spectrum_query' $pepXMLfile|$cmd`;
  }
  chomp $n0;
  return split(",", $n0);


} # End getNSpectraFromFlatFiles  

###################################################################
# local_start_handler -- local content handler for parsing of a
# pepxml to get number of spectra in interact-prob.xml file
###################################################################
  sub local_start_handler {
    my ($expat, $element, %attrs) = @_;

    ## need to get attribute spectrum from spectrum_query element,
    ## drop the last .\d from the string to get the spectrum name,
    ## then count the number of unique spectrum names in the file
    if ($element eq 'spectrum_query') {
      my $spectrum = $attrs{spectrum};
      ## drop the last . followed by number
      $spectrum =~ s/(.*)(\.)(\d)/$1/;
      $spectra{$spectrum} = $spectrum;
    }
  }


###############################################################################
=head1 BUGS

Please send bug reports to SBEAMS-devel@lists.sourceforge.net

=head1 AUTHOR

Eric W. Deutsch (edeutsch@systemsbiology.org)

=head1 SEE ALSO

perl(1).

=cut
###############################################################################
1;

__END__
###############################################################################
###############################################################################
###############################################################################
