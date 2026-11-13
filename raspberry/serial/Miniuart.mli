(* This is the mini UART of the BCM2835's AUX block (base + 0x215000),
 * as QEMU models it (hw/char/bcm2835_aux.c). Characters written go out
 * at once, so LSR always says the transmitter is empty and idle
 * (0x60). Received characters wait in an 8-deep FIFO. The interrupt
 * (line 29) is raised while IER's receive bit is set and a character
 * is waiting, or while IER's transmit bit is set. It is 9pi's console
 * (QEMU's second -serial). *)

type t

val create : output:(char -> unit) -> line:(bool -> unit) -> t

(* whether there is room for a character from the host *)
val room : t -> bool
val input : t -> char -> unit

val device : t -> Memory.device
