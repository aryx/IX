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
 * A file's times are the kernel's (xv6 keeps none). *)

(* the device registered *)
val init : unit -> unit
