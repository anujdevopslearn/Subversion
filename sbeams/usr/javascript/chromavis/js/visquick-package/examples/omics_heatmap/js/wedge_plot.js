
function wedge_plot_simulated(div) {
    var width=530, height=670;

    function normal_sample() {
  var x = 0, y = 0, rds, c;
  do {
    x = Math.random() * 2 - 1;
    y = Math.random() * 2 - 1;
    rds = x * x + y * y;
  } while (rds == 0 || rds > 1);
  c = Math.sqrt(-2 * Math.log(rds) / rds); // Box-Muller transform
  return x * c; // throw away extra sample y * c
}
    var mean = 0;
    var dev = 0.2;
    var normal = function() { return mean + dev * normal_sample();}


    var matrix = pv.range(0,166).map(function(a)
                {var theme = normal(); return pv.range(0,166).map(function(b){return theme + ((Math.random() - 0.5) / 25);});});

    var transpose=matrix.map(function(row,row_index) { return row.map(function(col,col_index) { return matrix[col_index][row_index];}); });
         matrix.forEach(function(row,row_index) { row.forEach(function(col,col_index)
                                                    { matrix[row_index][col_index] = matrix[row_index][col_index] + transpose[row_index][col_index] * -1;})});

    var labels = matrix.map(function(a) {return a.slice(0,20).map(function(c) { return String.fromCharCode(Math.floor((c+1) * 13) + 97);}).join('');} );

    var data = {
        PLOT: {
            container : div,
            width : width,
            height: height,
            vertical_padding : 10,
            horizontal_padding: 110,
            font :"sans"
        },
            data_matrix : matrix,
            row_labels : labels,
            row_label_prefix : '',
            row_label_font : '10px bold Courier, monospace',
            item_row_padding : 0,
            item_column_padding : 0,
            item_width : 3,
            item_height : 4,
            row_click_notifier: row_click

    };
    var listener = function(list) { return console.log("listener!"); };
    var heatmap_vis = new vq.OmicsHeatmap();
    var dataObject ={DATATYPE : "vq.models.OmicsHeatmapData", CONTENTS : data};
    heatmap_vis.draw(dataObject);

    return heatmap_vis;
}



function wedge_plot(div) {
    var width=530, height=800;

    var matrix = pv.range(0,166).map(function(a)
                {return pv.range(0,166).map(function(b){return Math.random()*2 -1;});});
    var labels = matrix.map(function(a) {return a.slice(0,20).map(function(c) { return String.fromCharCode(Math.floor((c+1) * 13) + 97);}).join('');} );

    var data = {
        PLOT :  {
            width : width,
            height: height,
            vertical_padding : 10,
            horizontal_padding: 110,
            font :"sans",
            container : div
        },
        data_matrix : matrix,
        row_labels : labels,
        row_label_prefix : '',
        row_label_font : '10px bold Courier, monospace',
        item_row_padding : 1,
        item_column_padding : 2,
        item_width : 3,
        item_height : 4,
        row_click_notifier: row_click
    };
    var listener = function(list) { return console.log("listener!"); };
    var heatmap_vis = new vq.OmicsHeatmap();
    var dataObject ={DATATYPE : "vq.models.OmicsHeatmapData", CONTENTS : data};

    heatmap_vis.draw(dataObject);

    return heatmap_vis;
}