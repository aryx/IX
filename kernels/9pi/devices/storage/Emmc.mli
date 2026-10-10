(* The SD card (principia's emmc.c and sdmmc.c): the BCM2835's Arasan
 * SD host controller (the EMMC, SDHCI's registers) and on it one card,
 * brought online as sdmmc does it (GO_IDLE, SEND_IF_COND, APP_CMD and
 * SD_SEND_OP_COND until powered up, CID, RCA, CSD, SELECT, BLOCKLEN,
 * bus width 4). Blocks read and written by the controller's data port
 * a word at a time, polled (9pi moves them by DMA, waiting for its
 * interrupt: here the kernel simply waits). Registers are read as
 * 16-bit halves (Machine.io_get16: a word is past the Pi1's ints), the
 * card's registers kept as bytes.
 *
 * A card answers commands, each a number and a 32-bit argument sent
 * on one wire, its reply on the same. Bringing one online is a
 * fixed conversation ([online]):
 *
 *     CMD0   GO_IDLE            reset
 *     CMD8   SEND_IF_COND       3.3 V and a pattern to echo: a card
 *                               that answers is of the second version
 *     CMD55, ACMD41             (55: the next command is an application's)
 *            SD_SEND_OP_COND    again, a tenth of a second apart, until
 *                               the card says it is powered up; its
 *                               answer (OCR) says if it is an SDHC
 *     CMD2   ALL_SEND_CID       who made it, its serial number
 *     CMD3   SEND_RELATIVE_ADDR the card picks an address (RCA)
 *     CMD9   SEND_CSD           its size, among other things
 *     CMD7   SELECT_CARD        from now on commands are for it
 *     CMD16  SET_BLOCKLEN       512
 *     CMD55, ACMD6              four data wires where there was one
 *
 *     then, for each read or write of blocks:
 *     CMD18 or CMD25            read or write several, from a block's
 *                               number (an SDHC) or byte offset
 *     the words through the controller's data register
 *     CMD12  STOP_TRANSMISSION
 *
 * Above it Devsd makes the card a file; under it Machine reaches
 * the controller's registers. On an emulator the card is a file of
 * the host's, and the conversation is the same (the emulator's
 * model of a card answers it).
 *
 * terminology:
 * MMC is the MultiMediaCard, the SD card's ancestor, whose command
 * set SD extended; eMMC is an MMC chip soldered on a board; SDHC
 * and SDXC are SD cards past 2 GB and 32 GB, addressed by block
 * where the first cards were by byte. SDHCI is something else: the
 * standard layout of a host controller's registers, the side this
 * file drives. And EMMC, in capitals, is only the name Broadcom
 * gave this controller on the Pi, where what is plugged is an SD
 * card.
 *
 * wib:
 * The kernel waits in a loop for the controller, and moves each
 * word itself. A read of the card then stops everything for its
 * time, the mouse too. 9pi lets the controller copy to memory
 * (DMA) and sleeps the process until an interrupt; that is two
 * mechanisms and a kind of bug (who wakes whom) that this kernel
 * does not have anywhere.
 *
 * References: the SD Association's "Physical Layer Simplified
 * Specification", for the commands and the registers' fields; its
 * "SD Host Controller Simplified Specification" for SDHCI.
 * principia's Kernel.nw (emmc.c, sdmmc.c). *)

(* the card: its RCA, its OCR (4 bytes, the lowest first), its CID and
 * CSD (16 bytes), its size *)
type card = {
  rca : int;
  ocr : string;
  cid : string;
  csd : string;
  sectors : int;
  secsize : int;
}

(* the controller reset (emmcinit); its clock and interrupts set
 * (emmcenable) *)
val init : unit -> unit
val enable : unit -> unit

(* "Arasan eMMC SD Host Controller 02 Version 24" (emmcinquiry) *)
val inquiry : unit -> string

(* the card brought online (mmconline); Error on a failed command *)
val online : unit -> card

(* [bio c write buf bno nb]: nb blocks from block bno read (buf "": a
 * string of them) or written (buf's), as mmcbio's multiblock
 * transfers; Error eio *)
val bio : card -> bool -> string -> int -> int -> string

(* the controller's part of the unit's ctl (mmcrctl): "rca ... ocr ...
 * cid ... csd ...\ngeometry ...\n" *)
val rctl : card -> string
