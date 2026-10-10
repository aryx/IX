(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* ix: the author's mini-chrome's tests/js/Unit_js_scope.ml (its 8af888e) (docs/plans/plan_browser.md) *)

(* See Unit_js_scope.mli *)

let run ?(compiled = true) (opti : bool) (s : string) : string =
  let before = (!Mini_opti.enabled, !Mini_opti.compiled) in
  Mini_opti.enabled := opti;
  Mini_opti.compiled := compiled;
  Fun.protect ~finally:(fun () -> Mini_opti.enabled := fst before; Mini_opti.compiled := snd before) @@ fun () ->
  let t = Js_eval.create () in
  match Js_eval.eval t s with Ok v -> Js_value.display v | Error e -> Printf.sprintf "line %d: %s" e.line e.message

(* the program on slots and on tables: the same answer, the one expected *)
let check (what : string) (s : string) (expected : string) : unit =
  Alcotest.(check string) (what ^ " (slots, compiled)") expected (run true s);
  Alcotest.(check string) (what ^ " (slots, walked)") expected (run ~compiled:false true s);
  Alcotest.(check string) (what ^ " (tables)") expected (run false s)

let many = String.concat "; " (List.init 40 (fun i -> Printf.sprintf "var v%d = %d" i i))

let tests =
  Testo.categorize "Js_scope"
    [
      Testo.create "the worked example" (fun () ->
          check "total found two scopes up, n in the call's frame"
            "var total = 0;\nfunction add(n) {\n  for (var i = 0; i < n; i++) { total = total + i }\n}\nadd(4); add(3); total" "9");
      Testo.create "Js_quicken: the tree's copy, its names given places" (fun () ->
          let parsed = match Js_parse.parse "var i = 0, n; total = total + i; function f(a, b) { var s = a; return s }" with Ok p -> p | Error e -> Alcotest.fail e.message in
          let fresh (p : Js_ast.place) = p.hops = -1 in
          (match List.map (fun (st : Js_ast.stmt) -> st.stmt) parsed with
          | [ Let (Var_kind, [ (Bind "i", Some (Number 0.)); (Bind "n", None) ]); Expr (Assign ("=", Name "total", Binary ("+", Name "total", Name "i"))); Function_decl { frame = None; _ } ] -> ()
          | _ -> Alcotest.fail "the parser's tree: names, and nothing remembered");
          (match List.map (fun (st : Js_ast.stmt) -> st.stmt) (Js_quicken.program parsed) with
          | [ Var_set [ ("i", p, Some (Number 0.)); ("n", q, None) ]; Expr (Assign ("=", Local ("total", r), Binary ("+", Local ("total", r'), Local ("i", _)))); Function_decl { frame = Some l; body = [ { stmt = Var_set [ ("s", _, Some (Local ("a", _))) ]; _ }; _ ]; _ } ] ->
              Alcotest.(check bool) "nothing found yet" true (fresh p && fresh q && fresh r);
              Alcotest.(check bool) "a place each time the name is written" true (r != r');
              Alcotest.(check (list string)) "the call's names, in the order of their slots" [ "arguments"; "s"; "a"; "b" ] (Array.to_list l.names);
              Alcotest.(check (list int)) "a's slot and b's" [ 2; 3 ] (Array.to_list l.slots);
              Alcotest.(check bool) "plain names" true l.plain
          | _ -> Alcotest.fail "the copy: Var_set, Local, a function's frame");
          check "a default among the parameters: they are the evaluator's" "function f(a, b = a) { return a + b } f(2)" "4");
      Testo.create "a name shadowed" (fun () ->
          check "the nearest x, at each depth" "var x = 1; function f() { var x = 2; { let x = 3; return [x, g()] } function g() { return x } } [f(), x]"
            "[[3, 2], 1]";
          check "a parameter over a global" "var a = 1; function f(a) { return a } [f(5), f(), a]" "[5, undefined, 1]";
          check "a catch's name" "var e = 1; try { throw 2 } catch (e) { e = e + 1 } e" "1");
      Testo.create "one function, two callers" (fun () ->
          check "the same text run under two frames" "function make(k) { return function (x) { return x + k } } var a = make(1), b = make(10); [a(1), b(1), a(2)]"
            "[2, 11, 3]";
          check "recursion: a frame a call" "function fact(n) { var r = n < 2 ? 1 : n * fact(n - 1); return r } fact(10)" "3628800");
      Testo.create "a let per iteration, a var for all" (fun () ->
          check "let" "var fs = []; for (let i = 0; i < 3; i++) fs.push(function () { return i }); fs.map(function (f) { return f() })" "[0, 1, 2]";
          check "var" "var fs = []; for (var i = 0; i < 3; i++) fs.push(function () { return i }); fs.map(function (f) { return f() })" "[3, 3, 3]";
          check "a let in the body" "var fs = []; for (var i = 0; i < 3; i++) { let j = i * 2; fs.push(function () { return j }) } fs.map(function (f) { return f() })"
            "[0, 2, 4]");
      Testo.create "hoisting, arguments, a function's own name" (fun () ->
          check "a var before its line" "function f() { var a = typeof x; var x = 1; return [a, x] } f()" "[\"undefined\", 1]";
          check "a var and a parameter of one name" "function f(a) { var a; return a } function g(a) { var a = 2; return a } [f(1), g(1)]" "[1, 2]";
          check "arguments" "function f() { return arguments.length + arguments[1] } f(1, 2, 3)" "5";
          check "a name of its own" "var f = function again(n) { return n < 1 ? 0 : n + again(n - 1) }; var g = f; f = null; g(4)" "10";
          check "a declaration's name is the scope's" "function f() { return typeof f } var g = f; f = 1; g()" "number";
          check "a default sees the parameter before" "function f(a, b = a + 1) { return a + b } [f(1), f(1, 5)]" "[3, 6]";
          check "a rest and a pattern" "function f(a, ...r) { return a + r.length } function g({ x, y }, [z]) { return x + y + z } [f(1, 2, 3), g({ x: 1, y: 2 }, [3])]"
            "[3, 6]");
      Testo.create "names not known before the program runs" (fun () ->
          check "typeof of a name nobody declared, then declared" "function t() { return typeof late } var a = t(); late = 1; [a, t()]" "[\"undefined\", \"number\"]";
          check "a with's object first" "var x = 1, o = { x: 2 }; function f() { with (o) { return x } } var a = f(); delete o.x; [a, f()]" "[2, 1]";
          check "a switch entered by two cases" "function f(k) { var r = 0; switch (k) { case 1: r = r + 1; case 2: r = r + 2; break; default: r = 9 } return r } [f(1), f(2), f(3)]"
            "[3, 2, 9]";
          check "a global made by an assignment" "function f() { made = 5 } f(); made" "5");
      Testo.create "a function of many names" (fun () ->
          (* past sixteen: the frame's names by an index *)
          check "forty var's and a closure over them" ("function f(p) { " ^ many ^ "; return function () { return v0 + v17 + v39 + p } } f(1)()") "57";
          check "and more declared as it runs" ("function f() { " ^ many ^ "; let a = 1; const b = 2; function h() { return a + b + v20 } return h() } f()") "23");
      Testo.create "Js_compile: a body compiled does what the evaluator does" (fun () ->
          check "the worked example" "function sum(n) { var s = 0; for (var i = 0; i < n; i++) { s = s + i } return s } sum(100)" "4950";
          check "+= and ++, on names, properties and items" "function f() { var a = 1, o = { n: 2 }, xs = [3]; a += 4; a++; o.n += 5; xs[0] *= 2; ++o.n; return [a, o.n, xs[0], a--, a] } f()"
            "[6, 8, 6, 6, 5]";
          check "a switch falls through to a break; its default" "function f(k) { var r = ''; switch (k) { case 1: r += 'a'; case 2: r += 'b'; break; case 3: r += 'c'; default: r += 'd' } return r } [f(1), f(2), f(3), f(9)]"
            "[\"ab\", \"b\", \"cd\", \"d\"]";
          check "try, catch, finally: the order, and a return in each" "function f(k) { var log = []; function g() { try { if (k) throw 'x'; return 'r' } catch (e) { log.push(e); return 'c' } finally { log.push('f') } } var v = g(); return [v, log] } [f(0), f(1)]"
            "[[\"r\", [\"f\"]], [\"c\", [\"x\", \"f\"]]]";
          check "a loop's break and continue, and one with a label" "function f() { var n = 0; outer: for (var i = 0; i < 4; i++) { for (var j = 0; j < 4; j++) { if (j == 2) continue outer; if (i == 3) break outer; n++ } } var m = 0; while (true) { if (++m > 5) break; if (m % 2) continue; n += 10 } return n } f()"
            "26";
          check "a constant assigned to: the evaluator's error" "function f() { const c = 1; c = 2 } f()" "line 1: TypeError: Assignment to constant variable.";
          check "what is not a function, named, on its line" "function f(o) {\n  return o.missing(1)\n}\nf({})" "line 2: TypeError: o.missing is not a function";
          check "a name nobody declared" "function f() { return nowhere + 1 } f()" "line 1: ReferenceError: nowhere is not defined";
          check "arguments made only where it is said, and seen by an arrow" "function f() { return (() => arguments.length)() } function g(a) { return a } [f(1, 2, 3), g(7)]" "[3, 7]";
          check "what is left to the evaluator, inside a compiled body" "function f(...xs) { var [a, b] = xs; var o = { a, ['k' + b]: `t${a}` }; class C { m() { return o.k2 } } return new C().m() + Math.max(...xs) } f(1, 2)"
            "t12";
          check "typeof of a name, declared or not; instanceof" "function f(x) { return [typeof x, typeof nowhere, x instanceof Array, [] instanceof Array, typeof f] } f(1)"
            "[\"number\", \"undefined\", false, true, \"function\"]";
          check "a regexp written in a loop: a new one each turn, its lastIndex its own" "function f() { var out = []; for (var i = 0; i < 2; i++) { var re = /a/g; re.test('aa'); out.push(re.lastIndex) } return out } f()" "[1, 1]";
          check "a built-in method found once, and found again after it is replaced" "function f(xs) { return xs.join('-') } var a = f([1, 2]); Array.prototype.join = function () { return 'mine' }; var b = f([1, 2]); var own = [3]; own.join = function () { return 'own' }; [a, b, f(own), 'x'.concat('y')]"
            "[\"1-2\", \"mine\", \"own\", \"xy\"]";
          check "length: an array's, a string's, a function's, an object's" "function f(a, b) { return [[1, 2, 3].length, 'four'.length, f.length, { length: 9 }.length] } f()" "[3, 4, 2, 9]";
          check "a let in an if without braces, in a switch, in a try: each its own" "function f(k) { let x = 'out'; if (k) var y = x; switch (k) { case 1: let x = 'in'; y = x } try { let x = 'try'; throw x } catch (e) { y = y + e } finally { y = y + x } return y } f(1)"
            "intryout";
          check "a catch with no name" "function f() { try { throw 1 } catch { return 'caught' } } f()" "caught";
          check "numbers written as text: integers, and the rest" "function f() { var o = {}; o[3] = 'k'; return [String(12), String(-7), String(1e21), String(0.1), String(-0), Object.keys(o)[0], 2 ** 53 + ''] } f()"
            "[\"12\", \"-7\", \"1e+21\", \"0.1\", \"0\", \"3\", \"9007199254740992\"]";
          Alcotest.(check string) "a loop that never ends is stopped, compiled too" "line 1: RangeError: the script ran too long (a loop that never ends?)" (run true "function f() { while (true) {} } f()"));
      Testo.create "what 9fans.topicbox.com asked of the language" (fun () ->
          check "a function expression's name is its own, whatever it is outside; a method's key is not a name"
            "var e = 'outer'; var o = { go: function e(n) { return n < 1 ? typeof e : e(n - 1) }, m() { return typeof m } }; [o.go(3), o.m()]"
            "[\"function\", \"undefined\"]";
          check "and a parameter or a var of that name is the one meant" "[(function f(f) { return f })(7), (function g() { var g = 2; return g })()]" "[7, 2]";
          check "the second argument of forEach, map, filter, some, every, find: the function's this"
            "var o = {}; var seen = []; [1].forEach(function () { seen.push(this === o) }, o); seen.concat([[1].map(function () { return this === o }, o)[0], [1].filter(function () { return this === o }, o).length, [1].some(function () { return this === o }, o), [1].every(function () { return this === o }, o), [1].find(function () { return this === o }, o), [1].findIndex(function () { return this === o }, o)])"
            "[true, true, 1, true, true, 1, 0]";
          check "new Number and new String: objects that hold a value" "[new Number(5) + 1, String(new Number(5)), new Number(5).toString(), new String('a') + 'b', typeof new Number(5), (255).toString(16)]"
            "[6, \"5\", \"5\", \"ab\", \"object\", \"ff\"]");
      Testo.create "classes, generators, async: scopes kept alive" (fun () ->
          check "a class's methods see its scope" "var k = 2; class A { constructor(x) { this.x = x } twice() { return this.x * k } } class B extends A { twice() { return super.twice() + 1 } } new B(4).twice()"
            "9";
          check "a generator between two yields" "function* g(n) { var s = 0; for (var i = 0; i < n; i++) { s += i; yield s } } var out = []; for (var v of g(4)) out.push(v); out"
            "[0, 1, 3, 6]");
    ]
