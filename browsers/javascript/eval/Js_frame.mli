(* A call's frame is the scope a function's body runs in. This module
   says what is in it before the body's first line.

     function add(a, b) { var sum = a + b; return sum }
     add(1, 2)

     the scope add was written in
       the call's frame    arguments = [1, 2]     what it was given, all of it
                           sum       = undefined  its var's, there from the start ("hoisted")
                           a = 1, b = 2           its parameters

   A frame goes under the scope the function was written in (the
   closure's), not under the caller's. It holds, in this order:
   - arguments;
   - the function's own name, if it is a function expression's. In
     var f = function again(n) { ... again(n - 1) }, again is the
     function in its body, whatever again is outside. A declaration's
     name belongs to its scope, and is not here;
   - every var of the body, wherever it is written, as undefined;
   - then the parameters, each bound to what the call gave. That is
     the evaluator's part ([params]), because a parameter can be a
     pattern and can have a default, an expression read in the frame.

   **The simple way** ([simple]) does just that, declaring one name
   after the other in the frame.

   **The fast way** ([opti]): what a call declares is known from the
   function's text, as the same names in the same order at every
   call. So it is found once ([layout], which Js_quicken keeps in the
   function's tree: Js_ast.frame), and a call makes its frame in one
   go. The frame is an array of bindings beside the layout's array of
   names, which every call of the function shares. When the
   parameters are all plain names, they are set by their slot's
   number, with no name compared; with a pattern or a default among
   them, they are the evaluator's part, as in [simple]. In the end the
   frame is the same as [simple]'s, with the same names in another
   order.

   cs-history:
   var's hoisting dates from the ten days of 1995 (Js_eval.mli): a
   name's scope was the function, as a label's is in C, and a block
   made no scope. let and const (ES2015) belong to the block, and are
   not here: the evaluator declares them as it meets them. arguments
   is as old: it let a function be given more than it names, before
   there were rest parameters (...xs, ES2015). *)
(* ix: copied from languages/javascript/eval/Js_frame.mli in the
 * author's mini-chrome, at its commit 8af888e (docs/plans/plan_browser.md) *)

open Js_value

(* binds the parameters in a frame to what the call gave. It is given
 * the frame, the call's this, the parameters, the rest parameter, and
 * the values. *)
type params = scope -> value -> (Js_ast.pattern * Js_ast.expr option) list -> Js_ast.pattern option -> value list -> unit

(* the names a pattern binds *)
val pattern_names : Js_ast.pattern -> string list

(* the names that a body's vars declare, including those in its blocks
 * and loops, but not those of an inner function *)
val hoisted : Js_ast.stmt list -> string list

(* declares those names in a scope, as undefined, except the ones the
 * scope already has *)
val hoist : scope -> Js_ast.stmt list -> unit

(* what every call of a function declares. [arguments] says
 * whether its text uses arguments, which the caller knows
 * (Js_quicken). *)
val layout_with : arguments:bool -> Js_ast.func -> Js_ast.frame

(* the same, with arguments true (ix: in mini-chrome, layout has an
 * optional ?arguments) *)
val layout : Js_ast.func -> Js_ast.frame

(* [simple ~params c fn this args ~strict] makes the frame of a call of
 * the closure [c] (the function value [fn]) with [args] *)
val simple : params:params -> closure -> value -> value -> value list -> strict:bool -> scope

(* opti: the same, made from the function's layout *)
val opti : params:params -> Js_ast.frame -> closure -> value -> value -> value list -> strict:bool -> scope

(* the fast way if the function has a layout and its scope is of the
 * fast kind (Js_scope), else the simple one *)
val make : params:params -> closure -> value -> value -> value list -> strict:bool -> scope
