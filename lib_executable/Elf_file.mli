(* This module reads back an ELF executable (plan_debugger.md, stage
 * 8a): Linux's, gcc's, and mini-ld's -H6 and -H7, in 32 or 64 bits,
 * little-endian. It reads what a debugger needs: where the text and
 * data are (the program headers' loads), the sections by name, and the
 * symbol table with Plan 9's letters (Symbols.sym), so that mini-nm and
 * mini-acid read it as they read an a.out:
 *
 *     ELF header      its class (32, 64), machine, entry, and where
 *                     the two tables are
 *     program headers the segments the loader maps (PT_LOAD): an
 *                     address, a file's offset, sizes, rwx
 *     sections        .text .data .bss .symtab .strtab .debug_line...
 *                     each with a name, a type, an address, an offset
 *
 * An entry of .symtab has a name (an offset in .strtab), a type (a
 * function, an object), a binding (local, global) and a section. Its
 * letter is nm's: T for a function, D or B for an object (B in a
 * section with no bytes, .bss), in lower case when it is local. nm's
 * r (read-only) and W (weak) are D or T here, since Plan 9 has no such
 * letters. An undefined entry (a shared library's) is left out.
 *
 * others:
 * Plan 9's a.out has one table of its own after the data, and no
 * sections: the linker writes names and lines only for the debugger.
 * ELF (System V, 1988) is a container of sections, and a linker, a
 * loader and a debugger each read their part of it. DWARF's lines and
 * types are sections too.
 *
 * References: the System V ABI, "Object Files" (gabi41); elf(5). *)

type section = { sname : string; styp : int; sflags : int; addr : int; offset : int; size : int; link : int; entsize : int }
(* a PT_LOAD: pflags 1 x, 2 w, 4 r *)
type segment = { vaddr : int; foffset : int; filesz : int; memsz : int; pflags : int }

type t = { bits : int; machine : int; entry : int; sections : section list; segments : segment list }

(* whether a file's bytes are an ELF's (little-endian) *)
val is_elf : string -> bool

(* the file's headers, from its bytes *)
val read : string -> t option

(* a section by its name *)
val section : t -> string -> section option

(* a section's bytes, from the file's bytes ("" for .bss) *)
val bytes : string -> section -> string

(* an address's offset in the file, if a load maps it from the file *)
val file_offset : t -> int -> int option

(* the load that is code (x), and the one that is data (w, not x) *)
val text_segment : t -> segment option
val data_segment : t -> segment option

(* .symtab's functions and objects, with nm's letters, from the file's
 * bytes; none if the program was stripped *)
val symbols : string -> t -> Symbols.sym list
