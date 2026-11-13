(* The board's random number generator, which is what /dev/random gives.
 * The secrets of a TLS connection (its key exchange, its hello) cannot
 * come from Random.int, whose numbers anyone who knows the seed can
 * compute again.
 *
 * The Pi 1's generator (BCM2835) is three registers at the devices'
 * 0x104000:
 * - a control register, whose bit 0 starts it;
 * - a status register: its top byte is the number of words ready, and
 *   writing it says how many of the first words to throw away while the
 *   generator warms up;
 * - the data register, which gives a word at each read.
 * The Pi 4's generator (RNG200, at the same place) has a control
 * register, a count of the words ready at 0x24, and the data at 0x20.
 *
 *     start          once, at boot, so that it is started long before
 *                    a read
 *     bytes n        n bytes, two from each word read (a register is
 *                    read by halves, and each read gives a new word);
 *                    None when no word comes, or when no device answers
 *                    at the address (QEMU's raspi4b has none: io_probe)
 *
 * history:
 * Plan 9's kernel has no such device on most machines. Its /dev/random
 * (random.c, genrandom, the kernel process kgenrandom) is a counter
 * sampled by the clock's interrupt: the two drift apart, which gives a
 * few bits at each tick. 9pi's (that is, bcm's) kept that. Here the
 * kernel uses the chip's own generator.
 *
 * References: Linux's drivers/char/hw_random/bcm2835-rng.c and
 * iproc-rng200.c; QEMU's hw/misc/bcm2835_rng.c. *)

val start : unit -> unit
val bytes : int -> string option
