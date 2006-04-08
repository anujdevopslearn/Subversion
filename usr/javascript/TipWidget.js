// tooltip credits? mjohnson, other ISBers?
function showTooltip(ev, tooltipText) {
  if ( !Tip.ok ||
	   typeof Tip == "undefined" ) {
	return;
  }
  Tip.showTooltip(ev, tooltipText);
}

function hideTooltip() {
  if ( !Tip.ok ||
	   typeof Tip == "undefined" ) {
	return;
  }
  Tip.hideTooltip();
}

var buffer = 18;
var Tip = {
 tipID: "tooltipID",
 ok:false,
 countdown:null,
 tooltip:null, 

 initialize: function() {  
   if ( document.body && 
        document.createElement && 
		typeof document.body.appendChild != "undefined" ) {

	 // Create <DIV> element
	 if ( !document.getElementById(this.tipID) ) {
	   var divElement = document.createElement("DIV");
	   divElement.id = this.tipID; document.body.appendChild(divElement);
	 }

	 this.ok = true;
   }
 },

 getWindowpaneX: function () {
   this.width = 0;
   if (window.innerWidth) this.width = window.innerWidth - buffer;
   else if (document.documentElement && 
			document.documentElement.clientWidth) 
	 this.width = document.documentElement.clientWidth;
   else if (document.body && 
			document.body.clientWidth) 
	 this.width = document.body.clientWidth;
 },
  
 getWindowpaneY: function () {
   this.height = 0;
   if (window.innerHeight) this.height = window.innerHeight - buffer;
   else if (document.documentElement && 
			document.documentElement.clientHeight) 
	 this.height = document.documentElement.clientHeight;
   else if (document.body && 
			document.body.clientHeight) 
	 this.height = document.body.clientHeight;
 },
  
 getScrollpaneX: function () {
   this.scrollX = 0;
   if (typeof window.pageXOffset == "number") this.scrollX = window.pageXOffset;
   else if (document.documentElement && 
			document.documentElement.scrollLeft)
	 this.scrollX = document.documentElement.scrollLeft;
   else if (document.body && 
			document.body.scrollLeft) 
	 this.scrollX = document.body.scrollLeft; 
   else if (window.scrollX) this.scrollX = window.scrollX;
 },
  
 getScrollpaneY: function () {
   this.scrollY = 0;    
   if (typeof window.pageYOffset == "number") this.scrollY = window.pageYOffset;
   else if (document.documentElement && 
			document.documentElement.scrollTop)
	 this.scrollY = document.documentElement.scrollTop;
   else if (document.body && 
			document.body.scrollTop) 
	 this.scrollY = document.body.scrollTop; 
   else if (window.scrollY) this.scrollY = window.scrollY;
 },
  
 getAllDimensions: function () {
   this.getWindowpaneX();
   this.getScrollpaneX();
   this.getWindowpaneY();
   this.getScrollpaneY();
 },
  
 add: function(obj, eventType, fp, cap) {
   cap = cap || false;
   if (obj.addEventListener) obj.addEventListener(eventType, fp, cap);
   else if (obj.attachEvent) obj.attachEvent("on" + eventType, fp);
 }, 

 remove: function(obj, eventType, fp, cap) {
   cap = cap || false;
   if (obj.removeEventListener) obj.removeEventListener(eventType, fp, cap);
   else if (obj.detachEvent) obj.detachEvent("on" + eventType, fp);
 },

 showTooltip: function(ev, tooltipText) {
   if (this.countdown) { 
	 clearTimeout(this.countdown);
	 this.countdown = 0; 
   }
   this.tooltip = document.getElementById( this.tipID );

   // mouse movement tracking
   if (this.mouseMovement) 
	 this.add( document, "mousemove", this.trackMouseMovement, true );

   // create the tooltip message
   if ( this.tooltip && 
		typeof this.tooltip.innerHTML != "undefined" ) {
	 this.tooltip.innerHTML = tooltipText;
   }

   // get dimensions and (relative) location
   this.getAllDimensions();

   // show the tooltip
   this.placeToolTip(ev);

   // 100 => how long to wait before evaluating to show (in millisec.)
   // should be setTimeouut(Tip.switch('tipID','visible'),100)
   this.countdown = setTimeout("Tip.toggleVis('" + this.tipID + "','visible')", 100);
 },


 getVisibility: function (ev) {
   if (ev.style) {
	 if (ev.style.visibility && 
		 ev.style.visibility != 'inherit')
	   return ev.style.visibility;

	 if (ev.currentStyle && 
		 ev.currentStyle.visibility && 
		 ev.currentStyle.visibility != 'inherit')
	   return ev.currentStyle.visibility;

	 else while (ev = ev.parentEvement) {
	   if (ev != null && 
		   ev.style.visibility && 
		   ev.style.visibility != 'inherit')
		 return ev.style.visibility;

	   if (ev != null && 
		   ev.currentStyle && 
		   ev.currentStyle.visibility && 
		   ev.currentStyle.visibility != 'inherit')
		 return ev.currentStyle.visibility;
	 }

   } else if (document.layers) {
	 if (ev.visibility != 'inherit') 
	   return ev.visibility;
	 else 
	   while (ev = ev.parentLayer) {
		 if (ev != null && 
			 ev.visibility != 'inherit') {
		   return ev.visibility;
		 }
	   }
   }
   return (!document.layers) ? 'visible' : 'show';
 },


 hideTooltip: function() {
   if (this.countdown) {
	 clearTimeout(this.countdown);
	 this.countdown = 0;
   }
   
   // 150 => how long to wait before evaluating to hid (in millisec.)
   // should be setTimeouut(Tip.switch('tipID','hidden'),150)
   this.countdown = setTimeout("Tip.toggleVis('" + this.tipID + "','hidden')", 150);
   if (this.mouseMovement) {
	 this.remove( document, "mousemove", this.trackMouseMovement, true );
   }
   this.tooltip = null; 
 },

 toggleVis: function(id, isVisible) { 
   var divElement = document.getElementById(id);
   if (divElement) {
	 //	 divElement.style.visibility = (this.getVisibility(divElement) == 'visible') ? 'hidden' : 'visible';
	 divElement.style.visibility = isVisible;
   }
 },
    
 mouseMovement: true,
 trackMouseMovement: function(ev) {
   ev = ev? ev: window.event;
   ev.tgt = ev.srcElement? ev.srcElement: ev.target;
    
   if (!ev.preventDefault)
	 ev.preventDefault = function () { return false; }
   if (!ev.stopPropagation) 
	 ev.stopPropagation = function () { 
	   if (window.event) window.event.cancelBubble = true; 
	 }

   Tip.placeToolTip(ev);
 },

 placeToolTip: function (event) {
   // place the tooltip, offset by 10 pixels
   if ( this.tooltip && this.tooltip.style ) {

	 var x = event.pageX? event.pageX:event.clientX+this.scrollX;
	 var y = event.pageY? event.pageY:event.clientY+this.scrollY;

	 //Y-coordinate information
	 if ( y + this.tooltip.offsetHeight + 10 > this.height + this.scrollY ) {
	   y = y - this.tooltip.offsetHeight - 10;
	   if ( y < this.scrollY ) 
		 y = this.height + this.scrollY - this.tooltip.offsetHeight;
	 } else {
	   y = y + 10;
	 }

	 //X-coordinate information
	 if ( x + this.tooltip.offsetWidth + 10 > this.width+this.scrollX ) {
	   x = x - this.tooltip.offsetWidth - 10;
	   if ( x < 0 ) x = 0;
	 } else {
	   x = x + 10;
	 }

	 //Set the tooltip, based upon the coordinate information
	 this.tooltip.style.left = x+"px";
	 this.tooltip.style.top = y+"px";
   }
 }
 
 }

Tip.initialize();
