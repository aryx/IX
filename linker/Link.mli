(* The linker's general part: the symbols, the objects and libraries
 * a program needs, the data's layout, the branches' targets, and the
 * bytes of the data -- everything that does not look inside an
 * instruction. The machine modules (Arm, Arm64) lay the code out and
 * encode it; Exe writes the file, in its formats (ELF, Plan 9's
 * a.out, Mach-O).
 *
 *     load (objects, libraries) -> resolve (branches) -> layout_data
 *       -> Arm.rewrite -> Arm.layout (pcs, pools) -> Arm.encode -> Exe.write
 *
 * (CLI.mli has every pass, in order.)
 *
 * {b A symbol} is a name and what is known of it so far (Program's
 * sym). It starts Undefined, the first time any object names it; a
 * TEXT makes it Text, a GLOBL Bss, a DATA on it Data. Linking
 * hello.5, which calls print, with a libc.a of three members:
 *
 *                       defines        names
 *     hello.5           main           print
 *     libc.a: print.5   print          write, buf
 *             write.5   write
 *             atoi.5    atoi
 *
 *     the entry asked for (-E main)            main: Undefined
 *     hello.5 read       main: Text            print: Undefined
 *     the library, once  print.5 defines print: taken
 *                        print: Text  write: Undefined  buf: Bss
 *     the library, again write.5 defines write: taken
 *     again              nothing is wanted: done. atoi.5 is not in
 *                        the program.
 *
 * A library is so a set from which what is needed is drawn, an
 * object given on the line is taken whole: the reason libc is a
 * library of many small objects, a function a file. What is still
 * Undefined when a branch to it is resolved is the error
 * (hello.c:0: undefined: print).
 *
 * {b name<>}, a name with <> after it in the assembly (C's static),
 * is its object's own: the table's key is the name and a version, 0
 * for the names all share, the object's number for its own, so two
 * files may each have a tmp<> without meeting.
 *
 * {b The data's layout} ([layout_data]). The code reaches a global
 * by an offset from a register that holds one fixed address in the
 * data (R12 on arm, 4092 bytes after the data's start), and an
 * instruction's offset is 12 bits and a sign: what is within 4095
 * bytes of R12, the data's first 8 KB, costs one instruction, the
 * rest a second, and a word of a literal pool. Hence the order:
 *
 *     data_start
 *     | small ones, 64 bytes or less  | the rest with  |  the rest
 *     | (initialized or not)          | DATAs          |  without
 *     '---------- in the file: data_size --------------'-- bss_size --
 *
 * The small variables, which are the many, are near the register;
 * the large arrays are far, where the second instruction is lost in
 * the loop that walks them.
 *
 * {b Why the linker encodes} (the plan's decision 1, and Asm.ml): it
 * does so after the whole program is laid out, so an address is known
 * whenever a word is made -- no relocations in the objects or here;
 * one encoder per machine, shared by the assembler's path and (next)
 * the compiler's; the choices that depend on distances (a literal
 * pool or not, a long branch or not) made once, knowing them; and the
 * machine confined to its module.
 *
 * Names: each function says which of 5l's (goken's linkers/5l, as the
 * Principia book documents it) and of xix's (linker/) it corresponds
 * to, so either can be found from here.
 *
 * References: Ken Thompson, "Plan 9 C Compilers" (Summer 1990 UKUUG
 * Conference), its section "The loader": external data allocated
 * "with the smallest variables allocated first", written for the
 * MIPS, whose loads reach +-32K from R30 ([layout_data], for arm's
 * R12; the same section's reordering of the code is Follow's, which
 * quotes it); Leon Presser and John R. White,
 * "Linkers and Loaders" (ACM Computing Surveys, 1972), the classic
 * survey, which splits the job into allocation, linking, relocation
 * and loading -- here [layout_data] allocates, [load] and [resolve]
 * link, relocation has no pass of its own (the encoder writes final
 * addresses), and loading is the kernel's exec; John R. Levine,
 * Linkers and Loaders (2000), for archives and their symbol index, and
 * the one scan of Unix's ld that makes the order of libraries matter,
 * where [load] scans them all again until nothing new is defined.
 *
 * others:
 * A weak name. C's toolchains have "weak symbols", a definition
 * that gives way to another, or a reference that may stay
 * undefined and is then 0. 5l has neither. Here a GLOBL with the
 * flag 32 is the second kind: no member of a library is taken for
 * it, and where nothing defines it a call to it is no call. It is
 * how a program of ML's links only the units it uses: its start
 * calls every unit's initialization by such a name, and those of
 * the units not taken are nothing. *)

open Program

val invert : cond -> cond
val cond_bits : cond -> int
val cond_of_string : string -> cond option
val string_of_cond : cond -> string

(* an opcode from its name, the machine's [decode] for the rest *)
val decode : (string -> 'm option) -> string -> 'm op option

val show_op : ('m -> string) -> 'm op -> string

exception Error of string

(* an instruction as the assembler writes it *)
val show : ('m -> string) -> 'm prog -> string

(* raise Error, printf-style *)
val error : ('a, unit, string, 'b) format4 -> 'a

(* a shift's kind, as both machines encode it *)
val shift_bits : Asm.shift_kind -> int

val create : Asm.arch -> text_start:int -> 'm t

(* [lookup t name version]: 5l's lookup; created as Undefined *)
val lookup : 'm t -> string -> int -> sym

(* the symbol a memory operand names, from the object of [version] *)
val sym_of : 'm t -> int -> Asm.name -> sym

(* [load t files]: the objects, then from the libraries (.a) the objects
 * defining what is still undefined, until nothing new is (5l's
 * objfile, loadlib and ldobj; xix's Load). [needs]: the names the
 * machine's rewriting will call, which the libraries must define too
 * (5l's needsdiv) *)
val load : < Cap.open_in; .. > -> 'm t -> decode:(string -> 'm option) -> needs:('m prog list -> string list) -> Fpath.t list -> unit

(* A library (lib.a): objects, each with the names it defines, from
 * which load takes those that define what is undefined. ix's own
 * file, a marshalled value as an object is, not ar's; mini-ar makes it
 * (Plan 9's ar; xix's Library_file). In the file a member is its
 * object's bytes: load reads as values those it takes, read_library
 * all of them. *)
type library = (Asm.obj * string list) list
val read_library : < Cap.open_in; .. > -> Fpath.t -> library
val write_library : < Cap.open_out; .. > -> Fpath.t -> Asm.obj list -> unit

(* branch targets: a BL f(SB) to f's TEXT, a branch to a branch to the
 * final one (5l's patch and brloop; xix's Resolve) *)
val resolve : 'm t -> unit

(* each data symbol's offset (5l's dodata; xix's Layout.layout_data):
 * small ones (<= 64 bytes, bss included) first, then the data, then
 * the bss, each in 5l's hash-table order, so that the addresses are
 * goken's *)
val layout_data : 'm t -> unit

(* the data segment's bytes (5l's datblk; xix's Datagen) *)
val data_bytes : 'm t -> Bytes.t

(* a double's bits as a single's, as 5l rounds them (5l's ieeedtof) *)
val single_bits : float -> int64

(* a float constant as a memory operand, its symbol and DATA made
 * once; [single] for 4 bytes (5l's and 7l's ldobj) *)
val float_constant : 'm t -> float -> single:bool -> Asm.operand

(* the data's pointers, as offsets in the data, sorted (for Mach-O's
 * rebase stream) *)
val pointers : 'm t -> int list

(* the entry's address *)
val entry : 'm t -> string -> int

val rnd : int -> int -> int

(* the NOPs out, as 5c -O0 leaves them, a branch to one to the next
 * instruction (5l's and 7l's noops) *)
val drop_nops : 'm t -> unit
