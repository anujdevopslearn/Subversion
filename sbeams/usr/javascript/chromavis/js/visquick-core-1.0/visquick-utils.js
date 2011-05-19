


if (!vq)
    var vq = {};
/**
 * @namespace - the parent class of all data models for Protovis-based Visualization Tool Data
 */
if (!vq.models)
    vq.models = {};
/**
 * @namespace - the parent class for utility classes focused on visualization tools.
 */
if (!vq.utils)
    vq.utils = {};

vq.Base = function() {
      this.$properties = {};
};

vq.Base.prototype.properties = {};
vq.Base.cast = {};

vq.Base.prototype.extend =  function(proto) {
  return this;
};


vq.Base.prototype.property = function(name, cast) {
  if (!this.hasOwnProperty("properties")) {
    this.properties = pv.extend(this.properties);
  }
  this.properties[name] = true;

  /*
   * Define the setter-getter globally, since the default behavior should be the
   * same for all properties, and since the Protovis inheritance chain is
   * independent of the JavaScript inheritance chain. For example, anchors
   * define a "name" property that is evaluated on derived marks, even though
   * those marks don't normally have a name.
   */
  vq.Base.prototype.propertyMethod(name, vq.Base.cast[name] = cast);
  return this;
};


/** @private Sets the value of the property <i>name</i> to <i>v</i>. */
vq.Base.prototype.propertyValue = function(name, v) {
  var properties = this.$properties;
  properties[name] = v;
  return v;
};

/**
 * @private Defines a setter-getter for the specified property.
 *
 * <p>If a cast function has been assigned to the specified property name, the
 * property function is wrapped by the cast function, or, if a constant is
 * specified, the constant is immediately cast. Note, however, that if the
 * property value is null, the cast function is not invoked.
 *
 * @param {string} name the property name.
 * @param {function} [cast] the cast function for this property.
 */
vq.Base.prototype.propertyMethod = function(name, cast) {
  if (!cast) cast = vq.Base.cast[name];
  this[name] = function(v) {

      /* If arguments are specified, set the property value. */
      if (arguments.length) {
        var type = (typeof v == "function");
        this.propertyValue(name, (type & 1 && cast) ? function() {
            var x = v.apply(this, arguments);
            return (x != null) ? cast(x) : null;
          } : (((v != null) && cast) ? cast(v) : v)).type = type;
        return this;
      }

      return (this.$properties[name] != null) ? (typeof this.$properties[name] == "function") & 1 ?
             this.$properties[name].apply(this) :
              this.$properties[name] : null;
    };
};


vq.Vis = function() {
   vq.Base.call(this);
};

vq.Vis.prototype = pv.extend(vq.Base);

vq.Vis.prototype
    .property("vertical_padding",Number)
    .property("horizontal_padding",Number)
    .property("width", Number)
    .property("height", Number)
    .property("container",  function(c) {
            return (typeof c == "string")
            ? document.getElementById(c)
            : c; // assume that c is the passed-in element
      });


vq.models.VisData = function(data){
    /** @lends vq.models.VisData# */

    /**
     * It contains a meta-tag for the included data, as well as the data in JSON format.
     *
     * @constructs
     * @param data - a JSON object
     * @param {String} data.DATATYPE - a string describing the contents of the JSON data object
     * @param {JSON} data.CONTENTS - a JSON object containing the necessary input to create the visualization
     */
        if (data.DATATYPE != null) {
            this.DATATYPE = data.DATATYPE;
        } else {
            this.DATATYPE = "VisData";
        }

        if (data.CONTENTS != null) {
            this.CONTENTS = data.CONTENTS;
        }
        /**@private */
        this._ready=false;
    };

/**
 *  Returns an identifying string used to specify the <i>CONTENTS</i>.  This ensures that the data is properly parsed by a visualization
 *  which may accept multiple JSON formats.
 *
 * @return {String} dataType - a string describing the contents of the JSON object. This can be used to verify that the
 *  data is the correct format for the visualization.
 */


vq.models.VisData.prototype.getDataType = function() {
    return this.DATATYPE;
};

/**
 *  Returns the JSON object used to contain the data, parameters, options, behavior functions, and other information necessary
 *  to create a visualization.
 *
 * @return {JSON} dataType -a JSON Object containing the necessary input to create the visualization.
 */

vq.models.VisData.prototype.getContents = function() {
    return this.CONTENTS;
};
vq.models.VisData.prototype.get =  function(prop) {
    var parts = prop.split('.');
    var obj = this;
    for(var i = 0; i < parts.length - 1; i++) {
        var p = parts[i];
        if(obj[p] === undefined) {
            obj[p] = {};
        }
        obj = obj[p];
    }
    p=parts[parts.length -1];
    return obj[p] === undefined ?  undefined : obj[p];
};


vq.models.VisData.prototype.set = function(prop,value) {
    var parts = prop.split('.');
    var obj = this;
    for(var i = 0; i < parts.length - 1; i++) {
        var p = parts[i];
        if(obj[p] === undefined) {
            obj[p] = {};
        }
        obj = obj[p];
    }
    p = parts[parts.length - 1];
    obj[p] =  value === undefined ? null : value;
    return this;
};

    vq.models.VisData.prototype.isDataReady = function() {
        return this._ready;
    };

    vq.models.VisData.prototype.setDataReady = function(bool) {
        this._ready = Boolean(bool);
    };


vq.models.VisData.prototype.setValue = function(data,o) {
    var get = vq.utils.VisUtils.get;
    if (typeof get(data,o.id) == 'function') {
        this.set(o.label, get(data,o.id));
        return;
    }
    else {
        if(o.cast) {
            this.set(o.label, o.cast(get(data,o.id)));
            return;
        } else {
            this.set(o.label,get(data,o.id));
            return;
        }
    }
};


vq.models.VisData.prototype._processData = function(data) {
    var that = this;
    var get = vq.utils.VisUtils.get;

    if(!this.hasOwnProperty('_dataModel')) {
        this._dataModel = pv.extend(this._dataModel);
    }
    data = Object(data);
    this['_dataModel'].forEach(function(o) {
        try{
            if (!typeof o == 'object') { return;}
            //use default value if nothing defined
            if (!o.optional) {
                if (get(data,o.id)  === undefined) {
                    that.set(o.label,o.defaultValue || o['cast'](0));
                } else { //o.id value is found and not optional
                    that.setValue(data,o);
                }
            }  else {  // it is optional
                if (get(data,o.id)  === undefined) {
                    return;  //don't set it
                } else {
                    that.setValue(data,o);    //set it
                }
            }
        } catch(e) {
            console.warn('Unable to import property \"'+ o.id +'\": ' + e);
        }
    });
};

/**
 *
 *
 * Used as a static class object to reserve a useful namespace.
 *
 * @class Provides a set of static functions for use in creating visualizations.
 * @namespace A set of simple functions for laying out visualizations rapidly.
 *
 */

vq.utils.VisUtils =  {};
    /**
     * Utility function for the creation of a div with specified parameters.  Useful in structuring interface for
     * multi-panel cooperating visualizations.
     *
     * @static
     * @param {String} id -  the id of the div to be created.
     * @param {String} [className] - the class of the created div
     * @param {String} [innerHTML] - text to be included in the div
     * @return divObj - a reference to the div (DOM) object
     *
     */
    vq.utils.VisUtils.createDiv = function(id, className, innerHtml) {
        var divObj;
        try {
            divObj = document.createElement('<div>');
        } catch (e) {
        }
        if (!divObj || !divObj.name) { // Not in IE, then
            divObj = document.createElement('div')
        }
        if (id) divObj.id = id;
        if (className) {
            divObj.className = className;
            divObj.setAttribute('className', className);
        }
        if (innerHtml) divObj.innerHTML = innerHtml;
        return divObj;
    };

    /**
     * Ext.ux.util.Clone Function
     * @param {Object/Array} o Object or array to clone
     * @return {Object/Array} Deep clone of an object or an array
     * @author Ing. Jozef Sak�lo?
     */
    vq.utils.VisUtils.clone = function(o) {
        if(!o || 'object' !== typeof o) {
            return o;
        }
        var c = '[object Array]' === Object.prototype.toString.call(o) ? [] : {};
        var p, v;
        for(p in o) {
            if(o.hasOwnProperty(p)) {
                v = o[p];
                if(v && 'object' === typeof v) {
                    c[p] = vq.utils.VisUtils.clone(v);
                }
                else {
                    c[p] = v;
                }
            }
        }
        return c;
    }; // eo function clone

vq.utils.VisUtils.get =  function(obj,prop) {
    var parts = prop.split('.');
    for(var i = 0; i < parts.length - 1; i++) {
        var p = parts[i];
        if(obj[p] === undefined) {
            obj[p] = {};
        }
        obj = obj[p];
    }
    p=parts[parts.length -1];
    return obj[p] === undefined ?  undefined : obj[p];
};



vq.utils.VisUtils.set = function(obj,prop,value) {
    var parts = prop.split('.');
    for(var i = 0; i < parts.length - 1; i++) {
        var p = parts[i];
        if(obj[p] === undefined) {
            obj[p] = {};
        }
        obj = obj[p];
    }
    p = parts[parts.length - 1];
    obj[p] = value || null;
    return this;
};

//sorting functions, etc

    vq.utils.VisUtils.alphanumeric = function(comp_a,comp_b) {	//sort order -> numbers -> letters
        if (isNaN(comp_a || comp_b))  { // a is definitely a non-integer
            if (isNaN( comp_b || comp_a)) {   // both are non-integers
                return [comp_a, comp_b].sort();   // sort the strings
            } else {                // just a is a non-integer
                return 1;           // b goes first
            }
        } else if (isNaN(comp_b || comp_a)) {  // only b is a non-integer
            return -1;          //a goes first
        } else {                                    // both are integers
            return Number(comp_a) - Number(comp_b);
        }
    },


//function network_node_id(node) { return node.nodeName + node.start.toFixed(4) + node.end.toFixed(4);};
    vq.utils.VisUtils.network_node_id = function(node) {
        var map = vq.utils.VisUtils.options_map(node);
        if (map != null && map['label'] != undefined)
        {return map['label'];}
        return node.nodeName + node['start'].toFixed(2) + node['end'].toFixed(2);
    };

//function network_node_id(node) { return node.nodeName + node.start.toFixed(4) + node.end.toFixed(4);};
    vq.utils.VisUtils.network_node_title = function(node) {
        var map = vq.utils.VisUtils.options_map(node);
        if (map != null && map['label'] != undefined)
        {return map['label'] + ' \n' +  'Chr: ' + node.nodeName +
                '\nStart: ' + node['start'] +
                '\nEnd: ' + node['end'];}
        return node.nodeName + ' ' +  node['start'].toFixed(2) + ' ' + node['end'].toFixed(2);
    };

//function tick_node_id(tick) { return tick.chr + tick.start.toFixed(4) + tick.end.toFixed(4);};
    vq.utils.VisUtils.tick_node_id = function(tick) { return tick.value;};

    vq.utils.VisUtils.parse_pairs = function(column,assign_str,delimit_str) {
        var map = {}, pair_arr =[], pairs = [];
            pair_arr =[];
            pairs = column.split(delimit_str);
            for (var i=0;i< pairs.length; i++) {
                pair_arr = pairs[i].split(assign_str);
                if (pair_arr.length == 2) {
                    map[pair_arr[0]] = pair_arr[1];
                }
            }
        return map;
    };

    vq.utils.VisUtils.options_map = function(node) {
        var options_map = {};
        if (node.options != null) {
            options_map = vq.utils.VisUtils.parse_pairs(node.options,'=',',');
        }
        return options_map;
    };

    vq.utils.VisUtils.wrapProperty = function(property) {
        if (typeof property == 'function'){
            return property;
        } else {
            return function() {return property;}
        }
    };

vq.utils.VisUtils.pivotArray = function(array,pivot_on,group_by,value_id,aggregate_object,
                                        include_other_properties,filter_incomplete){

    var dims =  pv.uniq(array.map(function(c) { return c[pivot_on];})).sort();

    var nested_data = pv.nest(array)
            .key(function(d) { return d[group_by];})
            .map();

    var data = pv.values(nested_data).map(function(pivot_array){
        var new_object = {};
        if (include_other_properties) {
            new_object = vq.utils.VisUtils.clone(pivot_array[0]);
            delete new_object[value_id];
            delete new_object[pivot_on];}
        else {
            new_object[group_by] = pivot_array[0][group_by];
        }
        pivot_array.forEach(  function(pivot_object) {
            new_object[pivot_object[pivot_on]] = pivot_object[value_id];
        });

        if (aggregate_object) {
            switch(aggregate_object.operation) {
                case 'collect' :
                    new_object[aggregate_object.column] = pv.map(pivot_array, function(data) { return data[aggregate_object.column];});
                    break;
                case 'mean':
                    new_object[aggregate_object.column] = pv.mean(pivot_array, function(data) { return data[aggregate_object.column];});
                    break;
                case 'min':
                    new_object[aggregate_object.column] = pv.min(pivot_array, function(data) { return data[aggregate_object.column];});
                    break;
                case 'max':
                    new_object[aggregate_object.column] = pv.max(pivot_array, function(data) { return data[aggregate_object.column];});
                    break;
                case 'sum':
                default:
                    new_object[aggregate_object.column] = pv.sum(pivot_array, function(data) { return data[aggregate_object.column];});
            }
        }
        return new_object;
        //filter out any data points which are missing a year or more
    });
    if(filter_incomplete) data = data.filter(function(d) { return dims.every(function(dim) { return d[dim];} );});
    return data;

};

vq.utils.VisUtils.layoutChrTiles = function(tiles,overlap) {
    var new_tiles = [], chr_arr = [];
    chr_arr = pv.uniq(tiles, function(tile) { return tile.chr;});
    chr_arr.forEach(function(chr) {
        new_tiles = pv.blend([new_tiles,
                vq.utils.VisUtils.layoutTiles(tiles.filter(function(tile) { return tile.chr == chr;}),overlap)]);
    });
    return new_tiles;
};

//tiles : {Array} of tiles.  tile is composed of start,end
// this returns an array with tile appended with a 'level' property representing a linear layout
// of non-overlapping Tiles

vq.utils.VisUtils.layoutTiles = function(tiles,overlap) {

    tiles.forEach (function(b) { b.tile_length = (b.end - b.start);});  // generate a tile length property
    tiles = tiles.sort(function(a,b) { return (a.tile_length < b.tile_length) ? -1 :
            (a.tile_length > b.tile_length) ? 1 : a.start < b.start ? -1 : 1 ;}).reverse();         //sort all tiles by tile length
    if (tiles.length) {tiles[0].level = 0;}
    tiles.forEach(function(tile,index,array) {

        var levels = array.slice(0,index).map(function(a){return vq.utils.VisUtils._isOverlapping(a,tile,overlap || 0) ? a.level : null;});
        levels = levels.filter(function(a) { return a != null;}).sort(pv.naturalOrder);
        var find = 0, l_index =0;
        while (find >= levels[l_index]) {
            if (find == levels[l_index]) { find++;}
            l_index++;
        }
        tile.level = find;
    });
    return tiles;
};

vq.utils.VisUtils._isOverlapping = function(tile1,tile2,overlap) {
    return ((tile1.start-overlap) <= tile2.end && (tile1.end + overlap) >= tile2.start);
};


/**
 * Provides a set of static functions for use in converting
 * a google.visualization.DataTable object into a Protovis consumable
 * JSON array.
 *
 * Intended to be used as a static class object to reserve a useful namespace.
 *
 * For the Circvis project, the fundamental data element is <b>node</b> JSON object consisting of:
 *      {chromosome, start, end, value, options}
 *          {string} chromosome
 *          {integer} start
 *          {integer} end
 *          {string} value
 *          {string} options
 *
 *
 *
 */

vq.utils.GoogleDSUtils = {};

    /**     Converts any DataTable object into an array of JSON objects, each object consisting of a single row in the
     *      DataTable.  The property label is obtained from the getColumnLabel() function of the google.visualiztion.DataTable class.
     *
     *      Column types listed as a 'number' are passed in as numeric data.  All other data types are passed in as strings.
     *
     *      The returned JSON array conforms to the common input format of Protovis visualizations.
     *
     * @param googleDataTable - google.visualizations.DataTable object returned by a google datasource query
     * @return data_array - JSON array.
     */


    vq.utils.GoogleDSUtils.dataTableToArray = function(googleDataTable) {
        var table = googleDataTable,
        data_array=[],
        headers_array=[],
        column_type=[];
        if (table == null) { return [];}
        for (col=0; col<table.getNumberOfColumns(); col++){
            headers_array.push(table.getColumnLabel(col));
            column_type.push(table.getColumnType(col));
        }


        for (row=0; row<table.getNumberOfRows(); row++){
            var temp_hash={};
            for (col=0; col<table.getNumberOfColumns(); col++){
                if(column_type[col].toLowerCase() == 'number') {
                    temp_hash[headers_array[col]]=table.getValue(row,col);
                } else {
                    temp_hash[headers_array[col]]=table.getFormattedValue(row,col);
                }
            }
            data_array.push(temp_hash);
        }
        return data_array;
    };

    /**
     *  Converts a special DataTable object into a network object used by CircVis.
     *  For a DataTable with fields: chr1, start1, end1, value1, options1, chr2, start2, end2, value2, options2, linkValue
     *  the function returns an array of JSON objects consisting of two <b>node</b> JSON objects and a <b>linkValue</b>:
     *  {node1,node2,linkValue}
     *
     *  The JSON array can then be passed into the NETWORK.DATA.data_array parameter used to configure Circvis.
     *
     * @param googleDataTable - google.visualizations.DataTable object returned by a google datasource query
     * @returns network_json_array - a JSON array which can be used into Protovis code.  Each element contains
     */

    vq.utils.GoogleDSUtils.dataTableToNetworkArray = function(googleDataTable) {
        var data_array = this.dataTableToArray(googleDataTable);
        return data_array.map(function(c) { return {node1 : {chr:c['chr1'],start:c['start1'],end:c['end1'],value:c['value1'],options:c['options1']},
        node2 : {chr:c['chr2'],start:c['start2'],end:c['end2'],value:c['value2'],options:c['options2']}, linkValue:c['linkValue']};});
    };

    /** @private */
    vq.utils.GoogleDSUtils.getColIndexByLabel = function(table,label) {
        for (col = 0; col < table.getNumberOfColumns(); col++) {
            if (label.toLowerCase() == table.getColumnLabel(col).toLowerCase()) {
                return col;
            }
        }
        return -1;
    };


/**
 * Constructs a utility object for use with multiple-source Ajax requests.
 * If data must be retrieved from several sources before a workflow may be started, this tool can be used to
 * check that all necessary data is available.
 *
 * @param {integer} timeout number of milliseconods between checks for valid data.  Defaults to 200ms.
 * @param {total_checks}  total number of checks to perform. Defaults to 20.
 * @param {callback}    function to call if all data is successfully found
 * @param {args}    an object containing the variables which will be assigned values by the Ajax responses.
 */

vq.utils.SyncDatasources = function(timeout,total_checks,callback,args){

        if (timeout && timeout instanceof Number) {
            this.timeout = timeout;
        } else {
            this.timeout = 200;
        }
        if (total_checks && total_checks instanceof Number) {
            this.num_checks_until_quit = total_checks;
        } else {
            this.num_checks_until_quit = 20;
        }
        if (args instanceof Object) {
            this.args = args;
        } else {
            console.log('Error: variable array not passed to timer initialize method.');
            return;
        }
        if (callback instanceof Function) {
            this.callback = callback
        } else {
            console.log('Error: callback function not passed to timer initialize method.');
            return;
        }
        this.num_checks_so_far = 0;
    };

    /**
     * Initiates the data object poll.  After the maximum number of checks, a log is filed on the console and the object
     *  aborts the polling operation.
     */

    vq.utils.SyncDatasources.prototype.start_poll = function() {
        var that = this;
        setTimeout(function() { that.poll_args();},that.timeout);
    };

    /** @private */
    vq.utils.SyncDatasources.prototype.check_args = function(){
        var check = true;
        for (arg in this.args) {
            if (this.args[arg] == null) { check = false;}
        }
        return check;
    };

    /** @private */
    vq.utils.SyncDatasources.prototype.poll_args = function(){
        var that=this;
        if (this.check_args()) { this.callback.apply(); return false;}
        this.num_checks_so_far++;
        if(this.num_checks_so_far >= this.num_checks_until_quit) {
            console.log('Maximum number of polling events reached.  Datasets not loaded.  Aborting.');
            return false;
        }
        setTimeout(function() { that.poll_args();},that.timeout)
    };

vq.Hovercard = function(options) {

        this.hovercard = vq.utils.VisUtils.createDiv('hovercard');
        this.hovercard.style.display = 'hidden';


    if (options) {
        this.include_footer = options.include_footer != null ? options.include_footer : false;
        this.include_header = options.include_header != null ? options.include_header : true;
        this.data_config = options.data_config ? options.data_config : null;
        this.self_hover = options.self_hover ? options.self_hover : false;
    }

};

vq.Hovercard.prototype.show = function(anchorTarget,dataObject) {
    if (!anchorTarget) { throw 'vq.Hovercard.show: target div not found.'; return;}
    if (anchorTarget.hasChildNodes()) {anchorTarget.innerHTML ='';anchorTarget.appendChild(this.hovercard);}
    else {anchorTarget.appendChild(this.hovercard);}
    var html = this.renderCard(dataObject);
    this.hovercard.innerHTML = html;
    if (this.include_footer) this.hovercard.appendChild(this.renderFooter());
    this.hovercard.style.display = 'block';
    this.hovercard.style.backgroundColor = 'white';
    this.hovercard.style.borderWidth = '2px';
    this.hovercard.style.borderColor = '#222';
    this.hovercard.style.borderStyle = 'solid';
    this.hovercard.style.font = "9px sans-serif";

};

vq.Hovercard.prototype.hide = function() {
    if(!this.self_hover || !this.over_self) {
    this.hovercard.style.display = 'none';
    }
};

vq.Hovercard.prototype.isHidden = function() {
    return this.hovercard.style.display == 'none';
};

vq.Hovercard.prototype.renderCard = function(dataObject) {
          return this.renderData(dataObject);
};

vq.Hovercard.prototype.renderData = function(dataObject) {
    var html = '';
    var get = vq.utils.VisUtils.get;
    var table = document.createElement('table');
    if (typeof dataObject == 'object') {
        if (this.include_header) {
            var thead = table.createTHead();
            var thead_row = thead.insertRow(-1);
            var thead_cell = thead_row.insertCell(-1);
            thead_cell.innerHTML = 'Property';
            thead_cell = thead_row.insertCell(-1);
            thead_cell.innerHTML = 'Value';
        }
        var tBody = document.createElement("tbody");
        table.appendChild(tBody);

        if (this.data_config) {
            for (var key in this.data_config) {
                try {
                    if (!this.data_config.hasOwnProperty(key)) continue;
                    var trow = tBody.insertRow(-1);
                    var tcell= trow.insertCell(-1);
                    tcell.innerHTML = '<b>' + key + '</b>:';
                    tcell= trow.insertCell(-1);
                    if (typeof  this.data_config[key] == 'function') {
                        tcell.innerHTML= '<span>' +  this.data_config[key](dataObject) + '</span>';
                    }else {
                        tcell.innerHTML= '<span>' +  get(dataObject,this.data_config[key]) + '</span>';
                    }
                } catch(e) {
                    console.warn('Data not found for tool tip: ' + e);
                }

            }
        } else {
            pv.keys(dataObject).forEach(function(key) {
                try {
                    var trow = tBody.insertRow(-1);
                    var tcell= trow.insertCell(-1);
                    tcell.innerHTML = '<b>' + key + '</b>:';
                    tcell = trow.insertCell(-1);
                    tcell.innerHTML = '<span>' + get(dataObject,key) + '</span>';
                } catch (e) {
                    console.warn('Data not found for tool tip: ' + e);
                }
            });
        }

    }
    else if ( typeof dataObject == 'string') {
        return dataObject;
    }
    function outerHTML(node){
        // if IE, Chrome take the internal method otherwise build one
        return node.outerHTML || (
                                 function(n){
                                     var div = document.createElement('div'), h;
                                     div.appendChild( n.cloneNode(true) );
                                     h = div.innerHTML;
                                     div = null;
                                     return h;
                                 })(node);
    }
    return outerHTML(table);
};

vq.Hovercard.prototype.getContainer = function() {
    return this.hovercard;
};

vq.Hovercard.prototype.renderFooter = function() {
    var footer = document.createElement('p');
    footer.style.textAlign = 'right';
    var close = document.createElement('a');
    close.href = "#";
    function hideHovercard() {
        document.getElementById('hovercard').style.display = "none";
    }
    close.onclick = hideHovercard;
    close.innerHTML = 'CLOSE [X]';
    footer.appendChild(close);
    return footer;
};


pv.Behavior.hovercard = function(opts) {

    var hovercard, anchor_div, outtimer_id,target, timeout = 800;
    var hovercard_div_id =  'vq_hover';


    function startOutTimer() {
        if (!outtimer_id){ outtimer_id = window.setTimeout(trigger,timeout); }
    }

    function cancelOutTimer() {
        if (outtimer_id){
            window.clearTimeout(outtimer_id);
            outtimer_id = null;
        }
    }

    function trigger() {
        if(outtimer_id) {
            window.clearTimeout(outtimer_id);
            outtimer_id = null;
            target.onmouseout = null;
            hovercard.hide();
        }
    }
    return function(d) {
        var info = opts.param_data ? d : (this instanceof pv.Mark ? (this.data() ||  this.title()) : d);
        if (hovercard && hovercard.getContainer() &&
                hovercard.getContainer().style.display != 'none') {return;}
        var t= pv.Transform.identity, p = this.parent;
        do {
            t=t.translate(p.left(),p.top()).times(p.transform());
        } while( p=p.parent);

         var c = this.root.canvas();
        c.style.position = "relative";
       // c.onmouseout = trigger;

        if (!document.getElementById(hovercard_div_id)) {
            anchor_div = vq.utils.VisUtils.createDiv(hovercard_div_id);
            c.appendChild(anchor_div);
            anchor_div.style.position = "absolute";
        }
        else {
            anchor_div = document.getElementById(hovercard_div_id);
            if (anchor_div.parentNode.id != c.id) {
                c.appendChild(anchor_div);
                }
            }
        hovercard = new vq.Hovercard(opts);


        target = pv.event.target;
         target.onmouseout = startOutTimer;

        hovercard.getContainer().onmouseover = cancelOutTimer;
        hovercard.getContainer().onmouseout = startOutTimer;

        if (this.properties.radius) {
            var r = this.radius();
            t.x -= r;
            t.y -= r;
        }
        var width = this.width() ? this.width() : this.properties.radius ? this.radius() * 2 : 0;
        var height = this.height() ? this.height() : this.properties.radius ? this.radius() * 2 : 0;

        anchor_div.style.left = opts.on_mark ? Math.floor(this.left() * t.k + t.x) + width + "px" : this.parent.mouse().x + t.x + 20 + "px";
        anchor_div.style.top = opts.on_mark ? Math.floor(this.top() * t.k + t.y) + height + "px" : this.parent.mouse().y + t.y + 20 + "px";

        hovercard.show(anchor_div,this.data() || this.title());

    };
};


pv.Behavior.flextip = function(opts) {

    var hovercard, anchor_div,timeout_id;
    var timeout = opts.timeout || 1000;
    var hovercard_div_id =  'vq_hover';


    function trigger() {
        if(timeout_id) {
            window.clearTimeout(timeout_id);
            timeout_id = null;
        }
        if (hovercard) {  hovercard.hide();}
    }

    return function(d) {
        var info = opts.param_data ? d : (this instanceof pv.Mark ? (this.data() ||  this.title()) : d);
        if (hovercard && hovercard.getContainer() &&
                hovercard.getContainer().style.display != 'none') {return;}
        var t= pv.Transform.identity, p = this.parent;
        do {
            t=t.translate(p.left(),p.top()).times(p.transform());
        } while( p=p.parent);

        var c = this.root.canvas();
        c.style.position = "relative";
        c.onmouseout = trigger;

        if (!document.getElementById(hovercard_div_id)) {
            anchor_div = vq.utils.VisUtils.createDiv(hovercard_div_id);
            c.appendChild(anchor_div);
            anchor_div.style.position = "absolute";
        }
        else {
            anchor_div = document.getElementById(hovercard_div_id);
            if (anchor_div.parentNode.id != c.id) {
                c.appendChild(anchor_div);
            }
        }


        hovercard = new vq.Hovercard(opts);
        pv.event.target.onmouseout = trigger;


        if (this.properties.radius) {
            var r = this.radius();
            t.x -= r;
            t.y -= r;
        }
        var width = this.width() ? this.width() : this.properties.radius ? this.radius() * 2 : 0;
        var height = this.height() ? this.height() : this.properties.radius ? this.radius() * 2 : 0;

         anchor_div.style.left = opts.on_mark ? Math.floor(this.left() * t.k + t.x) + width + "px" : this.parent.mouse().x + t.x +20 + "px";
          anchor_div.style.top = opts.on_mark ? Math.floor(this.top() * t.k + t.y) + height + "px" : this.parent.mouse().y + t.y +20 + "px";

        function showTip() {
            hovercard.show(anchor_div,info);
            timeout_id = null;
        }
        timeout_id = window.setTimeout(showTip,timeout);

    };
};




