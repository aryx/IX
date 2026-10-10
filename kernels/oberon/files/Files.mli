(* Files and riders (Oberon's Files): a file is found by its name
 * (old) or made without one in the directory (new_), which register
 * gives it; it is read and written through a rider, a position in it.
 * A rider past the end reads 0 and says eof.
 *
 *     let f = Files.new_ "Notes.Text" in      a file, in no directory
 *     let w = Files.set f 0 in                a rider at its start
 *     Files.write_string w "abc";             a b c 0, w.pos = 4
 *     let r = Files.set f 1 in                another rider, at 1
 *     Files.read r = 'b'
 *     Files.register f                        now old "Notes.Text"
 *                                             finds it
 *
 * design:
 * The position is not the file's. Unix's open file has one offset,
 * shared by all who inherited the descriptor, and a program that
 * wants two places in a file opens it twice or seeks back and
 * forth. Wirth split the two: a file is the bytes, a rider a place
 * in them, and there are as many riders as one wants. A text's
 * pieces (Texts) are riders that are never moved: a file, a
 * position, a length.
 *
 * design:
 * A new file has no name in the directory until it is registered:
 * a program writes the whole file, then gives it its name in one
 * step, the old file of that name staying whole until then. On
 * Unix the same is done by writing a temporary name and renaming
 * it. A file never registered is gone when nothing holds it: the
 * collector's work here, as in Oberon.
 *
 * References: "Project Oberon", chapter 7, "The file system" (its
 * section on files and riders); Files.Mod of Project Oberon 2013. *)

type t = FileDir.file

val old : string -> t option
val new_ : string -> t
val register : t -> unit
val length : t -> int

type rider = { file : t; mutable pos : int; mutable eof : bool }

val set : t -> int -> rider
val read_byte : rider -> int
val read : rider -> char
(* 4 bytes, the low one first, signed *)
val read_int : rider -> int
(* the bytes up to a zero, which is read *)
val read_string : rider -> string
val write_byte : rider -> int -> unit
val write : rider -> char -> unit
val write_int : rider -> int -> unit
(* its bytes, then a zero *)
val write_string : rider -> string -> unit

(* in the directory: a file's name changed (false: no such file), a file out of it *)
val rename : string -> string -> bool
val delete : string -> unit
