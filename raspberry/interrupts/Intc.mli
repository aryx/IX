(* This is the BCM2835's interrupt controller (base + 0xB200, which
 * holds the registers from 0x200 on). It has the GPU's 64 interrupt
 * lines, which are level-triggered and are enabled and disabled by
 * bits. The pending registers show the enabled lines that are up (as
 * QEMU's model does). The basic pending register gives a summary, and
 * shows a few lines again (in bits 10-20). The ARM's own interrupts
 * (its timer, the doorbells) are not modelled, because no Pi kernel of
 * the list uses them.
 *
 * The processor has one input for all the devices, IRQ. This is the
 * funnel in front of it. There are 64 wires in, each from a device
 * saying "I need attention". Each wire has a bit that lets it through
 * or not, and IRQ is the OR of what passes:
 *
 *     level   (the devices')   0 0 1 0 ... 1 0     [set]
 *     enable  (the kernel's)   0 0 1 0 ... 0 0     written at 0x210,
 *     ----------------------------------------     cleared at 0x21c
 *     pending = level and enable   0 0 1 0 ... 0 0     read at 0x204
 *     irq = any pending bit                            [irq]
 *
 * (The second half of each, for lines 32-63, is at the next address.)
 * A handler reads pending, picks a bit, and calls that line's driver.
 * Nothing here is cleared by being read. A line is a level, up as
 * long as its device wants, and it is the driver talking to the
 * device (reading the character, acknowledging the timer) that brings
 * it down. If the handler returns with the line still up, the
 * interrupt is taken again at once, which is the classic way for a
 * kernel to hang.
 *
 * others:
 * There are no priorities and no acknowledgment. With several lines
 * pending, the order is the kernel's: the order in which it tests the
 * bits. ARM's own controller, the GIC of the Pi 4 (Gic), does both in
 * hardware. The kernel reads one register to get the most urgent
 * interrupt's number, and writes another when it is done. Intel's
 * 8259, the PC's controller, did as much for 8 lines.
 *
 * Reference: BCM2835 ARM Peripherals (Broadcom, 2012), chapter 7;
 * QEMU's hw/intc/bcm2835_ic.c. *)

type t

val create : unit -> t

(* [set t n up] puts a device's line up or down. For example, 3 is the
 * system timer's compare 3, and 57 is the PL011. *)
val set : t -> int -> bool -> unit

(* the CPU's IRQ input *)
val irq : t -> bool

(* its FIQ input: whether the source that the FIQ control register names
 * is up (0x20C: bit 7 enables it, bits 6-0 give the line) *)
val fiq : t -> bool

(* its registers, from base + 0xB200 *)
val device : t -> Memory.device
