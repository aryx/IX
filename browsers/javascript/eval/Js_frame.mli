(* A call's frame: the scope a function's body runs in, and what is in
   it before the body's first line.

     function add(a, b) { var sum = a + b; return sum }
     add(1, 2)

     the scope add was written in
       the call's frame    arguments = [1, 2]     what it was given, all of it
                           sum       = undefined  its var's, there from the start ("hoisted")
                           a = 1, b = 2           its parameters

   A frame goes under the scope the function was written in (the
   closure's), not under the caller's. In it, in this order: arguments;
   the function's own name, if it is a function expression's (var f =
   function again(n) { ... again(n - 1) }: again is the function in
   its body, whatever again is outside; a declaration's name is its
   scope's, and is not here); every var of the body, wherever it is written,
   undefined; then the parameters, each bound to what the call gave --
   which is the evaluator's part ([params]): a parameter can be a
   pattern and can have a default, an expression read in the frame.

   **The simple way** ([simple]) does just that, a name declared after
   the other in the frame.

   **The fast way** ([opti]). What a call declares is known from the
   function's text: the same names in the same order at every call.
   So it is found once ([layout], kept in the function's tree by
   Js_quicken: Js_ast.frame), and a call makes its frame in one go: an
   array of bindings beside the layout's array of names, which every
   call of the function shares; the parameters, when they are all
   plain names, are set by their slot's number, with no name compared
   (with a pattern or a default among them, they are the evaluator's
   as in [simple]). The same frame in the end as [simple]'s, whose
   words these are in another order.

   cs-history:
   var's hoisting is of the ten days of 1995 (Js_eval.mli): a name's
   scope was the function, as in C a label's, and a block made none.
   let and const (ES2015) are the block's, and are not here: the
   evaluator declares them as it meets them. arguments is as old: a
   function could be given more than it names before there were rest
   parameters (...xs, ES2015). *)
(* ix: the author's mini-chrome's languages/javascript/eval/Js_frame.mli (its 8af888e) (docs/plans/plan_browser.md) *)

open Js_value

(* the parameters bound in a frame to what the call gave: the frame,
 * the call's this, the parameters and the rest one, the values *)
type params = scope -> value -> (Js_ast.pattern * Js_ast.expr option) list -> Js_ast.pattern option -> value list -> unit

(* the names a pattern binds *)
val pattern_names : Js_ast.pattern -> string list

(* the names a body's var's declare, a block's and a loop's too, not an
 * inner function's *)
val hoisted : Js_ast.stmt list -> string list

(* those names declared in a scope, undefined, but the ones it has *)
val hoist : scope -> Js_ast.stmt list -> unit

(* what every call of a function declares; [arguments] (true): whether
 * its text says arguments, which the caller knows (Js_quicken) *)
val layout_with : arguments:bool -> Js_ast.func -> Js_ast.frame

(* the same, with arguments (ix: it was layout's ?arguments) *)
val layout : Js_ast.func -> Js_ast.frame

(* [simple ~params c fn this args ~strict]: the frame of a call of the
 * closure [c] (the function value [fn]) with [args] *)
val simple : params:params -> closure -> value -> value -> value list -> strict:bool -> scope

(* opti: the same from the function's layout *)
val opti : params:params -> Js_ast.frame -> closure -> value -> value -> value list -> strict:bool -> scope

(* the fast way if the function has a layout and its scope is of the
 * fast kind (Js_scope), else the simple one *)
val make : params:params -> closure -> value -> value -> value list -> strict:bool -> scope
