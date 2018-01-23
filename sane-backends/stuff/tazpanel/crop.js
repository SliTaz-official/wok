var cropOrgWidth, cropOrgHeight, cropX, cropY, cropWidth, cropHeight;
var cropBaseX, cropBaseY, cropDot2value, cropMinSize, cropDragOfs;

var cropEventX, cropEventY;
var cropResizeId, cropEventTop, cropEventLeft, cropEventWidth, cropEventHeight;
var cropResizeCounter = -1, cropMoveCounter = -1;

var cropDivW, cropDivN, cropDivE, cropDivS, cropDivFrame;
var cropNW, cropN, cropNE, cropW, cropE, cropSW, cropS, cropSE; 

function cropOpacity(div,degree)
{
	div.style.backgroundColor = '#FFF';
	if (div.style.opacity) div.style.opacity = degree / 100;
	if (div.style.MozOpacity) div.style.MozOpacity = degree / 101;
	if (div.style.KhtmlOpacity) div.style.KhtmlOpacity = degree / 100;
}

function cropCreateDiv(e)
{
	var div = document.createElement('DIV');
	div.style.position = 'absolute';
	div.style.visibility = 'visible';
	cropOpacity(div,60);
	div.style.left= div.style.top= div.style.height= div.style.width= '0px';
	div.innerHTML = '<span></span>';
	e.appendChild(div);
	return div;
}

function cropCreateDragImg(id)
{
	var div = document.createElement('IMG');
	div.src = 'styles/default/images/drag.gif';
	div.width = 12;
	div.style.position = 'absolute';
	div.style.cursor = div.id = id;
	div.onmousedown = cropInitResize;
	cropDivFrame.appendChild(div);
	return div;
}

function cropSetFrame()
{
	var top = cropDivFrame.style.top.replace('px','');
	var left = cropDivFrame.style.left.replace('px','');
	var width = cropDivFrame.style.width.replace('px','');
	var height = cropDivFrame.style.height.replace('px','');
	var totalTop = top/1 + height/1;
 	var totalWidth = left/1 + width/1;
	
	cropN.style.left =
	cropS.style.left = (Math.floor(width/2) - cropDragOfs) + 'px';
	cropE.style.left =
	cropNE.style.left =
	cropSE.style.left = (width - cropDragOfs) + 'px';
	cropW.style.top = 
	cropE.style.top = (Math.floor(height/2) - cropDragOfs) + 'px';
	cropS.style.top =
	cropSE.style.top =
	cropSW.style.top = (height - cropDragOfs) + 'px';
	
	cropDivS.style.height = Math.max(0,cropOrgHeight - totalTop) + 'px';
	cropDivN.style.height = cropDivFrame.style.top;
	cropDivS.style.width = 
	cropDivN.style.width = width + 'px' ;
	cropDivE.style.width = Math.max(0,cropOrgWidth - totalWidth) + 'px';
	cropDivW.style.width =
	cropDivS.style.left = 
	cropDivN.style.left = cropDivFrame.style.left;
	cropDivE.style.left = totalWidth + 'px';
	cropDivS.style.top = totalTop + 'px';
}

function cropSaveEvent(e)
{
	cropEventX = e.clientX;
	cropEventY = e.clientY;
	cropEventTop = cropDivFrame.style.top.replace('px','');
	cropEventLeft = cropDivFrame.style.left.replace('px','');
	cropEventWidth = cropDivFrame.style.width.replace('px','');
	cropEventHeight = cropDivFrame.style.height.replace('px','');
}

function cropTimerMove()
{
	if (cropMoveCounter >= 0 && cropMoveCounter < 10) {
		cropMoveCounter++;
		setTimeout('cropTimerMove()',1);
	}		
}

function cropTimerResize()
{
	if (cropResizeCounter >= 0 && cropResizeCounter < 10) {
		cropResizeCounter++;
		setTimeout('cropTimerResize()',1);
	}
}

function cropCancelEvent(e)
{
	if (document.all) e = event;
	if (e.target) source = e.target;
	else if (e.srcElement) source = e.srcElement;
	if (source.tagName && source.tagName.toLowerCase() == 'input')
		return true;
	return false;
}

function cropInitMove(e)
{
	if (document.all) e = event;
	if (e.target) source = e.target;
	else if (e.srcElement) source = e.srcElement;
	if (source.id && source.id.indexOf('resize') >= 0) return;	
	cropSaveEvent(e);
	cropMoveCounter = 0;
	cropTimerMove();
	return false;
}

var cropDiv0style;
function cropInitResize(e)
{
	if (document.all) e = event;
	cropDivFrame.style.cursor = 'default';
	if (document.all) cropDiv0style.display = 'none';
	cropResizeId = this.id;
	cropResizeCounter = 0;
	cropSaveEvent(e);
	cropTimerResize();
	return false;
}

var cropMouseMoveEventInProgress = false;
function cropMouseMove(e)
{
	if (cropMouseMoveEventInProgress) return;
	if (cropMoveCounter < 10 && cropResizeCounter < 10) return;
	if (document.all) cropMouseMoveEventInProgress = true;
	if (document.all) e = event;
	var deltaX = e.clientX - cropEventX;
	var deltaY = e.clientY - cropEventY;
	if (cropResizeCounter == 10) {
		var top = cropEventTop;
		var left = cropEventLeft;
		var width = cropEventWidth;
		var height = cropEventHeight;
		if (cropResizeId == 'e-resize'
		 || cropResizeId == 'ne-resize'
		 || cropResizeId == 'se-resize') {
			width = Math.max(cropMinSize,
				cropEventWidth/1 + deltaX/1);
		}
		if (cropResizeId == 's-resize'
		 || cropResizeId == 'sw-resize'
		 || cropResizeId == 'se-resize') {
			height = Math.max(cropMinSize,
				cropEventHeight/1 + deltaY/1);
		}
		if (cropResizeId == 'w-resize'
		 || cropResizeId == 'sw-resize'
		 || cropResizeId == 'nw-resize') {
		 	var total = left/1 + width/1;
			left = Math.min(left/1 + deltaX/1, total - cropMinSize);
			width = total - left;
		}
		
		if (cropResizeId == 'n-resize'
		 || cropResizeId == 'nw-resize'
		 || cropResizeId == 'ne-resize') {
			var total = top/1 + height/1;
			top = Math.min(top/1 + deltaY/1, total - cropMinSize);
			height = total - top;
		}
		
		if (top > cropOrgHeight) height = cropOrgHeight - top;
		if (left > cropOrgWidth) width  = cropOrgWidth - left;
		
		cropDivFrame.style.top = top + 'px';
		cropDivFrame.style.left = left + 'px';
		cropDivFrame.style.width = width + 'px';
		cropDivFrame.style.height = height + 'px';
	}
	
	if (cropMoveCounter == 10) {
		var left = cropEventLeft/1 + deltaX/1;
		var leftMax = cropOrgWidth - cropEventWidth;
		if (left < 0) left = 0;
		if (left > leftMax) left = leftMax;
		cropDivFrame.style.left = left + 'px';
		var top = cropEventTop/1 + deltaY/1;
		var topMax = cropOrgHeight - cropEventHeight;
		if (top < 0) top = 0;
		if (top > topMax) top = topMax;
		cropDivFrame.style.top = top + 'px';
	}
	cropSetFrame();		
	cropMouseMoveEventInProgress = false;
}

function cropUpdateFromValues()
{
	cropX.value = Math.round(10 * cropDot2value 
		* cropDivFrame.style.left.replace('px','')) /10 
		+ cropBaseX/1;
	cropY.value = Math.round(10 * cropDot2value 
		* cropDivFrame.style.top.replace('px','')) /10 
		+ cropBaseY/1;
	cropWidth.value = Math.round(10 * cropDot2value 
		* cropDivFrame.style.width.replace('px','')) /10;
	cropHeight.value = Math.round(10 * cropDot2value 
		* cropDivFrame.style.height.replace('px','')) /10;
}

function cropStopResizeMove()
{
	cropMoveCounter = cropResizeCounter = -1;
	cropDivFrame.style.cursor = 'move';
	cropUpdateFromValues();
	if (document.all) cropDiv0style.display = 'block';
}

function cropGetInput(obj,origin,ofs,min,max)
{
	var t = origin;
	if (obj.value.length)
		t = (obj.value.replace(/[^0-9\.]/gi,'') - ofs) / cropDot2value;
	if (t < min) t = min;
	if (t > max) t = max;
	obj.value = Math.round(t * cropDot2value * 10) /10;
	return Math.round(t);
}

function cropSetFrameByInput()
{
	var x, y;
	x = cropGetInput(cropX, 0, cropBaseX, 0, cropOrgWidth - cropMinSize);
	y = cropGetInput(cropY, 0, cropBaseY, 0, cropOrgHeight - cropMinSize);
	cropDivFrame.style.top = y + 'px';
	cropDivFrame.style.left = x + 'px';
	cropDivFrame.style.width = cropGetInput(cropWidth, cropOrgWidth, 0, 
					cropMinSize, cropOrgWidth - x) + 'px';
	cropDivFrame.style.height = cropGetInput(cropHeight, cropOrgHeight, 0, 
					cropMinSize, cropOrgHeight - y) + 'px';
	cropSetFrame();		
}

function cropInit(e,x,y,width,height)
{
	var div = e.parentNode;
	
	cropOrgWidth = e.width;
	cropOrgHeight = e.height;
	
	cropX = document.getElementById(x);
	cropY = document.getElementById(y);
	cropWidth = document.getElementById(width);
	cropHeight = document.getElementById(height);
	
	cropBaseX = cropX.value.replace(/[^0-9\.]/gi,'');
	cropBaseY = cropY.value.replace(/[^0-9\.]/gi,'');
	
	cropDot2value = cropWidth.value / e.width;
	
	div.style.position = 'relative';
	div.style.top = div.style.left = '0px';
	div.style.width = div.style.height = '100%';
	cropOpacity(div,0);

	cropDivW = cropCreateDiv(div);
	cropDivN = cropCreateDiv(div);
	cropDivE = cropCreateDiv(div);
	cropDivS = cropCreateDiv(div);
	cropDivN.style.width = cropDivE.style.left = 
	cropDivS.style.width = cropOrgWidth + 'px';
	cropDivW.style.height = cropDivE.style.height = 
	cropDivS.style.top = cropOrgHeight + 'px';
	
	cropDivFrame = document.createElement('DIV');
	cropDivFrame.style.border = '1px #000000 dashed';
	cropDivFrame.style.zIndex = 1000;
	cropDivFrame.style.position = 'absolute';
	cropDivFrame.style.left = cropDivFrame.style.top = '0px';
	cropDivFrame.style.width = cropOrgWidth + 'px';
	cropDivFrame.style.height = cropOrgHeight + 'px';
	cropDivFrame.innerHTML = '<div></div>'; 
	cropDivFrame.style.cursor = 'move';

	cropDiv0style = cropDivFrame.getElementsByTagName('DIV')[0].style;
	if (navigator.userAgent.indexOf('Opera') >=0 ) {
		cropDiv0style.backgroundColor =
		cropDivS.style.backgroundColor =
		cropDivE.style.backgroundColor =
		cropDivN.style.backgroundColor =
		cropDivW.style.backgroundColor = 'transparent';
	}
	
	cropNW = cropCreateDragImg('nw-resize');
	cropNE = cropCreateDragImg('ne-resize');
	cropSW = cropCreateDragImg('sw-resize');
	cropSE = cropCreateDragImg('se-resize');
	cropN = cropCreateDragImg('n-resize');
	cropS = cropCreateDragImg('s-resize');
	cropW = cropCreateDragImg('w-resize');
	cropE = cropCreateDragImg('e-resize');
	cropMinSize = cropE.width*2;
	cropDragOfs = Math.floor(cropE.width/2) 

	cropN.style.left = cropS.style.left = 
		(Math.floor(cropOrgWidth/2) - cropDragOfs) + 'px';
	cropSW.style.top = cropSE.style.top = 
	cropS.style.top = (cropOrgHeight - cropDragOfs) + 'px';
	
	cropNW.style.top = cropNW.style.left = 
	cropNE.style.top = cropSW.style.left = 
	cropN.style.top  = cropW.style.left = (-cropDragOfs) + 'px';
	
	cropNE.style.left = cropSE.style.left =
	cropE.style.left = (cropOrgWidth - cropDragOfs) + 'px';
	cropW.style.top = cropE.style.top = 
		(Math.floor(cropOrgHeight/2) - cropDragOfs) + 'px';
	
	div.appendChild(cropDivFrame); 
	
	div.onselectstart = div.ondragstart = cropCancelEvent;
	div.onmousemove = cropMouseMove;
	div.onmouseup = cropStopResizeMove;
	cropDivFrame.onmousedown = cropInitMove;
	cropX.onchange = cropY.onchange = cropWidth.onchange =
	cropHeight.onchange = cropSetFrameByInput;
}
