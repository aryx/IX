(* '#S', the disks (principia's devsd.c) with its one controller, the
 * SD card (Emmc: sdmmc's sdM): #S/sdctl, #S/sdM0/ctl (the card's
 * inquiry, registers, geometry, partitions; written "part name start
 * end", "delpart name"), raw, and the partitions ("data" the whole card,
 * boot.rc adds "dos"), each read and written by blocks (sdbio). The
 * card brought online at its first use.
 *
 *     /dev/sdM0/data     the whole card, sector 0 to its end
 *     /dev/sdM0/ctl      written: part dos 8192 532480
 *     /dev/sdM0/dos      then exists: the sectors 8192 to 532479
 *
 *     a read of 100 bytes at offset 1000 of dos
 *       the partition's start added: sector 8192 + 1, from byte 488
 *       whole sectors of 512 asked of the card (Emmc), the 100
 *       bytes cut out of them
 *
 * A partition is a file that is a range of another file, and that
 * is all this device adds to the controller: names, offsets, and
 * the cutting of a byte range into blocks. What is in a partition
 * is not its affair: a FAT is read by dossrv or Kdos, xv6's file
 * system by Kfs, each opening its partition as a file.
 *
 * plan9-is-cleaner:
 * The kernel reads no partition table. In Unix and Linux the
 * kernel finds the partitions itself when a disk appears, and so
 * holds a parser for each scheme there is (the PC's MBR, GPT,
 * BSD's labels, Apple's map...) running with its rights on bytes
 * anyone may have written. Here a program reads the table and
 * writes lines to ctl (mini-fdisk: Fdisk), another program could
 * read another scheme, and a user may carve a card by hand with
 * echo.
 *
 * References: sd(3) in the Plan 9 manual. principia's Kernel.nw
 * (devsd.c). *)

(* the controller reset (sdreset) and the device registered *)
val init : unit -> unit
