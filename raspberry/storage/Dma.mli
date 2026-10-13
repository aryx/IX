(* The BCM2835's DMA controller (base + 0x7000): 15 channels, each a
 * chain of 32-byte control blocks (TI, source, destination, length,
 * stride, next) by bus address; writing ACTIVE runs the chain at once,
 * incrementing the addresses TI says, a peripheral's register (9pi's
 * EMMC data port) read or written in place; then END, and INT when TI
 * asks, raising the channel's interrupt (16 + channel). 2D mode is
 * not modelled, and a transfer is immediate, as QEMU's
 * (hw/dma/bcm2835_dma.c), but one to a peripheral that asks for its
 * words at its own pace (TI's DEST_DREQ, and a PERMAP said by [pace]):
 * that block's words are given one by one to who [pull]s them, the
 * channel active until its last, then its interrupt and the next
 * block. The sound is the one such peripheral (Pwm): a block of
 * samples lasts what its samples last.
 *
 * Reference: BCM2835 ARM Peripherals, chapter 4; 9pi's
 * dma.c. *)

type t

val create : mem:Memory.t -> io:int -> line:(int -> bool -> unit) -> t

val device : t -> Memory.device

(* [pace t ~permap]: the blocks to the peripheral of that request line
 * wait for [pull] *)
val pace : t -> permap:int -> unit

(* [pull t ~permap]: the next word for that peripheral, None when no
 * channel is giving it one; the block's last word ends the block *)
val pull : t -> permap:int -> int option

(* the words left of the block being given to it *)
val left : t -> permap:int -> int option
