(* debug is a debugger for tiny-kernel's programs, at the level of their
 * machine instructions (not the source). It starts its program stopped
 * at its first instruction (a child that calls trace(0), then exec),
 * or attaches to a process by its pid. It then controls the process
 * through the kernel's trace descriptor, writing commands to it and
 * reading lines back. Its own commands are typed as in ed: a letter
 * and its arguments. An address is a number in hexadecimal (0x1a4) or
 * decimal, pc for the pc, or a function's name with an optional offset
 * (main, main+0x14):
 *
 *     b addr        set a breakpoint      d addr   remove it
 *     c             continue              s        one instruction
 *     n             one instruction, over a call (jal or jalr to lr)
 *     r             the registers, and the instruction at the pc
 *     bt            the backtrace: the calls the pc is in, and an ML
 *                   function's slots on the value stack
 *     x addr [n]    n words               x/i addr [n]  instructions
 *     q             quit (kills the program, or lets it run if attached)
 * usage examples:
 *     $ debug cat f
 *     $ debug -window cat f
 *     $ debug 12 /bin/cat
 *
 * At each stop it shows why, and the instruction at the pc, located by
 * the function it is in, as in main+0x14. The names are the labels that
 * tiny-ld wrote after the image (-s, see TinyLibMachine). debug reads
 * them from the program's file: the one it started, or the one named
 * after the pid when it attaches (the kernel knows a process's image,
 * not the file it came from).
 *
 * Here is how it works. debug and its program are two processes, and the
 * kernel stands between them. Every command is a line written on the
 * descriptor that trace(pid) returned, and every answer and every stop
 * is a line read from it (see command and stop in TinyKernel.ml):
 *
 *     debug                     tiny-kernel                 cat
 *     t = trace(pid)
 *     "b 4096"        ------>   saves the word at 4096,
 *                    <------    writes 0 there; "ok"
 *     "c"             ------>   cat Ready ---------------->  runs
 *                                                            ... 0 at 4096:
 *                               illegal, cat Stopped  <----  a trap
 *                    <------    "stopped 4096 break"
 *     "r", "m 4096 4" ------>   its frame, its memory (the
 *                    <------    saved word, not the 0)
 *     "c"             ------>   runs the saved word alone (a
 *                               step), writes the 0 again,
 *                               cat Ready
 *
 * - {b n is a breakpoint after the call.} On a jal or jalr to lr, n
 *   sets a breakpoint at the next instruction, then does c. In a
 *   recursive function, a deeper call of the same function reaches
 *   that breakpoint first; the sp tells them apart (a lower sp means a
 *   deeper call, which is run past), as gdb's next does.
 * - {b bt reads the code.} There is no frame pointer and no table of
 *   frame sizes, but every function made by tiny-cc and tiny-ml starts
 *   with addi sp, sp, -f and stw lr, k(sp), and the third instruction
 *   of an ML function is addi r12, r12, v, which gives its frame on the
 *   value stack. So the name gives the start of the function, its first
 *   words give the frame size, the frame gives the return address, and
 *   the return address gives the caller. Assembly without that
 *   prologue (start.s's write, _start) ends the walk.
 * - {b The window} (-window) runs the same commands, inside
 *   TinyLibGUI's run_canvas. After each command it shows the
 *   registers, the instructions around the pc and the backtrace, then
 *   what the commands printed and what the program wrote, then the
 *   last command typed. The program's output is a pipe, read while the
 *   program runs so that it never fills up. On an empty line, s, n and
 *   c run at once, and there are buttons for them. While the program
 *   runs (c), the window waits for it to stop.
 *
 * kept:
 * Where we differ from Plan 9's tools and gdb:
 *
 * - The debugger uses {b one descriptor and a system call}, not a
 *   directory of files. trace(pid) returns the descriptor, and trace(0)
 *   asks to be traced by the parent (Unix's PTRACE_TRACEME). The
 *   commands are text, as in /proc's ctl file.
 * - {b The kernel keeps the breakpoints.} b gives it the address and
 *   the kernel saves the word; m shows the saved word, c and s run it,
 *   and the child of a fork gets the original words back. Plan 9's db
 *   writes the breakpoint instruction itself, through /proc/n/mem, and
 *   keeps the words in its own table (db's runpcs.c, with a flag per
 *   breakpoint to skip it once when continuing from it).
 * - {b bt reads the prologues.} Plan 9's linkers instead write the
 *   frame size of each function in the symbol table (a .frame symbol,
 *   read by libmach's sym.c), and the stack walk reads it there.
 * - {b The commands are gdb's letters} (b, c, s, n, bt, x/i), not db's
 *   adb syntax (main:b, :c, $c), which readers today know less well.
 * - {b The names are lines of text after the image}, in the map's
 *   format, rather than a binary symbol table, and only functions have
 *   names; there are no line numbers and no types. db too shows a
 *   function and an instruction.
 *
 * dropped:
 * {b The source.} It debugs machine instructions only: a breakpoint is
 * an address or a function's name, a step is one instruction, and no
 * line of C or ML is shown or stepped over, since neither tiny-cc nor
 * tiny-ml writes a table from pcs to lines (tiny-ld has no -g).
 * Also dropped are watchpoints, conditional breakpoints, printing a C
 * variable or an ML value according to its type (this needs the
 * compilers to describe their frames, which is acid's road), and
 * debugging the kernel itself.
 *
 * twist:
 * {b A step is the timer's interrupt.} kentry.s's k_step sets the timer
 * to ring after one instruction of the process, then runs the process
 * like any other. No instruction is decoded to find where the next one
 * is. In contrast, db's runstep asks libmach for the addresses where
 * the instruction can go next (machdata's foll, which gives two for a
 * branch) and puts temporary breakpoints there (db's trcrun.c); and
 * Unix's PTRACE_SINGLESTEP sets the CPU's trap flag.
 *
 * context:
 * Its sibling is trace (TinyTracer), which applies strace's idea to the
 * same descriptor: it stops the program before and after each system
 * call.
 *
 * exercises:
 * - reverse step by replay: tiny-machine is deterministic (-events,
 *   -seed, -date), so a step back can be done by running the session
 *   again up to the previous instruction, as rr does, with no log of
 *   undos.
 *
 * cs-history:
 * Unix's first debugger was db, then adb (Steve Bourne, Seventh
 * Edition, 1979), with its terse syntax of addresses and verbs; sdb and
 * dbx added source lines, and gdb (Richard Stallman, 1986) became the
 * free one. /proc came from Tom Killian, in the Eighth Edition ("Processes
 * as Files", 1984), and Plan 9 made it a directory. Plan 9's db keeps
 * adb's syntax; acid (Phil Winterbottom, 1994) is a debugger built on a
 * language, where the printing of each type is a function written in
 * acid.
 *
 * others:
 * gdb drives its program by ptrace on Unix, and by a remote protocol
 * of text packets (gdbserver, QEMU's stub) elsewhere, where the
 * commands are lines on a wire, as here. LLDB (2010) is built on LLVM's
 * disassemblers and its compiler's knowledge of types.
 *
 * plan9-is-cleaner:
 * On Unix a debugger drives its program with ptrace, a system call of
 * a dozen requests (peek a word, poke a word, get the registers,
 * continue, step), one word at a time, and only a parent or an
 * attached tracer may call it. Plan 9 makes a process a directory of
 * files, /proc/n: mem is its memory, regs holds its registers, ctl is
 * a file of text commands (stop, start, waitstop), and note carries its
 * signals. A debugger is then a program that reads and writes files,
 * and it can debug a process on another machine by importing that
 * machine's /proc. The trace descriptor is that idea in a single
 * file.
 *
 * references:
 *  - S. R. Bourne, "A. Debugging with adb" (Seventh Edition's manual,
 *    1979; from memory)
 *  - T. J. Killian, "Processes as Files" (USENIX, 1984)
 *  - P. Winterbottom, "Acid: A Debugger Built From A Language" (USENIX,
 *    1994)
 *  - Plan 9's proc(3), db(1) and ratrace(1) manual pages
 *  - principia's debuggers/ (db, acid, libmach, tracers/ratrace.c):
 *    read for the comparisons above, not copied
 *  - plan_tiny_debugger.md: the design and its steps
 *)

(* The program reads its command line, then its commands, until it
 * exits.
 * caps includes what a window needs (-window, with TinyLibGUI's
 * run_canvas), and stdout, where it prints its answers at once. *)
val main :
  < Cap.clock; Cap.keyboard; Cap.open_in; Cap.pipe; Cap.forkew; Cap.kill;
    Cap.stdout; Cap.stderr; .. > ->
  string array -> Exit.t
