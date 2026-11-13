(* These are the BCM2835's smaller devices, each a Memory.device whose
 * offsets are from its base. They are what the Pi kernels touch, as
 * QEMU's raspi1ap models them (plan_pi.md, decision 4).
 *
 * The one with an idea is the mailbox. On a Pi, the ARM is not the
 * master of the board. The VideoCore, the graphics processor, booted
 * it, owns the top of the memory and the screen, and knows what the
 * ARM must ask: how much memory is mine, what board is this, give me
 * a framebuffer. The asking is done by a letter. The kernel fills a
 * buffer in its own memory, writes the buffer's address (with the
 * channel, 8, in the four low bits) to one register, and reads it
 * back from another when the answer is in the buffer. Here is the
 * letter that asks "How much memory has the ARM?", in words of 32
 * bits:
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
 * Several tags may go in one letter. The framebuffer is asked for the
 * same way (0x00048003 for the size wanted, 0x00048005 for a depth,
 * and 0x00040001 to allocate it, to which an address and a length
 * come back). From then on, the screen is memory that the kernel
 * writes pixels to (Framebuffer).
 *
 * design:
 * This is a protocol of tagged values, each with its length, where a
 * register for each question would have done. A kernel skips the
 * tags it does not know, and a firmware answers those it does, so the
 * two were changed for years without breaking each other. It is the
 * idea of the device tree, and of the ATAGs before it, the list that
 * the ARM boot loaders handed to Linux. A PC's kernel asks its BIOS or
 * ACPI the same questions.
 *
 * References: BCM2835 ARM Peripherals; the Raspberry Pi firmware's
 * mailbox property interface (its wiki), for the tags;
 * QEMU's hw/misc/bcm2835_mbox.c, bcm2835_property.c, hw/usb/hcd-dwc2.c
 * (read by a survey, 2026-09-25). *)

(* registers that read back what is written, some of which read fixed
 * values *)
val regs : fixed:(int * int) list -> unit -> Memory.device

(* AUX (base + 0x215000): the mini UART with no backend, as in QEMU.
 * Nothing uses it: Board maps Miniuart there. *)
val aux : unit -> Memory.device

(* the board's random number generator (the Pi 1's BCM2835, the Pi 4's
 * RNG200). Its words are the 32 bits of [!random ()]. Main sets it to
 * the host's /dev/urandom. When it is left alone (in the tests and the
 * page), it is OCaml's Random, which is no secret. *)
val random : (unit -> int) ref
val rng : pi4:bool -> Memory.device

(* the rest of the I/O space, which reads 0; each address is logged once *)
val unassigned : log:(string -> int -> unit) -> Memory.device

(* the mailbox (base + 0xB880). A write to MAIL1 (0x20) is answered at
 * once on MAIL0 (0x00, with EMPTY in 0x18). That is so for channel 8's
 * property tags (the ARM's and the VideoCore's memory, the revisions,
 * clocks and power) and for channel 1's framebuffer (at vc_base + 1MB,
 * as in QEMU). As in QEMU, channel 0 is never answered. Buffers are
 * given by bus address (the top two bits are dropped). [board_rev] is
 * the board revision it gives (the Pi1's or the Pi4's). *)
val mailbox : mem:Memory.t -> ram_size:int -> vc_base:int -> board_rev:int -> on_framebuffer:(Framebuffer.geometry -> unit) -> Memory.device

