(* The Arasan SD host controller (the BCM2835's EMMC, base + 0x300000),
 * SDHCI's registers as the Pi names them, and on it QEMU's SD card
 * (hw/sd/sd.c): its CID ("QEMU!", serial 0xdeadbeef) and a standard
 * capacity CSD for the image's size, byte addressed. Commands complete
 * at once (CMDDONE; R1b ones DATADONE too); a read or write of blocks
 * streams through the DATA port a 32-bit word at a time (DMA channel 4
 * moves them, for 9pi), DATADONE at its end. The interrupt (line 62)
 * while INTERRUPT and IRPTEN share a bit.
 *
 * Two things are modelled, as on the board: the controller, which
 * is registers, and the card, which is a small computer at the end
 * of a few wires that answers numbered commands. A driver writes an
 * argument and a command's number in the controller, which sends
 * them, and reads the card's response there. Waking a card and
 * reading a block, the commands [command] answers:
 *
 *     CMD0            reset
 *     CMD8            which voltages? (and: is the card of version 2)
 *     CMD55, ACMD41   are you ready, and of which capacity kind
 *     CMD2            who are you: the CID, a maker and a serial
 *     CMD3            choose an address for yourself: the RCA
 *     CMD9            your CSD: the size, the block length
 *     CMD7            select the card of that address
 *     CMD16           blocks of 512 bytes
 *     CMD17 arg       read the block at arg (CMD18: several;
 *                     CMD24, CMD25: write): 512 bytes then come
 *                     through the DATA register, four at a time
 *
 * arg is a byte offset for this card, a standard capacity one; a
 * high capacity card counts in blocks, a difference every SD driver
 * has a line for. A disk, to the kernel, is that last line: a
 * number in, 512 bytes out. The partitions and the file system
 * above are the kernel's affair, and the same code reads a disk of
 * another kind.
 *
 * Where it stands: Storage gives the card's bytes, a file of the
 * host (mini-qemu's -drive); Dma moves the DATA words for a kernel
 * that asks it to; on the other side are the kernel's SD driver and
 * its file servers.
 *
 * References: SD Host Controller Simplified Specification 3.00 and SD
 * Physical Layer 3.01 (SD Association); BCM2835 ARM
 * Peripherals, chapter 5; 9pi's emmc.c and sdmmc.c;
 * QEMU's hw/sd/sd.c (read 2026-09-25). *)

(* the card's bytes (the -drive image) *)
type storage = { read : int -> int -> string; write : int -> string -> unit; size : int }

type t

val create : card:storage option -> line:(bool -> unit) -> t

val device : t -> Memory.device
