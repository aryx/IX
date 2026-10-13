(* Xavier Leroy, projet Cristal, INRIA Rocquencourt
 * Objective Caml. Copyright 1996 INRIA. Distributed only by permission. *)

(* Ensure that [at_exit] functions are called at the end of every program *)

let _ = do_at_exit()
