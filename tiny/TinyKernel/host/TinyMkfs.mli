(* tiny-mkfs makes a disk of tiny-kernel's file system on the host,
 * filled with files of the host, for tiny-machine -d. Its usage and
 * examples are in [help], which is what tiny-mkfs -h prints.
 *
 * The disk is written by the kernel's own file system code,
 * TinyKernel/KFS.ml, compiled by OCaml for the host (as are its test
 * and tests/KFS_tests/Cat.ml, which reads a disk back). The disk is
 * first mounted blank, so it is formatted exactly as the kernel
 * formats it at its first boot. Then each file is created and written
 * as a program's write would do it. A disk is therefore right by
 * construction: there is no second writer of the format to keep in
 * step with the kernel.
 *
 * TinyKernel/Makefile uses it to make two disks: disk.img holds the
 * system (/bin, /lib, /examples) and src.img holds the sources (/src).
 * This keeps them out of boot.img, whose files must fit in 10 MB, below
 * where the file system's buffers start. m-ix's machine has the same
 * split between its boot.img and its card.img.
 *
 * twin:
 * mini-mkfs, m-ix's version of xv6's mkfs.c. This one follows its
 * command line: -m, name=file, and directory/. We dropped -b and -i,
 * because here a block is always 1 KB, and the inodes are a file of
 * their own (see KFS.mli). *)

(* [main caps argv] runs tiny-mkfs's command line. *)
val main :
  < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr; .. > ->
  string array -> Exit.t
