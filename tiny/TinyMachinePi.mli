(* A tiny Raspberry Pi 4, in one file: the smallest machine a kernel
 * can run on, and one a bare-metal program for the real board runs on
 * too. mini-qemu (raspberry/) is QEMU's raspi4b, faithfully: every
 * device xv6 touches, the MMU, four cores, USB, the framebuffer. This
 * is what is left when the kernel is one we write: TinyCPUArm's CPU
 * (TinyLibArm) with what a kernel sees below the system call. Its
 * usage and examples: [help], what tiny-pi -h prints.
 *
 * What a machine adds to a CPU, and nothing else:
 *
 * - {b Exception levels.} EL0 (the programs), EL1 (the kernel), EL2
 *   (where the firmware leaves the kernel's image: it goes down to EL1
 *   itself). Each has its own stack pointer, swapped in when the level
 *   is entered. The state beside the registers: the flags (the CPU's),
 *   the four masks (DAIF; I is the interrupts'), the level.
 * - {b Exceptions.} An svc, an undefined word, an interrupt, all taken
 *   to EL1: the state saved in SPSR_EL1, the return address in ELR_EL1,
 *   the cause in ESR_EL1 (its top six bits: 0x15 an svc, 0 an unknown
 *   word), the masks set, the pc at a vector, VBAR_EL1 plus 0x400
 *   (from EL0) or 0x200 (from EL1), plus 0x80 for an interrupt. Back
 *   with eret: the state from SPSR, the pc from ELR, at once.
 * - {b The system instructions}, which the CPU's subset leaves out:
 *   mrs and msr (a system register read or written), eret, wfi (wait
 *   for an interrupt). The CPU hands TinyMachinePi the words it does not
 *   know; from EL0 they are undefined.
 * - {b An interrupt between two instructions}: when a device's line is
 *   up, the controller lets it through, and I is clear.
 * - {b Three devices at the Pi 4's addresses}, each a few registers,
 *   behind the CPU's load and store, or behind mrs and msr: the PL011
 *   UART (0xfe201000: DR written, a character out, read, a character
 *   in; FR, never full, empty when nothing came; IMSC, the receive
 *   interrupt); the CPU's own virtual timer (the system registers
 *   CNTFRQ_EL0, the counter's frequency, CNTVCT_EL0, the counter,
 *   CNTV_TVAL_EL0, the ticks to the next interrupt, CNTV_CTL_EL0, its
 *   enable and mask); the interrupt controller, a GIC-400 (its
 *   distributor at 0xff841000: on, and each line's enable; this CPU's
 *   interface at 0xff842000: on, the priority mask, IAR which
 *   acknowledges the line that interrupts, EOIR which ends it). The
 *   timer's line is 27, the UART's 153.
 * - {b Time from instructions}: [ips] instructions a simulated
 *   microsecond (default 30, mini-qemu's), the counter at QEMU's 62.5
 *   MHz; a WFI with nothing pending jumps to the timer's next
 *   interrupt (and waits for a terminal's key, up to 10ms of the
 *   host's). With interrupts masked and none pending, a WFI never
 *   wakes: the machine has halted, and tiny-pi exits.
 *
 * The program is a raw image (TinyAssembler's -raw 0x80000), loaded at
 * 0x80000 and entered there at EL2 with the four masks set, as the Pi
 * 4's firmware starts kernel8.img and QEMU a raw -kernel; its vectors
 * are its own to write. The memory is 16MB from 0.
 *
 * The addresses a kernel's first page is written against:
 *
 *     0x00000000   memory, to 0x01000000
 *     0x00080000   the image; its first word is the first run, at EL2
 *     0xfe201000   the UART:  +0 DR, +0x18 FR, +0x38 IMSC, +0x3c RIS,
 *                  +0x40 MIS
 *     0xff841000   the GIC's distributor:  +0 on, +0x100 a line's
 *                  enable set, +0x180 cleared (a bit a line, 32 a word)
 *     0xff842000   the GIC's interface to this CPU:  +0 on, +4 the
 *                  priority mask, +0xc IAR, +0x10 EOIR
 *
 * and where an exception lands, by where it came from and what it is
 * (ARM's table has sixteen entries of 0x80 bytes, 32 instructions
 * each; these four are the ones taken here):
 *
 *     VBAR_EL1 + 0x200   from EL1, synchronous: an svc, an unknown word
 *              + 0x280   from EL1, an interrupt
 *              + 0x400   from EL0, synchronous
 *              + 0x480   from EL0, an interrupt
 *
 * A timer's tick, whole: the counter passes the value compared, line
 * 27 goes up; the distributor and the interface are on, the line
 * enabled, I clear: before the next instruction the state goes to
 * SPSR_EL1, the pc to ELR_EL1, the masks are set, the level is 1 on
 * its own stack, the pc at one of the two interrupt entries. The
 * handler reads IAR (27: the line is now taken), sets CNTV_TVAL for
 * the next tick (the line goes down), writes 27 to EOIR, and erets.
 * tick.s, among the tests, is that page.
 *
 * The same machine under two sets of names, TinyMachine's being the
 * one we drew and this one the one ARM grew:
 *
 *     TinyMachine          here
 *     user, supervisor     EL0, EL1 (and EL2, EL3 above)
 *     status's ps, pie     SPSR_EL1
 *     epc                  ELR_EL1
 *     cause, tval          ESR_EL1 (and FAR_EL1, an address: not here)
 *     tvec                 VBAR_EL1, a table
 *     eret                 eret
 *     time, timecmp        CNTVCT_EL0, CNTV_TVAL_EL0 and CNTV_CTL_EL0
 *     ip, ie               the GIC, a device apart
 *     -16(r0)              0xfe201000
 *     csrr, csrw           mrs, msr
 *
 * Left out, against mini-qemu's Pi 4: the MMU (the CPU fetches from
 * physical memory), EL3, the other three cores, the stack pointer
 * SP_EL0 used above EL0, FIQ and the aborts (a bad address stops
 * tiny-pi), the physical timer, the controller's priorities, groups
 * and targets (one priority: an interrupt is not interrupted), the
 * UART's transmit interrupt and its FIFOs' levels, the mailbox, the
 * framebuffer, USB, the SD card. Exercises: a shell on the UART
 * (echo.s's interrupt, a line kept until Enter); the physical timer
 * (CNTP, line 30); a second core, parked until the kernel writes its
 * entry at 0xe0; an MMU (a fetch hook in TinyLibArm first).
 *
 * The tests: TinyMachinePi_test.sh assembles TinyMachinePi_tests/*.s
 * with TinyAssembler; runs each here, under mini-qemu and under QEMU
 * (raspi4b), the console the same; and checks its laws: the interrupts
 * counted, the simulated time when it halts.
 *
 * Where it stands: the CPU is TinyLibArm, the image TinyAssembler's
 * (-raw). mini-qemu is the whole board (its Pi4, Gic, Pl011 are these
 * three devices in full, and Board the loop), which mini-9pi and
 * mini-xv6 boot on; TinyKernel does not run here but on TinyMachine,
 * the machine made for it. So this file is the bridge: the smallest
 * thing on which a page written for a real Pi 4 does what it does on
 * the board.
 *
 * cs-history:
 * The Raspberry Pi (2012; Eben Upton and others, Cambridge) was made
 * so that children would again have a computer to program, as the
 * BBC Micro had been thirty years before, and it is built around a
 * chip made for set-top boxes and telephones, in which the graphics
 * processor is the master: it starts first, reads the SD card, loads
 * the kernel's image into the ARM's memory and only then lets the
 * ARM run. That is why a kernel here starts at a fixed address with
 * nothing set up and no boot loader of its own to write. The Pi 4
 * (2019, a BCM2711 with four Cortex-A72) is the first with ARM's
 * standard interrupt controller, the GIC-400; the earlier ones have
 * Broadcom's (mini-qemu's Intc).
 *
 * terminology:
 * ARM calls everything that enters the kernel an exception:
 * synchronous when an instruction causes it (an svc, an undefined
 * word, a bad address, called an abort), asynchronous when a device
 * does (IRQ, and FIQ, a second line with priority). RISC-V and
 * TinyMachine say trap for the event, with exceptions and interrupts
 * its two kinds. On x86 a trap is an exception that returns after the
 * instruction and a fault one that returns to it. A system call is
 * each one's deliberate exception: svc here, ecall on RISC-V, sys on
 * TinyMachine.
 *
 * design:
 * The interrupt controller is not in the processor's architecture
 * but beside it, a device with registers, because how many lines
 * there are and which core takes which is the board's business. The
 * CPU has one input and one mask bit (I); everything else, the
 * enables, the priorities, the acknowledging and the end, is the
 * GIC's. TinyMachine folds the same job into two registers of
 * control (ip, ie), which is what a machine with four devices can
 * afford and a family of boards cannot.
 *
 * References: Arm Architecture Reference Manual for A-profile (ARM DDI
 * 0487): the levels, the exceptions' entry and return,
 * the system registers, the generic timer; ARM Generic Interrupt
 * Controller Architecture Specification v2 (IHI 0048);
 * mini-qemu's raspberry/ (Pi4, Gic, Pl011), itself checked against
 * QEMU and xv6, and QEMU's raspi4b, run on the three test programs:
 * the behavior; mini-qemu's Main for a terminal as a serial line. *)

(* the board: the CPU, its system registers, the timer, the UART, the
 * interrupt controller *)
type t

(* one instruction, or an interrupt taken, or the time to the next
 * event when waiting *)
val step : t -> unit

(* the program: its arguments (-h: how) to its exit status *)
val main : < Cap.argv; Cap.open_in; Cap.stdin; Cap.stdout; Cap.stderr; .. > -> int
