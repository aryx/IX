(* '#/' is the root (principia's devroot.c). It has the directories that
 * the name space is built on (bin, dev, env, ..., which are empty and
 * serve as mount points), and /boot, the bootdir. The bootdir holds the
 * programs that 9pi links into its image (boot, which is the rc script,
 * rcmain, rc, echo, bind, fdisk, dossrv, mount and ls); here they come
 * from the kernel's embedded image (in mkbootdir.py's format), read in
 * place.
 *
 *     /         boot  bin  dev  env  fd  mnt  net  proc  root  srv  sys
 *               |     '-------- each one empty, somewhere to bind -----'
 *               boot, rc, rcmain, echo, bind, ...: the image's files
 *
 * This is the first process's whole world before its first bind. It
 * is also the answer to how a system with no file system in its kernel
 * starts: the few programs needed to find a disk and mount a server are
 * in the kernel's own image, and /boot/boot, a script, does it
 * (boot.rc). A program run from here is paged in from the image as it
 * would be from any file (Fault reads through this device's read).
 *
 * others:
 * Linux's initramfs is the same idea, grown larger. It is an archive
 * (cpio) beside the kernel, unpacked into a file system in memory, whose
 * init finds the real root and moves onto it. xv6 instead has its file
 * system in the kernel, and its first program is a few instructions
 * kept as an array in the kernel's data (initcode), which exec the
 * disk's /init. *)

(* reads the bootdir's files from the embedded image, and registers the
 * device *)
val init : unit -> unit
