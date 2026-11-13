(* Worker_spawn says what the window's worker is: a thread or a domain.
   It is the one module of mini-netscape that depends on the compiler,
   as in the author's mini-chrome (its libs/network).

     OCaml 4.14          OCaml 5              mini-ml
     -----------------   ------------------   ----------------------
     Thread.create       Domain.spawn         lib_core's Thread
     one thread runs     each domain runs on  cooperative: a thread
     OCaml at a time,    a core, so the       runs until it waits or
     and the lock is     worker runs beside   yields, and a system
     taken from it       the window           call makes all of them
     every 50 ms, so                          wait
     the window still
     answers

   dune copies spawn/threads.ml or spawn/domains.ml to Worker_spawn.ml,
   depending on the compiler's version (see dune). mini-mk's build takes
   spawn/large_threads.ml (see mkfile), which makes a thread with the
   program's stacks, because lib_core's threads have small ones (a
   page's List.map overflowed one on mini-9pi). Mutex and Condition have
   the same names in all three.

   What a piece of work on the worker may share with the window is said
   where the worker is used (in Netscape, the tab's scripts run on one
   thread at a time). *)

(* do the worker and the window run at the same instant? *)
val parallel : bool

(* Starts a worker running [f], which does not return. *)
val spawn : (unit -> unit) -> unit
