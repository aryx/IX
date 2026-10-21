(* debug: a debugger for tiny-kernel's programs, at the level of their
 * instructions (plan_tiny_debugger.md). It starts its program stopped
 * at its first instruction (a child that calls trace(0), then exec),
 * or attaches to a process by its pid, and controls it through the
 * kernel's trace descriptor: commands written, lines read. Its own
 * commands are typed as ed's, a letter and its arguments; an address
 * is a number in hexadecimal (0x1a4) or decimal, pc for the pc, or a
 * function's name and maybe an offset (main, main+0x14):
 *
 *     b addr        a breakpoint          d addr   one removed
 *     c             continue              s        one instruction
 *     n             one instruction, over a call (jal or jalr to lr)
 *     r             the registers, and the instruction at the pc
 *     bt            the backtrace: the calls the pc is in, and an ML
 *                   function's slots on the value stack
 *     x addr [n]    n words               x/i addr [n]  instructions
 *     q             quit (the program killed, or left to run if attached)
 *
 *     debug cat f
 *     debug -window cat f
 *     debug 12 /bin/cat
 *
 * At each stop it shows why, and the instruction at the pc, by the
 * function it is in: main+0x14. The names are the labels tiny-linker
 * wrote after the image (-s, TinyLibSymbols), read from the program's
 * file: the one started, or the one named after an attached pid (the
 * kernel knows a process's image, not its file).
 *
 * How it works: debug and its program are two processes, and the
 * kernel stands between them. Every command is a line written on the
 * descriptor trace(pid) gave, every answer and every stop a line read
 * from it (TinyKernel.ml's command and stop):
 *
 *     debug                     tiny-kernel                 cat
 *     t = trace(pid)
 *     "b 4096"        ------>   the word at 4096 kept,
 *                    <------    0 written there; "ok"
 *     "c"             ------>   cat Ready ---------------->  runs
 *                                                            ... 0 at 4096:
 *                               illegal, cat Stopped  <----  a trap
 *                    <------    "stopped 4096 break"
 *     "r", "m 4096 4" ------>   its frame, its memory (the
 *                    <------    kept word, not the 0)
 *     "c"             ------>   the kept word run alone (a
 *                               step), the 0 written again,
 *                               cat Ready
 *
 * - {b A step is the timer's interrupt}: entry.tm's k_step sets the
 *   timer to ring after one instruction of the process, then runs it
 *   as any other. No instruction is decoded to find where the next
 *   one is.
 * - {b n is a breakpoint after the call}: on a jal or jalr to lr, a
 *   breakpoint at the next instruction, and c. In a recursive function
 *   a deeper call of the same one comes back there first; the sp tells
 *   them apart (lower: a deeper call's, run past), as gdb's next does.
 * - {b bt reads the code}: no frame pointer and no table of frame
 *   sizes, but every function of tiny-c's and tiny-ml's starts with
 *   addi sp, sp, -f and stw lr, k(sp), and an ML function's third
 *   instruction is addi r12, r12, v, its frame on the value stack. So
 *   the name gives the function's start, its first words the frame,
 *   the frame the return address, and that the caller. Assembly without
 *   that prologue (start.tm's write, _start) ends the walk.
 * - {b The window} (-window) is the same commands, run by
 *   TinyLibGUI's run_canvas: the registers, the instructions around the
 *   pc and the backtrace shown after each one, then what the commands
 *   said and what the program wrote (its output a pipe, read while it
 *   runs, so that it never fills), the command typed last; s, n and c
 *   at once on an empty line, and buttons for them. While the program
 *   runs (c) the window waits for its stop.
 *
 * Its sibling is trace (TinyTracer), strace's idea on the same
 * descriptor: a stop before each system call and after it.
 *
 * What is ours, where Plan 9's tools and gdb go another way:
 *
 * - {b One descriptor and a system call}, not a directory of files.
 *   trace(pid) gives it, trace(0) asks to be traced by the parent
 *   (Unix's PTRACE_TRACEME); the commands are text, as /proc's ctl.
 * - {b The kernel keeps the breakpoints}: b gives it the address, it
 *   keeps the word, m shows the kept word, c and s run it, and a fork's
 *   child gets the words back. Plan 9's db writes the breakpoint
 *   instruction itself, through /proc/n/mem, and keeps the words in its
 *   own table (db's runpcs.c, with a flag per breakpoint to skip it
 *   once when continuing from it).
 * - {b The step by the timer} (above), where db's runstep asks libmach
 *   for the addresses the instruction can go to next (machdata's foll:
 *   a branch's two) and puts temporary breakpoints there (db's
 *   trcrun.c), and Unix's PTRACE_SINGLESTEP sets the CPU's trap flag.
 * - {b bt by the prologues}, where Plan 9's linkers write each
 *   function's frame size in the symbol table (a .frame symbol, read
 *   by libmach's sym.c) and its stack walk reads it.
 * - {b The commands are gdb's letters} (b, c, s, n, bt, x/i), not db's
 *   adb syntax (main:b, :c, $c), which a reader of today knows less.
 * - {b The names are text lines after the image}, the map's format,
 *   rather than a binary symbol table, and only the functions': no
 *   line numbers, no types. A function and an instruction is what db
 *   shows too.
 * - Left out: watchpoints, conditional breakpoints, printing a C
 *   variable or an ML value by its type (that needs the compilers to
 *   describe their frames: acid's road), the kernel itself.
 *
 * plan9-is-cleaner:
 * On Unix a debugger drives its program with ptrace, a system call of
 * a dozen requests (peek a word, poke a word, get the registers,
 * continue, step), one word at a time, and only a parent or an
 * attached tracer may call it. Plan 9 makes a process a directory of
 * files, /proc/n: mem its memory, regs its registers, ctl a file of
 * text commands (stop, start, waitstop), note its signals; a debugger
 * is a program that reads and writes files, and can debug a process
 * of another machine by importing its /proc. The trace descriptor is
 * that idea in a single file.
 *
 * cs-history:
 * Unix's first debugger was db, then adb (Steve Bourne, Seventh
 * Edition, 1979), with its terse syntax of addresses and verbs; sdb and
 * dbx added source lines, and gdb (Richard Stallman, 1986) became the
 * free one. /proc came from Tom Killian, in the Eighth Edition ("Processes
 * as Files", 1984), and Plan 9 made it a directory. Plan 9's db keeps
 * adb's syntax; acid (Phil Winterbottom, 1994) is a debugger built on a
 * language, its printing of each type a function written in acid.
 *
 * others:
 * gdb drives its program by ptrace on Unix, and by a remote protocol
 * of text packets (gdbserver, QEMU's stub) elsewhere: commands as
 * lines on a wire, as here. LLDB (2010) is built on LLVM's
 * disassemblers and its compiler's knowledge of types.
 *
 * References: plan_tiny_debugger.md (the design and its steps);
 * principia's debuggers/ (db, acid, libmach, tracers/ratrace.c), read
 * for the comparisons above, not copied;
 * T. J. Killian, "Processes as Files" (USENIX, 1984); P. Winterbottom,
 * "Acid: A Debugger Built From A Language" (USENIX, 1994); Plan 9's
 * proc(3), db(1) and ratrace(1) manual pages; S. R. Bourne, "A.
 * Debugging with adb" (Seventh Edition's manual, 1979; from memory). *)

(* the program: its command line, its commands, its exit *)
val main : unit -> unit
