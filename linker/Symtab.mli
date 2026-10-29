(* Plan 9's symbol table and pc/line table, written after an a.out's
 * data (5l's asmsym and asmlc, principia's debuggers/libmach reads
 * them): what a trace, a debugger and a profiler name an address by
 * (plan_debugger.md, stage 1).
 *
 * The symbol table is entries, each a value (4 bytes, big-endian), a
 * type (a letter, 0x80 added), a name and its NUL:
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
 * etext first, then the data, the bss and the files in the order of
 * the linker's hash (Link.bucket: each bucket newest first, as the
 * data's layout), then each function in the text's order, the history
 * of its object before the object's first one.
 *
 * A line is global: counted over an object's files as its assembler
 * or compiler read them, each #include's lines inside its includer's,
 * so one number says a file and a line once the history is read. The
 * pc/line table gives each instruction's, as differences from the one
 * before, a byte each mostly:
 *
 *     1 .. 64      the line goes up by it       (then the pc by 4)
 *     65 .. 128    down by n - 64
 *     129 .. 255   the pc up by 4 * (n - 128), the line as it is
 *     0 + 4 bytes  the line by more than 64, either way
 *
 * Only a change of line is written: a function of 50 instructions on
 * 10 lines costs some 20 bytes. A literal pool's words have line 0.
 *
 * design:
 * Two tables for two questions: which function is this address in
 * (the symbols, sorted by value), and which line (the pc/line table,
 * walked from the start). Go's runtime has the same two, grown from
 * these (its pclntab, 2009 to 2014): a Go program prints its own
 * symbolic traces with them, and stage 5a here is that.
 *
 * References: Plan 9's a.out(6), symbol(2) and mach(2); principia's
 * linkers/5l (debugging.c) and debuggers/libmach (sym.c). *)

(* the symbol table's bytes *)
val symbols : 'm Program.t -> string

(* the pc/line table's bytes *)
val lines : 'm Program.t -> string
