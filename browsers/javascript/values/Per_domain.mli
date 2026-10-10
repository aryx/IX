(* Per_domain: a value of which each domain has its own -- what a
   module kept in a global for itself (a cache, "what is running now")
   when the program had one thread of OCaml, and must not share now
   that a tab's work runs on a domain of its own beside the window's.

     let cache = Per_domain.make (fun () -> Hashtbl.create 16)
     ... Hashtbl.find_opt (cache ()) key ...

   [make init] gives a function: called on a domain, it gives that
   domain's value, made by [init] the first time. Two tabs laid out at
   once then fill two caches, and neither sees the other's half-written
   entry. Nothing is locked, so nothing waits; the price is that a
   cache filled on one domain is empty on another.

   What must be one for the whole program (the cookies' jar, the
   pictures decoded ahead) is not this: it keeps its mutex.

   Under OCaml 4.14 there is one domain and [make init] is one value,
   made at once: the same code, built by both compilers (dune copies
   domain/domains.ml.in or domain/threads.ml.in, as libs/network does
   its Worker_spawn).

   cs-history:
   A variable of which each thread has its own is as old as threads in
   C: POSIX's pthread_key_create (1995), then a word of the language
   itself (__thread, C11's _Thread_local) -- the way a library written
   for one thread, with its errno and its static buffers, was made to
   live with many. OCaml 5 (2022) has it per domain, Domain.DLS, for
   the same reason: its own runtime's random generator and formatter
   buffers were globals.

   modern:
   Chrome's answer to "a tab must not freeze the others" was to give
   each a process (2008): nothing shared, so nothing to make safe, at
   the price of memory and of messages between them. Domains share
   one heap: cheaper, and every global is a question. *)
(* ix: the author's mini-chrome's libs/opti/Per_domain.mli (its 8af888e) (docs/plans/plan_browser.md) *)

(* whether domains really run side by side (OCaml 5) *)
val parallel : bool

(* [make init]: this domain's value, made by [init] at its first use there *)
val make : (unit -> 'a) -> unit -> 'a

(* whether this is the program's first domain, the window's *)
val main : unit -> bool
