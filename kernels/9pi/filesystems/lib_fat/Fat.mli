(* A FAT file system on a device (a partition, an image): MS-DOS's, in
 * its three sizes (FAT12, FAT16, FAT32), with VFAT's long names, read
 * and written (plan_rio.md). What knows a FAT is here once, for a
 * program (mini-dossrv, ../user/dossrv: a file server) and for the
 * kernel (Kdos: a device); how the device's bytes are read and
 * written is the caller's. It keeps to what the compilers of both
 * have.
 *
 * On the disk: a boot sector that says the geometry; the FAT, a table
 * with a number a cluster, the next cluster of its file (twice); the
 * root directory (FAT12 and 16: a place of its own; FAT32: a file like
 * another); then the clusters. A directory is entries of 32 bytes: a
 * name of 8 and 3 characters, attributes, a date, the first cluster,
 * the length; a long name is in the entries before its file's, 13
 * characters each, the last part first.
 *
 * What fails raises Failure, with words for the user ("file does not
 * exist"). Each change is written at once, the table after the data:
 * no cache to lose, and an order that leaves at worst clusters taken
 * by no file. Not here: the free count FAT32
 * keeps beside its table (fsck says it is stale, and mends it).
 *
 *     | boot sector | FAT | FAT (copy) | root directory | clusters ... |
 *
 *     the directory's entry             the FAT, a number a cluster
 *     CONFIG  TXT  first 5, 9000 bytes  5: 6   6: 9   9: end
 *                                       7: 0 (free)   8: 0 (free)
 *
 *     with clusters of 4096 bytes, the file is clusters 5, 6, 9: its
 *     byte 5000 is in the second one, 6, at 904
 *
 * The table gave the format its name (file allocation table) and is
 * its whole idea: a file is a chain, and the chain is not in the
 * file's blocks but beside them, in one array small enough to keep
 * in memory. The 12, 16 and 32 are the bits of a table's number,
 * so how many clusters a volume may have.
 *
 * design:
 * A chain and an entry, against Unix's inode (Xv6fs). Finding the
 * place of byte n walks the chain from the start, where an inode's
 * list of blocks is indexed; a file's size, date and first cluster
 * are in its directory's entry, so a file has one name and no hard
 * link, where an inode is a file with no name and any number of
 * them; and there is no owner and no rwx, only a read-only bit. In
 * exchange a FAT is read in a hundred lines, by a boot ROM.
 *
 * cs-history:
 * The table is from Microsoft's Standalone Disk BASIC (1977, Marc
 * McDonald), on 8-inch floppies; Tim Paterson took it for 86-DOS
 * (1980), which became MS-DOS, with 12-bit numbers. 16 bits came
 * with hard disks (1984), long names with Windows 95 (1995), hidden
 * in entries old systems skip, and 32 bits the year after. (All
 * from memory.)
 *
 * why-win:
 * It is the format everything reads, because it asks so little:
 * cameras, the firmware of PCs (UEFI's system partition is a FAT)
 * and of the Raspberry Pi, which finds the kernel as a file of the
 * card's first, FAT, partition. That is why mini-9pi has it at all:
 * it is where the kernel itself comes from. *)

type t

(* a file or a directory, from its entry: its long name if it has one;
 * [where] is its entry's place on the disk (in entries of 32 bytes),
 * its identity for a server; [longs] the places of its long name's
 * entries *)
type entry = { name : string; is_dir : bool; read_only : bool; first : int; size : int; mtime : float; where : int; longs : int list }

(* the file system of a device, given how to read it ([read at n]: n
 * bytes at an offset, fewer at its end) and how to write it ([write at
 * bytes]; None: it is only read); Failure when it is not a FAT *)
val make : (int -> int -> string) -> (int -> string -> unit) option -> t
(* the time now, seconds since 1970, for what is written (the caller
 * says how: a kernel and a program do not ask the same) *)
val clock : (unit -> float) ref

val root : t -> entry
(* a directory's entries (not "." and "..") *)
val entries : t -> entry -> entry list
(* an entry as it is on the disk now (its length, its first cluster:
 * another holder of the file may have written it) *)
val refresh : t -> entry -> entry
(* a file's bytes: an offset, a count *)
val read : t -> entry -> int -> int -> string

(* bytes written in a file at an offset (past its end: zeros between);
 * the file's entry after *)
val write : t -> entry -> int -> string -> entry
(* a file emptied *)
val truncate : t -> entry -> entry
(* a new file, or directory, of a name in a directory *)
val create : t -> entry -> string -> bool -> entry
(* a file, or an empty directory, taken away *)
val remove : t -> entry -> unit
(* a file's name changed for another of its directory's (given first),
 * which no other file has: its entry after, at another place *)
val rename : t -> entry -> entry -> string -> entry
(* a file's time written set (seconds since 1970, to FAT's two
 * seconds); a file made one that is only read, or not *)
val set_mtime : t -> entry -> float -> entry
val set_read_only : t -> entry -> bool -> entry
