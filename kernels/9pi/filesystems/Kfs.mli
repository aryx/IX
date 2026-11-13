(* '#x' is xv6's file system as files, served by the kernel itself
 * (plan_rio.md, stage 6: "the file system in the kernel"). It reads
 * the SD card's partition that the attach names: "#xother" is
 * #S/sdM0/other, the card's second partition, and so is "#x".
 *
 *     bind -c '#x' /usr
 *
 * xv6's file system is the one a first course on kernels reads, where
 * the FAT (Kdos) is the one the firmware reads. Its format and its
 * code are in lib_xv6fs, which mini-mkfs also uses to make the image.
 * This file has only what a device is (Dev) and how the partition is
 * read and written, as Kdos does. A file's times come from the kernel
 * (xv6 keeps none).
 *
 * This is mini-9pi's root once there is a card. boot.rc binds it at
 * /root, and also at / after the kernel's own directories, so /usr,
 * /tmp and the programs of /progs are files of this device. A qid's
 * path is the inode's number: the two are one idea, a file's identity
 * apart from its names (Types). Kdos says what having a file system
 * in the kernel costs and saves, compared with Plan 9's way. *)

(* registers the device *)
val init : unit -> unit
