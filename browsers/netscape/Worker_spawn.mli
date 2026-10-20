(* Worker_spawn: what the window's worker is -- a thread, or a domain:
   the one module of mini-netscape that depends on the compiler (the
   author's mini-chrome's, libs/network's).

     OCaml 4.14          OCaml 5              mini-ml
     -----------------   ------------------   ----------------------
     Thread.create       Domain.spawn         lib_core's Thread
     one runs OCaml at   each on a core:      cooperative: one runs
     a time, the lock    the worker runs      until it waits or
     taken from it each  beside the window    yields; a system call
     50 ms: the window                        waits for all
     still answers

   dune copies one of spawn/threads.ml and spawn/domains.ml to
   Worker_spawn.ml, by the compiler's version (dune); mini-mk's build
   takes spawn/large_threads.ml (mkfile): a thread with the program's
   stacks, where lib_core's are small (a page's List.map overflowed
   one on mini-9pi). Mutex and Condition are the same
   names in all three.

   What a piece on the worker may share with the window is said where
   it is used (Netscape: the tab's scripts on one thread at a time). *)

(* do the worker and the window run at the same instant? *)
val parallel : bool

(* a worker running [f], which does not return *)
val spawn : (unit -> unit) -> unit
