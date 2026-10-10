(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Unit_js_module.mli *)

(* [files] as a little site: main.js run, what the console said (the
 * error of the run last, if it failed). An address is resolved as a
 * file's name: "./a.js" in "lib/b.js" is "lib/a.js" *)
let resolve ~(base : string) (spec : string) : string =
  let dir = match String.rindex_opt base '/' with Some i -> String.sub base 0 (i + 1) | None -> "" in
  if String.starts_with ~prefix:"./" spec then dir ^ String.sub spec 2 (String.length spec - 2) else spec

let site ?(dynamic = false) (files : (string * string) list) : string * (unit -> unit) list ref =
  let lines = ref [] and waiting = ref [] in
  let engine = Js_eval.create_with (fun l -> lines := l :: !lines) 1 (fun () -> 0.) in
  ignore (Js_eval.eval engine "var log = console.log;");
  let modules = Js_module.create engine ~resolve ~source:(fun url -> List.assoc_opt url files) in
  (* a host that answers later: what it was asked is kept, to be done by the test *)
  if dynamic then
    Js_module.set_dynamic modules (fun url ready failed ->
        waiting := !waiting @ [ (fun () -> ignore (Js_eval.protect engine (fun () -> (if List.mem_assoc url files then ready () else failed ("no " ^ url)); Js_value.Undefined))) ]);
  (match Js_module.run modules "main.js" with Ok _ -> () | Error e -> lines := e.message :: !lines);
  List.iter (fun later -> later ()) !waiting;
  (String.concat " | " (List.rev !lines), waiting)

let check (what : string) (files : (string * string) list) (expected : string) : unit =
  Alcotest.(check string) what expected (fst (site files))

let shapes =
  ( "shapes.js",
    {|export const sides = { square: 4 }
      export function area(r) { return Math.round(Math.PI * r * r) }
      export default class Shape {}|} )

let tests =
  Testo.categorize "Js module"
    [
      Testo.create "the worked example: names taken, renamed, the default, the whole" (fun () ->
          check "main.js"
            [ shapes;
              ( "main.js",
                {|import Shape, { area, sides as n } from "./shapes.js"
                  import * as shapes from "./shapes.js"
                  log(area(1), n.square, shapes.default === Shape, Object.keys(shapes).join())|} ) ]
            "3 4 true area,default,sides");
      Testo.create "a module's names are its own; it runs once; its imports before its first line" (fun () ->
          check "not the page's"
            [ ("a.js", "var count = 1; log('a runs'); export const a = count");
              ("b.js", "import { a } from './a.js'; var count = 10; export const b = a + count");
              ("main.js", "log(typeof a, typeof count); import { a } from './a.js'; import { b } from './b.js'; log(a, b, typeof globalThis.count)") ]
            "a runs | number undefined | 1 11 undefined");
      Testo.create "live bindings: what the exporter assigns, the importer sees" (fun () ->
          check "count"
            [ ("counter.js", "export let count = 0; export function bump() { count++ }");
              ("main.js", "import { count, bump } from './counter.js'; import * as c from './counter.js'; bump(); bump(); log(count, c.count)") ]
            "2 2");
      Testo.create "every export: declarations, lists, from another, all of another" (fun () ->
          check "the forms"
            [ ("a.js", "const one = 1, two = 2; function f() { return 'f' }; export { one, two as deux, f }; export default 'def'");
              ("b.js", "export { one as uno, default as d } from './a.js'; export * from './a.js'; export * as all from './a.js'; export const own = 0");
              ("main.js", "import * as b from './b.js'; import d2, { deux } from './a.js'; log(Object.keys(b).join(), b.uno, b.d, b.all.f(), b.default, d2, deux)") ]
            "all,d,deux,f,one,own,uno 1 def f undefined def 2";
          check "default function and class, named and not"
            [ ("f.js", "export default function named() { return 1 }; export const again = named()");
              ("g.js", "export default function () { return 2 }");
              ("c.js", "export default class C { m() { return 3 } }");
              ("main.js", "import f, { again } from './f.js'; import g from './g.js'; import C from './c.js'; log(f(), again, g(), new C().m(), f.name)") ]
            "1 1 2 3 named");
      Testo.create "a circle of two" (fun () ->
          check "b runs first, with a's functions"
            [ ("a.js", "import { b, later } from './b.js'; export function a() { return 'a' }; export const va = 'va'; log('a sees', b()); export { later }");
              ("b.js", "import { a, va } from './a.js'; export function b() { return 'b and ' + a() }; export function later() { return va }; log('b sees', typeof a, va)");
              ("main.js", "import { later } from './a.js'; log('once a has run, b has its names:', later())") ]
            "b sees function undefined | a sees b and a | once a has run, b has its names: va");
      Testo.create "what is not there" (fun () ->
          check "a name not exported" [ shapes; ("main.js", "import { volume } from './shapes.js'") ]
            "SyntaxError: The requested module './shapes.js' does not provide an export named 'volume'";
          check "a module not found" [ ("main.js", "import './gone.js'") ] "TypeError: Failed to fetch the module gone.js";
          check "one that does not parse" [ ("bad.js", "export const = 1"); ("main.js", "import './bad.js'") ] "SyntaxError: expected a name, not '=' (bad.js, line 1)";
          check "what a body throws: the importer's error, and each time" [ ("boom.js", "throw new Error('boom')"); ("main.js", "import './boom.js'; log('never')") ] "Error: boom");
      Testo.create "import(), import.meta" (fun () ->
          check "a promise of the names, at once when the text is there"
            [ shapes; ("main.js", "log(import.meta.url); import('./shapes.js').then(m => log(m.area(2))); import('./gone.js').catch(e => log(e.message)); log('first')") ]
            "main.js | first | 13 | Failed to fetch the module gone.js";
          let said, waiting = site ~dynamic:true [ shapes; ("main.js", "import('./shapes.js').then(m => log('late', m.sides.square)); import('./gone.js').catch(e => log(e.message)); log('first')") ] in
          Alcotest.(check (pair string int)) "the host asked, and answering later" ("first | late 4 | no gone.js", 2) (said, List.length !waiting));
      Testo.create "what a module names, from its text" (fun () ->
          Alcotest.(check (list string)) "imports and exports from, in order" [ "./a.js"; "./b.js"; "c"; "./d.js" ]
            (Js_module.specifiers "import a from './a.js'\nimport './b.js'; export * from 'c'; export { x } from './d.js'; const y = import('./not-static.js')");
          Alcotest.(check (list string)) "import as a name is not one" [] (Js_module.specifiers "var x = { import: 1 }; x.import; importScripts('a')"));
    ]
