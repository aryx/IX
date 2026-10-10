(* The interpreter: what code.c's stack machine does, on the trees.
 *
 * A function's formals are not local names: for the time of a call the
 * formal's own symbol is the argument, and gets back what it was at
 * the return (so a function called from the body sees them). Both
 * operands of && and || are evaluated. A Symbol.Error stops the line.
 *
 *     func g() { return n }
 *     n = 5
 *     func f(n) { return g() }
 *     f(7)
 *     7               g sees f's n, not the 5
 *     n
 *     5               which is back after the call
 *
 * terminology:
 * That is dynamic scope: a name means what the last call still
 * running made it. It is the first Lisp's, and the shells' (a local
 * of rc's, x=1 cmd, is seen by what cmd calls), and costs one saved
 * value a call. Lexical scope, a name meaning what the text around
 * it says (Algol 60, Scheme, C, OCaml), wants an environment a call,
 * and a closure if a function is a value: mini-scheme's
 * interpreter has them (Scheme_eval).
 *
 * design:
 * Why a tree, or a machine's code, at all. The book's first three
 * hocs compute in the grammar's actions: when the parser has seen
 * 2 + 3 it adds. That holds until hoc5: a while's body must run many
 * times and a function's later, but an action runs once, when its
 * text is read. So hoc4 makes the actions write instructions for a
 * stack machine, run when the line is whole, and code.c is that
 * machine. A tree is the same thing kept in another shape, and the
 * one a language with variants makes easy: Ast is hoc.y's program,
 * and [run] a match where code.c has a function an instruction. *)

type caps = < Input.caps; Cap.stdout >

(* a line run: a statement, or an expression whose value is printed and
 * kept as _ *)
val run : < caps; .. > -> Ast.line -> unit

(* a number as hoc prints it: Plan 9's %.12g *)
val number : float -> string
