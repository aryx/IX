(* mini-9pi: a Plan 9 kernel for the Raspberry Pi, in OCaml. It runs
 * processes, each with a name space of its own, and in a name space
 * everything is a file: the console, the processes, the screen, the
 * network. A file is a device's, in the kernel, or a server's, a
 * program the kernel speaks 9P to. This module is the kernel's main
 * one: mini-9pi's boot, its traps and interrupts (principia's main.c,
 * trap.c). The first process does initcode's work in the kernel (as
 * mini-xv6's init does xv6's initcode): #c/cons opened as 0, 1, 2, then
 * the boot program exec'd (/boot/boot, an rc script, boot.rc; stage
 * A's was /boot/echo: plan_9pi.md).
 *
 * A system call's way, from the program to a device and back:
 *
 *     a program             n = read(fd, buf, 100)        user mode
 *     ====================== SWI 0 =========================== kernel
 *     Main.trap             lib_machine's assembly has saved the
 *        |                  registers (the trap frame) and called here
 *     Syscall               R0 is 10; five words read on the user's
 *        |                  stack; back: R0 the result, or -1 (errstr)
 *     Systab                10 is Pread: Sysfile.syspread
 *        |
 *     Sysfile               fd to the process's channel (Kchan), the
 *        |                  bytes written in buf (Usermem, Fault)
 *     Dev.find c.dev        the channel's device, a record of functions
 *        |
 *        |-- Devcons   #c   a line typed (Proc.sleep until there is one)
 *        |-- Devpipe   #|   what the other end wrote
 *        |-- Devproc   #p   a process's state, as text
 *        |-- Kfs       #x   a file of the SD card (Devsd, Emmc under it)
 *        |-- Devip     #I   a connection's bytes (Tcp, Ip, Devether)
 *        '-- Devmnt    #M   a file of a server's: a 9P message written
 *                           to the server, its reply read (P9, P9_wire)
 *
 * The modules, by directory, and under them what is not this
 * directory's (lib_machine: the C and assembly of the board, shared
 * with mini-xv6):
 *
 *     init         Main: the boot, the traps, the clock's tick
 *     syscalls     Syscall, Systab, Usermem, Ureg: a call taken in
 *     processes    Proc (the table, the scheduler, sleep and wakeup,
 *                  notes), Sysproc (rfork, exits, await...), Exec,
 *                  Syssema, Kproc
 *     memory       Fault: segments, a page given at its first touch
 *     files        Kchan (names, the name space, descriptors), Dev (the
 *                  devices' table), Sysfile (open, pread, bind,
 *                  mount...), P9 and P9_wire (the messages)
 *     devices      sys: Devroot, Devenv, Devproc, Devpipe, Devsrv,
 *                  Devdup, Devmnt, Devsys, Devarch; keyboard, mouse,
 *                  screen (Devdraw), storage (Devsd, Emmc)
 *     console      Devcons
 *     buses        Devusb, Usbdwc, Kusb, lib_usb; usbd, a program
 *     network      Devether, Etherusb, ip: Devip, Ip, Icmp, Tcp
 *     filesystems  Kdos (lib_fat), Kfs (lib_xv6fs); dossrv, a program
 *     lib_graphics Kdraw over lib_memdraw and lib_memlayer
 *     security     Auth
 *     core         Types (every record: read it first), Errors
 *     ----------------------------------------------------------------
 *     lib_machine  Machine (trap frame, context switch, timer, UART),
 *                  Mmu and Page (the page tables), Arch (Pi1 or Pi4)
 *
 * The boot (Main.ml's last lines, top to bottom): the caches; the
 * four entries the assembly calls back (trap: a system call; irq: an
 * interrupt; fault: a page fault or an error of the program;
 * process_start: a new process's first run); the screen and the
 * console on it; the banner; each device reset, in devtab's order; the
 * memory's line; the timer armed for a first tick, the UART's input
 * on; the first process made by hand in slot 0, pid 1, its root '#/';
 * then Proc.scheduler, which never returns. Process 1's first run is
 * process_start: the three descriptors, four binds (#c on /dev, #ec
 * and #e on /env, #s on /srv), and Exec.exec of /boot/boot. From there
 * on the kernel only answers: a trap, an interrupt.
 *
 * An interrupt is the clock's or the UART's ([devices], called from
 * irq and from the idle loop). The clock ticks 100 times a second, and
 * a tick is where everything that is not a process's own gets done:
 * the sleepers on the clock woken, the cursor redrawn, the network's
 * frames taken in, the USB keyboard and mouse asked, TCP's timers, the
 * alarms. Then, if the running process has had its 100 ms and another
 * is ready, it is preempted (Proc.preempt): only here, on the way back
 * to user mode, never inside the kernel.
 *
 * What is ours. The twin of principia's 9pi: the same 40 system calls
 * with the same numbers, the same devices in the same order, so that
 * principia's programs run on it from principia's SD card, and its
 * console is compared with the C kernel's, byte for byte (the banner
 * above is 9pi's words). Inside it is OCaml: Plan 9's structures are
 * records and variants (Types), error() is an exception (Errors), a
 * device is a record of closures (Dev), and there is one processor and
 * no lock. Not here: swapping, the shared segments' calls, UDP and
 * IPv6, a text segment that is read-only (plan_9pi.md's Status).
 *
 * cs-history:
 * Plan 9 from Bell Labs was begun in the middle of the 1980s by the
 * group that had made Unix (Rob Pike, Ken Thompson, Dave Presotto,
 * Phil Winterbottom, with Dennis Ritchie's department around them),
 * to do Unix again for a world of networked machines with bitmap
 * screens, which Unix had met one feature at a time: sockets, ioctl,
 * X11, NFS, each with its own names and calls. Their answer was three
 * ideas held to everywhere: resources are files; one protocol, 9P,
 * reaches them, local or remote; and each process assembles its own
 * name space out of them. Four editions: 1992 (to universities), 1995,
 * 2000 (the sources open), 2002 (9P2000). The name is the film's, Ed
 * Wood's Plan 9 from Outer Space.
 *
 * evolution:
 * After Bell Labs. Inferno (1996) took the ideas to a virtual machine,
 * and its Styx is close to what 9P2000 became. The fourth edition went on
 * outside the Labs: 9front (a fork, since 2011) is the one most used
 * today, and since 2021 the Plan 9 Foundation holds the code, under
 * the MIT license. 9pi, the Raspberry Pi's kernel that principia
 * explains and this one follows, is Richard Miller's port of 2012
 * (from memory). What went into other systems is larger than what
 * stayed: UTF-8 (Latin1), /proc as text (Devproc), per-process name
 * spaces (Kchan: Linux's containers), rfork (Sysproc: Linux's clone),
 * 9P itself (P9).
 *
 * others:
 * xv6 (MIT, 2006) is the kernel a first course reads: Unix's sixth
 * edition again, in under 10,000 lines of C; ix has it as mini-xv6,
 * on the same lib_machine, and reading both shows what a choice costs.
 * xv6 has a file system in the kernel, 21 system calls, a device as a
 * pair of functions; mini-9pi has no file system of its own to boot
 * (its root is a device's few directories, the rest is bound or
 * mounted), twice the calls, and behind them the screen, the network
 * and USB, which xv6 does not reach.
 *
 * others:
 * A kernel in a language with a garbage collector has been tried
 * since SPIN (Modula-3, 1995): House (Haskell, 2005), Singularity
 * (Microsoft's, in a C# dialect: ix's kernels/singularity is after
 * it), MirageOS (OCaml, 2013: a library the application links, not a
 * system of processes), Biscuit (Go, 2018), whose paper measures the
 * price against C. Here the price is taken for another gain: a kernel
 * short enough to read, with no pointer to get wrong. What the
 * language cannot say (a register, a page of another's memory, a
 * change of stack) is lib_machine's C and assembly.
 *
 * why-study:
 * Plan 9 never replaced Unix, and is the better kernel to read for
 * it: there is one way to do each thing. The 2,200 lines of init,
 * processes, files, memory, syscalls and core here are a whole
 * kernel; every device after them is the same record filled in again.
 *
 * References: Rob Pike, Dave Presotto, Sean Dorward, Bob Flandrena,
 * Ken Thompson, Howard Trickey and Phil Winterbottom, "Plan 9 from
 * Bell Labs" (Computing Systems, 1995): the paper to read first.
 * principia's Kernel.nw: the C kernel this one follows, explained
 * line by line. Russ Cox, Frans Kaashoek and Robert Morris, "xv6: a
 * simple, Unix-like teaching operating system" (MIT, since 2006), and
 * John Lions, "A Commentary on the Sixth Edition UNIX Operating
 * System" (1977), which it descends from. Brian Bershad and others,
 * "Extensibility, Safety and Performance in the SPIN Operating
 * System" (SOSP 1995). Cody Cutler, Frans Kaashoek and Robert Morris,
 * "The benefits and costs of writing a POSIX kernel in a high-level
 * language" (OSDI 2018): Biscuit. plan_9pi.md (docs/plans/done): the
 * stages this kernel was written by, and what each found. *)
