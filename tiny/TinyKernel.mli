(* A tiny kernel, written in ML, for tiny-machine (TinyMachine.ml). It
 * contains the essentials of an operating system and borrows nothing
 * from an existing kernel except ideas. Its programs are in ML (most of
 * them) or in C (sh, mltests and the network's):
 *
 *     ./tiny-machine tiny-kernel   (at the top of ix; or make run in TinyKernel/)
 *     $ echo hello | wc; mkdir d; cd d; echo x > f; cd ..; cat d/f; ls
 *     $ ls /; ls /dump                          the next boot: f is still there
 *     $ mltests
 *     ./tiny-machine -window tiny-kernel      its screen in a window
 *     $ paint                                 or windows, and paint in a window
 *
 * Why it is not a twin of an existing kernel. In ix, each mini-xxx is
 * a twin of an original program, while each tiny-xxx keeps what is
 * fundamental and drops the rest according to what it costs. A kernel
 * seems to call for a twin (of xv6 or 9pi) for two reasons. First, it
 * is not a leaf: its system calls are a contract with every program
 * above it, so a new interface means a new userland. Second, a
 * reference implementation answers the hard questions (what wait
 * returns and when, what the reader of a dead pipe sees), and that has
 * been the first debugging tool of mini-9pi and mini-xv6. But xv6 is
 * tiny only for C: it has locks, a kernel stack per process, and an
 * on-disk file system. In ML other paths are shorter, so this kernel
 * keeps the concepts and chooses its own way to implement each one:
 *
 *   concept                how it is done             why it is cheap here
 *   user and kernel        a trap returns from        the machine has one way
 *   modes, system calls    k_run; a system call is a  in and one way out
 *                          match on its number
 *   preemptive scheduling  round robin on the timer   a list; the process that
 *                                                     ran is moved to the end
 *   protection             tiny-machine's relocating  no page tables to build
 *                          window, a 1 MB partition
 *                          per process
 *   processes              fork, exec, exit, wait     with a window, fork just
 *                                                     copies a partition: one
 *                                                     k_copy
 *   blocking               each waiting process has   no kernel stack per
 *                          a closure, the rest of     process, no swtch, no
 *                          its call, retried by the   sleep, no locks
 *                          scheduler
 *   files and directories  the disk's                 no log, no fsck, no map
 *                          (TinyKernelFS.ml):         of free blocks: a commit
 *                          inodes, copied on write,   is one block written; a
 *                          the root; the boot         collector finds the free
 *                          image's, a tree of ML      ones
 *                          values, in a union with
 *                          it
 *   console, pipes         other kinds of open files  pipes make a shell a
 *                                                     shell
 *   a screen, a mouse      descriptors 3 and 4 of a   TinyKernelGraphics.ml
 *                          program: it writes         draws; no memory is
 *                          drawing messages (the      shared, so nothing to map
 *                          kernel owns the pixels)
 *                          and reads the mouse
 *                          position
 *   a window system        a program                  a window's program gets
 *                          (TinyWindows.ml) using     the same kind of
 *                          pipes and a box, a pipe    interface the kernel
 *                          that keeps only the last   gives
 *                          write (for a window's
 *                          mouse)
 *   waiting for several    ready(fds, n, until): one  again a closure: a list
 *   things, or for a time  more closure, using the    is scanned, no select
 *                          clock's ticks              queues
 *
 * The files. The programs come in the boot image, after the kernel,
 * and are read from memory. With a disk (-d), the disk is the root,
 * Plan 9's way: / is a union of the disk's root, of /boot (the image's
 * files alone) and /dump (the snapshots of the boots before), and of
 * the image's files, so /bin is the disk's /bin and /boot/bin together.
 * What is written goes to the disk, and is kept; a file of the image
 * written by its /bin name is copied to the disk first. The first shell
 * starts in /usr/glenda: glenda is the user of a Plan 9 installed from
 * its CD (and the name of its bunny). With no disk, the tree is the
 * image's alone and lives in memory until the halt.
 *
 * What is dropped: paging, multiple cores, users and permissions, and signals
 * except the simplest: kill(pid) ends a process as a fault does (with
 * status -1), and ^C at the console kills every process except the
 * shell. The system calls are specific to this kernel (its programs
 * are in TinyKernel/user/), but t6's cat, echo, ls, wc, mkdir and rm
 * run unchanged, because they use only calls the two kernels have in
 * common.
 *
 * Where it fits: it is the tiny program in ix's Kernel row (see the
 * README), as mini-9pi is the mini one. It is not a new version of the
 * kernels that came before it on the same machine (v0 and t6 in
 * steps/, written in assembly and C). TinyKernel/ holds the rest:
 * entry.tm, runtime.c, the user programs, and the Makefile.
 *
 * The toolchain is entirely ix's own, and so is the bridge between ML
 * and the machine. It is small, where the bridge of mini-9pi and
 * mini-xv6 (kernels/lib_machine/: ocaml-light's C runtime, gcc, boot
 * code, C glue) cannot be:
 * - tiny-ml: the second back end of the stack machine (TinyML.ml);
 * - the runtime: TinyMLRuntime/core.c, shared with every tiny-ml
 *   program, and runtime.c, which holds the kernel's memory layout and
 *   ten functions on bytes (peek, poke, copying a string from memory
 *   and to it);
 * - entry.tm, one page of assembly: k_run (which runs the process until
 *   its next trap, so the kernel calls a process like a function, the
 *   way a hypervisor's KVM_RUN runs a guest), the trap entry, the
 *   timer, and the window; memory.tm, the loops that copy a partition
 *   at fork and zero memory.
 * The compiler needs no new primitive: the machine is reached through
 * externals, which are functions written in C or in assembly.
 *
 * How it runs. The toplevel reads the files carried by the image,
 * creates the first process (/bin/sh, with the console as its 0, 1 and 2),
 * and enters [schedule], a loop that never returns: run a process
 * until it traps, handle the trap, and choose again. A process has a
 * slot (a partition, and a frame of 17 words where entry.tm saves its
 * registers), a pid, a state, a parent, its descriptors and its
 * current directory. A system call that must wait (a read on an empty
 * pipe, or a wait) leaves its process Waiting, with the rest of the
 * call stored as a closure. The scheduler calls that closure when it
 * looks for a process to run, and the process becomes ready again once
 * the closure can finish. So there is no wakeup to forget (the
 * lost-wakeup bug of sleep and wakeup) and no channel: a process waits
 * on a condition, as with Brinch Hansen's await and Plan 9's
 * sleep(r, cond), at the price of one retry per scheduling round.
 *
 * Several harts (tiny-machine -cores n, plan_tiny_multicore.md). The
 * kernel stays hart 0's, whole: one heap, one collector, written for
 * one thread. The others run processes only, in entry.tm's slave loop,
 * which runs no ML: hart 0 writes a process's frame, window and slice
 * in hart k's mailbox and raises k's interrupt; k runs the process
 * until its trap, writes the cause back and raises hart 0's, which
 * handles the trap as one of its own ([back]). So the kernel needs no
 * lock and its structures did not change; what does not scale is the
 * system calls, one hart's, which a compiler makes few of. The first
 * multiprocessor Unix kernels worked the same way, master and slaves
 * (Purdue's dual VAX, Goble and Marsh, 1982):
 *
 *     hart k                                  hart 0
 *     runs P (k's mailbox) ── a trap ──>      [interrupts]: P's trap,
 *     cause, value in the mailbox,            handled as its own ([back]);
 *     hart 0's interrupt; waits               P or another given to k
 *                               <── k's interrupt (frame, window, slice)
 *
 * Here is how the kernel divides the machine's 256 MB (runtime.c has
 * the numbers; a process sees only its own partition, starting at 0,
 * thanks to the machine's relocating window):
 *
 *     0x000000   the image: entry.tm, the runtime, this file; then the
 *                files it carries, each a name, a size, the bytes
 *                (10 MB at most: /src, the sources, are among them)
 *     0xa00000   the file system's buffers and its map of the
 *                disk's blocks (TinyKernelFS.ml)
 *     0xb00000   the value stack: the kernel's own roots (TinyML's)
 *     0xb40000   the frames, 68 bytes per slot: r1 to r15 and the pc
 *                of each process that is not running
 *     0xb41000   the harts' mailboxes, 32 bytes each
 *     0xb50000   a packet's place, sent or received
 *     0xb51000   unused (but the speaker's ring, at 0xc00000)
 *     0xd00000   pixels of images: the font, the hidden windows
 *     0xf00000   the screen, 640 by 480 bytes; more images after it
 *    0x1000000   the heap, two halves of 8 MB: every file written,
 *                every pipe, descriptor table and closure
 *    0x2000000   the processes' partitions: 1 MB each, or what an
 *                a.out's header asks for (tiny-linker -a), found
 *                first-fit when a program starts
 *    0xfffffc0   the devices, reached as -64 to -4
 *
 * A process consists of two very different things. One is its
 * partition and its frame, plain memory that the collector never sees
 * and that is accessed with peek and poke. The other is its record, an
 * ML value, where the descriptors are a list of (number, file) pairs
 * and a file is a variant. Here is the whole mechanism for a read that
 * must wait (wc reading a pipe that nothing has been written to yet):
 *
 *     wc: sys read      the trap ends k_run; [syscall] finds the file
 *                       and the buffer and calls [block] with the
 *                       attempt, a closure that reads what is there,
 *                       puts the count in the frame's r1, and returns
 *                       true
 *     the attempt       returns false: the pipe is empty and still has
 *                       a writer; wc becomes Waiting with that
 *                       closure, and goes to the end of the round
 *     [schedule]        [runnable] goes down the list: a Ready process
 *                       is chosen; for a Waiting one, its closure is
 *                       called again
 *     echo: sys write   the pipe's buffer grows; echo keeps running
 *     [schedule]        this time wc's closure returns true: the
 *                       answer is already in its frame, wc is Ready,
 *                       and k_run runs it
 *
 * Nothing links the pipe to the processes waiting on it: no queue, no
 * channel, no wakeup. The closure holds the file, the address and the
 * count, which is exactly what a C kernel keeps the sleeping process's
 * kernel stack for.
 *
 * Exercises, each cheap in this design:
 * - a cache of the disk's blocks, and the count of the instructions it
 *   saves (each access reads its blocks again: the disk is instant);
 * - keep each waiting process's closure together with what it waits
 *   for, and retry it only when that changes (a wakeup again, but a
 *   typed one);
 * - copy-on-write fork: share the partition until one side writes,
 *   using pages (tiny-machine's Sv32), which is why pages were
 *   invented;
 * - measure the kernel's own heap: print its live words after each
 *   collection, and at halt.
 *
 * cs-history:
 * The sixth edition Unix kernel (1975), the one that John Lions's
 * commentary turned into a textbook, blocks a process with
 * sleep(chan, pri) and wakes every process sleeping on that address
 * with wakeup(chan). Each process has a kernel stack, and swtch, which
 * switches stacks, carries the comment "You are not expected to
 * understand this". xv6 keeps all three, and adds a lock passed to
 * sleep so that a wakeup cannot slip in between the test and the
 * sleep. This file's waiting has no such window, because the test
 * itself is the waiting.
 *
 * design:
 * A kernel either keeps a stack for each process and blocks in the
 * middle of a call (Unix, Linux, xv6, Plan 9), or has a single stack
 * and must record, when a call cannot finish, what remains to be done
 * (Mach after Draves's continuations, and every event loop). Lauer and
 * Needham argued in 1978 that the two are duals: a program written in
 * one style can be mechanically turned into the other. In C the second
 * style costs a structure and a function for each place where a call
 * may stop, which is why C kernels choose stacks. In ML the compiler
 * builds that structure for us, a closure, and the second style is the
 * shorter one.
 *
 * wib:
 * Two costs are accepted. First, a waiting call is retried at every
 * round instead of being woken up, which wastes work while nothing
 * changes (the two shortcuts in [runnable] and [idle] exist because
 * this showed up). Second, fork copies a whole megabyte whatever the
 * size of the program, and there can be only eight processes. Both
 * are things a real kernel spends its cleverness on, and both can be
 * measured here (the machine counts instructions).
 *
 * comeback:
 * A kernel written in a language with a garbage collector and no
 * pointer arithmetic is an old idea that keeps coming back: Burroughs's
 * MCP in an Algol dialect (1961), the Lisp machines, Xerox's Pilot in
 * Mesa (1980), SPIN in Modula-3 (1995), Microsoft's Singularity (from
 * 2003), MirageOS in OCaml (2013), and, for safety without a
 * collector, Rust in Linux (2022). Each time, the argument is that the
 * language can do some of the protection that hardware and discipline
 * do in C. Here protection is still done by the hardware (the window);
 * what the language provides is the file tree and the closures.
 *
 * References:
 *  - P. Brinch Hansen, "Structured Multiprogramming" (CACM 1972): await
 *  - R. Pike et al., "The Use of Name Spaces in Plan 9" (1993), and
 *    Plan 9's sleep and wakeup
 *  - D. M. Ritchie and K. Thompson, "The UNIX Time-Sharing System"
 *    (CACM 1974): fork, exec, pipes
 *  - R. Draves et al., "Using Continuations to Implement Thread
 *    Management and Communication in Operating Systems" (SOSP 1991)
 *  - A. Kivity et al., "kvm: the Linux Virtual Machine Monitor" (OLS
 *    2007): a guest run by a call that returns when the guest exits
 *  - G. Hunt and J. Larus, "Singularity: Rethinking the Software
 *    Stack" (2007): a kernel in a safe, garbage-collected language
 *  - A. Madhavapeddy et al., "Unikernels" (ASPLOS 2013): MirageOS, a
 *    kernel in OCaml
 *  - P. Denning, "Virtual Memory" (Computing Surveys 1970): partitions
 *    before pages
 *)

(* A program, and tiny-ml's alone: OCaml does not compile TinyKernel.ml
 * (its externals are entry.tm's and runtime.c's), so nothing checks
 * this file against it. It gives nothing to another file. *)
