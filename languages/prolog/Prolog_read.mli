(* Prolog's reader: a text's clauses, one at a time, each read by the
 * operators' priorities as they are at that moment (a directive may
 * have changed them: op/3). Written by hand for that reason: the
 * grammar is not known before the text is read
 * (docs/plans/plan_prolog.md, decision 3).
 *
 * A term of priority 1200 at most, then a dot and a blank. An argument
 * and a list's element are of 999 at most (so a comma separates them).
 * An atom right before an open parenthesis is a functor; - or + right
 * before a number is its sign; a prefix operator before what cannot
 * begin a term is an atom.
 *
 * An operator has a priority, 1 to 1200, the higher the looser, and a
 * type that says where its arguments are and what they may be: x an
 * argument of a lower priority, y of the same or lower.
 *
 *     :- 1200 xfx    ; 1100 xfy    , 1000 xfy    = is < 700 xfx
 *     + - 500 yfx    * // mod 400 yfx    - (prefix) 200 fy
 *
 *     X is 1 + 2 * 3     is(X, +(1, *(2, 3)))   * binds tighter than +
 *     1 - 2 - 3          -(-(1, 2), 3)          yfx: the left side may
 *                                               be a - itself
 *     a, b, c            ','(a, ','(b, c))      xfy: the right side
 *     a = b = c          a syntax error         xfx: neither
 *
 * The reading is by precedence climbing: a term is a primary (an
 * atom, a number, a variable, f(...), a list, a term in parentheses,
 * a prefix operator and its argument), then, as long as the next
 * token is an infix operator whose priority fits under the limit
 * given, that operator and a right side read with the limit its type
 * allows. One function with a number for parameter, where a grammar
 * has a rule a level of priority (mini-yacc's %left lines are the
 * same table, fixed when the parser is made).
 *
 * cs-history:
 * A table of operators that the program may extend is as old as the
 * language's Edinburgh form (DEC-10 Prolog's op/3), and is why
 * Prolog was a language to write other languages in: a grammar's
 * rule (-->), a constraint, a small notation are a few op/3 lines
 * away, with no reader to write. The parsing method is Vaughan
 * Pratt's (1973) in its simplest form. A spreadsheet's formulas
 * (Formula) have two levels and a function each; with some forty
 * operators and more to come, the level must be data.
 *
 * References: ISO/IEC 13211-1 (1995), 6.3 (the terms' syntax, the
 * operators' table); Vaughan Pratt, "Top Down Operator Precedence"
 * (Principles of Programming Languages, 1973). *)

(* the message, the place in the text *)
exception Error of string * int

(* a text being read *)
type t

val make : Prolog.ops -> string -> t

(* the next clause and its variables by name, in the order met (not _);
 * None at the text's end *)
val next : t -> (Prolog.term * (string * Prolog.term) list) option

(* after an Error: to the end of the clause it was in *)
val skip : t -> unit

(* where the token last read starts, and a place's line (from 1) *)
val position : t -> int
val line : t -> int -> int

(* does the text end with a clause's end? (a prompt reads on if not) *)
val complete : string -> bool

(* a term, written without its final dot *)
val term : Prolog.ops -> string -> Prolog.term * (string * Prolog.term) list
