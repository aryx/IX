(* This is the BCM2835's DMA controller (base + 0x7000). It has 15
 * channels, and each runs a chain of 32-byte control blocks (TI,
 * source, destination, length, stride, next), linked by bus address.
 * Writing ACTIVE runs the chain at once. The addresses that TI says to
 * increment are incremented, and the others stay on a peripheral's
 * register (9pi's EMMC data port), which is read or written in place.
 * Then the channel sets END, and INT when TI asks for it, which raises
 * the channel's interrupt (16 + channel).
 *
 * As in QEMU (hw/dma/bcm2835_dma.c), 2D mode is not modelled, and a
 * transfer is immediate. The exception is a transfer to a peripheral
 * that asks for its words at its own pace (TI's DEST_DREQ, with a
 * PERMAP given to [pace]). That block's words are given one by one
 * to whoever [pull]s them, and the channel stays active until the last
 * one. Then come its interrupt and the next block. The sound (Pwm) is
 * the one such peripheral, so a block of samples lasts as long as its
 * samples take to play.
 *
 * Reference: BCM2835 ARM Peripherals, chapter 4; 9pi's
 * dma.c. *)

type t

val create : mem:Memory.t -> io:int -> line:(int -> bool -> unit) -> t

val device : t -> Memory.device

(* [pace t ~permap] makes the blocks to the peripheral of that request
 * line wait for [pull] *)
val pace : t -> permap:int -> unit

(* [pull t ~permap] gives the next word for that peripheral, or None
 * when no channel is giving it one. The block's last word ends the
 * block. *)
val pull : t -> permap:int -> int option

(* [left t ~permap] is the number of words left in the block being
 * given to that peripheral *)
val left : t -> permap:int -> int option
