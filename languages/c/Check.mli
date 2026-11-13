(* The machine-independent passes over an expression (com.c, sub.c,
 * scon.c, acom.c). Each pass is a function from a tree to a tree:
 * - the typing, [tcom], which inserts the conversions and checks the
 *   operands against Tree's tables;
 * - the rewrites of comma expressions, the simplifications and the
 *   constant folding (ccom, evconst);
 * - then the back end's [xcom].
 * [complex] runs all of them. 5c's arithmetic rewrites (acom) belong to
 * the compat back end (Acom), which runs them from its xcom.
 *
 * This is Plan 9's C, not ANSI's: unsigned char and unsigned short
 * promote to unsigned int, and double op float is computed as a float
 * (cck's table). The listing depends on both.
 *
 * The passes have effects: the typing writes the data of the strings,
 * in the order the expressions come, as 5c does.
 *
 * What the tree gains, with int *p, int i, x and char c (on arm):
 *
 *     p[i] + c     from the parser: the content of p + i, plus c
 *       tcom       i is converted to p's type and multiplied by 4, the
 *                  size of what p points to; c is converted to int;
 *                  every node is given its type
 *     3*4 + x*1
 *       ccom       12 + x: the constants are computed, and the product
 *                  by 1 is gone
 *     x - 5
 *       ccom       x + -5, which leaves one operator less for what
 *                  follows
 *
 * After [complex] the tree says everything C leaves unsaid, and a
 * back end never asks what the language means by an operator: an
 * addition has two operands of one type, and a conversion is a node.
 *
 * others:
 * The question is which type a small unsigned type becomes. Here, as
 * in the Unix compilers before ANSI, the sign is kept: an unsigned
 * char is promoted to unsigned int. ANSI C chose to keep the value
 * instead, and promotes it to int, which holds every unsigned char.
 * The two rules differ when the result meets a negative number:
 *
 *     unsigned char u;      u < -1      here 1: the comparison is
 *                                       unsigned, and -1 is the largest
 *                                       ANSI 0: u is an int, not negative
 *
 * (mini-cc -S writes CMN $1 then BHS, the unsigned branch.) The
 * committee's Rationale gives the argument, and calls the two rules
 * unsigned preserving and value preserving.
 *
 * References: Ken Thompson, "Plan 9 C Compilers", sections "Typing"
 * ("Implicit operations on the tree are added, such as type promotions
 * and taking the address of arrays and functions") and
 * "Machine-independent optimization"; the Rationale published with
 * ANSI C (1989), section 3.2.1.1, "Characters and integers", for the
 * promotions. *)

(* what the front end asks of the back end, set by the command (CLI) *)
val outstring : (string -> int -> int) ref
val xcom : (Tree.expr -> Tree.expr) ref
(* the trees for the .NET back end, whose places are typed (a member is
 * a field, an array is an array). A member is kept as a Dot of its
 * structure, which is an l-value when the structure is one, rather than
 * as the content of the structure's address plus the member's offset.
 * An array that is used is the address of the array, not of its first
 * element. *)
val managed : bool ref

(* the value of a small integral constant, or -159 *)
val vconst : Tree.expr -> int

(* log2 of a power-of-two constant, or -1 *)
val vlog : Tree.expr -> int

(* a conversion that makes no code *)
val nocast : Tree.typ -> Tree.typ -> bool

(* a conversion that means nothing: from small to large, within one
 * kind *)
val nilcast : Tree.typ -> Tree.typ -> bool

(* mkt makes a node of type t at the line diagnosed; konst makes a
 * constant, and cast_to a cast; ival gives a constant's value, or 0
 * (for compat's Acom) *)
val mkt : Tree.typ -> Tree.kind -> Tree.expr
val konst : int64 -> Tree.typ -> Tree.expr
val cast_to : Tree.expr -> Tree.typ -> Tree.expr
val ival : Tree.expr -> int64

(* an error unless the operator's table takes the operands' types *)
val tcompat : Tree.expr -> Tree.typ -> Tree.typ -> (Tree.etype -> Tree.etype -> bool) -> unit

(* a relation with its operands swapped (invrel), and a relation negated
 * (comrel) *)
val invrel : Tree.binop -> Tree.binop
val comrel : Tree.binop -> Tree.binop

(* the typing of n, which makes its conversions into nodes; an array or
 * a function that is used becomes its address *)
val tcom : Tree.expr -> Tree.expr

(* all the passes, then the back end's xcom. complex_ret does the same
 * for a function's result, converted to the result's type. *)
val complex : Tree.expr -> Tree.expr
val complex_ret : Tree.typ -> Tree.expr -> Tree.expr
