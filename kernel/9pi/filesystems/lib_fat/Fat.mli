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
 * by no file. Not here: a file's name changed, the free count FAT32
 * keeps beside its table (fsck says it is stale, and mends it). *)

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
