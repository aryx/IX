(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
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
