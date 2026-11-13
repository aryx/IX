(* A Js_coroutine is a computation that can stop in its middle and go
   on later. It is what an async function is at each await.

   The interpreter walks the tree with OCaml's own calls (Js_eval), so
   where the script is in its run is where OCaml's stack is. An
   "await p" deep in a loop in a try in a function must stop there,
   give the hand back to whoever called the function, and go on from
   that very place when p is settled, perhaps seconds later. That
   needs a second stack, kept aside, and that is a coroutine.

       the caller                       the body
       ----------                       --------
       resume co  ------------------->  runs ...
                                        ... await: suspend ()
       goes on  <---------------------
       ...
       resume co  ------------------->  ... goes on after its await
                                        ends
       goes on  <---------------------

   One of the two runs at a time, never both: [resume] returns when
   the body suspends or ends; [suspend] returns when the body is
   resumed. So nothing of the interpreter needs a lock.

   comeback:
   The word and the idea are Melvin Conway's (1958; his paper of 1963
   is below): two routines that call each other as equals, where
   neither is the other's subroutine. Simula 67 had them, and Knuth
   gave them pages of his first volume (1968). Then the stack won (one
   call, one return), and for thirty years a program that had to wait
   wrote its waiting inside out, as callbacks or as a state machine by
   hand (mini-chrome's Http_request.mli). They came back one language
   at a time, under other names: generators (CLU's iterators, 1975;
   Python, 2001; JavaScript, 2015), goroutines (Go, 2009), async and
   await (C#, 2012; JavaScript, 2017), and effect handlers (OCaml 5,
   2022), with which a library can write its own.

   others:
   In OCaml 4.14 the only stack that can be set aside is a thread's,
   so a coroutine here is a thread. A mutex and a condition hold it,
   so that it only runs between a [resume] and the [suspend] that
   follows. (OCaml 5's effects do it with no thread. The other ways
   are an interpreter written in continuation-passing style, with
   every rule of Js_eval turned inside out, or the function's tree
   rewritten as a state machine, which is what compilers to ES5 do.)
   A body that is never resumed (an await on a promise nobody
   settles) is a thread that sleeps until the program ends. The price
   is its stack, a few pages of memory.

   Here is a worked example, from the tests (Unit_js_promise):

     let log = ref [] in
     let say x = log := x :: !log in
     let co = create (fun () -> say "a"; suspend (); say "c") in
     resume co; say "b"; resume co; say "d"
     (* a b c d *)

   Where it stands: two things of the language are a body stopped in
   its middle, and both are made here. The first is an async function
   at an await: Js_promise.async makes the coroutine, and its await
   suspends it and gives the promise awaited a job that resumes it.
   The second is a generator at a yield, in Js_eval: next() resumes
   the body, and yield suspends it with the value given. That is why

     function* count() { let i = 0; while (true) yield i++ }

   is a loop that never ends, and yet a function that returns at once.

   reframe:
   A coroutine is a thread without a scheduler: the program says who
   runs next ([resume], [suspend]), and nothing chooses for it. In ix
   built by mini-ml, lib_core's Thread is cooperative: a thread runs
   until it waits, each thread has its own machine stack, and the
   runtime's two primitives make a thread and switch to another. So
   there the mutex and the condition of this module only say whose
   turn it is, and what is left is the bare idea: a stack kept aside
   and a jump to it. A kernel's switch from one process to another is
   that jump again, with the registers saved by hand.

   Reference: Conway, "Design of a Separable Transition-Diagram
   Compiler" (1963), where the word comes from; ECMA-262 section 27.7
   (async functions), whose "execution context suspended" is what this
   module makes. *)
(* ix: copied from languages/javascript/eval/Js_coroutine.mli in the
 * author's mini-chrome, at its commit 8af888e (docs/plans/plan_browser.md) *)

type t

(* [create body] makes a coroutine that has not started; [body] runs at
 * the first [resume]. An exception that [body] lets through ends it
 * silently, so catch in [body] what matters. *)
val create : (unit -> unit) -> t

(* [resume co] runs its body, from its start or from where it
 * suspended, until it suspends or ends. On a coroutine that has
 * ended, it does nothing. *)
val resume : t -> unit

(* Called from a running body, [suspend] stops it here and gives the
 * hand back to the [resume] that made it run. Outside a body, it
 * raises Invalid_argument. *)
val suspend : unit -> unit

(* the body that is running, if there is one: what [suspend] would
 * stop, to be resumed later *)
val current : unit -> t option
