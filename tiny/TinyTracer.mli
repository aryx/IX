(* trace: the system calls of a process as it makes them, a line each
 * on the error output, so that trace prog > f keeps the program's
 * output apart (plan_tiny_debugger.md, section 5):
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
 *     trace -f rc -c 'cat f | wc'      the children too, [pid] a line
 *     trace 12                          a process already running
 *
 * How it works: it starts its program stopped at its first instruction
 * (a child that calls trace(0), then exec), or attaches to a process
 * by its pid, on the kernel's trace descriptor (TinyDebugger.mli has
 * its picture); then y, and a loop of stops:
 *
 *     trace                    tiny-kernel                cat
 *     "y"            ------>   a stop at each sys
 *                                                    <--- sys 2 (read)
 *                   <------    "call 2 5 8192 4096"       Stopped
 *     "c"            ------>   the read made (or waited
 *                              for: its end in runnable)
 *                   <------    "ret 2 6"                  Stopped
 *     "m 8192 6"     ------>   the bytes it read
 *                   <------    "68656c6c6f0a"
 *     "c"            ------>                         ---> runs on
 *
 * - {b Two stops, not one line after the call}: before the call an
 *   exec's path is still there (after it, the memory is the new
 *   program's), after it a read's bytes are; the kernel keeps nothing
 *   of the call and decodes nothing. trace has the table of the calls
 *   (TinyKernel.ml's syscall's numbers, user.h's order) and the kind of
 *   each argument: a number, a path, bytes given (their length the
 *   next argument), bytes filled (as many as the result says), an
 *   address.
 * - {b -f}: the command f makes the kernel trace what the process
 *   forks, by the same tracer and with the same stops; trace opens a
 *   descriptor on each child when the fork returns its pid (trace(pid)
 *   gives it, the child's stops kept till then), and waits on them all
 *   with ready.
 *
 * What is ours: a call's bytes shown as C strings, their first 32
 *   (strace's), and a read of nothing as "" rather than its buffer's
 *   address; one descriptor a process, rather than strace's one
 *   ptrace for all of them; a fault stops the process, which trace
 *   then kills.
 *
 * plan9-is-cleaner:
 * Plan 9's ratrace is a program over /proc: it writes startsyscall to
 * the process's ctl and reads each stop's line from /proc/n/syscall
 * (principia's debuggers/tracers/ratrace.c); the kernel adds a word to
 * ctl, not a system call. Here the same is the trace descriptor's y.
 *
 * others:
 * Linux's strace stops the process at each call's entry and exit with
 * ptrace's PTRACE_SYSCALL, as here; Solaris's truss reads /proc.
 * DTrace (Solaris, 2005) and Linux's eBPF trace without stopping the
 * process, by code the kernel runs at the call.
 *
 * References: plan_tiny_debugger.md; Plan 9's ratrace(1) and proc(3)
 * manual pages; strace(1). *)

(* the program: its command line, the stops of its processes, its exit *)
val main : unit -> unit
