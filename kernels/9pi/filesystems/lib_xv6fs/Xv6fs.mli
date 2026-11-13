(* xv6's file system on a device (a partition, an image). It is the
 * one a first course on kernels reads (xv6's fs.c; ix's mini-xv6 has
 * it on a RAM disk, in kernels/xv6's Fs). Here it is over a device's
 * bytes, for mini-9pi's card (its second partition) and for the tool
 * that makes the card's image (mini-mkfs). As with lib_fat, how the
 * device is read and written is left to the caller, and it uses only
 * what the kernel's compiler has.
 *
 * On the disk (in blocks of 512 or 1024 bytes) there is:
 * - a boot block;
 * - the superblock, which says where the rest is;
 * - the inodes, 256 bytes each: a type, a count of names, a size, and
 *   the numbers of the file's blocks (58 direct, then a block of
 *   numbers);
 * - a bitmap, with one bit per block, set when the block is taken;
 * - the blocks.
 * A directory is a file of entries of 16 bytes: an inode's number and
 * a name of 14 characters at most (64 bytes and 62 characters here:
 * see below). A file is its inode's number: names are only in
 * directories.
 *
 * The format is xv6-multiarch's, with ONE EXTENSION OF IX'S, not
 * xv6's: a second block of numbers, whose numbers are of blocks of
 * numbers (xv6's exercise "large files"). Its own number is in the 8
 * bytes of the inode that xv6 leaves unused (at byte 8). Without it a
 * file has 314 KB at most, less than one of ix's programs; with it, a
 * file can have 64 MB. A file made larger than xv6's limit is one
 * that xv6 cannot read whole (ix's mini-xv6 can, because kernels/xv6's
 * Fs has the same extension). In Xv6fs.ml each line of it is marked
 * "ix's extension". There is A SECOND ONE, smaller: the time a file was
 * last written, in the 4 bytes after (at byte 12; 0, as xv6 leaves
 * them, means not known). xv6 keeps no time and no permissions, and
 * there is no place left for those. There is A THIRD ONE: directory
 * entries of 64 bytes, with names of 62 characters (a fifth of ix's
 * sources have names longer than 14, such as Out_channel.mli; see
 * docs/plans/plan_self_hosting.md). Because of it, xv6's own images
 * can no longer be read, nor can ix's be read by xv6: the format has
 * xv6's layout, but it is ix's (the author: "there is no need to
 * remain backward compatible with the actual xv6 filesystem").
 *
 * There is no log and no cache of blocks: each change is written at
 * once, as in lib_fat. What fails raises Failure.
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
 * The inode is the file; a directory only gives it names. So one file
 * may have several names (links, counted in the inode: the file goes
 * away when the count is 0), a rename changes one entry, and finding
 * the n-th block of a file is one lookup in the inode's list, or two
 * through the block of numbers. The inodes' and the root's numbers
 * above are only an example.
 *
 * cs-history:
 * This is the Unix file system of 1974 nearly unchanged. It has Ken
 * Thompson's inodes, and a directory is a file of 16-byte entries (two
 * bytes of inode number and 14 of name: that limit lasted until
 * Berkeley's fast file system, in 1983). Unix had a list of free
 * blocks where xv6 has a bitmap. xv6 (MIT, 2006) rewrote the sixth
 * edition's kernel for today's C and processors, to teach from, as
 * John Lions had taught from the original; it added a log, which this
 * version leaves out.
 *
 * wib:
 * Without a log, a crash between two writes of one change leaves the
 * disk wrong: a block is marked taken that no file has, or, worse, a
 * directory has an entry for an inode not yet written. xv6's log
 * writes the blocks of a change twice, first to a separate place with
 * a mark that says the set is whole, and it replays them at boot. Here
 * a card pulled out while writing may need mini-mkfs again.
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
 * how to write it (None when it is only read). It raises Failure when
 * the device does not hold one. *)
val make : (int -> int -> string) -> (int -> string -> unit) option -> t
(* [format read write blocks size inodes] writes a new, empty file
 * system on a device, with that many blocks of that size (512 or 1024)
 * and that many inodes *)
val format : (int -> int -> string) -> (int -> string -> unit) -> int -> int -> int -> t

(* the root directory's inode *)
val root : int
val kind : t -> int -> kind
val size : t -> int -> int

(* a directory's names with their inodes, without "." and ".."; and
 * the inode of one name *)
val entries : t -> int -> (string * int) list
val lookup : t -> int -> string -> int option

val read : t -> int -> int -> int -> string
(* writes bytes at an offset (past the end, zeros fill the gap) *)
val write : t -> int -> int -> string -> unit
val truncate : t -> int -> unit
(* when a file was last written, in seconds since 1970 (0 means not
 * known). The caller sets it, at a write too (ix's extension). *)
val mtime : t -> int -> int
val set_mtime : t -> int -> int -> unit
(* makes a new file or directory with a name in a directory, and
 * returns its inode *)
val create : t -> int -> string -> kind -> int
(* takes a name out of a directory, and the file with it when that was
 * its last name (a directory's name is taken out only when the
 * directory is empty) *)
val remove : t -> int -> string -> unit
(* changes a name of a directory for another, which must not be there *)
val rename : t -> int -> string -> string -> unit
