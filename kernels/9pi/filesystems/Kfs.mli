(* '#x', xv6's file system as files, by the kernel itself (plan_rio.md,
 * stage 6: "the file system in the kernel"): the SD card's partition
 * of a name (the attach's: "#xother" is #S/sdM0/other, the card's
 * second, and so is "#x").
 *
 *     bind -c '#x' /usr
 *
 * The one a first course on kernels reads, where the FAT (Kdos) is
 * the one the firmware reads: its format and its code are
 * lib_xv6fs's, which mini-mkfs makes the image with. Here is what a
 * device is (Dev) and how the partition is read and written, as Kdos.
 * A file's times are the kernel's (xv6 keeps none).
 *
 * This is mini-9pi's root once there is a card: boot.rc binds it at
 * /root and after the kernel's own directories at /, so /usr, /tmp
 * and the programs of /progs are files of this device. A qid's path
 * is the inode's number: the two are one idea, a file's identity
 * apart from its names (Types). Kdos says what having a file system
 * in the kernel costs and saves, against Plan 9's way. *)

(* the device registered *)
val init : unit -> unit
