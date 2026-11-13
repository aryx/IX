(* This is the Pi4's interrupt controller, ARM's GIC-400 (GICv2)
 * (plan_pi.md, phase G3; for several cores, G5). It has two parts:
 * - its distributor, at 0xff841000, holds the enables, pendings,
 *   priorities, targets and configurations. The interrupts are SGIs
 *   0-15; PPIs 16-31, such as the generic timer's 27 and 30; and SPIs
 *   32 and up, such as the PL011's 153.
 * - its CPU interface, at 0xff842000, one per core, holds the priority
 *   mask, IAR to acknowledge the highest pending interrupt, and EOIR
 *   to end it.
 * The private interrupts (0-31, the SGIs and PPIs, such as each core's
 * timers) are banked: each core has its own enables, pendings,
 * priorities and lines. A shared interrupt goes to the cores that its
 * target byte names. The core that accesses the registers is
 * [current], which the board sets before each core runs.
 *
 * Interrupts are level-sensitive, as the devices drive them. A line
 * held high stays pending. An acknowledged interrupt is active until
 * its EOI, and one of a higher priority may preempt it.
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
 * Between the two registers a more urgent interrupt may come in, and a
 * less urgent one waits. That is the nesting a kernel would otherwise
 * do by hand with masks. Intc, the Pi 1's controller, has only the
 * first two lines of this, and its header says what the kernel does
 * instead.
 *
 * terminology:
 * There are three kinds of interrupts, by who can receive them. An
 * SPI (shared peripheral interrupt) comes from a device, and goes to
 * the cores that its target says. A PPI (private peripheral
 * interrupt) is a core's own, such as its timer: every core has a
 * number 30, and each has its own. An SGI (software generated
 * interrupt) is a message from one core to another. It is how a
 * kernel on several cores asks the others to reschedule or to flush
 * their TLBs.
 *
 * Some things are not modelled: the groups and the secure view (all
 * interrupts are in group 0), the binary point (priorities are
 * compared whole), and SGIs sent through GICD_SGIR.
 *
 * References: ARM Generic Interrupt Controller Architecture
 * Specification v2 (IHI 0048); QEMU's hw/intc/arm_gic.c
 * (read 2026-09-25) for the reset values: 192 SPIs on the BCM2711. *)

type t

val create : cores:int -> t

(* [set] puts a shared device's line up or down, by interrupt ID (32
 * and up) *)
val set : t -> int -> bool -> unit

(* [set_private] puts a core's private line up or down (its timers'
 * PPIs) *)
val set_private : t -> int -> int -> bool -> unit

(* whether a core's IRQ is asserted *)
val irq : t -> int -> bool

(* the core accessing the registers *)
val set_current : t -> int -> unit

val distributor : t -> Memory.device
val cpu_interface : t -> Memory.device
