(* This module reads back DWARF's line table (.debug_line, versions 2
 * to 5). It is what the programs of gcc and clang say of an address's
 * file and line, as Plan 9's pc/line table does (Symbols). mini-acid
 * uses it for pcfile, pcline, filepc, src and next on a program of this
 * machine (plan_debugger.md, stage 8a).
 *
 * The table is not a table but a program. Each compilation unit has a
 * header (the files' names, the constants of its encoding) and a
 * sequence of opcodes for a small machine. The machine's registers are
 * an address, a file, a line, and whether the address begins a
 * statement. An opcode changes them, and can emit a row:
 *
 *     set address 0x758       (an extended opcode: the sequence's start)
 *     advance line by 26      line 27
 *     copy                    a row: 0x758 target.c:27
 *     special 34              address += 8, line += 1: 0x760 :28
 *     ...
 *     end sequence            a row that ends: the function's end
 *
 * A special opcode does both in one byte, using the header's line_base
 * and line_range. It covers the commonest case: a few instructions
 * and a line or two. Version 5 (gcc 11's default) describes its
 * directories and files by formats, each one a field and a form: a
 * name inline, or an offset in .debug_line_str.
 *
 * Plan 9's 5l writes the same thing in less space: one byte holds a
 * pc's step and a line's change together (Symbols). But it has no
 * columns and no statements, and a file is found through the
 * history.
 *
 * References: the DWARF 5 standard (2017), section 6.2; DWARF 2 (1993),
 * which has the same machine. *)

type row = {
  addr : int;
  file : string;     (* joined to its directory's path *)
  line : int;
  stmt : bool;       (* the address begins a statement *)
  last : bool;       (* a sequence's end, at the address just after it *)
}

(* the rows, by address *)
type t = row array

(* an ELF's line table, if it has one (the string is the file's bytes) *)
val read : string -> Elf_file.t -> t option

(* the file and line of an address *)
val file_line : t -> int -> (string * int) option

(* the first address of a line that begins a statement; the file is
 * named by its path or by its last components *)
val file_pc : t -> string -> int -> int option
