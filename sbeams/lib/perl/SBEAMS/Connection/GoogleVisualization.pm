###############################################################################
# $Id: $
#
# Description :  Wrapper for Google Visualizations
#
# SBEAMS is Copyright (C) 2000-2008 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################

package SBEAMS::Connection::GoogleVisualization;
use strict;

use SBEAMS::Connection;
use SBEAMS::Connection::Settings;
use SBEAMS::Connection::Log;

use POSIX;

my $log = SBEAMS::Connection::Log->new();
my $sbeams = SBEAMS::Connection->new();

##### Public Methods ###########################################################

#+
# Constructor method.
#
sub new {
  my $class = shift;
  my $this = {
		           '_packages' => {},
							 '_callbacks' => [],
							 '_functions' => [],
							 '_charts' => 0,
							 '_tables' => 0,
							 '_options' => [],
               @_
             };
  bless $this, $class;
  return $this;
}

sub setDrawDataTable {
  # Get passed args
	my $self = shift;
	my %args = @_;

	if(	$self->{_hide_svg} ) {
		my $msg = $sbeams->makeInfoText("Your browser appears to be too old to display these graphics, please come back when you have upgraded");
		$log->debug( $msg );
		return $msg;
	}
  # Required!
	for my $arg ( qw( data data_types headings ) ) {
	  unless ( $args{$arg} ) {
			$log->error( "Missing required option $arg");
			return undef;
		}
	  unless ( ref $args{$arg} eq 'ARRAY' ) {
			$log->error( "Required option $arg must be an ARRAY, not " . ref $args{$arg} );
			return undef;
		}
	}
	if ( scalar( @{$args{headings}} ) != scalar( @{$args{data_types}} ) ) {
    $log->error( "Headings and data type arrays must have same size" );
    return undef;
	}


  # set script vars
  my $table = 'table' . $self->{'_tables'}; 
  # Just want the div name for now...
  my $table_div = $table . '_div'; 
  my $n = scalar( @{$args{data}} ); 
  my $n_rows = @{$args{data}}[$n-1]->[0] +1 ;

	my $fx = qq~
    function drawTable() {
      var data = new google.visualization.DataTable();
  ~;

	for ( my $i = 0; $i <= $#{$args{headings}}; $i++ ) {
    $fx .= " data.addColumn('$args{data_types}->[$i]', '$args{headings}->[$i]');\n";
	}
	$fx .= " data.addRows( $n_rows );\n"; 
	for my $s ( @{$args{data}} ) {
      my $line = join(",", @$s);
    	$fx .= " data.setCell($line );\n";
	}
  $fx .= qq~
    var table = new google.visualization.Table(document.getElementById('$table_div'));

    table.draw(data, {showRowNumber: false});
    }
  ~;
  push @{$self->{'_functions'}}, $fx;

  $table_div = '<DIV id="' . $table . '_div' . '"></DIV>'; 
	return $table_div;
}


sub setDrawBarChart {
  # Get passed args
	my $self = shift;
	my %args = @_;
	
	if(	$self->{_hide_svg} ) {
		my $msg = $sbeams->makeInfoText("Your browser appears to be too old to display these graphics, please come back when you have upgraded");
		$log->debug( $msg );
		return $msg;
	}

  # Required!
	for my $arg ( qw( samples data_types headings ) ) {
	  unless ( $args{$arg} ) {
			$log->error( "Missing required option $arg");
			return undef;
		}
	  unless ( ref $args{$arg} eq 'ARRAY' ) {
			$log->error( "Required option $arg must be an ARRAY, not " . ref $args{$arg} );
			return undef;
		}
	}
	if ( scalar( @{$args{headings}} ) != scalar( @{$args{data_types}} ) ) {
    $log->error( "Headings and data type arrays must have same size" );
    return undef;
	}

	# Set defaults
	$args{show_table} ||= 0;
	my $height = $args{height} || 0;
	my $width = $args{width} || 800;


  # Tally information
	$self->{_packages}->{barchart}++; 
	$self->{'_charts'}++;
	if( $args{show_table} ) {
  	$self->{_packages}->{table}++; 
	}

  # set script vars
  my $chart = 'chart' . $self->{'_charts'}; 
  my $table = 'table' . $self->{'_tables'}; 
  # Just want the div name for now...
  my $chart_div = $args{chart_div} || $chart . '_div'; 
  my $table_div = $table . '_div'; 
  my $chart_fx = 'draw_' . $chart; 
  my $table_fx = 'draw_' . $table; 

	my $table_script = 

  push @{$self->{'_callbacks'}}, $chart_fx;

  my $n_rows = scalar( @{$args{samples}} );

	my $fx = <<"  END";
  function $chart_fx() {
    var data = new google.visualization.DataTable();
  END
	for ( my $i = 0; $i <= $#{$args{headings}}; $i++ ) {
    $fx .= " data.addColumn('$args{data_types}->[$i]', '$args{headings}->[$i]');\n";
	}
	$fx .= " data.addRows( $n_rows );\n"; 
  my $sample_cnt = 0;
  my $sample_list = '';
	for my $s ( @{$args{samples}} ) {
    my $posn = 0;
		for my $c ( @$s ) {
	    # caller requested labels be truncated (will affect table too!)
		  if ( $args{truncate_labels} && !$posn ) {
			  $c = $sbeams->truncateString( string => $c, len => $args{truncate_labels} );
	    }
			if ( $args{data_types}->[$posn] eq 'number' ) {
    		$sample_list .= " data.setValue($sample_cnt, $posn, $c );\n";
			} else {
    		$sample_list .= " data.setValue($sample_cnt, $posn, '$c' );\n";
			}
			$posn++;
		}
		$sample_cnt++;
	}
	$height = $height || 50 + ( $n_rows * ( 8 + ( $#{$args{headings}} * 4 ) ) );

  my $table_js = '';
	if( $args{show_table} ) {
    $table_js =<<"    END";
    var table = new google.visualization.Table(document.getElementById('$table_div'));
    table.draw(data, {showRowNumber: true});
    END
	}

  my $options = "{ width: $width, height: $height, is3D: true }";
  if ( $args{options} ) {
    $options = "{ width: $width, height: $height, is3D: true, $args{options} }";
  }

  my $callback = $args{callback} || '';
  $fx .=<<"  END";
  $sample_list
  $table_js
  var chart = new google.visualization.BarChart(document.getElementById('$chart_div'));
  var options = $options
  chart.draw(data, options );
  }
  END

  push @{$self->{'_functions'}}, $fx;

	# Put divs into markup for return to caller
  $chart_div = '<DIV id="' . $chart . '_div' . '"></DIV>'; 
  $chart_div = '' if $args{no_div};
  $table_div = '<DIV id="' . $table . '_div' . '"></DIV>'; 
  
	if ( $args{show_table} ) {
		if ( wantarray ) {
			return ( $chart_div, $table_div );
		}
		return( "$chart_div\n$table_div" );
	}
	return $chart_div;

}


#+
# To be called last!
#-
sub getHeaderInfo {
	my $self = shift;
	my %args = @_;
	my $pkgs = '';
	my $sep = '';

	unless( $self->is_supported_browser( ffox_version => '1.5' ) ) {
		$log->warn( "Browser incompatibility error" );
		$self->{_hide_svg} = 1;
		return $sbeams->makeErrorText( "Incompatible browser detected, some content may not be available" );
	}

	for my $p ( keys( %{$self->{'_packages'}} ) ) {
		$pkgs .= $sep . '"' . $p . '"'; 
		$sep = ', ';
	}
	my $callbacks = '';
	for my $callback ( @{$self->{'_callbacks'}} ) {
		$callbacks .= "google.setOnLoadCallback($callback);";
	}
  if ( $args{callbacks} ) {
	  for my $callback ( @{$args{callbacks}} ) {
		  $callbacks .= "google.setOnLoadCallback($callback);";
  	}
  }
	my $functions = '';
	for my $function ( @{$self->{'_functions'}} ) {
		$functions .= "$function\n";
	}

  my $header_info = '';

#    <script type="text/javascript" src="$HTML_BASE_DIR/usr/javascript/ga.js"></script>
#    <script type="text/javascript" src="$HTML_BASE_DIR/usr/javascript/defaultbarchart.js"></script>
#    <script type="text/javascript" src="https://www.google.com/javascript/ga.js"></script>
#    <script type="text/javascript" src="https://www.google.com/defaultbarchart.js"></script>
	if ( $CONFIG_SETTING{USE_LOCAL_GOOGLEVIS} ) {
		$log->debug( "Using local version" );
    $header_info =<<"  END_SCRIPT";
    <script type="text/javascript" src="$HTML_BASE_DIR/usr/javascript/jsapi"></script>
    <script type="text/javascript">
    google.load("visualization", "1", {packages:[$pkgs]});
		$callbacks
		$functions
    </script>
  END_SCRIPT
	} else {
		$log->debug( "Using google version" );
    $header_info =<<"  END_SCRIPT";
    <script type="text/javascript" src="https://www.google.com/jsapi"></script>
    <script type="text/javascript">
    google.load("visualization", "1", {packages:[$pkgs]});
		$callbacks
		$functions
    </script>
  END_SCRIPT
	}

  return $header_info;
}

sub is_supported_browser {
	my $self = shift;
	my %args = @_;

	my $ffox_version = $args{ffox_version} || '1.5';

  my $browser = $ENV{HTTP_USER_AGENT};
	if ( $browser =~ /.*Firefox\/(.*)$/ ) {
		if ( $1 < $ffox_version ) {
		  $log->warn( "Browser: $browser failed version test! ($1 is less than $ffox_version)" );
		  return 0 
		}
	}
	return 1;
}
1;

