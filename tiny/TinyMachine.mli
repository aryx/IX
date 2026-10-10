(* A tiny machine of our own: TinyLibCPU.ml's CPU with what a kernel
 * needs around it, designed as its instructions were. TinyCPU.ml runs
 * the CPU as a user program runs, its system calls answered by the
 * host; here nothing answers them but a program the machine runs, a
 * kernel, in the same assembly; its usage and examples: [help], what
 * tiny-machine -h prints.
 *
 * The link is TinyLibCPU's: the files one after the other, their
 * labels one namespace, so a kernel's table names its programs; the
 * kernel first, at 0. An image is the memory's first bytes, as they are
 * at the start: no header, since the machine always starts at 0 in
 * supervisor mode (the Pi's kernel.img, loaded at 0x8000 by its
 * firmware, is the same idea). Files named .tm are assembly, another
 * an image. tiny-os/ is an OS for it, by versions, each with a Makefile
 * that builds and runs it: v0/ a page of assembly and its programs, v6/
 * xv6's kind of kernel in C, its disk made by tiny-mkfs; ./tiny-machine
 * v0 or v6, at the top of ix, builds and boots one.
 *
 * The machine, what the CPU lacked to run a kernel:
 *
 * - {b Two modes}, supervisor and user, a bit of [status]. The machine
 *   starts in supervisor mode at 0.
 * - {b One way in, one way out.} A trap saves the pc in [epc], the
 *   reason in [cause] (1 sys, 2 an illegal word, 3 a fault, 4 the
 *   timer), what goes with it in [tval] (the call's number, the word,
 *   the address), the mode and the interrupts' bit in [status]; it
 *   enters supervisor mode with interrupts off and jumps to [tvec].
 *   [eret] undoes it: the mode and the interrupts' bit back, the pc at
 *   [epc]. epc is where to resume: past a sys, on a faulting
 *   instruction, on the instruction an interrupt came before.
 * - {b Registers of control}, read by [csrr d, name] and written by
 *   [csrw name, a]: status epc cause tval tvec time timecmp base
 *   bound. time counts the instructions (the time is the program's
 *   alone, so every run is the same); the timer interrupts when time
 *   reaches timecmp and interrupts are on. csrr, csrw and eret are
 *   illegal in user mode.
 * - {b Protection by a window.} In user mode an address must be in
 *   [base, bound), the fetch's too, or it is a fault. No relocation:
 *   a user program is assembled where it runs; what a window buys is
 *   that a program can harm only itself (RISC-V's PMP, the 360's
 *   storage keys, without pages).
 * - {b Two devices at the top of memory}, reached from anywhere by a
 *   negative offset from r0: a store to -16(r0) writes a byte to the
 *   console, a store to -12(r0) halts the machine, the value its exit
 *   status. They are outside any window a kernel gives, so only it
 *   reaches them.
 *
 * What tiny-os v6 (xv6's kind of kernel) adds, each kept apart so that
 * v0 runs as it did (plan_tiny_os.md, phase 2):
 *
 * - {b 16 MB}, the devices still at the top (-16(r0) the console).
 * - {b Pages}, Sv32 (RISC-V's 32-bit scheme, xv6's): satp's top bit
 *   turns them on, the window off; a fault's address in tval.
 * - {b amoswap d, a, (b)}, the atomic swap a spinlock is made of, in
 *   either mode; {b hartid}, the core's number (0: one core, for now);
 *   {b scratch} and {b csrrw}, for a trap's first register.
 * - {b Interrupts by source}: ip (pending) and ie (enabled), a bit
 *   each; the timer's is the first, enabled at the start as v0 wants;
 *   an interrupt's cause is 4, its sources in tval.
 * - {b The console's input} at -8(r0), and its interrupt; {b a disk}
 *   (-d image), 1 KB blocks moved at once, and its interrupt.
 *
 * And t6 (tiny-os's free kernel) one more: status's bit 16, the window
 * relocating (a user address plus base, below bound).
 *
 * And for a window system (plan_tiny_windows.md), each an option, so
 * that a kernel without one runs as it did:
 *
 * - {b A screen}: 640 by 480 pixels, a byte each, at 0xf00000, memory
 *   like any other (a kernel stores a pixel by stb); a byte is a
 *   colour in Plan 9's table of 256. -window shows it in a window of
 *   the host's, -screen f writes it at the halt, a PPM.
 * - {b A mouse}: the word at -4(r0), its x in the low 12 bits, its y
 *   in the next 12, its buttons above (1 left, 2 middle, 4 right, as
 *   Plan 9's); its interrupt, the fourth source, from a change until
 *   the word is read.
 * - {b The keys} are the console's input, the window's too with
 *   -window (the arrows the bytes 128 to 131: up, down, left, right;
 *   a key held is typed again and again).
 * - {b A speed}, with -window: 8 million instructions a second, so
 *   that a program's time, which is the machine's instructions, is the
 *   same on every host.
 * - {b A session replayed} (-events f): the mouse and the keys from a
 *   file, each at its time; the time being the instructions counted,
 *   the screen at the halt is the same on every run.
 *
 * All of it, as a kernel sees it. The memory, 16 MB, with what is not
 * memory at its top (an address is taken modulo the size, so r0 minus
 * 16 is 0xfffff0: a device costs no register to reach):
 *
 *     0x000000   the image: the kernel's first word, where the machine
 *                starts, in supervisor mode; the programs linked after
 *        ...     memory: the kernel's to give out, by a window (base,
 *                bound) or by pages
 *     0xf00000   the screen: 480 rows of 640 bytes, to 0xf4b000
 *        ...
 *     0xffffe0   the disk: a block's number, an address,  -32(r0) up
 *                a command, its status
 *     0xfffff0   the console's output                     -16(r0)
 *     0xfffff4   the halt                                 -12(r0)
 *     0xfffff8   the console's input                       -8(r0)
 *     0xfffffc   the mouse                                 -4(r0)
 *
 * and the one word that says which mode, with what a trap and eret do
 * to it (TinyLibMachine's [trap], and its [extra] for eret):
 *
 *     status      16 relocate | 8 pie | 4 ps | 2 ie | 1 supervisor
 *
 *     a trap      epc, cause, tval set; ps and pie take the mode and
 *                 ie as they were; supervisor, ie off; the pc at tvec
 *     eret        the mode and ie back from ps and pie; the pc at epc
 *
 * One level only is kept: a kernel that lets interrupts in while it
 * handles a trap must save epc and status itself first, as on RISC-V.
 * A system call's whole way, in v0: a program's sys 1 traps; the
 * kernel at tvec saves the program's registers and epc, reads cause
 * (1) and tval (the call's number), does it, restores a process's
 * registers, and eret is the return, to the word after the sys.
 *
 * The CPU's hooks carry all of it (TinyLibCPU's [env]): the fetch, the
 * load and the store go through the pages or the window and find the
 * devices; sys raises a trap; a word the CPU does not know is csrr,
 * csrw or eret, in supervisor mode, or amoswap, or a trap. The loop
 * around [step] adds the rest: the time, the interrupts.
 *
 * The tests: TinyMachine_test.sh runs tiny-os/v0/kernel.tm, a page of
 * kernel, with its four user programs (two printing, one executing
 * csrw, one storing into the kernel), on a long and a short timer
 * period: every letter printed, the two faults caught, the printing
 * interleaved by the short period and not by the long one; and the
 * programs of TinyMachine_tests/ (amoswap and csrrw, the pages, the
 * console's input, the disk, the relocating window) against their
 * .expected. tiny-os's v6 and t6 run on it too (their make check).
 *
 * Exercises, each cheap because the time is the instructions counted
 * and everything else is a hook of the CPU:
 * - several cores (plan_tiny_os.md, phase 5): N CPUs sharing the
 *   memory, stepped in an order a seed draws; a race then comes back
 *   from its seed, which real hardware never gives;
 * - wfi: a core waiting for an interrupt, the time jumping to timecmp,
 *   so an idle kernel costs nothing;
 * - a slow disk: the transfer done N instructions after the command,
 *   so a kernel must sleep for it (v6's diskrw becomes xv6's);
 * - a TLB: the last translations kept, flushed by a write of satp; a
 *   kernel that forgets a flush then shows its bug, as on real machines;
 * - pages' A and D bits, set by the load and the store, for a clock
 *   page replacement in a kernel.
 *
 * The machine itself is TinyLibMachine.ml (the registers of control,
 * the traps, the pages, the devices' state, one instruction of its
 * time); here its terminal: the console, the files, the window, the
 * loop. TinyMachineWeb.ml is the same for a web page.
 *
 * Where it stands: below it TinyLibCPU, the instructions; above it
 * its kernels, tiny-os's three (assembly, then C by tiny-c -tm) and
 * TinyKernel (ML by tiny-ml -tm). Its twins are the machines ix did
 * not design: mini-qemu's Board and Pi4, and TinyMachinePi, a Pi 4's
 * part, where the same five ideas (modes, a trap's registers, a
 * timer, devices at addresses, an image loaded at a fixed place) have
 * ARM's names and ARM's history: compare SPSR and ELR there with
 * status and epc here.
 *
 * cs-history:
 * Two modes and a trap between them are the Atlas's (Manchester,
 * 1962) and then every machine's that ran more than one program:
 * the IBM 360's supervisor state and its SVC instruction (1964) gave
 * the system call its shape. A base and a bound around a program
 * were the protection of the machines before pages (the CDC 6600's
 * reference address and field length, the PDP-10's registers), and
 * with relocation they are a whole memory management: a program
 * moved by changing one register. What they cannot do is share a
 * part, grow in the middle, or leave a part on the disk, which is
 * why pages came, on the Atlas again (the machines from memory).
 *
 * design:
 * Time counted in instructions is what makes this machine a tool for
 * learning. A run is a function of the image and the input: the same
 * interleaving of processes, the same screen at the halt, the same
 * bug at the same instruction, on any host and under a debugger. A
 * real board's timer follows a crystal, and an interrupt lands where
 * it lands. The cost is that nothing can be learned here about a
 * device's real timing; mini-qemu counts instructions too and has
 * the same limit.
 *
 * others:
 * The machines made to carry a teaching system: Wirth's RISC for
 * Project Oberon (2013 edition), on an FPGA, no modes at all, the
 * language being the protection; MIT's 6.004 Beta; Nisan and
 * Schocken's Hack, whose keyboard and screen are memory as here and
 * which has no interrupt; xv6's choice was a real machine (x86, then
 * RISC-V, under QEMU; the sixth edition it retells ran on a PDP-11),
 * and tiny-os v6 brings its kind of kernel to our own.
 *
 * References: the RISC-V privileged specification (from memory): the
 * trap registers, their names, mret; Wirth and Gutknecht, Project
 * Oberon (from memory): a machine and its system designed together;
 * Nisan and Schocken, The Elements of Computing Systems (Hack):
 * devices as memory. *)

(* the command line's: a disk's file, a window, a screen's file, events *)
type options

(* an image, run to the machine's halt: the hosts' turns (the console,
 * the window), then the machine's instruction; to the exit status *)
val run :
  < Cap.stdin; Cap.stdout; Cap.open_in; Cap.open_out; Cap.fork; Cap.exec; .. > -> options -> string -> int

(* the program: its arguments (-h: how) to its exit status *)
val main :
  < Cap.stdin; Cap.stdout; Cap.stderr; Cap.argv; Cap.open_in; Cap.open_out; Cap.fork; Cap.exec; .. > -> int
