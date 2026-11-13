(* '#F' is a FAT as files, served by the kernel itself. It reads the
 * SD card's partition that the attach names: "#Fdos" is
 * #S/sdM0/dos, and so is "#F".
 *
 *     bind '#Fdos' /root
 *
 * Plan 9's way is a program, dossrv, a file server that the kernel
 * speaks 9P to (user/dossrv is ix's). This is the other way, the one
 * kernels usually take, with the same code: lib_fat's Fat, which
 * knows what a FAT is. This file has only what a device is (Dev: it
 * walks its tree, lists its entries, and reads, writes, makes and
 * removes a file) and how the partition is read and written (through
 * the disk's device, called from the kernel). Saying what the
 * partitions are is still a program's job (fdisk -p).
 *
 *     cat /mnt/fat/config.txt does a read, in the two ways:
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
 * In the kernel or outside it? It is the oldest argument about
 * kernels, and here one file system's code is on both sides of it.
 * Outside, the server is a program: it can be killed, restarted,
 * replaced and debugged like one, its mistakes are its own, and the
 * kernel knows one protocol and no format. Inside, a read is a
 * function call where it was two messages, two changes of process and
 * the copies between them; and there is one program less to have in
 * the image at boot. Unix chose inside; microkernels
 * (Mach, Minix, L4, which is ix's kernels/l4) chose outside for
 * everything; Plan 9 chose outside for file systems and inside for
 * devices. boot.rc uses whichever the image has, so the two can be
 * timed against each other. *)

(* registers the device *)
val init : unit -> unit
