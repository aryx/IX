(* Plan 9's symbol table and pc/line table, written after an a.out's
 * data (5l's asmsym and asmlc; principia's debuggers/libmach reads
 * them). A trace, a debugger and a profiler use them to name an address
 * (plan_debugger.md, stage 1).
 *
 * The symbol table is a list of entries. Each entry has a value (4
 * bytes, big-endian), a type (a letter, with 0x80 added), a name and
 * the name's NUL:
 *
 *     T 00001078 etext        the text's end
 *     D 00002000 hello        a data's address (B: a bss's)
 *     f 00000001 /            a component of a file's path, numbered
 *     f 00000002 tmp            (the history's names, below)
 *     z 00000001 /1/2/8       a file starts at global line 1: its path
 *     z 00000026              as its components' numbers; it ends at 38
 *     T 00001020 _main        a function (L: a leaf), a t, d or b: static
 *     m 00000018 .frame       its frame, the return address's word too
 *     p 00000004 x            a parameter, x+4(FP); a: a local, y-8(SP)
 *
 * etext comes first, then the data, the bss and the files, in the order
 * of the linker's hash table (Link.bucket: each bucket newest first, as
 * in the data's layout). Then come the functions in the text's order,
 * with the history of each object before the object's first function.
 *
 * A line number is global: it counts over all of an object's files as
 * its assembler or compiler read them, with each #include's lines
 * inside its includer's. So once the history is read, one number gives
 * both a file and a line. The pc/line table gives each instruction's
 * line, as a difference from the one before, mostly in one byte:
 *
 *     1 .. 64      the line goes up by n        (then the pc by 4)
 *     65 .. 128    the line goes down by n - 64
 *     129 .. 255   the pc goes up by 4 * (n - 128), the line stays
 *     0 + 4 bytes  the line moves by more than 64, either way
 *
 * Only a change of line is written, so a function of 50 instructions on
 * 10 lines costs about 20 bytes. A literal pool's words have line 0.
 *
 * design:
 * There are two tables for two questions: which function an address is
 * in (the symbols, sorted by value), and which line it is at (the
 * pc/line table, walked from the start). Go's runtime has the same two
 * tables, grown from these (its pclntab, from 2009 to 2014). A Go
 * program prints its own symbolic traces with them, and stage 5a of
 * plan_debugger.md does the same here.
 *
 * References: Plan 9's a.out(6), symbol(2) and mach(2); principia's
 * linkers/5l (debugging.c) and debuggers/libmach (sym.c). *)

(* the symbol table's bytes *)
val symbols : 'm Program.t -> string

(* the pc/line table's bytes *)
val lines : 'm Program.t -> string

(* ELF's symbols (-g with -H7: Exe's .symtab), sorted by value.
 * Each has a name, its value, its size (for a data object), whether it
 * is a function, and whether it is global (a name<> is local to its
 * object). *)
val elf_symbols : 'm Program.t -> (string * int * int * bool * bool) list
