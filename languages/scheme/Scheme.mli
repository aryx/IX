(* Scheme: the values of a small Scheme, the code they run, and how
   they print.

   Scheme (Guy Steele and Gerald Sussman, MIT, 1975) is Lisp cut down
   to what cannot be defined from the rest: variables whose scope is
   the text around them (lexical scope, where Emacs Lisp's is dynamic,
   Lisp_eval.mli), so that a lambda closes over the variables it sees
   -- a *closure*; procedures that are values like any other; calls in
   tail position that don't grow the stack, so a loop is a procedure
   calling itself; and the continuation, the rest of the computation,
   made a value by call/cc. Sussman and Steele wrote it to understand
   Hewitt's actors, and found that an actor was a closure ("Scheme: An
   Interpreter for Extended Lambda Calculus", MIT AI Memo 349, 1975).

   Where it differs from Emacs Lisp's values (Lisp.mli): false (#f)
   and the empty list ('()) are two things; a procedure is a closure,
   code and the environment it was made in, not a list; and pairs
   here can't be changed -- no set-car! -- as in Racket since 2008
   (PLT Scheme 4.0, whose mcons is the mutable kind): only variables
   change, with set!, and they live in the machine's store
   (Scheme_eval.mli). HtDP's teaching languages add structures
   (define-struct) and images (Scheme_image.mli) as values.

   The code is here too, because a closure holds code and a
   continuation holds frames of code: Scheme_syntax.mli makes the
   [expr] from the text, Scheme_eval.mli runs it.

   (Lisp.mli and Lisp_eval.mli are the playground's Emacs Lisp, which
   ix does not have; the comparison is kept for what it says.)

   A closure, on the smallest example:

       (define (adder n) (lambda (x) (+ x n)))
       (define add3 (adder 3))
       (add3 4)                                     7

       add3 = Closure ({ params = ["x"]; body = (+ x n); ... },
                       [("n", l)])          and the store has l -> 3

   The call (adder 3) has returned and its n is still there, since
   what the closure holds is not n's value on a stack but n's place
   in the store, which nothing takes back. Two closures made by one
   call share the place: one's set! is seen by the other, which is
   all an object with private state is.

   terminology:
   *Closure* is Peter Landin's word (1964): an expression "closed" by
   the environment that gives its free variables a meaning. Lexical,
   or static, scope: a name means what the text around the lambda
   says; dynamic scope: what the caller's bindings say when the
   procedure runs. A *continuation* is what remains to be done with a
   value ([kont]); *first-class* says a thing can be passed, returned
   and stored like a number, which Scheme asks of procedures and of
   continuations.

   cs-history:
   Lisp had lambda from the start (McCarthy, 1960) and for fifteen
   years gave it dynamic scope, at first by accident of the first
   interpreter: a function passed as an argument found the caller's
   variables under its own names, the "funarg problem", patched with
   a special form, FUNCTION, that kept the environment. Algol 60 had
   lexical scope and no procedures as values to return. Scheme put
   the two together and showed that nothing else was needed, and
   every Lisp since has followed: Common Lisp (1984), and Emacs Lisp
   at last, file by file, since 2012.

   References: Peter Landin, "The Mechanical Evaluation of
   Expressions" (Computer Journal, 1964), for the closure. Joel
   Moses, "The Function of FUNCTION in LISP" (1970). Guy Steele and
   Gerald Sussman, "The Art of the Interpreter, or the Modularity
   Complex" (MIT AI Memo 453, 1978): scope, state and what each
   costs, an interpreter at a time. *)

(*****************************************************************************)
(* {1 Values} *)
(*****************************************************************************)

type t =
  | Int of int
  | Real of float
  | Bool of bool
  | Char of int
  | Str of string
  | Sym of string
  | Nil (* '(), empty *)
  | Pair of t * t
  | Vector of t array (* never changed: no vector-set! *)
  | Struct of string * t list (* a posn and its fields: (make-posn 1 2) *)
  | Image of Scheme_image.t
  | Proc of proc
  | Void (* what define, set! and display give back: nothing printed *)

and proc =
  | Prim of string (* a built-in, by name: #<procedure:car> *)
  | Closure of lambda * env
  | Cont of kont (* a continuation, made by call/cc *)
  | Make of string * int (* a structure's constructor, and its field count *)
  | Get of string * int * string (* a selector: the structure, the field's index, name *)
  | Is of string (* a predicate: posn? *)

(*****************************************************************************)
(* {1 Code} *)
(*****************************************************************************)

(* a variable's place in the store (Scheme_eval.mli) *)
and loc = int

(* the local variables in scope, innermost first; the globals are the
   machine's *)
and env = (string * loc) list

and expr = { desc : desc; span : Sexpr.span }

and desc =
  | Quote of t (* a constant: 1, "a", '(a b) *)
  | Var of string
  | Lambda of lambda
  | If of expr * expr * expr
  | Set of string * expr
  | App of expr * expr list
  | Seq of expr list (* begin, never empty *)
  | Define of string * expr (* at the top only: a global *)
  | Define_struct of string * string list
  | Big_bang of expr * (string * expr) list (* the world, and [on-tick f] ... *)

and lambda = {
  params : string list;
  rest : string option; (* (lambda (a . rest) ...) *)
  locals : string list; (* the body's own defines, as letrec* makes them *)
  body : expr list;
  name : string; (* what defined it, for printing; "" for an anonymous one *)
}

(* what is left to do with the value being computed: Felleisen's
   continuation, a stack of frames each holding what it needs *)
and kont =
  | Halt
  | K_if of expr * expr * env * kont (* the branches *)
  | K_app of t list * expr list * env * Sexpr.span * kont (* values so far (backwards), arguments left *)
  | K_set of loc * kont
  | K_seq of expr list * env * kont (* the rest of a begin *)
  | K_define of string * kont
  | K_big_bang of t list * (string * expr) list * string list * env * Sexpr.span * kont

(*****************************************************************************)
(* {1 Printing} *)
(*****************************************************************************)

(* DrScheme prints a value in two ways, set by the language: Scheme's,
   (1 2 3) and #t, which read gives back as data; and the teaching
   languages', (list 1 2 3) and true, which evaluated give the value
   back -- the expression that makes it, so a student never sees a
   quote. *)
type style = Write | Constructor

(* [print style v]: v written; an image as #<image>, or in the
   teaching languages as the expression that makes it (a screen draws
   it instead); a string in quotes *)
val print : style -> t -> string

(* how display writes it, for people: strings and characters as
   themselves *)
val display : t -> string

(* [list [a; b]] is (a b); [to_list] the elements of a proper list *)
val list : t list -> t
val to_list : t -> t list option

(* anything but #f is true *)
val truthy : t -> bool

(* equal?: the same structure; eqv? on the leaves *)
val equal : t -> t -> bool

(* a type's name, for the errors: "number", "list", "procedure" *)
val kind : t -> string
