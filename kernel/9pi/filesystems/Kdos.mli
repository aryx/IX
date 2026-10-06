(* '#F', a FAT as files, by the kernel itself: the SD card's partition
 * of a name (the attach's: "#Fdos" is #S/sdM0/dos, and so is "#F").
 *
 *     bind '#Fdos' /root
 *
 * Plan 9's way is a program, dossrv, a file server the kernel speaks
 * 9P to (user/dossrv is ix's); this is the other way, a kernel's
 * usual one, with the same code: lib_fat's Fat, which knows what a
 * FAT is. Here is only what a device is (Dev: its tree walked, its
 * entries, a file read, written, made, removed) and how the partition
 * is read and written (the disk's device, called from the kernel).
 * The partitions are still a program's to say (fdisk -p). *)

(* the device registered *)
val init : unit -> unit
