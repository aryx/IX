(* Scheme_secd: Scheme run by Landin's SECD machine, the first abstract
   machine for a language of functions (Peter Landin, "The Mechanical
   Evaluation of Expressions", 1964), where Scheme_eval.mli's is the
   CESK machine that came of it twenty years later. Four registers:

       Stack        the values computed so far, the last on top
       Environment  each variable in scope (here its place in a store,
                    for set!: Landin's first machine had no assignment)
       Control      what is left to do: expressions, and "ap"
       Dump         the callers' S, E and C, to go back to

       ((lambda (x) (+ x 1)) 41), a step at a time
       (mini-scheme -secd -landin -trace; D is the dump's depth):
         S: - | E: - | C: ((lambda (x) ...) 41) | D: 0
         S: - | E: - | C: (lambda (x) ...) 41 ap | D: 0
         S: #<procedure> | E: - | C: 41 ap | D: 0
         S: 41 #<procedure> | E: - | C: ap | D: 0
         S: - | E: x=41 | C: (+ x 1) | D: 1
         S: - | E: x=41 | C: + x 1 ap | D: 1
         S: #<procedure:+> | E: x=41 | C: x 1 ap | D: 1
         S: 41 #<procedure:+> | E: x=41 | C: 1 ap | D: 1
         S: 1 41 #<procedure:+> | E: x=41 | C: ap | D: 1
         S: 42 | E: x=41 | C: - | D: 1
         then the dump gives S, E and C back: 42 on an empty control

   An application puts its parts on the control, then "ap"; "ap" finds
   the procedure and its arguments on the stack. A closure applied
   saves S, E and C on the dump and starts on its body with a stack of
   its own; when the control is empty the dump gives them back, with
   the result on top. So the stack and the dump are two halves of what
   the CESK machine has as one continuation: Felleisen and Friedman's
   paper is how the one becomes the other.

   What is not Landin's: the conditional and assignment ("sel",
   "assign": Henderson's Lispkit, 1980, has them as instructions); the
   store; and the call in tail position, which does not save on the
   dump when nothing is left on the control ([tail], on unless said):
   Landin's machine grows its dump at each turn of a loop, Scheme may
   not. A continuation (call/cc) is the four registers kept, as
   Landin's J operator (1965) was.

   The machine is changed in place, where Scheme_eval's state is a
   value: its store is an array. The built-ins, the prelude and the
   errors' texts are the first machine's. No world: big-bang fails.

   The rule that is not Landin's, counted. With
   (define (loop i) (if (= i 0) 'done (loop (- i 1)))), mini-scheme
   -secd -s on (loop 1000):

       with the rule       the dump 0 deep at most
       -landin             the dump 1001 deep at most

   A frame of dump a turn, each holding a stack, an environment and
   an empty control to go back to and do nothing with: that is what
   "a tail call needs no frame" says, seen.

   cs-history:
   Landin's paper is where several things start. It runs the lambda
   calculus on a machine, with sharing and an order of evaluation,
   where before it was a notation one rewrote by hand; it has the
   closure, and the word; and its language of "applicative
   expressions" became ISWIM ("The Next 700 Programming Languages",
   1966), the ancestor on paper of ML and Haskell: let and where,
   functions as values, indentation that counts. The machine was a
   definition, not something to run fast: a language's meaning given
   by a small program that anyone can step by hand, which is what an
   abstract machine has meant since.

   evolution:
   The machines that came of it. Peter Henderson's Lispkit (1980)
   compiled to SECD instructions (ld, ldc, ldf, ap, rtn, sel, join)
   where Landin's control holds expressions, as here. Felleisen and
   Friedman's CEK (1986) joined the stack and the dump into one
   continuation (Scheme_eval.mli). The Categorical Abstract Machine
   (Cousineau, Curien and Mauny, 1985) gave Caml its name, and
   Xavier Leroy's ZINC (1990), whose calls with several arguments
   build no closure in between, is still under OCaml's bytecode.
   Krivine's machine does call by name with a stack and an
   environment alone.

   References: Peter Landin, "The Mechanical Evaluation of
   Expressions" (Computer Journal 6, 1964): the machine is a few
   pages of it. Landin, "A
   Generalization of Jumps and Labels" (1965), for J. Peter
   Henderson, "Functional Programming: Application and
   Implementation" (Prentice-Hall, 1980). Olivier Danvy, "A Rational
   Deconstruction of Landin's SECD Machine" (2004): the machine
   turned back into an evaluator, step by step. Xavier Leroy, "The
   ZINC Experiment" (INRIA, 1990). *)

type t

(* [create ~tail]: with the built-ins and the prelude. [tail] false:
   every call saves on the dump, as in 1964 *)
val create : tail:bool -> t

(* [start m e]: evaluating [e] next, from nothing *)
val start : t -> Scheme.expr -> unit

(* at most [fuel] steps: Done, Running or Failed (never World) *)
val run : fuel:int -> t -> Scheme_eval.outcome

(* what display and newline printed since the last time *)
val take_output : t -> string

val steps : t -> int

(* the dump's greatest depth since the machine was made *)
val deepest : t -> int

(* the four registers, a line: for a trace, before each step *)
val show : t -> string
