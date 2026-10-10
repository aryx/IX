(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's tests/js/Unit_js_eval.ml (its 8af888e) (docs/plans/plan_browser.md) *)

(* See Unit_js_eval.mli *)

(* the program's last value as the console shows it, or its error *)
let run ?(budget = 10_000_000) (s : string) : string =
  let t = Js_eval.create () in
  Js_eval.set_budget t budget;
  match Js_eval.eval t s with
  | Ok v -> Js_value.display v
  | Error e -> Printf.sprintf "line %d: %s" e.line e.message

let check (what : string) (s : string) (expected : string) : unit = Alcotest.(check string) what expected (run s)

(* an expression's value inside [ ]: strings shown quoted *)
let value (s : string) (expected : string) : unit = check s ("[" ^ s ^ "]") ("[" ^ expected ^ "]")

let tests =
  Testo.categorize "Js_eval"
    [
      Testo.create "closures: the notes' counter" (fun () ->
          check "each counter its own n"
            "function counter() {\n  let n = 0;\n  return () => { n = n + 1; return n; };\n}\nconst c = counter();\nconst d = counter();\n[c(), c(), d()]"
            "[1, 2, 1]");
      Testo.create "a let per iteration" (fun () ->
          check "for (let i ...): each function its own i" "const fs = [];\nfor (let i = 0; i < 3; i++) fs.push(() => i);\nfs.map(f => f())"
            "[0, 1, 2]");
      Testo.create "a number past OCaml's int: 0x7fffffffffffffff" (fun () ->
          (* Closure's Long.fromNumber asks a >= 0x7fffffffffffffff: read
           * as -1, every number was the largest, and a division never ended *)
          value "0x7fffffffffffffff > 1e18" "true";
          value "0x7fffffffffffffff" "9223372036854776000";
          value "-0x8000000000000000" "-9223372036854776000";
          value "[0xff, 0XdeadBEEF, 0b101, 0o17, 0x100000000]" "[255, 3735928559, 5, 15, 4294967296]";
          value "[2 ** 53 + 2, 2 ** 64, 1e20, 123456789012345680000]" "[9007199254740994, 18446744073709552000, 100000000000000000000, 123456789012345680000]");
      Testo.create "what the language has does not show: for-in, Object.keys" (fun () ->
          check "no built-in member in a for-in" "var n = 0; for (var k in Array.prototype) n++; for (var k in Object.prototype) n++; for (var k in Math) n++; for (var k in new Map) n++; n" "0";
          value "[Object.keys(Array.prototype).length, Object.keys(new Error('x')).length, JSON.stringify(new TypeError('t'))]" "[0, 0, \"{}\"]";
          check "what a page adds shows" "Array.prototype.mine = 1; var a = Object.keys(Array.prototype); delete Array.prototype.mine; a" "[\"mine\"]";
          check "an error's fields through super()" "class E2 extends Error { constructor(m) { super(m); this.code = 3 } }; [Object.keys(new E2('m')), new E2('m').message]" "[[\"code\"], \"m\"]";
          check "a Map's methods" "var m = new Map([[1, 2]]); m.mine = 4; [Object.keys(m), m.get(1), m.size]" "[[\"mine\"], 2, 1]");
      Testo.create "the coercions: Wat" (fun () ->
          value "1 + 2" "3";
          value "\"1\" + 2" "\"12\"";
          value "1 + \"2\"" "\"12\"";
          value "\"3\" * \"4\"" "12";
          value "true + 1" "2";
          value "[] + []" "\"\"";
          value "[] + {}" "\"[object Object]\"";
          value "[1, 2] + [3]" "\"1,23\"";
          value "\"b\" + \"a\" + +\"a\" + \"a\"" "\"baNaNa\"";
          value "0.1 + 0.2" "0.30000000000000004";
          value "typeof null" "\"object\"";
          value "\"10\" < \"9\"" "true";
          value "10 < 9" "false";
          value "0 || \"x\"" "\"x\"";
          value "1 === 1.0" "true");
      Testo.create "this: a method's object, an arrow's outer this" (fun () ->
          check "o.get()" "const o = {n: 1, get: function () { return this.n }};\no.get()" "1";
          check "an arrow in a method" "const o = {n: 2, f: function () { return [1].map(x => this.n) }};\no.f()" "[2]";
          check "a plain call: the global object, 1995's rule" "function f() { return this === globalThis }\nf()" "true";
          check "in strict code: undefined" "function f() { 'use strict'; return typeof this }\nf()" "undefined";
          check "strict within strict, a class's methods" "function f() { 'use strict'; return (function () { return typeof this })() }\nclass C { m() { return typeof this } }\nconst m = new C().m;\n[f(), m()]" {|["undefined", "undefined"]|});
      Testo.create "errors, named and on their line" (fun () ->
          check "not defined" "let a = 1\nb + 1" "line 2: ReferenceError: b is not defined";
          check "not a function" "let f = 3\nf()" "line 2: TypeError: f is not a function";
          check "a method not a function" "const o = {}\no.m()" "line 2: TypeError: o.m is not a function";
          check "reading undefined's" "let o\n\no.y" "line 3: TypeError: Cannot read properties of undefined (reading 'y')";
          check "a const" "const k = 1\nk = 2" "line 2: TypeError: Assignment to constant variable.";
          check "inside a function: its own line" "function f() {\n  return x\n}\nf()" "line 2: ReferenceError: x is not defined";
          check "a syntax error" "let = 1" "line 1: SyntaxError: expected a name, not '='");
      Testo.create "throw and try" (fun () ->
          check "caught" "let m;\ntry { null.x } catch (e) { m = e.name + \": \" + e.message }\nm"
            "TypeError: Cannot read properties of null (reading 'x')";
          check "thrown and not caught" "throw 3" "line 1: Uncaught 3";
          check "an object thrown" "throw {code: 7}" "line 1: Uncaught {code: 7}");
      Testo.create "the limits: recursion, and a loop that never ends" (fun () ->
          check "fib" "function fib(n) { return n < 2 ? n : fib(n - 1) + fib(n - 2) }\nfib(15)" "610";
          check "recursion without end" "function f() { return f() }\nf()" "line 1: RangeError: Maximum call stack size exceeded";
          Alcotest.(check string) "while (true)" "line 1: RangeError: the script ran too long (a loop that never ends?)"
            (run ~budget:10_000 "while (true) {}");
          (* a job is a run of its own: thirty thens of a thousand turns each are not one loop of thirty thousand *)
          let t = Js_eval.create () in
          Js_eval.set_budget t 20_000;
          ignore (Js_eval.eval t "var n = 0; for (var j = 0; j < 30; j++) Promise.resolve().then(function () { for (var i = 0; i < 1000; i++) n++ })");
          Alcotest.(check string) "each job its budget" "30000" (match Js_eval.eval t "n" with Ok v -> Js_value.display v | Error e -> e.message));
      Testo.create "a long string grown by additions (a rope inside): a string to every eye" (fun () ->
          let grown = "var s = ''; for (var i = 0; i < 3000; i++) s += String.fromCharCode(97 + i % 26); var t = 'x' + s + 'y'; var o = { k: s }, a = [s, t];" in
          check "its length, a character, its type, what it equals"
            (grown ^ "[s.length, t.length, s.charAt(2999), typeof s, s === o.k, s == o.k, s != t, t === 'x' + o.k + 'y', a[1].slice(0, 3), s ? 1 : 0]")
            {|[3000, 3002, "j", "string", true, true, true, true, "xab", 1]|};
          check "compared, iterated, a key, in JSON, in a template, a number"
            (grown ^ "var m = new Map([[s, 7]]), n = '1' + '0'.repeat(1500); [s < t, t < s, [...s].length, m.get(o.k), JSON.stringify({ s: s }).length, `${s}!`.length, (s + 1).length, n - 1 > 1e300, s.indexOf('xyz'), s.split('a').length, ({ [s]: 1 })[o.k]]")
            "[true, false, 3000, 7, 3008, 3001, 3001, true, 23, 117, 1]";
          check "the same string added to twice is two strings; one added to in a property and an array too"
            (grown ^ "var p = s + '1', q = s + '2'; var h = { v: '' }, l = ['']; for (var i = 0; i < 2000; i++) { h.v += 'ab'; l[0] += 'c' } [p.slice(-1), q.slice(-1), p.length, s.length, h.v.length, l[0].length, h.v.slice(-2)]")
            {|["1", "2", 3001, 3000, 4000, 2000, "ab"]|};
          check "given to a function of the script, returned, thrown, kept by a closure"
            (grown ^ "function id(x) { return x } function len() { return arguments[0].length } var keep = (function (z) { return function () { return z.length } })(s + s); var caught; try { throw s + '!' } catch (e) { caught = e.length } [id(s + s).length, len(s + 'q'), keep(), caught, [s + s].map(function (x) { return x + x })[0].length]")
            "[6000, 3001, 6000, 3001, 12000]");
      Testo.create "a function declared in a block is the function's too (Annex B.3.3)" (fun () ->
          check "declared in a try, called in the next: a bundle's parts"
            "(function () { try { function f() { return 1 } } catch (e) {} try { return f() } catch (e) { return 'lost' } })()" "1";
          check "a block's, an if's; undefined before the block, the function after"
            "[(function () { { function g() {} } return typeof g })(), (function () { if (true) { function h() {} } return typeof h })(), (function () { var b = typeof k; { function k() {} } return b + '/' + typeof k })()]"
            {|["function", "function", "undefined/function"]|};
          check "a parameter of that name keeps what it was given; an outer function of that name is not touched"
            "[(function (p) { { function p() {} } return typeof p })(7), (function () { function o() { return 'outer' } (function () { { function o() { return 'inner' } } })(); return o() })()]"
            {|["number", "outer"]|};
          check "escape and unescape, 1995's" "[escape('a b&c=d/e@f'), unescape('a%20b%26c%u0041')]" {|["a%20b%26c%3Dd/e@f", "a b&cA"]|});
      Testo.create "the end of a chain of prototypes: null, then an error" (fun () ->
          check "going up until the property is found, or the chain's end throws (a monitoring script's loop)"
            "function up(o, k) { var n = 0; try { for (; 'object' == typeof o && !Object.prototype.hasOwnProperty.call(o, k); n++) o = Object.getPrototypeOf(o) } catch (e) { return e.name + ' after ' + n } return n } [up({ a: 1 }, 'a'), up(Object.create({ b: 1 }), 'b'), up({}, 'nowhere')]"
            {|[0, 1, "TypeError after 2"]|};
          check "getPrototypeOf(null) and (undefined) are errors" "[null, undefined].map(function (v) { try { return Object.getPrototypeOf(v) } catch (e) { return e.name } })"
            {|["TypeError", "TypeError"]|});
      Testo.create "a boolean and a symbol have every object's methods" (fun () ->
          check "(!o).hasOwnProperty(k), a minifier's false" "var o = { a: 1 }; [(!o).hasOwnProperty('a'), typeof Symbol('s').hasOwnProperty, true.toString(), false.missing]"
            "[false, \"function\", \"true\", undefined]");
      Testo.create "functions declared below their call" (fun () -> check "hoisted" "f()\nfunction f() { return 1 }" "1");
      Testo.create "arrays: holes, length" (fun () ->
          check "a[2] = 5" "const a = [];\na[2] = 5;\n[a.length, a[0], a[2]]" "[3, undefined, 5]";
          check "length cut" "const a = [1, 2, 3];\na.length = 1;\na" "[1]");
      Testo.create "the built-ins" (fun () ->
          value "Math.max(1, 3, 2)" "3";
          value "parseInt(\"42px\")" "42";
          value "\"a,b\".split(\",\")" "[\"a\", \"b\"]";
          value "[3, 1, 2].sort()" "[1, 2, 3]";
          value "[10, 9, 1].sort()" "[1, 10, 9]";
          value "[10, 9, 1].sort((a, b) => a - b)" "[1, 9, 10]";
          value "[1, 2, 3].reduce((a, b) => a + b)" "6";
          value "[1, 2, 3, 4].filter(x => x % 2 === 0)" "[2, 4]";
          value "JSON.stringify({a: [1, \"x\"], b: undefined})" "\"{\\\"a\\\":[1,\\\"x\\\"]}\"";
          value "\"abc\".slice(-2)" "\"bc\"";
          value "\"abc\".toUpperCase().length" "3";
          value "Object.keys({b: 1, a: 2})" "[\"b\", \"a\"]";
          let lines = ref [] in
          let t = Js_eval.create_with (fun l -> lines := l :: !lines) 1 (fun () -> 0.) in
          ignore (Js_eval.eval t "console.log(\"a\", 1, [1, \"b\"], {x: null})");
          Alcotest.(check (list string)) "console.log" [ "a 1 [1, \"b\"] {x: null}" ] !lines;
          let random () = Js_eval.eval (Js_eval.create_with (fun _ -> ()) 7 (fun () -> 0.)) "Math.random()" |> Result.map Js_value.display in
          Alcotest.(check bool) "Math.random: the same seed, the same number" true (random () = random ()));
    ]
