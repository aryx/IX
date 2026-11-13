(* What a program waits for from the system, turned into messages on a
 * channel (plan_rio.md, "Threads: the design"). A thread never reads a
 * descriptor that may block. Instead it receives from a source's
 * channel, and it may choose between several channels (Event.select).
 *
 * There are two files, for the two kinds of threads:
 *  - this directory's file is for OCaml's threads (dune's builds): a
 *    thread does the read and sends what it read;
 *  - ../concurrency/'s file is for mini-ml's threads, which are
 *    cooperative, so a thread that reads stops them all. There a
 *    process of its own does the read, and writes each read, with the
 *    source's number and its length, to one pipe. The scheduler reads
 *    that pipe when no thread can run.
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
 * So a program is a loop of events, but no one writes the loop. Each
 * thread receives from the channels it cares about (a window receives
 * from its keys and its mouse), and what the system has for it comes
 * the same way as what another thread has for it. mini-rio's Keyboard
 * and Mouse, its file server's requests, and the Plan 9 platform's
 * loop are made this way.
 *
 * plan9-is-cleaner:
 * Unix answers "wait for the first of these descriptors" by a system
 * call made for it (select in 4.2BSD, then poll, then Linux's epoll),
 * and by a program built around that call. Plan 9 has no such call.
 * A process is cheap and shares memory when asked to (rfork), so each
 * thing waited for gets a process that waits in an ordinary read, and
 * the program makes the choice itself, on channels (libthread's alt).
 * That is what this module's second file does; the first file has
 * OCaml's threads do the reading.
 *
 * References: docs/notes/notes_source.md (this design from the start,
 * why it does not use the system's threads, and what was met since);
 * plan_rio.md, "Threads: the design"; thread(2) and ioproc(2) of
 * Plan 9; Rob Pike, "A Concurrent Window System" (Computing Systems,
 * 1989), which builds a window system as processes on channels, the
 * design rio has. *)

(* [reader caps fd n]: each read of fd (of n bytes at most, and 4000 at
 * most) becomes a message. The last message is an empty one, sent at
 * the end of fd or when a read fails. *)
val reader : < Cap.fork; .. > -> Unix.file_descr -> int -> bytes Event.channel

(* [timer caps d]: a message comes every d seconds *)
val timer : < Cap.fork; Cap.clock; .. > -> float -> unit Event.channel

(* [alarm caps]: a clock that you ask each time. Given d, the first
 * function of the pair makes one message come on the channel d seconds
 * later. Ask once at a time, and ask again only after the message came.
 * It is for a loop that may be slower than its clock: a timer's
 * messages would pile up in front of it, and what else it waits for
 * (a key) would wait behind them. *)
val alarm : < Cap.fork; Cap.clock; .. > -> (float -> unit) * unit Event.channel
