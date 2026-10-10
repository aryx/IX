(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* ix: the author's mini-chrome's tests/js/Unit_js_classic.ml (its 8af888e) (docs/plans/plan_browser.md) *)

(* See Unit_js_classic.mli *)

let run (s : string) : string =
  let t = Js_eval.create () in
  match Js_eval.eval t s with Ok v -> Js_value.display v | Error e -> Printf.sprintf "line %d: %s" e.line e.message

let check (what : string) (s : string) (expected : string) : unit = Alcotest.(check string) what expected (run s)

(* how an expression is grouped *)
let parsed (s : string) (expected : string) : unit =
  Alcotest.(check string) s expected (match Js_parse.parse_expression s with Ok e -> Js_ast.expr_to_string e | Error e -> "error: " ^ e.message)

let tests =
  Testo.categorize "Js classic"
    [
      Testo.create "the powers: the comma last, the bits between && and ===, the shifts above <" (fun () ->
          parsed "a = 1, b = 2" "((a = 1), (b = 2))";
          parsed "a || b && c | d ^ e & f === g" "(a || (b && (c | (d ^ (e & (f === g))))))";
          parsed "1 << 2 + 3 < 4" "((1 << (2 + 3)) < 4)";
          parsed "2 ** 3 ** 2" "(2 ** (3 ** 2))";
          parsed "a ?? b || c" "(a ?? (b || c))";
          parsed "'k' in o && x instanceof F" "((\"k\" in o) && (x instanceof F))";
          parsed "c ? a = 1 : b = 2" "(c ? (a = 1) : (b = 2))";
          parsed "f(a, (b, c))" "(f(a, (b, c)))";
          parsed "x >>>= 1" "(x >>>= 1)";
          parsed "~-x" "(~(-x))");
      Testo.create "the comma: the last one's value; void" (fun () ->
          check "each done, the last returned" "var n = 0; var r = (n++, n++, n * 10); [n, r]" "[2, 20]";
          check "a for with two of each" "var s = ''; for (var i = 0, j = 3; i < j; i++, j--) s += i + '' + j + ' '; [s]" "[\"03 12 \"]";
          check "void: undefined, whatever it is of" "[void 0, typeof void 'x']" "[undefined, \"undefined\"]");
      Testo.create "the bits: 32 of them" (fun () ->
          check "and, or, xor, not" "[12 & 10, 12 | 10, 12 ^ 10, ~5]" "[8, 14, 6, -6]";
          check "shifts; >>> has no sign" "[1 << 17, -16 >> 2, -16 >>> 28, 1 << 31, 1 << 32]" "[131072, -4, 15, -2147483648, 1]";
          check "a number cut to an integer: x | 0, ~~x" "[7.9 | 0, -7.9 | 0, ~~3.5, 4294967301 | 0, NaN | 0]" "[7, -7, 3, 5, 0]";
          check "the same, assigning" "var x = 5; x <<= 2; x |= 1; x &= ~4; x ^= 8; x >>= 1; x" "12";
          check "** and **=" "var y = 2; y **= 10; [y, 2 ** -1]" "[1024, 0.5]");
      Testo.create "in, delete, for-in" (fun () ->
          check "in: its own, its prototype's, an array's index" "var a = {x: 1}; var b = Object.create(a); b.y = 2; ['x' in b, 'y' in b, 'z' in b, 1 in [7, 8], 2 in [7, 8], 'length' in []]"
            "[true, true, false, true, false, true]";
          check "in of what is no object" "'x' in 3" "line 1: TypeError: Cannot use 'in' operator to search for 'x' in 3";
          check "delete: gone" "var o = {a: 1, b: 2}; delete o.a; delete o['b']; ['a' in o, 'b' in o, delete o.none]" "[false, false, true]";
          check "for-in: the keys, as strings, in the order set" "var o = {b: 1, a: 2}; o.c = 3; var ks = []; for (var k in o) ks.push(k); ks" "[\"b\", \"a\", \"c\"]";
          check "an array's indices; a string's" "var ks = []; for (var i in ['x', 'y']) ks.push(i); for (i in 'ab') ks.push(i); [ks, typeof i]" "[[\"0\", \"1\", \"0\", \"1\"], \"string\"]";
          check "its prototype's too, not the constructor nor a built-in's" "function F() { this.own = 1 } F.prototype.shared = 2; var ks = []; for (var k in new F()) ks.push(k); ks"
            "[\"own\", \"shared\"]";
          check "into a property; break" "var t = {}, n = 0; for (t.key in {a: 1, b: 2, c: 3}) { n++; if (t.key === 'b') break } [t.key, n]" "[\"b\", 2]";
          check "'in' is the operator inside a for's parentheses" "var n = 0; for (var i = ('a' in {a: 1}) ? 2 : 0; i < 4; i++) n++; n" "2");
      Testo.create "do-while, switch, labels" (fun () ->
          check "do: once at least" "var n = 0; do { n++ } while (n < 0); n" "1";
          check "do, continue: the test still made" "var n = 0, s = 0; do { n++; if (n % 2) continue; s += n } while (n < 6); s" "12";
          check "switch: the case that is ===, falling into the next until a break"
            "function f(x) { var r = ''; switch (x) { case 1: r += 'one '; case 2: r += 'two '; break; case '3': r += 'text '; break; default: r += 'other ' } return r } [f(1), f(2), f('3'), f(3)]"
            "[\"one two \", \"two \", \"text \", \"other \"]";
          check "the default in the middle: taken last, falling on" "function f(x) { var r = ''; switch (x) { case 1: r += 'a'; default: r += 'd'; case 2: r += 'b' } return r } [f(1), f(2), f(9)]"
            "[\"adb\", \"b\", \"db\"]";
          check "a return from a case; a loop's continue through a switch" "function f() { for (var i = 0; i < 5; i++) { switch (i) { case 1: continue; case 3: return i } } } f()" "3";
          check "break out of two loops, by a label" "var r = []; outer: for (var i = 0; i < 3; i++) { for (var j = 0; j < 3; j++) { if (j === 2) continue outer; if (i === 2) break outer; r.push(i + '' + j) } } r"
            "[\"00\", \"01\", \"10\", \"11\"]";
          check "a labeled block" "var n = 0; b: { n = 1; break b; n = 2 } n" "1");
      Testo.create "finally: whatever happens" (fun () ->
          check "after the try, after the catch" "var r = []; try { r.push('t') } finally { r.push('f') } try { throw 1 } catch (e) { r.push('c' + e) } finally { r.push('f') } r"
            "[\"t\", \"f\", \"c1\", \"f\"]";
          check "before a return goes; and its own return wins" "function f() { try { return 'try' } finally { n = 1 } } function g() { try { return 'try' } finally { return 'finally' } } var n = 0; [f(), n, g()]"
            "[\"try\", 1, \"finally\"]";
          check "with no catch, the error goes on after it" "var n = 0; try { try { throw new Error('x') } finally { n = 1 } } catch (e) { n += 10 } n" "11";
          check "catch without a name" "var n = 0; try { throw 1 } catch { n = 1 } n" "1");
      Testo.create "an assignment's order: the target, then the value" (fun () ->
          check "the object first" {|var b; (b = { p: { eq: 1 } }).p.nth = b.p.eq; b.p.nth|} "1";
          check "and the key" {|var log = [], o = {}; function f(x) { log.push(x); return x } o[f('k')] = f('v'); log|} "[\"k\", \"v\"]");
      Testo.create "an array's methods on what is like an array" (fun () ->
          check "read: indexOf, slice, map, join" {|var o = { length: 3, 0: 'a', 1: 'b', 2: 'c' };
            [[].indexOf.call(o, 'b'), [].slice.call(o, 1), Array.prototype.map.call(o, function (x) { return x + x }), [].join.call(o, '-'), [].map.call('hi', function (c) { return c + c })]|}
            {|[1, ["b", "c"], ["aa", "bb", "cc"], "a-b-c", ["hh", "ii"]]|};
          check "written back: push, splice, pop, sort; its length too" {|var o = { length: 0 };
            [].push.call(o, 'c', 'a'); [].push.apply(o, ['b']); var pushed = [o.length, o[0], o[2]];
            var sorted = [].sort.call(o) === o; [].splice.call(o, 0, 1); var last = [].pop.call(o);
            [pushed, sorted, o.length, o[0], o[1], last]|} {|[[3, "c", "b"], true, 1, "b", undefined, "c"]|};
          check "a function's arguments; a length inherited (an empty jQuery object)" {|function Q() {} Q.prototype.length = 0; var q = new Q();
            [].push.call(q, 1); [(function () { return [].slice.call(arguments, 1) })(1, 2, 3), q.length, q[0], Q.prototype.length]|} "[[2, 3], 1, 1, 0]";
          check "on nothing" {|var r; try { [].slice.call(null) } catch (e) { r = e.name } r|} "TypeError");
      Testo.create "new Function, with" (fun () ->
          check "a function from its text: of the global scope" {|var g = 10; var add = new Function('a', 'b', 'return a + b + g'); var none = Function('return typeof local');
            (function () { var local = 1; return [add(1, 2), none(), new Function('a, b', 'return a * b')(3, 4), add.name, add.length, (function named(a) {}).name, Math.max.name] })()|} {|[13, "undefined", 12, "anonymous", 2, "named", "max"]|};
          check "a mistake in its text" {|var r; try { new Function('return (') } catch (e) { r = e.name } r|} "SyntaxError";
          check "an async function's constructor makes async ones" {|var AsyncFunction = Object.getPrototypeOf(async function () {}).constructor; var out = [];
            var f = new AsyncFunction('x', 'return await x + 1'); f(1).then(function (v) { out.push(v) }); [f(1) instanceof Promise, AsyncFunction === Function]|} "[true, false]";
          check "with: a name is the object's property, read and assigned; else the scope's" {|var o = { a: 1, b: 2 }, c = 3, r;
            with (o) { r = a + b + c; a = 10; c = 30; var made = 5 } [r, o.a, c, made, 'c' in o, 'made' in o]|} "[6, 10, 30, 5, false, false]";
          check "a template compiled to a function, as libraries do" {|var render = new Function('data', "var out = ''; with (data) { out += 'Hello ' + name + ', ' + (items.length) + ' items' } return out");
            render({ name: 'you', items: [1, 2] })|} "Hello you, 2 items";
          check "with a proxy: has decides, get and set are told; a closure made inside keeps it" {|var log = [];
            var scope = new Proxy({ n: 1 }, { has: function (o, k) { return k in o }, get: function (o, k) { log.push('get ' + k); return o[k] }, set: function (o, k, v) { log.push('set ' + k); o[k] = v; return true } });
            var later; with (scope) { n = n + 1; later = function () { return n } }
            [later(), log, typeof missing]|} {|[2, ["get n", "set n", "get n"], "undefined"]|};
          check "with is a name elsewhere; with of nothing" {|var o = { with: 1 }, r; try { with (null) { } } catch (e) { r = [o.with, e.name] } r|} {|[1, "TypeError"]|});
      Testo.create "eval" (fun () ->
          check "a text run, its last value; anything else given back" {|var g = 2; [eval('g * 21'), eval('var made = 1; made + 1'), made, eval(7), typeof eval]|} {|[42, 2, 1, 7, "function"]|};
          check "its mistakes are the caller's to catch" {|var r; try { eval('(') } catch (e) { r = e.name } r|} "SyntaxError";
          check "called by its name, it is of the caller's scope: its names, its this, what it declares" {|var g = 'global';
            var o = { n: 3, run: function (a) { var g = 'local'; var seen = eval('[g, a, this.n]'); eval('var made = a * 2'); eval('a = 7'); return seen.concat([made, a]) } };
            [o.run(1), typeof made]|} {|[["local", 1, 3, 2, 7], "undefined"]|};
          check "a function made there keeps the scope; hot or not" {|function vm() { var key = 5, op = function (x) { return x + key };
              var again = function (Q) { return eval(Q) }('0,' + op); for (var i = 0, t = 0; i < 300; i++) t += again(1);
              eval('key = 6'); return [t, again(1), again === op] }
            vm()|} "[1800, 7, false]";
          check "by another name, or as a member, it is of the global scope" {|var g = 'global';
            (function () { var g = 'local', e = eval; return [(0, eval)('g'), e('g'), globalThis.eval('g'), eval('g')] })()|} {|["global", "global", "global", "local"]|});
      Testo.create "a function's text" (fun () ->
          check "as it was written, comments and all" {|function add(a, b) { return a + b /* sum */ }
            var f = function (x) {return x*2}, g = (a, b) => a + b, h = async x => { await x };
            [String(add), '' + f, g.toString(), h + '', Function.prototype.toString.call(f) === '' + f]|}
            {|["function add(a, b) { return a + b /* sum */ }", "function (x) {return x*2}", "(a, b) => a + b", "async x => { await x }", true]|};
          check "one of the engine's, one made of a text" {|[String(Math.max), /native code/.test(String([].push)), eval('(' + function (a) { return a + 1 } + ')')(1),
            String(new Function('a', 'return a')).indexOf('return a') > 0, String(eval('0,function(q){return q}'))]|}
            {|["function max() { [native code] }", true, 2, true, "function(q){return q}"]|});
    ]
