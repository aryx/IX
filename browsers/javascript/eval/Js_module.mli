(* Js_module: modules -- a program in several files, each with names
   of its own, saying which it gives out and which it takes.

     // shapes.js
     export const sides = { square: 4 }
     export function area(r) { return Math.PI * r * r }
     export default class Shape {}

     // main.js
     import Shape, { area, sides as n } from "./shapes.js"
     import * as shapes from "./shapes.js"
     console.log(area(1), n.square, shapes.default === Shape)

   A script's top-level names are the page's: two scripts that both
   say var count share one count. A module's are its own (a scope
   under the globals, Js_eval.module_scope), and nothing leaves it
   but what it exports, by name.

   A module is run once, however many import it: its address is its
   identity. The engine does not know where texts come from -- a
   file, a server -- nor how one address is found from another: the
   host gives both ([create]'s source and resolve; a browser resolves
   "./shapes.js" against the importing module's URL, as a link).

   What happens, for the module asked for ([run]):

     1. its text is parsed, and what it exports is read from its
        statements: each name out, and where its value will be
     2. the modules it names are run first, in the order named (each
        the same way: the whole tree, depth first)
     3. the names it imports are bound in its scope
     4. its body runs

   So a module's imports are there before its first line runs,
   wherever the import is written: import is not a call. That is the
   point of the syntax being fixed (a string, no expression): the
   whole graph of who imports whom is known from the texts alone,
   before anything runs -- which lets a host fetch all the files
   first ([specifiers]), and a bundler put them in one.

   **Live bindings.** An import is not a copy. In

     // counter.js                    // main.js
     export let count = 0             import { count, bump } from "./counter.js"
     export function bump() {         bump()
       count++ }                      console.log(count)       // 1

   main's count is counter's variable itself, read when used. Here
   the importer's name is made the exporter's very binding (the same
   mutable cell in both scopes), and the object of import * as ns
   reads each name where it is when asked.

   **Circles.** a imports b and b imports a: the standard allows it,
   and live bindings are what make it work -- b runs first, with a's
   names bound but not yet given their values; it can define
   functions that use them, and call them once a has run. Here b sees
   a's function declarations (hoisted before anything runs) and
   undefined for the rest, where the standard has an error for a name
   read too early; once a has run, b's names are a's.

   The exports, all the forms:

     export const x = 1, y = 2      export function f() {}    export class C {}
     export { a, b as c }           export default expression
     export { a as b } from "m"     export * from "m"         export * as ns from "m"

   And import("./m.js"), an expression, where the rest are
   statements: a promise of the module's names, for a module chosen
   or wanted only while the program runs. Its text may not be there:
   the host is asked ([set_dynamic]), and the promise waits.
   import.meta.url is the module's own address.

   cs-history:
   JavaScript had no modules for twenty years. A page's scripts
   shared one set of global names, and a library was one global
   object ($, _) by courtesy. The first modules were a pattern -- a
   function called at once whose local names nobody else sees, giving
   back an object -- and then two conventions over it. CommonJS (Kevin
   Dangoor's ServerJS, 2009, Node's from its start): require("m")
   returns the module's exports, a call like any other, run when
   reached, reading a file and waiting for it -- fine on a server's
   disk, impossible in a page, where a file is a request that takes
   time. AMD (James Burke's RequireJS, 2009) for pages: define(names,
   function), the function called when the files have come. A program
   written for one did not run on the other.

   cs-history:
   ES2015 put modules in the language, after years of argument, with
   the choice told above: import and export are syntax, static, so a
   page's graph can be fetched before running and a server's read at
   once. Browsers ran them from 2017 (<script type=module>: Safari
   10.1, Chrome 61; Firefox 60 in 2018), import() is ES2020's. Node
   took until 2019 to run both kinds side by side (.mjs).

   evolution:
   Before browsers ran modules, programs were written in them
   anyway and a bundler (Browserify, 2011; webpack, 2012; Rollup,
   2015, which named tree shaking: leaving out what no import names)
   turned the graph into one file of the old kind. They still do: a
   page of four hundred modules is four hundred requests. What a real
   site sends is modules that were bundled into a few modules.

   modern:
   What is not here: top-level await (ES2022: a module's body
   waiting, and its importers with it), import maps (a page's table
   from bare names like "react" to addresses), JSON and CSS modules,
   strict mode (a module is always strict). A real engine also links
   in a pass of its own, before running anything, and reports a name
   that no module exports for the whole graph at once; here it is
   found when the importer is reached.

   mini-node's require (tools/node's Node_host) is the other
   convention, CommonJS, in sixty lines: compare. (That is
   mini-chrome's mini-node; ix's has no require, nor this module: a
   file given to it is a script.)

   Where it stands: the host is Script_modules, for a page's <script
   type=module>: it resolves a specifier against the importer's URL,
   fetches the graph's texts before any runs ([specifiers]), and
   answers import() later ([set_dynamic]). This module calls Js_eval
   for a scope under the globals and to run a body in it, and
   Js_parse, whose trees it keeps by their text ([ahead]: a text
   parsed where it was fetched is not parsed again).

   design:
   A graph of files known from their texts alone, before any runs,
   is what a builder needs, and it is the rule ix's own sources
   follow: an OCaml file names the modules it uses, ocamldep reads
   that without compiling anything, and mini-mk compiles them in the
   order found. CommonJS's require, a call whose argument is
   computed, is the other choice, C's #include a third (a text
   pasted, no names of its own): of the three only the static import
   lets a tool leave out what nobody names.

   Reference: ECMAScript 2015, section 15.2 (modules); HTML Living
   Standard, 8.1.3.7 (module scripts: fetching the graph); Axel
   Rauschmayer, Exploring ES6, chapter 16. *)
(* ix: the author's mini-chrome's languages/javascript/eval/Js_module.mli (its 8af888e) (docs/plans/plan_browser.md) *)

type t

(* [create engine ~resolve ~source]: modules for an engine. [resolve
 * ~base spec]: the address of the module [spec] names in the module
 * at [base]; [source url]: its text, if the host has it *)
val create : Js_eval.t -> resolve:(base:string -> string -> string) -> source:(string -> string option) -> t

(* [run t url]: the module at that address run, with all it imports
 * (each once, ever); its names, as the object import * gives. An
 * error: a text missing, one that does not parse, a name not
 * exported, what its body throws *)
val run : t -> string -> (Js_value.value, Js_eval.error) result

(* the same inside a run (a host's function called by a script, a
 * task): throws *)
val import : t -> string -> Js_value.value

(* after an error: the address of the module whose body threw (the
 * innermost, if it was one imported), once *)
val take_failing : t -> string option

(* the modules a module's text names (its imports, its exports from),
 * as written, in order: for a host to fetch them before running it *)
val specifiers : string -> string list

(* [set_dynamic t load]: what import() does for a module not run yet:
 * [load url ready failed], the host's, which fetches the module and
 * all it imports and then calls [ready] (in a run), or [failed why] *)
val set_dynamic : t -> (string -> (unit -> unit) -> (string -> unit) -> unit) -> unit

(* a module's text read ahead and kept for the module system to find
 * it read: to be called where the text was fetched, off the window's
 * thread (the parser shares nothing; the memo is behind a lock) *)
val ahead : string -> unit
