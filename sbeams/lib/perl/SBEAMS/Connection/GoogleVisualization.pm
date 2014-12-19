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
use List::Util qw/max/;

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

sub drawPTMHisChart{
  my $self = shift;
  my %args = @_;
  my $data = $args{data};
  my $dataTable = qq~ 
   var data = new google.visualization.DataTable();
   data.addColumn('string', 'AA');
   data.addColumn('number', '< 0.3');
   data.addColumn({type:'string', role:'annotation'});
   data.addColumn('number', '0.30 - 0.70');
   data.addColumn({type:'string', role:'annotation'});
   data.addColumn('number', '0.70 - 0.90');
   data.addColumn({type:'string', role:'annotation'});
   data.addColumn('number', '0.90 - 0.98');
   data.addColumn({type:'string', role:'annotation'});
   data.addColumn('number', '0.98 - 1.00');
   data.addColumn({type:'string', role:'annotation'});
   data.addRows([
  ~;
  my $not_sty='';
  my $total;
  my $max_obs = 0;
  foreach my $pos(sort {$a <=> $b} keys %$data){
    my $aa=$data->{$pos}{aa};
    my ($obsh,$obsmh,$obsm,$obsml,$obsl); 
    if ($aa =~ /[STY]/){
       if($not_sty){
         $dataTable .= "['$not_sty',0,'',0,'',0,'',0,'',0,''],";
       }
       $not_sty='';

       $obsh= $data->{$pos}{obsh}  || 0;
       $obsmh = $data->{$pos}{obsmh} || 0;
       $obsm = $data->{$pos}{obsm} || 0;
       $obsml = $data->{$pos}{obsml} || 0;
       $obsl=$data->{$pos}{obsl} || 0;
       my $higestval = max ($obsl, $obsml,$obsm,$obsmh,$obsh);
       if ($max_obs < $higestval){
         $max_obs = $higestval;
       } 
       $dataTable .= "['$aa',$obsl,'$obsl',$obsml,'$obsml',$obsm,'$obsm',$obsmh,'$obsmh',$obsh,'$obsh'],";
      $total = $obsl+$obsml+$obsm+$obsmh+$obsh;
    }else{
       $not_sty .= "$aa";
    }
  }
  if($not_sty){
    $dataTable .= "['$not_sty',0,'',0,'',0,'',0,'',0,'']";
  }
  $dataTable =~ s/,$//;
  $dataTable .= "]);";

  $max_obs += ceil(0.2 * $max_obs);
  my $chart_div = qq~
    <script type="text/javascript" src="../../usr/javascript/jquery/jquery.js"></script>
    <script type="text/javascript" src="https://www.google.com/jsapi"></script>
    <script type="text/javascript">
      google.load("visualization", "1", {packages:["corechart"]});
			function drawVisualization() {
          $dataTable
				var chart = new google.visualization.ComboChart(document.getElementById('chart_ptm'));
        chart.draw(data,{
					vAxis: {title: "N obs"},
          vAxes: {0: {'maxValue':$max_obs }},
          seriesType: "bars",
					annotations:{alwaysOutside:'true'},
					legend: { position: 'top' },
					'colors': ['#A6A6A6', '#7030A0', '#00B0F0', '#FFC000', '#00B050'],
          width: 900, height: 400,
          chartArea: {left: 30, top: 50, width: "100%"},
          focusTarget: 'category'
         });
  
				var mydiv = document.getElementById('chart_ptm')
				var rects = \$(mydiv).find('svg > g > g > g > text')
				var re = \/[STY]\/i;  
				var row = 0;
				for (i = 0; i < rects.length; i++) {
          var el = \$(rects[i]);
          var aparent = el.parent();
          var aas = el.text();
          if (! re.test(aas)) {    
            continue;
          }
          //alert (el.attr("height"));
          var pos = getElementPos(el);
          var attrs = {x:pos.x,y: 70,
                     fill: 'black',
                     'font-family': 'Arial',
                     'font-size': 14,
                     'text-anchor': 'middle'};
          aparent.append(addTextNode(attrs, $total, aparent));
        }
        var attrs = {x: 50 ,y: 70,
                     fill: 'black',
                     'font-family': 'Arial',
                     'font-size': 14,
                     'text-anchor': 'middle'};
        \$(rects[0]).parent().append(addTextNode(attrs, 'Total obs' , \$(rects[0]).parent()));
 
			}
      google.setOnLoadCallback(drawVisualization);
		  function getElementPos(\$el) {
				// returns an object with the element position
				return {
						x: parseFloat(\$el.attr("x")),
						width: parseFloat(\$el.attr("width")),
						y: parseFloat(\$el.attr("y")),
						height: parseFloat(\$el.attr("height"))
				}
	  	}


		  function addTextNode(attrs, text, _element) {
							// creates an svg text node
          var sNamespace = "http://www.w3.org/2000/svg";
					var el = document.createElementNS(sNamespace, "text");
					for (var k in attrs) { el.setAttribute(k, attrs[k]); }
					var textNode = document.createTextNode(text);
					el.appendChild(textNode);
					return el;
	  	}

  </script>
  <table>
  <div id="chart_ptm" style="width: 1000px;height: 400px;"></div>
  </table>
  ~;
  return $chart_div;
}


1;

