(* The semaphores (principia's syssema.c): a user's int, decremented
 * when positive (acquire: else waiting, when blocking; tsemacquire: for
 * ms at most), incremented (release: its waiters woken). With one core
 * and no preemption in the kernel, a decrement or a sleep on the word's
 * physical address (the same for every sharer). *)

open Types

(* [syssemacquire p addr block]: 1 acquired, 0 not (not blocking) *)
val syssemacquire : proc -> int -> bool -> int
(* [systsemacquire p addr ms]: 1 acquired, 0 timed out *)
val systsemacquire : proc -> int -> int -> int
(* [syssemrelease p addr n]: the new value *)
val syssemrelease : proc -> int -> int -> int
