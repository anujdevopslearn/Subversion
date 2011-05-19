/**
 * Created by IntelliJ IDEA.
 * User: rkreisbe
 * Date: Oct 14, 2010
 * Time: 10:03:04 AM
 *
 */

if (!vq)
    var vq = {};
if (!vq.models)
    vq.models = {};
if (!vq.protovis)
    vq.protovis = {};
if (!vq.PaCo)
    vq.PaCo = {};

vq.PaCo.SelectionGrid = function(term_str,div,populate_handler,singleSelection_handler,articleSelect_handler,searchTerm_handler) {

        this.table = new google.visualization.Table(div);
        this.div = div;
        this.options = {alternatingRowStyle:true,showRowNumber:true,width:200, height:400};

        this.dt = this._buildTable();

        this.addselection_function = singleSelection_handler;
        this.populate_function = populate_handler;
        this.getArticles_function = articleSelect_handler;
        this.searchTerm_function = searchTerm_handler;
        this.render();
};

vq.PaCo.SelectionGrid.prototype.getSelectedItem = function() {
       return this.table.getSelection();
    };

vq.PaCo.SelectionGrid.prototype._buildTable = function() {
         var dt = new google.visualization.DataTable();
        dt.addColumn("string","Cell Type","name");
        return dt;
    };

vq.PaCo.SelectionGrid.prototype.appendDataItem = function(item){
        if (item instanceof Array) {
            for ( i=0;i<item.length;i++) {
                this.addUniqueItem(item[i]);
            }
        } else {
            this.addUniqueItem(item)
        }
    };

vq.PaCo.SelectionGrid.prototype.addUniqueItem = function(item) {
        var that = this;
        if (this.dt.getFilteredRows([{column:0,value:item.label}]).length < 1){
            this.dt.addRow([item.label]);
            this.table.draw(that.dt,that.options);
        }
    };

vq.PaCo.SelectionGrid.prototype.setStore = function(term_array){
        var that = this;
        this.dt = this._buildTable();
        this.dt.addRows(term_array.map(function(c) { return [c];}));
        this.table.draw(that.dt,that.options);
    };

vq.PaCo.SelectionGrid.prototype.render = function() {
        var that = this;
        this.div.innerHTML='';

        this.table.draw(that.dt,that.options);

}
