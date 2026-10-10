(* The semaphores (principia's syssema.c): a user's int, decremented
 * when positive (acquire: else waiting, when blocking; tsemacquire: for
 * ms at most), incremented (release: its waiters woken). With one core
 * and no preemption in the kernel, a decrement or a sleep on the word's
 * physical address (the same for every sharer).
 *
 *     long s = 1;                  a word of memory two processes share
 *     A: semacquire(&s, 1)         1 -> 0, returns 1 at once
 *     B: semacquire(&s, 1)         0: B sleeps, Semaphore pa
 *     A: semrelease(&s, 1)         0 -> 1, the sleepers on pa woken
 *     B:                           looks again: 1 -> 0, returns 1
 *
 * The semaphore is not a thing of the kernel's: no call makes one,
 * none frees it, the kernel keeps no table of them. It is the word,
 * wherever the program put it, and the kernel's part is only to wait
 * on it. The physical address is the name because the two processes
 * may have the page at different addresses of their own, or, sharing
 * all their memory (rfork's RFMEM), at the same one.
 *
 * cs-history:
 * Edsger Dijkstra's semaphores (1965, for the THE system): a counter
 * with two operations, P to take and wait if there is none, V to
 * give, from which every other way of waiting can be built. Unix
 * did without them at first (a pipe was its way to wait); System V
 * added them as kernel objects with keys and their own calls
 * (semget, semop, semctl).
 *
 * others:
 * Linux's futex (2002) is the same idea as here: an int in the
 * user's memory, changed there without a call when no one has to
 * wait, and the kernel asked only to sleep on its address or to wake
 * those who do. Plan 9's came a few years later (the paper below);
 * until then its programs had rendezvous to wait with (Sysproc).
 *
 * References: E. W. Dijkstra, "Cooperating Sequential Processes"
 * (1965). Sape Mullender and Russ Cox, "Semaphores in Plan 9"
 * (International Workshop on Plan 9, 2008). Hubertus Franke, Rusty
 * Russell and Matthew Kirkwood, "Fuss, Futexes and Furwocks: Fast
 * Userlevel Locking in Linux" (Ottawa Linux Symposium, 2002). *)

open Types

(* [syssemacquire p addr block]: 1 acquired, 0 not (not blocking) *)
val syssemacquire : proc -> int -> bool -> int
(* [systsemacquire p addr ms]: 1 acquired, 0 timed out *)
val systsemacquire : proc -> int -> int -> int
(* [syssemrelease p addr n]: the new value *)
val syssemrelease : proc -> int -> int -> int
