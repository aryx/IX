(* tiny-mkfat makes, on the host, the disk image of t6's file system,
 * as xv6's mkfs.c makes xv6's. t6 is a kernel in C, a step before
 * TinyKernel.ml. The usage and examples are in [help], which is what
 * tiny-mkfat -h prints. The file system uses MS-DOS's idea, a FAT.
 * Here is the disk, in blocks of 1 KB:
 *
 *     0             the superblock: a magic number, the size in blocks,
 *                   the block where the FAT starts, the number of the
 *                   FAT's blocks, and the root's first block
 *     1 .. 8        the FAT: a word for each block of the disk, which
 *                   is 0 if the block is free, 0xffffffff at the end of
 *                   a chain, and otherwise the next block of the file
 *                   (the blocks of the superblock and of the FAT are
 *                   marked as ends of chains, so they are never free)
 *     9 ..          the data: the root directory, then the files
 *
 * A directory is a chain of 32-byte entries. An entry has a name of at
 * most 20 bytes, a type (0 free, 1 a directory, 2 a file, 3 a device),
 * the file's first block (0 when it has none) and its size. There are
 * no inodes; a file is its entry, so it has only one name. There is no
 * "." or ".." entry either; t6 resolves ".." in a path by its text, as
 * Plan 9's cleanname does.
 *
 * context:
 * The image is what tiny-machine -d gives a kernel as its disk (through
 * TinyMachineDevices's four words: a block's number, an address, a
 * command and a status), and t6's kernel in C reads its format.
 * TinyKernel's disk has a format of its own (KFS.mli), which the kernel
 * makes on a blank disk. In m-ix, the real FAT, as MS-DOS left it, is
 * served by mini-dossrv (Plan 9's dossrv), and mini-9pi boots from a
 * card that has one.
 *
 * exercises:
 * Each one is cheap, because a disk image is a string to walk:
 * - a checker (-c), which checks that every block is used once, that
 *   the FAT's free blocks are the ones no chain uses, and that every
 *   entry's chain is whole. These are fsck's first passes, and they are
 *   the law for a kernel's writes (an image would be checked after make
 *   check);
 * - extraction (-x name), which reads a file back from an image; the
 *   round trip is a law of its own;
 * - a second FAT for t6, which this program makes once the kernel
 *   learns to use it.
 *
 * cs-history:
 * The two formats are the two answers to one question: where are a
 * file's blocks written down? Unix (Thompson, 1969) puts them in the
 * inode, a small record for each file, kept apart from any directory.
 * A directory then holds only names and inode numbers, a file can have
 * two names or none, and a large file pays with indirect blocks. The
 * FAT (Marc McDonald, for Microsoft's disk BASIC, 1977; then Tim
 * Paterson's 86-DOS, 1980) puts them in one table for the whole disk,
 * with a word for each block that says which block comes next. A file
 * has nothing of its own but its first block, which is kept in its
 * directory entry, so a file has one name, and reading the end of a
 * file means following its chain from the start. The FAT was made for
 * floppy disks, and it is on every memory card sold since, including
 * the Pi's: the Pi's firmware reads the kernel from a FAT partition.
 *
 * design:
 * The file system is made by a program on the host and not by the
 * kernel, as xv6's is. A kernel that can only mount what already exists
 * needs no code to make one, and the format is then checked by two
 * programs written apart, this one and the kernel, which must agree on
 * every byte. A kernel that makes its own disk can be wrong the same
 * way twice.
 *
 * references:
 *  - D. Ritchie and K. Thompson, "The UNIX Time-Sharing System" (CACM,
 *    1974): the inodes
 *  - T. Kowalski, "FSCK -- The UNIX File System Check Program" (1979)
 *  - T. Paterson, 86-DOS (1980): the FAT
 *  - R. Cox, F. Kaashoek, R. Morris, xv6's mkfs.c (2006-): made on the
 *    host
 *)

(* [make files] returns a disk's bytes, made from the files (each a name
 * and its contents): the superblock, the FAT, the root directory and
 * the data. *)
val make : (string * string) list -> string

(* [main caps argv] runs the program on its arguments (its name first;
 * -h prints how to use it) and returns how it ended. *)
val main :
  < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr; .. > ->
  string array -> Exit.t
