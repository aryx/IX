(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's tests/browser/Unit_script_modules.ml (its 8af888e) (docs/plans/plan_browser.md) *)

(* See Unit_script_modules.mli *)

(* a page at http://site.test/app/ with this body *)
let page (body : string) : Browser_script.t =
  let t = Browser_script.create_with { Browser_script.defaults with base = "http://site.test/app/" } (Html_tree.of_string ("<body><script>var seen = [];</script>" ^ body ^ "</body>")) in
  Browser_script.run_scripts t;
  t

let value (t : Browser_script.t) (s : string) : string = match Browser_script.eval t s with Ok v -> Js_value.display v | Error e -> "error: " ^ e.message

(* the requests made since the last call: their addresses, and the
 * function that answers one with a text (or a status that is not 200) *)
let asked (t : Browser_script.t) : string list * (string -> ?status:int -> ?headers:(string * string) list -> string -> unit) =
  let rs = Browser_script.take_requests t in
  ( List.map (fun (r : Script_types.request) -> r.url) rs,
    fun url ?(status = 200) ?(headers = []) body ->
      match List.find_opt (fun (r : Script_types.request) -> r.url = url) rs with
      | Some r -> Browser_script.answer t r.rid (Ok { status; headers; body; final = url })
      | None -> Alcotest.failf "%s was not asked for" url )

let strings = Alcotest.(list string)

let tests =
  Testo.categorize "Script_modules"
    [
      Testo.create "the worked example: a module's graph fetched, then run" (fun () ->
          let t =
            page
              {|<script type="module" src="app.js"></script>
                <script type="module">seen.push("inline: no import, run at once; this is " + typeof this)</script>
                <script>seen.push("a classic script after them runs first")</script>
                <script nomodule>seen.push("for browsers without modules")</script>|}
          in
          Alcotest.(check string) "the page's scripts, then the module with nothing to wait for"
            {|["a classic script after them runs first", "inline: no import, run at once; this is undefined"]|} (value t "seen");
          let urls, answer = asked t in
          Alcotest.check strings "the module asked for, resolved" [ "http://site.test/app/app.js" ] urls;
          answer "http://site.test/app/app.js" {|import { area } from "./shapes.js"; import twice from "/lib/twice.js"; seen.push("app: " + twice(area(1)))|};
          let urls, answer = asked t in
          Alcotest.check strings "what it names, read from its text and asked for at once" [ "http://site.test/app/shapes.js"; "http://site.test/lib/twice.js" ] urls;
          answer "http://site.test/lib/twice.js" "export default x => 2 * x";
          Alcotest.(check string) "one missing: not run yet" "2" (value t "seen.length");
          answer "http://site.test/app/shapes.js" "export const area = r => Math.round(Math.PI * r * r)";
          Alcotest.(check string) "all there: run" "app: 6" (value t "seen[2]");
          Alcotest.check strings "and nothing asked twice" [] (fst (asked t)));
      Testo.create "an inline module that imports; a circle; one address run once" (fun () ->
          let t =
            page
              {|<script type="module">import { a } from "./a.js"; import { count } from "./count.js"; seen.push(a() + " " + count)</script>
                <script type="module">import { count } from "./count.js"; seen.push("again " + count)</script>|}
          in
          let urls, answer = asked t in
          Alcotest.check strings "each inline module's imports, one asked for once" [ "http://site.test/app/a.js"; "http://site.test/app/count.js" ] urls;
          answer "http://site.test/app/count.js" "seen.push('count runs'); export const count = 1";
          answer "http://site.test/app/a.js" {|import { b } from "./b.js"; export function a() { return "a" + b() }|};
          let urls, answer = asked t in
          Alcotest.check strings "a's import" [ "http://site.test/app/b.js" ] urls;
          answer "http://site.test/app/b.js" {|import { a } from "./a.js"; export function b() { return "b" }|};
          Alcotest.check strings "b names a, already there: the circle is not gone round" [] (fst (asked t));
          Alcotest.(check string) "run, count's body once" {|["count runs", "again 1", "ab 1"]|} (value t "seen"));
      Testo.create "what cannot be had: a 404, another origin's, a bare name" (fun () ->
          let t =
            page
              {|<script type="module" src="gone.js"></script>
                <script type="module" src="https://other.test/lib.js"></script>
                <script type="module" src="https://open.test/lib.js"></script>
                <script type="module">import React from "react"</script>|}
          in
          let _, answer = asked t in
          answer "http://site.test/app/gone.js" ~status:404 "no such file";
          answer "https://other.test/lib.js" "seen.push('read from another origin')";
          answer "https://open.test/lib.js" ~headers:[ ("Access-Control-Allow-Origin", "*") ] "seen.push('allowed')";
          Alcotest.(check string) "only the one allowed ran" {|["allowed"]|} (value t "seen");
          let console = String.concat "\n" (Browser_script.console t) in
          List.iter
            (fun part ->
              let rec at i = i + String.length part <= String.length console && (String.sub console i (String.length part) = part || at (i + 1)) in
              Alcotest.(check bool) ("the console says: " ^ part) true (at 0))
            [ "Failed to fetch the module http://site.test/app/gone.js (404)"; "blocked by CORS policy"; "Failed to resolve module specifier \"react\"" ]);
      Testo.create "an import map: names, prefixes" (fun () ->
          let t =
            page
              {|<script type="importmap">{ "imports": { "react": "/assets/react-e27d.js", "lib/": "https://cdn.test/lib/", "lib/special/": "/own/" } }</script>
                <script type="module">import React from "react"; import { a } from "lib/a.js"; import { s } from "lib/special/s.js"; import "./plain.js"; seen.push(React + a + s)</script>|}
          in
          let urls, answer = asked t in
          Alcotest.check strings "a name, a prefix, the longest prefix, and a plain address"
            [ "http://site.test/assets/react-e27d.js"; "https://cdn.test/lib/a.js"; "http://site.test/own/s.js"; "http://site.test/app/plain.js" ] urls;
          answer "http://site.test/assets/react-e27d.js" "export default 'R'";
          answer "https://cdn.test/lib/a.js" ~headers:[ ("Access-Control-Allow-Origin", "*") ] "export const a = 'a'";
          answer "http://site.test/own/s.js" "export const s = 's'";
          answer "http://site.test/app/plain.js" "";
          Alcotest.(check string) "run" {|["Ras"]|} (value t "seen"));
      Testo.create "a script a script inserts: fetched from anywhere, run, its load told" (fun () ->
          let t =
            page
              {|<script>
                  function load(src, name) {
                    var s = document.createElement("script"); s.src = src;
                    s.onload = function () { seen.push(name + " loaded, " + typeof window[name]) };
                    s.onerror = function () { seen.push(name + " failed") };
                    document.head.appendChild(s); return s }
                  load("https://cdn.test/lib.js", "lib"); load("gone.js", "gone");
                  var inline = document.createElement("script"); inline.textContent = "seen.push('inline, at once')"; document.body.appendChild(inline);
                  var loose = document.createElement("script"); loose.textContent = "seen.push('never: not in the page')";
                  seen.push("the script goes on")</script>|}
          in
          let urls, answer = asked t in
          Alcotest.check strings "asked for" [ "https://cdn.test/lib.js"; "http://site.test/app/gone.js" ] urls;
          answer "https://cdn.test/lib.js" "var lib = { version: 1 }; seen.push('lib runs, currentScript is its: ' + (document.currentScript.src.indexOf('lib.js') > 0))";
          answer "http://site.test/app/gone.js" ~status:404 "";
          Alcotest.(check string) "another origin's runs with no leave asked: a classic script"
            {|["inline, at once", "the script goes on", "lib runs, currentScript is its: true", "lib loaded, object", "gone failed"]|} (value t "seen");
          ignore (Browser_script.eval t "document.body.appendChild(document.head.querySelector('script[src]'))");
          Alcotest.check strings "moved: not run again" [] (fst (asked t)));
      Testo.create "import(): a module fetched while the page runs" (fun () ->
          let t = page {|<script>function later() { import("./late.js").then(m => seen.push(m.default + " " + m.n), e => seen.push(e.message)) }</script>|} in
          ignore (Browser_script.eval t "later(); seen.push('asked')");
          let urls, answer = asked t in
          Alcotest.check strings "asked for when called" [ "http://site.test/app/late.js" ] urls;
          answer "http://site.test/app/late.js" "export default 'late'; export const n = 1";
          Alcotest.(check string) "its names, when it has come" {|["asked", "late 1"]|} (value t "seen");
          ignore (Browser_script.eval t "later()");
          Alcotest.check strings "the second time, not fetched" [] (fst (asked t));
          Alcotest.(check string) "and the same module" "late 1" (value t "seen[2]"));
    ]
