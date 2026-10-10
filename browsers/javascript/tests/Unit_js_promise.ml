(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's tests/js/Unit_js_promise.ml (its 8af888e) (docs/plans/plan_browser.md) *)

(* See Unit_js_promise.mli *)

(* what the script said on the console, once it and its jobs are done:
 * "log(...)" is console.log *)
let run (s : string) : string =
  let lines = ref [] in
  let t = Js_eval.create_with (fun l -> lines := l :: !lines) 1 (fun () -> 0.) in
  (match Js_eval.eval t ("var log = console.log;\n" ^ s) with
  | Ok _ -> ()
  | Error e -> lines := Printf.sprintf "line %d: %s" (e.line - 1) e.message :: !lines);
  String.concat " | " (List.rev !lines)

let check (what : string) (s : string) (expected : string) : unit = Alcotest.(check string) what expected (run s)

let tests =
  Testo.categorize "Js promise"
    [
      Testo.create "a coroutine: suspended, resumed" (fun () ->
          let said = ref [] in
          let say x = said := x :: !said in
          let co = Js_coroutine.create (fun () -> say "a"; Js_coroutine.suspend (); say "c") in
          Js_coroutine.resume co; say "b"; Js_coroutine.resume co; say "d";
          Js_coroutine.resume co;
          Alcotest.(check string) "each in its turn; one ended: nothing" "a b c d" (String.concat " " (List.rev !said));
          Alcotest.(check bool) "none running outside" true (Js_coroutine.current () = None);
          (* one resuming another: suspend stops the innermost *)
          said := [];
          let inner = Js_coroutine.create (fun () -> say "i1"; Js_coroutine.suspend (); say "i2") in
          let outer = Js_coroutine.create (fun () -> say "o1"; Js_coroutine.resume inner; say "o2"; Js_coroutine.suspend (); say "o3") in
          Js_coroutine.resume outer; say "m"; Js_coroutine.resume inner; Js_coroutine.resume outer;
          Alcotest.(check string) "a body resuming another" "o1 i1 o2 m i2 o3" (String.concat " " (List.rev !said)));
      Testo.create "then: later, in order" (fun () ->
          check "a then's function runs after the script" {|Promise.resolve().then(() => log(2)); log(1)|} "1 | 2";
          check "the executor runs at once; its resolve's value is the then's" {|new Promise((resolve) => { log('in'); resolve(42) }).then(v => log(v)); log('out')|} "in | out | 42";
          check "a chain: each then a promise of what its function returns" {|Promise.resolve(1).then(v => v + 1).then(v => v * 10).then(log)|} "20";
          check "jobs in the order they were added, a job's own after" {|
            Promise.resolve().then(() => { log('a1'); Promise.resolve().then(() => log('a2')) });
            Promise.resolve().then(() => log('b1'));
            queueMicrotask(() => log('c1'))|} "a1 | b1 | c1 | a2";
          check "a promise settled once" {|new Promise((resolve, reject) => { resolve(1); resolve(2); reject(3) }).then(log, log)|} "1";
          check "then on a promise settled long ago" {|var p = Promise.resolve('v'); p.then(log); p.then(log)|} "v | v";
          check "what it is" {|var p = Promise.resolve(1); log(p instanceof Promise, typeof p.then, Object.keys(p).length, p)|} "true function 0 {}")
      ;
      Testo.create "rejections" (fun () ->
          check "reject's reason goes to the second function, or catch" {|Promise.reject('no').then(log, e => log('second', e)); Promise.reject('no').catch(e => log('catch', e))|}
            "second no | catch no";
          check "a throw in a then is the next catch's; then the chain goes on" {|Promise.resolve(1).then(v => { throw new Error('boom') }).then(() => log('skipped')).catch(e => e.message).then(log)|} "boom";
          check "a throw in the executor" {|new Promise(() => { throw new TypeError('bad') }).catch(e => log(e.name))|} "TypeError";
          check "finally: either way, and the outcome passes" {|
            Promise.resolve(1).finally(() => log('f1')).then(log);
            Promise.reject(2).finally(() => log('f2')).catch(log)|} "f1 | f2 | 1 | 2";
          check "nobody handles it: said on the console" {|Promise.reject(new Error('lost')); Promise.reject('s').then(log)|} "Uncaught (in promise) Error: lost | Uncaught (in promise) s";
          check "handled later in the same run: nothing said" {|var p = Promise.reject(1); log('a'); p.catch(() => log('caught'))|} "a | caught";
          check "not a constructor's call; not a function" {|try { Promise(() => 1) } catch (e) { log(e.name) } try { new Promise(1) } catch (e) { log(e.message) }|}
            "TypeError | Promise resolver 1 is not a function")
      ;
      Testo.create "thenables followed" (fun () ->
          check "a then that returns a promise: the chain waits for it" {|Promise.resolve(1).then(v => new Promise(r => r(v + 1))).then(log)|} "2";
          check "resolve with a promise" {|new Promise(r => r(Promise.resolve('inner'))).then(log)|} "inner";
          check "any object with a then" {|Promise.resolve({ then(ok) { ok('mine') } }).then(log)|} "mine";
          check "a rejected one" {|Promise.resolve(1).then(() => Promise.reject('r')).catch(log)|} "r";
          check "Promise.resolve of a promise is it" {|var p = Promise.resolve(1); log(Promise.resolve(p) === p)|} "true";
          check "a promise resolved with itself" {|var r; var p = new Promise(x => r = x); r(p); p.catch(e => log(e.name))|} "TypeError")
      ;
      Testo.create "all, allSettled, race, any" (fun () ->
          check "all: the values, in the items' order; a value is its own promise" {|Promise.all([Promise.resolve(1), 2, new Promise(r => r(3))]).then(vs => log(vs))|} "[1, 2, 3]";
          check "all: none; one rejected" {|Promise.all([]).then(vs => log(vs.length)); Promise.all([1, Promise.reject('x'), 3]).catch(log)|} "0 | x";
          check "allSettled" {|Promise.allSettled([Promise.resolve(1), Promise.reject('e')]).then(rs => log(rs.map(r => r.status + ':' + (r.value || r.reason))))|}
            "[\"fulfilled:1\", \"rejected:e\"]";
          check "race: the first settled" {|Promise.race([new Promise(() => {}), Promise.resolve('fast')]).then(log)|} "fast";
          check "any: the first fulfilled; none" {|Promise.any([Promise.reject(1), Promise.resolve(2)]).then(log); Promise.any([Promise.reject(1)]).catch(e => log(e.name, e.errors))|}
            "2 | AggregateError [1]";
          check "a Set's items" {|Promise.all(new Set([1, 2])).then(vs => log(vs))|} "[1, 2]")
      ;
      Testo.create "async and await" (fun () ->
          check "the caller goes on at the await" {|
            async function f() { log(1); const v = await Promise.resolve('v'); log(3, v) }
            f(); log(2)|} "1 | 2 | 3 v";
          check "an async function gives a promise of what it returns" {|async function f() { return 7 } var p = f(); log(p instanceof Promise); p.then(log)|} "true | 7";
          check "await of a value that is not a promise still waits" {|(async () => { log('a'); await 0; log('c') })(); log('b')|} "a | b | c";
          check "a throw is a rejection; a rejection awaited is a throw" {|
            async function bad() { throw new Error('thrown') }
            async function f() { try { await bad() } catch (e) { log('caught', e.message) } finally { log('finally') } return 'done' }
            f().then(log)|} "caught thrown | finally | done";
          check "in a loop, in order" {|
            const later = v => new Promise(r => r(v));
            async function sum(xs) { let n = 0; for (const x of xs) { n += await later(x); log(n) } return n }
            sum([1, 2, 3]).then(v => log('sum', v))|} "1 | 3 | 6 | sum 6";
          check "two at once take turns" {|
            async function count(name) { for (let i = 0; i < 2; i++) { log(name + i); await null } }
            count('a'); count('b')|} "a0 | b0 | a1 | b1";
          check "one awaiting another; this and the arguments kept" {|
            const o = { k: 2, async twice(v) { return v * this.k } };
            async function f() { const a = await o.twice(4); const b = await o.twice(a); return [a, b, arguments.length] }
            f(1, 2).then(v => log(v))|} "[8, 16, 2]";
          check "arrows, with and without brackets; a class's method" {|
            const inc = async x => x + 1, add = async (a, b) => (await inc(a)) + b;
            class A { async m() { return await add(1, 2) } static async s() { return 's' } }
            new A().m().then(log); A.s().then(log)|} "s | 4";
          check "an expression: its name, its place among operators" {|
            var f = async function named() { return typeof named };
            (async () => { log(await f(), 1 + await 2 * 3, !await false) })()|} "function 7 true";
          check "await of something never settled: the rest goes on" {|(async () => { log('in'); await new Promise(() => {}); log('never') })(); log('out')|} "in | out";
          check "an uncaught throw in one is said" {|(async () => { await 1; null.x })()|}
            "Uncaught (in promise) TypeError: Cannot read properties of null (reading 'x')";
          check "async and await are names elsewhere" {|var async = 1, await = 2; function g(async) { return async + await } log(g(5), async)|} "7 1";
          check "await outside an async function is a name" {|function f() { return await 1 }|} "line 1: SyntaxError: expected ';' or a new line, not 1";
          check "deep calls in one" {|
            function depth(n) { return n === 0 ? 0 : 1 + depth(n - 1) }
            (async () => { log(depth(1500)); try { depth(5000) } catch (e) { log(e.name) } })()|} "1500 | RangeError")
      ;
      Testo.create "for await" (fun () ->
          check "each item awaited, in order; the caller goes on meanwhile" {|
            (async () => { for await (const x of [Promise.resolve(1), 2, new Promise(r => r(3))]) log(x); log('end') })(); log('out')|} "out | 1 | 2 | 3 | end";
          check "what gives its items late itself: Symbol.asyncIterator" {|
            const ticks = { [Symbol.asyncIterator]() { let n = 0; return { next() { return Promise.resolve(n < 2 ? { value: 't' + n++, done: false } : { done: true }) } } } };
            (async () => { for await (const t of ticks) log(t); for await (const t of ticks) { log('once ' + t); break } })()|} "t0 | t1 | once t0";
          check "a rejection is the loop's to catch" {|(async () => { try { for await (const x of [1, Promise.reject('no')]) log(x) } catch (e) { log('caught ' + e) } })()|} "1 | caught no");
    ]
