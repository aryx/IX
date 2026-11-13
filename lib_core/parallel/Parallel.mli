(* Several of the host's cores for one program, when the compiler allows
   it. This module holds the few lines of such a program that depend on
   the compiler.

     OCaml 4.14                          OCaml 5
     ---------------------------------   ---------------------------------
     one lock for the whole runtime:     a heap for each domain for what
     a single thread runs OCaml at a     is young, and one shared for the
     time, the others wait or block      rest; the domains run at the
     in a system call                    same time, one core each
     [available] false                   [available] true
     nothing to spawn, and a lock        Domain.spawn, Mutex, Condition
     that nobody waits for

   Both compilers build the same program. dune copies one of two files
   to Parallel.ml, depending on the compiler's version
   (lib_core/parallel/dune):

     host/single.ml.in     (enabled_if (< %{ocaml_version} 5.0))
     host/domains.ml.in    (enabled_if (>= %{ocaml_version} 5.0))

   A program asks [available] once and keeps both ways. When it is
   true, the program runs its workers on domains, with what they share
   behind a lock. When it is false, the program does the work in turns
   in its one thread, where the same lock is taken and given by the
   only one who is there (so the code that takes it is written once).
   mini-qemu's cores of a Pi 2 work this way: each core runs on a
   domain of its own under OCaml 5 when asked (Board.cores_parallel),
   and the cores take turns otherwise.

   What changes with domains is what a worker may assume. When workers
   take turns, no two are in the same table at the same instant. On
   domains they can be, so what they share must be behind a lock, or be
   made before the first one starts, or be a word that does no harm
   when it is read late.

   design:
   Why not use threads under 4.14, as mini-chrome's Worker_spawn does
   (it uses a thread there and a domain under 5, with Mutex and
   Condition under their own names in both)? Its workers mostly wait
   (for a name to be resolved, for a connection), and a thread that
   waits lets the others run. A worker that computes does not wait:
   under 4.14 the threads would take the same turns as a loop in one
   thread, but slower, and in an order that the host chooses, whereas a
   loop's order is the same each time. Also, 4.14's Mutex belongs to the
   threads library, which a page compiled by js_of_ocaml cannot link
   (its caml_thread_initialize is not there), and mini-qemu's board
   also runs in a page. So the lock is here, under one name for both.

   cs-history:
   OCaml has had threads since 1995 (Xavier Leroy's, over the bytecode
   interpreter, then over POSIX threads), and for twenty-five years it
   had a runtime that only one thread at a time could enter. Multicore
   OCaml (KC Sivaramakrishnan, Stephen Dolan and others, from 2014) gave
   the collector a minor heap for each domain and a shared major heap
   collected concurrently. It was merged as OCaml 5.0, released in
   December 2022.

   Reference: KC Sivaramakrishnan et al., "Retrofitting Parallelism
   onto OCaml" (ICFP 2020). *)

(* Whether workers run at the same time as the code that started them
 * (OCaml 5). When they do not, [spawn] and [wait] must not be
 * called. *)
val available : bool

(* Starts a worker that runs [f], on a domain of its own. *)
val spawn : (unit -> unit) -> unit

(* A lock has one holder at a time. Its holder must not take it
 * twice. *)
type lock
val lock : unit -> lock
val take : lock -> unit
val give : lock -> unit

(* Something to wait for, with a lock held. [wait] gives up the lock,
 * waits until it is told, and then holds the lock again. It is
 * sometimes told for no reason, so the waiter must look again at what
 * it waited for. [signal] tells one of those who wait, and [broadcast]
 * tells all of them. *)
type cond
val cond : unit -> cond
val wait : cond -> lock -> unit
val signal : cond -> unit
val broadcast : cond -> unit
