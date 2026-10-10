(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's tests/js/Unit_js_modern.ml (its 8af888e) (docs/plans/plan_browser.md) *)

(* See Unit_js_modern.mli *)

let run (s : string) : string =
  let t = Js_eval.create () in
  match Js_eval.eval t s with Ok v -> Js_value.display v | Error e -> Printf.sprintf "line %d: %s" e.line e.message

let check (what : string) (s : string) (expected : string) : unit = Alcotest.(check string) what expected (run s)

let tests =
  Testo.categorize "Js modern"
    [
      (* what a framework of the 2020s is written in (Ember, as
       * discuss.ocaml.org bundles it): each stopped its start *)
      Testo.create "a regular expression where a statement starts" (fun () ->
          check "after an if's head, a block's end" "var r = []; if (true) /^a/.test('ab') && r.push(1); { } /b/.test('b') && r.push(2); r" "[1, 2]";
          check "a division still, after a value" "var x = 8, o = { a: 8 }; [(x) / 2 / 1, o.a / 2, [8][0] / 2]" "[4, 4, 4]");
      Testo.create "classes: private and async members, static's super, the order" (fun () ->
          check "async#n: two words" "class A { async#n(e) { return await e } go() { return this.#n(5) } } var out; new A().go().then(function (v) { out = v }); out" "undefined";
          check "an object's async generator" "var o = { async *g() { yield 1 } }; typeof o.g().next" "function";
          check "super in a static method: the parent class's" "class P { static s() { return 1 } } class Q extends P { static s() { return super.s() + 1 } } class R extends Q {} R.s()" "2";
          check "methods and accessors before the static blocks" "var seen; class S { get a() { return 1 } static { seen = typeof Object.getOwnPropertyDescriptor(this.prototype, 'a').set } set a(v) { } } seen" "function");
      Testo.create "a regular expression's named groups" (fun () ->
          check "match, exec, replace" "var re = /(?<y>\\d+)-(?<m>\\d+)/; var m = '2026-10'.match(re); [m.groups.y, re.exec('1-2').groups.m, '2026-10'.replace(re, '$<m>/$<y>'), 'ab'.match(/a/).groups]" "[\"2026\", \"2\", \"10/2026\", undefined]");
      Testo.create "proxies: an array answered for, the prototype" (fun () ->
          check "spread and for-of go through the traps"
            "var real = [1, 2, 3]; var p = new Proxy([], { get: function (t, k) { return k === 'length' ? real.length : real[k] } }); var r = []; for (var v of p) r.push(v); [r, [...p].length]"
            "[[1, 2, 3], 3]";
          check "getPrototypeOf: the target's, or the trap's" "function T() {} var p = new Proxy([], {}), q = new Proxy([], { getPrototypeOf: function () { return T.prototype } }); [Object.getPrototypeOf(p) === Array.prototype, Object.getPrototypeOf(q) === T.prototype, T.prototype.isPrototypeOf(q)]"
            "[true, true, true]");
      Testo.create "small things: a boolean's text, a descriptor's silence" (fun () ->
          check "toString" "[true.toString(), 'a'.toString(), ('1|2' || '').toString().split('|').length]" "[\"true\", \"a\", 2]";
          check "defineProperty keeps what it is not told" "var o = { a: 1 }; Object.defineProperty(o, 'a', { enumerable: false }); var g = {}; Object.defineProperty(g, 'q', { get: function () { return 5 }, set: function (v) { this.w = v } }); Object.defineProperty(g, 'q', { get: function () { return 6 } }); g.q = 7; [o.a, g.q, g.w]" "[1, 6, 7]");
      Testo.create "what frameworks lean on: assign and keys through getters and proxies, Map's order, bytes" (fun () ->
          check "Object.assign and spread read a getter and a proxy"
            "var s = { get a() { return 5 } }; var real = { x: 1 }; var p = new Proxy({ x: 0 }, { get: function (t, k) { return real[k] } }); var q = new Proxy({}, { ownKeys: function () { return ['k'] }, get: function () { return 9 } }); [Object.assign({}, s).a, { ...s }.a, Object.assign({}, p).x, Object.keys(q), Object.values(q), { ...q }.k]"
            "[5, 5, 1, [\"k\"], [9], 9]";
          check "a Map: any key, the order they were put in, one replaced in place"
            "var o = {}, m = new Map([[1, 'a'], ['1', 'b']]); m.set(o, 'o').set(NaN, 'n'); m.set(1, 'A'); m.delete('1'); [m.size, m.get(1), m.get(o), m.get(NaN), m.has('1'), Array.from(m.values())]"
            "[3, \"A\", \"o\", \"n\", false, [\"A\", \"o\", \"n\"]]";
          check "a typed array: of its kind, its bytes a buffer other views share"
            "var u = new Uint8Array(3); u[1] = 7; var v = new Uint8Array(u.buffer); v[2] = 9; [u instanceof Uint8Array, Array.isArray(u), u.buffer.byteLength, new Uint16Array(2).byteLength, new DataView(u.buffer).getUint8(1), u[2], ArrayBuffer.isView(u)]"
            "[true, true, 3, 4, 7, 9, true]";
          check "Reflect.construct and new.target" "function P(a) { this.a = a } class Q { hi() { return 'q' } } class E2 extends Error { constructor(m) { super(m); Object.setPrototypeOf(this, new.target.prototype) } } class E3 extends E2 {} var o = Reflect.construct(P, [5], Q); [o.a, o.hi(), new E3('x') instanceof E3]"
            "[5, \"q\", true]");
      (* an object of many properties is found by a table (Js_value.find):
       * the answers are the list's, through adds, deletes and changes *)
      Testo.create "an object of many properties: its table follows its list" (fun () ->
          check "set, read, delete, set again, keys in order"
            "var o = {}; for (var i = 0; i < 20; i++) o['k' + i] = i; var r = [o.k0, o.k19, o.nope]; delete o.k5; r.push(o.k5, 'k5' in o); o.k5 = 'again'; o.k19 = 'changed'; o.late = 1; r.push(o.k5, o.k19, o.late, Object.keys(o).length, Object.keys(o)[19], Object.keys(o)[20]); r"
            "[0, 19, undefined, undefined, false, \"again\", \"changed\", 1, 21, \"k5\", \"late\"]";
          check "a class of many methods, and one that shadows"
            "class B { a(){return 1} b(){return 2} c(){return 3} d(){return 4} e(){return 5} f(){return 6} g(){return 7} h(){return 8} i(){return 9} j(){return 10} k(){return 11} } class C extends B { k(){ return super.k() + 100 } } var c = new C(); B.prototype.z = function () { return 26 }; [c.a(), c.k(), c.z(), c.nope]"
            "[1, 111, 26, undefined]");
      Testo.create "template literals" (fun () ->
          check "values among the text" "var n = 3, who = 'you'; [`${n} for ${who}, ${n * 2} in all`]" "[\"3 for you, 6 in all\"]";
          check "no value; nothing at all" "[`plain`, ``]" "[\"plain\", \"\"]";
          check "lines kept, escapes read" "[`a\nb\\tc`.length, `\\${x}`, `\\``]" "[5, \"${x}\", \"`\"]";
          check "an expression of any kind: an object, a string with a brace, a call" "var o = {k: 'v'}; [`${ {a: 1}.a }-${'}'}-${[1, 2].map(x => x * 2)}-${o['k']}`]"
            "[\"1-}-2,4-v\"]";
          check "a regular expression with a quote in it" "[`<${'a\"b'.replace(/\"/g, \"'\")}>`]" "[\"<a'b>\"]";
          check "a template in a template" "var xs = ['a', 'b']; [`<ul>${xs.map(x => `<li>${x}</li>`).join('')}</ul>`]" "[\"<ul><li>a</li><li>b</li></ul>\"]";
          check "an object's and undefined's strings" "[`${[1, 2]} ${undefined} ${null}`]" "[\"1,2 undefined null\"]";
          check "its line" "var a = `x\ny`;\nnone" "line 3: ReferenceError: none is not defined");
      Testo.create "destructuring: declarations" (fun () ->
          check "an object's properties" "const { a, b } = { a: 1, b: 2, c: 3 }; [a, b]" "[1, 2]";
          check "another name, a default, one inside another" "let { a: x, missing = 'd', in: { deep } } = { a: 1, in: { deep: 'yes' } }; [x, missing, deep]"
            "[1, \"d\", \"yes\"]";
          check "the rest of an object" "var { a, ...others } = { a: 1, b: 2, c: 3 }; [a, others.b, others.c, 'a' in others]" "[1, 2, 3, false]";
          check "an array's items: one skipped, a default, the rest" "let [first, , third = 'd', fourth = 'd', ...more] = [1, 2, undefined, 4, 5, 6]; [first, third, fourth, more]"
            "[1, \"d\", 4, [5, 6]]";
          check "a string's characters; too few" "const [h, i, none] = 'hi'; [h, i, none]" "[\"h\", \"i\", undefined]";
          check "a computed key" "const k = 'dyn'; const { [k]: v } = { dyn: 7 }; v" "7";
          check "of nothing" "const { a } = null" "line 1: TypeError: Cannot destructure 'null' as it is null.";
          check "in a for-of" "var r = []; for (const [k, { n }] of [['a', { n: 1 }], ['b', { n: 2 }]]) r.push(k + n); r" "[\"a1\", \"b2\"]");
      Testo.create "destructuring: assignments" (fun () ->
          check "a swap" "var a = 1, b = 2; [a, b] = [b, a]; [a, b]" "[2, 1]";
          check "into properties; a default; the rest" "var o = {}, r; [o.x, o.y = 9, ...r] = [1, undefined, 3, 4]; [o.x, o.y, r]" "[1, 9, [3, 4]]";
          check "an object's, in parentheses" "var a, c, d; ({ a, b: c, d = 4 } = { a: 1, b: 2 }); [a, c, d]" "[1, 2, 4]";
          check "its value is the right side" "var a, b; var v = ([a, b] = [1, 2]); v" "[1, 2]");
      Testo.create "parameters: defaults, the rest, patterns" (fun () ->
          check "a default, when undefined is given or nothing" "function f(a, b = a + 1) { return [a, b] } [f(1), f(1, undefined), f(1, null), f(1, 5)]" "[[1, 2], [1, 2], [1, null], [1, 5]]";
          check "the rest" "function f(first, ...others) { return [first, others.length, others] } f(1, 2, 3)" "[1, 2, [2, 3]]";
          check "the rest of nothing" "((...xs) => xs)()" "[]";
          check "an object taken apart, with defaults" "function box({ w = 10, h = w }, [x, y] = [0, 0]) { return [w, h, x, y] } [box({}), box({ w: 2 }, [5, 6])]" "[[10, 10, 0, 0], [2, 2, 5, 6]]";
          check "an arrow's" "[[1, 2], [3, 4]].map(([a, b]) => a + b)" "[3, 7]");
      Testo.create "spread" (fun () ->
          check "in an array" "var xs = [2, 3]; [1, ...xs, 4, ...'ab', ...[]]" "[1, 2, 3, 4, \"a\", \"b\"]";
          check "in a call, and a new" "function sum(a, b, c) { return a + b + c } function P(x, y) { this.x = x; this.y = y } var p = new P(...[1, 2]); [sum(...[1, 2, 3]), Math.max(0, ...[5, 2]), p.x + p.y]"
            "[6, 5, 3]";
          check "in an object: copied, the later one wins" "var a = { x: 1, y: 2 }; var b = { ...a, y: 3, ...{ z: 4 } }; [b.x, b.y, b.z, a.y]" "[1, 3, 4, 2]";
          check "what is not a list" "[...5]" "line 1: TypeError: 5 is not iterable";
          check "a hole" "[1, , 3]" "[1, undefined, 3]");
      Testo.create "an object literal's short forms" (fun () ->
          check "a name alone, a method, a computed key, a keyword and a number as keys" "var x = 1, k = 'dyn'; var o = { x, twice() { return this.x * 2 }, [k + '!']: 3, if: 4, 5: 6 }; [o.x, o.twice(), o['dyn!'], o.if, o[5]]"
            "[1, 2, 3, 4, 6]";
          check "get and set are names too" "var o = { get: 1, set: 2, get() { return 3 } }; [typeof o.get, o.set]" "[\"function\", 2]");
      Testo.create "classes" (fun () ->
          check "a constructor, a method, a getter and a setter, a static"
            {|class Point { constructor(x, y) { this.x = x; this.y = y } sum() { return this.x + this.y } get twice() { return this.sum() * 2 } set both(v) { this.x = this.y = v } static origin() { return new Point(0, 0) } } var p = new Point(1, 2); p.both = 5; [p.sum(), p.twice, Point.origin().x, p instanceof Point, typeof Point, Object.keys(p)]|}
            {|[10, 20, 0, true, "function", ["x", "y"]]|};
          check "it is the old way underneath: a function and its prototype" {|class A { m() { return 1 } } [A.prototype.m === new A().m, A.prototype.constructor === A, new A().hasOwnProperty('m')]|} "[true, true, false]";
          check "extends: its methods, the parent's behind them; super(...) and super.m()"
            {|class Animal { constructor(name) { this.name = name } says() { return this.name + ' makes a sound' } } class Dog extends Animal { constructor(name) { super(name); this.legs = 4 } says() { return super.says() + ': woof' } } var d = new Dog('Rex'); [d.says(), d.legs, d instanceof Dog, d instanceof Animal, Object.getPrototypeOf(Dog.prototype) === Animal.prototype]|}
            {|["Rex makes a sound: woof", 4, true, true, true]|};
          check "no constructor: the parent's, with what was given" {|class A { constructor(x) { this.x = x } } class B extends A {} new B(7).x|} "7";
          check "statics are inherited too" {|class A { static make() { return 'made by ' + this.name2 } } A.name2 = 'A'; class B extends A {} B.name2 = 'B'; B.make()|} "made by B";
          check "fields: on each object made, before the constructor's own lines; a static one on the class" {|class C { count = 1; items = []; static made = 0; constructor() { this.count += 1; C.made++ } } var a = new C(), b = new C(); a.items.push(1); [a.count, b.items.length, C.made]|}
            "[2, 0, 2]";
          check "a field of a class that extends: after super()" {|class A { constructor() { this.a = 1 } } class B extends A { b = this.a + 1 } new B().b|} "2";
          check "a class as a value; a computed name; get and static as names" {|var k = 'dyn'; var C = class { [k]() { return 1 } get() { return 2 } static() { return 3 } }; var c = new C(); [c.dyn(), c.get(), c.static()]|} "[1, 2, 3]";
          check "an error of one's own" {|class Missing extends Error { constructor(what) { super(what + ' is missing'); this.what = what } } var r; try { throw new Missing('key') } catch (e) { r = [e.message, e.what, e instanceof Missing, e instanceof Error] } r|}
            {|["key is missing", "key", true, true]|};
          check "extending what is no class" {|class A extends 5 {}|} "line 1: TypeError: Class extends value 5 is not a constructor or null";
          check "a private name is a name" {|class Counter { #n = 0; inc() { this.#n++; return this.#n } } var c = new Counter(); c.inc(); c.inc()|} "2");
      Testo.create "optional chaining, and ??" (fun () ->
          check "a property of what may be nothing" {|var o = { a: { b: 1 } }, none = null; [o?.a?.b, none?.a, o.missing?.b, o.a?.['b']]|} "[1, undefined, undefined, 1]";
          check "the whole chain ends, not one step" {|var none; [none?.a.b.c, none?.a.b(), none?.[0].x]|} "[undefined, undefined, undefined]";
          check "a call that may not be there, the method still on its object" {|var o = { n: 5, get() { return this.n } }; [o.get?.(), o.other?.(), o?.get()]|} "[5, undefined, 5]";
          check "what is skipped is not run" {|var n = 0, none = null; none?.f(n++); n|} "0";
          check "it is not a ?: before a number" {|true ?.5 : 1|} "0.5";
          check "?? takes the right side for null and undefined only" {|[0 ?? 'd', '' ?? 'd', null ?? 'd', undefined ?? 'd', null?.x ?? 'none']|} {|[0, "", "d", "d", "none"]|});
      Testo.create "getters and setters" (fun () ->
          check "read by calling, assigned by calling" "var log = []; var o = { _v: 1, get v() { log.push('get'); return this._v }, set v(x) { log.push('set ' + x); this._v = x * 2 } }; o.v = 5; [o.v, log]"
            "[10, [\"set 5\", \"get\"]]";
          check "a getter alone: assigning does nothing" "var o = { get now() { return 7 } }; o.now = 1; o.now" "7";
          check "inherited" "var base = { get full() { return this.first + ' ' + this.last } }; var p = Object.create(base); p.first = 'Ada'; p.last = 'L'; [p.full]" "[\"Ada L\"]";
          check "++ on one" "var n = 0; var o = { get c() { return n }, set c(x) { n = x } }; o.c++; o.c += 10; n" "11");
      Testo.create "tagged templates" (fun () ->
          check "the tag is called with the strings, then each value" {|function tag(strings, a, b) { return strings.join('|') + ' ' + a + ' ' + b + ' ' + strings.raw.length }
            tag`x${1}y${2}z`|} "x|y|z 1 2 3";
          check "a method as a tag keeps its object; no value at all" {|var o = { p: '<', t(s) { return this.p + s[0] + '>' } }; [o.t`in`, (s => s.length)`a`]|} {|["<in>", 1]|};
          check "what a styling library does with one" {|function css(strings) { var vs = [].slice.call(arguments, 1); return strings.map(function (s, i) { return s + (vs[i] || '') }).join('') }
            var c = 'red'; css`color: ${c}; margin: ${4}px`|} "color: red; margin: 4px");
      Testo.create "logical assignment" (fun () ->
          check "only when it would change something" {|var a = 0, b = 1, c = null, d = 2, calls = 0; function v() { calls++; return 9 }
            a ||= v(); b ||= v(); c ??= v(); d ??= v(); b &&= v(); a &&= 5; [a, b, c, d, calls]|} "[5, 9, 9, 2, 3]";
          check "on a property" {|var o = { n: 0 }; o.n ||= 7; o.m ??= []; o.m.push(1); [o.n, o.m]|} "[7, [1]]");
      Testo.create "generators" (fun () ->
          check "the body runs a yield at a time; what next() gives" {|var log = [];
            function* g() { log.push('start'); var x = yield 1; log.push('got ' + x); yield 2; return 3 }
            var it = g(); log.push('made'); var a = it.next(); var b = it.next('hello'); var c = it.next(); var d = it.next();
            [log, [a.value, a.done], [b.value, b.done], [c.value, c.done], [d.value, d.done]]|}
            {|[["made", "start", "got hello"], [1, false], [2, false], [3, true], [undefined, true]]|};
          check "in a for-of, a spread, a pattern, Array.from" {|function* upto(n) { for (var i = 1; i <= n; i++) yield i }
            var sum = 0; for (var x of upto(4)) sum += x; var [a, b] = upto(9); [sum, [...upto(3)], a, b, Array.from(upto(2)), Math.max(...upto(5))]|}
            "[10, [1, 2, 3], 1, 2, [1, 2], 5]";
          check "one that never ends, left by a break: its finally runs" {|var log = [];
            function* naturals() { var n = 0; try { while (true) yield n++ } finally { log.push('closed') } }
            for (var n of naturals()) { if (n === 3) break } log.push(n); log|} {|["closed", 3]|};
          check "yield* gives each of another; a method; an object's own iterator" {|
            function* inner() { yield 'a'; yield 'b' }
            var o = { *each() { yield 0; yield* inner(); yield* [1, 2] }, [Symbol.iterator]: function* () { yield 'x'; yield 'y' } };
            class Tree { constructor(v, kids) { this.v = v; this.kids = kids || [] } *[Symbol.iterator]() { yield this.v; for (var k of this.kids) yield* k } }
            [[...o.each()], [...o], [...new Tree(1, [new Tree(2, [new Tree(3)]), new Tree(4)])]]|} {|[[0, "a", "b", 1, 2], ["x", "y"], [1, 2, 3, 4]]|};
          check "throw() into one; return() ends it; a throw inside is next()'s" {|
            function* g() { try { yield 1 } catch (e) { yield 'caught ' + e } yield 3 }
            var a = g(); a.next(); var caught = a.throw('boom').value; var ended = a.return(7); var after = a.next();
            function* bad() { yield 1; throw new Error('inside') } var b = bad(); b.next(); var said; try { b.next() } catch (e) { said = e.message }
            [caught, [ended.value, ended.done], after.done, said]|} {|["caught boom", [7, true], true, "inside"]|};
          check "yield is a name elsewhere" {|var yield = 5; yield + 1|} "6");
      Testo.create "the iteration protocol" (fun () ->
          check "an object with next(), by hand" {|var countdown = { [Symbol.iterator]() { var n = 3; return { next() { return n > 0 ? { value: n--, done: false } : { value: undefined, done: true } } } } };
            [[...countdown], Array.from(countdown, x => x * 2)]|} "[[3, 2, 1], [6, 4, 2]]";
          check "an array's iterators; a Map's and a Set's" {|var it = ['a', 'b'][Symbol.iterator](); var first = it.next().value;
            var m = new Map([['k', 1], ['l', 2]]);
            [first, [...['x', 'y'].entries()], [...['x', 'y'].keys()], m.keys().next().value, [...m.values()], [...new Set(m.keys())], new Map(m).get('l'), [...new Set('aab')]]|}
            {|["a", [[0, "x"], [1, "y"]], [0, 1], "k", [1, 2], ["k", "l"], 2, ["a", "b"]]|};
          check "what is not iterable" {|var r; try { [...{}] } catch (e) { r = e.name } r|} "TypeError");
      Testo.create "names and spaces beyond ASCII" (fun () ->
          check "a name in another alphabet; a no-break space between tokens" "var caf\xc3\xa9 = 1, \xcf\x80 = 3;\xc2\xa0caf\xc3\xa9 + \xcf\x80" "4");
      Testo.create "classes: a static block, one with no name that extends" (fun () ->
          check "static { }: run once, this the class" {|class A { static count = 1; static { this.count += 10; this.made = typeof A } } [A.count, A.made]|} {|[11, "function"]|};
          check "class extends B { } as a value" {|class B { hi() { return 'b' } } var C = class extends B { hi() { return super.hi() + 'c' } }; new C().hi()|} "bc");
      Testo.create "in, inside a for's first part" (fun () ->
          check "between brackets and in a function's body it is the operator" {|var o = { x: 1 }, r = [];
            for (var i = 0, a = ['x' in o], f = function () { return 'y' in o }, t = ('x' in o); i < 1; i++) r.push(a[0], f(), t); r|} "[true, false, true]");
      Testo.create "properties that are not enumerated" (fun () ->
          check "a class's methods, a defined property; they are still own names" {|class A { m() {} static s() {} get g() { return 1 } }
            var o = {}; Object.defineProperty(o, 'hid', { value: 1 }); Object.defineProperty(o, 'seen', { value: 2, enumerable: true }); o.plain = 3;
            var c = Object.create({}, { x: { value: 7 }, y: { value: 8, enumerable: true } });
            [Object.keys(A.prototype), Object.keys(A), Object.getOwnPropertyNames(A.prototype), Object.keys(o), o.hid, JSON.stringify(o),
             Object.getOwnPropertyDescriptor(o, 'hid').enumerable, Object.keys(function () {}), [c.x, Object.keys(c)]]|}
            {|[[], [], ["constructor", "m", "g"], ["seen", "plain"], 1, "{\"seen\":2,\"plain\":3}", false, [], [7, ["y"]]]|});
      Testo.create "an assignment to a pattern with a rest; a typed array's kind kept; an error's stack" (fun () ->
          check "({ a, ...rest } = v)" {|var a, rest; ({ a, ...rest } = { a: 1, b: 2, c: 3 }); [a, rest]|} {|[1, {b: 2, c: 3}]|};
          check "slice, subarray, map of a Uint8Array are Uint8Arrays" {|var u = new Uint8Array([1, 2, 3]);
            [u.slice(1) instanceof Uint8Array, u.subarray(1) instanceof Uint8Array, u.map(x => x * 2) instanceof Uint8Array, u.filter(x => x > 1).length]|}
            "[true, true, true, 2]";
          check "stack: a text, not enumerated, that can be set" {|var e = new Error('x'); var before = typeof e.stack; e.stack = 'mine'; [before, Object.keys(e).indexOf('stack'), e.stack]|}
            {|["string", -1, "mine"]|});
      Testo.create "a regular expression's class: bounds written as \\u escapes" (fun () ->
          check "from a string as from a literal; beyond ASCII, any such character" {|[new RegExp("^[\\u0009\\u0020-\\u007e\\u0080-\\u00ff]+$").test("ckns_echo_device_id"),
            new RegExp("^[\\u0041-\\u005a]+$").test("ABC"), new RegExp("^[\\u0041-\\u005a]+$").test("abc"), /^[\u00e0-\u00ff]+$/.test("\u00e9"),
            /[^\u0000-\u007f]/.test("e"), /[^\u0000-\u007f]/.test("\u00e9"), /[\u0041]/.test("A"), /[a\-z]/.test("-")]|}
            "[true, true, false, true, false, true, true, true]");
      Testo.create "the bytes of an array of 32-bit integers" (fun () ->
          check "a hash's two numbers as eight bytes, the low one first (Lit's digest of a template)" {|var strings = ['<div class="a">', '</div>'];
            var hashes = new Uint32Array(2).fill(5381);
            for (var s of strings) for (var i = 0; i < s.length; i++) hashes[i % 2] = (hashes[i % 2] * 33) ^ s.charCodeAt(i);
            Array.from(new Uint8Array(hashes.buffer))|} "[3, 185, 254, 90, 190, 124, 213, 130]");
      Testo.create "a sticky regular expression matches at its lastIndex, and moves it" (fun () ->
          check "a text read piece by piece (Fluent's parser)" {|var source = "# c\nhello = Hello, world\n    .title = T\n";
            var y = /([^{}\n\r]+)/y; y.lastIndex = 12; var m = y.exec(source); var first = [m[1], y.lastIndex];
            var nl = /[ \t\n\r]+/y; nl.lastIndex = 24; var blank = [nl.test(source), nl.lastIndex];
            var no = / +/y; no.lastIndex = 0; var none = [no.test(source), no.lastIndex];
            var plain = /l+/; plain.lastIndex = 7; var kept = [plain.test(source), plain.lastIndex];
            [first, blank, none, kept]|} {|[["Hello, world", 24], [true, 29], [false, 0], [true, 7]]|});
      Testo.create "new Array(n): places not given, which map and forEach skip" (fun () ->
          check "the schemes of a charting library" {|var calls = 0, f = function (s) { calls++; return s.length; };
            var a = new Array(3).concat("ab", "cde").map(f), seen = 0; new Array(2).forEach(function () { seen++ });
            var b = new Array(2); b[0] = "x"; var given = b.map(function (v) { return v + "!" });
            [a, calls, seen, given, new Array(2).fill(7).map(function (v) { return v + 1 })]|} {|[[undefined, undefined, undefined, 2, 3], 2, 0, ["x!", undefined], [8, 8]]|});
      Testo.create "new on a bound function" (fun () ->
          check "an object of the function bound, its arguments first" {|function C(a, b) { this.a = a; this.b = b } C.prototype.sum = function () { return this.a + this.b };
            var o = new (Function.prototype.bind.apply(C, [null, 5]))(2);
            class K { constructor(x) { this.x = x } get twice() { return this.x * 2 } } var k = new (K.bind(null, 21))();
            var self = { n: 1 }, plain = function () { return this.n }.bind(self);
            [o instanceof C, o.sum(), k instanceof K, k.twice, plain(), plain.call({ n: 2 })]|} "[true, 7, true, 42, 1, 1]");
      Testo.create "__proto__, read and set" (fun () ->
          check "an object's prototype as a property" {|var p = { hi: function () { return "p" } }, o = { a: 1 }; var before = o.__proto__ === Object.prototype;
            o.__proto__ = p; function F() {} var f = new F();
            [before, o.hi(), Object.getPrototypeOf(o) === p, f.__proto__ === F.prototype, [].__proto__ === Array.prototype, Object.keys(o)]|} {|[true, "p", true, true, true, ["a"]]|});
      Testo.create "a DataView's floats: IEEE 754's bytes" (fun () ->
          check "written and read back, of eight bytes and of four" {|function bytes(v, n) { var d = new DataView(new ArrayBuffer(n)); if (n === 8) d.setFloat64(0, v); else d.setFloat32(0, v); var out = []; for (var i = 0; i < n; i++) out.push(d.getUint8(i)); return out }
            function back(v) { var d = new DataView(new ArrayBuffer(8)); d.setFloat64(0, v, true); return d.getFloat64(0, true) }
            [bytes(1, 8), bytes(0.1, 8), bytes(1.5, 4), [-2.5, 1e300, 5e-324, 123456.789, Infinity].every(function (v) { return back(v) === v }), 1 / back(-0)]|}
            "[[63, 240, 0, 0, 0, 0, 0, 0], [63, 185, 153, 153, 153, 153, 153, 154], [63, 192, 0, 0], true, -Infinity]");
      Testo.create "match and search with a string: an expression's text" (fun () ->
          check "a key taken out of an address (a script loader's own)" {|var path = "/js/k=base.en_US/am=AAAA/d=1/m=a,b";
            [["k", "am", "d", "m"].map(function (e) { var v = path.match("/" + e + "=([^/]+)"); return v && v[1] }), "abc".match("a.c")[0], "abc".search("b."), "a.c".replace(".", "-"), "a.c".split(".").length]|}
            {|[["base.en_US", "AAAA", "1", "a,b"], "abc", 1, "a-c", 2]|});
    ]
