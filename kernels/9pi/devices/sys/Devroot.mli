(* '#/', the root (principia's devroot.c): the directories the
 * namespace is built on (bin, dev, env, ... empty: mount points), and
 * /boot, the bootdir: the programs 9pi links into its image (boot, the
 * rc script, rcmain, rc, echo, bind, fdisk, dossrv, mount, ls), here the
 * kernel's embedded image (mkbootdir.py's format), read in place.
 *
 *     /         boot  bin  dev  env  fd  mnt  net  proc  root  srv  sys
 *               |     '-------- empty, each: somewhere to bind --------'
 *               boot, rc, rcmain, echo, bind, ...: the image's files
 *
 * This is the first process's whole world before its first bind,
 * and the answer to how a system with no file system in its kernel
 * starts: the few programs needed to find a disk and mount a server
 * are in the kernel's own image, and /boot/boot, a script, does it
 * (boot.rc). A program run from here is paged in from the image as
 * from any file (Fault reads through this device's read).
 *
 * others:
 * Linux's initramfs is the same idea, grown: an archive (cpio)
 * beside the kernel, unpacked into a file system in memory, whose
 * init finds the real root and moves onto it. xv6 instead has its
 * file system in the kernel and its first program's few
 * instructions as an array in the kernel's data (initcode), which
 * exec the disk's /init. *)

(* the bootdir's files read from the embedded image; the device
 * registered *)
val init : unit -> unit
