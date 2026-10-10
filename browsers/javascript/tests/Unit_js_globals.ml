(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* ix: the author's mini-chrome's tests/js/Unit_js_globals.ml (its 8af888e) (docs/plans/plan_browser.md) *)

(* See Unit_js_globals.mli *)

let run (s : string) : string =
  let t = Js_eval.create () in
  match Js_eval.eval t s with Ok v -> Js_value.display v | Error e -> Printf.sprintf "line %d: %s" e.line e.message

let check (what : string) (s : string) (expected : string) : unit = Alcotest.(check string) what expected (run s)

let tests =
  Testo.categorize "Js globals"
    [
      Testo.create "a property whose key is a symbol: copied by Object.assign, listed by getOwnPropertySymbols" (fun () ->
          (* a mark put on an object and looked for with "in", as a framework does *)
          Alcotest.(check string) "copied, found, listed; not among the keys" {|[true, true, 1, true, ["a"]]|}
            (run {|var m = Symbol("mark"), d = { a: 1 }; d[m] = true; var o = Object.assign({}, d); var syms = Object.getOwnPropertySymbols(o); [m in o, o[m], syms.length, syms[0] === m, Object.keys(o)]|}));
      Testo.create "Object's helpers" (fun () ->
          check "defineProperty: a value; a getter and a setter" {|var o = {}, n = 0; Object.defineProperty(o, 'v', { value: 1 }); Object.defineProperty(o, 'g', { get: function () { return this.v + 1 }, set: function (x) { n = x } }); o.g = 9; [o.v, o.g, n]|}
            "[1, 2, 9]";
          check "what libraries write at their top" {|var exports = {}; Object.defineProperty(exports, '__esModule', { value: true }); exports.__esModule|} "true";
          check "entries, values, fromEntries, getOwnPropertyNames" {|var o = { a: 1, b: 2 }; [Object.entries(o), Object.values(o), Object.fromEntries([['x', 1]]).x, Object.getOwnPropertyNames(o)]|}
            {|[[["a", 1], ["b", 2]], [1, 2], 1, ["a", "b"]]|};
          check "a descriptor read back" {|var d = Object.getOwnPropertyDescriptor({ a: 1 }, 'a'); [d.value, d.writable, Object.getOwnPropertyDescriptor({}, 'a')]|} "[1, true, undefined]";
          check "setPrototypeOf; isPrototypeOf; propertyIsEnumerable" {|var p = { hi: 1 }, o = {}; Object.setPrototypeOf(o, p); o.own = 2; [o.hi, p.isPrototypeOf(o), o.propertyIsEnumerable('own'), o.propertyIsEnumerable('hi')]|}
            "[1, true, true, false]";
          check "freeze gives the object back (and freezes nothing)" {|var o = Object.freeze({ a: 1 }); o.a = 2; [o.a, Object.isFrozen(o)]|} "[2, false]";
          check "Object.is, hasOwn" {|[Object.is(NaN, NaN), Object.is(1, '1'), Object.hasOwn({ a: 1 }, 'a'), Object.hasOwn({}, 'toString')]|} "[true, false, true, false]");
      Testo.create "Number's, isFinite, Array.of, globalThis" (fun () ->
          check "isFinite converts, Number.isFinite does not" {|[isFinite('12'), isFinite(1 / 0), Number.isFinite('12'), Number.isInteger(5), Number.isInteger(5.5), Number.isNaN('x')]|}
            "[true, false, false, true, false, false]";
          check "its constants" {|[Number.MAX_SAFE_INTEGER, Number.isSafeInteger(Number.MAX_SAFE_INTEGER + 1), Number.POSITIVE_INFINITY]|} "[9007199254740991, false, Infinity]";
          check "Array.of; globalThis" {|var g = 5; [Array.of(7).length, globalThis.g, typeof globalThis.isFinite]|} {|[1, 5, "function"]|});
      Testo.create "an undeclared name assigned to is a global" (fun () ->
          check "made by a function, seen after it" {|function f() { counter = 1 } f(); counter += 1; counter|} "2";
          check "read before it is one: still an error" {|nothing + 1|} "line 1: ReferenceError: nothing is not defined");
      Testo.create "Symbol: a key no one else has" (fun () ->
          check "each its own; Symbol.for the same for the same name" {|[Symbol('a') === Symbol('a'), Symbol.for('app') === Symbol.for('app'), typeof Symbol, typeof Symbol.iterator]|}
            {|[false, true, "function", "symbol"]|};
          check "a value of its own: its description, its text, never equal to a string" {|var s = Symbol('saved'); [s.description, s.toString(), String(Symbol.iterator), s == 'saved', s === s, typeof s]|}
            {|["saved", "Symbol(saved)", "Symbol(Symbol.iterator)", false, true, "symbol"]|};
          check "as a key: there, and not in a for-in nor the entries" {|var tag = Symbol('tag'); var o = { a: 1 }; o[tag] = 'hidden'; var ks = []; for (var k in o) ks.push(k); [o[tag], ks, Object.entries(o).length, JSON.stringify(Object.getOwnPropertyNames(o))]|}
            {|["hidden", ["a"], 1, "[\"a\"]"]|};
          check "React's test" {|var hasSymbol = typeof Symbol === 'function' && Symbol.for; var el = hasSymbol ? Symbol.for('react.element') : 0xeac7; typeof el|} {|symbol|});
      Testo.create "Map and Set" (fun () ->
          check "a Map: any value as a key, in the order set" {|var k = {}, m = new Map(); m.set('a', 1).set(k, 2).set(NaN, 3); m.set('a', 10); [m.get('a'), m.get(k), m.get(NaN), m.get({}), m.has(k), m.size, [...m.keys()].length]|}
            "[10, 2, 3, undefined, true, 3, 3]";
          check "delete, clear" {|var m = new Map([[1, 'one'], [2, 'two']]); var gone = [m.delete(1), m.delete(1)]; var left = m.size; m.clear(); [gone, left, m.size]|} "[[true, false], 1, 0]";
          check "a for-of, a pattern, a spread, forEach" {|var m = new Map([['a', 1], ['b', 2]]); var r = []; for (const [k, v] of m) r.push(k + v); m.forEach(function (v, k) { r.push(k + '=' + v) }); [r, [...m].length, [...m.keys()]]|}
            {|[["a1", "b2", "a=1", "b=2"], 2, ["a", "b"]]|};
          check "a Set: each value once" {|var s = new Set([1, 2, 2, 3]); s.add(3).add(4); [s.size, s.has(2), s.has(9), [...s], Array.from(new Set('hello')).length >= 0]|} "[4, true, false, [1, 2, 3, 4], true]";
          check "instanceof; without new" {|[new Map() instanceof Map, new Set() instanceof Map]|} "[true, false]";
          check "the methods are the prototype's, asked of any map" {|var m = new Map([[1, 5]]), s = new Set([1, 2]);
            [typeof Map.prototype.set, Map.prototype.get.call(m, 1), Set.prototype.has.call(s, 2), Object.keys(m).length, m.hasOwnProperty('set'), typeof Map.prototype[Symbol.iterator]]|}
            {|["function", 5, true, 0, false, "function"]|};
          check "on what is no map" {|var r; try { Map.prototype.get.call({}, 1) } catch (e) { r = e.name } r|} "TypeError";
          check "a class made of Map the old way (Closure's)" {|var Base = function () { return Reflect.construct(Map, [], this.constructor) };
            Base.prototype = Object.create(Map.prototype); Base.prototype.constructor = Base; Object.setPrototypeOf(Base, Map);
            var Mine = function (x) { var e = Base.call(this) || this; Base.prototype.set.call(e, 'k', x); return e };
            Mine.prototype = Object.create(Base.prototype); Mine.prototype.constructor = Mine;
            Mine.prototype.twice = function (k) { return Base.prototype.get.call(this, k) * 2 };
            var c = new Mine(21); [c instanceof Mine, c instanceof Map, c.size, c.twice('k'), Array.from(Base.prototype.entries.call(c)).length]|} "[true, true, 1, 42, 1]";
          check "a subclass's own method is the one called" {|class Counted extends Map { constructor() { super(); this.n = 0 } set(k, v) { this.n++; return super.set(k, v) } }
            var m = new Counted(); m.set(1, 2).set(3, 4); [m.n, m.get(1), m.size, [...m].length]|} "[2, 2, 2, 2]";
          check "a WeakMap, by the object" {|var w = new WeakMap(), o = {}; w.set(o, 'x'); [w.get(o), w.has({})]|} {|["x", false]|};
          check "a Map from a Map" {|new Map(new Map([[1, 2]])).get(1)|} "2");
      Testo.create "a mistake of the engine's own is the script's error, not the program's end" (fun () ->
          check "half a surrogate pair, in a string and a pattern" {|['\ud800'.length, /[\ud800-\udfff]/.test('a')]|} "[1, false]");
      Testo.create "Proxy and Reflect" (fun () ->
          check "the worked example: get and set seen" {|
            const seen = [];
            const p = new Proxy({ a: 1 }, {
              get(target, key) { seen.push(key); return Reflect.get(target, key) },
              set(target, key, value) { target[key] = value * 2; return true } });
            p.a; p.b = 2; [p.b, seen]|} {|[4, ["a", "b"]]|};
          check "has, deleteProperty; a trap not given: the target's own way" {|
            const log = [], t = { a: 1, b: 2 };
            const p = new Proxy(t, { has(o, k) { log.push('has ' + k); return k in o }, deleteProperty(o, k) { log.push('delete ' + k); delete o[k]; return true } });
            const r = ['a' in p, 'z' in p]; delete p.a; p.c = 3;
            [r, log, Object.keys(t), p.c]|} {|[[true, false], ["has a", "has z", "delete a"], ["b", "c"], 3]|};
          check "what does not go through a trap sees the target" {|
            const p = new Proxy({ a: 1, list: [1, 2] }, { get(o, k) { return k === 'a' ? 'trapped' : o[k] } });
            [p.a, JSON.stringify(p), Object.keys(p), typeof p, p instanceof Object]|} {|["trapped", "{\"a\":\"trapped\",\"list\":[1,2]}", ["a", "list"], "object", true]|};
          check "a proxy of an array is an array: its methods through the traps" {|
            const sets = [];
            const p = new Proxy([1, 2], { set(o, k, v) { sets.push(k); o[k] = v; return true } });
            p.push(3);
            [Array.isArray(p), p.length, p.map(x => x * 2), [...p], sets]|} {|[true, 3, [2, 4, 6], [1, 2, 3], ["0", "1", "2", "length"]]|};
          check "a proxy of a function: apply; for-in: ownKeys" {|
            const f = new Proxy(function (a, b) { return a + b }, { apply(target, self, args) { return target(...args) * 10 } });
            const o = new Proxy({}, { ownKeys() { return ['x', 'y'] } });
            const ks = []; for (const k in o) ks.push(k);
            [f(1, 2), typeof f, ks]|} {|[30, "function", ["x", "y"]]|};
          check "Reflect: each operation as a function" {|
            const o = { a: 1 };
            [Reflect.get(o, 'a'), Reflect.set(o, 'b', 2), Reflect.has(o, 'b'), Reflect.ownKeys(o), Reflect.ownKeys([7]), Reflect.deleteProperty(o, 'a'), Object.keys(o),
             Reflect.apply(Math.max, null, [1, 3]), Reflect.getPrototypeOf([]) === Array.prototype]|}
            {|[1, true, true, ["a", "b"], ["0", "length"], true, ["b"], 3, true]|});
      Testo.create "typed arrays, Array.from, getPrototypeOf" (fun () ->
          check "a typed array is an array" {|[new Uint8Array(3), new Float64Array([1.5, 2]), new Uint8Array(2).length]|} "[[0, 0, 0], [1.5, 2], 2]";
          check "Array.from: what can be gone through, what is like an array, a function for each" {|
            [Array.from('ab'), Array.from(new Set([1, 1, 2])), Array.from({ length: 2, 0: 'x', 1: 'y' }), Array.from({ length: 3 }, (v, i) => i * i), Array.from([1, 2], x => x + 1)]|}
            {|[["a", "b"], [1, 2], ["x", "y"], [0, 1, 4], [2, 3]]|};
          check "getPrototypeOf: its kind's, when it was given none" {|
            [Object.getPrototypeOf([]) === Array.prototype, Object.getPrototypeOf(function () {}) === Function.prototype, Object.getPrototypeOf({}) === Object.prototype,
             Object.getPrototypeOf(Object.prototype), Object.keys(Object.getOwnPropertyDescriptors({ a: 1, get b() { return 2 } }))]|}
            {|[true, true, true, null, ["a", "b"]]|});
      Testo.create "JSON.parse" (fun () ->
          check "the worked example" {|var v = JSON.parse('{"a": [1, 2.5e1, "x\\n"], "b": null}'); [v.a, v.b, Object.keys(v)]|} {|[[1, 25, "x\n"], null, ["a", "b"]]|};
          check "every kind of value; spaces anywhere; an escape" {|[JSON.parse(' [ true , false , null , -0.5 , "\\u0041\\"q\\"" , { } , [ ] ] '), JSON.parse('"alone"'), JSON.parse('7')]|}
            {|[[true, false, null, -0.5, "A\"q\"", {}, []], "alone", 7]|};
          check "and back" {|JSON.stringify(JSON.parse('{"a":[1,{"b":"c"}],"d":null}'))|} {|{"a":[1,{"b":"c"}],"d":null}|};
          check "not JSON: a key without quotes, a comma too many, a text cut short, something after" {|
            ['{a: 1}', '[1, 2,]', '{"a": ', '[1] 2', "{'a': 1}", 'undefined', ''].map(function (t) { try { JSON.parse(t); return 'read' } catch (e) { return e.name } })|}
            {|["SyntaxError", "SyntaxError", "SyntaxError", "SyntaxError", "SyntaxError", "SyntaxError", "SyntaxError"]|});
    ]
