(* Scheme_eval: running Scheme on a CESK machine.

   Emacs Lisp's eval (Lisp_eval.mli) is recursive: to evaluate (f (g
   x)), it calls itself on (g x), and OCaml's stack remembers what to
   do with the result. That stack is the whole difficulty of Scheme:
   call/cc must *capture* it as a value and reinstate it later, a call
   in tail position must *not* grow it, and DrScheme's Break button
   must stop a program in the middle of it. So here the stack is data,
   the continuation (Scheme.mli's [kont]), and running is a loop over
   a machine's state, one small step at a time -- Matthias Felleisen
   and Daniel Friedman's CEK machine (1986), with a Store for set!
   (the CESK machine), Felleisen being the author of DrScheme:

       Control      the expression being evaluated (with its
                    Environment), or the value just computed
       Environment  each variable's location in the store
       Store        each location's value: what set! changes
       Kontinuation what to do next with a value

       ((lambda (x) (+ x 1)) 41), a step at a time:
         Eval ((lambda ...) 41)         k = Halt
         Eval (lambda ...)              k = [app: ( ) args (41)] Halt
         Return #<procedure>            k = [app: ( ) args (41)] Halt
         Eval 41                        k = [app: (#<procedure>) ( )] Halt
         Return 41                      ...   all evaluated: apply,
         Eval (+ x 1)  env x->l0        k = Halt   store l0 -> 41
         ...
         Return 42                      k = Halt: done

   What falls out of the continuation being data:
   - call/cc is two lines: (call/cc f) calls f with the current [kont]
     wrapped as a procedure, and calling that procedure throws the
     current one away for it;
   - tail calls: a body's last expression is evaluated with the body's
     own continuation, no frame added, so a loop runs in constant
     space (R5RS requires it; C and OCaml's own stack don't give it);
   - [run] takes a number of steps, its *fuel*, and stops there: the
     host runs a budget of steps a frame, so an endless loop leaves
     the screen alive and Break is simply not running any more.

   The state is a value, as Lisp_eval's is: the store a persistent
   map, never collected (a program making a million bindings holds
   them all -- a garbage collector is an exercise).

   call/cc, on the two examples that say what it is:

       (+ 1 (call/cc (lambda (k) (k 41))))           42
         k is the continuation [app: (+ 1) ( )] Halt, "add 1 to it
         and stop"; (k 41) returns 41 to it: a jump out, an exit

       (define k2 #f)
       (+ 1 (call/cc (lambda (k) (set! k2 k) 1)))    2
       (k2 10)                                       11
         the same continuation, kept, and called after the addition
         it is part of has finished: the addition is done again,
         with 10. No stack could do that; a value can, any number
         of times.

   And a loop, (define (loop i) (if (= i 0) 'done (loop (- i 1)))):
   the call (loop (- i 1)) is the if's answer and the if is the
   body's last expression, so it is evaluated with the continuation
   the body was given. A thousand turns and the continuation is
   still the one of the first call (Scheme_secd.mli counts it: its
   dump stays at 0, and reaches 1001 with the rule taken away).

   Where it stands: CLI runs it at a prompt and mini-drscheme in a
   window, a budget of steps a frame; Scheme_step is not built on it
   (it rewrites text) and agrees with it by evaluating in the same
   order. St_interp.mli is the same design met in another language:
   the stack as objects of the language, a budget, a debugger that
   reads; Smalltalk's contexts and this [kont] are the two ways to
   let a program hold its own future.

   design:
   The continuation as a data type is not a trick of this machine
   but a transformation with a name. Write the evaluator in OCaml
   with one more argument, a function saying what to do with the
   result (continuation-passing style): no call ever returns, so
   OCaml's stack is not used. Then replace each of those functions
   by a constructor holding its free variables, and one function,
   [run]'s Return case, that does what each would have done: [kont]
   is the result, K_if the function made while a test is evaluated.
   John Reynolds described both steps in 1972; Olivier Danvy and
   others showed in 2003 that they turn an evaluator into the CEK
   machine exactly.

   cs-history:
   Continuations were found several times around 1970 by people who
   needed to say what a jump means: Christopher Strachey and
   Christopher Wadsworth for goto in a language's mathematics
   (1974), Reynolds's escape, and before them Landin's J operator
   (1965), which Scheme_secd.mli has. Scheme's first report had
   CATCH for it; call-with-current-continuation is the later
   reports' name, call/cc the abbreviation everyone used.

   cs-history:
   Proper tail calls are Steele's point of 1977: a call that is the
   last thing a procedure does needs nothing kept, so it is a jump
   that passes arguments, and "procedure calls are slow" was a fact
   about compilers that pushed a frame anyway. Scheme's reports make
   it a requirement of the language, not an optimization, since a
   program written as a loop of tail calls is wrong, not slow, on
   an implementation without it. C compilers do it when they can and
   promise nothing; the JVM does not.

   References: Matthias Felleisen and Daniel Friedman, "Control
   Operators, the SECD-Machine, and the lambda-Calculus" (1986);
   Felleisen, Findler and Flatt, "Semantics Engineering with PLT
   Redex" (2009), chapter 6; R5RS, "Revised^5 Report on the
   Algorithmic Language Scheme" (1998), section 3.5, "Proper tail
   recursion". John Reynolds, "Definitional Interpreters for
   Higher-Order Programming Languages" (ACM Annual Conference,
   1972): the paper behind the design paragraph, and the clearest.
   Mads Sig Ager, Dariusz Biernacki, Olivier Danvy and Jan
   Midtgaard, "A Functional Correspondence between Evaluators and
   Abstract Machines" (PPDP 2003). Christopher Strachey and
   Christopher Wadsworth, "Continuations: A Mathematical Semantics
   for Handling Full Jumps" (Oxford, 1974). Guy Steele, "Debunking
   the 'Expensive Procedure Call' Myth, or, Procedure Call
   Implementations Considered Harmful, or, Lambda: The Ultimate
   GOTO" (MIT AI Memo 443, 1977). William Clinger, "Proper Tail
   Recursion and Space Efficiency" (PLDI 1998): what the requirement
   means, said as a space bound on a machine like this one. *)

type state

(* a world program asked for by (big-bang ...): the first world, and
   its handlers by clause name, "to-draw", "on-tick"... in the order
   written *)
type world = { init : Scheme.t; handlers : (string * Scheme.t) list; span : Sexpr.span }

(* an error, the text at fault when known -- DrScheme paints it pink *)
type error = { message : string; at : Sexpr.span option }

type outcome =
  | Done of Scheme.t (* the expression's value *)
  | Running (* the fuel ran out first: run again *)
  | Failed of error
  | World of world (* waiting for the host to run a world, then [resume] *)

(* a machine with the built-ins (Scheme_prims.mli, call/cc, apply,
   display, random) and the prelude (Scheme_prelude.mli) defined *)
val create : unit -> state

(* [start st e]: evaluating [e] next, from nothing *)
val start : state -> Scheme.expr -> state

(* [run ~fuel st]: at most [fuel] steps (the playground's default,
   when it was optional: 100000) *)
val run : fuel:int -> state -> outcome * state

(* [resume st v]: the big-bang that waited returns [v], the last
   world *)
val resume : state -> Scheme.t -> state

(* [call st f args]: the host calling a procedure (a world's handler),
   to its end, with at most [fuel] steps (there a million); what
   the machine was doing is kept for after *)
val call : fuel:int -> state -> Scheme.t -> Scheme.t list -> (Scheme.t, error) result * state

(* what display and newline printed since the last time, and the
   machine without it *)
val take_output : state -> string * state

(* [eval_all st text]: every form of [text], read, checked and run to
   its end, the last's value -- for the tests, and the prelude *)
val eval_all : fuel:int -> state -> string -> (Scheme.t, error) result * state

(* how many steps the machine has taken, since its creation *)
val steps : state -> int

(* the global variables the program defined, not the built-ins' --
   for a host listing them *)
val defined : state -> string list
