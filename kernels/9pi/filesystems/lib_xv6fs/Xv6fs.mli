(* xv6's file system on a device (a partition, an image): the one a
 * first course on kernels reads (xv6's fs.c; ix's mini-xv6 has it on a
 * RAM disk: kernels/xv6's Fs), here over a device's bytes, for
 * mini-9pi's card (its second partition) and for the tool that makes
 * its image (mini-mkfs). As lib_fat: how the device is read and
 * written is the caller's, and it keeps to what the kernel's compiler
 * has.
 *
 * On the disk (blocks of 512 or 1024 bytes): a boot block; the
 * superblock, which says where the rest is; the inodes, 256 bytes
 * each: a type, a count of names, a size, and the numbers of the
 * file's blocks (58 direct, then a block of numbers); a bitmap, a bit
 * a block taken; the blocks. A directory is a file of entries of 16
 * bytes: an inode's number and a name of 14 characters at most. A file
 * is its inode's number: names are only in directories.
 *
 * The format is xv6-multiarch's, with ONE EXTENSION OF IX'S, not
 * xv6's: a second block of numbers, of blocks of numbers (xv6's
 * exercise "large files"), its own number in the inode's 8 bytes xv6
 * leaves unused (at byte 8). Without it a file has 314 KB at most,
 * less than one of ix's programs; with it, 64 MB. An image of xv6's
 * is read as it is (those bytes are 0 there); a file made larger than
 * xv6's limit is one xv6 cannot read whole (ix's mini-xv6 can:
 * kernels/xv6's Fs has the same extension). In Xv6fs.ml each line of
 * it is marked "ix's extension". A SECOND ONE, smaller: the time a file
 * was last written, in the 4 bytes after (byte 12; 0, as xv6 leaves
 * them: not known). xv6 keeps no time, and no permissions: there is no
 * place left for those.
 *
 * No log, no cache of blocks: each change is written at once, as
 * lib_fat's. What fails raises Failure.
 *
 *     | boot | super | inodes ...      | bitmap | blocks ...          |
 *
 *     the name /usr/pad/notes, found:
 *     inode 1 (the root, a directory)   its blocks hold entries:
 *                                         usr -> 7
 *     inode 7 (a directory)               pad -> 12
 *     inode 12 (a directory)              notes -> 31
 *     inode 31 (a file, 9000 bytes)     its block numbers: 500, 501,
 *                                       502, ...: byte 5000 is in the
 *                                       file's block 5000 / block size
 *
 * The inode is the file; a directory only gives it names. So one
 * file may have several (links, counted in the inode: it goes when
 * the count is 0), a rename moves 16 bytes, and the n-th block of a
 * file is one lookup in the inode's list, or two through the block
 * of numbers. The inode's and the root's numbers above are an
 * example's.
 *
 * cs-history:
 * This is the Unix file system of 1974 nearly unchanged: Ken
 * Thompson's inodes, a directory as a file of 16-byte entries (two
 * bytes of inode number, 14 of name: the limit lasted until
 * Berkeley's fast file system, 1983), a list of free blocks where
 * xv6 has a bitmap. xv6 (MIT, 2006) rewrote the sixth edition's
 * kernel for today's C and processors to teach from, as John Lions
 * had taught from the original; it added a log, which this version
 * leaves out.
 *
 * wib:
 * Without a log, a crash between two writes of one change leaves
 * the disk wrong: a block marked taken that no file has, or worse a
 * directory's entry for an inode not yet written. xv6's log writes
 * the blocks of a change twice, first to a place apart with a mark
 * that says the set is whole, and replays them at the boot. Here a
 * card pulled out while writing may need mini-mkfs again.
 *
 * References: the xv6 book's chapter on the file system (Russ Cox,
 * Frans Kaashoek and Robert Morris, MIT). D. M. Ritchie and K.
 * Thompson, "The UNIX Time-Sharing System" (CACM, 1974), its
 * section on the file system's implementation. M. K. McKusick and
 * others, "A Fast File System for UNIX" (1984), for what came
 * next. *)

type t

type kind = Dir | File | Device

(* the file system of a device, given how to read it ([read at n]) and
 * how to write it (None: only read); Failure when it is not one *)
val make : (int -> int -> string) -> (int -> string -> unit) option -> t
(* a new, empty one written on a device: so many blocks of a size (512
 * or 1024), so many inodes *)
val format : (int -> int -> string) -> (int -> string -> unit) -> int -> int -> int -> t

(* the root directory's inode *)
val root : int
val kind : t -> int -> kind
val size : t -> int -> int

(* a directory's names with their inodes (not "." and ".."); one name's *)
val entries : t -> int -> (string * int) list
val lookup : t -> int -> string -> int option

val read : t -> int -> int -> int -> string
(* bytes written at an offset (past the end: zeros between) *)
val write : t -> int -> int -> string -> unit
val truncate : t -> int -> unit
(* when a file was last written, seconds since 1970 (0: not known): the
 * caller's to say, at a write too (ix's extension) *)
val mtime : t -> int -> int
val set_mtime : t -> int -> int -> unit
(* a new file or directory of a name in a directory: its inode *)
val create : t -> int -> string -> kind -> int
(* a name taken out of a directory, its file with it when it was the
 * last (a directory: when it is empty) *)
val remove : t -> int -> string -> unit
(* a name of a directory changed for another, which must not be there *)
val rename : t -> int -> string -> string -> unit
