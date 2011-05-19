

vq.OmicsHeatmap = function() {
        vq.Vis.call(this);
        //set option variables to useful values before options are set.
        this.height(400);     // defaults
        this.width(400);     // defaults
        this.vertical_padding(0);
        this.horizontal_padding(0);

    };


vq.OmicsHeatmap.prototype = pv.extend(vq.Vis);

    /**
     *      Changes the plot size and re-renders the plot.
     *
     * @param {Number} height - plot height in units of pixels
     * @param {Number} width  - plot width in units of pixels
     */

vq.OmicsHeatmap.prototype.setSize = function(height, width) {
        if (height > 1 && width > 1) {
            this.width(width);
            this.height(height);
            this._render();
        }
    };

vq.OmicsHeatmap.prototype._setOptionDefaults = function(options) {

            if (options.height != null) { this.height(options.height); }

            if (options.width != null) { this.width(options.width); }

            if (options.container) { this.container(options.container); }

            if (options.vertical_padding != null) { this.vertical_padding(options.vertical_padding); }

            if (options.horizontal_padding != null) { this.horizontal_padding(options.horizontal_padding); }
},
    /**
     *
     *  Constructs the OmicsHeatmap model and adds the SVG tags to the defined DOM element.
     *
     * @param {JSON Object} circvis_object - the object defined above.
     * @param {JSON Object} options - the general options for the visualization.
     */
vq.OmicsHeatmap.prototype.draw = function(data) {
        var vis_data = new vq.models.OmicsHeatmapData(data);

        if (vis_data.isDataReady()) {
            this._setOptionDefaults(vis_data);
            this.data = vis_data;
            this._render();
        } else {
            console.warn('Invalid data input.  Check data for missing or improperly formatted values.');
        }
    };

vq.OmicsHeatmap.prototype._render = function() {
        var     dataObj = this.data,
                w = this.width(),
                h = this.height();

        var div = this.container();
        var vertical_padding = this.vertical_padding(), horizontal_padding = this.horizontal_padding();
        var color = pv.Scale.linear(-2,-1,-.1,.1,1,2).range('#00f','#88f','#fff','#fff','#f88','#f00');

        var vis = new pv.Panel()
                .left(horizontal_padding)
                .top(vertical_padding)
                .width(w)
                .height(h)
                .fillStyle(null)
                .canvas(div);

        var size = dataObj.datamatrix[0].length * dataObj.item_width;
        var heatmap_panel = vis.add(pv.Panel)
                            .width(size)
                            .height((dataObj.item_height + dataObj.item_row_padding) * dataObj.datamatrix.length)
                            .strokeStyle('rgba(40,40,40,1.0)')
                            .lineWidth(1);

        var heatmap_container = heatmap_panel.add(pv.Panel)
                .data(pv.range(0,dataObj.datamatrix.length))
                .height(dataObj.item_height)
                .top(function(c) { return c * (dataObj.item_height + dataObj.item_row_padding);})
                .strokeStyle(null)
                .fillStyle(null)
                .lineWidth(dataObj.item_row_padding / 2)
                .width(size);

        heatmap_container.add(pv.Image)
                .width(size)
                .height(dataObj.item_height)
                .image( color.by(function(x,y){
            return dataObj.datamatrix[this.parent.index][Math.floor(x/dataObj.item_width)];}));

        var highlight_panel = heatmap_panel.add(pv.Panel);

        var highlighter = highlight_panel.add(pv.Panel)
                .data(function() { return [dataObj.active];})
                .visible(function(c) { return c > -1;})
                .fillStyle('rgba(255,255,255,1.0)')
                .strokeStyle('rgba(40,40,40,1)')
                .lineWidth(1)
                .width(size)
                .height((dataObj.item_height) * 4)
                .top(function(c) {
            return c * (dataObj.item_height + dataObj.item_row_padding) - ((dataObj.item_height) * 2);});
        highlighter.add(pv.Image)
                .image(color.by(function(x,y){
            return dataObj.datamatrix[dataObj.active][Math.round(x/dataObj.item_width)];}));

        highlighter.add(pv.Label)
                .visible(function(c) { return c > -1;})
                .right(size+5)
                .textBaseline('middle')
                .textAlign('right')
                .font(dataObj.row_label_font)
                .text(function(c) { return dataObj.row_label_prefix + dataObj.row_labels[c];});

        var col_label_panel = highlight_panel.add(pv.Panel)
                .data(function() { return [dataObj.column]; })
                .visible(function(c) { return c > -1 && dataObj.active > -1;})
                .left(function(c) { return (c * dataObj.item_width) + (dataObj.column  < (dataObj.datamatrix.length / 5) ? 0 :
                                (dataObj.column  > (dataObj.datamatrix.length * 3 / 5)) ?  ('Column: ' + dataObj.column_labels[c]).length *
                                        -6 : -50);})
                .width(function(c) { return (Math.max(('Column: ' + dataObj.column_labels[c]).length * 6,200));})
                .fillStyle('rgba(240,240,240,1.0)')
                .strokeStyle('rgba(40,40,40,1.0)')
                .lineWidth(0.5)
                .top(function() { return dataObj.active * (dataObj.item_height + dataObj.item_row_padding) +
                ((dataObj.item_height + dataObj.item_row_padding) * (dataObj.active  < (dataObj.datamatrix.length / 2) ? 3 : -9)) ;})
                .height(30)

        col_label_panel.anchor('left').add(pv.Label)
                .font(dataObj.row_label_font)
                .top(5)
                .text(function(c) { return 'Column: ' + dataObj.column_labels[c];})
              .add(pv.Label)
                .top(15)
                 .text(function(c) { return 'Value: ' +  dataObj.datamatrix[dataObj.active][dataObj.column];});

    var drag_panel = heatmap_panel.add(pv.Panel)
            .events('all')
            .data([{y:0,dy:0,fix:0}])
            .cursor('crosshair')
            .event('mousedown',pv.Behavior.select())
            .event('select',function() {drag_panel.render();})
            .event('selectend', function(d) {
                var begin = Math.round(d.y/(dataObj.item_height+dataObj.item_row_padding));
                var end = Math.round((d.y+d.dy)/(dataObj.item_height+dataObj.item_row_padding));
                if (end <= begin+1) { return; }
                var labels = pv.permute(dataObj.row_labels,pv.range(begin,end+1,1));
                dataObj.select_notifier(labels);})
          .add(pv.Bar)
            .left(-5)
            .width(5)
            .fillStyle('rgba(255,0,0,1)')
            .top(function(d){return d.y;})
            .height(function(d){return d.dy;})
            .strokeStyle(null)
            .lineWidth(1);

    var event_panel = drag_panel.add(pv.Panel)
               .events('all')
               .data(pv.range(0,dataObj.datamatrix.length))
               .height(dataObj.item_height)
               .top(function(c) { return c * (dataObj.item_height + dataObj.item_row_padding);})
               .fillStyle(null)
               .width(size)
               .event('mouseover',function(c){ dataObj.active = c; dataObj.column = Math.round((this.mouse().x)/dataObj.item_width)-1; highlight_panel.render()})
               .event('mousemove',function(c){dataObj.active = c; dataObj.column = Math.round((this.mouse().x)/dataObj.item_width)-1; highlight_panel.render()})
               .event('mouseout',function(c) { dataObj.active = -1; highlight_panel.render()})
               .event('click',function(c) { dataObj.row_click_notifier( dataObj.row_labels[dataObj.active]);});


        vis.render();
    };

/**

 */

vq.models.OmicsHeatmapData = function(data) {
    /**
     * @lends vq.models.OmicsHeatmapData#
     */
        vq.models.VisData.call(this,data);
    this._setDataModel();
    /**
     *  @augments vq.models.VisData
     *  @class The class which models the OmicsHeatmap data.  The JSON Object is parsed and analyzed to create the proper data structure for
     *  consumption by the OmicsHeatmap class.
     *
     * @constructs
     * @param {Class} $super - the {@link vq.models.VisData} class is passed into the instance on creation.
     * @param {JSON Object} data - JSON Object defined in {@link vq.OmicsHeatmap}.
     * @see vq.OmicsHeatmap
     */
        if (this.getDataType() == 'vq.models.OmicsHeatmapData') {
            this._build_data(this.getContents())
        } else {
            console.warn('Unrecognized JSON object.  Expected vq.models.OmicsHeatmapData object.');
        }
    };

vq.models.OmicsHeatmapData.prototype = pv.extend(vq.models.VisData);

    vq.models.OmicsHeatmapData.prototype._build_data = function(data) {
        this._processData(data);

        if (this.row_labels === []) this.row_labels = pv.repeat(['Default'],this.datamatrix.length);
        this.imagematrix = [];
          this.setDataReady(true);
      };


vq.models.OmicsHeatmapData.prototype._setDataModel = function() {
          this._dataModel = [
              {label: 'width', id: 'PLOT.width', cast : Number, defaultValue: 400},
              {label: 'height', id: 'PLOT.height', cast : Number, defaultValue: 400},
              {label : 'container', id:'PLOT.container', optional : true},
              {label:  'vertical_padding', id: 'PLOT.vertical_padding', cast : Number, defaultValue: 0},
              {label:  'horizontal_padding', id: 'PLOT.horizontal_padding',cast : Number,  defaultValue: 0},
              {label : 'datamatrix', id: 'data_matrix', defaultValue : [[]] },
              {label : 'item_width', id: 'item_width', cast: Number, defaultValue : 8 },
              {label : 'item_height', id: 'item_height', cast: Number, defaultValue : 8 },
              {label : 'item_row_padding', id: 'item_row_padding', cast: Number, defaultValue : 1 },
              {label : 'item_column_padding', id: 'item_column_padding', cast: Number, defaultValue : 2 },
              {label : 'row_labels' , id: 'row_labels', defaultValue : []},
              {label : 'column_labels' , id: 'column_labels', defaultValue : []},
              {label : 'row_label_prefix' , id: 'row_label_prefix', cast : String, defaultValue : ''},
              {label : 'row_label_font', id: 'row_label_font', cast: String, defaultValue : '10pt helvetica serif'},
              {label : 'row_click_notifier', id: 'row_click_notifier', cast: vq.utils.VisUtils.wrapProperty, defaultValue : function(a) {} },
                  {label : 'select_notifier', id: 'select_notifier', cast: vq.utils.VisUtils.wrapProperty, defaultValue : function(a) {} },
              {label : 'tooltipItems', id: 'CONFIGURATION.tooltip_items', defaultValue :
              {X : 'x' , Value : 'y'} }
          ];
      };
