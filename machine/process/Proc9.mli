(* Another process's /proc in mini-5i (plan_debugger.md, decision 12).
 * A debugger, which is a Plan 9 program like any other, reads and
 * writes the files of /proc/$pid of the program it debugs, as on Plan 9
 * (mem, regs, ctl, status, text), and mini-5i makes those files. Each
 * of mini-5i's processes is a process of the host (rfork is the host's
 * fork), so the target's memory is in another emulator, which answers.
 *
 *     the debugger's mini-5i                the target's mini-5i
 *     read /proc/63/mem at 0x1020
 *       kill 63 SIGUSR1         --------->  between two instructions
 *       63.req: mem 4128 4      --------->    (Plan9.deliver), it
 *       63.rep: ok + 4 bytes    <---------    answers the request,
 *                                             and the next ones while
 *                                             it is stopped
 *
 * Each process has two named pipes, in /tmp/mini-5i-debug, which the
 * debugger makes. There is one request at a time: the debugger opens
 * the pipe, writes and closes it, then reads the answer the same way.
 * Nothing is made or polled for a program that no one debugs, because
 * the signal brings the request, as a note does. A stopped target
 * (ctl's stop) waits on its pipe for the next request. A target
 * blocked in a host call answers when the call returns, which is a
 * limit.
 *
 * On Plan 9, the kernel's procctl and devproc.c do this, and a stopped
 * process is served by its own kernel. Here two emulators talk to
 * each other. *)

(* the signal the debugger sends to its target (SIGUSR1, Linux's
 * number) *)
val signal : int

(* [stopped] says whether this process is stopped by a debugger. When
 * it is [traced] (ctl's startstop), its next note stops it, and the
 * note is left for the debugger. When it is [hung] (by its own ctl's
 * hang), its next exec stops it. *)
val stopped : bool ref
val traced : bool ref
val hung : bool ref

(* [serve host ~pid answer] reads a request and answers it, and the
 * next ones while [stopped]. It makes the pipes if no debugger made
 * them yet, since a process hung at exec waits for one. [answer
 * request] gives the data, and its failure gives the error. Its second
 * result is run after the answer is sent (for a kill's exit). *)
val serve : Host_calls.t -> pid:int -> (string -> string * (unit -> unit)) -> unit

(* removes the target's pipes (when it was killed) *)
val forget : Host_calls.t -> int -> unit

(* [ask host pid request] returns the target's answer, or Error with
 * its text. The target is signalled first, unless [stopped] says it
 * is waiting. It returns Error "process exited" when pid is not a
 * process of mini-5i. *)
val ask : Host_calls.t -> int -> stopped:bool -> string -> (string, string) result
