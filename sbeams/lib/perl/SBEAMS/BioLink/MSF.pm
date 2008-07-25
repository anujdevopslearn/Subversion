###############################################################################
# $Id:  $
#
# Description : Module to parse multi-sequence files
# SBEAMS is Copyright (C) 2000-2008 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################

package SBEAMS::BioLink::MSF;
use strict;

use lib "../..";

use SBEAMS::Connection qw( $log );
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;

use SBEAMS::BioLink;
use SBEAMS::BioLink::Tables;

### Globals ###

my $sbeams = new SBEAMS::Connection;
my $sbeamsMOD = new SBEAMS::BioLink;
$sbeamsMOD->setSBEAMS($sbeams);


sub new {
  my $class = shift;
  my $this = { @_ };

  # Objectification.
  bless $this, $class;

  return $this;
}

sub runClustalW {
  my $self = shift;
	my %args = @_;
	return 'no data' unless $args{sequences};

	$args{sequences} =~ s/^>\s+/>_spc_/g;
  my $clustal_file = $sbeams->writeSBEAMSTempFile( content => $args{sequences},
                                                    suffix => 'fsa',
																										newdir => 1
																								 );
  my $clustal_exe = $CONFIG_SETTING{CLUSTALW} || return '';
  my $out = `$clustal_exe -tree -align -outorder=input -infile=$clustal_file`;
	my $align_file = $clustal_file;
	$align_file =~ s/fsa$/aln/;
	my $alignment = '';
	my %aligned_seqs;
	my @aligned_order;
	my $first_char = 0;
  {
		open( ALIGN, $align_file );
		my $head_line = 0;
		my $cnt;
		while ( my $line = <ALIGN>  ) {
		  $alignment .= $line;

			$cnt++;
			next if $cnt == 1;
			next if $line =~ /^\s+$/;

			if ( !$first_char ) {
				my $cnt;
				my $name = 1;
				my @line = split( "", $line );
				for my $char ( @line ) {
					$cnt++;
					$name = 0 if $char =~ /^\s$/;
					if ( !$name && $char !~ /^\s+$/ ) {
						$first_char = $cnt;
						last;
					}
				}
			}


      my $name = '';
			my $seq = '';
			chomp $line;

      # Consensus line!
			if ( $line =~ /^\s+/ ) {
			  $name = 'consensus';
			  $seq = substr( $line, $first_char - 1 );
			} else {
        $line =~ s/\s+/\t/g;
  			my @line = split( "\t", $line, -1 );
				$name = $line[0];
				$seq = $line[1];
			}
      
			if ( !$aligned_seqs{$name} ) {
				push @aligned_order, $name;
			}
			$aligned_seqs{$name} .= $seq;
		}
		close ALIGN;
	}
	$alignment = '';
	my @all_aligned;
  for my $acc ( @aligned_order ) {
		push @all_aligned, [ $acc, $aligned_seqs{$acc} ];
	}

  return \@all_aligned;

}

sub parse_aln {
  my $self = shift;
	my %args = @_;
	return 'no data' unless $args{aln};
}



1;
