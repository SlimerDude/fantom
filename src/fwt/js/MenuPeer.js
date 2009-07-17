//
// Copyright (c) 2009, Brian Frank and Andy Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Jul 09  Andy Frank  Creation
//

/**
 * MenuPeer.
 */
fan.fwt.MenuPeer = fan.sys.Obj.$extend(fan.fwt.WidgetPeer);
fan.fwt.MenuPeer.prototype.$ctor = function(self) {}

fan.fwt.MenuPeer.prototype.open = function(self, parent, point)
{
  this.$parent = parent;

  // mount mask that functions as input blocker for modality
  var mask = document.createElement("div")
  with (mask.style)
  {
    position   = "fixed";
    top        = "0";
    left       = "0";
    width      = "100%";
    height     = "100%";
    background = "#fff";
    opacity    = "0.01";
    filter     = "progid:DXImageTransform.Microsoft.Alpha(opacity=1);"
  }

  // mount shell we use to attach widgets to
  var shell = document.createElement("div")
  with (shell.style)
  {
    position   = "fixed";
    top        = "0";
    left       = "0";
    width      = "100%";
    height     = "100%";
  }
  var $this = this;
  shell.onclick = function() { $this.close(); }

  // mount menu content
  var content = this.emptyDiv();
  with (content.style)
  {
    background = "#fff";
    opacity    = "0.95";
    padding    = "5px 0";
    MozBoxShadow    = "0 5px 12px #555";
    webkitBoxShadow = "0 5px 12px #555";
    MozBorderRadius     = "5px";
    webkitBorderRadius  = "5px";
  }

  // attach to DOM
  shell.appendChild(content);
  this.attachTo(self, content);
  document.body.appendChild(mask);
  document.body.appendChild(shell);
  self.relayout();

  // cache elements so we can remove when we close
  this.$mask = mask;
  this.$shell = shell;
}

fan.fwt.MenuPeer.prototype.close = function()
{
  if (this.$shell) this.$shell.parentNode.removeChild(this.$shell);
  if (this.$mask) this.$mask.parentNode.removeChild(this.$mask);
}

fan.fwt.MenuPeer.prototype.relayout = function(self)
{
  fan.fwt.WidgetPeer.prototype.relayout.call(this, self);

  var dx = 0; // account for padding
  var dy = 5; // account for padding
  var pw = 0;
  var ph = 0;

  var kids = self.children();
  for (var i=0; i<kids.length; i++)
    pw = Math.max(pw, kids[i].prefSize().w);

  pw += 8; // account for padding

  for (var i=0; i<kids.length; i++)
  {
    var kid  = kids[i];
    var pref = kid.prefSize();
    var mh = pref.h + 2;  // account for padding

    kid.pos$set(fan.gfx.Point.make(dx, dy));
    kid.size$set(fan.gfx.Size.make(pw, mh));
    kid.peer.sync(kid);
    dy += mh;
    ph += mh;
  }

  var pp = this.$parent.posOnDisplay();
  var ps = this.$parent.size$get();
  var x = pp.x + 1;
  var y = pp.y + ps.h + 1;
  var w = pw;
  var h = ph;

  // check if we need to swap dir
  var shell = this.elem.parentNode;
  if (x+w >= shell.offsetWidth-4)  x = pp.x + ps.w - w -1;
  if (y+h >= shell.offsetHeight-4) y = pp.y - h;

  this.pos$set(self, fan.gfx.Point.make(x, y));
  this.size$set(self, fan.gfx.Size.make(w, h));
  this.sync(self);
}

