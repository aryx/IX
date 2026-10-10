(* '#p', the processes (principia's devproc.c): a directory per process
 * (its pid), its files procdir's. Here: status, args, fd, ns, noteid,
 * segment, ctl (kill), note, notepg (notes posted); the debugger's
 * (mem, regs, text...) not yet.
 *
 *     /proc/63/status    the name, the user, the state (or the system
 *                        call it is in: Pread), times, memory in KB:
 *                        fields of fixed width, a line
 *     /proc/63/args      the command line, quoted as rc reads it
 *     /proc/63/fd        the current directory, then a line a
 *                        descriptor: its number, r or w, the device's
 *                        letter, the qid, the offset, the name
 *     /proc/63/ns        the name space, as the binds that would
 *                        make it again: bind -c #e /env
 *     /proc/63/segment   Text R 00001000 0001b000 ... a line a segment
 *     /proc/63/note      written: the note is posted (Proc.postnote)
 *     /proc/63/notepg    written: posted to its whole note group
 *     /proc/63/ctl       written kill: the note "sys: killed"
 *
 * Nothing is kept for these files: a read computes its text from
 * the proc record at that moment (Types.proc), a write acts on it.
 * The directory itself is the processes' table read by pid, so ls
 * /proc is the list of processes.
 *
 * plan9-is-cleaner:
 * ps is a loop of cat over /proc's status files, and kill prints
 * the echo commands that would do it, for the user to look at and
 * pipe to rc. Unix's ps of the time opened /dev/kmem, the kernel's
 * own memory, and decoded the process table from the kernel's symbol
 * file, as a program with root's rights that broke at each change of
 * a structure; kill, ptrace, getpriority, wait's cousins were calls.
 * And since these are files, another machine's processes are seen,
 * killed or debugged by mounting its /proc: the debugger knows
 * nothing of networks.
 *
 * cs-history:
 * Tom Killian's /proc for the eighth edition of Unix (1984): a file
 * a process, which was the process's memory, and ioctl for the rest,
 * made to replace ptrace for debuggers. Plan 9 turned the file into
 * a directory and the ioctls into files of text. Linux's /proc
 * (1992) took the directory, in text, and went on to put under the
 * same name whatever the kernel had to say (meminfo, cpuinfo,
 * mounts), which is why its newer /sys exists.
 *
 * References: proc(3), ps(1) and kill(1) in the Plan 9 manual. T. J.
 * Killian, "Processes as Files" (USENIX Summer 1984). principia's
 * Kernel.nw (devproc.c). *)

(* the device registered *)
val init : unit -> unit
