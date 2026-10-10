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
   errors' texts are the first machine's. No world: big-bang fails. *)

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
