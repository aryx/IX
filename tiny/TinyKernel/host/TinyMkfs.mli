(* tiny-mkfs: a disk of tiny-kernel's file system, made on the host with
 * files of the host's, for tiny-machine -d. Its usage and examples:
 * [help], what tiny-mkfs -h prints.
 *
 * The disk is written by the kernel's own file system,
 * TinyKernel/KFS.ml, compiled by OCaml for the host (as its test
 * and tests/KFS_tests/Cat.ml, which reads a disk back): mounted
 * blank, so made as the kernel makes it at its first boot, then each file
 * created and written as a program's write would. So a disk is right by
 * construction: no second writer of the format to keep in step with the
 * kernel's.
 *
 * TinyKernel/Makefile makes disk.img so: the sources (/src), which the
 * image carried in memory before (boot.img: its files are at most 10 MB,
 * where the file system's buffers start), as m-ix's machine has its
 * boot.img and its card.img.
 *
 * twin:
 * mini-mkfs (m-ix's, xv6's mkfs.c), whose command line this is: -m,
 * name=file, a directory/. Dropped: -b and -i, a block being 1 KB and
 * the inodes a file of their own here (KFS.mli). *)

(* [main caps argv]: tiny-mkfs's command line *)
val main :
  < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr; .. > ->
  string array -> Exit.t
