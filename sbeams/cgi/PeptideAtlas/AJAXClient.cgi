#!/usr/local/bin/perl

###############################################################################
# Program     : AJAXClient.cgi
# $Id: $
#
# Description : Script responds to AJAX requests from Peptide Atlas scripts and 
# returns desired information as JSON object.
#
# SBEAMS is Copyright (C) 2000-2016 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################


###############################################################################
# Get the script set up with everything it will need
###############################################################################
use strict;
use vars qw ( $q $sbeams $atlas $PROG_NAME
             $current_contact_id $current_username );
use lib qw (../../lib/perl);

use CGI::Carp qw(fatalsToBrowser croak);
use JSON;
use Data::Dumper;

use SBEAMS::Connection qw($q $log);
use SBEAMS::Connection::DataTable;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Tables;
use SBEAMS::Connection::TabMenu;

use SBEAMS::PeptideAtlas;
use SBEAMS::PeptideAtlas::Settings;
use SBEAMS::PeptideAtlas::Tables;

###############################################################################
# Global Variables
###############################################################################
$sbeams = new SBEAMS::Connection;
$atlas = new SBEAMS::PeptideAtlas;
$atlas->setSBEAMS($sbeams);

my $json = new JSON;
my %params;

main();

###############################################################################
# Main Program:
###############################################################################
sub main
{
    #### Do the SBEAMS authentication and exit if a username is not returned
    exit unless ( $current_username = $sbeams->Authenticate(      connect_read_only => 1, 
                                                             allow_anonymous_access => 1 ) 
                                                           );
    #### Read in the default input parameters
    my $n_params_found = $sbeams->parse_input_parameters( q => $q, 
                                             parameters_ref => \%params
                                                        );


    if ( $params{pabst_build_id} eq 'specialaccess' ) {
      $params{pabst_build_id} = 146;
    }

  print $sbeams->get_http_header();
  print process_query();

} # end main


sub process_query {

  if ( $params{source} eq 'GetTransitions_SourceSelect' ) {
    return GetTransitions_SourceSelect();
  } elsif ( $params{source} eq 'GetTransitions_ElutionTimeSelect' ) {
    return GetTransitions_ElutionTimeSelect();
  } elsif ( $params{source} eq 'GetTransitions_NamespaceFilters' ) {
    return GetTransitions_NamespaceFilters();
  } elsif ( $params{source} eq 'SEL_Transitions_Run_Select' ) {
    return SEL_Transitions_Run_Select();
  } elsif ( $params{source} eq 'GetProtein_VariantDisplay' ) {
    return GetProtein_VariantDisplay();
  } elsif ( $params{source} eq 'GetDIALibs_LibrarySelect' ) {
    return GetDIALibs_LibrarySelect();
  } elsif ( $params{source} eq 'GetTransitions_Gradient_doc' ) {
    return GetTransitions_Gradient_doc();
  } else {
    return $params{source};
  }
}

sub GetDIALibs_LibrarySelect {

  use SBEAMS::PeptideAtlas::DIALibrary;
  my $dia = new SBEAMS::PeptideAtlas::DIALibrary;

  # Build select list
  my $select = $dia->get_library_select( as_array => 1, %params );
  my $json_text = $json->encode( $select ); 
  $log->debug( $json_text );
  return $json_text;
}



# +
# Routine to update variant display in GetProtein (show all snps vs dbsnp only)
# -
sub GetProtein_VariantDisplay {

  # Do something with parameters
  $log->debug( Dumper( %params ) );

  # Build select list
  my @select;
#  push @select, { optionValue => $row[1], optionText => $row[0] }; 

  my $json_text = $json->encode( \@select ); 

	$log->debug( $json_text );
  return $json_text;
}


sub GetTransitions_SourceSelect {

  my @select;

  if ( $params{pabst_build_id} && $params{pabst_build_id} =~ /^\d+$/ ) {

    my $sql = qq~
    SELECT CASE WHEN instrument_type_name = 'QQQ' THEN 'Agilent QQQ' ELSE instrument_type_name END AS instrument_type_name, IT.instrument_type_id
    FROM $TBAT_PABST_BUILD_RESOURCE PBR
    JOIN $TBAT_CONSENSUS_LIBRARY CL ON CL.consensus_library_id = PBR.resource_id
    JOIN $TBAT_INSTRUMENT_TYPE IT on IT.instrument_type_id = PBR.instrument_type_id
    WHERE resource_type = 'spectral_lib'
    AND pabst_build_id = $params{pabst_build_id} 
    AND is_source_instrument = 'Y'
    UNION ALL
    SELECT instrument_type_name, IT.instrument_type_id
    FROM $TBAT_INSTRUMENT_TYPE IT
    WHERE instrument_type_name = 'Predicted'
    ~;

    my $sth = $sbeams->get_statement_handle( $sql );
    while ( my @row = $sth->fetchrow_array() ) {
			my $skip = 0;
			if ( $row[0] =~ /Predicted/ ) {
				for my $id ( 154, 164, 165 ) {
					$skip++ if $params{pabst_build_id} == $id;
  			}
			}
      push @select, { optionValue => $row[1], optionText => $row[0] } unless $skip;
    }

  }

  if ( scalar( @select ) < 2 ) {
    @select = ();
    my $sql = qq~
      SELECT CASE WHEN instrument_type_name = 'QQQ' THEN 'Agilent QQQ' ELSE instrument_type_name END AS instrument_type_name, instrument_type_id
      FROM $TBAT_INSTRUMENT_TYPE
      WHERE is_source_instrument = 'Y'
    ~;
    my $sth = $sbeams->get_statement_handle( $sql );
    while ( my @row = $sth->fetchrow_array() ) {
			my $skip = 0;
			if ( $row[0] =~ /Predicted/ ) {
				for my $id ( 154, 164, 165 ) {
					$skip++ if $params{pabst_build_id} == $id;
  			}
			}
      push @select, { optionValue => $row[1], optionText => $row[0] } unless $skip;
    }
  }

  my $json_text = $json->encode( \@select ); 

  

	$log->debug( $json_text );
  return $json_text;
}

sub GetTransitions_NamespaceFilters {

  my %names;
  my $div_text = '&nbsp;' x 4; #  . $sbeams->makeInactiveText( 'N/A' );
#  my $json_text = $json->encode( [$div_text] );
#  return $json_text;
  if ( $params{pabst_build_id} && ( $params{pabst_build_id} =~ /^\d+$/ || $params{pabst_build_id} =~ /special/ ) ) {

    my $sql = qq~
    SELECT organism_id
    FROM $TBAT_PABST_BUILD
    WHERE pabst_build_id = $params{pabst_build_id}
    ~;
    my $sth = $sbeams->get_statement_handle( $sql );
    $log->warn( " $sql" );
    while ( my @row = $sth->fetchrow_array() ) {
      $log->warn( " ID is $row[0]" );
      if ( $row[0] == 6 ) {
        $div_text = '<INPUT TYPE=checkbox NAME=SwissProt checked> SwissProt </INPUT><INPUT TYPE=checkbox NAME=Ensembl checked> Ensembl </INPUT><INPUT TYPE=checkbox NAME=IPI checked> IPI </INPUT>';

      } elsif ( $row[0] == 2 ) {
  
        $div_text = '<INPUT TYPE=checkbox NAME=SwissProt checked> SwissProt </INPUT><INPUT TYPE=checkbox NAME=Ensembl > Ensembl </INPUT><INPUT TYPE=checkbox NAME=IPI > IPI </INPUT>';
#      for my $name ( qw( SwissProt Ensembl IPI neXtProt ) ) {
#        $div_text .= "<INPUT TYPE=checkbox NAME=$name $names{$name} id=$name onclick='chk_namespace(this)'> $name </INPUT>";
#      }

      } elsif ( $row[0] == 3 ) {
        $div_text = '<INPUT TYPE=checkbox NAME=SGD checked  disabled> SGD </INPUT>';
      } elsif ( $row[0] == 40 ) {
        $div_text = '<INPUT TYPE=checkbox NAME=Tuberculist checked disabled> TubercuList </INPUT>';
      } elsif ( $row[0] == 43 ) {
        $div_text = '<INPUT TYPE=checkbox NAME=Dengue checked disabled> Dengue </INPUT>';
			}
    }
  }
  my $json_text = $json->encode( [$div_text] );
	$log->debug( $json_text );
  return $json_text;
}

sub GetTransitions_Gradient_doc {
  my $doc_url = '<td valign=top nobr><b>Elution Time Type:</b></td>';
  if ( $params{pabst_build_id} && $params{pabst_build_id} == 146 ) {
    $doc_url = "<td valign=top nobr><b>Elution Time Type:</b>&nbsp;&nbsp;<a href='https://db.systemsbiology.net/devDC/sbeams/doc/PeptideAtlas/HumanSRMAtlas_Gradient_RTs_web_v1_20160714.pdf'>[gradient info]</a></td>";
  }
  return $json->encode( { url => $doc_url} );
}

sub GetTransitions_ElutionTimeSelect {

  my @select;

  $params{pabst_build_id} = 146 if $params{pabst_build_id} == 'specialaccess';

  if ( $params{pabst_build_id} && $params{pabst_build_id} =~ /^\d+$/ ) {

    my $build_resources = $atlas->fetchBuildResources( pabst_build_id => $params{pabst_build_id} );

    my $resource_clause = "WHERE elution_time_type LIKE 'SSR%'";
    if ( $build_resources->{elution_time_set} ) {
      $resource_clause = " WHERE elution_time_set IN ( " . join( ',', keys( %{$build_resources->{elution_time_set}} ) ) . " ) ";
    }

    my $sql = qq~
    SELECT DISTINCT elution_time_type, ET.elution_time_type_id
    FROM $TBAT_ELUTION_TIME ET 
    JOIN $TBAT_ELUTION_TIME_TYPE ETT on ET.elution_time_type_id = ETT.elution_time_type_id
    $resource_clause
    ORDER BY elution_time_type ASC
    ~;

   $log->debug( $sql );
    

    my $sth = $sbeams->get_statement_handle( $sql );
    while ( my @row = $sth->fetchrow_array() ) {
      push @select, { optionValue => $row[1], optionText => $row[0] };
    }

  }

  my $json_text = $json->encode( \@select ); 
  $log->debug( $json_text );
  return $json_text;
}


sub SEL_Transitions_Run_Select {

  my $div_text = { optionValue=>'', optionText => '&nbsp;' x 20 };
  my @select;
  my $json_text;

  my $runs;
  if ( $params{'sel_run_id[]'} && $params{'sel_run_id[]'} =~ /^\d+/ ) {
    for my $run ( split( /,/, $params{'sel_run_id[]'} )) {
      $run =~ s/\s//g;
      $runs->{$run}++;
    }
  }

  if ( $params{'sel_experiment_id[]'} && $params{'sel_experiment_id[]'} =~ /^\d+/ ) {

  my $sql = qq~
  SELECT DISTINCT SEL_run_id, spectrum_filename
    FROM $TBAT_SEL_RUN 
    WHERE SEL_experiment_id IN ( $params{'sel_experiment_id[]'} )
    ORDER BY spectrum_filename ASC
    ~;
    
    my $sth = $sbeams->get_statement_handle( $sql );
    while ( my @row = $sth->fetchrow_array() ) {
      my $selected = ( $runs->{$row[0]} ) ? ' selected ' : '';
      push @select, { optionValue => $row[0], optionText => $row[1], optionSelected => $selected };
    }

  } else {
      push @select, $div_text;
  }
  $json_text = $json->encode( \@select );
  return $json_text;
}
__DATA__

