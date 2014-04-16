/*
   This script is modified from ncbi 54545.js script for Old Peptidome page
 */

function sortFileSz(a,b){    
  var aSelector = jQuery(a.clonedRow[0]).children('[fsize]')
    var bSelector = jQuery(b.clonedRow[0]).children('[fsize]')
    var aVal = 0;
  var bVal = 0;
  if(aSelector.length > 0){ aVal = parseInt(aSelector.attr('fsize'));}
  if(bSelector.length > 0){ bVal = parseInt(bSelector.attr('fsize'));}

  return (aVal > bVal) ? this.options.sortColumnDir : (aVal < bVal) ? -this.options.sortColumnDir : 0;    
}

(function($) {

 if (typeof jQuery.ui === 'undefined') {
 jQuery.ui = {version:{}};
 } 
 jQuery.ui.PAcommon = function(){
 this.logged_in = "";

 this.redirect_href = '';

 this.projectsURL = '/passel';
 this.rootURL = this.projectsURL;
 //repositoryName does not appear anywhere else in this file.
 //      this.repositoryName = 'passel';
 this.pathname = window.location.pathname.replace('cgi\/PeptideAtlas\/GetSELExperiments', '');
 this.httpProxyLoadFunc = function(E,B,F,C,A){
 var EE = {}; 
 for(k in E){
 EE[k] = E[k];
 }	
 if(EE.start != 1){
   EE.start++;
 }
 if(this.fireEvent("beforeload",this,EE)!==false){
   var D={params:EE||{},request:{callback:F,scope:C,arg:A},reader:B,callback:this.loadResponse,scope:this};
   if(this.useAjax){
     Ext.applyIf(D,this.conn);
     if(this.activeRequest){
       Ext.Ajax.abort(this.activeRequest)
     }
     this.activeRequest=Ext.Ajax.request(D)
   }else{
     this.conn.request(D)
   }
 }else{
   F.call(C||this,null,A,false)
 }
 };
 this.formatIntComma = function (number) {
   number = '' + number;
   if (number.length > 3) {
     var mod = number.length % 3;
     var output = (mod > 0 ? (number.substring(0,mod)) : '');
     for (i=0 ; i < Math.floor(number.length / 3); i++) {
       if ((mod == 0) && (i == 0)){
	 output += number.substring(mod+ 3 * i, mod + 3 * i + 3);
       }else{
	 output+= ',' + number.substring(mod + 3 * i, mod + 3 * i + 3);
       }
     }
     return (output);
   }
   else return number;
 }


 this.query_url = this.projectsURL;
 this.editusr_url = this.projectsURL + "cgi/editusr.cgi";
 this.approvedState = {};
 //this.dataStoreParamNames =  {sort : "sortby", limit:'pgsize',dir : "orderby",start : "start"};
 this.dataStoreParamNames =  {sort : "sortby",
   fliterbystr: "filterstr",
   fliterbycol: "fliterbycol",
   limit:'pgsize',
   dir : "orderby",
   start : "start"};

 this.tabPanel = '';
 this.refreshList = {};

 this.queryms_url = this.query_url;

 this.changeWindowTitle = function(t){
   window.document.title = t;
 }

 var isEmpty = function(obj){    	

   if(!obj || typeof obj === 'undefined'){return true;}
   if(obj.length > 0){ return false;}
   return true;
 };
 this.isEmpty = isEmpty;



 this.get_url_parameter = function ( name )
 {
   name = name.replace( /[\[]/, "\\\[" ).replace( /[\]]/, "\\\]" );	
   var regexS = "[\\?&]" + name + "=([^&#]*)";

   var regex = new RegExp( regexS,'i' );
   var results = regex.exec( window.location.href );

   if( results == null ){
     if(typeof browseAttributes !== 'undefined'){
       if(browseAttributes[name]){
	 return browseAttributes[name];    		           
       }
     }
     return "";
   }
   else{
     //results[ 1 ] = results[ 1 ].replace(/^(%\d\d)+/,'');
     return results[ 1 ];
   }
 }  
 this.get_url_flag = function ( name )
 {
   name = name.replace( /[\[]/, "\\\[" ).replace( /[\]]/, "\\\]" );	
   var regexS = "[\\?&]" + name + "";

   var regex = new RegExp( regexS,'i' );
   var results = regex.exec( window.location.href );

   if( results == null ){    		    
     return false;
   }
   else{
     return true;
   }
 } 

 this.debug= false;
 this.debugFlag = 'debug';
 var isDebug = this.get_url_flag( this.debugFlag );
 this.debug= isDebug ? true :  false;

 this.setParamsObj = function( o ){
   o.filterstr = jQuery('input#searchq').val();
   o.filtercol = jQuery('select#selectedTitle').val();

   if (this.debug && !o[this.debugFlag]){
     o[this.debugFlag] = '';
   }
   return o;
 }

 var token_from_param = this.get_url_parameter( 'token' )
   this.token = token_from_param ? token_from_param : '';
 this.tokenAppendURL = '';	
 if(this.token){ this.tokenAppendURL = '&token='+this.token;}	

 this.ftp_url = "ftp://ftp:a@ftp.peptideatlas.org/pub/PeptideAtlas/Repository/";
 this.returnObj = [];

 this.layout_height = 700;
 this.tab_height = 26;
 var offset = 266; // originally 205
 this.numberPerPage = 30;	
 if( window.innerHeight ){
   window.innerHeight - offset; 
 }
 else if( document.body.clientHeight ){
   this.layout_height = document.body.clientHeight - offset;
 }        
 else if( document.documentElement && document.documentElement.clientHeight ){
   this.layout_height = document.documentElement.clientHeight - offset;
 }


 // calculate the number of rows based on the window size
 if(this.layout_height <  300){
   this.layout_height = 300;
   this.numberPerPage = 10 ;
 }    	
 else {
   this.numberPerPage = Math.round((this.layout_height - 2 - 55 - 33)/20) - 3; // - 0
 }

 var formatACC = function(id,type){
   var tmp = id+'';
   if(!tmp.match(/PAe/i)){
     id = 'PAe'+id;	
   }

   return id;
 }
 this.checkHashLink = function(){
   if(window.location.hash){
     var h = window.location.hash;

     var t = Ext.get(h.replace('#',''));

     if(t){			        
       //t.scrollIntoView();
       var XY = t.getXY();
       window.scrollTo(XY[0],XY[1]);
     }		
   }
 }
 function stCap(strObj){
   return(strObj.charAt(0).toUpperCase()+strObj.substr(1).toLowerCase());
 }
 function multiSort(a,b) {
   a = a.type+a.name;
   b = b.type+b.name;
   if( !b || !a){return 0;}
   //return a.localeCompare(b);
   return a == b ? 0 : (a < b ? -1 : 1)
 }

 this.filesTable = {};

 this.addViewMore = function(){

   var that = this;
   if(that.filesTable['levels'] > 0){ 
     jQuery('#dlTable table').ncbigrid();
   }

   if(typeof(that.filesTable) != "undefined" && that.filesTable['showOverage'] == true){
     var overageTxt = "<p>The table below displays a maximum of 100 files. <a href='"+that.ftpLinkUrl+"'>You may view all  files for this accession here</a></p>";
     var ovrD = jQuery('#overage');
     if( ovrD.length>0 && that.ftpLinkUrl){ovrD.html(overageTxt);}

   }  

   return true;
   var fTable = jQuery('#dlTable table'); 


   if(typeof(that.filesTable) == "undefined" || that.filesTable['levels'] == 0){return false;}    	    

   if (fTable.length > 0){
     if(that.filesTable['levels'] > 0){ 
       var moreLessLinks = jQuery('<div class="morebox"><a href="#" id="moreboxLess">view less</a><a href="#" id="moreboxMore">view more</a><span id="moreboxPerpage"></span></div>');
       fTable.parent().append( moreLessLinks );
       jQuery('a#moreboxLess,a#moreboxMore').click(function(){
	   var element = jQuery(this);
	   var isMoreClick = false;
	   if(element.attr('id') == 'moreboxMore'){ isMoreClick = true; }

	   var workingSet = that.filesTable['current'] ;
	   if (isMoreClick){ workingSet = that.filesTable['current'] +1}

	   if (workingSet < 0 || workingSet > that.filesTable['levels']){
	   return false
	   }

	   var els = jQuery('tr.level'+workingSet,fTable);


	   if(els.length > 0){
	   els.toggle();
	   if(isMoreClick){ that.filesTable['current']++;}
	   else{ that.filesTable['current']--;}
	   }

	   that.showHideMore();


	   return false;
       });
       that.showHideMore();
     }
   }
   return true;
 }
 this.showHideMore = function(){
   if(!this.filesTable['lessButton']){ this.filesTable['lessButton'] = jQuery('a#moreboxLess')}
   if(!this.filesTable['moreButton']){ this.filesTable['moreButton'] = jQuery('a#moreboxMore')}
   if(!this.filesTable['perPageSpan']){ this.filesTable['perPageSpan'] = jQuery('span#moreboxPerpage')}

   if(this.filesTable['lessButton'].length > 0){
     if(this.filesTable['current'] <= 0){    	       
       this.filesTable['lessButton'].hide();
     }else{
       this.filesTable['lessButton'].show();
     }
   }

   if(this.filesTable['moreButton'].length > 0){
     if(this.filesTable['current'] >= this.filesTable['levels'] ){    	       
       this.filesTable['moreButton'].hide();
     }else{
       this.filesTable['moreButton'].show();
     }
   }    
   if(this.filesTable['perPageSpan'].length > 0){
     var lt = 10;
     if(this.filesTable['current'] > 0 ){lt = (this.filesTable['current']+1) * this.filesTable['perpage'];}
     if(lt > this.filesTable['total'] ){lt = this.filesTable['total'];}

     this.filesTable['perPageSpan'].html('Showing '+lt+' of '+this.filesTable['total']);
   }    
 }

 function pretty_filesize( bytes ){
   var s = ['bytes', 'KB', 'MB', 'GB', 'TB', 'PB'];
   var e = Math.floor(Math.log(bytes)/Math.log(1024));
   return (bytes/Math.pow(1024, Math.floor(e))).toFixed(2)+" "+s[e];

 }    
 this.renderFiles = function(d,type){
   var record = d;
   if(d.data){ record = [d.data];}

   var details = '';		
   for(i = 0; i<record.length; i++){
     var data = '';		
     data = record[i];


     var acc = data['acc'];			
     var downloadableFiles = ( data.files )? data.files : '';
     details += this.checkIfExists(downloadableFiles)? this.renderFileDownloadTable(downloadableFiles,acc,type) : "";					

   }

   return details;
 }

 this.renderSingleDownloadURL = function(id,type,dl){
   var html = '';    
   id = formatACC(id,type);


   if(dl && dl.length > 0){
     html = '<div id="ftpDownload" class="godown"><a href="#'+id+'_dlSection">Jump to downloads</a></div>';
   }else{    		   

     html = this.makeFTPDownloadURL(id,type,true);
   }

   return html;
 } 
 this.ftpLinkUrl = false;
 this.makeFTPDownloadURL = function(id,type,floatType){
   var html = '';
   id = formatACC(id,type);    		
   var folder = id;	
   var f = 'none';
   if (floatType){f = 'right';}
   this.ftpLinkUrl = this.ftp_url+id
     html = '<div id="ftpDownload" style="float:'+f+'"><a href="'+this.ftpLinkUrl+'" target="_new">FTP Directory</a></div>';

   return html;
 } 

 this.checkIfExists = function ( v ){
   if( v !== null && v !== undefined && v != '') { return true;}
   return false;
 }

 this.checkNumeric = function( value ){
   var anum=/(^\d+$)|(^\d+\.\d+$)/;
   if (anum.test(value)){ return true;}
   return false;
 }		

 var initialCap = function( str ) {
   return str = str.substr(0, 1).toUpperCase() + str.substr(1);	
 }

 this.contact_renderer = function( obj ){
   var html = "<table cellpadding='0' cellspacing='0' border='0' class='contactinfo'>";

   if (this.checkIfExists(obj.name)){ html += '<tr><td valign="top" id="specWidth"><b>Name:</b></td><td valign="top">'+obj.name+'</td></tr>';}
   if (this.checkIfExists(obj.org)){ html += '<tr><td valign="top" id="specWidth"><b>Organization:</b></td><td valign="top">'+obj.org+'</td></tr>';}
   if (this.checkIfExists(obj.email)){ html += '<tr><td valign="top" id="specWidth"><b>Email:</b></td><td valign="top">'+obj.email+'</td></tr>';}
   if (this.checkIfExists(obj.address)){ 
     html += '<tr><td valign="top" id="specWidth"><b>Address:</b></td><td valign="top">'+obj.address;
     if (this.checkIfExists(obj.city)){ html += '<br>'+obj.city;}
     if (this.checkIfExists(obj.state)){ html += ', '+obj.state;}
     if (this.checkIfExists(obj.zip)){ html += ' '+obj.zip;}

     html += '</td></tr>';
   }

   html += "</table>";
   return html;
 };


 this.characteristics_renderer = function ( obj ){
   var html = "";

   if(obj instanceof Object) {
     var html = "<table cellpadding='0' cellspacing='0' border='0'>";

     for (var i in obj){
       if(obj[i] && typeof(obj[i]) != 'function'){
	 if (this.checkIfExists(obj[i].tag) && this.checkIfExists(obj[i].value)){ 
	   var tag = initialCap(obj[i].tag.replace("_",' '));
	   tag = tag.replace("_", ' ');
	   html +='<tr><td valign="top" id="specWidth"><b>'+tag+':</b></td><td id="bottomAlign">'+obj[i].value+'</td></tr>';
	 }
       }
     }	
     html += "</table>";
   }			
   return html;	
 };

 this.search_type_renderer = function ( obj ){
   var html = "";

   if(obj instanceof Object) {
     var html = "<table cellpadding='0' cellspacing='0' border='0'>";
     html +='<tr><td valign="top" id="specWidth"><b>Search Engines:</b></td><td id="bottomAlign">';
     html += obj.join(', ');
     html += '</td></tr>';    			
     html += "</table>";
   }			
   return html;	
 };

 this.modifications_renderer = function ( obj ){
   var html = "";

   if(obj instanceof Object) {
     var html = "<table cellpadding='0' cellspacing='0' border='0'>";
     var uniModURL = 'http://www.unimod.org/modifications_view.php?editid1=';
     for (var i in obj){
       if(obj[i] && typeof(obj[i]) != 'function'){
	 if(typeof(obj[i]) == 'object'){
	   html +='<tr><td valign="top" id="specWidth"><b>'+initialCap(i.replace("_",' '))+':</b></td><td id="bottomAlign">';
	   var tAr = [];
	   for (j=0;j<obj[i].length;j++){
	     tAr.push(obj[i][j]);
	   }
	   html += tAr.join(', ');
	   html += '</td></tr>';
	 }
       }
     }
     html += "</table>";
   }
   return html;
 };



 this.filesWindow = '';

 handleFDButtonEvent = function(el,r){
   if(el){    	    
     var that = this;

     var divEl = Ext.get(el).dom.innerHTML;    	            

     if(!that.filesWindow){
       that.filesWindow = new Ext.Window({
applyTo:'dlWin',
layout:'fit',
width:500,
/*height:300,*/
autoHeight: true,
closeAction:'hide',
plain: true,

title: (r && r.data.acc)?"Supplementary files for "+r.data.acc: '',
html:divEl,

buttons: [{
text: 'Close',
handler: function(){
that.filesWindow.hide();
}
}]
});    	            
}else{    	      
  if(r && r.data.acc){
    that.filesWindow.setTitle("Supplementary files for "+r.data.acc);
  }
  that.filesWindow.center();
  that.filesWindow.body.update(divEl);
}
that.filesWindow.show();
}
}
this.highlightLink = function(g){
  var v =  g.getView();
  var that = this;

  g.getEl().on('click', function(e, t){
      var id = t.rel;
      if (id){ 

      var row = grid.getView().findRowIndex(t);
      if(row !== false){
      var record = grid.getStore().getAt(row);
      handleFDButtonEvent(t.rel,record);
      }else{
      handleFDButtonEvent(t.rel);
      }

      }                             
      }, g, {delegate: 'a.filesIcon', stopEvent: true});

  v.mainBody.on({
mouseover: function(e, t){
if(this.currentCell){
this.currentCell.removeClass('blockLink');
}
this.currentCell = Ext.get(t);
this.currentCell.addClass('blockLink');
},
mouseout: function(e, t){
if(this.currentCell){
this.currentCell.removeClass('blockLink');
}
delete this.currentCell;
},
delegate: v.cellSelector,
scope: v
});
}

this.files_renderer = function( value, metaData, record, rowIndex ){
  var id = Math.floor(Math.random()*11001);
  if(record.id){ id = record.id;}
  else if(record.data.acc){ id = record.data.acc;}
  else if(record.data.id){ id = record.data.id;}

  var html = '';

  var data = record.data.contributors;
  if(!data){ data = record.data.characteristics;}

  if(data){
    html = '<a rel="files_'+id+'" class="filesIcon"><img src="/portal/portal3rc.fcgi/1049549/img/29051" /></a>';
    html += '<div class="hidden" id="files_'+id+'"><div class="filesCont"><ul><li>'+data.join( "</li><li> " )+'</li></ul></div></div>'
  }

  return html;
}	

this.transitions_renderer = function (value,  metadata, record, rowIndex ) {
  var html = '<a href="GetSELTransitions?SEL_experiments='+record.data.SEL_experiment_id+'&action=QUERY">'+value+'</a>';
  return html;
}

this.px_renderer = function (value,  metadata, record, rowIndex ) {
  var html = '<a href="http://proteomecentral.proteomexchange.org/cgi/GetDataset?ID='+record.data.px_identifier+'">'+value+'</a>';
  return html;
}

this.experiment_title = function (value,  metadata, record, rowIndex ) {
  var html = '<a href="GetSELExperiments?SEL_experiment_id='+record.data.SEL_experiment_id+'">'+value+'</a>';
  return html;
}

this.date_renderer = function( value, metaData, record, rowIndex ){
  var html = value;

  if(typeof value == 'object'){
    var month_names = new Array ( );
    month_names[0] = '';
    month_names[month_names.length] = "January";
    month_names[month_names.length] = "February";
    month_names[month_names.length] = "March";
    month_names[month_names.length] = "April";
    month_names[month_names.length] = "May";
    month_names[month_names.length] = "June";
    month_names[month_names.length] = "July";
    month_names[month_names.length] = "August";
    month_names[month_names.length] = "September";
    month_names[month_names.length] = "October";
    month_names[month_names.length] = "November";
    month_names[month_names.length] = "December"

      html = month_names[value.month] + ' '+value.day +', '+value.year;			
  }		
  return html;
}
this.publication_render = function (value,  metadata, record, rowIndex, columnIndex, store) {
  //build the qtip:
  var html = value.author;
  var tip = value.cite;
  if( html ){
    //          metadata.attr = ' ext:qtip="' + tip + '"';
    html += ", " + tip;
  }
  return html;
};


this.msgNotAuth = function (id){
  var t = 'This accession';
  if(id){ t = 'Accession "'+id+'"';}
  var link = this.makeLink('contact/','',true);
}

this.errorMSG = function ( id , msg ){	
  if(!id){id ='err';}
  if(msg === undefined){msg ='No experiments found, or software or server error';}	 
  return "<div id='expandedContent'><div id='"+id+"'><p id='errorMSG'>"+msg+"</p></div></div>";		
}

this.print_array  = function ( arr ){
  var html = '';
  if (arr instanceof Array) {
    for (var key in arr) {	
      if(typeof arr[key] == 'function'){continue;}
      html += "<p>"+arr[key]+'</p>';		
    }
  }
  else if (arr instanceof Object) {
    html = print_r( arr, {} );
  }
  return html;	
}

this.print_r = function( array, skipped ) {
  var output = "", pad_char = " ", pad_val = 4; 	
  checkNumeric = this.checkNumeric;
  var formatArray = function (obj, cur_depth, pad_val, pad_char, skip) {

    if (cur_depth > 0) {
      cur_depth++;
    }

    /*var base_pad = repeat_char(pad_val*cur_depth, pad_char);
      var thick_pad = repeat_char(pad_val*(cur_depth+1), pad_char);*/
    var str = "";

    if (obj instanceof Array || obj instanceof Object) {
      for (var key in obj) {					
	if (obj[key] instanceof Array || obj[key] instanceof Object) {

	  if(key != 'std'){
	    var keyName = key;

	    if(!checkNumeric(key)){keyName = initialCap(key);}
	    keyName = keyName.replace(/\_/,' ');
	    //if(key == 'metadata'){
	    //	keyName = 'Meta data update';
	    //}
	    if (obj[key] instanceof Array ){
	      str += '<table cellspacing="0" cellpadding="0" border="0"><tr><td valign="top" id="specWidth"><b>'+keyName+':</b></td><td id="bottomAlign">';
	      for( var i in obj[key]){
		if(typeof obj[key][i] == 'function'){continue;}
		str += '<p>'+obj[key][i]+'</p>';	
	      }
	      str += '</td></tr></table>';
	    }else{
	      str += "<b>"+keyName+":</b> "+formatArray(obj[key], cur_depth+1, pad_val, pad_char, skip);
	    }

	  }else{
	    str += formatArray(obj[key], cur_depth+1, pad_val, pad_char, skip);
	  }
	} else {
	  if(obj[key]) {
	    var openTable ='<table cellspacing="0" cellpadding="0" border="0"><tr><td valign="top" id="specWidth"><b>';
	    var closeTable = '</td></tr></table>';
	    var inbetweenTD = '</b></td><td id="bottomAlign">';
	    if(key == 'year' || key =='month'){
	      if(key == 'year') {str += '<span>';}
	      str +=  obj[key] + "/";
	    }
	    else if(key == 'day' && !skip[key]){
	      str +=  obj[key] + "</span><br>";
	    }

	    else if(key == 'samples' && !skip[key] ){								
	      str += "<b>"+initialCap(key)+':</b>  <a class="clickable" id="viewSamplesTextLink">View samples ('+obj[key]+')</a> &nbsp;&nbsp;<br>';
	    }
	    else if(key == 'spectra' && !skip[key] ){								
	      str += "<b>"+initialCap(key)+':</b>  '+obj[key]+' &nbsp;&nbsp;';
	    }
	    else if(key == 'proteins' && !skip[key]){								
	      str += "<b>"+initialCap(key)+":</b>  <a class='clickable' id='switchpr'>" + obj[key] + "</a> &nbsp;&nbsp;";
	    }
	    else if(key == 'peptides' && !skip[key]){							 
	      str += "<b>"+initialCap(key)+":</b>  <a class='clickable' id='switchpe'>" + obj[key] + "</a> &nbsp;&nbsp;";
	    }
	    else if(key == 'org' && !skip[key]){								
	      str += "<p><b>Organization:</b> " + obj[key] + "</p>";
	    }	
	    else if(key == 'spectra' || key == 'samples' || key == 'proteins'  || key == 'peptides' ){								
	      str += "<b>"+initialCap(key)+':</b>  '+obj[key]+' &nbsp;&nbsp;';
	    }
	    else{
	      str += openTable+"<p><b>"+initialCap(key)+":</b>  "+inbetweenTD + obj[key] + "</p>"+closeTable;
	    }
	  }
	}
      }
    } else if(obj == null || obj == undefined) {
      str = '';
    } else {
      str = "<p>"+obj.toString()+"</p>";
    }

    return str;
  };

  var repeat_char = function (len, pad_char) {
    var str = "";
    for(var i=0; i < len; i++) { 
      str += pad_char; 
    }
    return str;
  };
  output = formatArray(array, 0, pad_val, pad_char, skipped);

  return output;    	
}	

this.dateHTMLRenderer = function ( rD,dD,daD ){
  var html = '';
  var openTable ='<table cellspacing="0" cellpadding="0" border="0"><tr><td valign="top" id="specWidth"><p><b>';
  var openTable2 ='<table cellspacing="0" cellpadding="0" border="0"><tr><td valign="top" width="70"><p><b>';
  var closeTable = '</p></td></tr></table>';
  var inbetweenTD = '</p></b></td><td id="bottomAlign"><p>';

  var top = "<h3>Dates</h3><div id='box' style='width:500px;'><table class='datatable' width='auto' border='0'><tr>";
  var details = '';

  var c = 0;								
  var classStr = openTable;
  if(this.checkIfExists(rD)){ c++;}
  //details += this.checkIfExists(rD)? "<td>"+classStr+"<b>Release:</b> "+inbetweenTD +rD+ ""+closeTable+"</td>":'';
  if(this.checkIfExists(dD)){  c++; if (c >1){ classStr = openTable2;}else{classStr = openTable;}}
  details += this.checkIfExists(dD)? "<td>"+classStr+"<b>Deposit:</b> "+inbetweenTD +dD+ ""+closeTable+"</td>":'';
  //if(this.checkIfExists(mUD)){ c++; if(c > 2){c = 1; details += '</tr><tr>';}if (c >1){ classStr = openTable2;}else{classStr = openTable;}}
  //details += this.checkIfExists(mUD)? "<td>"+classStr+"<b>Metadata update:</b> "+inbetweenTD +mUD+ ""+closeTable+"</td>":'';

  if(this.checkIfExists(daD)){ c++; if(c > 2){c = 1; details += '</tr><tr>';}if (c >1){ classStr = openTable2;}else{classStr = openTable;}} 
  details += this.checkIfExists(daD)? "<td>"+classStr+"<b>Data update:</b> "+inbetweenTD +daD+ ""+closeTable+"</td>":'';

  var end = "</tr></table></div>";
  if(details){html = top+''+details+''+end;}

  return html;
}

var addNode = function ( hash, key, cnts, val ) {
  if ( this.usearray == true ) {              // into array
    if ( cnts == 1 ) hash[key] = [];
    hash[key][hash[key].length] = val;      // push
  } else if ( this.usearray == false ) {      // into scalar
    if ( cnts == 1 ) hash[key] = val;       // only 1st sibling
  } else if ( this.usearray == null ) {
    if ( cnts == 1 ) {                      // 1st sibling
      hash[key] = val;
    } else if ( cnts == 2 ) {               // 2nd sibling
      hash[key] = [ hash[key], val ];
    } else {                                // 3rd sibling and more
      hash[key][hash[key].length] = val;
    }
  } else if ( this.usearray[key] ) {
    if ( cnts == 1 ) hash[key] = [];
    hash[key][hash[key].length] = val;      // push
  } else {
    if ( cnts == 1 ) hash[key] = val;       // only 1st sibling
  }
};

this.xml2Json = function ( elem ) {
  //  COMMENT_NODE
  if ( elem.nodeType == 7 ) {
    return;
  }

  //  TEXT_NODE CDATA_SECTION_NODE
  if ( elem.nodeType == 3 || elem.nodeType == 4 ) {
    var bool = elem.nodeValue.match( /[^\x00-\x20]/ ); // for Safari
    if ( bool == null ) return;     // ignore white spaces
    return elem.nodeValue;
  }

  var retval;
  var cnt = {};

  //  parse attributes
  if ( elem.attributes && elem.attributes.length ) {
    retval = {};
    for ( var i=0; i<elem.attributes.length; i++ ) {
      var key = elem.attributes[i].nodeName;
      if ( typeof(key) != "string" ) continue;
      var val = elem.attributes[i].nodeValue;
      if ( ! val ) continue;
      if ( typeof(cnt[key]) == "undefined" ) cnt[key] = 0;
      cnt[key] ++;
      addNode( retval, key, cnt[key], val );
    }
  }

  //  parse child nodes (recursive)
  if ( elem.childNodes && elem.childNodes.length ) {
    var textonly = true;
    if ( retval ) textonly = false;        // some attributes exists
    for ( var i=0; i<elem.childNodes.length && textonly; i++ ) {
      var ntype = elem.childNodes[i].nodeType;
      if ( ntype == 3 || ntype == 4 ) continue;
      textonly = false;
    }
    if ( textonly ) {
      if ( ! retval ) retval = "";
      for ( var i=0; i<elem.childNodes.length; i++ ) {
	retval += elem.childNodes[i].nodeValue;
      }
    } else {
      if ( ! retval ) retval = {};
      for ( var i=0; i<elem.childNodes.length; i++ ) {
	var key = elem.childNodes[i].nodeName;
	if ( typeof(key) != "string" ) continue;
	var val = xml2Json( elem.childNodes[i] );
	if ( ! val ) continue;
	if ( typeof(cnt[key]) == "undefined" ) cnt[key] = 0;
	cnt[key] ++;
	addNode( retval, key, cnt[key], val );
      }
    }
  }
  return retval;
};

this.isAnonymous = function ( role ){if (role == 'anonymous'){return true;}else{ return false;}}

this.getFtpInfo = function(){
  var common = this;
  jQuery.ajax ({
type: 'POST',
url: this.queryms_url,			
data: { cmd: "ftpinfo" },	
dataType: "json",
success: function ( result, request ) 
{
var obj = result;//Ext.decode( result.responseText );

var rObj = obj;
if(obj.MS_QueryResponse.ftpinfo){
rObj = obj.MS_QueryResponse.ftpinfo;
}

}
});
};

function readCookie( name ) 
{
  var nameEQ = name + "=";
  var ca = document.cookie.split(';');

  for( var i = 0; i < ca.length; i++ ) 
  {
    var c = ca[ i ];

    while ( c.charAt( 0 ) == ' ' ) c = c.substring( 1, c.length );
    if ( c.indexOf( nameEQ ) == 0 ) return c.substring( nameEQ.length, c.length );
  }
  return null;
}

var get_userid_from_cookie = function ()    // Read cookie that NCBI PDA login sets
{
  return readCookie( "NcbiLsSessionPDA" );
};

this.constructTabPanel = function(opts){


  var t = new Ext.TabPanel({
renderTo: 	(opts && opts.renderTo)?opts.renderTo:'toolbar',
activeTab: 	(opts && opts.activeTab)?opts.activeTab:0,
//resizeTabs:	(opts && opts.resizeTabs)?opts.resizeTabs:false,
id:	(opts && opts.id)?opts.id:'gridTabs',

enableTabScroll:(opts && opts.enableTabScroll)?true:false,	

border: false,
layoutOnTabChange: true,
forceFit: true,
autoWidth: true,
defaults:{autoHeight: true}

});
return t;
}
this.RemoveDuplicates = function(a){
  var r = new Array();
o:for(var i = 0, n = a.length; i < n; i++)
  {
    for(var x = 0, y = r.length; x < y; x++)
    {
      if(r[x]==a[i]) continue o;
    }
    r[r.length] = a[i];
  }
  return r;
}

this.constructTabPanelComponent = function(opts){
  var t = '';

  t = new Ext.BoxComponent({
title: (opts && opts.title)?opts.title:'Component',
autoEl: {},
id: (opts && opts.id)?opts.id:'unknownID',
listeners: (opts && opts.listeners)? opts.listeners : null,
ifEmpty: (opts && opts.ifEmpty)? opts.ifEmpty : null
});
return t;
}

this.public_private_renderer = function( value, metaData, record, rowIndex ) {			 
  //var checkedImg = '/core/extjs/ext-2.1/resources/images/default/menu/checked.gif';
  var checkedImg = '../images/default/menu/checked.gif';
  var uncheckedImg = '../images/default/menu/unchecked.gif';
  var cb = ''
    + '<div style="text-align:center;height:16px;overflow:visible">'
    + '<img style="vertical-align:-3px" src="'
    + checkedImg
    //+ (value ? checkedImg : uncheckedImg)
    + '"'
    + ' />'
    + '</div>'
    ;

  var html = (value) ? '' : cb;
  return html;
}


this.gridViewOpts = {
  'publicSamples': {scope: 'public', type : 'samples', cmd: 'entries',gridID: 'samples_grid'}
};
this.capWords = function(str){ 
  var words = str.split(" "); 
  for (var i=0 ; i < words.length ; i++){ 
    var testwd = words[i]; 
    var firLet = testwd.substr(0,1); 
    var rest = testwd.substr(1, testwd.length -1) ;
    words[i] = firLet.toUpperCase() + rest 
  } 
  return words.join(" "); 
}	 


this.xrefs_renderer = function( v, rec ){ 
  var html_str = []; 
  if(v){			
    for( key in v )
    {				
      if( key == 'remove' ){ continue; }
      var t = '';
      html_str[ key ] = "<table cellpadding='0' cellspacing='0' border='0'><tr>";
      if( typeof v[ key ].type !== undefined ){ t += '<b>'+v[ key ].type+'</b>';} 
      if( v[ key ].subtype && v[ key ].subtype != 'not defined' ){ t += ' ('+v[ key ].subtype+')';} 

	  if( t ){ html_str[ key ] += "<td valign='top' id='specWidth'>" + t +': </td><td id="bottomAlign">';}
	  else{  html_str[ key ] += "<td valign='top'>" ;}

	  if( typeof v[ key ].target !== undefined){
	  if( typeof v[ key ].url !== undefined){ 
	  html_str[ key ] += ' <a title="' + v[ key ].target + '"></a><a href="' + v[ key ].url + '" target="_blank">' + v[ key ].target + '</a> ';
	  } 
	  else{ 
	  html_str[key] += ' ' + v[ key ].target + '';
	  } 
	  }	

	  html_str[key] += '</td></tr></table>';
	  }
	  }
	  return html_str.join('<br>');
	  };
	  this.clearGrids = function (type,currentGridInView/*,id*/){

	    var grids = [
	      'tab_my_samples_public_grid',
	      ];
	    //if(id){grids.push('tab_'+id+'_grid');}
	    for(i in grids){
	      var gridAddr = grids[i];

	      if(gridAddr && typeof(gridAddr) == 'function'){ continue;}	
	      if(type && !gridAddr.match(type) ){continue;}

	      if(currentGridInView && currentGridInView != gridAddr){					
		var grid = Ext.getCmp(gridAddr);
		if(grid){
		  grid.destroy();
		  this.refreshList[gridAddr] = 'a';
		}
	      }
	    }
	  }	 
}; // end PAcommon

jQuery.ui.PAcommon.version = "1.0";

})(jQuery);


jQuery(document).ready( function() {

    var c = new jQuery.ui.PAcommon;
    });


Portal.Portlet.Pepdome_browse = Portal.Portlet.extend ({
init: function (path, name, notifier){
console.info ("Created Pepdome_browse");
this.base (path, name, notifier);

this.sample   = this.getMyAttr("AccParam");
this.study    = this.getMyAttr("AccParam");
this.acc      = this.getMyAttr("AccParam");
this.view     = this.getMyAttr("DefaultViewParam");
this.pro_id   = this.getMyAttr("ProIdParam");
this.pro_acc  = this.getMyAttr("ProAccParam");
this.pep_id   = this.getMyAttr("PepIdParam");
this.pep_seq  = this.getMyAttr("PepSeqParam");
},
getP: function (v) { if(this[v]){return this[v];} return null;},
getMyAttr: function(term) {
if (this.has(term)){ 
return this.getValue(term);
}
return null;
}, 

setMyAttr: function(term,value) {
	     if (this.has(term)){ 
	       this.setValue(term, value);
	     }
	   }, 

clearMyAttr: function(term) {
	       if (this.has(term)){ 
		 this.setValue(term, "");
	       }
	     }
});	


var sampleClass = function(settings){

  var options = {
view: 'multi', //  multi = grid type. single = single data view (meta data)	
      renderTo: 'center',
      initialDisplay: 'sample',
      centerPanel: ''
  };

  var opts = extend(options,settings);	 

  /* Rendering properties */
  this.tabs = [];

  Ext.QuickTips.init(); 
  var xg = Ext.grid; 

  var mask = "";

  var dataFormat = 'json'; // json or xml
  var downloadLinkParams = '';

  var common = new jQuery.ui.PAcommon;

  var gridID = '';
  var inMetaView = false;

  var sampleParams = {};
  var sampleIsPublic = true;

  var tabPanel = '';

  /* User variables */
  var reviewerToken = '';

  var sample = "";
  var sample_from_param = common.get_url_parameter( 'sample' );
  if(!sample_from_param){sample_from_param = common.get_url_parameter( 'acc' )}

  sample = sample ? sample : sample_from_param;	
  sample = sampleName();

  /**********************************************************/
  /*                     PUBLIC FUNCTIONS                   */
  /**********************************************************/
  var init = function(){}	
  init();

  this.metaDataView = function(tabObj){
    inMetaView = true;		 
    gridID = 'sampleMetaData';
    var p = { cmd: "sample", acc: sample };
    if (tabObj){tabPanel = tabObj;}
    get_data( p, 'meta' );		 
  }
  this.gridView = function(o){
    inMetaView = false;
    var scope = 'public';
    var type  = 'samples';
    var cmd   = 'entries';
    gridID    = 'samples_grid';
    var acc = '';

    if(o instanceof Object){
      if(o.gridID){gridID  = o.gridID;}
      if(o.cmd){cmd  = o.cmd;}
      if(o.scope){scope  = o.scope;}
      if(o.type){type  = o.type;}
      if(o.acc){acc  = o.acc; scope = 'all';}
      if (o.tabObj){tabPanel = o.tabObj;}
    }

    var p = { cmd: cmd, scope: scope, type: type };
    if(acc){p.study = acc;}
    get_data( p, 'grid' );		 
  }

  /**********************************************************/
  /*                  END PUBLIC FUNCTIONS                  */
  /**********************************************************/

  function show_wait_msg( row_id )
  {
    mask = new Ext.LoadMask( Ext.get( row_id ) );
    mask.show();
  }		

  /* Utilities */
  function extend(target, obj){
    if(obj instanceof Object){					
      for (k in obj){
	target[k] = obj[k];	
      }
    }
    return target;
  }

  function sampleName(name,type){
    if(!name){name = sample;}
    if(common.checkNumeric(name)){ name = 'PSM'+name;if(type && type =='study'){name = 'PSE'+name;}}			
    return name;
  }

  function calcGridHeight(){	
    var p = Ext.getCmp('center-panel');
    if(p){
      return p.getSize().height - 0;
    }else{
      return common.layout_height - 25;
    }
  }

  function no_data_msg( id, message )
  {
    var msg_loc = Ext.get( id );

    if( msg_loc )
    {
      Ext.DomHelper.insertFirst( msg_loc, message );
    }
  }

  function get_data( paramsObj,view ){
    //var paramsObj = sampleParams;
    var errorContainer =  gridID+'_err';

    if(!view){ view = 'meta';}
    /*		
		if(opts.initialDisplay == 'sample'){
		paramsObj = { cmd: "sample", acc: sample };		
		}*/

    if(common.token){ paramsObj.token = common.token;}

    show_wait_msg( (opts.centerPanel)?opts.centerPanel:opts.renderTo );

    paramsObj.pgsize = common.numberPerPage ;
    paramsObj.filterstr =  jQuery('input#searchq').val();
    paramsObj.filtercol = jQuery('select#selectedTitle').val();

    paramsObj = common.setParamsObj( paramsObj );

    Ext.Ajax.request(
	{
url: common.pathname + 'cgi/passel/query_repository.cgi',
params: paramsObj,
success: function ( result, request ) 
{
var obj = '';

obj = Ext.decode( result.responseText );
var errrrr = Ext.get('sampleMetaData_grid_err');
if(errrrr){Ext.get('expandedContent').remove();}

if(obj instanceof Object && obj.MS_QueryResponse){
if ( obj.MS_QueryResponse.userinfo ) {
//userRole = obj.MS_QueryResponse.userinfo.role;	
user = obj.MS_QueryResponse.userinfo;
}

if ( view == "meta" && obj.MS_QueryResponse.samples ) 
{
//xg.pdata = obj.MS_QueryResponse.samples;						 
  make_meta_data( obj.MS_QueryResponse.samples, sample );
}	
else if ( view == "grid" && obj.MS_QueryResponse.samples ) 
{
  obj.params = paramsObj;
  make_grid(obj/*.MS_QueryResponse.samples*/);					 						 
}						 
else if(obj.error){
  mask.hide();							
  no_data_msg( opts.renderTo ,common.errorMSG(errorContainer)  );
}
else
{
  mask.hide();
  no_data_msg( opts.renderTo ,common.errorMSG(errorContainer)  );
}											
}
else{
  mask.hide();
  no_data_msg( opts.renderTo , common.errorMSG(errorContainer) );
}	
mask.hide();
},
failure: function () 
{ 
  mask.hide();				 
  no_data_msg( opts.renderTo ,common.errorMSG(errorContainer));
}
});

}

/* Rendering Functions */
function make_meta_data (data, sampleid){



  var tabTitle = sampleName();
  var title = "Sample "+tabTitle;

  common.changeWindowTitle(title);		 

  var container = Ext.get(opts.renderTo);
  if (container){ 

    var details = style_metaData(data,'sample');

    container.insertHtml('afterBegin','<div id="sampleMetaData"><div id="samplesContent">'+details+'</div></div>');
    var files_container = Ext.get('files_container');

    if (files_container){
      files_container.insertHtml('afterBegin',common.renderFiles(data,'sample'));
      common.addViewMore();
    }
    common.checkHashLink();

    var aa = Ext.get('approveSample_'+data[0].acc);
    if(aa){
      aa.on('click',function(){
	  processApproveDisapprove(this,'sample',data[0].acc);		
	  });									
    }

    var a = ['switchpr','switchpe'];
    for(i in a){
      if(typeof(a[i]) == 'function'){continue;}
      var t = Ext.get(a[i]);
      if(t){
	if(a[i] == 	'switchpr'){
	  t.addListener('click',function(){												   									
	      tabPanel.setActiveTab('proteins');
	      });
	}
	else if(a[i] == 'switchpe'){					
	  t.addListener('click',function(){												   									
	      tabPanel.setActiveTab('peptides');
	      });
	}
      }
    }
  }		
}	

function style_metaData(d,userT){
  var details = '<div id="subMeta"><div id="metadata">';
  var record = d;
  if(d.data){ record = [d.data];}


  for(i = 0; i<record.length; i++){
    var data = '';		
    data = record[i];

    var acc = data['acc'];
    if(!acc) {acc = data['acc']};
    var title = data[ "title" ];
    var public = data[ "public" ];
    var platforms = data[ "platforms" ];	

    var downloadableFiles = ( data.files )? data.files : '';

    if(inMetaView){sampleIsPublic = public;}

    //			var depositDate = (data.dates.deposit)? common.date_renderer(data.dates.deposit.std): undefined;
    //			var releaseDate; // = (data.dates.release)?common.date_renderer(data.dates.release.std): undefined;
    //			var metadataUpdateDate; // = (data.dates.metadata)?common.date_renderer(data.dates.metadata.std): undefined;
    //			var dataDate = (data.dates.data)?common.date_renderer(data.dates.data.std): undefined;

    var openTable ='<table cellspacing="0" cellpadding="0" border="0"><tr><td valign="top" id="specWidth"><p><b>';
    var openTable2 ='<table cellspacing="0" cellpadding="0" border="0"><tr><td valign="top"><p><b>';
    var closeTable = '</p></td></tr></table>';
    var inbetweenTD = '</p></b></td><td id="bottomAlign"><p>';

    var title = data[ "title" ];

    common.approvedState[acc] =  data.approved;
    // javascript complains that isAdmin is undefined.
    //			details += (public)?'': (user && common.isAdmin(user.role) && inMetaView)? (!common.approvedState[acc])?'<div id="approveHolder"><a id="approveSample_'+acc+'" class="clickable approve '+acc+'">Approve</a></div>': '<div id="approveHolder"><a id="approveSample" class="clickable disapprove '+acc+'">Disapprove</a></div>': '';

    /*
     * We don't need to display sample_tag and organism; they're already in the
     * unexpanded view

     details += (public)?common.renderSingleDownloadURL(acc,'sample',downloadableFiles):'';
     var privateTag = (public) ?'': '<span>(<span id="privateTag">private</span>)</span>';
    //			details += '<h3 style="border:none;">'+ acc+ ': ' + title + ' '+ privateTag + '</h3>';
    details += '<h3 style="border:none;">'+  title + ' '+ privateTag + '</h3>';

    var org = data.taxonomy;
    if(data.taxonomy && typeof data.taxonomy[0] == 'object'){
    org = render_organism(data.taxonomy);
    }

    var studyFieldTitle = 'Parent Study';

    //      details += common.checkIfExists(data.SEL_experiment_id)?'<h3><b><a href="'+common.pathname+'cgi/PeptideAtlas/GetSELTransitions?SEL_experiments='+data.SEL_experiment_id+'&action=QUERY">Transitions</a></b></h3>' : '';

    details += common.checkIfExists(data.taxonomy)? "<h3>Organism</h3><div id='box'>"+org+"</div>" : '';	

     */
    details += common.checkIfExists(data.datasetIdentifier)? '<h3><a href="http://www.peptideatlas.org/PASS/'+data.datasetIdentifier+'">Download raw data and supporting files</a></h3>' : '';				
    details += common.checkIfExists(data.comment)? "<h3>Experiment Description</h3><div id='box'>"+data.comment+"</div>" : '';
    details += common.checkIfExists(data.description)? "<h3>Sample Description</h3><div id='box'>"+data.description+"</div>" : '';	

    details += common.checkIfExists(data.counts)? "<h3>Statistics</h3><div id='box'><p>"+common.print_r(data.counts,{})+"</div>" : '';									 
    //			details += common.checkIfExists(data.cite)? "<h3>Publication</h3><div id='box'><p>"+common.print_r(data.cite,{})+"</div>" : '';									 
    if( common.checkIfExists(data.publication) ) {
      if (common.checkIfExists(data.pubmed_ids)) {
	var pubmed_url = "http://www.ncbi.nlm.nih.gov/pubmed/" + data.pubmed_ids.join(',');
	details += "<h3>Publication</h3><div id='box'><p>"+'<a href="'+ pubmed_url +'">'+common.publication_render(data.publication)+'</a></div>';
      } else {
	details += "<h3>Publication</h3><div id='box'><p>"+common.publication_render(data.publication)+"</div>";
      } 
    }

    details += common.checkIfExists(data.abstract)?  "<h3>Abstract</h3><div id='box'><p>"+common.print_r(data.abstract,{})+"</div>" : '';									 
    //details += common.dateHTMLRenderer(releaseDate,depositDate,metadataUpdateDate,dataDate);		
    //			details += common.dateHTMLRenderer(releaseDate,depositDate,dataDate);
    //details += common.checkIfExists(data.contact)? "<h3>Contact</h3><div id='box'>"+common.contact_renderer(data.contact)+"</div>" : '';
    // if( common.checkIfExists(data.pubmed_ids) ) {
      // details += '<div id="citations_'+acc+'"></div>'+getPubmedCitation(data.pubmed_ids,acc);
    // }else if( common.checkIfExists(data.link) ){
      // details += '<h3><b>Publications</h3><div id="box"><a href="'+data.link+'">'+data.author+'</a></div>';
    // }
    details += common.checkIfExists(data.summary)? "<h3>Summary</h3><div id='box'>"+data.summary+"</div>" : '';

    details += common.checkIfExists(data.preparation)? "<h3>Preparation</h3><div id='box'>"+common.print_r(data.preparation,{})+"</div>" : '';				
    details += common.checkIfExists(data.sample_tag)? "<h3>Sample Tag</h3><div id='box'>"+common.print_r(data.sampletag,{})+"</div>" : '';				

    details += common.checkIfExists(data.characteristics)? "<h3>Characteristics</h3><div id='box'>"+common.characteristics_renderer(data.characteristics,{})+"</div>" : '';	
    details += common.checkIfExists(data.sample_date)? "<h3>Sample Date</h3><div id='box'>"+common.print_r(data.sample_date,{})+"</div>" : '';				

    details += common.checkIfExists(data.characteristics)? "<h3>Characteristics</h3><div id='box'>"+common.characteristics_renderer(data.characteristics,{})+"</div>" : '';	

    if (common.checkIfExists(data.data_processing)){
      details += "<h3>Processing Methods</h3><div id='box'>"+common.print_r(data.data_processing,{}) ;
      if (common.checkIfExists(data.search_type)){
	details += common.search_type_renderer(data.search_type,{});				
      }
      /*if (common.checkIfExists(data.modifications)){
	details += common.modifications_renderer(data.modifications,{});				
	}*/

      details += "</div>";
    }
    details += common.checkIfExists(data.modifications)? "<h3>Modifications</h3><div id='box'>"+common.modifications_renderer(data.modifications)+"</div>" : '';

    details += common.checkIfExists(data.xrefs)? "<h3>Cross References</h3><div id='box'>"+common.xrefs_renderer(data.xrefs)+"</div>" : '';
    details += common.checkIfExists(data.other_parameters)? "<h3>Other parameters</h3><div id='box'>"+common.characteristics_renderer(data.other_parameters,{})+"</div>" : '';

    details += common.checkIfExists(data.contributors)? "<h3>Contributors</h3><div id='box'>"+data.contributors+"</div>" : '';	
    details += common.checkIfExists(data.contact)? "<h3>Contact</h3><div id='box'>"+data.contact+"</div>" : '';
    details += common.checkIfExists(downloadableFiles)? "<h3>Download Files</h3><div id='box'><div id='files_container'></div></div>" : "";
    //--------------------------------------------------
    // details += common.checkIfExists(downloadableFiles)? "<h3>Download Files</h3><div id='box'>"+common.renderFileDownloadTable(downloadableFiles,acc,'sample')+"</div>" : "";
    //-------------------------------------------------- 
  }

  details += '</div></div>';		
  return details;				
}


/**************************************************************/
/* 						RENDERERS 	  						  */
/**************************************************************/

var pubMedCitations = {};
var getPubmedCitation = function (arr,id){
  if(pubMedCitations[id]){ return pubMedCitations[id];}

  if(typeof arr == 'object'){
    var ids = arr.join(',');

    Ext.Ajax.request({
      url: common.pathname + 'cgi/passel/pmqproxy.cgi',
      params: {ids: ids},
      success: function ( result, request ){
	var obj = result.responseText;
	var t = Ext.get('citations_'+id);
	if(t && typeof obj != 'undefined'){
	  var text = '<h3><b>Publications</h3><div id="box">'+obj+'</div>';
	  pubMedCitations[id] = text;
	  t.update(text);
	}
      },
      failure: function (){
	var t = Ext.get('citations');
	if(t){
	  var text = pubmed_renderer(arr);
	  pubMedCitations[id] = text;
	  t.update(text);
	}
      }
    });
  }
  return '';
}

var organism_column_renderer = function( value, metaData, record, rowIndex ){
  if(value[0]){return value[0];}
  return value;
};
var render_organism = function( v, rec )
{ 
  var html_str = [];
  if(v){

    for( key in v )
    {				
      if( /*checkNumeric(key) ||*/ key == 'remove' ){ continue; }
      html_str[key] = ' <a title="' + v[ key ].name + '"></a><a href="http://www.ncbi.nlm.nih.gov/Taxonomy/Browser/wwwtax.cgi?id=' + 
	v[ key ].id + '" target="_blank">' + v[ key ].name + '</a> ';				
    }
  }
  return html_str;
};		

var null_renderer = function( value )
{
  return value ? value : "-";
};

/**************************************************************/
/* 						END RENDERERS 	  					  */
/**************************************************************/

/**************************************************************/
/* 				  Data Store and Column Models 				  */
/* defines  variables and maps to fields in .json file */
/**************************************************************/
var SampleRecord = Ext.data.Record.create([
    { name: 'acc'},
    { name: 'peptides', mapping: 'counts.peps'},
    { name: 'ions', mapping: 'counts.ions'},
    { name: 'proteins', mapping: 'counts.prots' },
    { name: 'runs', mapping: 'counts.runs'},
    { name: 'transition_groups', mapping: 'counts.transition_groups'},
    { name: 'transitions', mapping: 'counts.transitions'},
    { name: 'spikein' },
    { name: 'mprophet' },
    { name: 'summary' },
    { name: 'contributors'},
    { name: 'sample_date' },
    { name: 'SEL_experiment_id' },
    { name: 'public' },
    { name: 'sampletag' },
    { name: 'experiment_title'},
    { name: 'datasetIdentifier'},
    { name: 'taxonomy' },
    { name: 'description' },
    { name: 'comment' },
    { name: 'publication_name' },
    { name: 'instrumentation' },
{ name: 'abstract' },
{ name: 'publication' },
{ name: 'link',  mapping: 'publication.link' },
{ name: 'pubmed_ids',  mapping: 'publication.ids' },
{ name: 'author',  mapping: 'publication.author' },
{ name: 'cite',  mapping: 'publication.cite' },
{ name: 'title' },
{ name: 'px_identifier'},
  ]);
var sample_reader = new Ext.data.JsonReader({	
id: "acc",
root: 'MS_QueryResponse.samples',		
totalProperty: 'MS_QueryResponse.counts.samples'              
}, SampleRecord );

function make_grid( details ){
  var border = Ext.getCmp( 'layout' );
  var sample_expander = new xg.RowExpander({		
beforeExpand: function( record, body, rowIndex ){			 			 
body.innerHTML ="<div style='padding:7px'>"+ style_metaData( record, rowIndex) +"</div>";
return true;
}
});
var checkBoxSelectedItems = {};

Ext.grid.CheckColumn = function(config){
  Ext.apply(this, config);
  if(!this.id){
    this.id = Ext.id();
  }
  this.renderer = this.renderer.createDelegate(this);
};

Ext.grid.CheckColumn.prototype ={
init : function(grid){
	 this.grid = grid;

	 this.selected = {}; // hash mapping record id to selected state



	 this.grid.on('render', function(){
	     var view = this.grid.getView();
	     view.mainBody.on('mousedown', this.onMouseDown, this);

	     }, this);
       },			
onMouseDown : function(e, t){
		if(t.className && t.className.indexOf('x-grid3-cc-'+this.id) != -1){
		  e.stopEvent();

		  var index = this.grid.getView().findRowIndex(t);
		  var record = this.grid.store.getAt(index);

		  submitApprovals(record,this.dataIndex);
		}				
	      },

renderer : function(v, p, record,t){
	     p.css += ' x-grid3-check-col-td'; 				 

	     if(record.get('acc') in checkBoxSelectedItems){ v = checkBoxSelectedItems[record.get('acc')]; record.data[this.dataIndex] = v; }
	     else{ checkBoxSelectedItems[record.get('acc')] = record.data[this.dataIndex]; }				 

	     return '<div class="x-grid3-check-col'+(v?'-on':'')+' x-grid3-cc-'+this.id+'">&#160;</div>';
	   }
};

//var checkboxmodel = new xg.CheckboxSelectionModel({
var checkboxmodel = new Ext.grid.CheckColumn({
width : 37,
dataIndex: 'approved',
header: "Approved?",
id: gridID+'_checkboxs'
});

var submitApprovals = function(record,dataIndex){
  var ids = [];
  var approveAllSub = false;
  var disapproveAllSub = false;

  var grid = '';//grid;

  if(gridID){
    grid = Ext.getCmp(gridID);					
  }

  var acc = record.get('acc');
  if(!acc && record.json){ acc = record.json.acc }
  if(!acc){ acc = record.get('acc'); }

  var actionType = 'approve';
  if(record.get('approved')){actionType = 'disapprove';}

  var selections = '';//grid.getSelections();
  if(acc){selections = [acc];}


  var addSelectionToList = function(id,s){
    if(id){ ids.push({acc:id,approveAll:s});}	
  }

  var submitSelections = function() {				 

    if(ids[0]){

      var params = {cmd: 'togglehold',acc:ids[0].acc};
      if(ids[0].approveAll){
	params.allSamples = '';
      }
      mask.show();					
      params = common.setParamsObj( params );
      //----------------------------------------------
      // Approve/disapprove a Study/sample
      //----------------------------------------------
      Ext.Ajax.request(
	  {
url: common.query_url,
params: params,

success: function ( result, options ) 
{
var obj = Ext.decode( result.responseText );
mask.hide();							

if ( obj.MS_QueryResponse /*&& obj.MS_QueryResponse.length > 0*/ ) 
{					
checkBoxSelectedItems[record.get('acc')] = !record.data[dataIndex];

record.set(dataIndex,  !record.data[dataIndex]);
record.commit(); 
common.clearGrids(null,gridID/*'',record.get('acc')*/);
}							
},
failure: function () 
{ 
  mask.hide();							
}
});
}
}


if(selections[0]){
  var type = 'sample';
  processSelection(selections,false);
}						
}		

//--------------------------------------------
// ColumnModel for Studies
//--------------------------------------------
var sample_cm = new xg.ColumnModel(
    [
    sample_expander,
    {
header: "Experiment Title", dataIndex: 'experiment_title', width: 190,
tooltip: 'Experiment Title',
renderer: common.experiment_title,
sortable: true
}, 
{ 
header: "TxGrps", width: 25, fixed: false, dataIndex: 'transition_groups',  
sortable: false,
tooltip: 'Transition groups measured; click for details and chromatograms' ,
renderer: common.transitions_renderer
},
{
header: "Organism",
width: 50,
dataIndex: 'taxonomy',
sortable: true,
tooltip: 'Study Organism'
},
{ 
header: "Instrument", width: 60, fixed: false, dataIndex: 'instrumentation',  
	sortable: true,
	tooltip: 'Platform Title' 
},
{ 
header: "Runs", width: 25, fixed: false, dataIndex: 'runs',  
	sortable: false,
	tooltip: 'Number of MS runs in experiment' 
},
{ 
header: "Prots", width: 25, fixed: false, dataIndex: 'proteins',  
	sortable: false,
	tooltip: 'Number of proteins measured' 
},
{ 
header: "Peps", width: 25, fixed: false, dataIndex: 'peptides',  
	sortable: false,
	tooltip: 'Distinct peptide sequences measured' 
},
{ 
header: "spike?", width: 25, fixed: false, dataIndex: 'spikein',  
	sortable: true,
	tooltip: 'Spike-in experiment?' 
},
{ 
header: "mPro", width: 25, fixed: false, dataIndex: 'mprophet',  
	sortable: true,
	tooltip: 'mProphet analysis run?' 
},
{
header: "Publication", dataIndex: 'publication_name', width: 100,
	tooltip: 'Publication'
},
{ 
header: "PXD Identifier", width: 50, dataIndex: 'px_identifier',
renderer: common.px_renderer,
}
]);

sample_cm.defaultSortable = true;

var title = "Sample";	

var sampleProxy = new Ext.data.HttpProxy({
    //url:common.query_url,
url: common.pathname + 'cgi/passel/query_repository.cgi',
//success: function(e,r){if(mask){mask.hide();}}
success: function ( result, request )
{
var obj = '';

obj = Ext.decode( result.responseText );
if(obj instanceof Object && obj.MS_QueryResponse){
if ( obj.MS_QueryResponse.counts.samples == 0 ) {
sample_store.removeAll();
//grid.getBottomToolbar().displayEl.dom.innerHTML=grid.getBottomToolbar().emptyMsg;
var bbar = grid.getBottomToolbar();
bbar.updateInfo();
bbar.afterTextEl.el.innerHTML = String.format(bbar.afterPageText, 1);
bbar.field.dom.value="1";
bbar.first.setDisabled(true);
bbar.prev.setDisabled(true);
bbar.next.setDisabled(true);
bbar.last.setDisabled(true);
}
}
mask.hide();
}
})

var sample_store = new Ext.data.Store(
    {
proxy: sampleProxy,
baseParams: details.params,
sortInfo: {field:'acc', direction:'ASC'},
paramNames: common.dataStoreParamNames,
firstLoad: true,			 
reader: sample_reader,
remoteSort: true,
listeners: {  
'beforeload': function(e,r){
if(typeof r.params == 'undefined' || typeof r.params.start == 'undefined'){
if(typeof r.params == 'undefined'){ r.params = {};}
r.params.start = 0;
}
if(e.firstLoad){ 
e.loadData(details);
e.firstLoad = false; 
return false;
}
return true;
},
  'load': function(){ 
    // The line below was in Zhi's repository version
    //           expandedrowidx = -1 ;

    Ext.select( '.x-grid3-row-expanded' ).replaceClass( 'x-grid3-row-expanded', 'x-grid3-row-collapsed' );
  },
scope: this 
}
});

var id = 'samples_grid';
if(gridID) {id = gridID;}
//if (currentlyInView == 'admin_studies' || currentlyInView == 'my_studies' ){id=data_type + '_grid';}

var enterykey = jQuery('input#searchq').keypress(function(e){
    if(e.which == 13){
    details.params.filterstr =  jQuery('input#searchq').val();
    details.params.filtercol = jQuery('select#selectedTitle').val();
    sample_store.load( { params: { start: 0,
      filterstr: details.params.filterstr,
      filtercol: details.params.filtercol,
      limit: common.numberPerPage }
      }
      );
    }
    });

var button = jQuery('input#searchbtn').click(function(){
    details.params.filterstr = jQuery('input#searchq').val();
    details.params.filtercol = jQuery('select#selectedTitle').val();
    sample_store.load( { params: { start: 0,
      filterstr: details.params.filterstr,
      filtercol: details.params.filtercol,
      limit: common.numberPerPage }
      }
      );
    });


grid = new xg.GridPanel(
    {
id: id,
store: sample_store,
cm: sample_cm,
emptyText: 'No Record found',
viewConfig: 
{
forceFit: true,
scrollOffset: 15
},				
fitToFrame: true,	
bbar: new Ext.PagingToolbar( 
  {
id: id+'_pager',//'studies_pager',
store: sample_store,
pageSize: common.numberPerPage,
displayInfo: true,
displayMsg: 'Displaying samples {0} - {1} of {2}',
emptyMsg: "No samples to display"
}),
selModel:null ,

  listeners:{
render: common.highlightLink,
	cellclick:cellClickHandler
  },
loadMask: { msg: 'Loading...' },   
  height: calcGridHeight() ,		
  //width: '100%',
  viewConfig: {forceFit: true},
  collapsible: false,				
  monitorResize: true,				 
  iconCls: 'icon-grid', 
  border: false,
  plugins: [sample_expander/*,checkboxmodel*/],
  //plugins: [new Ext.ux.FitToParent("samplestudyWrapper")]
  autoExpandColumn: 3,
  stripeRows: true,
  renderTo: opts.renderTo
  });            
sample_store.load( { params: { start: 0, limit: common.numberPerPage } } );

var button = jQuery('input#downloadbtn').click(function(){
    var filterstr = jQuery('input#searchq').val();
    var filtercol = jQuery('select#selectedTitle').val();

    var p = {cmd: 'downloadtable', filterstr: filterstr, filtercol: filtercol};
    var paramsObj = common.setParamsObj( p );
    var request = common.pathname + 'cgi/passel/query_repository.cgi?cmd=downloadtable&filterstr='+filterstr+'&filtercol='+filtercol;
    var iframe = Ext.DomHelper.append(document.body, {
tag: 'iframe',
frameBorder: 0,
width: 0,height: 0,
src: request
});                                                                                                     
    });            


//recalculateHeights(grid);                
if(border){
  border.doLayout();
  border.syncSize();
}else{		     
  grid.setWidth(grid.container.parent().getWidth());			    
}

Ext.EventManager.onWindowResize( function(){
    if(!Ext.isIE){
    grid.getView().refresh();
    }else{
    if(border){ grid.setWidth(border.body.getWidth());	}
    }									  
    // onGridRender();
    });

function cellClickHandler(grid, rowIndex, columnIndex, e){
  //e.stopEvent(); 
  var record = grid.getStore().getAt(rowIndex);  // Get the Record
  var fieldName = grid.getColumnModel().getDataIndex(columnIndex); // Get field name
  var data = record.get(fieldName);
  var gridId = grid.getId();

  var renderer = grid.getColumnModel().getRenderer( columnIndex);
  var rendered = data;
  if(renderer){
    rendered = renderer(data,' ',record);			
  }				

  if(fieldName && columnIndex != 0 && !/<a/.test(rendered) ){
    if(/samples/.test(gridId) || /tab_PSE.*/.test(gridId) /*gridId == 'grid_samples' */){
      sample_expander.toggleRow(rowIndex);
    }
  }	  	  
}
}
/**************************************************************/
/* 			    END Data Store and Column Models 			  */
/**************************************************************/
} // End sample Class

/*
 * Ext JS Library 2.0
 * Copyright(c) 2006-2007, Ext JS, LLC.
 * licensing@extjs.com
 * 
 * http://extjs.com/license
 * 
 * MODIFIED: SGB [12.12.07]
 * Added support for a new config option, remoteDataMethod,
 * including getter and setter functions, and minor mods
 * to the beforeExpand and expandRow functions
 */

Ext.grid.RowExpander = function(config){
  Ext.apply(this, config);
  Ext.grid.RowExpander.superclass.constructor.call(this);

  if(this.tpl){
    if(typeof this.tpl == 'string'){
      this.tpl = new Ext.Template(this.tpl);
    }
    this.tpl.compile();
  }

  this.state = {};
  this.bodyContent = {};

  this.addEvents({
beforeexpand : true,
expand: true,
beforecollapse: true,
collapse: true
});
};
var expandedrowidx = -1;
Ext.extend(Ext.grid.RowExpander, Ext.util.Observable, {
header: "",
width: 20,
sortable: false,
fixed:true,
dataIndex: '',
id: 'expander',
lazyRender : true,
enableCaching: true,

getRowClass : function(record, rowIndex, p, ds){
p.cols = p.cols-1;
var content = this.bodyContent[record.id];
if(!content && !this.lazyRender){
content = this.getBodyContent(record, rowIndex);
}
if(content){
p.body = content;
}
return this.state[record.id] ? 'x-grid3-row-expanded' : 'x-grid3-row-collapsed';
},

init : function(grid){
	 this.grid = grid;

	 var view = grid.getView();
	 view.getRowClass = this.getRowClass.createDelegate(this);

	 view.enableRowBody = true;

	 grid.on('render', function(){
	     view.mainBody.on('mousedown', this.onMouseDown, this);
	     }, this);
       },

getBodyContent : function(record, index){
		   if(!this.enableCaching){
		     return this.tpl.apply(record.data);
		   }
		   var content = this.bodyContent[record.id];
		   if(!content){
		     content = this.tpl.apply(record.data);
		     this.bodyContent[record.id] = content;
		   }
		   return content;
		 },
		 // Setter and Getter methods for the remoteDataMethod property
setRemoteDataMethod : function (fn){
			this.remoteDataMethod = fn;
		      },

getRemoteDataMethod : function (record, index){
			if(!this.remoteDataMethod){
			  return;
			}
			return this.remoteDataMethod.call(this,record,index);
		      },

onMouseDown : function(e, t){
		if(t.className == 'x-grid3-row-expander'){
		  e.stopEvent();
		  var row = e.getTarget('.x-grid3-row');
		  this.toggleRow(row);
		}
	      },

renderer : function(v, p, record){
	     p.cellAttr = 'rowspan="2"';
	     return '<div class="x-grid3-row-expander">&#160;</div>';
	   },

beforeExpand : function(record, body, rowIndex){
		 if(this.fireEvent('beforexpand', this, record, body, rowIndex) !== false){
		   // If remoteDataMethod is defined then we'll need a div, with a unique ID,
		   //  to place the content

		   if(this.remoteDataMethod){
		     this.tpl = new Ext.Template("<div id='remData" + rowIndex + "' class='rem-data-expand'></div>");
		   }
		   if(this.tpl && this.lazyRender){
		     body.innerHTML = this.getBodyContent(record, rowIndex);
		   }

		   return true;
		 }else{
		   return false;
		 }
	       },

toggleRow : function(row){
	      if(typeof row == 'number'){
		row = this.grid.view.getRow(row);
	      }
	      this[Ext.fly(row).hasClass('x-grid3-row-collapsed') ? 'expandRow' : 'collapseRow'](row);
	    },

expandRow : function(row){
	      if(typeof row == 'number'){
		row = this.grid.view.getRow(row);
	      }

	      var record = this.grid.store.getAt(row.rowIndex);
	      var body = Ext.DomQuery.selectNode('tr:nth(2) div.x-grid3-row-body', row);
	      if( expandedrowidx != -1){
		this.toggleRow(expandedrowidx);
	      }

	      if(this.beforeExpand(record, body, row.rowIndex)){
		this.state[record.id] = true;
		Ext.fly(row).replaceClass('x-grid3-row-collapsed', 'x-grid3-row-expanded');
		if(this.fireEvent('expand', this, record, body, row.rowIndex) !== false){
		  //  If the expand event is successful then get the remoteDataMethod
		  this.getRemoteDataMethod(record,row.rowIndex);
		  expandedrowidx = row.rowIndex;
		}
	      }
	    },

collapseRow : function(row){
		if(typeof row == 'number'){
		  row = this.grid.view.getRow(row);
		}
		var record = this.grid.store.getAt(row.rowIndex);
		var body = Ext.fly(row).child('tr:nth(1) div.x-grid3-row-body', true);
		if(this.fireEvent('beforcollapse', this, record, body, row.rowIndex) !== false){
		  this.state[record.id] = false;
		  Ext.fly(row).replaceClass('x-grid3-row-expanded', 'x-grid3-row-collapsed');
		  this.fireEvent('collapse', this, record, body, row.rowIndex);
		  expandedrowidx = -1;
		}
	      }
});
Ext.namespace("Ext.ux");
Ext.namespace("Ext.ux.data");

/* Fixes for IE/Opera old javascript versions */
if(!Array.prototype.map){
  Array.prototype.map = function(fun){
    var len = this.length;
    if(typeof fun != "function"){
      throw new TypeError();
    }
    var res = new Array(len);
    var thisp = arguments[1];
    for(var i = 0; i < len; i++){
      if(i in this){
	res[i] = fun.call(thisp, this[i], i, this);
      }
    }
    return res;
  };
}

if (!Array.prototype.filter){
  Array.prototype.filter = function(fun /*, thisp*/){
    var len = this.length;
    if (typeof fun != "function")
      throw new TypeError();

    var res = new Array();
    var thisp = arguments[1];
    for (var i = 0; i < len; i++){
      if (i in this){
	var val = this[i]; // in case fun mutates this
	if (fun.call(thisp, val, i, this))
	  res.push(val);
      }
    }
    return res;
  };
}

/**
 * browsePeptidome
 * NCBI Peptidome browsing application
 *
 */

Ext.BLANK_IMAGE_URL = '../images/default/s.gif';
Ext.ns( 'browsePeptidome' );


browsePeptidome.app = function(){
  //Ext.QuickTips.init();

  var common = new jQuery.ui.PAcommon;	

  var studyObj = '';
  var sampleObj = '';	

  var contentContainer = 'center';
  var centerPanel = 'center-panel';
  var tabContainer = 'tabsPanel';
  var sampleLayout = 'sample-layout';
  var tabsID = 'studiesSampleTabs';

  var userRole = '';

  var data_type = "samples";

  var sample = [];       // For saving sub-grid data

  var scope = 'public';
  var userLevel = '';	


  var sample_from_param = common.get_url_parameter( 'samples' );


  //--------------------------------------------
  // Create sample selection menu using Tabs
  //--------------------------------------------	
  function handleActivate ( tab ){
    data_type = tab.id;

    // Get grid for current tab			
    var gridAddr = data_type;

    gridAddr = data_type+"_grid";

    //currentGridInView = gridAddr;		

    var grid = Ext.getCmp(gridAddr);		

    // get grid for inactivated tab
    // hide all grids in inactive tabs
    var allTabs = common.tabPanel.findByType('box');
    for (index in allTabs){
      var id = allTabs[index].id;
      if(id){
	var addr2 = id+'_grid';

	if(id != data_type){	
	  var err = Ext.get(addr2+'_err');
	  if(err){Ext.get('expandedContent').enableDisplayMode('inline-block').setVisible(false);}
	  err = Ext.get('_err');
	  if(err){Ext.get('expandedContent').enableDisplayMode('inline-block').setVisible(false);}
	  //if(err){Ext.get('expandedContent').remove();}

	  var grid2 = Ext.getCmp(addr2);
	  if(grid2){grid2.setVisible(false);}
	}
      }
    }

    if(grid && grid !== undefined){					
      grid.show();


      grid.setWidth(grid.container.getWidth());
      Ext.EventManager.onWindowResize( function(){ 
	  grid.setWidth(grid.container.getWidth());	
	  });

      return true;
    } else if (Ext.get(gridAddr+'_err')){
      Ext.get('expandedContent').show();
      return true;
    }	

    if( tab.ifEmpty ) {tab.ifEmpty(); return;}			
  }

  function makeTabs(params){	
    common.tabPanel = common.constructTabPanel({renderTo: tabContainer,id:tabsID,enableTabScroll:true,autoWidth:true});
    var samples_placeholder = common.constructTabPanelComponent({ 
title: 'Experiments', 
ifEmpty: function(){ 
if(!sampleObj && sampleClass){
sampleObj = new sampleClass({renderTo: contentContainer,centerPanel: centerPanel});
}				 
var config = common.gridViewOpts.publicSamples;				 
sampleObj.gridView(config) ;
},	
id: 'samples', 
listeners: {activate: handleActivate }
});

common.tabPanel.add(samples_placeholder);

var view_from_param = common.get_url_parameter( 'view' );
data_type = view_from_param ? view_from_param : data_type;

if(data_type == 'mysamples'){
  var ty = 'samples';
  var opt = 'mySamples';
  data_type = ty;

  var tabGridID = 'tab_my_'+ty+'_all';			

  if(Ext.getCmp(tabsID).findById(tabGridID)){				
    Ext.getCmp(tabsID).setActiveTab(tabGridID);
  }else{				
    var title= 'My '+ty;								 				 
    createDataTabs(tabGridID,title,'',data_type, opt);
  }	
}else{		
  common.tabPanel.setActiveTab(data_type);
}
}  // END makeTabs

function createDataTabs (id,title,params,type, gridViewOptsID){
  if(common.tabPanel.findById(id)){		
    common.tabPanel.setActiveTab(id);
  }
  else{			
    var placeholder = new Ext.BoxComponent({
title: title,
autoEl: {},
id: id,
closable: true,
ifEmpty: function (){
if (type == 'samples'){
if(!sampleObj && sampleClass){
sampleObj = new sampleClass({renderTo: contentContainer,centerPanel: centerPanel});
}				 
var config = common.gridViewOpts[gridViewOptsID];				 
sampleObj.gridView(config) ;	
}
},
listeners: {
activate: handleActivate,
destroy: function(p){	
var gid = this.id+"_grid";	
var err = Ext.get(gid+'_err');												 
if(err){Ext.get('expandedContent').remove();}

grid = Ext.getCmp(gid);
if(grid){ 	
  // do no cache grid
  grid.destroy();//grid.setVisible(false);							
}
}
}
});
common.tabPanel.add(placeholder);
//get_data( params, type, level );
common.tabPanel.setActiveTab(id);
}		
}


function calcGridHeight(){		
  return Ext.getCmp(centerPanel).getSize().height - 0;
}

function appendTab (grid,rowIndex,id,title,record,cmdOptions){
  var tp = common.tabPanel;
  if(tp.findById(id)){
    tp.setActiveTab(id);
  }
  else{
    var placeholder = new Ext.BoxComponent({
title: title,
autoEl: {},
id: id,
ifEmpty: function(){ 
if(!sampleObj && sampleClass){
sampleObj = new sampleClass({renderTo: contentContainer,centerPanel: centerPanel});
}				 
var config = '';

if(cmdOptions) {config = cmdOptions;}
else{ config = common.gridViewOpts.publicSamples;}

sampleObj.gridView(config) ;
},
closable: true,
listeners: {
activate: handleActivate,
destroy: function(p){						
var gid = this.id+"_grid";

var err = Ext.get(gid+'_err');						

if(err){Ext.get('expandedContent').remove();}

grid = Ext.getCmp(gid);
if(grid){ 			
  // do no cache grid
  grid.destroy();//grid.setVisible(false);
}
}
}
});
tp.add(placeholder);
/*var isPublic = true;
  if(record.data.public === false){isPublic = false;}
  get_samples_for_experiment( record, rowIndex,isPublic );*/
tp.setActiveTab(id);
}		
}


function getStringWidthHeight(text, r )
{
  Ext.DomHelper.append(document.body,{html: Ext.util.Format.trim(text), tag: 'span',id: 'deflDynaHiddenSpan'});
  var tspan = Ext.get('deflDynaHiddenSpan'); 
  var val = Ext.util.TextMetrics.measure(tspan, text).width; 
  if(r === 'height'){val = Ext.util.TextMetrics.measure(tspan, text).height;}
  tspan.remove();

  return val;
}

return {

init: function () 
      {

	/**
	 * Add Panel for border layout
	 */
	var border = new Ext.Panel(
	    {
id: 'layout',
layout: 'border',
height: common.layout_height,
monitorResize: true,

items: 
[
{
layout: 'fit',
region:'north',       			
id: 'north-panel',
contentEl: tabContainer,					
border: false,
height: common.tab_height,
split: false
},				 
{
layout: 'fit',
region: 'center',
id: centerPanel,
contentEl: contentContainer,
margins: '5 5 5 5',//(Ext.isSafari)?'5 20 5 5':'5 5 5 5',    // In Safari, the scroll bar is hidden. Setting right margin to 20 shows the scroll bar (15px for scroll bar, 5px for blue margin (evening the style)
border: false,
split: false
}
],
  renderTo: sampleLayout
  });

var tokenURL = '';
if(common.token){tokenURL = '?token='+common.token;}
var cC = Ext.get('samplestudyWrapper');
if (cC){                
  cC.enableDisplayMode('inline-block').setVisible(false);
}
var params = "cmd=entries&type=samples";//&details";
if(sampleClass){
  sampleObj = new sampleClass({renderTo: contentContainer,centerPanel: centerPanel});
}	
makeTabs(params);
}   // End init
};  // End return
}();


Ext.onReady( browsePeptidome.app.init, browsePeptidome.app );
