(* The BCM2835's interrupt controller (base + 0xB200, the registers from
 * 0x200 on): the GPU's 64 interrupt lines, level-triggered, enabled
 * and disabled by bits; the pending registers show the enabled lines
 * that are up (as QEMU's model does), the basic one a summary and a
 * few lines again (bits 10-20). The ARM's own interrupts (its timer,
 * doorbells) are not modelled: no Pi kernel of the list uses them.
 *
 * The processor has one input for all the devices, IRQ. This is the
 * funnel in front of it: 64 wires in, each a device saying "I need
 * attention", a bit a wire to let it through or not, and the OR of
 * what passes:
 *
 *     level   (the devices')   0 0 1 0 ... 1 0     [set]
 *     enable  (the kernel's)   0 0 1 0 ... 0 0     written at 0x210,
 *     ----------------------------------------     cleared at 0x21c
 *     pending = level and enable   0 0 1 0 ... 0 0     read at 0x204
 *     irq = any pending bit                            [irq]
 *
 * (And the second half of each at the next address, lines 32-63.)
 * A handler reads pending, picks a bit, and calls that line's
 * driver. Nothing here is cleared by being read: a line is a level,
 * up as long as its device wants, and it is the driver's talking to
 * the device (reading the character, acknowledging the timer) that
 * brings it down. Return from the handler with the line still up
 * and the interrupt is taken again at once, the classic way for a
 * kernel to hang.
 *
 * others:
 * No priorities and no acknowledgment: with several lines pending
 * the order is the kernel's, the order in which it tests the bits.
 * ARM's own controller, the GIC of the Pi 4 (Gic), does both in
 * hardware: the kernel reads one register to get the most urgent
 * interrupt's number and writes another when it is done. Intel's
 * 8259, the PC's, did as much for 8 lines.
 *
 * Reference: BCM2835 ARM Peripherals (Broadcom, 2012; from memory),
 * chapter 7; QEMU's hw/intc/bcm2835_ic.c (from memory). *)

type t

val create : unit -> t

(* a device's line, up or down: 3 the system timer's compare 3, 57 the
 * PL011 *)
val set : t -> int -> bool -> unit

(* the CPU's IRQ input *)
val irq : t -> bool

(* its FIQ input: the source the FIQ control register names (0x20C: bit
 * 7 enable, bits 6-0 the line), up *)
val fiq : t -> bool

(* its registers, from base + 0xB200 *)
val device : t -> Memory.device
