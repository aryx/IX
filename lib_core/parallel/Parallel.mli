(* Several of the host's cores for one program, where the compiler can
   -- the few lines of such a program that depend on the compiler.

     OCaml 4.14                          OCaml 5
     ---------------------------------   ---------------------------------
     one lock for the whole runtime:     a heap a domain for what is young,
     a single thread runs OCaml at a     one shared for the rest: the
     time, the others wait or block      domains run at the same time, a
     in a system call                    core each
     [available] false                   [available] true
     nothing to spawn, and a lock        Domain.spawn, Mutex, Condition
     that nobody waits for

   The same program is built by both. dune copies one of two files to
   Parallel.ml, by the compiler's version (lib_core/parallel/dune):

     host/single.ml.in     (enabled_if (< %{ocaml_version} 5.0))
     host/domains.ml.in    (enabled_if (>= %{ocaml_version} 5.0))

   A program asks [available] once and keeps both ways: with it, its
   workers on domains and what they share behind a lock; without, the
   work in turns in its one thread, where the same lock is taken and
   given by the one who is there (so the code that takes it is written
   once). mini-qemu's cores of a Pi 2 are so: a domain each under
   OCaml 5 when asked (Board.cores_parallel), turns otherwise.

   What changes with domains is what a worker may assume. In turns no
   two are in the same table at the same instant. On domains they
   are: what they share is behind a lock, or made before the first
   one starts, or is a word whose late reading does no harm.

   design:
   Why not threads under 4.14, as mini-chrome's Worker_spawn (a thread
   there, a domain under 5, and Mutex and Condition under their own
   names in both)? Its workers mostly wait (a name resolved, a
   connection), and a thread that waits lets the others run. A worker
   that computes does not: 4.14's threads would take the same turns as
   one thread's loop, slower, and in an order the host chooses, where
   a loop's is the same each time. And 4.14's Mutex is the threads
   library's, which a page compiled by js_of_ocaml cannot link (its
   caml_thread_initialize is not there): mini-qemu's board is also a
   page's. So the lock is here, under one name for both.

   cs-history:
   OCaml had threads from 1995 (Xavier Leroy's, over the bytecode
   interpreter, then POSIX threads) and for twenty-five years a
   runtime that one thread at a time could enter. Multicore OCaml
   (KC Sivaramakrishnan, Stephen Dolan and others, from 2014) gave the
   collector a minor heap a domain and a shared major heap collected
   concurrently; it was merged as OCaml 5.0, released in December
   2022.

   Reference: KC Sivaramakrishnan et al., "Retrofitting Parallelism
   onto OCaml" (ICFP 2020). *)

(* do workers run at the same time as the code that started them
 * (OCaml 5)? When not, [spawn] and [wait] must not be called. *)
val available : bool

(* a worker running [f], on a domain of its own *)
val spawn : (unit -> unit) -> unit

(* a lock: one holder at a time. Not to be taken twice by its holder. *)
type lock
val lock : unit -> lock
val take : lock -> unit
val give : lock -> unit

(* something to wait for, with a lock held: [wait] gives the lock, waits
 * until told, and has the lock again; told for no reason at times, so
 * what was waited for is looked at again. [signal]: one of those who
 * wait; [broadcast]: all. *)
type cond
val cond : unit -> cond
val wait : cond -> lock -> unit
val signal : cond -> unit
val broadcast : cond -> unit
