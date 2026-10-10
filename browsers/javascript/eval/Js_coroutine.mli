(* Js_coroutine: a computation that can stop in its middle and go on
   later -- what an async function is at each await.

   The interpreter walks the tree by OCaml's own calls (Js_eval): where
   a script is, is where OCaml's stack is. An "await p" deep in a
   loop in a try in a function must stop there, give the hand back to
   whoever called the function, and go on from that very place when p
   is settled, perhaps seconds later. That is a second stack, kept
   aside: a coroutine.

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
   The word and the idea are Melvin Conway's (1958; his paper of 1963,
   below): two routines that call each other as equals, neither the
   other's subroutine. Simula 67 had them, and Knuth gave them pages
   of his first volume (1968). Then the stack won -- one call, one
   return -- and for thirty years a program that had to wait wrote its
   waiting inside out, as callbacks or as a state machine by hand
   (mini-chrome's Http_request.mli). They came back one language at a
   time, under other names: generators (CLU's iterators, 1975; Python, 2001;
   JavaScript, 2015), goroutines (Go, 2009), async and await (C#,
   2012; JavaScript, 2017), and effect handlers (OCaml 5, 2022), with
   which a library writes its own.

   others:
   OCaml 4.14 has no stack to set aside but a thread's: a coroutine
   here is a thread, held by a mutex and a condition so that it only
   runs between a [resume] and the [suspend] that follows. (OCaml 5's
   effects do it with no thread; the other ways are an interpreter
   written in continuation-passing style, every rule of Js_eval turned
   inside out, or the function's tree rewritten as a state machine,
   what compilers to ES5 do.) A body that is never resumed -- an await
   on a promise nobody settles -- is a thread asleep until the program
   ends: its stack is the price, a few pages of memory.

   Worked example (the tests': Unit_js_promise):

     let log = ref [] in
     let say x = log := x :: !log in
     let co = create (fun () -> say "a"; suspend (); say "c") in
     resume co; say "b"; resume co; say "d"
     (* a b c d *)

   Where it stands: two things of the language are a body stopped in
   its middle, and both are made here. An async function at an await
   (Js_promise.async makes the coroutine, its await suspends it and
   leaves the promise awaited a job that resumes it), and a generator
   at a yield (Js_eval's: next() resumes the body, yield suspends it
   with the value given), which is why

     function* count() { let i = 0; while (true) yield i++ }

   is a loop that never ends and a function that returns at once.

   reframe:
   A coroutine is a thread without a scheduler: who runs next is said
   by the program ([resume], [suspend]), never chosen for it. So in
   ix built by mini-ml, where lib_core's Thread is cooperative (a
   thread runs until it waits; each has its machine stack, and the
   runtime's two primitives are a thread made and a switch to
   another), the mutex and the condition of this module only say
   whose turn it is, and what is left is the idea bare: a stack kept
   aside and a jump to it. A kernel's switch from a process to
   another is that jump again, with the registers saved by hand.

   Reference: Conway, "Design of a Separable Transition-Diagram
   Compiler" (1963), where the word is from; ECMA-262 section 27.7
   (async functions), whose "execution context suspended" this is. *)
(* ix: the author's mini-chrome's languages/javascript/eval/Js_coroutine.mli (its 8af888e) (docs/plans/plan_browser.md) *)

type t

(* [create body]: not started; [body] runs at the first [resume]. An
 * exception [body] lets through ends it, silently: catch in it what
 * matters *)
val create : (unit -> unit) -> t

(* [resume co]: its body runs, from its start or from where it
 * suspended, until it suspends or ends. One that has ended: nothing *)
val resume : t -> unit

(* from a body running: stop here, and give the hand back to the
 * [resume] that made it run. Outside one: Invalid_argument *)
val suspend : unit -> unit

(* the body running, if one is: what [suspend] would stop, to [resume]
 * later *)
val current : unit -> t option
