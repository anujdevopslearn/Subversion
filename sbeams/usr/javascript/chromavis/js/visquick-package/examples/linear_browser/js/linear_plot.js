
function linear_plot(div,chr,start,range_length) {
    var barListener = bar_listener;

    var upListener =  uniprot_listener;

    var tileTooltipItems = {Label : function(feature) { return vq.utils.VisUtils.options_map(feature)['label'];}, Chr : 'chr', Start : 'start', End: 'end'},
    barTooltipItems = {Label : function(feature) { return vq.utils.VisUtils.options_map(feature)['label'];}, '# Obs' : 'value'};
    pepObsTooltipItems = {Label : function(feature) { return vq.utils.VisUtils.options_map(feature)['label'];}, Chr : 'chr', Start : 'start', Value: 'value'};

      var fillProteinTile = function(feature) {
        var options = vq.utils.VisUtils.options_map(feature);
        switch(options['pl']){
            case('canonical'):
                return 'rgba(20,140,20,0.88)';
                break;
            case('ntt-subsumed'):
                return  'rgba(190,210,60,0.88)';
                break;

            case('subsumed'):
                return 'rgba(32,210,210,0.88)';
                break;
            case('possibly_distinguished'):
                return'rgba(210,32,32,0.88)';
                break;
            default:
                return 'rgba(48,48,48,0.88)';
                break;
        }

    };

    var data_obj = function() { return {
        PLOT : {container: div,
            width:800,
            height:600,
            min_position:1,
            max_position:maxPos,
            vertical_padding:20,
            horizontal_padding:20,
            context_height: 110
        },
        TRACKS : [
            { type: 'tile',
                label : 'SwissProt Protein Locations',
                CONFIGURATION: {
                    fill_style : "#c50",          //required
                    stroke_style : 'null',          //required
                    track_height : 50,           //required
                    tile_height:7,                //required
                    track_padding: 20,             //required
                    tile_padding:5,              //required
                    tile_overlap_distance:0.5,    //required
                    tile_show_all_tiles : true,
                    notifier:upListener,         //optional
                    tooltip_items : tileTooltipItems     //optional
                },
                data_array : vq.utils.VisUtils.clone(per_protein)
             }, {type: 'glyph',
                label : 'SwissProt Protein Locations',
                CONFIGURATION: {
                    fill_style : fillProteinTile,          //required
                    stroke_style : fillProteinTile,          //required
                    track_height : 50,           //required
                    track_padding: 20,             //required
                    tile_padding:4,              //required
                    radius:2,
                    shape:'triangle',
                    tile_overlap_distance:0.5,    //required
                    notifier:upListener,         //optional
                    tooltip_items : tileTooltipItems
                },
                   data_array : vq.utils.VisUtils.clone(per_protein)

            },{ type: 'bar',
                label : 'PeptideAtlas Observations',
                CONFIGURATION: {
                    fill_style : fillProteinTile,
                    stroke_style : fillProteinTile,
                    track_height : 80,
                    track_padding: 20,
                    base_value: 1,
                    max_value : 10000,
                    min_value : .1,
                    yaxis_scale_type : 'log',
                    notifier:barListener,
                    tooltip_items : barTooltipItems
                },
                data_array : vq.utils.VisUtils.clone(per_protein).filter(function(a) { return a.value > 0;})
            }, { type: 'scatter',
                label : 'PeptideAtlas Observations',
                CONFIGURATION: {
                    fill_style : fillProteinTile,
                    stroke_style : null,
                    shape : 'circle',
                    radius : 2,
                    track_height : 80,
                    track_padding: 20,
                    base_value: 1,
                    max_value : 100000,
                    min_value : .1,
                    yaxis_scale_type : 'log',
                    notifier:barListener,
                    tooltip_items : pepObsTooltipItems
                },
                data_array :vq.utils.VisUtils.clone(per_protein).filter(function(a) { return a.value > 0;})
            }, { type: 'line',
                label : 'PeptideAtlas Density',
                CONFIGURATION: {
                    fill_style : 'null', //: "#444"; },
                    stroke_style : '#b00', //function() {return null;},
                    track_height : 100,
                    track_padding: 20,
                    base_value:0,
                    max_value : 1.0,
                    min_value : -1.0,
                    tooltip_items : barTooltipItems
                },
                data_array : protein_density
            }]
    }
    };
    var chr_match = chrom_leng.filter(function(chrom) { return chrom.chr_name == chr;});
    var maxPos = Math.ceil(chr_match[0]['chr_length']/ 100000);


    var lin_browser = new vq.LinearBrowser();
    var lin_data = {DATATYPE: 'vq.models.LinearBrowserData',CONTENTS: data_obj()};

    lin_browser.draw(lin_data);

    if (start != null && start > 0 && range_length != null && range_length > 0) {
        lin_browser.setFocusRange(start,range_length);
    }


}


