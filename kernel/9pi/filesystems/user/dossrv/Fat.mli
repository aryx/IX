(* A FAT file system read from a device's file (a partition, an image):
 * MS-DOS's, in its three sizes (FAT12, FAT16, FAT32), with VFAT's long
 * names. Reading only, for now (plan_rio.md, stage 5).
 *
 * On the disk: a boot sector that says the geometry; the FAT, a table
 * with a number a cluster, the next cluster of its file (twice); the
 * root directory (FAT12 and 16: a place of its own; FAT32: a file like
 * another); then the clusters. A directory is entries of 32 bytes: a
 * name of 8 and 3 characters, attributes, a date, the first cluster,
 * the length; a long name is in the entries before its file's, 13
 * characters each, the last part first. *)

type t

(* a file or a directory, from its entry: its long name if it has one;
 * [where] is its entry's place on the disk (in entries of 32 bytes),
 * its identity for a server *)
type entry = { name : string; is_dir : bool; read_only : bool; first : int; size : int; mtime : float; where : int }

(* the file system of a device's descriptor; Failure when it is not a FAT *)
val of_fd : Unix.file_descr -> t
val root : t -> entry
(* a directory's entries (not "." and "..") *)
val entries : t -> entry -> entry list
(* a file's bytes: an offset, a count *)
val read : t -> entry -> int -> int -> string
