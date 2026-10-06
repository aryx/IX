(* The directory (Oberon's FileDir): the files by their names, one flat
 * list of them, as Oberon's is.
 *
 * Oberon's own is a B-tree of names on the disk's sectors, and a file
 * a header and its sectors (FileDir.Mod, Files.Mod: 857 lines, a
 * chapter of the book). Here the disk is a text one can read, made by
 * the mkfile and put in the kernel's image:
 *
 *     Oberon10.Scn.Fnt 2284
 *     ...the file's 2284 bytes...
 *     System.Tool 560
 *     ...
 *
 * a line with a file's name and its length, the file's bytes, the next
 * line; an empty line ends it. The files are read from it once, at the
 * boot, and live in memory: what is written is lost when the machine
 * stops (plan_system_oberon.md: Oberon's own format is a later stage). *)

(* a file: its bytes, the first [length] of [data] *)
type file = { name : string; mutable data : Bytes.t; mutable length : int }

(* the disk's files read (the boot's) *)
val init : unit -> unit

val find : string -> file option
(* under its name, in the place of the one that had it *)
val insert : file -> unit
val delete : string -> unit
(* each file, in the order of the names *)
val enumerate : (file -> unit) -> unit
