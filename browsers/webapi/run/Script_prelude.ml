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

  // EventTarget made by a page itself (new EventTarget(), a class that
  // extends it): listeners kept on the object, told in order. An
  // element's own are the browser's (Script_host), found before these
  // -- and reached through these too, when a library calls the
  // prototype's method on an element
  // (EventTarget.prototype.dispatchEvent.call(el, e): Polymer keeps
  // the "native" methods so; the event went to a list of no listener,
  // and a dialog waiting to be told its animation was over waited).
  (function () {
    var P = g.EventTarget && g.EventTarget.prototype;
    if (!P) return;
    // the browser's own method of that name, if this is one of its objects
    function own(o, name) { var f = typeof __host_get === "function" ? __host_get(o, name) : undefined; return typeof f === "function" ? f : null; }
    function listeners(o, type) { var all = o.__listeners || (o.__listeners = {}); return all[type] || (all[type] = []); }
    Object.defineProperty(P, "addEventListener", { value: function (type, f, options) {
      var h = own(this, "addEventListener"); if (h) return h.apply(this, arguments);
      var l = listeners(this, type), self = this;
      if (!f || l.some(function (e) { return e.f === f; })) return;
      l.push({ f: f, once: !!(options && options.once) });
      var signal = options && typeof options === "object" && options.signal;
      if (signal) signal.addEventListener("abort", function () { self.removeEventListener(type, f); });
    }, writable: true, configurable: true });
    Object.defineProperty(P, "removeEventListener", { value: function (type, f) {
      var h = own(this, "removeEventListener"); if (h) return h.apply(this, arguments);
      var all = this.__listeners; if (all && all[type]) all[type] = all[type].filter(function (e) { return e.f !== f; });
    }, writable: true, configurable: true });
    Object.defineProperty(P, "dispatchEvent", { value: function (event) {
      var h = own(this, "dispatchEvent"); if (h) return h.apply(this, arguments);
      var self = this; try { event.target = this; event.currentTarget = this; } catch (e) {}
      listeners(this, event.type).slice().forEach(function (e) {
        if (e.once) self.removeEventListener(event.type, e.f);
        if (typeof e.f === "function") e.f.call(self, event); else if (e.f && e.f.handleEvent) e.f.handleEvent(event);
      });
      return !event.defaultPrevented;
    }, writable: true, configurable: true });
  })();

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

  // A message from another window (a frame's from its page, a page's
  // from its frame: Browser_script.adopt): the browser's to give, as
  // postMessage's own. Its source is a window to answer to.
  g.__deliver = function (data, from) {
    var e = new Event("message");
    e.data = data; e.origin = location.origin; e.ports = []; e.lastEventId = "";
    e.source = from && from.contentWindow ? from.contentWindow : g.parent;
    window.dispatchEvent(e);
  };
  // This document is a frame's: its parent, and the top, are a window
  // it can only post to.
  g.__framed = function () {
    var up = { postMessage: function (data) { __post_parent(data); }, addEventListener: function () {}, removeEventListener: function () {},
               focus: function () {}, blur: function () {}, location: { href: "", origin: location.origin }, frames: [], length: 0 };
    up.parent = up.top = up.self = up.window = up;
    g.parent = g.top = up;
    g.frameElement = null;
  };

  // MessageChannel (HTML5's channel messaging): two ports, what is
  // posted on one given to the other's onmessage in a task of its own.
  // Frameworks use it as a timer that is not held back (a scheduler's
  // "as soon as the browser has drawn").
  global("MessageChannel", function MessageChannel() {
    function port() {
      var p = { onmessage: null, _other: null, _listeners: [],
        postMessage: function (data) {
          var to = p._other;
          setTimeout(function () {
            var e = { data: data, target: to, ports: [] };
            if (typeof to.onmessage === "function") to.onmessage(e);
            to._listeners.forEach(function (f) { f(e); });
          }, 0);
        },
        addEventListener: function (type, f) { if (type === "message") p._listeners.push(f); },
        removeEventListener: function (type, f) { p._listeners = p._listeners.filter(function (g) { return g !== f; }); },
        start: function () {}, close: function () {} };
      return p;
    }
    this.port1 = port(); this.port2 = port();
    this.port1._other = this.port2; this.port2._other = this.port1;
  });

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

  // text to bytes and back (the Encoding standard): a string's
  // characters as UTF-8's bytes, one to four each, and bytes read as
  // characters -- what is not UTF-8 read as U+FFFD, the mark of it
  global("TextEncoder", class TextEncoder {
    get encoding() { return "utf-8"; }
    encode(s) {
      s = s === undefined ? "" : String(s);
      var out = [];
      for (var i = 0; i < s.length; i++) {
        var c = s.codePointAt(i);
        if (c > 0xffff) i++;
        if (c >= 0xd800 && c <= 0xdfff) c = 0xfffd;
        if (c < 0x80) out.push(c);
        else if (c < 0x800) out.push(0xc0 | (c >> 6), 0x80 | (c & 0x3f));
        else if (c < 0x10000) out.push(0xe0 | (c >> 12), 0x80 | ((c >> 6) & 0x3f), 0x80 | (c & 0x3f));
        else out.push(0xf0 | (c >> 18), 0x80 | ((c >> 12) & 0x3f), 0x80 | ((c >> 6) & 0x3f), 0x80 | (c & 0x3f));
      }
      return new Uint8Array(out);
    }
  });
  global("TextDecoder", class TextDecoder {
    constructor(label) { this.encoding = (label || "utf-8").toLowerCase(); }
    decode(bytes) {
      if (!bytes) return "";
      if (bytes instanceof ArrayBuffer) bytes = new Uint8Array(bytes);
      else if (bytes.buffer instanceof ArrayBuffer && !(bytes instanceof Uint8Array)) bytes = new Uint8Array(bytes.buffer, bytes.byteOffset, bytes.byteLength);
      var s = "", units = [], n = bytes.length, latin = this.encoding !== "utf-8" && this.encoding !== "utf8";
      for (var i = 0; i < n; ) {
        var b = bytes[i++], c = b, more = latin || b < 0x80 ? 0 : b >= 0xf0 && b <= 0xf4 ? 3 : b >= 0xe0 ? 2 : b >= 0xc2 ? 1 : -1;
        if (more < 0) c = 0xfffd;
        else if (more > 0) {
          c = b & (0x3f >> more);
          for (var k = 0; k < more; k++) {
            var next = bytes[i];
            if (next === undefined || (next & 0xc0) !== 0x80) { c = 0xfffd; break; }
            c = (c << 6) | (next & 0x3f); i++;
          }
        }
        if (c < 0x10000) units.push(c);
        else { c -= 0x10000; units.push(0xd800 + (c >> 10), 0xdc00 + (c & 0x3ff)); }
        if (units.length > 8192) { s += String.fromCharCode.apply(null, units); units = []; }
      }
      return s + String.fromCharCode.apply(null, units);
    }
  });

  // a way to say stop: the controller's abort() tells the signal's
  // listeners, and whoever was given the signal gives up
  class AbortSignal {
    constructor() { this.aborted = false; this.reason = undefined; this.onabort = null; this._listeners = []; }
    addEventListener(type, f) { if (type === "abort") this._listeners.push(f); }
    removeEventListener(type, f) { this._listeners = this._listeners.filter(function (x) { return x !== f; }); }
    throwIfAborted() { if (this.aborted) throw this.reason; }
    _abort(reason) {
      if (this.aborted) return;
      this.aborted = true;
      this.reason = reason === undefined ? new Error("AbortError: signal is aborted without reason") : reason;
      var event = { type: "abort", target: this };
      if (typeof this.onabort === "function") this.onabort(event);
      this._listeners.slice().forEach(function (f) { f(event); });
    }
    static abort(reason) { var s = new AbortSignal(); s._abort(reason); return s; }
    static timeout(ms) { var s = new AbortSignal(); setTimeout(function () { s._abort(new Error("TimeoutError: signal timed out")); }, ms); return s; }
    static any(signals) {
      var s = new AbortSignal();
      signals.forEach(function (other) { if (other.aborted) s._abort(other.reason); else other.addEventListener("abort", function () { s._abort(other.reason); }); });
      return s;
    }
  }
  global("AbortSignal", AbortSignal);
  global("AbortController", class AbortController {
    constructor() { this.signal = new AbortSignal(); }
    abort(reason) { this.signal._abort(reason); }
  });

  // a copy all the way down: arrays, plain objects, dates, maps and
  // sets; a function cannot be copied, as the standard has it
  global("structuredClone", function (value) {
    var seen = new Map();
    function copy(v) {
      if (typeof v === "function") throw new Error("DataCloneError: a function could not be cloned");
      if (v === null || typeof v !== "object") return v;
      if (seen.has(v)) return seen.get(v);
      var out;
      if (Array.isArray(v)) { out = []; seen.set(v, out); v.forEach(function (x, i) { out[i] = copy(x); }); return out; }
      if (v instanceof Date) return new Date(v.getTime());
      if (v instanceof Map) { out = new Map(); seen.set(v, out); v.forEach(function (x, k) { out.set(copy(k), copy(x)); }); return out; }
      if (v instanceof Set) { out = new Set(); seen.set(v, out); v.forEach(function (x) { out.add(copy(x)); }); return out; }
      out = {}; seen.set(v, out);
      Object.keys(v).forEach(function (k) { out[k] = copy(v[k]); });
      return out;
    }
    return copy(value);
  });

  global("reportError", function (e) { console.error("Uncaught " + (e && e.stack ? e.name + ": " + e.message : e)); });
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

  // Request (the Fetch Standard): what fetch is asked, as a value --
  // an address, a method, headers, a body -- that can be made from
  // another with something changed
  global("Request", class Request {
    constructor(input, init) {
      var from = input instanceof Request ? input : null;
      init = init || {};
      this.url = from ? from.url : new URL(String(input), location.href).href;
      this.method = String(init.method || (from ? from.method : "GET")).toUpperCase();
      this.headers = new Headers(init.headers || (from ? from.headers : undefined));
      this.body = init.body !== undefined ? init.body : from ? from.body : null;
      this.credentials = init.credentials || (from ? from.credentials : "same-origin");
      this.mode = init.mode || (from ? from.mode : "cors");
      this.signal = init.signal || (from ? from.signal : new AbortController().signal);
    }
    clone() { return new Request(this); }
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

  // one language and one way to write a number or a date: what a page
  // asks of Intl is answered, in English
  if (typeof g.Intl === "undefined") {
    var options = function () { return { locale: "en-US", timeZone: "UTC", calendar: "gregory", numberingSystem: "latn" }; };
    var supported = function () { return ["en-US"]; };
    g.Intl = {
      DateTimeFormat: class DateTimeFormat {
        format(d) { return (d === undefined ? new Date() : new Date(d)).toString(); }
        formatToParts(d) { return [{ type: "literal", value: this.format(d) }]; }
        resolvedOptions() { return options(); }
        static supportedLocalesOf() { return supported(); }
      },
      NumberFormat: class NumberFormat {
        format(n) { return String(n); }
        formatToParts(n) { return [{ type: "integer", value: String(n) }]; }
        resolvedOptions() { return options(); }
        static supportedLocalesOf() { return supported(); }
      },
      PluralRules: class PluralRules {
        select(n) { return n === 1 ? "one" : "other"; }
        resolvedOptions() { return options(); }
        static supportedLocalesOf() { return supported(); }
      },
      RelativeTimeFormat: class RelativeTimeFormat {
        format(n, unit) { var u = Math.abs(n) === 1 ? unit : unit + "s"; return n < 0 ? -n + " " + u + " ago" : "in " + n + " " + u; }
        resolvedOptions() { return options(); }
        static supportedLocalesOf() { return supported(); }
      },
      ListFormat: class ListFormat {
        format(items) { items = Array.from(items); return items.length < 3 ? items.join(" and ") : items.slice(0, -1).join(", ") + ", and " + items[items.length - 1]; }
        static supportedLocalesOf() { return supported(); }
      },
      Collator: class Collator {
        compare(a, b) { return a < b ? -1 : a > b ? 1 : 0; }
        resolvedOptions() { return options(); }
        static supportedLocalesOf() { return supported(); }
      },
      getCanonicalLocales: function (l) { return l === undefined ? [] : [].concat(l); }
    };
  }

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
  getter(D, "fullscreenEnabled", function () { return false; });
  // CSSStyleSheet made by a script (Constructable Stylesheets, Chrome
  // 73, 2019): a sheet with no element, given its text by replaceSync
  // and put on the page by document.adoptedStyleSheets = [sheet] --
  // how a component library shares one sheet between its components.
  // Here each adopted sheet is a <style> of the head, kept up to date.
  (function () {
    function CSSStyleSheet() { this._text = ""; this._rules = []; this._style = null; this.cssRules = this._rules; this.disabled = false; }
    var P = CSSStyleSheet.prototype;
    // a rule is an object with its text (cssRules[i].cssText)
    P._sync = function () { if (this._style) this._style.textContent = this._text + "\n" + this._rules.map(function (r) { return r.cssText; }).join("\n"); };
    P.replaceSync = function (text) { this._text = String(text); this._rules.length = 0; this._sync(); };
    P.replace = function (text) { this.replaceSync(text); return Promise.resolve(this); };
    P.insertRule = function (rule, index) {
      index = index === undefined ? 0 : index;
      rule = String(rule);
      this._rules.splice(index, 0, { cssText: rule, selectorText: rule.split("{")[0].trim(), type: 1, parentStyleSheet: this });
      this._sync();
      return index;
    };
    P.deleteRule = function (index) { this._rules.splice(index, 1); this._sync(); };
    g.CSSStyleSheet = CSSStyleSheet;
    var adopted = [];
    getter(D, "adoptedStyleSheets", function () { return adopted; });
    // document.adoptedStyleSheets = sheets (the document tells us: Script_document)
    g.__adopt = function (sheets) {
      var doc = document;
      adopted.forEach(function (s) { if (Array.prototype.indexOf.call(sheets, s) < 0 && s._style) { s._style.remove(); s._style = null; } });
      adopted = Array.prototype.slice.call(sheets);
      adopted.forEach(function (s) {
        if (!s._style && doc.head) { s._style = doc.createElement("style"); s._style.setAttribute("data-adopted", ""); doc.head.appendChild(s._style); }
        if (s._sync) s._sync();
      });
    };
  })();
  getter(D, "fonts", function () { return { ready: Promise.resolve(), status: "loaded", addEventListener: nothing, removeEventListener: nothing, load: function () { return Promise.resolve([]); }, check: function () { return true; } }; });
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
  method(D, "open", stub("document.open"));
  method(D, "close", nothing);
  // the nodes under a root, one after the other in the document's
  // order, those a filter keeps: a walk a script steps through
  method(D, "createTreeWalker", function (root, whatToShow, filter) {
    var show = whatToShow === undefined ? 0xffffffff : whatToShow;
    var accept = typeof filter === "function" ? filter : filter && filter.acceptNode ? function (n) { return filter.acceptNode(n); } : function () { return 1; };
    function next(n) {
      if (n.firstChild) return n.firstChild;
      while (n && n !== root) { if (n.nextSibling) return n.nextSibling; n = n.parentNode; }
      return null;
    }
    // 1 a node is the walk's, 2 nor it nor what is under it, 3 not it
    // but what is under it
    function kept(n) { return (show >> (n.nodeType - 1)) & 1 ? accept(n) : 3; }
    // the walk's children of a node: its own that are kept, and those
    // of the ones skipped
    function kids(n) {
      var out = [];
      for (var c = n.firstChild; c; c = c.nextSibling) {
        var k = kept(c);
        if (k === 1) out.push(c); else if (k !== 2) out = out.concat(kids(c));
      }
      return out;
    }
    function parent(n) {
      for (n = n === root ? null : n.parentNode; n; n = n === root ? null : n.parentNode) if (n === root || kept(n) === 1) return n;
      return null;
    }
    function to(walker, n) { if (n) walker.currentNode = n; return n || null; }
    function sibling(walker, by) {
      var p = parent(walker.currentNode);
      if (!p) return null;
      var all = kids(p);
      return to(walker, all[all.indexOf(walker.currentNode) + by]);
    }
    return {
      root: root, currentNode: root, whatToShow: show, filter: filter || null,
      nextNode: function () {
        for (var n = next(this.currentNode); n; n = next(n))
          if (kept(n) === 1) { this.currentNode = n; return n; }
        return null;
      },
      // the one before in the document's order: found from the root
      previousNode: function () {
        var last = null;
        for (var n = root; n && n !== this.currentNode; n = next(n)) if (n === root || kept(n) === 1) last = n;
        return this.currentNode === root ? null : to(this, last);
      },
      firstChild: function () { return to(this, kids(this.currentNode)[0]); },
      lastChild: function () { var all = kids(this.currentNode); return to(this, all[all.length - 1]); },
      nextSibling: function () { return sibling(this, 1); },
      previousSibling: function () { return this.currentNode === root ? null : sibling(this, -1); },
      parentNode: function () { return to(this, parent(this.currentNode)); }
    };
  });
  method(D, "createNodeIterator", D && D.createTreeWalker);
  // XMLSerializer (2000, Mozilla's): a node as text.
  global("XMLSerializer", function XMLSerializer() {
    this.serializeToString = function (n) { return n.nodeType === 9 ? n.documentElement.outerHTML : n.nodeType === 1 ? n.outerHTML : n.nodeType === 11 ? Array.prototype.map.call(n.childNodes, function (c) { return c.nodeType === 1 ? c.outerHTML : c.textContent; }).join("") : n.textContent; };
  });
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
  getter(E, "popoverTargetElement", function () { return null; });
  getter(D, "prerendering", function () { return false; });
  method(E, "isSameNode", function (other) { return this === other; });
  method(E, "isEqualNode", function (other) { return !!other && this.outerHTML === other.outerHTML; });
  method(E, "checkVisibility", function () { return true; });
  method(E, "getAnimations", function () { return []; });
  // el.animate(keyframes, timing) (Web Animations, Chrome 36, 2014):
  // an animation here is over as soon as it starts -- the element is
  // where its own style has it, which is where an animation that
  // keeps nothing ends -- and says so a moment later: its finished
  // promise, onfinish, its "finish" listeners. A dialog that fades
  // away waits for that to take itself out (Polymer's; YouTube's
  // stayed on the page). It has every member the W3C's polyfill looks
  // for, which then leaves it alone.
  method(E, "animate", function (keyframes, timing) {
    var listeners = [], done = false, settle;
    var a = {
      id: "", effect: null, timeline: null, currentTime: 0, startTime: 0, playbackRate: 1, playState: "running", pending: false, onfinish: null, oncancel: null,
      ready: Promise.resolve(),
      play: nothing, pause: nothing, reverse: nothing, updatePlaybackRate: nothing, commitStyles: nothing, persist: nothing,
      addEventListener: function (type, f) { if (type === "finish") listeners.push(f); },
      removeEventListener: function (type, f) { listeners = listeners.filter(function (g) { return g !== f; }); },
      cancel: function () { done = true; a.playState = "idle"; },
      finish: function () {
        if (done) return;
        done = true; a.playState = "finished";
        var e = new Event("finish"); e.currentTime = a.currentTime;
        settle(a);
        if (typeof a.onfinish === "function") a.onfinish(e);
        listeners.slice().forEach(function (f) { f.call(a, e); });
      }
    };
    a.finished = new Promise(function (resolve) { settle = resolve; });
    setTimeout(a.finish, 0);
    return a;
  });
  method(E, "requestFullscreen", function () { return Promise.reject(new TypeError("fullscreen is not supported")); });
  method(E, "setPointerCapture", nothing);
  method(E, "releasePointerCapture", nothing);
  method(E, "hasPointerCapture", function () { return false; });
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
  // a <canvas> not drawn yet: a script that draws on one goes on, and
  // its picture is empty (docs/plans/plan_tinybox.md, "later")
  method(E, "getContext", function () {
    var canvas = this, context = { canvas: canvas };
    if (typeof __missed === "function") __missed("canvas.getContext (nothing is drawn)");
    ["putImageData", "drawImage", "fillRect", "clearRect", "strokeRect", "beginPath", "closePath", "moveTo", "lineTo", "arc", "rect", "fill", "stroke",
     "fillText", "strokeText", "save", "restore", "translate", "rotate", "scale", "setTransform", "clip"].forEach(function (k) { context[k] = nothing; });
    context.measureText = function (text) { return { width: 8 * String(text).length }; };
    context.getImageData = context.createImageData = function (x, y, w, h) { return new ImageData(w || x, h || y); };
    return context;
  });
  method(E, "toDataURL", function () { return "data:,"; });
  // a canvas of no page (a worker's, a picture made aside): the same
  // one, not drawn either
  global("OffscreenCanvas", function OffscreenCanvas(width, height) {
    var canvas = document.createElement("canvas");
    this.width = width; this.height = height;
    this.getContext = function () { var c = canvas.getContext.apply(canvas, arguments); c.canvas = this; return c; };
  });
  global("ImageData", function ImageData(data, width, height) {
    if (typeof data === "number") { this.width = data; this.height = width; this.data = new Uint8ClampedArray(4 * data * width); }
    else { this.data = data; this.width = width; this.height = height; }
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
  // what a tree walker is told to show, and what its filter answers
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
  // in the nodes it observes. Before promises it was the one way to
  // run something "right after this script": change a text node
  // nobody sees and be told of it -- which Polymer still does for its
  // every debounced job (YouTube's lists fill that way), and Vue 2
  // where it finds no promise. That is the part done here: a text
  // node's data changed (the browser calls __mutated). A child added
  // or an attribute set is not told yet.
  var observers = [];
  g.MutationObserver = class MutationObserver {
    constructor(callback) { this._callback = callback; this._targets = []; this._records = []; }
    observe(target, options) {
      this._targets.push({ target: target, options: options || {} });
      target.__observed = true;
      if (observers.indexOf(this) < 0) observers.push(this);
    }
    disconnect() { this._targets = []; this._records = []; observers = observers.filter(function (o) { return o !== this; }, this); }
    takeRecords() { var records = this._records; this._records = []; return records; }
  };
  g.__mutated = function (target, type) {
    observers.slice().forEach(function (o) {
      if (!o._targets.some(function (t) { return t.target === target && t.options[type]; })) return;
      o._records.push({ type: type, target: target, addedNodes: [], removedNodes: [], previousSibling: null, nextSibling: null, attributeName: null, oldValue: null });
      if (o._records.length == 1) queueMicrotask(function () { var records = o.takeRecords(); if (records.length) o._callback(records, o); });
    });
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
  global("NodeFilter", { SHOW_ALL: -1, SHOW_ELEMENT: 1, SHOW_TEXT: 4, SHOW_COMMENT: 128, FILTER_ACCEPT: 1, FILTER_REJECT: 2, FILTER_SKIP: 3 });
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

  // An <iframe>'s window. A frame's page is not loaded here; what a
  // script is given is the window of an empty one (about:blank's): a
  // document it can write in, listeners that are never called. Gmail
  // makes a hidden frame for the "resize" of its window alone -- the
  // old trick to be told that the size of the text changed.
  getter(E, "contentWindow", function () {
    if (this.localName !== "iframe") return undefined;
    if (!this.__frame) {
      var d = document.implementation.createHTMLDocument(""), el = this;
      d.open = d.close = d.write = function () {};
      var nothing = function () {};
      // over the page's own window: the language's globals (String, Array)
      // are asked of a frame's window by who wants them as they were made
      this.__frame = Object.assign(Object.create(window), { document: d, parent: window, top: window, frameElement: this, location: { href: "about:blank" },
        addEventListener: nothing, removeEventListener: nothing, dispatchEvent: function () { return true; },
        // to the frame's own document, if it has scripts (Browser_script.adopt)
        postMessage: function (data) { if (typeof __post_frame === "function") __post_frame(el, data); }, focus: nothing, blur: nothing, close: nothing });
      this.__frame.self = this.__frame.window = this.__frame;
    }
    return this.__frame;
  });
  getter(E, "contentDocument", function () { return this.localName === "iframe" ? this.contentWindow.document : undefined; });

  // Custom elements: a name with a dash given a class
  // (customElements.define("user-card", class extends HTMLElement {})).
  // An element of that name is *upgraded*: the class's prototype made
  // its own, the class's constructor run on it, then its callbacks --
  // attributeChangedCallback for the attributes the class observes,
  // connectedCallback when it is in the page. It is there that a
  // component attaches its shadow tree (libs/dom/Shadow_tree.mli). The
  // browser says when an element enters the page (__connected).
  // An attribute set or removed later by setAttribute and
  // removeAttribute is told too (__attribute).
  // Not done: new UserCard() (an element is made by its name), the
  // callback of an element removed.
  (function () {
    var classes = {}, waiting = {};
    function upgrade(el) {
      var C = classes[el.localName];
      if (!C || el.__upgraded) return;
      el.__upgraded = true;
      Object.setPrototypeOf(el, C.prototype);
      try {
        C.call(el);
        if (el.attributeChangedCallback) (C.observedAttributes || []).forEach(function (a) {
          if (el.hasAttribute(a)) el.attributeChangedCallback(a, null, el.getAttribute(a));
        });
        if (el.isConnected && el.connectedCallback) el.connectedCallback();
      } catch (e) { console.error(e); }
    }
    function under(node) {
      var all = node.querySelectorAll ? Array.from(node.querySelectorAll("*")) : [];
      if (node.nodeType === 1) all.unshift(node);
      // and in the shadow trees of those
      all.slice().forEach(function (el) { if (el.shadowRoot) all = all.concat(under(el.shadowRoot)); });
      return all;
    }
    g.customElements = {
      define: function (name, C) {
        if (classes[name]) throw new DOMException("the name \"" + name + "\" has already been used with this registry", "NotSupportedError");
        classes[name] = C;
        // those of that name now in the page: asked of the browser,
        // which has them without a list of all the others. Simply:
        //   under(document.documentElement).forEach(function (el) { if (el.localName === name) upgrade(el); });
        __named(name).forEach(upgrade);
        (waiting[name] || []).forEach(function (resolve) { resolve(C); });
        delete waiting[name];
      },
      get: function (name) { return classes[name]; },
      getName: function (C) { for (var name in classes) if (classes[name] === C) return name; return null; },
      whenDefined: function (name) {
        if (classes[name]) return Promise.resolve(classes[name]);
        return new Promise(function (resolve) { (waiting[name] = waiting[name] || []).push(resolve); });
      },
      upgrade: function (root) { under(root).forEach(upgrade); }
    };
    // an attribute set or removed later, said by the browser
    g.__attribute = function (el, name, old, now) {
      var C = classes[el.localName];
      if (!C || !el.attributeChangedCallback || (C.observedAttributes || []).indexOf(name) < 0) return;
      // not in a <template>'s content (Polymer writes its bindings
      // there as attributes, "[[data]]", and takes them away)
      if (el.getRootNode().__inert) return;
      el.attributeChangedCallback(name, old, now);
    };
    g.__connected = function (node) {
      under(node).forEach(function (el) {
        if (!classes[el.localName]) return;
        if (!el.__upgraded) upgrade(el);
        else if (el.connectedCallback) try { el.connectedCallback(); } catch (e) { console.error(e); }
      });
    };
    // an element made by a script is upgraded at once: its methods are
    // there before it is put in the page (document.createElement tells)
    g.__created = upgrade;
  })();
  global("DOMException", class DOMException extends Error { constructor(message, name) { super(message); this.name = name || "Error"; } });
  method(E, "scrollTo", stub("element.scrollTo"));
  method(E, "scrollBy", stub("element.scrollBy"));
  reflects(E, "role", "role");
  reflects(E, "nonce", "nonce");
  reflects(E, "slot", "slot");
  reflects(E, "ariaLabel", "aria-label");
  reflects(E, "ariaHidden", "aria-hidden");
  reflects(E, "ariaExpanded", "aria-expanded");
  // a <style>'s sheet: the object a script adds rules through, one at
  // a time (sheet.insertRule: how a CSS-in-JS library writes a
  // component's style when it is first drawn -- styled-components,
  // Emotion). Its rules are written after the element's own text.
  getter(E, "sheet", function () {
    if (this.tagName !== "STYLE") return null;
    if (!this.__sheet) { var s = new CSSStyleSheet(); s._style = this; s._text = this.textContent; s.ownerNode = this; this.__sheet = s; }
    return this.__sheet;
  });
  getter(D, "styleSheets", function () { return Array.prototype.map.call(this.querySelectorAll("style"), function (s) { return s.sheet; }); });
  getter(E, "draggable", function () { return this.getAttribute("draggable") === "true"; }, function (v) { this.setAttribute("draggable", String(!!v)); });
  getter(E, "inert", function () { return this.hasAttribute("inert"); }, function (v) { this.toggleAttribute("inert", !!v); });
  getter(E, "contentEditable", function () { return this.getAttribute("contenteditable") || "inherit"; }, function (v) { this.setAttribute("contenteditable", v); });
  getter(E, "isContentEditable", function () { return this.getAttribute("contenteditable") === "true"; });
  getter(E, "assignedSlot", function () { return null; });
  // a <slot>'s nodes: its host's children that name it (slot="name"),
  // or that name none for the slot with no name
  method(E, "assignedNodes", function () {
    var root = this.getRootNode ? this.getRootNode() : null, host = root && root.host;
    if (!host) return [];
    var name = this.getAttribute("name") || "";
    return Array.prototype.filter.call(host.childNodes, function (n) {
      return (n.nodeType === 1 || n.nodeType === 3) && ((n.nodeType === 1 && n.getAttribute("slot")) || "") === name;
    });
  });
  method(E, "assignedElements", function () { return this.assignedNodes().filter(function (n) { return n.nodeType === 1; }); });

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

// The DOM's members on its prototypes. An element here answers for its
// own members itself (a host object: src/webapi/dom); a real browser
// has them on Node.prototype, Element.prototype... as accessors and
// methods, and code that reaches under the DOM takes them from there:
//   Object.getOwnPropertyDescriptor(Node.prototype, "firstChild").get.call(node)
// -- a polyfill that keeps "the native one" before putting its own
// (Shady DOM, which YouTube runs in every browser, takes thirty-five
// so). Each is here as a thin one, asking the element itself.
(function () {
  if (typeof __host_get !== "function" || typeof Node !== "function") return;
  var get = __host_get, set = __host_set;
  function accessors(C, names) {
    if (typeof C !== "function") return;
    names.split(" ").forEach(function (k) {
      if (!Object.getOwnPropertyDescriptor(C.prototype, k))
        Object.defineProperty(C.prototype, k, { get: function () { return get(this, k); }, set: function (v) { set(this, k, v); }, configurable: true, enumerable: true });
    });
  }
  function methods(C, names) {
    if (typeof C !== "function") return;
    names.split(" ").forEach(function (k) {
      if (!Object.getOwnPropertyDescriptor(C.prototype, k))
        Object.defineProperty(C.prototype, k, { value: function () { var f = get(this, k); return typeof f === "function" ? f.apply(this, arguments) : undefined; }, writable: true, configurable: true });
    });
  }
  var G = typeof globalThis === "object" ? globalThis : this;
  methods(G.EventTarget, "addEventListener removeEventListener dispatchEvent");
  accessors(G.Node, "parentNode parentElement firstChild lastChild previousSibling nextSibling childNodes textContent nodeType nodeName nodeValue ownerDocument isConnected");
  methods(G.Node, "appendChild insertBefore removeChild replaceChild cloneNode contains hasChildNodes getRootNode compareDocumentPosition isEqualNode isSameNode normalize");
  accessors(G.Element, "children firstElementChild lastElementChild previousElementSibling nextElementSibling childElementCount innerHTML outerHTML id className classList tagName localName namespaceURI attributes shadowRoot slot scrollTop scrollLeft scrollWidth scrollHeight clientWidth clientHeight clientTop clientLeft");
  methods(G.Element, "getAttribute setAttribute removeAttribute hasAttribute toggleAttribute getAttributeNames hasAttributes querySelector querySelectorAll getElementsByTagName getElementsByClassName matches closest attachShadow append prepend before after remove replaceWith replaceChildren insertAdjacentHTML insertAdjacentElement insertAdjacentText getBoundingClientRect getClientRects scrollIntoView focus blur click");
  accessors(G.HTMLElement, "style dataset hidden title lang dir tabIndex innerText offsetParent offsetTop offsetLeft offsetWidth offsetHeight");
  accessors(G.CharacterData, "data length");
  accessors(G.Document, "documentElement body head activeElement children firstElementChild lastElementChild childElementCount readyState defaultView title cookie location URL");
  methods(G.Document, "createElement createElementNS createTextNode createComment createDocumentFragment createEvent createRange createTreeWalker getElementById getElementsByTagName getElementsByClassName getElementsByName querySelector querySelectorAll importNode adoptNode elementFromPoint append prepend");
  accessors(G.DocumentFragment, "children firstElementChild lastElementChild childElementCount");
  methods(G.DocumentFragment, "querySelector querySelectorAll getElementById append prepend");
  accessors(G.ShadowRoot, "host mode innerHTML activeElement");
})();
|prelude}
