(* What a program waits for from the system, as messages on a channel
 * (plan_rio.md, "Threads: the design"): a thread never reads a
 * descriptor that may block; it receives from a source's channel, and
 * may choose between several (Event.select).
 *
 * Two files, for the two kinds of threads. This directory's, for
 * OCaml's (dune's builds): a thread reads and sends. And
 * ../concurrency/'s, for mini-ml's, which are cooperative (a thread
 * that reads stops them all): a process of its own reads, and writes
 * each read, with the source's number and its length, to one pipe,
 * which the scheduler reads when no thread can run.
 *
 *     the keyboard --> a process, in read --.
 *     a 9P client  --> a process, in read --+--> one pipe --> the
 *     the clock    --> a process, in sleep -'    program, when its
 *                                                threads all wait
 *     a frame on the pipe:  [ source | length, 2 bytes | the bytes ]
 *
 *     the program:  frame --> its source's thread --> the channel
 *                   --> Event.sync (Event.receive keys), or a choice
 *
 * So a program is a loop of events with no loop written: each thread
 * receives from the channels it cares for (a window from its keys
 * and its mouse), and what the system has for it comes the same way
 * as what another thread has. mini-rio's Keyboard and Mouse, its
 * file server's requests and the Plan 9 platform's loop are made so.
 *
 * plan9-is-cleaner:
 * Unix answers "wait for the first of these descriptors" by a system
 * call made for it (select in 4.2BSD, then poll, then Linux's epoll)
 * and a program built around that call. Plan 9 has no such call: a
 * process is cheap and shares memory when asked (rfork), so each
 * thing waited for gets a process that waits in an ordinary read,
 * and the choice is made in the program, on channels (libthread's
 * alt). That is this module's second file; the first has OCaml's
 * threads do the reading.
 *
 * References: plan_rio.md, "Threads: the design"; thread(2) and
 * ioproc(2) of Plan 9; Rob Pike, "A Concurrent Window System"
 * (Computing Systems, 1989), a window system as processes on
 * channels: the design rio has. *)

(* [reader caps fd n]: each read of fd (n bytes at most, 4000 at most)
 * a message; an empty one at its end, or when a read fails, the last *)
val reader : < Cap.fork; .. > -> Unix.file_descr -> int -> bytes Event.channel

(* [timer caps d]: a message every d seconds *)
val timer : < Cap.fork; .. > -> float -> unit Event.channel

(* [alarm caps]: a clock that is asked each time: the first of the pair,
 * given d, has one message come on the channel d seconds later. One
 * asking at a time (the next after its message came). For a loop that
 * may be slower than its clock: a timer's messages would pile up before
 * it, and what else it waits for (a key) behind them. *)
val alarm : < Cap.fork; .. > -> (float -> unit) * unit Event.channel
