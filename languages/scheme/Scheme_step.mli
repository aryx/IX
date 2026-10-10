(* Scheme_step: DrScheme's stepper, Beginning Student's evaluation
   shown as algebra.

   HtDP teaches that running a program is calculating, the way a
   student simplifies (2 + 3) * 4 at school: each step replaces one
   expression, the *redex*, by a simpler one, until a value is left.
   The stepper (John Clements, Matthew Flatt and Matthias Felleisen,
   "Modeling an Algebraic Stepper", ESOP 2001) shows each step, the
   redex highlighted before (green in DrScheme) and what replaced it
   after (purple):
{|
       (define (sq x) (* x x))
       (+ (sq 3) 1)

       (+ (sq 3) 1)      -->   (+ (* 3 3) 1)       a call: the body,
           ^^^^^^                 ^^^^^^^          x replaced by 3
       (+ (* 3 3) 1)     -->   (+ 9 1)             a built-in
       (+ 9 1)           -->   10
|}

   The rules are Beginning Student's semantics, a *substitution*
   model: no store, no environment -- a function's parameters are
   replaced by the argument values in its body's text, a constant's
   name by its value, (cond [#f a] ...) loses its first clause. The
   next redex is always the leftmost innermost one not yet a value,
   which is the order the machine (Scheme_eval.mli) evaluates in, so
   the stepper and Execute agree.

   It knows Beginning Student only: define, define-struct, cond, if,
   and, or, calls, quote; no lambda, local, set! -- for those the
   substitution model needs more (the Advanced Student stepper shows
   the store too). A (big-bang ...) at the top is left out: a world
   runs in time, not in steps.

   Where it stands: beside the machine, not on it. It reads Sexpr's
   tree, keeps the program as a term and rewrites the term; the
   built-ins are Scheme_prims', so the two cannot differ on what +
   gives. mini-scheme -step prints the steps, mini-drscheme shows
   them in two panes.

   cs-history:
   The substitution model is the lambda calculus's one rule, Alonzo
   Church's beta reduction (the 1930s): a function applied to an
   argument is its body with the argument put for the parameter.
   Which redex first is the whole of a language's order of
   evaluation; arguments before the call, as here, is call by value,
   and Gordon Plotkin (1975) is who showed that the rule restricted
   to arguments that are values is the calculus a machine like
   Landin's computes. SICP opens with this model (section 1.1.5) and
   keeps it for two chapters, then gives it up in the third, the day
   set! comes in: once a variable can change, a name cannot be
   replaced by its value, and an environment is needed. The two
   machines beside this module are that second model.

   design:
   A semantics a student can do by hand and a tool that shows the
   same steps: the stepper is the language's definition made a
   program, which is HtDP's reason for teaching languages cut to
   what the model explains. Each feature left out of Beginning
   Student is one the algebra could not show.

   References: John Clements, Matthew Flatt and Matthias Felleisen,
   "Modeling an Algebraic Stepper" (ESOP 2001): how DrScheme's is
   made, over the real evaluator, by marking continuations, where
   this one is a second evaluator, far simpler. Gordon Plotkin,
   "Call-by-name, Call-by-value and the lambda-Calculus" (Theoretical
   Computer Science, 1975). Abelson and Sussman, "Structure and
   Interpretation of Computer Programs", sections 1.1.5 and 3.1.3
   ("The Costs of Introducing Assignment"). *)

(* a step: the form being reduced, before and after, as text, and
   where the redex and its replacement are in each: DrScheme's two
   panes *)
type step = { before : string; redex : int * int; after : string; contractum : int * int }

(* [steps ~max text]: every step of the program [text], in order, at
   most [max] of them (there 1000), and the error that stopped
   it, if one did (the last steps before it are kept) *)
val steps : max:int -> string -> step list * string option
