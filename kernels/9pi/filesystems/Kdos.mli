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
 * The partitions are still a program's to say (fdisk -p).
 *
 *     cat /mnt/fat/config.txt, a read, the two ways
 *
 *     bind '#Fdos' /mnt/fat              mount /srv/dos /mnt/fat ...
 *     Sysfile -> Dev 'F'.read            Sysfile -> Dev 'M'.read
 *       Fat.read                           T Read on a pipe (Devmnt)
 *         Dev 'S'.read (Devsd, Emmc)       dossrv runs: Fat.read
 *                                            pread of /dev/sdM0/dos:
 *                                            a system call, Dev 'S'
 *                                          R Read on the pipe
 *                                        cat runs again
 *
 * design:
 * In the kernel or outside it: the oldest argument about kernels,
 * here with one file system's code on both sides of it. Outside,
 * the server is a program: it can be killed, restarted, replaced
 * and debugged like one, its mistakes are its own, and the kernel
 * knows one protocol and no format. Inside, a read is a function
 * call where it was two messages, two changes of process and the
 * copies between; and there is one program less to have in the
 * image at boot. Unix chose inside; microkernels (Mach, Minix, L4:
 * ix's kernels/l4) outside for everything; Plan 9 outside for file
 * systems and inside for devices. boot.rc uses whichever the image
 * has, so the two can be timed against each other. *)

(* the device registered *)
val init : unit -> unit
