(* The Pi4's interrupt controller, ARM's GIC-400 (GICv2) (plan_pi.md,
 * phase G3; several cores, G5): its distributor at 0xff841000 (enables,
 * pendings, priorities, targets, configurations: SGIs 0-15, PPIs
 * 16-31 such as the generic timer's 27 and 30, SPIs 32 and up such as
 * the PL011's 153) and its CPU interface at 0xff842000 (the priority
 * mask, IAR to acknowledge the highest pending interrupt, EOIR to end
 * it), one per core. The private interrupts (0-31: the SGIs and PPIs,
 * such as each core's timers) are banked: each core has its own
 * enables, pendings, priorities, lines; a shared one goes to the
 * cores its target byte names. Which core accesses the registers is
 * [current], set by the board before each core runs.
 *
 * Interrupts are level-sensitive as the devices drive them: a
 * line held high stays pending; an acknowledged one is active until
 * its EOI, and a higher-priority one may preempt it.
 *
 * An interrupt's life, seen from the kernel's handler:
 *
 *     the PL011 raises its line     153: pending
 *     enabled, its priority above
 *     the core's mask               the core's IRQ input goes up
 *     the handler reads IAR         = 153, the most urgent one:
 *                                   pending -> active; IRQ goes down
 *     ... the driver reads the character, the line falls ...
 *     the handler writes 153        active -> inactive: 153 may
 *     to EOIR                       interrupt again
 *
 * Between the two registers a more urgent interrupt may come in,
 * and a less urgent one waits: the nesting a kernel would otherwise
 * do by hand with masks. Intc, the Pi 1's, has only the first two
 * lines of this: its header says what the kernel does instead.
 *
 * terminology:
 * Three kinds of interrupts, by who can receive them. An SPI
 * (shared peripheral interrupt) is a device's, and goes to the
 * cores its target says. A PPI (private peripheral) is a core's
 * own, such as its timer: every core has number 30, each its own.
 * An SGI (software generated) is one core's message to another, how
 * a kernel on several cores asks the others to reschedule or to
 * flush their TLBs.
 *
 * Not modelled: groups and the secure view (all interrupts group 0),
 * the binary point (priorities compared whole), SGIs sent through
 * GICD_SGIR.
 *
 * References: ARM Generic Interrupt Controller Architecture
 * Specification v2 (IHI 0048; from memory); QEMU's hw/intc/arm_gic.c
 * (read 2026-09-25) for the reset values: 192 SPIs on the BCM2711. *)

type t

val create : cores:int -> t

(* a shared device's line, by interrupt ID (32 and up) *)
val set : t -> int -> bool -> unit

(* a core's private line (its timers' PPIs) *)
val set_private : t -> int -> int -> bool -> unit

(* whether a core's IRQ is asserted *)
val irq : t -> int -> bool

(* the core accessing the registers *)
val set_current : t -> int -> unit

val distributor : t -> Memory.device
val cpu_interface : t -> Memory.device
