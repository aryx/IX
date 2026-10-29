(* An a.out's symbol table and pc/line table, read back (principia's
 * debuggers/libmach, sym.c: syminit, fileline, pc2line, fileelem): what
 * mini-nm lists and what names an address, a function and an offset,
 * a file and a line (plan_debugger.md, stage 2). The tables' format is
 * the linker's, said in linker/Symtab.mli.
 *
 * An address to its name and line, in three steps:
 *
 *     0x10b4c   the text symbol at or before it      Tar.main+0x2c
 *               the pc/line table walked to it       global line 412
 *               the history of the function's        Tar.ml:412
 *               object: which file, which line in it
 *
 * The history is what makes one number a file and a line. Each object
 * counts its lines once over its files, an #include's lines inside its
 * includer's, and says where each file starts and ends:
 *
 *     z 1   a.c        line 1 of the count is a.c's 1
 *     z 10  u.h        a.c's #include at its line 10: u.h from 10
 *     z 40             u.h ends: 30 lines; global 50 is a.c's 20
 *     z 80             a.c ends
 *
 * so a line is found by walking the history to it, a stack of the
 * files open there (libmach's fline, recursive; here a list).
 *
 * Written with ocaml-light's library only: mini-9pi's kernel reads its
 * processes' tables (plan_debugger.md, stage 4).
 *
 * References: Plan 9's symbol(2) and a.out(6); principia's
 * debuggers/libmach/sym.c. *)

(* an entry: its value, its letter (the 0x80 taken off), its name (a
 * path's, z: its files' numbers, as the table has them) *)
type sym = { value : int; typ : char; name : string }

type t = {
  syms : sym list;          (* in the table's order *)
  text_start : int;         (* the first instruction's address *)
  text_end : int;
  lines : string;           (* the pc/line table's bytes *)
}

(* the tables of an a.out for arm, from [read off len], its bytes from
 * off (fewer at its end): its header and its tables only, not its
 * text and data (a kernel's read of a dying process's file); None
 * when it is none, or has no symbol table (-s) *)
val read_with : (int -> int -> string) -> t option

(* the same from the file's bytes *)
val read : string -> t option

(* a z entry's path: its components joined, cleaned (libmach's fileelem) *)
val path : t -> sym -> string

(* the function an address is in, and the offset in it *)
val func : t -> int -> (string * int) option

(* the file and the line of an address, when the table has them *)
val file_line : t -> int -> (string * int) option
