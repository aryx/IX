(* Script_modules: a page's modules -- <script type=module>, and what
   each imports, fetched and run.

     <script type="module" src="app.js"></script>
     <script type="module">
       import { area } from "./shapes.js"
       document.body.append(area(2))
     </script>

   The language's part is Js_module's: a module's own names, its
   exports, who runs before whom. A browser's part is finding the
   texts. A module's address is a URL, and what it imports is said
   as a link is: "./shapes.js" beside the importer, "/lib/x.js" on
   its server, "https://cdn.example/x.js" anywhere ([resolve]). A
   bare name, import "react", is none: Node would look it up in
   node_modules, a browser has nowhere to look -- unless the page
   says where, in an import map (2021 in Chrome, every browser by
   2023):

     <script type="importmap">
       { "imports": { "react": "/assets/react-e27d1b.js",
                      "lib/": "/assets/lib/" } }
     </script>

   a table from names (or prefixes ending in /) to addresses, read
   before the first module. It is how a site keeps short names in its
   sources and addresses with a hash of the file's content on its
   servers, so that a file can be cached for ever and a new version
   is a new address. GitHub's pages have one.

   A script runs when reached; a module cannot, its imports must be
   there first, and they are requests. So ([load]):

     the module's text asked for (XMLHttpRequest's and fetch's way:
       Script_fetch.ask, sent by the browser, answered later)
     its text come: what it names read from it (Js_module.specifiers:
       no need to run it), and each asked for in turn, at once
     ... until nothing is missing: then the module is run, a task

   The graph is fetched as wide as it is: a module's ten imports are
   ten requests at once. The page is shown meanwhile, and a classic
   script after a module in the page runs before it: a module is
   deferred, always.

   The requests are a script's (Script_fetch), and are judged as one:
   a module from another origin must be allowed to be read
   (Access-Control-Allow-Origin), where a classic <script src> from
   anywhere runs. That is the standard's doing, on purpose: the old
   tag's freedom is a hole kept for compatibility, and what was new
   in 2017 did not get it.

   import("./late.js") at any time is the same load, and its promise
   is settled when the graph has come ([modules]' dynamic).

   What is run, and when: the jobs kept here ([take_jobs]), each a
   module's run or a promise settled, are done by Browser_script as
   tasks, after the scripts of the page and after each answer.

   modern:
   A real browser adds a module map shared by the page (here too:
   an address is fetched and run once), <link rel=modulepreload> to
   ask for the graph's files before they are found, and the choice
   by <script nomodule> -- a script for browsers that have no
   modules, which this one, having them, skips. *)
(* ix: the author's mini-chrome's src/webapi/run/Script_modules.mli (its 8af888e) (docs/plans/plan_browser.md) *)

(* the address of the module [spec] names in the module at [base]: by
 * the page's import map, else as a link; throws a TypeError for a bare
 * name no map has *)
val resolve : Script_types.t -> base:string -> string -> string

(* a <script type=importmap>'s JSON read: the page's table from names
 * to addresses ("imports"; its "scopes" are not read) *)
val read_import_map : Script_types.t -> string -> unit

(* the page's modules, made when first asked for *)
val modules : Script_types.t -> Js_module.t

(* [load t url k]: the module at [url] and all it names, fetched;
 * then [k], with why if one could not be had *)
val load : Script_types.t -> string -> ((unit, string) result -> unit) -> unit

(* [start t ~url text]: a <script type=module>: its text if it is
 * written in the page ([url] then a name for it), else fetched; its
 * graph loaded, and its run kept as a job *)
val start : Script_types.t -> url:string -> string option -> unit

(* the jobs ready since the last call, each to be run as a task *)
val take_jobs : Script_types.t -> (unit -> unit) list
