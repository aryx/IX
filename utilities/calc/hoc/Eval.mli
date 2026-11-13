(* The interpreter: it does what code.c's stack machine does, on the
 * trees.
 *
 * A function's formals are not local names. For the time of a call,
 * the formal's own symbol holds the argument, and it gets back what it
 * held before at the return (so a function called from the body sees
 * the formals). Both operands of && and || are evaluated. A
 * Symbol.Error stops the line.
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
 * running made it mean. It is the first Lisp's scope, and the shells'
 * (a local of rc's, as in x=1 cmd, is seen by what cmd calls), and it
 * costs one saved value for each call. Lexical scope, where a name
 * means what the text around it says (Algol 60, Scheme, C, OCaml),
 * needs an environment for each call, and a closure if a function is
 * a value: mini-scheme's interpreter has them (Scheme_eval).
 *
 * design:
 * Why have a tree, or a machine's code, at all? The book's first three
 * hocs compute in the grammar's actions: when the parser has seen
 * 2 + 3, it adds. That works until hoc5: a while's body must run many
 * times, and a function's body later, but an action runs once, when
 * its text is read. So hoc4 makes the actions write instructions for a
 * stack machine, which are run when the line is whole, and code.c is
 * that machine. A tree is the same thing kept in another shape, and
 * it is the shape that a language with variants makes easy: Ast is
 * hoc.y's program, and [run] is a match where code.c has a function
 * for each instruction. *)

type caps = < Input.caps; Cap.stdout >

(* runs a line: a statement, or an expression whose value is printed
 * and kept as _ *)
val run : < caps; .. > -> Ast.line -> unit

(* a number as hoc prints it: Plan 9's %.12g *)
val number : float -> string
