(* The BCM2835's smaller devices, each a Memory.device (offsets from its
 * base): what the Pi kernels touch, as QEMU's raspi1ap models it
 * (plan_pi.md, decision 4).
 *
 * The one with an idea is the mailbox. On a Pi the ARM is not the
 * master of the board: the VideoCore, the graphics processor, booted
 * it, owns the top of the memory and the screen, and knows what the
 * ARM must ask: how much memory is mine, what board is this, give me
 * a framebuffer. The asking is by a letter. The kernel fills a
 * buffer in its own memory, writes the buffer's address (with the
 * channel, 8, in the four low bits) to one register, and reads it
 * back from another when the answer is in the buffer. "How much
 * memory has the ARM?", words of 32 bits:
 *
 *     the kernel writes         the firmware answers (here: at once)
 *     32           the buffer's size, in bytes
 *     0            a request    0x80000000   done
 *     0x00010005   the tag: the ARM's memory
 *     8            room for the answer, in bytes
 *     0                         0x80000008   8 bytes of answer
 *     0                         0            from address 0
 *     0                         0x1c000000   448 MB (512, less the
 *     0            no more tags              VideoCore's 64)
 *
 * Several tags may go in one letter. The framebuffer is asked the
 * same way (0x00048003 a size wanted, 0x00048005 a depth,
 * 0x00040001 allocate: an address and a length come back), and from
 * then on the screen is memory the kernel writes pixels to
 * (Framebuffer).
 *
 * design:
 * A protocol of tagged values, each with its length, where a
 * register for each question would have done: a kernel skips the
 * tags it does not know and a firmware answers those it does, so
 * the two were changed for years without breaking each other. It is
 * the device tree's idea, and the ATAGs' before it, the list the
 * ARM boot loaders handed to Linux; a PC's kernel asks its BIOS or
 * ACPI the same questions.
 *
 * References: BCM2835 ARM Peripherals (from memory); the Raspberry Pi
 * firmware's mailbox property interface (its wiki; from memory);
 * QEMU's hw/misc/bcm2835_mbox.c, bcm2835_property.c, hw/usb/hcd-dwc2.c
 * (read by a survey, 2026-09-25). *)

(* registers that read back what is written, some reading fixed values *)
val regs : fixed:(int * int) list -> unit -> Memory.device

(* AUX (base + 0x215000): the mini UART with no backend, as QEMU's *)
val aux : unit -> Memory.device

(* the rest of the I/O space: reads 0; each address logged once *)
val unassigned : log:(string -> int -> unit) -> Memory.device

(* the mailbox (base + 0xB880): a write to MAIL1 (0x20) is answered
 * at once on MAIL0 (0x00, EMPTY in 0x18) -- channel 8's property tags
 * (the ARM's and VideoCore's memory, revisions, clocks, power),
 * channel 1's framebuffer (at vc_base + 1MB, as QEMU's) -- channel 0
 * never, as QEMU. Buffers by bus address (the top two bits dropped).
 * [board_rev] the board revision it says (the Pi1's, the Pi4's). *)
val mailbox : mem:Memory.t -> ram_size:int -> vc_base:int -> board_rev:int -> on_framebuffer:(Framebuffer.geometry -> unit) -> Memory.device

