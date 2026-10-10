(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* ix: the author's mini-chrome's data/prelude/library.js (its 8af888e), as it is, in a string: its dune makes this file there; here it is kept, as Ua_sheet is (docs/plans/plan_browser.md) *)

let text = {prelude|
// The standard library's later additions, written in the language
// itself: what ES2016 to ES2024 added to Array, String, Object, Math
// and Promise, each a few lines over what the engine has (Js_builtins,
// in OCaml). Run once in every engine, before any script
// (languages/javascript/Js_prelude.mli says why here and not there).
(function () {
  // a method added as the built-in ones are: not listed by for-in
  function def(o, name, f) {
    if (!Object.prototype.hasOwnProperty.call(o, name)) Object.defineProperty(o, name, { value: f, writable: true, configurable: true, enumerable: false });
  }
  // an index counted from the end if negative, kept within 0..n
  function clamp(i, n, missing) {
    if (i === undefined) return missing;
    i = Math.trunc(i) || 0;
    return i < 0 ? Math.max(n + i, 0) : Math.min(i, n);
  }

  var A = Array.prototype;
  // an array as text is its items joined; a function, its source's
  // stand-in (Object.prototype.toString says "[object Array]" of one)
  def(A, "toString", function () { return this.join(); });
  def(Function.prototype, "toString", function () { return String(this); });
  def(A, "at", function (i) { i = Math.trunc(i) || 0; return this[i < 0 ? this.length + i : i]; });
  def(A, "fill", function (v, start, end) {
    var n = this.length, e = clamp(end, n, n);
    for (var i = clamp(start, n, 0); i < e; i++) this[i] = v;
    return this;
  });
  def(A, "flat", function (depth) {
    var out = [];
    (function go(a, d) {
      for (var i = 0; i < a.length; i++) if (Array.isArray(a[i]) && d > 0) go(a[i], d - 1); else out.push(a[i]);
    })(this, depth === undefined ? 1 : depth);
    return out;
  });
  def(A, "flatMap", function (f, self) { return this.map(f, self).flat(); });
  // a typed array (Uint8Array...) is an array here: the two methods it
  // has that an array has not. subarray gives a copy, not a view: read
  // from, as a runtime does to write bytes out, it is the same
  def(A, "subarray", function (a, b) { return this.slice(a, b); });
  def(A, "set", function (from, at) { at = at || 0; for (var i = 0; i < from.length; i++) this[at + i] = from[i]; });
  def(A, "findLastIndex", function (f, self) {
    for (var i = this.length - 1; i >= 0; i--) if (f.call(self, this[i], i, this)) return i;
    return -1;
  });
  def(A, "findLast", function (f, self) { var i = this.findLastIndex(f, self); return i < 0 ? undefined : this[i]; });
  def(A, "reduceRight", function (f, initial) {
    var i = this.length - 1, acc = initial;
    if (arguments.length < 2) { if (i < 0) throw new TypeError("Reduce of empty array with no initial value"); acc = this[i--]; }
    for (; i >= 0; i--) acc = f(acc, this[i], i, this);
    return acc;
  });
  def(A, "copyWithin", function (target, start, end) {
    var n = this.length, t = clamp(target, n, 0), s = clamp(start, n, 0), part = this.slice(s, clamp(end, n, n));
    for (var i = 0; i < part.length && t + i < n; i++) this[t + i] = part[i];
    return this;
  });
  // ES2023: the changes that give a new array and leave this one
  def(A, "toSorted", function (compare) { return this.slice().sort(compare); });
  def(A, "toReversed", function () { return this.slice().reverse(); });
  def(A, "toSpliced", function () { var a = this.slice(); a.splice.apply(a, arguments); return a; });
  def(A, "with", function (i, v) { var a = this.slice(); a[i < 0 ? a.length + i : i] = v; return a; });

  var S = String.prototype;
  def(S, "at", function (i) { i = Math.trunc(i) || 0; return this.charAt(i < 0 ? this.length + i : i) || undefined; });
  def(S, "replaceAll", function (what, by) {
    if (what instanceof RegExp) return this.replace(what, by);
    if (typeof by !== "function") return this.split(what).join(by);
    var s = String(this), out = "", from = 0, at;
    while (what !== "" && (at = s.indexOf(what, from)) >= 0) { out += s.slice(from, at) + by(what, at, s); from = at + what.length; }
    return out + s.slice(from);
  });
  def(S, "padEnd", function (n, fill) {
    var s = String(this);
    fill = fill === undefined ? " " : String(fill);
    while (fill !== "" && s.length < n) s += fill.slice(0, n - s.length);
    return s;
  });
  def(S, "trimEnd", function () { return this.replace(/\s+$/, ""); });
  def(S, "trimRight", S.trimEnd);
  // a string is UTF-16's units (Js_utf16): a character beyond the
  // first 65,536 is two of them, a high half then a low one
  def(S, "codePointAt", function (i) {
    i = i || 0;
    var hi = this.charCodeAt(i);
    if (hi !== hi) return undefined;
    if (hi < 0xd800 || hi > 0xdbff) return hi;
    var lo = this.charCodeAt(i + 1);
    return lo >= 0xdc00 && lo <= 0xdfff ? 0x10000 + ((hi - 0xd800) << 10) + (lo - 0xdc00) : hi;
  });
  def(S, "normalize", function () { return String(this); });
  // as a dictionary has them, nearly: a letter's accent and its case
  // count only between two words otherwise the same (é before f, not
  // after z as its number would put it)
  var plain = { "à": "a", "á": "a", "â": "a", "ã": "a", "ä": "a", "å": "a", "ç": "c", "è": "e", "é": "e", "ê": "e", "ë": "e", "ì": "i", "í": "i", "î": "i", "ï": "i", "ñ": "n",
    "ò": "o", "ó": "o", "ô": "o", "õ": "o", "ö": "o", "ø": "o", "ù": "u", "ú": "u", "û": "u", "ü": "u", "ý": "y", "ÿ": "y", "ß": "ss", "æ": "ae", "œ": "oe" };
  function folded(s) { return s.toLowerCase().replace(/[\u00c0-\u017f]/g, function (c) { c = c.toLowerCase(); return plain[c] || c; }); }
  def(S, "localeCompare", function (other) {
    var s = String(this); other = String(other);
    var a = folded(s), b = folded(other);
    return a < b ? -1 : a > b ? 1 : s < other ? -1 : s > other ? 1 : 0;
  });
  def(S, "toLocaleLowerCase", S.toLowerCase);
  def(S, "toLocaleUpperCase", S.toUpperCase);
  def(S, "matchAll", function (re) {
    var all = [], m, r = new RegExp(re.source, re.flags.indexOf("g") < 0 ? re.flags + "g" : re.flags);
    while ((m = r.exec(this)) !== null) { all.push(m); if (m[0] === "") r.lastIndex++; }
    return all[Symbol.iterator]();
  });
  def(String, "fromCodePoint", function () {
    var units = [];
    for (var i = 0; i < arguments.length; i++) {
      var c = Number(arguments[i]);
      if (!(c >= 0 && c <= 0x10ffff) || c !== Math.floor(c)) throw new RangeError("Invalid code point " + arguments[i]);
      if (c < 0x10000) units.push(c);
      else { c -= 0x10000; units.push(0xd800 + (c >> 10), 0xdc00 + (c & 0x3ff)); }
    }
    return String.fromCharCode.apply(null, units);
  });

  def(String, "raw", function (strings) {
    var raw = strings.raw || strings, s = "";
    for (var i = 0; i < raw.length; i++) s += raw[i] + (i + 1 < raw.length && i + 1 < arguments.length ? arguments[i + 1] : "");
    return s;
  });

  def(Object, "groupBy", function (items, key) {
    var groups = {}, i = 0;
    for (var x of items) { var k = key(x, i++); (groups[k] || (groups[k] = [])).push(x); }
    return groups;
  });
  def(Number, "parseFloat", parseFloat);
  def(Number, "parseInt", parseInt);

  // an error's stack: where it was made is not kept here, and a text is
  // what a library expects to cut (e.stack.trim().match(...))
  [Error, TypeError, RangeError, SyntaxError, ReferenceError].forEach(function (E) {
    if (E.prototype && !("stack" in E.prototype)) Object.defineProperty(E.prototype, "stack", {
      get: function () { return String(this.name || "Error") + ": " + String(this.message || "") + "\n    at <anonymous>"; },
      set: function (v) { Object.defineProperty(this, "stack", { value: v, writable: true, configurable: true }); },
      configurable: true });
  });

  // Object.create(proto, properties): the second argument, descriptors
  // as Object.defineProperties takes them
  var create = Object.create;
  Object.create = function (proto, properties) {
    var o = create(proto);
    if (properties !== undefined) Object.defineProperties(o, properties);
    return o;
  };

  // Reflect.construct(F, args, NewTarget): new F(...args), the object
  // then of NewTarget's kind (how a class compiled for old browsers
  // extends a built-in: Reflect.construct(HTMLElement, [], new.target))
  def(Reflect, "construct", function (F, args, NewTarget) {
    var made = new F(...(args || []));
    if (NewTarget !== undefined && NewTarget !== F && made !== null && typeof made === "object") Object.setPrototypeOf(made, NewTarget.prototype);
    return made;
  });
  def(Reflect, "ownKeys", Reflect.ownKeys || function (o) { return Object.keys(o); });

  // new Number(5) and new String("a") are objects holding a value
  // (Js_builtins' boxed): valueOf gives it, and so does what converts
  // an object (new Number(5) + 1 is 6)
  [Number, String].forEach(function (C) {
    var own = C.prototype.valueOf;
    C.prototype.valueOf = function () {
      if (typeof this === "object" && this !== null && "@@primitive" in this) return this["@@primitive"];
      return own ? own.call(this) : this;
    };
  });
  var text = String.prototype.toString;
  String.prototype.toString = function () {
    if (typeof this === "string") return "" + this;
    return typeof this === "object" && this !== null && "@@primitive" in this ? this["@@primitive"] : text ? text.call(this) : String(this);
  };


  // a number written in another base, (255).toString(16): the
  // engine's own toString is base 10
  var N = Number.prototype, decimal = N.toString, digits = "0123456789abcdefghijklmnopqrstuvwxyz";
  N.toString = function (radix) {
    var n = typeof this === "object" && this !== null ? this.valueOf() : this;
    if (typeof n !== "number") throw new TypeError("Number.prototype.toString requires that 'this' be a Number");
    if (radix === undefined || radix === 10 || n !== n || n === Infinity || n === -Infinity) return decimal.call(n);
    var whole = Math.floor(Math.abs(n)), fraction = Math.abs(n) - whole, s = "";
    do { s = digits[whole % radix] + s; whole = Math.floor(whole / radix); } while (whole > 0);
    if (fraction > 0) {
      s += ".";
      for (var i = 0; i < 20 && fraction > 0; i++) { fraction *= radix; var d = Math.floor(fraction); s += digits[d]; fraction -= d; }
    }
    return (n < 0 ? "-" : "") + s;
  };
  def(N, "toExponential", function (places) {
    var n = Number(this);
    if (n === 0) return (0).toFixed(places || 0) + "e+0";
    var e = Math.floor(Math.log10(Math.abs(n))), m = n / Math.pow(10, e);
    var text = places === undefined ? String(m) : m.toFixed(places);
    if (Math.abs(Number(text)) >= 10) { e++; text = (n / Math.pow(10, e)).toFixed(places); }
    return text + "e" + (e < 0 ? "-" : "+") + Math.abs(e);
  });
  def(N, "toPrecision", function (precision) {
    var n = Number(this);
    if (precision === undefined) return String(n);
    if (n === 0) return (0).toFixed(precision - 1);
    var e = Math.floor(Math.log10(Math.abs(n)));
    return e < -6 || e >= precision ? n.toExponential(precision - 1) : n.toFixed(Math.max(0, precision - 1 - e));
  });
  def(N, "toLocaleString", function () { return String(Number(this)); });

  var M = Math;
  def(M, "cbrt", function (x) { return x < 0 ? -M.pow(-x, 1 / 3) : M.pow(x, 1 / 3); });
  def(M, "hypot", function () { var s = 0; for (var i = 0; i < arguments.length; i++) s += arguments[i] * arguments[i]; return M.sqrt(s); });
  def(M, "log2", function (x) { return M.log(x) / M.LN2; });
  def(M, "log10", function (x) { return M.log(x) / M.LN10; });
  def(M, "log1p", function (x) { return M.log(1 + x); });
  def(M, "expm1", function (x) { return M.exp(x) - 1; });
  def(M, "sinh", function (x) { return (M.exp(x) - M.exp(-x)) / 2; });
  def(M, "cosh", function (x) { return (M.exp(x) + M.exp(-x)) / 2; });
  def(M, "tanh", function (x) { var a = M.exp(x), b = M.exp(-x); return a === Infinity ? 1 : b === Infinity ? -1 : (a - b) / (a + b); });
  def(M, "fround", function (x) { return x; });
  def(M, "clz32", function (x) { x = x >>> 0; if (x === 0) return 32; var n = 0; while ((x & 0x80000000) === 0) { x <<= 1; n++; } return n; });
  def(M, "imul", function (a, b) {
    var ah = (a >>> 16) & 0xffff, al = a & 0xffff, bh = (b >>> 16) & 0xffff, bl = b & 0xffff;
    return (al * bl + (((ah * bl + al * bh) << 16) >>> 0)) | 0;
  });

  // ES2024: a promise and the two functions that settle it, at once
  def(Promise, "withResolvers", function () {
    var r = {};
    r.promise = new Promise(function (resolve, reject) { r.resolve = resolve; r.reject = reject; });
    return r;
  });

  // a typed array's buffer: an ArrayBuffer whose bytes are the array
  // itself (right for the arrays of bytes, the ones buffers are asked
  // of; a Float64Array's would be its numbers), kept on it
  ["Uint8Array", "Int8Array", "Uint8ClampedArray", "Uint16Array", "Int16Array", "Uint32Array", "Int32Array", "Float32Array", "Float64Array"].forEach(function (name) {
    var C = globalThis[name], size = /8/.test(name) ? 1 : /16/.test(name) ? 2 : /64/.test(name) ? 8 : 4;
    C.BYTES_PER_ELEMENT = size;
    Object.defineProperty(C.prototype, "BYTES_PER_ELEMENT", { value: size, configurable: true });
    Object.defineProperty(C.prototype, "byteLength", { get: function () { return this.length * size; }, configurable: true });
    Object.defineProperty(C.prototype, "byteOffset", { get: function () { return 0; }, configurable: true });
    Object.defineProperty(C.prototype, "buffer", { get: function () {
      // an array of 16 or 32 bit integers: its bytes as they are now,
      // the low one first -- a copy, not the array's own memory (what
      // a hash reads at its end: new Uint8Array(hashes.buffer))
      if (size > 1 && !/Float/.test(name)) {
        var wide = new ArrayBuffer(0), bytes = [];
        for (var i = 0; i < this.length; i++) for (var k = 0, v = this[i] >>> 0; k < size; k++) bytes.push((v >>> (8 * k)) & 255);
        wide._bytes = bytes; wide.byteLength = bytes.length;
        return wide;
      }
      if (!this._buffer) { var b = new ArrayBuffer(0); b._bytes = this; b.byteLength = this.length * size; Object.defineProperty(this, "_buffer", { value: b, enumerable: false, configurable: true }); }
      return this._buffer;
    }, configurable: true });
    // a part of one, or what map and filter make of it, is of its kind
    // too (a plain array would have no buffer: bytes cut with subarray,
    // then read through a DataView)
    ["slice", "subarray", "map", "filter"].forEach(function (m) {
      var plain = Array.prototype[m === "subarray" ? "slice" : m];
      Object.defineProperty(C.prototype, m, { value: function () { return new C(plain.apply(this, arguments)); }, writable: true, configurable: true });
    });
    C.from = function (items, f) { return new C(Array.from(items, f)); };
    C.of = function () { return new C(Array.prototype.slice.call(arguments)); };
  });

  // bytes as a thing of their own, and a view that reads numbers of
  // any size in them: the buffer here is an array of bytes, shared by
  // the views made with new DataView(buffer) (a typed array made from
  // a buffer copies it: not a view)
  if (typeof ArrayBuffer === "undefined") {
    globalThis.ArrayBuffer = class ArrayBuffer {
      constructor(n) { this.byteLength = n || 0; this._bytes = new Array(this.byteLength).fill(0); }
      slice(a, b) { var out = new ArrayBuffer(0); out._bytes = this._bytes.slice(a, b); out.byteLength = out._bytes.length; return out; }
      static isView(v) { return v instanceof DataView || (Array.isArray(v) && "BYTES_PER_ELEMENT" in v); }
    };
    globalThis.DataView = class DataView {
      constructor(buffer, offset, length) {
        this.buffer = buffer; this.byteOffset = offset || 0;
        this.byteLength = length === undefined ? buffer.byteLength - this.byteOffset : length;
      }
      _get(at, n, little) {
        var v = 0, b = this.buffer._bytes, o = this.byteOffset + at;
        for (var i = 0; i < n; i++) v = v * 256 + b[little ? o + n - 1 - i : o + i];
        return v;
      }
      _set(at, n, v, little) {
        var b = this.buffer._bytes, o = this.byteOffset + at;
        for (var i = 0; i < n; i++) { b[little ? o + i : o + n - 1 - i] = v % 256; v = Math.floor(v / 256); }
      }
      getUint8(at) { return this._get(at, 1); }
      getUint16(at, little) { return this._get(at, 2, little); }
      getUint32(at, little) { return this._get(at, 4, little); }
      getInt8(at) { var v = this._get(at, 1); return v > 127 ? v - 256 : v; }
      getInt16(at, little) { var v = this._get(at, 2, little); return v > 32767 ? v - 65536 : v; }
      getInt32(at, little) { return this._get(at, 4, little) | 0; }
      setUint8(at, v) { this._set(at, 1, v & 255); }
      setUint16(at, v, little) { this._set(at, 2, v & 65535, little); }
      setUint32(at, v, little) { this._set(at, 4, v >>> 0, little); }
      setInt8(at, v) { this._set(at, 1, v & 255); }
      setInt16(at, v, little) { this._set(at, 2, v & 65535, little); }
      setInt32(at, v, little) { this._set(at, 4, v >>> 0, little); }
      // a float's eight bytes (IEEE 754: a sign, eleven bits of
      // exponent, fifty-two of fraction), by arithmetic; four for a
      // float32 (the same, of 8 and 23 bits)
      _float(v, ebits, fbits) {
        var bias = (1 << (ebits - 1)) - 1, s = v < 0 || (v === 0 && 1 / v < 0) ? 1 : 0, e, f;
        v = Math.abs(v);
        if (v !== v) { e = (1 << ebits) - 1; f = Math.pow(2, fbits - 1); }
        else if (v === Infinity) { e = (1 << ebits) - 1; f = 0; }
        else if (v === 0) { e = 0; f = 0; }
        else {
          e = Math.min(Math.floor(Math.log(v) / Math.LN2), 1023);
          if (v / Math.pow(2, e) < 1) e--;
          if (v / Math.pow(2, e) >= 2) e++;
          if (e + bias >= 1) { f = Math.round((v / Math.pow(2, e) - 1) * Math.pow(2, fbits)); e += bias; if (f >= Math.pow(2, fbits)) { f = 0; e++; } }
          else { f = Math.round(v / Math.pow(2, 1 - bias - fbits)); e = 0; }
        }
        // the bytes, the high one first: sign and exponent, then the fraction
        var bytes = [], n = (ebits + fbits + 1) / 8, high = s * Math.pow(2, ebits) + e;
        for (var i = n - 1; i >= 0; i--) {
          var shift = 8 * i - fbits;
          bytes.push(shift >= 0 ? Math.floor(high / Math.pow(2, shift)) & 255 : (Math.floor(high * Math.pow(2, -shift)) & 255 & ~(Math.pow(2, -shift) - 1)) | (Math.floor(f / Math.pow(2, 8 * i)) & 255 & (i === Math.floor(fbits / 8) ? Math.pow(2, -shift) - 1 : 255)));
        }
        return bytes;
      }
      _unfloat(bytes, ebits, fbits) {
        var bias = (1 << (ebits - 1)) - 1, bits = 0, s = bytes[0] >> 7, e = 0, f = 0, n = bytes.length;
        // the exponent: the bits after the sign; the fraction: the rest
        for (var i = 0; i < n * 8; i++) {
          var bit = (bytes[i >> 3] >> (7 - (i & 7))) & 1;
          if (i >= 1 && i <= ebits) e = e * 2 + bit; else if (i > ebits) f = f * 2 + bit;
        }
        if (e === (1 << ebits) - 1) return f ? NaN : s ? -Infinity : Infinity;
        var m = e === 0 ? f / Math.pow(2, fbits) * Math.pow(2, 1 - bias) : (1 + f / Math.pow(2, fbits)) * Math.pow(2, e - bias);
        return s ? -m : m;
      }
      _putBytes(at, bytes, little) { var b = this.buffer._bytes, o = this.byteOffset + at, n = bytes.length; for (var i = 0; i < n; i++) b[o + i] = bytes[little ? n - 1 - i : i]; }
      _takeBytes(at, n, little) { var b = this.buffer._bytes, o = this.byteOffset + at, out = []; for (var i = 0; i < n; i++) out.push(b[o + (little ? n - 1 - i : i)]); return out; }
      setFloat64(at, v, little) { this._putBytes(at, this._float(+v, 11, 52), little); }
      setFloat32(at, v, little) { this._putBytes(at, this._float(+v, 8, 23), little); }
      getFloat64(at, little) { return this._unfloat(this._takeBytes(at, 8, little), 11, 52); }
      getFloat32(at, little) { return this._unfloat(this._takeBytes(at, 4, little), 8, 23); }
    };
  }

  // integers of any size are not here: BigInt(x) is x's whole part, a
  // number (and 10n is read as 10), right up to 2^53
  if (typeof BigInt === "undefined") {
    globalThis.BigInt = function BigInt(x) { return Math.trunc(Number(x)); };
    BigInt.asUintN = function (bits, x) { return bits >= 53 ? x : x % Math.pow(2, bits); };
    BigInt.asIntN = function (bits, x) { return x; };
  }

  // nothing is ever collected here: a weak reference always has what
  // it refers to, and nobody is told of an object's end
  if (typeof WeakRef === "undefined") globalThis.WeakRef = class WeakRef { constructor(target) { this.target = target; } deref() { return this.target; } };
  if (typeof FinalizationRegistry === "undefined") globalThis.FinalizationRegistry = class FinalizationRegistry { register() {} unregister() { return false; } };
  if (typeof AggregateError === "undefined")
    globalThis.AggregateError = class AggregateError extends Error {
      constructor(errors, message) { super(message); this.name = "AggregateError"; this.errors = Array.from(errors); }
    };

  // JSON.stringify whole: an object's own toJSON, the replacer (a
  // function, or the names to keep), the indentation. Strings and
  // numbers are written by the engine's own.
  var text = JSON.stringify;
  JSON.stringify = function (value, replacer, space) {
    var indent = typeof space === "number" ? " ".repeat(Math.min(space, 10)) : typeof space === "string" ? space.slice(0, 10) : "";
    var keep = Array.isArray(replacer) ? replacer.map(String) : null, change = typeof replacer === "function" ? replacer : null;
    var inside = [];
    function write(holder, key, pad) {
      var v = holder[key];
      if (v !== null && v !== undefined && typeof v.toJSON === "function") v = v.toJSON(String(key));
      if (change) v = change.call(holder, String(key), v);
      if (v === null) return "null";
      if (typeof v === "string" || typeof v === "number" || typeof v === "boolean") return text(v);
      if (typeof v !== "object") return undefined;
      if (inside.indexOf(v) >= 0) throw new TypeError("Converting circular structure to JSON");
      inside.push(v);
      var deeper = pad + indent, parts = [], open = "{", close = "}";
      if (Array.isArray(v)) {
        open = "["; close = "]";
        for (var i = 0; i < v.length; i++) parts.push(write(v, i, deeper) || "null");
      } else
        (keep || Object.keys(v)).forEach(function (k) {
          var s = write(v, k, deeper);
          if (s !== undefined) parts.push(text(String(k)) + (indent ? ": " : ":") + s);
        });
      inside.pop();
      if (parts.length === 0) return open + close;
      return indent ? open + "\n" + deeper + parts.join(",\n" + deeper) + "\n" + pad + close : open + parts.join(",") + close;
    }
    return write({ "": value }, "", "");
  };

  // Date: a moment as milliseconds since 1970, and the calendar's
  // arithmetic over it. The engine gives the clock (Date.now); the rest
  // is here. One zone, UTC: getHours is getUTCHours.
  var clock = Date.now, DAY = 86400000;
  var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  var weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
  // days since 1970-01-01 of a date, and back (Howard Hinnant's
  // algorithms: years counted from March, so the leap day comes last)
  function daysFromCivil(y, m, d) {
    y -= m <= 2 ? 1 : 0;
    var era = Math.floor(y / 400), yoe = y - era * 400;
    var doy = Math.floor((153 * (m + (m > 2 ? -3 : 9)) + 2) / 5) + d - 1;
    return era * 146097 + yoe * 365 + Math.floor(yoe / 4) - Math.floor(yoe / 100) + doy - 719468;
  }
  function civilFromDays(z) {
    z += 719468;
    var era = Math.floor(z / 146097), doe = z - era * 146097;
    var yoe = Math.floor((doe - Math.floor(doe / 1460) + Math.floor(doe / 36524) - Math.floor(doe / 146096)) / 365);
    var doy = doe - (365 * yoe + Math.floor(yoe / 4) - Math.floor(yoe / 100)), mp = Math.floor((5 * doy + 2) / 153);
    var m = mp + (mp < 10 ? 3 : -9);
    return { y: yoe + era * 400 + (m <= 2 ? 1 : 0), mo: m - 1, d: doy - Math.floor((153 * mp + 2) / 5) + 1 };
  }
  // the moment of a date and a time, a month past December or a day
  // past the month's end counted on: setDate(32) is the next month's
  function moment(y, mo, d, h, mi, s, ms) {
    y += Math.floor(mo / 12); mo = ((mo % 12) + 12) % 12;
    return (daysFromCivil(y, mo + 1, 1) + d - 1) * DAY + h * 3600000 + mi * 60000 + s * 1000 + ms;
  }
  function parts(t) {
    var days = Math.floor(t / DAY), rest = t - days * DAY, c = civilFromDays(days);
    c.h = Math.floor(rest / 3600000); c.mi = Math.floor(rest / 60000) % 60; c.s = Math.floor(rest / 1000) % 60; c.ms = rest % 1000;
    c.wd = ((days % 7) + 11) % 7;
    return c;
  }
  // 2020-01-15T10:30:00.000Z and its shorter forms; else the forms
  // people and servers write: 15 Jan 2020 10:30:00 GMT, Jan 15, 2020
  function parse(text) {
    text = String(text).trim();
    var m = /^(\d{4})-(\d\d)(?:-(\d\d))?(?:[T ](\d\d):(\d\d)(?::(\d\d)(?:\.(\d{1,3})\d*)?)?)?\s*(Z|[+-]\d\d:?\d\d)?$/.exec(text);
    if (m) {
      var t = moment(+m[1], +m[2] - 1, +(m[3] || 1), +(m[4] || 0), +(m[5] || 0), +(m[6] || 0), +((m[7] || "0") + "00").slice(0, 3));
      if (m[8] && m[8] !== "Z") { var zone = m[8].replace(":", ""); t -= (zone[0] === "-" ? -1 : 1) * (+zone.slice(1, 3) * 60 + +zone.slice(3)) * 60000; }
      return t;
    }
    var month = function (name) { return months.indexOf(name[0].toUpperCase() + name.slice(1, 3).toLowerCase()); };
    var time = "(?:\\s+(\\d\\d):(\\d\\d)(?::(\\d\\d))?)?";
    var a = new RegExp("(\\d{1,2})[\\s-]+([A-Za-z]{3})[a-z]*[\\s-]+(\\d{4})" + time).exec(text);
    if (a && month(a[2]) >= 0) return moment(+a[3], month(a[2]), +a[1], +(a[4] || 0), +(a[5] || 0), +(a[6] || 0), 0);
    var b = new RegExp("([A-Za-z]{3})[a-z]*\\s+(\\d{1,2}),?\\s+(\\d{4})" + time).exec(text);
    if (b && month(b[1]) >= 0) return moment(+b[3], month(b[1]), +b[2], +(b[4] || 0), +(b[5] || 0), +(b[6] || 0), 0);
    return NaN;
  }
  function two(n) { return (n < 10 ? "0" : "") + n; }
  function was(d, x, missing) { return x === undefined ? missing : x; }

  class Date {
    constructor(a, mo, d, h, mi, s, ms) {
      var n = arguments.length;
      this._t = n === 0 ? clock()
        : n === 1 ? (a instanceof Date ? a._t : typeof a === "string" ? parse(a) : Number(a))
        : moment(a >= 0 && a < 100 ? 1900 + a : a, mo, d === undefined ? 1 : d, h || 0, mi || 0, s || 0, ms || 0);
    }
    static now() { return clock(); }
    static parse(text) { return parse(text); }
    static UTC(y, mo, d, h, mi, s, ms) { return moment(y, mo || 0, d === undefined ? 1 : d, h || 0, mi || 0, s || 0, ms || 0); }
    getTime() { return this._t; }
    valueOf() { return this._t; }
    getTimezoneOffset() { return 0; }
    getFullYear() { return parts(this._t).y; }
    getMonth() { return parts(this._t).mo; }
    getDate() { return parts(this._t).d; }
    getDay() { return parts(this._t).wd; }
    getHours() { return parts(this._t).h; }
    getMinutes() { return parts(this._t).mi; }
    getSeconds() { return parts(this._t).s; }
    getMilliseconds() { return parts(this._t).ms; }
    getYear() { return parts(this._t).y - 1900; }
    setTime(t) { return (this._t = Number(t)); }
    setFullYear(y, mo, d) { var p = parts(this._t); return (this._t = moment(y, was(this, mo, p.mo), was(this, d, p.d), p.h, p.mi, p.s, p.ms)); }
    setMonth(mo, d) { var p = parts(this._t); return (this._t = moment(p.y, mo, was(this, d, p.d), p.h, p.mi, p.s, p.ms)); }
    setDate(d) { var p = parts(this._t); return (this._t = moment(p.y, p.mo, d, p.h, p.mi, p.s, p.ms)); }
    setHours(h, mi, s, ms) { var p = parts(this._t); return (this._t = moment(p.y, p.mo, p.d, h, was(this, mi, p.mi), was(this, s, p.s), was(this, ms, p.ms))); }
    setMinutes(mi, s, ms) { var p = parts(this._t); return (this._t = moment(p.y, p.mo, p.d, p.h, mi, was(this, s, p.s), was(this, ms, p.ms))); }
    setSeconds(s, ms) { var p = parts(this._t); return (this._t = moment(p.y, p.mo, p.d, p.h, p.mi, s, was(this, ms, p.ms))); }
    setMilliseconds(ms) { var p = parts(this._t); return (this._t = moment(p.y, p.mo, p.d, p.h, p.mi, p.s, ms)); }
    toISOString() {
      if (this._t !== this._t) throw new RangeError("Invalid time value");
      var p = parts(this._t), y = p.y;
      return (y >= 0 && y <= 9999 ? ("000" + y).slice(-4) : (y < 0 ? "-" : "+") + ("00000" + Math.abs(y)).slice(-6)) + "-" + two(p.mo + 1) + "-" + two(p.d) + "T" + two(p.h) + ":" + two(p.mi) + ":" + two(p.s) + "." + ("00" + p.ms).slice(-3) + "Z";
    }
    toJSON() { return this._t !== this._t ? null : this.toISOString(); }
    toDateString() { var p = parts(this._t); return weekdays[p.wd] + " " + months[p.mo] + " " + two(p.d) + " " + p.y; }
    toTimeString() { var p = parts(this._t); return two(p.h) + ":" + two(p.mi) + ":" + two(p.s) + " GMT+0000 (Coordinated Universal Time)"; }
    toString() { return this._t !== this._t ? "Invalid Date" : this.toDateString() + " " + this.toTimeString(); }
    toUTCString() { var p = parts(this._t); return weekdays[p.wd] + ", " + two(p.d) + " " + months[p.mo] + " " + p.y + " " + two(p.h) + ":" + two(p.mi) + ":" + two(p.s) + " GMT"; }
    toLocaleDateString() { var p = parts(this._t); return p.mo + 1 + "/" + p.d + "/" + p.y; }
    toLocaleTimeString() { var p = parts(this._t); return ((p.h + 11) % 12) + 1 + ":" + two(p.mi) + ":" + two(p.s) + (p.h < 12 ? " AM" : " PM"); }
    toLocaleString() { return this.toLocaleDateString() + ", " + this.toLocaleTimeString(); }
    // a date added is its text, a date subtracted or compared its number
    [Symbol.toPrimitive](hint) { return hint === "number" ? this._t : this.toString(); }
  }
  var P = Date.prototype;
  P[Symbol.toStringTag] = "Date";
  ["FullYear", "Month", "Date", "Day", "Hours", "Minutes", "Seconds", "Milliseconds"].forEach(function (k) {
    def(P, "getUTC" + k, P["get" + k]);
    if (P["set" + k]) def(P, "setUTC" + k, P["set" + k]);
  });
  def(P, "toGMTString", P.toUTCString);
  globalThis.Date = Date;
})();

// Symbol.unscopables (ES2015): the names of an object that a "with"
// does not see. Nobody writes "with" any more, but the polyfills of
// arrays' newer methods (core-js) write theirs in
// Array.prototype[Symbol.unscopables], and stop if it is not there.
(function () {
  if (!Symbol.unscopables) Symbol.unscopables = Symbol("Symbol.unscopables");
  Array.prototype[Symbol.unscopables] = { at: true, copyWithin: true, entries: true, fill: true, find: true, findIndex: true, findLast: true, findLastIndex: true, flat: true, flatMap: true, includes: true, keys: true, values: true };
})();

// console's other methods: said as log says them, or not at all
(function () {
  if (typeof console !== "object") return;
  ["info", "debug", "trace", "dir", "table", "group", "groupCollapsed"].forEach(function (m) { if (!console[m]) console[m] = console.log; });
  ["groupEnd", "time", "timeEnd", "timeLog", "count", "countReset", "clear", "profile", "profileEnd", "timeStamp"].forEach(function (m) { if (!console[m]) console[m] = function () {}; });
  if (!console.assert) console.assert = function (ok) { if (!ok) console.error.apply(console, ["Assertion failed:"].concat(Array.prototype.slice.call(arguments, 1))); };
  // escape and unescape (JavaScript 1.0's, 1995; out of the standard's
  // body since ES3 and on the web still, in a cookie's reading and a
  // tracker's): %XX for a character that is not a letter, a digit or
  // one of @*_+-./, %uXXXX above 255. Our strings being bytes, a letter
  // with an accent is its two bytes here (%C3%A9 where a browser says %E9).
  if (typeof globalThis.escape !== "function") {
    globalThis.escape = function (s) {
      return String(s).replace(/[^A-Za-z0-9@*_+\-.\/]/g, function (c) {
        var n = c.charCodeAt(0);
        return n < 256 ? "%" + (n < 16 ? "0" : "") + n.toString(16).toUpperCase() : "%u" + ("0000" + n.toString(16).toUpperCase()).slice(-4);
      });
    };
    globalThis.unescape = function (s) {
      return String(s).replace(/%u([0-9A-Fa-f]{4})|%([0-9A-Fa-f]{2})/g, function (m, u, b) { return String.fromCharCode(parseInt(u || b, 16)); });
    };
  }
})();
|prelude}
