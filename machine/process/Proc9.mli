(* Another process's /proc in mini-5i (plan_debugger.md, decision 12):
 * a debugger, a Plan 9 program as any, reads and writes the files of
 * /proc/$pid of the program it debugs, as on Plan 9 (mem, regs, ctl,
 * status, text), and mini-5i makes them. Each of mini-5i's processes
 * is a process of the host (rfork is the host's fork): the target's
 * memory is in another emulator, which answers.
 *
 *     the debugger's mini-5i                the target's mini-5i
 *     read /proc/63/mem at 0x1020
 *       kill 63 SIGUSR1         --------->  between two instructions
 *       63.req: mem 4128 4      --------->    (Plan9.deliver): answer
 *       63.rep: ok + 4 bytes    <---------    it, and the next ones
 *                                             while it is stopped
 *
 * Two named pipes a process, in /tmp/mini-5i-debug, made by the
 * debugger; a request a turn: open, write, close, then the answer
 * read the same way. Nothing is made nor polled for a program that
 * no one debugs: the signal brings it, as a note does. A target
 * stopped (ctl's stop) waits on its pipe for the next request; one
 * blocked in a host call answers when the call returns (a limit).
 *
 * Plan 9's: the kernel's procctl and devproc.c, a stopped process
 * served by its own kernel. Here two emulators, which talk. *)

(* the debugger's signal to its target (SIGUSR1, Linux's number) *)
val signal : int

(* whether this process is stopped by a debugger; traced (ctl's
 * startstop): its next note stops it, the note left for the debugger;
 * hung (ctl's hang, its own): its next exec stops it *)
val stopped : bool ref
val traced : bool ref
val hung : bool ref

(* [serve host ~pid answer]: a request read and answered, and the next
 * ones while [stopped] (the pipes made if no debugger made them yet: a
 * process hung at exec waits for one); [answer request] gives the data, its failure
 * the error; its second result is done after the answer is sent (a
 * kill's exit) *)
val serve : Host_calls.t -> pid:int -> (string -> string * (unit -> unit)) -> unit

(* the target's pipes removed (it was killed) *)
val forget : Host_calls.t -> int -> unit

(* [ask host pid request]: the target's answer, Error with its text;
 * the target signalled first unless [stopped] says it waits. Error
 * "process exited" when pid is not a process of mini-5i *)
val ask : Host_calls.t -> int -> stopped:bool -> string -> (string, string) result
