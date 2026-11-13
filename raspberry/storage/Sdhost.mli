(* This is the Arasan SD host controller (the BCM2835's EMMC, base +
 * 0x300000), with SDHCI's registers as the Pi names them. On it is
 * QEMU's SD card (hw/sd/sd.c), with QEMU's CID ("QEMU!", serial
 * 0xdeadbeef) and a standard capacity CSD for the image's size; the
 * card is byte addressed. Commands complete at once and raise CMDDONE
 * (and DATADONE too for the R1b ones). A read or write of blocks
 * streams through the DATA port, a 32-bit word at a time (for 9pi, DMA
 * channel 4 moves the words), and raises DATADONE at its end. The
 * interrupt (line 62) is raised while INTERRUPT and IRPTEN have a bit
 * set in common.
 *
 * Two things are modelled, as on the board. The controller is a set
 * of registers. The card is a small computer at the end of a few
 * wires, which answers numbered commands. A driver writes an argument
 * and a command's number in the controller, which sends them to the
 * card, and then reads the card's response there. Here are the
 * commands that [command] answers, to wake a card and read a block:
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
 * arg is a byte offset for this card, because it is a standard
 * capacity one. A high capacity card counts in blocks, and every SD
 * driver has a line for that difference. To the kernel, a disk is
 * that last command: a number goes in and 512 bytes come out. The
 * partitions and the file system above are the kernel's affair, and
 * the same code reads a disk of another kind.
 *
 * Where it stands: Storage gives the card's bytes, from a file of the
 * host (mini-qemu's -drive). Dma moves the DATA words for a kernel
 * that asks it to. On the other side are the kernel's SD driver and
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
