(* tiny-mkfs: the disk image of tiny-os v6's file system, made on the
 * host, as xv6's mkfs.c makes xv6's (plan_tiny_os.md, "v6's design").
 * The format is xv6's, less its log and its link counts; the usage and
 * examples: [help], what tiny-mkfs -h prints.
 *
 * The disk, in blocks of 1 KB:
 *
 *     0             the superblock: a magic, the size in blocks, the
 *                   inodes' number, where the inodes, the bitmap and
 *                   the data start (six words)
 *     1 .. 4        the inodes, 64 bytes each, 16 a block: a type (0
 *                   free, 1 a directory, 2 a file, 3 a device), the
 *                   device's number, the size, 12 direct blocks and
 *                   one indirect (256 more); inode 1 is the root
 *     5             the bitmap, a bit per block, set when used
 *     6 ..          the data
 *
 * A directory is 16-byte entries: an inode's number (0: a free entry),
 * then a name of at most 12 bytes, padded with zeros. Every word is
 * little-endian and 4 bytes, as the kernel's C reads them.
 *
 * Only the kernel's C and this must agree on the format; mini-xv6, in
 * OCaml, could start from it (its xv6 format adds the log and nlink).
 *
 * With -fat, t6's file system (tiny-os's free kernel), MS-DOS's idea:
 *
 *     0             the superblock: a magic, the size in blocks, where
 *                   the FAT starts, its blocks, the root's first block
 *     1 .. 8        the FAT: a word per block of the disk, 0 free,
 *                   0xffffffff a chain's end, else the next block of
 *                   the file (the superblock's and the FAT's own blocks
 *                   are chains' ends, so never free)
 *     9 ..          the data: the root directory, then the files
 *
 * A directory is a chain of 32-byte entries: a name of at most 20
 * bytes, a type (0 free, 1 a directory, 2 a file, 3 a device), the
 * file's first block (0 when it has none) and its size. No inodes: a
 * file is its entry, so it has one name; no "." or "..": t6 resolves
 * ".." in a path by its text, as Plan 9's cleanname.
 *
 * Exercises, each cheap because a disk image is a string to walk:
 * - a checker (-c): every block used once, the bitmap (or the FAT's
 *   free blocks) agreeing, every entry's inode or chain whole: fsck's
 *   first passes, and the law for a kernel's writes (an image checked
 *   after make check);
 * - extraction (-x name): a file read back from an image, the round
 *   trip a law of its own;
 * - v6's log region, or t6's second FAT, made here as the kernels learn
 *   to use them.
 *
 * Where it stands: the image is what tiny-machine -d gives a kernel as
 * its disk (TinyLibMachine's four words: a block's number, an
 * address, a command, a status), and the two formats are read by
 * tiny-os's kernels in C, v6 and t6. TinyKernel has no disk: its files
 * are values in its heap, carried by the boot image. In m-ix the real
 * FAT, as MS-DOS left it, is mini-dossrv's (Plan 9's dossrv), and
 * mini-9pi boots from a card that has one.
 *
 * cs-history:
 * The two formats are the two answers to one question, where a file's
 * blocks are written down. Unix's (Thompson, 1969) puts them in the
 * inode, a small record per file kept apart from any directory: a
 * directory is then only names and inode numbers, a file can have
 * two names or none, and a large file pays with indirect blocks. The
 * FAT (Marc McDonald, for Microsoft's disk BASIC, 1977; then Tim
 * Paterson's 86-DOS, 1980) puts them in one table for the whole
 * disk, a word per block saying which block comes next: nothing per
 * file but its first block, kept in its directory entry, so a file
 * has one name; reading a file's end means following its chain from
 * the start. The FAT was made for floppy disks and is on every
 * memory card sold since, the Pi's among them: its firmware reads
 * the kernel from a FAT partition.
 *
 * design:
 * The file system is made by a program of the host and not by the
 * kernel, as xv6's is: a kernel that can only
 * mount what already exists needs no code to make one, and the
 * format is checked by two programs written apart, this one and the
 * kernel, which must agree on every byte. A kernel that makes its
 * own disk can be wrong the same way twice.
 *
 * References: D. Ritchie and K. Thompson, "The UNIX Time-Sharing
 * System" (CACM, 1974), the inodes; T. Kowalski, "FSCK --
 * The UNIX File System Check Program" (1979); T.
 * Paterson, 86-DOS (1980), the FAT; R. Cox, F. Kaashoek, R. Morris,
 * xv6's mkfs.c (2006-), made on the host. *)

(* a disk's bytes, from the files (each a name and its contents): the
 * superblock, the inodes, the bitmap, the root directory, the data *)
val make : (string * string) list -> string

(* the program: its arguments (-h: how) to its exit status *)
val main : < Cap.argv; Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr; .. > -> int
