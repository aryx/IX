(* mini-node: JavaScript run outside a page (Node.js, Ryan Dahl, 2009,
 * is V8 so taken out of Chrome), after the author's mini-chrome's
 * tools/node. A file's statements run, console.log on standard
 * output; or a line read, run and its value shown, until the input
 * ends, as a console.
 *
 *     mini-node file.js       mini-node -e 'console.log(6 * 7)'
 *     echo '1 + 1' | mini-node
 *
 * The program is forty lines (CLI.ml): the rest of this directory is
 * the engine, a library, and this is where it is presented whole. A
 * text is cut into tokens, the tokens made a tree, and the tree is
 * walked:
 *
 *     characters                         the modules, a script's way
 *        | Js_lexer    a newline remembered (a semicolon not written),
 *        |             a / told from a regular expression's
 *     tokens
 *        | Js_parse    statements by recursive descent, expressions
 *        |             by Pratt's binding powers
 *     Js_ast.program
 *        | Js_quicken  the tree copied, a place to remember at each name
 *        | Js_eval     walks it
 *        |-- Js_scope, Js_frame      where the names live; a call's frame
 *        |-- Js_compile              a function's body made OCaml
 *        |                           closures at its first call
 *        |-- Js_value, Js_props      a value; an object's properties and
 *        |                           its chain of prototypes
 *        |-- Js_operators, Js_utf16  + and ==, the conversions; a string
 *        |                           counted in UTF-16's units
 *        |-- Js_builtins, Js_globals String, Array, Math, Map, Proxy...
 *        |-- Js_prelude              the library's part written in
 *        |                           JavaScript itself
 *        |-- Js_json, Js_regexp      JSON.parse; /a(b+)c/ by backtracking
 *        |-- Js_promise              then's jobs, run when the script
 *        |                           has returned
 *        |-- Js_coroutine            an async function stopped at an await
 *        '-- Js_module               import and export, the texts asked
 *                                    of the host
 *
 * The same three stages as the shell's (the diagram of mini-rc's
 * CLI.mli: Lexer, Parser, an Eval that walks the tree), for a language
 * of floats, objects and closures where rc's has lists of strings.
 * Each module's interface has its part of the story; Js_eval.mli has
 * the language's.
 *
 * design:
 * The engine is a language and nothing else: it cannot print, wait,
 * read a file, nor be given a second file. Everything of the kind is
 * its host's, given when the engine is made (Js_eval.create_with: where
 * console.log writes, Math.random's seed, the clock) or defined after
 * as a global (Js_eval.define). ix has two hosts. This one, a
 * terminal: the standard output and the clock, no more. And a page
 * (Browser_script, for mini-netscape): document, window, the events,
 * the timers on the frames' clock, the scripts and modules fetched
 * from the network. So the engine's modules take no capability, and
 * this file's caps are all that mini-node may do.
 *
 *     the engine (this directory)   the language: values, functions,
 *              |                    promises -- no way out
 *       +------+---------+
 *       |                |
 *     Browser_script     CLI
 *     a page             a terminal
 *     document, events   console (the standard output)
 *     timers, fetch      a file read, a line read
 *     <script src>
 *
 * cs-history:
 * JavaScript outside a browser is as old as JavaScript: Netscape's
 * server ran it in 1995 (LiveWire), and Rhino (1997) ran it on Java's
 * machine. Neither caught on. Ryan Dahl's Node.js (2009) did, and
 * not for the language: he wanted a server that never blocks -- one
 * loop, every call to the network or the disk given a function to
 * call back -- and found in JavaScript the one popular language whose
 * programmers already wrote that way, because a page's script has
 * always been one thread and its events; V8 (2008) made it fast
 * enough. Its modules were CommonJS's (2009), a convention agreed on
 * by people who needed one before the language had any (ES2015's
 * import came six years later, and the two live side by side still);
 * npm (Isaac Schlueter, 2010) made them a registry of millions. Deno
 * (Dahl again, 2018) and Bun (2022) are its critics.
 *
 * The command line: its usage is [usage] in CLI.ml, what a wrong
 * argument prints. A file or -e's text is one script: its status is 0,
 * or 1 with "line 3: ReferenceError: x is not defined" on the standard
 * error if it ends by an error not caught. With no argument each line
 * of the input is a script of its own in the same engine (a let of one
 * line is there for the next), its value shown as a console shows it,
 * or its error, and a "> " before each if the input is a terminal:
 *
 *     > let x = [1, "a", {b: 2}]
 *     undefined
 *     > x.map(v => typeof v)
 *     ["number", "string", "object"]
 *     > foo
 *     ReferenceError: foo is not defined
 *
 * Not Node's: require, process, modules, files, the network, timers
 * (the language alone: Js_eval's built-ins). mini-chrome's has them
 * (its Node_host: require by CommonJS's wrapper function, "fs", and a
 * loop that sleeps until the earliest timer is due); here a script
 * runs to its end, then its promises' jobs, and the program ends.
 *
 * References: Ryan Dahl's talk at JSConf EU, 2009, where Node was
 * shown first; Node.js's documentation, "The Node.js Event Loop" and
 * "Modules: CommonJS modules", for what is not here; Brendan Eich and
 * Allen Wirfs-Brock, "JavaScript: The First 20 Years" (HOPL IV, 2020),
 * the language's history by those who made it. *)

type caps = < Cap.open_in; Cap.stdin; Cap.stdout; Cap.stderr >

(* the program's status: 0, 1 for a script that failed, 2 for the usage *)
val main : < caps; .. > -> string array -> int
