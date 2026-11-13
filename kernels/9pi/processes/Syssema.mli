(* The semaphores (principia's syssema.c). A semaphore is an int in the
 * user's memory. Acquiring it decrements it when it is positive, and
 * otherwise waits, when the call blocks (tsemacquire waits for ms
 * milliseconds at most). Releasing it increments it and wakes its
 * waiters. With one core and no preemption in the kernel, acquiring is
 * just a decrement, or a sleep on the word's physical address (which
 * is the same for every process that shares the word).
 *
 *     long s = 1;                  a word of memory two processes share
 *     A: semacquire(&s, 1)         1 -> 0, returns 1 at once
 *     B: semacquire(&s, 1)         0: B sleeps, on Semaphore pa
 *     A: semrelease(&s, 1)         0 -> 1, the sleepers on pa are woken
 *     B:                           looks again: 1 -> 0, returns 1
 *
 * The semaphore is not a thing of the kernel's: no call makes one, no
 * call frees it, and the kernel keeps no table of them. It is the word,
 * wherever the program put it, and the kernel's part is only to wait
 * on it. The physical address is its name because the two processes
 * may have the page at different addresses of their own, or, when they
 * share all their memory (rfork's RFMEM), at the same one.
 *
 * cs-history:
 * Edsger Dijkstra invented semaphores (1965, for the THE system): a
 * counter with two operations, P to take one and wait if there is
 * none, and V to give one back. Every other way of waiting can be
 * built from them. Unix did without them at first (a pipe was its way
 * to wait); System V added them as kernel objects with keys and calls
 * of their own (semget, semop, semctl).
 *
 * others:
 * Linux's futex (2002) is the same idea as here: an int in the user's
 * memory is changed there without a call when no one has to wait, and
 * the kernel is asked only to sleep on its address or to wake those
 * who do. Plan 9's semaphores came a few years later (the paper
 * below); until then its programs waited with rendezvous (Sysproc).
 *
 * References: E. W. Dijkstra, "Cooperating Sequential Processes"
 * (1965). Sape Mullender and Russ Cox, "Semaphores in Plan 9"
 * (International Workshop on Plan 9, 2008). Hubertus Franke, Rusty
 * Russell and Matthew Kirkwood, "Fuss, Futexes and Furwocks: Fast
 * Userlevel Locking in Linux" (Ottawa Linux Symposium, 2002). *)

open Types

(* [syssemacquire p addr block] returns 1 when it acquired the
 * semaphore, and 0 when it did not (only when not blocking) *)
val syssemacquire : proc -> int -> bool -> int
(* [systsemacquire p addr ms] returns 1 when it acquired the semaphore,
 * and 0 when it timed out *)
val systsemacquire : proc -> int -> int -> int
(* [syssemrelease p addr n] returns the new value *)
val syssemrelease : proc -> int -> int -> int
