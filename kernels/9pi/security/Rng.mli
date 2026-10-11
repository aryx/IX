(* The board's random number generator, what /dev/random gives: the
 * secrets of a TLS connection (its key exchange, its hello) cannot be
 * Random.int's, which anyone who knows the seed computes again.
 *
 * The Pi 1's (BCM2835) is three registers at the devices' 0x104000:
 * a control (bit 0 starts it), a status (its top byte, the words
 * ready; written, how many of the first to throw away, the generator
 * warming up), and the data, a word a read. The Pi 4's (RNG200, at the
 * same place) has a control, a count of the words ready at 0x24 and
 * the data at 0x20.
 *
 *     start          once, at boot: started long before a read
 *     bytes n        n bytes, two from each word read (a register is
 *                    read by halves, each read a new word); None when
 *                    no word comes (a machine without the device)
 *
 * history:
 * Plan 9's kernel has no such device on most machines: its
 * /dev/random (random.c, genrandom, the kernel process kgenrandom) is
 * a counter sampled by the clock's interrupt, the two drifting apart,
 * a few bits a tick. 9pi's (bcm's) kept that. Here the chip's own.
 *
 * References: Linux's drivers/char/hw_random/bcm2835-rng.c and
 * iproc-rng200.c; QEMU's hw/misc/bcm2835_rng.c. *)

val start : unit -> unit
val bytes : int -> string option
