(* DWARF's line table read back (.debug_line, versions 2 to 5): what
 * gcc's and clang's programs say of an address's file and line, as Plan
 * 9's pc/line table does (Symbols), for mini-acid's pcfile, pcline,
 * filepc, src and next on a program of this machine (plan_debugger.md,
 * stage 8a).
 *
 * The table is not a table but a program: each compilation unit has a
 * header (the files' names, the constants of its encoding) and a
 * sequence of opcodes for a small machine, whose registers are an
 * address, a file, a line, and whether the address begins a statement;
 * an opcode moves them and emits a row:
 *
 *     set address 0x758       (an extended opcode: the sequence's start)
 *     advance line by 26      line 27
 *     copy                    a row: 0x758 target.c:27
 *     special 34              address += 8, line += 1: 0x760 :28
 *     ...
 *     end sequence            a row that ends: the function's end
 *
 * A special opcode does both in one byte (the commonest case: a few
 * instructions, a line or two), from line_base and line_range, the
 * header's. Version 5 (gcc 11's default) describes its directories and
 * files by formats, each a field and a form: a name inline, or an
 * offset in .debug_line_str.
 *
 * Plan 9's 5l writes the same thing smaller: one byte for a pc's step
 * and a line's change together (Symbols), but no columns, no
 * statements, and a file found through the history.
 *
 * References: the DWARF 5 standard (2017), section 6.2; DWARF 2 (1993),
 * the same machine. *)

type row = {
  addr : int;
  file : string;     (* its directory's path joined *)
  line : int;
  stmt : bool;       (* the address begins a statement *)
  last : bool;       (* a sequence's end: the address after it *)
}

(* the rows, by address *)
type t = row array

(* an ELF's line table (file its bytes), if it has one *)
val read : string -> Elf_file.t -> t option

(* the file and line of an address *)
val file_line : t -> int -> (string * int) option

(* the first address of a line that begins a statement, its file named
 * by its path or its last components *)
val file_pc : t -> string -> int -> int option
