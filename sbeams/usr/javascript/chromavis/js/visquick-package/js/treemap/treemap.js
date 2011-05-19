/**
*
*
* @class
*
*
*
*
*
*
*
*
*
*
*
*
*  @extends vq.Vis
*/

vq.Treemap = function(){
    vq.Vis.call(this);

    //set option variables to useful values before options are set.
    this.height(400);     // defaults
    this.width(500);     // defaults
    this.vertical_padding(10);
    this.horizontal_padding(10);
    this.selection([]);
};
vq.Treemap.prototype = pv.extend(vq.Vis);

vq.Treemap.prototype
        .property('selection');

/**
* 
*
* @type number
* @name sectionVertical_padding
*/


/**
*  @private set optional parameters passed in at draw
* @param options JSON object containing the passed in options
*/

vq.Treemap.prototype._setOptionDefaults = function(options) {

    if (options.height != null) { this.height(options.height); }

    if (options.width != null) { this.width(options.width); }

    if (options.vertical_padding != null) { this.vertical_padding(options.vertical_padding); }

    if (options.horizontal_padding != null) { this.horizontal_padding(options.horizontal_padding); }

    if (options.container != null) { this.container(options.container); }

    if (options.selection != null) { this.selection(options.selection); }

};

/**
*
*
* @param data JSON object containing data and Configuration
* @param options JSON object containing visualization options
*/

vq.Treemap.prototype.draw = function(data) {

    this._data = new vq.models.TreemapData(data);
    if (this._data.isDataReady()) {
        this._setOptionDefaults(this._data);
        this.render();
    }
};

/** @private renders the visualization as SVG model to the document DOM */

vq.Treemap.prototype.render = function() {

    var that = this;

var color = pv.Colors.category10().by(function(d) {return d.parentNode ? d.parentNode.nodeName : 'root';});



    function activeon(d) {
    d.active = true;
       treemap.reset();
  }
    function activeoff(d) {
    d.active = false;
  }

    var nodes =  that._data._root_node.nodes();
    var behavior = function(d) {
        return (pv.Behavior.flextip(
        {
            include_header : false,
            include_footer : false,
            self_hover : true,
            data_config : that._data.tooltipItems

        }
                ).call(this,d),
                activeon(d),
                this);};

    var vis = new pv.Panel()
            .width(that.width())
            .height(that.height())
            .left(that.horizontal_padding())
            .top(that.vertical_padding())
            .events('all')
            .canvas(that.container());

    var treemap = vis.add(pv.Layout.Treemap)
              .nodes(nodes)
              .padding(20)
              .round(true);


    treemap.node.add(pv.Bar)
          .fillStyle(function(d) { return  color(d).alpha(d.active ? 1 : .5);})
            .event("mouseover",behavior)
            .event("mouseout", function(d) {return (activeoff(d), this);})
            .event('click', that._data._notifier)
           .cursor('pointer')
            .anchor('top').add(pv.Label)
                .text(function(a) {return a.dx < 300 ? a.nodeName.slice(0,10) : a.nodeName;})
                .visible(function(a) { return a.firstChild;})
                .font('13px courier monospace')
                .textAngle(0);

    treemap.leaf.add(pv.Panel)
           .fillStyle(function(d) { return  color(d).alpha(d.active ? 1 : .5);})
            .event("mouseover",behavior)
            .event("mouseout", function(d) {return (activeoff(d), this);})
            .event('click', that._data._notifier)
           .cursor('pointer')
           .strokeStyle("#fff");

    treemap.label.add(pv.Label)
            .text(function(d) {return this.width() < 300 && this.height() < 400 ? d.nodeName.slice(0,10) : d.nodeName;})
            .textAngle(function(d) { return this.width() / this.height() > 0.7 ? 0 : -1 * Math.PI / 2;})
            .font(function(d) { return this.width() < 300 && this.height() < 400 ? Math.round((this.textAngle() == 0 ?
            ( this.width() / 5.5  ) : (this.height() / 5.5 )))  + 'px courier monospace' :
            Math.round((this.textAngle() == 0 ?
            ( this.width() / 20  ) : (this.height() / 20 )))  + 'px courier monospace';})
           .textStyle(function(d) { return pv.rgb(0, 0, 0, d.active ? 1 : .9);});

    vis.render();

};

/**
* Constructs the data model used in the Treemap visualization
* @class Represents the data, custom configuration, and behavioral functions
*
*
*  
* <pre> { data_array : {Array},
*	  columns : {Array}, 
*	  tooltipFormat : {Function},
*	  notifier : {Function},
* 	  CONFIGURATION : {
*			multiple_id : {string},
*			color_id : {string}
*			}
*	}
*	</pre>
*	
* @extends vq.models.VisData
*/

vq.models.TreemapData = function(data) {
    vq.models.VisData.call(this,data);

    this.setDataModel();

    if (this.getDataType() == 'vq.models.TreemapData') {
        this._build_data(this.getContents());
    } else {
        console.warn('Unrecognized JSON object.  Expected vq.models.TreemapData object.');
    }
};
vq.models.TreemapData.prototype = pv.extend(vq.models.VisData);

vq.models.TreemapData.prototype.setDataModel = function () {
    this._dataModel = [
        {label: 'width', id: 'PLOT.width', cast : Number, defaultValue: 700},
        {label: 'height', id: 'PLOT.height', cast : Number, defaultValue: 300},
        {label : 'container', id:'PLOT.container', optional : true},
        {label:  'vertical_padding', id: 'PLOT.vertical_padding', cast : Number, defaultValue: 20},
        {label:  'horizontal_padding', id: 'PLOT.horizontal_padding',cast : Number,  defaultValue:30},
        {label : 'selection', id: 'selection', defaultValue : [] },
        {label : '_data', id: 'data_array', defaultValue : [] },
        {label : '_tooltipFormat', id: 'tooltipFormat', defaultValue : function(a) {return 'Label: ' + a.nodeName;}},
        {label : 'tooltipItems', id: 'tooltip_items', defaultValue : {
            Name : 'nodeName',
            Parent : 'parentNode.nodeName'
        }  },
        {label : 'show_legend', id: 'CONFIGURATION.show_legend', cast: Boolean, defaultValue : false },
        {label : 'font', id: 'font', cast: String, defaultValue : "bold 14px sans-serif" },
        {label : '_notifier', id: 'notifier', cast : Function, defaultValue : function() {return null;}},
        {label : '_key', id: 'key', cast : String, defaultValue : 'id'},
        {label : '_key_delimiter', id: 'key_delimiter', cast : String, defaultValue : '.'},
        {label : '_value', id: 'value', cast : String, defaultValue : 'value'},
        {label : '_root', id: 'root_node', cast : String, optional : true, defaultValue : null}
    ];
};


vq.models.TreemapData.prototype._build_data = function(data) {
	var that = this;

    this._processData(data);
    this._create_dom();

    if (this._root_node.firstChild) {
        this.setDataReady(true);
    }
};


vq.models.TreemapData.prototype._create_dom = function() {
	var that = this;

    this._lookup = {};
    that._data.forEach(function(d) {that._lookup[d[that._key]] = d[that._value]; });

    this._tree = pv.tree(that._data)
                            .keys(function(d) { return d[that._key].split(that._key_delimiter); } )
                            .value(function(d) { return (d[that._key].split(that._key_delimiter).length+1)^1.4 ;})
                            .map();

    var vals = pv.values(that._tree);
    if (vals.length == 1){ this._root = pv.keys(that._tree)[0];this._tree = vals[0];}
    this._dom = pv.dom(that._tree);
    if (this._root) {
            this._root_node = this._dom.root(that._root);
    } else {
        this._root_node = this._dom.root();
    }
};
