(* A tiny kernel, in ML, for tiny-machine (TinyMachine.ml): the
 * essential of an operating system, with nothing borrowed from an
 * existing one but ideas. Compiled by tiny-ml -tm (TinyML.ml's second
 * back end), its runtime TinyML's (Cheney's collector, in C by
 * tiny-c -tm), its user programs C (tiny-c -tm, tiny-os's libc):
 *
 *     ./tiny-machine tiny-kernel   (at the top of ix; or make run in TinyKernel/)
 *     $ echo hello | wc; mkdir d; cd d; echo x > f; cd ..; cat d/f; ls
 *     $ mltests
 *     ./tiny-machine -window tiny-kernel      its screen in a window
 *     $ paint                                 or windows, and paint in a window
 *
 * Why free. ix's mini-xxx twin an original program; its tiny-xxx keep
 * what is fundamental and drop the rest by what it costs. A kernel
 * seems to ask for a twin, xv6's or 9pi's, for two reasons: it is not
 * a leaf (its system calls are a contract with every program above it,
 * so a new interface means a new userland), and a reference answers
 * the hard questions (what wait returns when, what a dead pipe's
 * reader sees), which has been mini-9pi's and mini-xv6's first
 * debugging tool. But xv6 is tiny for C: locks, a kernel stack per
 * process, an on-disk file system. In ML other roads are shorter, so
 * this one keeps the concepts and chooses each one's how:
 *
 *   concept                    kept how                              why cheap here
 *   user and kernel modes,     a trap returns from k_run; the call   the machine has one way in
 *   system calls               a match on its number                 and one way out
 *   preemptive scheduling      round robin on the timer              a list, the ran one moved last
 *   protection                 tiny-machine's window, relocating:    no page tables to build
 *                              a partition of 1 MB a process
 *   processes                  fork, exec, exit, wait                with a window, fork copies a
 *                                                                    partition: one k_copy
 *   blocking                   a closure per waiting process, the    no kernel stack per process,
 *                              call's rest, retried by the scheduler no swtch, no sleep, no locks
 *   files and directories      a tree of ML values in the heap       no disk format, no mkfs, no
 *                                                                    buffer cache, no log
 *   console, pipes             other kinds of open file              pipes make a shell a shell
 *   a screen, a mouse          a program's descriptors 3 and 4: it   TinyGraphics.ml draws; no
 *                              writes messages (the kernel has the   memory is shared, so none
 *                              pixels) and reads the mouse's place   to map
 *   a window system            a program (TinyWindows.ml): pipes,    what a window's program is
 *                              and a box, a pipe that keeps the      given looks like what the
 *                              last write only (a window's mouse)    kernel gives
 *   waiting for several        ready(fds, n, until): one more        the closure again: a list
 *   things, or for a time      closure, with the clock's ticks       looked at, no select's queues
 *
 * Dropped: the disk (the files come in the boot image, after the
 * kernel, and live in memory: what a program writes is lost at the
 * halt), pages, several cores, users and permissions, signals but
 * the simplest: kill(pid) ends a process as a fault does (its status
 * -1), and ^C at the console every process but the shell. The system
 * calls are this kernel's own (its programs are in TinyKernel/user/,
 * and tiny-os t6's cat, echo, ls, wc, mkdir and rm run unchanged, as
 * they use only calls in common).
 *
 * Where it sits: ix's Kernel row (README), its tiny program, as mini-9pi
 * is its mini one; not a version of tiny-os (v0, v6, t6, on the same
 * machine, in assembly and C). TinyKernel/ holds the rest: entry.tm,
 * runtime.c, the user programs, the Makefile.
 *
 * The toolchain, all ix's, and its bridge between ML and the machine,
 * small where mini-9pi's and mini-xv6's (kernels/lib_machine/: ocaml-light's C
 * runtime, gcc, boot code, a C glue) cannot be:
 * - tiny-ml -tm: the stack machine's second back end (TinyML.ml);
 * - the runtime: TinyML/core.c, shared with every tiny-ml program, and
 *   runtime.c, the kernel's memory and ten functions of bytes (peek,
 *   poke, a string from memory and to it);
 * - entry.tm, a page of assembly: k_run (the process run until its next
 *   trap: the kernel calls a process as a function, as a hypervisor's
 *   KVM_RUN runs a guest), the trap's entry, the timer, the window.
 * No new primitive in the compiler: the machine is reached through
 * externals, functions of C or of assembly.
 *
 * How it runs. The toplevel reads the files the image carries, makes
 * the first process (/sh, the console its 0, 1 and 2), and enters
 * [schedule], a loop that never returns: run a process until it traps,
 * handle the trap, choose again. A process is its slot (a partition,
 * and a frame of 17 words where entry.tm saves its registers), its pid,
 * its state, its parent, its descriptors and its current directory. A
 * system call that must wait (a read of an empty pipe, a wait) leaves
 * its process Waiting with the rest of the call as a closure; the
 * scheduler calls it when it looks for a process to run, and the
 * process is ready again when the closure could finish. So there is no
 * wakeup to forget (the lost-wakeup bug of sleep and wakeup) and no
 * channel: waiting is on a condition, as Brinch Hansen's await and
 * Plan 9's sleep(r, cond), paid for by a retry per round.
 *
 * The machine's 16 MB as the kernel cuts them (runtime.c has the
 * numbers; a process sees only its own megabyte, from 0, the
 * machine's window relocating):
 *
 *     0x000000   the image: entry.tm, the runtime, this file; then the
 *                files it carries, a name, a size, the bytes
 *     0x280000   the value stack: the kernel's own roots (TinyML's)
 *     0x2c0000   the frames, 68 bytes a slot: r1 to r15 and the pc of
 *                a process that is not running
 *     0x300000   the heap, two halves of 1 MB: every file written,
 *                every pipe, descriptor table and closure
 *     0x500000   eight partitions of 1 MB, a slot each
 *     0xd00000   the images' pixels: the font, the windows not shown
 *     0xf00000   the screen, 640 by 480 bytes; images again after it
 *     0xffffe0   the devices
 *
 * A process is two things that do not look alike: its megabyte and
 * frame, plain memory the collector never sees, reached by peek and
 * poke; and its record, an ML value, where its descriptors are a list
 * of (number, file) and a file a variant. A read that must wait, the
 * mechanism whole (wc reading a pipe nothing was written to yet):
 *
 *     wc: sys read      the trap ends k_run; [syscall] finds the file
 *                       and the buffer and calls [block] with the
 *                       attempt, a closure: read what is there, put
 *                       the count in the frame's r1, say true
 *     the attempt       says false: the pipe is empty and has a
 *                       writer; wc is Waiting of that closure, and
 *                       goes last in the round
 *     [schedule]        [runnable] goes down the list: for a Ready
 *                       process, that one; for a Waiting one, its
 *                       closure called again
 *     echo: sys write   the pipe's buffer is longer; echo runs on
 *     [schedule]        wc's closure says true this time: the answer
 *                       is already in its frame, it is Ready, k_run
 *
 * Nothing links the pipe to the processes that wait on it: no queue,
 * no channel, no wakeup. The closure holds the file, the address and
 * the count, which in a C kernel are what the sleeping process's
 * kernel stack is kept for.
 *
 * The test: make check in TinyKernel/, mltests (fork, exec, wait's statuses,
 * pipes and their end, files, directories and "..", a fault killed,
 * preemption) and a script through the shell, against check.expected;
 * and three sessions with a recorded mouse and keys, the screen at the
 * halt against its sum: paint, tiny-windows, and tiny-windows in one of
 * its windows.
 *
 * Exercises, each cheap in this design:
 * - the files saved: the tree written at the halt to a disk (-d), read
 *   at the boot instead of the image's (Marshal's idea, by hand);
 * - a waiting process's closure kept with what it waits for, retried
 *   only when that changes (a wakeup, again, but typed);
 * - copy-on-write fork: the partition shared until one side writes,
 *   with pages (tiny-machine's Sv32), the reason pages came;
 * - the kernel's own heap measured: its live words after each
 *   collection, printed at the halt.
 *
 * cs-history:
 * The sixth edition's kernel (1975), the one John Lions's commentary
 * made a textbook, blocks a process by sleep(chan, pri) and wakes
 * every sleeper on that address by wakeup(chan); each process has a
 * kernel stack, and swtch, which changes stacks, carries the comment
 * "You are not expected to understand this". xv6 keeps all three,
 * with a lock passed to sleep so that a wakeup cannot fall between
 * the test and the sleep. This file's waiting has no such window
 * because the test is the waiting.
 *
 * design:
 * A kernel either keeps a stack for each process and blocks in the
 * middle of a call (Unix, Linux, xv6, Plan 9), or has one stack and
 * must write down, when a call cannot finish, what is left of it
 * (Mach after Draves's continuations, every event loop). Lauer and
 * Needham argued in 1978 that the two are duals, a program in one
 * mechanically turned into the other. In C the
 * second costs a structure and a function per place a call may stop,
 * which is why C kernels choose stacks; in ML the compiler builds
 * the structure, a closure, and the second is the shorter.
 *
 * wib:
 * Two costs are accepted. A waiting call is tried again at each
 * round instead of being woken, work for nothing while nothing
 * changes (the two shortcuts in [runnable] and [idle] are there
 * because it showed). And fork copies a megabyte whatever the
 * program's size, eight processes being all there are. Both are
 * what a real kernel spends its cleverness on; both are measurable
 * here (the machine counts instructions).
 *
 * comeback:
 * A kernel in a language with a collector and no pointer arithmetic
 * is an old idea that keeps returning: Burroughs's MCP in an Algol
 * (1961), the Lisp machines, Xerox's Pilot in Mesa (1980), SPIN in
 * Modula-3 (1995), Microsoft's Singularity (from 2003), MirageOS
 * in OCaml (2013), and, for the safety without the collector, Rust
 * in Linux (2022). Each time the argument is
 * that the language can do some of the protecting that hardware and
 * discipline do in C.
 * Here protection stays the hardware's (the window); what the
 * language gives is the file tree and the closures.
 *
 * References: P. Brinch Hansen, "Structured
 * Multiprogramming" (CACM 1972), await; R. Pike et al., "The Use of
 * Name Spaces in Plan 9" (1993), and Plan 9's sleep and wakeup; D. M.
 * Ritchie and K. Thompson, "The UNIX Time-Sharing System" (CACM 1974),
 * fork, exec, pipes; R. Draves et al., "Using Continuations to
 * Implement Thread Management and Communication in Operating Systems"
 * (SOSP 1991); A. Kivity et al., "kvm: the Linux Virtual Machine
 * Monitor" (OLS 2007), a guest run by a call that returns at its exit;
 * G. Hunt and J. Larus, "Singularity: Rethinking the Software Stack"
 * (2007), a kernel in a safe, collected language; A. Madhavapeddy et
 * al., "Unikernels" (ASPLOS 2013), MirageOS, an OCaml kernel; P.
 * Denning, "Virtual Memory" (Computing Surveys 1970), partitions before
 * pages. *)

(* A program, and tiny-ml's alone: OCaml does not compile TinyKernel.ml
 * (its externals are entry.tm's and runtime.c's), so nothing checks
 * this file against it. It gives nothing to another file. *)
