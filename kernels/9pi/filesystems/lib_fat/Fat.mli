(* A FAT file system on a device (a partition, an image): MS-DOS's file
 * system, in its three sizes (FAT12, FAT16, FAT32), with VFAT's long
 * names, read and written (plan_rio.md). What knows a FAT is here
 * once, for a program (mini-dossrv, ../user/dossrv, a file server) and
 * for the kernel (Kdos, a device); how the device's bytes are read and
 * written is left to the caller. It uses only what the compilers of
 * both have.
 *
 * On the disk there is:
 * - a boot sector, which gives the geometry;
 * - the FAT, a table with one number per cluster, the next cluster of
 *   its file (the table is there twice);
 * - the root directory (with FAT12 and 16 it has a place of its own;
 *   with FAT32 it is a file like another);
 * - then the clusters.
 * A directory is made of entries of 32 bytes: a name of 8 and 3
 * characters, attributes, a date, the first cluster and the length. A
 * long name is in the entries before its file's entry, 13 characters
 * in each, the last part first.
 *
 * What fails raises Failure, with words for the user ("file does not
 * exist"). Each change is written at once, the table after the data:
 * there is no cache to lose, and that order leaves at worst clusters
 * taken by no file. What is not here is the free count that FAT32
 * keeps beside its table (fsck says it is stale, and mends it).
 *
 *     | boot sector | FAT | FAT (copy) | root directory | clusters ... |
 *
 *     the directory's entry             the FAT, a number per cluster
 *     CONFIG  TXT  first 5, 9000 bytes  5: 6   6: 9   9: end
 *                                       7: 0 (free)   8: 0 (free)
 *
 *     with clusters of 4096 bytes, the file is clusters 5, 6 and 9:
 *     its byte 5000 is in the second one, 6, at 904
 *
 * The table gave the format its name (file allocation table) and is
 * its whole idea: a file is a chain, and the chain is not in the
 * file's blocks but beside them, in one array small enough to keep in
 * memory. The 12, 16 and 32 are the bits of a number in the table, so
 * they say how many clusters a volume may have.
 *
 * design:
 * A FAT has a chain and an entry, where Unix has the inode (Xv6fs).
 * Finding the place of byte n walks the chain from the start, where an
 * inode's list of blocks is indexed. A file's size, date and first
 * cluster are in its directory's entry, so a file has one name and no
 * hard link, where an inode is a file with no name and any number of
 * names. And there is no owner and no rwx, only a read-only bit. In
 * exchange, a boot ROM can read a FAT in a hundred lines.
 *
 * cs-history:
 * The table is from Microsoft's Standalone Disk BASIC (1977 or 1978,
 * by Marc McDonald), on 8-inch floppies. Tim Paterson took it for
 * 86-DOS (1980), which became MS-DOS, with 12-bit numbers. 16 bits
 * came with hard disks (1984); long names came with Windows NT 3.5
 * (1994) and Windows 95, hidden in entries that old systems skip; and
 * 32 bits came in 1996.
 *
 * why-win:
 * It is the format everything reads, because it asks so little:
 * cameras, the firmware of PCs (UEFI's system partition is a FAT)
 * and the firmware of the Raspberry Pi, which finds the kernel as a
 * file of the card's first partition, a FAT one. That is why mini-9pi
 * has it at all: it is where the kernel itself comes from. *)

type t

(* a file or a directory, read from its entry. [name] is its long name
 * if it has one. [where] is its entry's place on the disk (counted in
 * entries of 32 bytes), which is its identity for a server. [longs]
 * are the places of its long name's entries. *)
type entry = { name : string; is_dir : bool; read_only : bool; first : int; size : int; mtime : float; where : int; longs : int list }

(* the file system of a device, given how to read it ([read at n]
 * reads n bytes at an offset, fewer at its end) and how to write it
 * ([write at bytes], or None when it is only read). It raises Failure
 * when the device is not a FAT. *)
val make : (int -> int -> string) -> (int -> string -> unit) option -> t
(* the time now, in seconds since 1970, for what is written. The caller
 * says how to get it, because a kernel and a program do not ask the
 * same way. *)
val clock : (unit -> float) ref

val root : t -> entry
(* a directory's entries, without "." and ".." *)
val entries : t -> entry -> entry list
(* an entry as it is on the disk now: another holder of the file may
 * have changed its length or its first cluster by writing it *)
val refresh : t -> entry -> entry
(* [read t e off n] reads n bytes of a file at an offset *)
val read : t -> entry -> int -> int -> string

(* writes bytes in a file at an offset (past its end, zeros fill the
 * gap), and returns the file's entry afterwards *)
val write : t -> entry -> int -> string -> entry
(* empties a file *)
val truncate : t -> entry -> entry
(* makes a new file, or directory, with a name in a directory *)
val create : t -> entry -> string -> bool -> entry
(* removes a file, or an empty directory *)
val remove : t -> entry -> unit
(* changes a file's name for another name in its directory (the
 * directory is given first), one that no other file has. It returns
 * the file's entry afterwards, which is at another place. *)
val rename : t -> entry -> entry -> string -> entry
(* sets the time a file was written (in seconds since 1970, kept to
 * FAT's two seconds); makes a file read only, or not *)
val set_mtime : t -> entry -> float -> entry
val set_read_only : t -> entry -> bool -> entry
