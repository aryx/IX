(* A tiny machine of our own. It is the CPU of TinyMachineCPU.ml plus
 * what a kernel needs around it, designed the same way the instructions
 * were. TinyCPU.ml runs the CPU the way a user program runs, with the
 * host answering its system calls. Here nothing answers them except a
 * program that the machine itself runs, a kernel, written in the same
 * assembly. The usage and examples are in [help], which is what
 * tiny-machine -h prints.
 *
 * The image is made by tiny-ld: the objects are placed one after the
 * other, and their labels share one namespace, so a kernel's table can
 * name its programs. The kernel comes first, at address 0. An image is
 * simply the first bytes of memory as they are at the start. It has no
 * header, since the machine always starts at 0 in supervisor mode (the
 * Pi's kernel.img, loaded at 0x8000 by its firmware, follows the same
 * idea).
 * The kernel is TinyKernel.ml, and TinyKernel/steps/ holds the two
 * steps that came before it, each with a Makefile that builds and runs
 * it: v0/ is a page of assembly with its programs, and t6/ is a kernel
 * in C whose disk is made by tiny-mkfat. At the top of ix,
 * ./tiny-machine tiny-kernel (or t6, or v0) builds and boots one.
 *
 * Here is what the machine adds to the CPU so that it can run a kernel:
 *
 * - {b Two modes}, supervisor and user, given by a bit of [status]. The
 *   machine starts in supervisor mode at 0.
 * - {b One way in, one way out.} A trap saves the pc in [epc] and the
 *   reason in [cause] (1 for sys, 2 for an illegal word, 3 for a fault,
 *   4 for the timer). It puts the related value in [tval] (the call's
 *   number, the illegal word, or the faulting address), and saves the
 *   mode and the interrupt-enable bit in [status]. It then enters
 *   supervisor mode with interrupts off and jumps to [tvec]. [eret]
 *   undoes this: it restores the mode and the interrupt bit and sets
 *   the pc to [epc]. epc is where execution resumes: after a sys, on the
 *   faulting instruction, or on the instruction that an interrupt
 *   preempted.
 * - {b Control registers}, read by [csrr d, name] and written by
 *   [csrw name, a]: status epc cause tval tvec time timecmp base
 *   bound. time counts executed instructions (so time belongs to the
 *   program alone, and every run is the same). The timer interrupts when
 *   time reaches timecmp and interrupts are on. [wfi] sleeps until an
 *   interrupt comes. It is what an idle kernel loops on, and the host
 *   then does not have to run that loop one jump at a time. csrr,
 *   csrw, eret and wfi are illegal in user mode.
 * - {b Protection by a window.} In user mode every address, including
 *   instruction fetches, must be in [base, bound), otherwise it is a
 *   fault. There is no relocation at run time: a user program is
 *   linked at the address where it runs. What the window gives is that
 *   a program can only harm itself (like RISC-V's PMP or the 360's
 *   storage keys, without pages).
 * - {b Two devices at the top of memory}, reachable from anywhere with
 *   a negative offset from r0. A store to -16(r0) writes a byte to the
 *   console, and a store to -12(r0) halts the machine, with the stored
 *   value as the exit status. They are outside any window a kernel
 *   hands out, so only the kernel can reach them.
 *
 * Then v6 added more (an xv6-like kernel in C; it was removed on
 * 2026-10-13 and is in git's history; no kernel in ix has used pages
 * since). Each addition is kept separate so that v0 still runs as it
 * did (plan_tiny_os.md, phase 2):
 *
 * - {b 256 MB} of memory, with the devices still at the top (-16(r0)
 *   is the console).
 * - {b Pages}, which use Sv32 (RISC-V's 32-bit scheme with two levels;
 *   xv6 on 64 bits uses Sv39, which has three). The top bit of satp
 *   turns paging on and the window off; a page fault puts the address
 *   in tval. With
 *   bit 30 set too (tiny-kernel's pages, plan_tiny_memory.md), only
 *   user mode's addresses are translated, and the kernel's stay
 *   physical (like the PDP-11's two sets of mapping registers, one for
 *   the kernel and one for the user). User mode's translations are kept
 *   in a cache of 64 pages, which is emptied when satp is written; a
 *   kernel writes satp after it changes a process's tables (RISC-V's
 *   sfence.vma).
 * - {b amoswap d, a, (b)} is the atomic swap that spinlocks are built
 *   from, and it can be used in either mode. {b core} holds the core's
 *   number (always 0 without -cores, below). {b scratch} and {b csrrw}
 *   let a kernel free a first register at the start of a trap.
 * - {b Interrupts by source}: ip (pending) and ie (enabled) have one
 *   bit per source. The timer is the first source, enabled at the start
 *   as v0 expects. An interrupt's cause is 4, and tval says which
 *   sources are pending.
 * - {b Console input} is at -8(r0), and it has its own interrupt.
 * - {b A disk} (-d image; a blank 8 MB one is made when there is no
 *   such file) moves 1 KB blocks instantly, and has its own interrupt.
 *   A block is written to the image file as soon as it is written, so
 *   a machine that is killed leaves the disk as a crash would.
 *
 * t6 (a kernel of our own in C, in TinyKernel/steps/t6/) added one
 * more thing: bit 16 of status makes the window relocate (a user
 * address is added to base, and must stay below bound). tiny-kernel's
 * segments (plan_tiny_memory.md) split this window in two when 32 is
 * also set in status:
 * - an address below {b tbound} is in the text; it is added to
 *   {b tbase}, and a store there faults;
 * - an address above it is in the data; tbound is subtracted from it,
 *   then it is added to base and must stay below bound.
 * One copy of a program's text then serves all its runs, as the
 * PDP-11/45's text segment did.
 *
 * For a window system (plan_tiny_windows.md) there are more additions,
 * each behind an option, so that a kernel without one runs as before:
 *
 * - {b A screen} of 1024 by 768 pixels, one byte each, is at 0xf00000. It
 *   is ordinary memory (a kernel draws a pixel with stb), and each byte
 *   is a colour in Plan 9's table of 256. -window shows it in a window
 *   on the host, and -screen f writes it as a PPM file at the halt.
 * - {b A mouse}: the word at -4(r0) has x in its low 12 bits, y in the
 *   next 12, and the buttons above (1 left, 2 middle, 4 right, as in
 *   Plan 9). Its interrupt is the fourth source, raised when the mouse
 *   changes and cleared when the word is read.
 * - {b The keys} arrive as console input, including the window's keys
 *   with -window (the arrows are bytes 128 to 131: up, down, left,
 *   right; a key held down repeats).
 * - {b A fixed speed} is used with -window: 20 million instructions a
 *   second (-rate n changes it), so that a game's time, counted in
 *   instructions, follows the host's clock and not the host's speed.
 * - {b A replayed session} (-events f): mouse and key events are read
 *   from a file, each at its time. Since time is counted in
 *   instructions, the screen at the halt is the same on every run.
 *
 * For a network (plan_tiny_network.md), again behind an option:
 *
 * - {b A wire} is four words at -48(r0), laid out like the disk's (an
 *   address, a length, a command, a status). A command either sends a
 *   packet from memory or takes the packet that is waiting; the
 *   interrupt, the fifth source, is raised while a packet waits. The
 *   other end of the wire is on the host. With -net dir, it is this
 *   program itself, running KNetwork.ml as tiny-kernel does,
 *   at the other address; it answers pings and serves dir's files over
 *   IL (see TinyMachinePeer). -net-trace prints each packet, -net-lose n
 *   drops the n-th one, and -net-pcap f saves them for tcpdump. With
 *   -net-out, the wire leads to other machines: the host opens the
 *   connections the machine asks for to other addresses. With
 *   -net-forward h:m, the host's port h is forwarded to the machine's
 *   port m. Both use tiny-machine-socket, a separate program that has
 *   the host's sockets and runs beside this one, like the window does.
 *   With -net-loop n, the wire loops back: a packet comes back n
 *   instructions later. Packets arrive at times counted in
 *   instructions, so a run is still the same every time.
 *
 * For sound (plan_tiny_audio.md):
 *
 * - {b A speaker} is memory, as the screen is. It is a ring of 8,192
 *   samples (one signed byte each), placed where the kernel says by
 *   writing its address at -52(r0). The speaker plays the ring at 8,000
 *   samples a second of the machine's time, and sets each sample it
 *   played to 0, so a ring nobody writes is silence. Reading the word
 *   gives the number of samples played, which the kernel keeps ahead
 *   of when it writes. The samples due are played only when somebody
 *   looks (the kernel or the host), so the speaker costs no instruction
 *   of its own. -window plays the samples, and -audio f writes them as
 *   a WAV file.
 *
 * For several cores (plan_tiny_multicore.md), behind -cores n:
 *
 * - {b Cores}: n CPUs share the memory, and each has its own registers,
 *   pc and control registers (core holds its number, and cores holds
 *   the count).
 *   All start at 0 in supervisor mode, as RISC-V's cores start at the
 *   reset address; a kernel looks at core to park the others. The
 *   devices are wired to core 0, so another core that reaches one
 *   faults.
 * - {b The interrupt between cores} is the sixth source (32). Any core
 *   can store k at -64(r0) to raise core k's interrupt. A load there
 *   gives the cores that raised this core's interrupt, one bit each,
 *   and clears them. A mailbox in memory plus this interrupt are all
 *   that tiny-kernel's cores need.
 * - {b In turns or at once.} By default the cores take turns in one
 *   thread, each running a slice of up to 1,024 instructions. A run is
 *   then the same every time, and one core behaves exactly as the
 *   single-core machine. With -cores-parallel, where OCaml has domains
 *   (tiny-machine built by OCaml 5), each core is a domain on one of
 *   the host's cores, counting its own time. The memory is shared
 *   without a lock (a race between cores is the program's problem, as
 *   on hardware), and the interrupt goes through an Atomic. amoswap is
 *   then no longer atomic, which tiny-kernel does not need.
 *
 * Here is all of it as a kernel sees it. Memory is 256 MB, with the
 * devices at its top. An address is taken modulo the size, so r0 minus
 * 16 is 0xffffff0: reaching a device costs no register.
 *
 *     0x000000   the image: the kernel's first word, where the machine
 *                starts in supervisor mode; the programs linked after
 *        ...     free memory, which the kernel hands out by a window
 *                (base, bound) or by pages
 *     0xf00000   the screen: 768 rows of 1024 bytes, up to 0xfc0000
 *        ...
 *     0xfffffc0  the interrupt between cores             -64(r0)
 *     0xfffffcc  the speaker: its ring's address, the     -52(r0)
 *                samples played
 *     0xfffffd0  the network: an address, a length,       -48(r0) up
 *                a command, whether there is a wire
 *     0xfffffe0  the disk: a block number, an address,    -32(r0) up
 *                a command, a status (the first read:
 *                the disk's size, in blocks)
 *     0xffffff0  console output                           -16(r0)
 *     0xffffff4  halt                                     -12(r0)
 *     0xffffff8  console input                             -8(r0)
 *     0xffffffc  the mouse                                 -4(r0)
 *
 * And here is the word that holds the mode, with what a trap and eret
 * do to it (see [trap] in TinyMachineDevices, and its [extra] for eret):
 *
 *     status      16 relocate | 8 pie | 4 ps | 2 ie | 1 supervisor
 *
 *     a trap      sets epc, cause, tval; ps and pie save the previous
 *                 mode and ie; then supervisor, ie off, pc = tvec
 *     eret        restores the mode and ie from ps and pie; pc = epc
 *
 * Only one level is saved: a kernel that enables interrupts while it
 * handles a trap must first save epc and status itself, as on RISC-V.
 * Here is the whole path of a system call in v0: a program's sys 1
 * traps; the kernel at tvec saves the program's registers and epc,
 * reads cause (1) and tval (the call's number), performs the call,
 * restores the registers of some process, and eret returns to the
 * word after the sys.
 *
 * The CPU's hooks (the [env] of TinyMachineCPU) carry all of this. The
 * fetch, the load and the store go through the pages or the window and
 * find the devices; sys raises a trap; a word the CPU does not know is
 * decoded here as csrr, csrw, eret or wfi (in supervisor mode), or
 * amoswap, or else it traps. The loop around [step] adds the rest: the
 * time and the interrupts.
 *
 * twin:
 * Its twins are machines that ix did not design: mini-qemu's Board and
 * Pi4. There, the same five ideas (modes, trap registers, a timer,
 * devices at addresses, an image loaded at a fixed place) have ARM's
 * names and ARM's history.
 *
 * Here is the same machine under two sets of names: ours, which we
 * designed, and the Pi 4's, which ARM evolved over time (the first
 * page of a kernel written against the latter is in
 * kernels/lib_machine/pi4/l.s):
 *
 *     here                 the Pi 4 (arm64)
 *     user, supervisor     EL0, EL1 (and EL2, EL3 above)
 *     status's ps, pie     SPSR_EL1
 *     epc                  ELR_EL1
 *     cause, tval          ESR_EL1, FAR_EL1
 *     tvec                 VBAR_EL1, a table of sixteen entries
 *     eret                 eret
 *     wfi                  wfi
 *     sys                  svc
 *     time, timecmp        CNTVCT_EL0, CNTV_TVAL_EL0 and CNTV_CTL_EL0
 *     ip, ie               the GIC, a separate device
 *     -16(r0)              0xfe201000, the UART
 *     csrr, csrw           mrs, msr
 *
 * Here every trap goes to one address and the cause is in a register;
 * on ARM there is a table, with one entry per origin and kind of
 * exception. Here the interrupt controller is just two control
 * registers, which a machine with four devices can afford. On ARM it
 * is a device with its own registers, because how many interrupt lines
 * there are, and which core handles which, is the board's business,
 * not the processor's.
 *
 * dropped:
 * This machine is not a real board, so it lacks what mini-qemu gains by
 * being like one. No kernel written for another machine runs here,
 * whereas mini-qemu boots xv6's Pi ports and principia's 9pi unchanged,
 * and their output is checked against QEMU's (raspberry/tests/xv6.sh,
 * 9pi.py). What a kernel learns here about
 * devices does not carry over to real ones either: there is no SD
 * card's protocol, no DMA controller, no interrupt controller of its
 * own, no USB. Nor is there a monitor or QMP to look into a running
 * machine or drive it from outside.
 *
 * twist:
 * {b The machine is designed with its kernel}, whereas mini-qemu must
 * copy a board as it is. A device is a few words at the top of memory.
 * The disk, for example, is a block number, an address, a command and a
 * status, and its transfer is done at once, whereas the Pi's SD card
 * needs commands to its host controller and control blocks for DMA. The
 * screen is memory at a fixed address, with no mailbox to ask the
 * firmware for it. So a kernel's driver is a few stores, and the
 * machine's side is as short.
 *
 * {b A session can be replayed.} -events gives the keys and the mouse
 * at times counted in instructions, and -screen writes the screen at
 * the halt, so a graphical session is a test whose result is a file,
 * the same on every run. mini-qemu's sessions are driven from outside,
 * through QMP's input-send-event and screendump, by a script that
 * sleeps between them (raspberry/tests/9pi_graphics.py).
 *
 * archi:
 * The machine itself is in TinyMachineDevices.ml (the control
 * registers, the traps, the pages, the state of the devices, and one
 * instruction's worth of time). This file is its terminal front end:
 * the console, the files, the window, and the main loop.
 * TinyMachineWeb.ml is the same front end for a web page.
 *
 * context:
 * Below it is TinyMachineCPU, which runs the instructions. Above it are
 * its kernels: TinyKernel (in ML, compiled by tiny-ml) and the steps before
 * it (v0 in assembly, t6 in C compiled by tiny-cc).
 *
 * exercises:
 * Each one is cheap, because time is counted in instructions
 * and everything else is a hook of the CPU:
 * - the cores take their turns in an order drawn from a seed (-cores
 *   takes them in a fixed one), so a race can be replayed from its
 *   seed, which real hardware never allows;
 * - a slow disk, whose transfer completes N instructions after the
 *   command, so a kernel must sleep while waiting (v6's diskrw becomes
 *   xv6's);
 * - a TLB: the last translations are cached and flushed by a write to
 *   satp, so a kernel that forgets a flush shows its bug, as on real
 *   machines;
 * - the A and D bits of pages, set by loads and stores, so that a
 *   kernel can do clock page replacement.
 *
 * cs-history:
 * Two modes with a trap between them come from the Atlas (Manchester,
 * 1962), and from then on every machine that ran more than one program
 * had them: the IBM 360's supervisor state and its SVC instruction
 * (1964) gave the system call its shape. A base and a bound around a
 * program were the protection on machines before pages (the CDC 6600's
 * reference address and field length, the PDP-10's registers). With
 * relocation, they are a complete memory management scheme: a program
 * can be moved by changing one register. What they cannot do is share
 * part of a program, grow it in the middle, or leave part of it on
 * disk, which is why pages were invented, on the Atlas again.
 *
 * others:
 * Other machines were made to carry a teaching system. Wirth's RISC for
 * Project Oberon (2013 edition) runs on an FPGA and has no modes at
 * all: the language is the protection. There is also MIT's 6.004 Beta,
 * and Nisan and Schocken's Hack, whose keyboard and screen are memory
 * as here and which has no interrupts. xv6 chose a real machine (x86,
 * then RISC-V, under QEMU; the sixth edition of Unix it retells ran on
 * a PDP-11), and v6, while it was here, brought that kind of kernel to
 * our own machine.
 *
 * design:
 * Counting time in instructions is what makes this machine a tool for
 * learning. A run is a function of the image and the input: the same
 * interleaving of processes, the same screen at the halt, the same bug
 * at the same instruction, on any host and under a debugger. On a real
 * board the timer follows a crystal, and an interrupt lands wherever it
 * lands. The cost is that nothing can be learned here about the real
 * timing of devices; mini-qemu also counts instructions and has the
 * same limit.
 *
 * terminology:
 * RISC-V says hart (a hardware thread, whose number is in hartid) where
 * this machine says core. They differ only on a core that runs several
 * threads at once, sharing its units (Intel's Hyper-Threading, SMT),
 * which the kernel then sees as several CPUs: Linux's /proc/cpuinfo
 * counts those. tiny-machine has no such core, so a core is one CPU,
 * and core is the word a reader knows.
 *
 * references:
 *  - the RISC-V privileged specification: the trap registers, their
 *    names, mret
 *  - Wirth and Gutknecht, Project Oberon (1992): a machine and its
 *    system designed together
 *  - Nisan and Schocken, The Elements of Computing Systems (Hack):
 *    devices as memory
 *)

(* what the command line chose (disks, window, files, wire...) *)
type options

(* [run caps options image] runs until the halt; each round gives the
 * host its turn (the console, the window), then runs the machine. *)
val run :
  < Cap.stdin; Cap.stdout; Cap.stderr; Cap.open_in; Cap.open_out; Cap.readdir;
    Cap.forkew; Cap.pipe; Cap.signal; Cap.clock; Cap.exit;
    .. > ->
  options -> string -> int

(* -h prints the usage; it exits with the kernel's halt code *)
val main :
  < Cap.stdin; Cap.stdout; Cap.stderr; Cap.open_in; Cap.open_out; Cap.readdir;
    Cap.forkew; Cap.pipe; Cap.signal; Cap.clock; Cap.exit;
    .. > ->
  string array -> Exit.t
