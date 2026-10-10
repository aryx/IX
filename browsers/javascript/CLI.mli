(* mini-node: JavaScript run outside a page (Node.js, Ryan Dahl, 2009,
 * is V8 so taken out of Chrome), after the author's mini-chrome's
 * tools/node. A file's statements run, console.log on standard
 * output; or a line read, run and its value shown, until the input
 * ends, as a console.
 *
 *     mini-node file.js       mini-node -e 'console.log(6 * 7)'
 *     echo '1 + 1' | mini-node
 *
 * Not Node's: require, process, modules, files, the network, timers
 * (the language alone: Js_eval's built-ins). *)

type caps = < Cap.open_in; Cap.stdin; Cap.stdout; Cap.stderr >

(* the program's status: 0, 1 for a script that failed, 2 for the usage *)
val main : < caps; .. > -> string array -> int
