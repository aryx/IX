(* trace prints the system calls of a process as it makes them, one
 * line per call. The lines go to the error output, so that trace prog
 * > f keeps the program's own output apart (plan_tiny_debugger.md,
 * section 5):
 *
 *     % trace cat f
 *     open("f", 0) = 5
 *     read(5, "hello\n", 4096) = 6
 *     hello
 *     write(1, "hello\n", 6) = 6
 *     read(5, "", 4096) = 0
 *     close(5) = 0
 *     exit(0)
 *
 *     % trace -f rc -c 'cat f | wc'      the children too, each line
 *                                         with its [pid]
 *     % trace 12                          a process already running
 *
 * Here is how it works. trace starts its program stopped at its first
 * instruction (a child that calls trace(0), then exec), or attaches to
 * a running process by its pid. Either way it talks to the kernel
 * through the trace descriptor (TinyDebugger.mli has a picture of it).
 * It sends y, then loops over the stops:
 *
 *     trace                    tiny-kernel                cat
 *     "y"            ------>   a stop at each sys
 *                                                    <--- sys 2 (read)
 *                   <------    "call 2 5 8192 4096"       Stopped
 *     "c"            ------>   does the read (or waits
 *                              for it to end, in runnable)
 *                   <------    "ret 2 6"                  Stopped
 *     "m 8192 6"     ------>   the bytes it read
 *                   <------    "68656c6c6f0a"
 *     "c"            ------>                         ---> runs on
 *
 * - {b Two stops per call, not one line after it.} Some arguments can
 *   only be read before the call: an exec's path is gone afterwards,
 *   since the memory then belongs to the new program. Others can only
 *   be read after it, such as the bytes of a read. The kernel keeps
 *   nothing of the call and decodes nothing. trace has the table of the
 *   calls (the numbers of syscall in TinyKernel.ml, in user.h's order)
 *   and the kind of each argument: a number, a path, bytes given (with
 *   their length in the next argument), bytes filled (as many as the
 *   result says), or an address.
 * - {b -f} sends the command f, which makes the kernel also trace the
 *   children the process forks, with the same tracer and the same
 *   stops. trace opens a descriptor on each child when the fork returns
 *   its pid (trace(pid) gives it; until then the child's stops are
 *   held), and waits on all of them with ready.
 *
 * kept:
 * Our choices:
 * - The bytes of a call are shown as C strings, only their first 32
 *   (as strace does), and a read of nothing is shown as "" rather than
 *   the address of its buffer.
 * - There is one descriptor per process, where strace has one ptrace
 *   for all of them.
 * - A fault stops the process, and trace then kills it.
 *
 * dropped:
 * strace's options are dropped: choosing which calls to show (-e), the time of
 * each call or its length (-t, -T), a table of counts at the end (-c),
 * the number of bytes shown (-s), and detaching to let the process go
 * on untraced. Every call of the process is printed, so a long run is
 * read with grep on trace's error output.
 *
 * twist:
 * Unlike ratrace's kernel, which formats each call as a line of text
 * (principia's syscallfmt.c, some 380 lines that know every call's
 * arguments), tiny-kernel decodes nothing: it stops the process and
 * gives the call's numbers, and trace reads the strings and bytes from
 * the process's memory. So a new call changes trace's table and not
 * the kernel. Following children needs no parsing of lines either:
 * ratrace finds a fork by searching its line for Rfork and RFPROC,
 * where here a child's stops are held until trace(pid) gives trace
 * its descriptor.
 *
 * others:
 * Linux's strace stops the process at each call's entry and exit with
 * ptrace's PTRACE_SYSCALL, as here; Solaris's truss reads /proc.
 * DTrace (Solaris, 2005) and Linux's eBPF trace without stopping the
 * process, with code that the kernel runs at the call.
 *
 * plan9-is-cleaner:
 * Plan 9's ratrace is a program on top of /proc: it writes startsyscall
 * to the process's ctl file and reads the line of each stop from
 * /proc/n/syscall (principia's debuggers/tracers/ratrace.c). So the
 * kernel only adds a word to ctl, not a system call. Here the same
 * role is played by y on the trace descriptor.
 *
 * references:
 *  - strace(1)
 *  - Plan 9's ratrace(1) and proc(3) manual pages
 *  - plan_tiny_debugger.md
 *)

(* [main] follows the stops of the command's processes until they exit. *)
val main :
  < Cap.forkew; Cap.kill; Cap.stderr; .. > -> string array -> Exit.t
