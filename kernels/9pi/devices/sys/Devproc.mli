(* '#p', the processes (principia's devproc.c): a directory per process
 * (its pid), its files procdir's. Here: status, args, fd, ns, noteid,
 * segment, ctl (kill), note, notepg (notes posted); the debugger's
 * (mem, regs, text...) not yet. *)

(* the device registered *)
val init : unit -> unit
