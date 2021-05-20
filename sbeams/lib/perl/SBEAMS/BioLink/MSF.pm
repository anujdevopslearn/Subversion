###############################################################################
# $Id$
#
# Description : Module to parse multi-sequence files
# SBEAMS is Copyright (C) 2000-2021 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################

package SBEAMS::BioLink::MSF;
use strict;

use lib "../..";

use Digest::MD5 qw(md5_hex);

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

  my $alignment_dir = $CONFIG_SETTING{ALIGNMENT_SUBDIR} || '';
  $this->{_alignment_dir} = $alignment_dir;
  $log->info( "Alignment dir is $alignment_dir" );

  # Make sure it exists 
  if ( $alignment_dir ) {
    my $exists = $sbeams->doesSBEAMSTempFileExist(  dirname => $alignment_dir,
						    filename => '' );
    unless ( $exists ) {
      $sbeams->writeSBEAMSTempFile( content => 'Nada Surf',
				    dirname => $alignment_dir,
				    filename => 'create_me',
				    newdir => 1 );
    }
  }
  return $this;
}

sub runClustalW {
  my $self = shift;
  my %args = @_;
  return 'no data provided' unless $args{sequences};

  $args{sequences} =~ s/^>\s+/>_spc_/g;

  my $checksum = md5_hex( $args{sequences} );
  my $dirname = ( $self->{_alignment_dir} ) ? $self->{_alignment_dir} . '/' : '';
  $dirname .= $checksum;

  my $clustal_file = "$checksum.fsa";
  my $exists = $sbeams->doesSBEAMSTempFileExist( filename => "$checksum.aln", 
						 dirname => $dirname );

  if ( !$exists ) {
    $log->info( "no existing alignment named $checksum!" );
    $clustal_file = $sbeams->writeSBEAMSTempFile( content => $args{sequences},
						  dirname => $dirname,
						  filename => $checksum,
						  suffix => 'fsa',
						  newdir => 1
	);
    my $clustal_exe = $CONFIG_SETTING{CLUSTALW} || return 'Clustal executable not found on this server';
    my $out = `$clustal_exe -tree -align -outorder=input -infile=$clustal_file`;

    if ( $out && $out =~ /No alignment!/gm ) {
      return "Clustal run failed: $out\n";
    }
  } else {
    $clustal_file = $exists;
    $log->info( "Reading existing alignment $checksum! ($clustal_file)" );
  }

  my $align_file = $clustal_file;
  $align_file =~ s/fsa$/aln/;
  if ( !-e $align_file ) {
    return "Output not produced";
  } elsif ( !-s $align_file ) {
    return "Output file is empty ";
  }

  my $alignment = '';
  my %aligned_seqs;
  my @aligned_order;
  my $first_char = 0;
  my $consensus_due = 0;
  {
    open( ALIGN, $align_file );
    my $head_line = 0;
    my $cnt = 0;
    while ( my $line = <ALIGN>  ) {
      $alignment .= $line;
      $cnt++;
      next if $cnt == 1;

      if ( $line =~ /^\s+$/ ) {

	# Added after the fact to account for alignments where there is no 
	# consensus string for a particular aligned segment.
	if ( $consensus_due ) {
	  $consensus_due = 0;
	  $line = ' ' x (59 + $first_char );
#					$log->debug( "blanky is " . length( $line ) . ' chars long' );
	} else {
	  next;
	}
      }

      if ( !$first_char ) {
	my $cnt;
	my $name = 1;
	my @line = split( "", $line, -1 );
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
	$consensus_due = 0;
	$name = 'consensus';
	$seq = substr( $line, $first_char - 1 );
      } else {
	$consensus_due = 1;
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
#		$log->debug( "in MSF, $acc is " . length( $aligned_seqs{$acc} ) . " long" );
    push @all_aligned, [ $acc, $aligned_seqs{$acc} ];
  }

  return \@all_aligned;
}

sub runAllvsOne {
  my $self = shift;
  my %args = @_;
  return {} unless $args{reference} && $args{sequences};

  for my $name ( keys( %{$args{sequences}} ) ) {
    next if $name eq $args{reference};
    my $fasta_content = qq~>$args{reference}
$args{sequences}->{$args{reference}}
>$name
$args{sequences}->{$name}
~;

    $log->info( $fasta_content );
    my $results = $self->runClustalW( sequences => $fasta_content );
    $log->info( join( "\n", @{$results} ) );
  }
}


sub parse_aln {
  my $self = shift;
  my %args = @_;
  return 'no data' unless $args{aln};
}


1;
