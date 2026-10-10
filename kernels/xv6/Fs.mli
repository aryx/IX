(* mini-xv6's file system (xv6's fs.c, and sysfile.c's operations on
 * names): xv6's on-disk format (xv6-multiarch's: 256-byte dinodes, 58
 * direct blocks; the block size read from the disk), read and written
 * in place. With ONE EXTENSION OF IX'S, not xv6's: files larger than
 * xv6's limit (314 KB), by a second block of numbers (Fs.ml says how,
 * and marks each line of it "ix's extension").
 *
 * The disk is RAM (xv6's ramdisks, memide.c and ramdisk.c: fs.img
 * linked into the kernel, start.s), so the layers xv6 puts between a
 * system call and a disk block have nothing to do here, and are not:
 * - no buffer cache (bio.c): a block is its address, base + b * bsize;
 * - no log (log.c): a write cannot be half done by a crash of the disk,
 *   the whole disk is lost with the machine (filewrite's chunks, the
 *   log transactions' size, stay: they make a failing write's result,
 *   File.ml);
 * - no inode copies (ilock's I_VALID, iupdate): an inode's fields are
 *   read and written on the disk, through [get] and [set];
 * - no locks: one core, a kernel never interrupted (Proc.ml).
 * What stays in memory is what the disk cannot say: which inodes are in
 * use, and by how many ([Types.inode], the table [icache]).
 *
 * The disk, in blocks (the superblock says where each part starts):
 *
 *     0    1       2 ..      inodestart ..    bmapstart ..   then
 *     +----+-------+---------+----------------+--------------+------
 *     |    | super | the log | the inodes,    | a bit a      | the
 *     |    | block | (unused | 256 bytes each | block: used? | data
 *     +----+-------+- here) -+----------------+--------------+------
 *
 * A file is an inode, and an inode is a number: its place in the
 * inodes' blocks. It has no name. Its bytes are in blocks that it
 * lists, the first 58 by their numbers, the next through a block of
 * numbers (and, ours, through a block of such blocks):
 *
 *     the inode n            a directory is a file too, of entries of
 *     type, nlink, size      16 bytes: an inode's number (2 bytes, 0:
 *     addrs[0]  ----> block  a free entry) and a name (14)
 *     ...
 *     addrs[57] ----> block       2  "bin"
 *     addrs[58] --.               3  "README"
 *                 v
 *              numbers ----> block, block, ... (bsize / 4 of them)
 *
 * So /bin/ls is found by reading the root's entries (inode 1) for
 * "bin", which gives a number, then that inode's entries for "ls"
 * ([namei]); a name is only an entry in a directory, and two entries
 * with one number are the same file (link), which is freed when no
 * entry names it (nlink 0) and no process has it open ([iput]).
 *
 * cs-history:
 * This is Unix's file system as Ken Thompson made it (1969-1971): a
 * flat array of inodes, directories that are files of names and
 * numbers, small files reached directly and large ones through
 * blocks of numbers. xv6's is the sixth edition's with other sizes.
 * What it had of new was what it left out: a file is bytes, with no
 * records and no type the kernel knows, and a device is a file too
 * (an inode of type Devnode here, major 1 the console).
 *
 * terminology:
 * inode: probably "index node", Dennis Ritchie said, the name's
 * origin already forgotten. A hard link is a directory's entry; the
 * file's name is not a property of the file. A file descriptor is
 * not an inode either: File.mli draws the three.
 *
 * evolution:
 * A crash of V6 left the disk between two states, to be repaired by
 * hand and then by fsck. Berkeley's fast file system (1984) kept the
 * format's ideas and made it fast on a real disk: larger blocks,
 * inodes near their data (cylinder groups), long names. Then the
 * disk was made safe to crash: a log of the changes written first
 * (journaling: xv6's log.c is the smallest one, ext3 and NTFS the
 * known ones), or nothing overwritten at all (the log-structured
 * file system, 1991; ZFS, btrfs). None is needed for a disk in RAM.
 *
 * others:
 * mini-9pi reads and writes the same format (its Kfs, over Xv6fs)
 * on an SD card's partition, a real disk this time, and mini-mkfs
 * makes the images. Its FAT is served Plan 9's way too: by a
 * program that speaks 9P (dossrv), not by code in the kernel.
 *
 * References: the xv6 book's chapter "File system", layer by layer
 * (the ones kept here: the block allocator, inodes, directories,
 * path names). Ritchie and Thompson, "The UNIX Time-Sharing System"
 * (1974), section 4, "Implementation of the file system". McKusick,
 * Joy, Leffler and Fabry, "A Fast File System for UNIX" (ACM
 * Transactions on Computer Systems, 1984). Rosenblum and Ousterhout,
 * "The Design and Implementation of a Log-Structured File System"
 * (1991). xv6's fs.c, fs.h, mkfs.c. *)

val rootino : int

(* An inode's fields are on the disk, reached by [get] and [set]: *)
type field
val i_major : field
val i_nlink : field
val i_size : field
val get : Types.inode -> field -> int
val set : Types.inode -> field -> int -> unit

(* its type, the short at the dinode's start *)
val itype : Types.inode -> Types.itype

(* the inodes in use (xv6's icache, NINODE at most): one held, once
 * more, let go (the last reference to an inode no directory names
 * frees it) *)
val iget : int -> Types.inode
val idup : Types.inode -> Types.inode
val iput : Types.inode -> unit

(* the file's blocks freed, its size 0 (O_TRUNC) *)
val itrunc : Types.inode -> unit

(* [readi ip off n]: n bytes, fewer at the end, none past it (None: a
 * negative offset or count). [writei ip off s]: s's length, the file
 * grown; or -1 (off past the end, or past MAXFILE). Files and
 * directories; devices are File.ml's *)
val readi : Types.inode -> int -> int -> string option
val writei : Types.inode -> int -> string -> int

(* a read(2)'s and a write(2)'s, through the user's memory (File.dst,
 * File.src's shapes): xv6-riscv's readi, writei, a block's piece at a
 * time; the bytes, or -1 *)
val readi_to : Types.inode -> int -> int -> (int -> string -> bool) -> int
val writei_from : Types.inode -> int -> int -> (int -> int -> string option) -> int

(* the disk's block size (512 or 1024: read from it) *)
val bsize : int

(* struct stat's bytes, at 0 and at 16 (its padding the user's) *)
val stat_head : Types.inode -> string
val stat_size : Types.inode -> string

(* a path's inode, from the root or the running process's directory:
 * held; or its directory's and its last element (at most 14 bytes:
 * DIRSIZ) *)
val namei : string -> Types.inode option
val nameiparent : string -> (Types.inode * string) option

(* sysfile.c's: [create path t major minor], the inode (held) made or,
 * for a file, found (a file or a device); [link old new]; [unlink
 * path] (not "." nor "..", not a directory with entries). 0 or -1 *)
val create : string -> Types.itype -> int -> int -> Types.inode option
val link : string -> string -> int
val unlink : string -> int
