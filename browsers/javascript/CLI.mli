(* mini-node runs JavaScript outside a page, as Node.js does (Ryan Dahl,
 * 2009; Node is V8 taken out of Chrome for that). It follows tools/node
 * in the author's mini-chrome. It runs a file's statements, and
 * console.log writes on the standard output. Or, like a console, it
 * reads a line, runs it and shows its value, until the input ends.
 *
 *     mini-node file.js       mini-node -e 'console.log(6 * 7)'
 *     echo '1 + 1' | mini-node
 *
 * The program itself is forty lines (CLI.ml). The rest of this
 * directory is the engine, which is a library, and this comment is
 * where the engine is presented whole. A text is cut into tokens, the
 * tokens are made into a tree, and the tree is walked:
 *
 *     characters                         the modules, in a script's order
 *        | Js_lexer    remembers a newline (where a semicolon is left
 *        |             out), tells a / from a regular expression's
 *     tokens
 *        | Js_parse    reads statements by recursive descent, and
 *        |             expressions by Pratt's binding powers
 *     Js_ast.program
 *        | Js_quicken  copies the tree, with a place to remember at
 *        |             each name
 *        | Js_eval     walks it
 *        |-- Js_scope, Js_frame      where the names live; a call's frame
 *        |-- Js_compile              makes a function's body into OCaml
 *        |                           closures at its first call
 *        |-- Js_value, Js_props      a value; an object's properties and
 *        |                           its chain of prototypes
 *        |-- Js_operators, Js_string  + and ==, the conversions; a string
 *        |                           counted in UTF-8's bytes
 *        |-- Js_builtins, Js_globals String, Array, Math, Map, Reflect...
 *        |-- Js_prelude              the part of the library written in
 *        |                           JavaScript itself
 *        |-- Js_json, Js_regexp      JSON.parse; /a(b+)c/ by backtracking
 *        |-- Js_promise              the jobs of then, run when the script
 *        |                           has returned
 *        '-- Js_coroutine            an async function stopped at an await
 *
 * These are the same three stages as the shell's (see the diagram in
 * mini-rc's CLI.mli: a Lexer, a Parser, and an Eval that walks the
 * tree), but for a language of floats, objects and closures, where
 * rc's language has lists of strings. Each module's interface tells
 * its part of the story, and Js_eval.mli tells the language's.
 *
 * design:
 * The engine is a language and nothing else: it cannot print, wait or
 * read a file, nor can it be given a second file. Everything of that
 * kind belongs to its host. The host gives it when the engine is made
 * (Js_eval.create_with: where console.log writes, Math.random's seed,
 * the clock), or defines it afterwards as a global (Js_eval.define).
 * ix has two hosts. This one is a terminal, which gives the standard
 * output and the clock, and no more. The other is a page
 * (Browser_script, for mini-netscape), which gives document, window,
 * the events, the timers on the frames' clock, and the scripts
 * fetched from the network. So the engine's modules take no
 * capability, and this file's caps are all that mini-node may do.
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
 * server ran it (LiveWire, planned in 1995, shipped in 1996), and
 * Rhino (1997) ran it on Java's machine. Neither caught on. Ryan
 * Dahl's Node.js (2009) did, and not for the language. He wanted a
 * server that never blocks, with one loop, where every call to the
 * network or the disk is given a function to call back. He found in
 * JavaScript the one popular language whose programmers already wrote
 * that way, because a page's script has always been one thread and its
 * events; V8 (2008) made it fast enough. Its modules followed CommonJS
 * (2009), a convention agreed on by people who needed one before the
 * language had any (ES2015's import came six years later, and the two
 * still live side by side). npm (Isaac Schlueter, 2010) made them a
 * registry of millions. Deno (Dahl again, 2018) and Bun (2022) are its
 * critics.
 *
 * The command line's usage is [usage] in CLI.ml, which is what a wrong
 * argument prints. A file, or the text given to -e, is one script. Its
 * status is 0, or 1 if the script ends by an error that is not caught;
 * the error is then printed on the standard error, as in "line 3:
 * ReferenceError: x is not defined". With no argument, each line of
 * the input is a script of its own, run in the same engine (so a let
 * on one line is still there for the next). Its value is shown as a
 * console shows it, or else its error is, and a "> " is printed before
 * each line if the input is a terminal:
 *
 *     > let x = [1, "a", {b: 2}]
 *     undefined
 *     > x.map(v => typeof v)
 *     ["number", "string", "object"]
 *     > foo
 *     ReferenceError: foo is not defined
 *
 * Node's require, process, files, network and timers are not here:
 * there is only the language (Js_eval's built-ins). mini-chrome's
 * mini-node has them, in its Node_host: require through CommonJS's
 * wrapper function, "fs", and a loop that sleeps until the earliest
 * timer is due. Here a script runs to its end, then its promises' jobs
 * run, and the program ends.
 *
 * References: Ryan Dahl's talk at JSConf EU, 2009, where Node was
 * first shown; and Node.js's documentation, "The Node.js Event Loop"
 * and "Modules: CommonJS modules", for what is not here. The
 * language's history and its reference are in Js_eval. *)

type caps = < Cap.open_in; Cap.stdin; Cap.stdout; Cap.stderr; Cap.clock >

(* returns the program's status: 0, or 1 for a script that failed, or 2
 * for a wrong usage *)
val main : < caps; .. > -> string array -> int
