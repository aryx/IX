(* Js_promise is about a value that comes later: promises, the jobs
   that settle them, and async functions over them.

   A script runs to its end before the page moves again (Js_eval), so
   it cannot wait for an answer from the network. Instead, it says
   what to do when the answer is there. With a callback, that is a
   function given to the one who asks. A promise (ES2015) is the
   answer itself as a value, not there yet, that can be kept, given
   and combined:

   evolution:
   It is an old idea that came late to the web. A value standing for a
   result not yet computed dates from the 1970s: "promise" is Daniel
   Friedman and David Wise's word (1976), and "future" is Henry Baker
   and Carl Hewitt's (1977). Barbara Liskov and Liuba Shrira's
   "Promises" (1988) gave them the shape used here, for calls across a
   network, and Mark Miller's E language gave the chaining with
   "when". JavaScript had only callbacks, and programs whose every step
   waits for the network grew sideways ("callback hell", the pyramid
   of nested functions, with errors lost at each level). Promises
   reached it through libraries: Twisted's Deferred, in Python, was
   copied by MochiKit, Dojo (2006) and jQuery (2011). Then came a
   common rule for "then" that let them work together, CommonJS
   Promises/A (Kris Zyp, 2009) and Promises/A+ (2012), and then the
   language (ES2015). async and await came from C# 5 (2012, after F#'s
   asynchronous workflows, 2007) and were in JavaScript in 2017. With
   them, code that waits reads like code that does not.

       pending ----resolve(v)----> fulfilled with v
          \------reject(e)-------> rejected with e      (once, for ever)

     const p = new Promise((resolve, reject) => { ... resolve(42) ... })
     p.then(v => v + 1).then(console.log)        // 43, later
     p.then(...).catch(e => ...)                 // a throw in a then: the catch's

   **then** gives a new promise, of what its function returns (or
   throws). So thens chain, and a rejection goes down the chain to the
   first that has a function for it. A function that returns a promise
   (anything with a then: a "thenable") makes the chain wait for it.

   **Jobs.** A then's function is never called at once, even on a
   promise already settled: it is put in a queue of jobs ("microtasks")
   that the engine runs when the script, the event's handler or the
   timer's function now running has returned ([drain], which Js_eval
   calls after each run and call). The jobs run in order, up to the
   last one, and a job can add jobs:

     Promise.resolve().then(() => log(2)); log(1)        // 1 2

   so that code after a then always runs before it, whether the promise
   was settled or not. queueMicrotask(f) adds a job of one's own.

   **async and await** (ES2017) write a chain of thens as plain code.
   An async function gives a promise of what it returns; "await p" in
   it stops the function there until p is settled, gives p's value (or
   throws its rejection, for a try around it), and meanwhile the caller
   goes on:

     async function f() { log(1); const v = await later(); log(3, v) }
     f(); log(2)                                          // 1 2 3

   The function stopped in its middle is a coroutine (Js_coroutine):
   [async] runs a body as one, and [await] suspends it and adds, to the
   promise awaited, a job that resumes it.

   A rejection that nobody handles is shown on the console once the
   jobs are done, as "Uncaught (in promise) ...", as browsers do;
   otherwise a mistake in an async function would be silent.

   This is less than the real thing: a promise made by a class that
   extends Promise is a plain one, and there is no
   Promise.withResolvers. (For await and an async generator are in
   Js_eval, over [await].)

   Where it stands: this module is the small half of a browser's
   event loop, the half that belongs to the language. The jobs of the
   queue here are the "microtasks". The tasks (a script, an event, a
   timer that is due) are the host's, and the host must keep the rule
   between the two: after each task, every job is run. Js_eval keeps
   it for a script run and a function called; for a page, Event_loop
   has the timers and the picture of the whole loop. mini-node has no
   task but the script, so its loop is: the script, the jobs, the end.

   reframe:
   A promise's then and a kernel's sleep and wakeup are the same
   pair. A process that cannot go on says what it waits for and gives
   the processor away; whoever makes the thing true wakes those that
   wait. Here the one that waits is a function (a then's) or a body
   stopped at its await, the processor is the one thread of the
   script, and settling a promise is the wakeup: it does not run the
   waiters, it makes them ready (a job in the queue), as wakeup makes
   a process runnable and leaves it to the scheduler.

   Reference: Barbara Liskov and Liuba Shrira, "Promises: Linguistic
   Support for Efficient Asynchronous Procedure Calls in Distributed
   Systems" (PLDI 1988); ECMA-262 sections 27.2 (Promise), 27.7 (async
   functions), 9.5 (jobs); the Promises/A+ specification, whose then
   (section 2.2) and "resolution procedure" (2.3, a thenable adopted)
   this module follows. *)
(* ix: copied from languages/javascript/library/Js_promise.mli in the
 * author's mini-chrome, at its commit 8af888e (docs/plans/plan_browser.md) *)

(* the jobs waiting, and what the promises need of the interpreter *)
type t

(* [install ~call ~get ~items ~report define] [define]s Promise and
 * queueMicrotask. [call] calls a script's function, [get] reads a
 * property (a thenable's then, through its prototypes and getters),
 * [items] gives what Promise.all goes through (an array's items), and
 * [report] says a rejection nobody handled. *)
val install :
  call:(Js_value.value -> this:Js_value.value -> Js_value.value list -> Js_value.value) ->
  get:(Js_value.value -> string -> Js_value.value) ->
  items:(Js_value.value -> Js_value.value list) ->
  report:(Js_value.value -> unit) ->
  (string -> Js_value.value -> unit) ->
  t

(* a new promise, and its two functions: resolve (with a value, or a
 * thenable to follow) and reject. The first call of either counts *)
val make : t -> Js_value.value * (Js_value.value -> unit) * (Js_value.value -> unit)

(* runs the jobs, and those they add too, until none is left; then it
 * reports the rejections left unhandled. [each] is called before each
 * job: the engine renews its budget of steps there, since a job is a
 * run of its own (a page that renders in a thousand thens is not a
 * loop that never ends). *)
val drain_each : (unit -> unit) -> t -> unit

(* the same, with nothing done between two jobs (ix: in mini-chrome,
 * drain has an optional ?each) *)
val drain : t -> unit

(* [async t body] gives the promise of [body]'s value, and runs [body]
 * now up to its first [await] (an async function's call) *)
val async : t -> (unit -> Js_value.value) -> Js_value.value

(* [await t v], in a body run by [async], suspends the body until [v]
 * is settled (for a value that is not a promise, until the jobs
 * before it are done). It gives [v]'s value, or raises Js_value.Throw
 * of its rejection. *)
val await : t -> Js_value.value -> Js_value.value
