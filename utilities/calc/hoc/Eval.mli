(* The interpreter: what code.c's stack machine does, on the trees.
 *
 * A function's formals are not local names: for the time of a call the
 * formal's own symbol is the argument, and gets back what it was at
 * the return (so a function called from the body sees them). Both
 * operands of && and || are evaluated. A Symbol.Error stops the line. *)

type caps = < Input.caps; Cap.stdout >

(* a line run: a statement, or an expression whose value is printed and
 * kept as _ *)
val run : < caps; .. > -> Ast.line -> unit

(* a number as hoc prints it: Plan 9's %.12g *)
val number : float -> string
