(* Js_promise: a value that comes later -- promises, the jobs that
   settle them, and async functions over them.

   A script runs to its end before the page moves again (Js_eval): it
   cannot wait for an answer from the network. It says instead what to
   do when the answer is there. With a callback that is a function
   given to the one who asks; a promise (ES2015) is the answer itself
   as a value, not there yet, that can be kept, given and combined:

   evolution:
   An old idea, late to the web. A value standing for a result not yet
   computed is of the 1970s: "promise" is Daniel Friedman and David
   Wise's word (1976), "future" Henry Baker and Carl Hewitt's (1977);
   Barbara Liskov and Liuba Shrira's "Promises" (1988) gave them the
   shape used here, for calls across a network, and Mark Miller's E
   language the chaining with "when". JavaScript had only callbacks,
   and programs whose every step waits for the network grew sideways
   ("callback hell", the pyramid of nested functions, errors lost at
   each level). Promises reached it through libraries: Twisted's
   Deferred in Python (2002) copied by Dojo (2007) and jQuery (2011);
   then a common rule for "then" that let them work together,
   CommonJS Promises/A (Kris Zyp, 2009) and Promises/A+ (2012); then
   the language (ES2015). async and await came from C# 5 (2012, after
   F#'s asynchronous workflows, 2007) and were in JavaScript in 2017:
   with them code that waits reads as code that does not.

       pending ----resolve(v)----> fulfilled with v
          \------reject(e)-------> rejected with e      (once, for ever)

     const p = new Promise((resolve, reject) => { ... resolve(42) ... })
     p.then(v => v + 1).then(console.log)        // 43, later
     p.then(...).catch(e => ...)                 // a throw in a then: the catch's

   **then** gives a new promise: of what its function returns (or
   throws). So thens chain, and a rejection goes down the chain to the
   first that has a function for it. A function that returns a promise
   (anything with a then: a "thenable") makes the chain wait for it.

   **Jobs.** A then's function is never called at once, even on a
   promise already settled: it is put in a queue of jobs ("microtasks")
   that the engine runs when the script, the event's handler or the
   timer's function now running has returned ([drain], called by
   Js_eval after each run and call), in order, to the last -- a job can
   add jobs:

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
   [async] runs a body as one, [await] suspends it and adds, to the
   promise awaited, a job that resumes it.

   A rejection nobody handles is said on the console once the jobs are
   done, "Uncaught (in promise) ...", as browsers do: else a mistake
   in an async function would be silent.

   Less than the real thing: a promise made by a class that extends
   Promise is a plain one. (Promise.withResolvers is Js_prelude's, in
   JavaScript over this module's Promise; for await and an async
   generator are Js_eval's, over [await].)

   Where it stands: this module is the small half of a browser's
   event loop, the half that is the language's. The queue of jobs
   here are the "microtasks"; the tasks (a script, an event, a timer
   due) are the host's, and the rule between the two is the host's to
   keep: after each task, every job. Js_eval keeps it for a script
   run and a function called; Event_loop, for a page, has the timers
   and the picture of the whole loop. mini-node has no task but the
   script, so its loop is: the script, the jobs, the end.

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
   Systems" (PLDI 1988); ECMA-262 sections 27.2 (Promise), 27.7 (async functions),
   9.5 (jobs); the Promises/A+ specification, which the then of
   section 2.2 and the "resolution procedure" of 2.3 (a thenable
   adopted) follow. *)
(* ix: the author's mini-chrome's languages/javascript/library/Js_promise.mli (its 8af888e) (docs/plans/plan_browser.md) *)

(* the jobs waiting, and what the promises need of the interpreter *)
type t

(* [install ~call ~get ~items ~report define]: Promise and
 * queueMicrotask [define]d. [call] calls a script's function, [get]
 * reads a property (a thenable's then, through its prototypes and
 * getters), [items] are what Promise.all goes through (an array's),
 * [report] says a rejection nobody handled *)
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

(* the jobs run, those they add too, until none is left; then the
 * rejections left unhandled reported. [each] is called before each
 * job: the engine renews its budget of steps there, a job being a run
 * of its own (a page that renders in a thousand thens is not a loop
 * that never ends) *)
val drain_each : (unit -> unit) -> t -> unit

(* the same, nothing done between two (ix: it was drain's ?each) *)
val drain : t -> unit

(* [async t body]: the promise of [body]'s value, [body] run now up to
 * its first [await] (an async function's call) *)
val async : t -> (unit -> Js_value.value) -> Js_value.value

(* [await t v], in a body run by [async]: the body suspended until [v]
 * is settled (a value that is not a promise: until the jobs before it
 * are done); its value, or Js_value.Throw of its rejection *)
val await : t -> Js_value.value -> Js_value.value
