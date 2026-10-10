(* Sexpr: s-expressions as read, before a Lisp gives them a meaning.

   Every Lisp writes its programs as its data's printed form, so the
   Lisps share their syntax and differ in their values: Emacs Lisp's
   nil is false and the empty list at once, Scheme's #f and '() are
   two things; Scheme's closures and mutable pairs have no Emacs
   counterpart. So the reader is shared (Sexpr_read.mli) and gives a
   neutral tree, this one, which each dialect turns into its own
   values -- languages/lisp's Lisp_read for Emacs, languages/scheme's
   for Scheme.

   What the tree adds to the text is where each part of it came from,
   its [span]: DrScheme paints the expression that failed in pink, and
   its stepper the one about to be reduced, and both need to know which
   characters those were.

       (+ 1 2)   is   List ([Sym "+" at 1-2; Int 1 at 3-4; Int 2 at 5-6], None)
                      at 0-7

   (ix has the Scheme alone: the Emacs Lisp is the playground's, and
   Sexpr_read keeps its dialect for it.)

   Where it stands: Sexpr_read makes the tree; Scheme_syntax turns it
   into code and Scheme_step into terms to rewrite; mini-drscheme
   uses the spans to paint.

   cs-history:
   The S in S-expression is for "symbolic", and the notation was not
   meant for programs. John McCarthy's paper (1960) writes Lisp's
   functions in another one, M-expressions, car[cons[x; y]], and
   uses S-expressions for the data they work on; to define eval, a
   function taking a program, he gave a way to write an M-expression
   as an S-expression. Steve Russell then coded eval by hand for the
   IBM 704, and what could be typed and run was the S-expressions.
   The M-expressions were never implemented, and Lisp's programmers
   found they did not want them: a program that is a list can be
   made, taken apart and rewritten by a program, which is what a
   macro is (Scheme_syntax.mli does it in OCaml).

   others:
   The same bargain later, for data alone: XML and JSON are trees
   with one syntax for everything, read by one small reader, and
   JSON is a programming language's literals cut out of it as
   S-expressions are Lisp's. What neither took is the other half,
   programs in the same notation. *)

(* the characters [start] to [stop] (excluded) of the text read *)
type span = { start : int; stop : int }

type t = { datum : datum; span : span }

and datum =
  | Int of int
  | Float of float
  | Str of string
  | Sym of string
  | Char of int (* Emacs's ?a, Scheme's #\a: the character's code *)
  | Bool of bool (* Scheme's #t and #f; Emacs has none *)
  | List of t list * t option (* (a b), or (a b . c) with its tail *)
  | Vector of t list (* Scheme's #(a b) *)

(* [make d span] and [sym name span] *)
val make : datum -> span -> t
val sym : string -> span -> t

(* the span of none of the text, for a tree made by a program *)
val nowhere : span

(* the tree printed back, spans forgotten, as Scheme writes it: for
   tests and error messages *)
val to_string : t -> string
