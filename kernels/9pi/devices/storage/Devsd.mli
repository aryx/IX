(* '#S' holds the disks (principia's devsd.c). It has one controller, for
 * the SD card (Emmc, which is sdmmc's sdM). Its files are:
 * - #S/sdctl;
 * - #S/sdM0/ctl, which gives the card's inquiry, registers, geometry and
 *   partitions, and takes the lines "part name start end" and "delpart
 *   name";
 * - raw;
 * - the partitions: "data" is the whole card, and boot.rc adds "dos".
 * Each partition is read and written by blocks (sdbio). The card is
 * brought online at its first use.
 *
 *     /dev/sdM0/data     the whole card, sector 0 to its end
 *     /dev/sdM0/ctl      written: part dos 8192 532480
 *     /dev/sdM0/dos      then exists: the sectors 8192 to 532479
 *
 *     a read of 100 bytes at offset 1000 of dos
 *       the partition's start is added: sector 8192 + 1, from byte 488
 *       whole sectors of 512 bytes are asked of the card (Emmc), and
 *       the 100 bytes are cut out of them
 *
 * A partition is a file that is a range of another file, and that is
 * all this device adds to the controller: names, offsets, and the
 * cutting of a byte range into blocks. What is in a partition is not
 * its affair: a FAT is read by dossrv or Kdos, and xv6's file system by
 * Kfs, each opening its partition as a file.
 *
 * plan9-is-cleaner:
 * The kernel reads no partition table. In Unix and Linux the kernel
 * finds the partitions itself when a disk appears, and so it holds a
 * parser for each scheme there is (the PC's MBR, GPT, BSD's labels,
 * Apple's map...), which runs with the kernel's rights on bytes that
 * anyone may have written. Here a program reads the table and writes
 * lines to ctl (mini-fdisk: Fdisk). Another program could read another
 * scheme, and a user may carve a card by hand with echo.
 *
 * References: sd(3) in the Plan 9 manual. principia's Kernel.nw
 * (devsd.c). *)

(* resets the controller (sdreset) and registers the device *)
val init : unit -> unit
