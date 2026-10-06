(* xv6's file system on a device (a partition, an image): the one a
 * first course on kernels reads (xv6's fs.c; ix's mini-xv6 has it on a
 * RAM disk: kernel/xv6's Fs), here over a device's bytes, for
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
 * kernel/xv6's Fs has the same extension). In Xv6fs.ml each line of
 * it is marked "ix's extension".
 *
 * No log, no cache of blocks: each change is written at once, as
 * lib_fat's. What fails raises Failure. *)

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
(* a new file or directory of a name in a directory: its inode *)
val create : t -> int -> string -> kind -> int
(* a name taken out of a directory, its file with it when it was the
 * last (a directory: when it is empty) *)
val remove : t -> int -> string -> unit
