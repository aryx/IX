(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's data/prelude/web/*.js (its 8af888e), one after the other as its dune puts them, in a string: kept here, as Js_prelude is (docs/plans/plan_browser.md) *)

let text = {prelude|
// What a page's scripts expect of a browser beyond the DOM, where it
// can be written over what is already here: small web APIs, in the
// language the pages use. Run once in every page, before its scripts
// (src/dom/Script_prelude.mli).
(function () {
  var g = globalThis;
  function global(name, v) { if (typeof g[name] === "undefined") g[name] = v; }
  // a function that is there so that a page does not stop, and does
  // nothing: said when it is called (with -v, "missing: name()"), for
  // the day a page looks wrong because of it
  function stub(name, value) { return function () { if (typeof __missed === "function") __missed(name); return value; }; }

  // the kinds of lists the DOM gives, as names a page tests against
  // (NodeList.prototype.isPrototypeOf(x)); the lists themselves are arrays
  // the class of window.screen, as a name a page tests against
  global("Screen", function Screen() {});
  // and window.screen is one, which can be listened to (its "change":
  // never said here), as an EventTarget is
  if (typeof screen === "object" && screen) {
    Object.setPrototypeOf(screen, Screen.prototype);
    Screen.prototype.addEventListener = Screen.prototype.removeEventListener = function () {};
    Screen.prototype.dispatchEvent = function () { return true; };
    if (screen.colorDepth === undefined) { screen.colorDepth = screen.pixelDepth = 24; screen.availLeft = screen.availTop = 0; }
  }
  global("NodeList", function NodeList() {});
  global("HTMLCollection", function HTMLCollection() {});
  // an element's attributes: a list, asked by name too (the host's)
  global("NamedNodeMap", function NamedNodeMap() {});
  NamedNodeMap.prototype = Object.create(Array.prototype);

  // window.postMessage (HTML5's cross-document messaging, 2008): a
  // message for a window, told to its "message" listeners in a task
  // of its own. Here a page can only post to itself -- which is how a
  // library gets a task sooner than a timer's, and how two parts of
  // one page that share nothing else talk.
  window.postMessage = function (data, options, transfer) {
    var ports = Array.isArray(transfer) ? transfer : (options && Array.isArray(options.transfer) ? options.transfer : []);
    setTimeout(function () {
      var e = new Event("message");
      e.data = data; e.origin = location.origin; e.source = window; e.ports = ports; e.lastEventId = "";
      window.dispatchEvent(e);
    }, 0);
  };

  // URL (WHATWG's URL Standard, 2012; the class in browsers from 2014):
  // an address in parts that can be written -- u.pathname = "/x",
  // u.searchParams.append("a", "1") -- its href made of them again.
  // The parts are cut by the browser (__url); the rest is here.
  (function () {
    var parts = g.__url;
    var PARTS = ["protocol", "host", "pathname", "search", "hash"];
    function URL(href, base) {
      if (!(this instanceof URL)) throw new TypeError("Failed to construct 'URL': Please use the 'new' operator");
      var text = String(href);
      if (base === undefined && !/^[a-zA-Z][a-zA-Z0-9+.-]*:/.test(text)) throw new TypeError("Failed to construct 'URL': Invalid URL");
      this._read(base === undefined ? parts(text) : parts(text, String(base)));
    }
    var P = URL.prototype;
    P._read = function (p) {
      this._p = { protocol: p.protocol, host: p.host, pathname: p.pathname, search: p.search, hash: p.hash };
      this._opaque = p.host === "" ? p.href : null;   // data:, about:, blob: -- no parts to write
      this._params = null;
    };
    Object.defineProperty(P, "href", {
      get: function () { var p = this._p; return this._opaque !== null ? this._opaque : p.protocol + "//" + p.host + p.pathname + p.search + p.hash; },
      set: function (v) { this._read(parts(String(v))); }, configurable: true });
    PARTS.forEach(function (k) {
      Object.defineProperty(P, k, {
        get: function () { return this._p[k]; },
        set: function (v) {
          v = String(v);
          if (k === "search") { v = v === "" || v === "?" ? "" : v.charAt(0) === "?" ? v : "?" + v; this._params = null; }
          if (k === "hash") v = v === "" || v === "#" ? "" : v.charAt(0) === "#" ? v : "#" + v;
          if (k === "pathname" && v.charAt(0) !== "/") v = "/" + v;
          if (k === "protocol" && v.charAt(v.length - 1) !== ":") v += ":";
          this._p[k] = v;
        }, configurable: true });
    });
    Object.defineProperty(P, "hostname", {
      get: function () { return this._p.host.replace(/:\d+$/, ""); },
      set: function (v) { var port = this.port; this._p.host = String(v) + (port ? ":" + port : ""); }, configurable: true });
    Object.defineProperty(P, "port", {
      get: function () { var m = /:(\d+)$/.exec(this._p.host); return m ? m[1] : ""; },
      set: function (v) { this._p.host = this.hostname + (String(v) === "" ? "" : ":" + v); }, configurable: true });
    Object.defineProperty(P, "origin", { get: function () { return this._opaque !== null ? "null" : this._p.protocol + "//" + this._p.host; }, configurable: true });
    Object.defineProperty(P, "username", { get: function () { return ""; }, set: function () {}, configurable: true });
    Object.defineProperty(P, "password", { get: function () { return ""; }, set: function () {}, configurable: true });
    // the query as pairs, written back into search by what changes them
    Object.defineProperty(P, "searchParams", {
      get: function () {
        if (this._params) return this._params;
        var url = this, sp = new URLSearchParams(this._p.search);
        ["append", "delete", "set", "sort"].forEach(function (m) {
          var own = sp[m];
          if (typeof own === "function") sp[m] = function () { var r = own.apply(sp, arguments), q = sp.toString(); url._p.search = q === "" ? "" : "?" + q; return r; };
        });
        return this._params = sp;
      }, configurable: true });
    P.toString = function () { return this.href; };
    P.toJSON = function () { return this.href; };
    URL.canParse = function (href, base) { try { new URL(href, base); return true; } catch (e) { return false; } };
    URL.parse = function (href, base) { try { return new URL(href, base); } catch (e) { return null; } };
    var blobs = 0;
    URL.createObjectURL = function () { return "blob:" + (++blobs); };
    URL.revokeObjectURL = function () {};
    g.URL = URL;
  })();

  // base64 (RFC 4648): three bytes as four letters. The bytes are a
  // "binary string", a character a byte (its code under 256): what
  // atob gives back, and all that btoa takes
  var letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
  global("btoa", function (s) {
    s = String(s);
    var out = "";
    for (var i = 0; i < s.length; i += 3) {
      var a = s.charCodeAt(i), b = s.charCodeAt(i + 1), c = s.charCodeAt(i + 2);
      var n = (a << 16) | ((b || 0) << 8) | (c || 0);
      out += letters[n >> 18] + letters[(n >> 12) & 63] + (i + 1 < s.length ? letters[(n >> 6) & 63] : "=") + (i + 2 < s.length ? letters[n & 63] : "=");
    }
    return out;
  });
  global("atob", function (s) {
    s = String(s).replace(/[\s=]/g, "");
    var out = "", bits = 0, n = 0;
    for (var i = 0; i < s.length; i++) {
      var v = letters.indexOf(s[i]);
      if (v < 0) throw new Error("InvalidCharacterError: the string to be decoded is not correctly encoded");
      n = (n << 6) | v; bits += 6;
      if (bits >= 8) { bits -= 8; out += String.fromCharCode((n >> bits) & 255); }
    }
    return out;
  });


  global("requestIdleCallback", function (f) {
    return setTimeout(function () { f({ didTimeout: false, timeRemaining: function () { return 50; } }); }, 1);
  });
  global("cancelIdleCallback", function (id) { clearTimeout(id); });

  // random numbers for a page: Math.random's here, not the kernel's
  // (a page run twice does the same)
  global("crypto", {
    getRandomValues: function (a) { for (var i = 0; i < a.length; i++) a[i] = Math.floor(Math.random() * 256); return a; },
    randomUUID: function () {
      return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, function (c) {
        var r = Math.floor(Math.random() * 16);
        return (c === "x" ? r : (r & 3) | 8).toString(16);
      });
    }
  });

  // what a page asks before it measures itself: none of it is measured here
  if (typeof PerformanceObserver === "function" && !PerformanceObserver.supportedEntryTypes) PerformanceObserver.supportedEntryTypes = [];

  // a request's or an answer's headers: names whatever their case
  global("Headers", class Headers {
    constructor(init) {
      this._h = {};
      var self = this;
      if (init instanceof Headers) init.forEach(function (v, k) { self.append(k, v); });
      else if (Array.isArray(init)) init.forEach(function (pair) { self.append(pair[0], pair[1]); });
      else if (init) Object.keys(init).forEach(function (k) { self.append(k, init[k]); });
    }
    append(k, v) { k = String(k).toLowerCase(); this._h[k] = k in this._h ? this._h[k] + ", " + v : String(v); }
    set(k, v) { this._h[String(k).toLowerCase()] = String(v); }
    get(k) { k = String(k).toLowerCase(); return k in this._h ? this._h[k] : null; }
    has(k) { return String(k).toLowerCase() in this._h; }
    delete(k) { delete this._h[String(k).toLowerCase()]; }
    forEach(f, self) { var h = this._h, me = this; Object.keys(h).sort().forEach(function (k) { f.call(self, h[k], k, me); }); }
    keys() { return Object.keys(this._h).sort()[Symbol.iterator](); }
    values() { var h = this._h; return Object.keys(h).sort().map(function (k) { return h[k]; })[Symbol.iterator](); }
    entries() { var h = this._h; return Object.keys(h).sort().map(function (k) { return [k, h[k]]; })[Symbol.iterator](); }
    [Symbol.iterator]() { return this.entries(); }
  });

  // a form's fields as a script builds them
  global("FormData", class FormData {
    constructor() { this._f = []; }
    append(k, v) { this._f.push([String(k), String(v)]); }
    set(k, v) { this.delete(k); this.append(k, v); }
    get(k) { var f = this._f.find(function (p) { return p[0] === String(k); }); return f ? f[1] : null; }
    getAll(k) { return this._f.filter(function (p) { return p[0] === String(k); }).map(function (p) { return p[1]; }); }
    has(k) { return this._f.some(function (p) { return p[0] === String(k); }); }
    delete(k) { this._f = this._f.filter(function (p) { return p[0] !== String(k); }); }
    forEach(f, self) { var me = this; this._f.forEach(function (p) { f.call(self, p[1], p[0], me); }); }
    entries() { return this._f.slice()[Symbol.iterator](); }
    keys() { return this._f.map(function (p) { return p[0]; })[Symbol.iterator](); }
    values() { return this._f.map(function (p) { return p[1]; })[Symbol.iterator](); }
    [Symbol.iterator]() { return this.entries(); }
  });


  // ---- what a page asks of its document, its elements and its window,
  // where an answer can be given without the browser's insides ----

  function method(proto, name, f) { if (proto && !(name in proto)) Object.defineProperty(proto, name, { value: f, writable: true, configurable: true }); }
  function getter(proto, name, f, set) { if (proto && !(name in proto)) Object.defineProperty(proto, name, { get: f, set: set || function (v) { if (typeof __host_set === "function") __host_set(this, name, v); }, configurable: true }); }
  // a property that is an attribute: el.role is role="..."
  function reflects(proto, name, attribute) {
    getter(proto, name, function () { return this.getAttribute(attribute); }, function (v) { this.setAttribute(attribute, v); });
  }
  var nothing = function () {};

  var D = typeof Document === "undefined" ? null : Document.prototype;
  getter(D, "domain", function () { return location.hostname; });
  getter(D, "baseURI", function () { return location.href; });
  getter(D, "contentType", function () { return "text/html"; });
  getter(D, "dir", function () { return ""; });
  getter(D, "scrollingElement", function () { return this.documentElement; });
  // document.all (Internet Explorer 4's, 1997: every element of the
  // page): kept by the standard as a thing no page should use, and
  // still compared with -- "x === document.all" must not be true of
  // an x that is undefined, which it is if there is no such thing
  getter(D, "all", function () { return this.querySelectorAll("*"); });
  method(D, "importNode", function (node, deep) { return node.cloneNode(deep); });
  method(D, "adoptNode", function (node) { return node; });
  method(D, "getSelection", function () { return getSelection(); });
  method(D, "hasFocus", function () { return true; });
  method(D, "elementFromPoint", stub("document.elementFromPoint", null));
  method(D, "elementsFromPoint", stub("document.elementsFromPoint", []));
  method(D, "execCommand", stub("document.execCommand", false));
  // document.write, from a script that runs as its page is read: the
  // text is HTML put where the script is, each write after the one
  // before (how a page chose its style sheet, or wrote its date, since
  // Netscape 2). The page is read whole before its scripts run here,
  // so what is written goes after the <script> itself; a script
  // written is made anew, to be run. Once the page is loaded a write
  // would replace it: not done.
  function written(html) {
    var s = document.currentScript;
    if (!s || !s.parentNode || document.readyState !== "loading") return;
    if (!s.__wrote) { s.__wrote = true; s.__next = s.nextSibling; }
    var holder = document.createElement("div");
    holder.innerHTML = html;
    while (holder.firstChild) {
      var n = holder.firstChild;
      holder.removeChild(n);
      if (n.localName === "script") {
        var again = document.createElement("script");
        Array.prototype.forEach.call(n.attributes, function (a) { again.setAttribute(a.name, a.value); });
        again.textContent = n.textContent;
        n = again;
      }
      s.parentNode.insertBefore(n, s.__next || null);
    }
  }
  method(D, "write", function () { written(Array.prototype.join.call(arguments, "")); });
  method(D, "writeln", function () { written(Array.prototype.join.call(arguments, "") + "\n"); });
  method(D, "close", nothing);
  method(D, "createRange", function () {
    var doc = this;
    if (typeof __missed === "function") __missed("document.createRange (a range that selects nothing)");
    return {
      collapsed: true, startContainer: doc, endContainer: doc, startOffset: 0, endOffset: 0, commonAncestorContainer: doc,
      setStart: nothing, setEnd: nothing, setStartBefore: nothing, setEndAfter: nothing, selectNode: nothing, selectNodeContents: nothing,
      collapse: nothing, detach: nothing, deleteContents: nothing, insertNode: nothing, cloneRange: function () { return this; },
      getBoundingClientRect: function () { return { x: 0, y: 0, top: 0, left: 0, right: 0, bottom: 0, width: 0, height: 0 }; },
      getClientRects: function () { return []; },
      // a text of HTML made nodes: what a library that builds from strings asks
      createContextualFragment: function (html) {
        var holder = doc.createElement("div"), fragment = doc.createDocumentFragment();
        holder.innerHTML = html;
        while (holder.firstChild) fragment.appendChild(holder.firstChild);
        return fragment;
      }
    };
  });

  var E = typeof Element === "undefined" ? null : Element.prototype;
  // A control's form: the one it is in, or the one its form= names.
  getter(E, "form", function () {
    if (["input", "select", "textarea", "button", "label", "fieldset", "output", "option", "object"].indexOf(this.localName) < 0) return undefined;
    var id = this.getAttribute("form");
    return (id && document.getElementById(id)) || this.closest("form");
  });
  // An event's handler not set is null, not undefined ("oninput" in
  // el, el.onclick === null: how a library asks whether an event is
  // known here); one set is the host's.
  ["abort", "blur", "change", "click", "close", "contextmenu", "dblclick", "error", "focus", "input", "invalid", "keydown", "keypress", "keyup",
   "load", "mousedown", "mouseenter", "mouseleave", "mousemove", "mouseout", "mouseover", "mouseup", "reset", "resize", "scroll", "select",
   "submit", "toggle", "wheel", "pointerdown", "pointermove", "pointerup", "touchstart", "touchmove", "touchend", "animationend",
   "transitionend", "beforeinput", "paste", "copy", "cut", "dragstart", "drop"].forEach(function (name) {
    getter(E, "on" + name, function () { return null; });
  });
  method(E, "isSameNode", function (other) { return this === other; });
  method(E, "isEqualNode", function (other) { return !!other && this.outerHTML === other.outerHTML; });
  // an <svg>'s point and matrix: how a program turns the pointer's
  // place in the window into its drawing's units,
  // pt.matrixTransform(svg.getScreenCTM().inverse()) -- for an svg
  // that fills the window (the Playground's), its viewBox fitted in it
  function matrix(a, d, e, f) {
    return { a: a, b: 0, c: 0, d: d, e: e, f: f, inverse: function () { return matrix(1 / a, 1 / d, -e / a, -f / d); } };
  }
  function point(x, y) {
    return { x: x, y: y, matrixTransform: function (m) { return point(m.a * this.x + m.e, m.d * this.y + m.f); } };
  }
  method(E, "createSVGPoint", function () { return point(0, 0); });
  method(E, "getScreenCTM", function () {
    var box = String(this.getAttribute("viewBox") || this.getAttribute("viewbox") || "").split(/[ ,]+/).map(Number);
    if (box.length !== 4 || !(box[2] > 0) || !(box[3] > 0)) return matrix(1, 1, 0, 0);
    var k = Math.min(innerWidth / box[2], innerHeight / box[3]);
    return matrix(k, k, (innerWidth - box[2] * k) / 2 - box[0] * k, (innerHeight - box[3] * k) / 2 - box[1] * k);
  });
  // Web Audio, the least of it: a context, its clock, a buffer of
  // samples and its source started at a time (AudioContext.mli); the
  // clock and the playing are the browser's (__audio)
  if (typeof __audio === "object") {
    global("AudioContext", class AudioContext {
      constructor() { this.state = "running"; this.sampleRate = 44100; this.destination = { context: this }; this.baseLatency = 0; this.outputLatency = 0; }
      get currentTime() { return __audio.now(); }
      resume() { this.state = "running"; return Promise.resolve(); }
      suspend() { return Promise.resolve(); }
      close() { this.state = "closed"; return Promise.resolve(); }
      createBuffer(channels, length, rate) {
        var data = [];
        for (var c = 0; c < channels; c++) data.push(new Float32Array(length));
        return { numberOfChannels: channels, length: length, sampleRate: rate, duration: length / rate, getChannelData: function (c) { return data[c]; } };
      }
      createBufferSource() {
        return {
          buffer: null, onended: null, connect: function (to) { return to; }, disconnect: nothing, stop: nothing,
          start: function (when) {
            var b = this.buffer;
            if (b) __audio.play(b.getChannelData(0), b.getChannelData(b.numberOfChannels > 1 ? 1 : 0), b.sampleRate, when || 0);
          }
        };
      }
    });
    global("webkitAudioContext", g.AudioContext);
  }
  // an SVG element's attribute that can be animated (its href, its
  // class): asked by instanceof, never made here
  global("SVGAnimatedString", function SVGAnimatedString() {});
  // IntersectionObserver (Chrome 51, 2016): told when an element comes
  // into view -- how a page puts a picture's address in only when it
  // is about to be seen ("lazy loading"), and asks for a list's next
  // page when its end is, where scripts once listened to every
  // scroll. Here an element is in view when its box is within a
  // window's height of the window: looked at a moment after it is
  // observed, then twice a second while some wait (the wheel tells no
  // script), and told once. When all was said to be in view, a list
  // without end grew without end (YouTube's results).
  var waiting = [], looking = false;
  var look = function () {
    looking = false;
    var still = [], told = [];
    waiting.forEach(function (w) {
      if (w.observer._observed.indexOf(w.element) < 0) return;
      var box = w.element.getBoundingClientRect();
      if (box.top > 2 * innerHeight || box.bottom < -innerHeight) { still.push(w); return; }
      // a picture with no address yet has no height, and a page asks
      // that what is seen of it have some (YouTube's thumbnails)
      var seen = box.height > 0 ? box : { x: box.x, y: box.y, left: box.left, top: box.top, right: box.right, bottom: box.top + 1, width: box.width, height: 1 };
      told.push([w.observer, Object.assign(new IntersectionObserverEntry(), { target: w.element, isIntersecting: true, intersectionRatio: 1, boundingClientRect: box, intersectionRect: seen, rootBounds: null, time: performance.now() })]);
    });
    waiting = still;
    told.forEach(function (t) { try { t[0]._callback([t[1]], t[0]); } catch (e) { console.error(e); } });
    watch(500);
  };
  var watch = function (delay) { if (waiting.length && !looking) { looking = true; setTimeout(look, delay); } };
  g.IntersectionObserver = class IntersectionObserver {
    constructor(callback, options) {
      this._callback = callback; this._observed = [];
      this.root = (options && options.root) || null; this.rootMargin = (options && options.rootMargin) || "0px"; this.thresholds = [0];
    }
    observe(element) {
      if (this._observed.indexOf(element) >= 0) return;
      this._observed.push(element);
      waiting.push({ observer: this, element: element });
      watch(0);
    }
    unobserve(element) { this._observed = this._observed.filter(function (e) { return e !== element; }); }
    disconnect() { this._observed = []; }
    takeRecords() { return []; }
  };
  // MutationObserver (2012): told, in a microtask, of what changed
  // in the nodes it observes -- the way to run something "right after
  // this script" before promises (Polymer's debounced jobs, YouTube's
  // lists). Here a name, never told: a page with promises does not ask
  // it (Vue 2 takes them first).
  g.MutationObserver = class MutationObserver {
    constructor(callback) { this._callback = callback; }
    observe() {}
    disconnect() {}
    takeRecords() { return []; }
  };
  // what the observer tells, as a class: a page looks for its
  // prototype's members before it trusts the observer, and brings its
  // own (the W3C's polyfill, which YouTube has) when they are not there
  g.IntersectionObserverEntry = class IntersectionObserverEntry {};
  IntersectionObserverEntry.prototype.intersectionRatio = 0;
  IntersectionObserverEntry.prototype.isIntersecting = false;
  // Range, as a name: new Range() is what document.createRange() gives
  global("Range", function Range() { return document.createRange(); });
  // CSS: what a script asks of the style engine. supports() says no
  // (a library then takes its older way); escape() makes a name safe
  // in a selector
  global("CSS", {
    supports: function () { return false; },
    escape: function (s) { return String(s).replace(/[^a-zA-Z0-9_\-\u00a0-\uffff]/g, function (c) { return "\\" + c; }); }
  });
  // a <template>'s content: its children, in a fragment of their own
  // (what cloneNode and importNode copy into the page)
  getter(E, "content", function () {
    if (this.localName !== "template") return undefined;
    if (!this.__content) {
      var f = document.createDocumentFragment();
      while (this.firstChild) f.appendChild(this.firstChild);
      // of a document of its own in a browser, where no element is a
      // custom one: here marked, for the registry to leave it alone
      f.__inert = true;
      this.__content = f;
    }
    return this.__content;
  });

  // new Option(text, value) (Netscape 2's, 1996): an <option> made, to
  // put in a <select> -- with add, below
  global("Option", function Option(text, value, chosen, selected) {
    var o = document.createElement("option");
    o.textContent = text === undefined ? "" : String(text);
    if (value !== undefined) o.setAttribute("value", String(value));
    if (chosen || selected) o.setAttribute("selected", "");
    return o;
  });
  // a <select>'s option put in (DOM Level 1): at the end, or before
  // the one given
  method(E, "add", function (option, before) { if (this.tagName === "SELECT") this.insertBefore(option, typeof before === "number" ? this.querySelectorAll("option")[before] || null : before || null); });
  // A table as its rows and cells (DOM Level 1's HTMLTableElement):
  // table.rows, a section's rows, a row's cells, and where each is.
  // Gmail's list is a table, and a click is read as "which cell of
  // this row": row.cells[i].
  function kids(el, names) { return Array.prototype.filter.call(el.children, function (c) { return names.indexOf(c.localName) >= 0; }); }
  function table_rows(t) {
    var rows = [];
    kids(t, ["thead"]).forEach(function (g) { rows = rows.concat(kids(g, ["tr"])); });
    Array.prototype.forEach.call(t.children, function (c) { if (c.localName === "tr") rows.push(c); else if (c.localName === "tbody") rows = rows.concat(kids(c, ["tr"])); });
    kids(t, ["tfoot"]).forEach(function (g) { rows = rows.concat(kids(g, ["tr"])); });
    return rows;
  }
  function listed(a) { a.item = function (i) { return this[i] || null; }; return a; }
  getter(E, "cells", function () { return this.localName === "tr" ? listed(kids(this, ["td", "th"])) : undefined; });
  getter(E, "rows", function () {
    var n = this.localName;
    return n === "table" ? listed(table_rows(this)) : n === "tbody" || n === "thead" || n === "tfoot" ? listed(kids(this, ["tr"])) : undefined;
  });
  getter(E, "tBodies", function () { return this.localName === "table" ? listed(kids(this, ["tbody"])) : undefined; });
  getter(E, "cellIndex", function () {
    if (this.localName !== "td" && this.localName !== "th") return undefined;
    return this.parentNode ? kids(this.parentNode, ["td", "th"]).indexOf(this) : -1;
  });
  getter(E, "sectionRowIndex", function () { return this.localName === "tr" && this.parentNode ? kids(this.parentNode, ["tr"]).indexOf(this) : this.localName === "tr" ? -1 : undefined; });
  getter(E, "rowIndex", function () {
    if (this.localName !== "tr") return undefined;
    var t = this.closest("table");
    return t ? table_rows(t).indexOf(this) : -1;
  });
  // ... and changed: a row put in a table or a section at a place
  // (-1, or none given: the end), a cell in a row, one taken out.
  // Gmail builds a message's header this way.
  function put(parent, made, list, i) {
    if (i === undefined || i === -1 || i === list.length) parent.appendChild(made);
    else if (i >= 0 && i < list.length) list[i].parentNode.insertBefore(made, list[i]);
    else throw new DOMException("The index is not in the allowed range.", "IndexSizeError");
    return made;
  }
  method(E, "insertRow", function (i) {
    var row = document.createElement("tr"), rows = this.rows;
    // a table with no row yet: in its body, made if there is none
    if (this.localName === "table" && rows.length === 0) return (this.tBodies[0] || this.appendChild(document.createElement("tbody"))).appendChild(row);
    if (this.localName === "table" && (i === undefined || i === -1 || i === rows.length)) return rows[rows.length - 1].parentNode.appendChild(row);
    return put(this, row, rows, i);
  });
  method(E, "insertCell", function (i) { return put(this, document.createElement("td"), this.cells, i); });
  function taken(list, i) { var e = list[i === -1 ? list.length - 1 : i]; if (e) e.parentNode.removeChild(e); }
  method(E, "deleteRow", function (i) { taken(this.rows, i); });
  method(E, "deleteCell", function (i) { taken(this.cells, i); });
  function section(name) {
    return function () {
      var had = kids(this, [name])[0];
      return had || (name === "thead" || name === "caption" ? this.insertBefore(document.createElement(name), this.firstChild) : this.appendChild(document.createElement(name)));
    };
  }
  method(E, "createTHead", section("thead"));
  method(E, "createTFoot", section("tfoot"));
  method(E, "createCaption", section("caption"));
  method(E, "createTBody", function () { return this.appendChild(document.createElement("tbody")); });


  // Custom elements (customElements.define("user-card", class extends
  // HTMLElement {})): not here, a component's page is not this
  // browser's; what a page asks is answered, so that its script goes on
  global("customElements", { define: stub("customElements.define"), get: function () { return undefined; },
    whenDefined: function () { return new Promise(function () {}); }, upgrade: nothing });
  global("DOMException", class DOMException extends Error { constructor(message, name) { super(message); this.name = name || "Error"; } });
  reflects(E, "role", "role");
  reflects(E, "nonce", "nonce");
  reflects(E, "slot", "slot");
  reflects(E, "ariaLabel", "aria-label");
  reflects(E, "ariaHidden", "aria-hidden");
  reflects(E, "ariaExpanded", "aria-expanded");
  getter(E, "draggable", function () { return this.getAttribute("draggable") === "true"; }, function (v) { this.setAttribute("draggable", String(!!v)); });
  getter(E, "inert", function () { return this.hasAttribute("inert"); }, function (v) { this.toggleAttribute("inert", !!v); });
  getter(E, "contentEditable", function () { return this.getAttribute("contenteditable") || "inherit"; }, function (v) { this.setAttribute("contenteditable", v); });
  getter(E, "isContentEditable", function () { return this.getAttribute("contenteditable") === "true"; });

  if (typeof navigator === "object") {
    var browser = {
      languages: ["en-US", "en"], onLine: true, cookieEnabled: true, platform: "Linux x86_64", vendor: "", product: "Gecko",
      appName: "Netscape", appVersion: "5.0", hardwareConcurrency: 1, maxTouchPoints: 0, doNotTrack: null, webdriver: false,
      plugins: [], mimeTypes: [], sendBeacon: function () { return true; }
    };
    Object.keys(browser).forEach(function (k) { if (!(k in navigator)) navigator[k] = browser[k]; });
  }
  if (typeof performance === "object") {
    var empty = function () { return []; };
    ["getEntries", "getEntriesByType", "getEntriesByName"].forEach(function (k) { if (!(k in performance)) performance[k] = empty; });
    ["clearMarks", "clearMeasures", "clearResourceTimings"].forEach(function (k) { if (!(k in performance)) performance[k] = nothing; });
    if (!("timing" in performance)) performance.timing = { navigationStart: Date.now() };
    if (!("navigation" in performance)) performance.navigation = { type: 0, redirectCount: 0 };
  }
  if (typeof history === "object" && !("scrollRestoration" in history)) history.scrollRestoration = "auto";
  global("visualViewport", { width: g.innerWidth, height: g.innerHeight, scale: 1, offsetLeft: 0, offsetTop: 0, pageLeft: 0, pageTop: 0, addEventListener: nothing, removeEventListener: nothing });
})();

|prelude}
