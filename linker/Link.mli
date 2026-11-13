(* The linker's general part: the symbols, the objects and libraries a
 * program needs, the data's layout, the branches' targets, and the
 * bytes of the data. It is everything that does not look inside an
 * instruction. The machine modules (Arm, Arm64) lay the code out and
 * encode it, and Exe writes the file in one of its formats (ELF, Plan
 * 9's a.out, Mach-O).
 *
 *     load (objects, libraries) -> resolve (branches) -> layout_data
 *       -> Arm.rewrite -> Arm.layout (pcs, pools) -> Arm.encode -> Exe.write
 *
 * (CLI.mli has every pass, in order.)
 *
 * {b A symbol} is a name and what is known of it so far (Program's
 * sym). It starts as Undefined, the first time any object names it. A
 * TEXT makes it Text, a GLOBL makes it Bss, and a DATA on it makes it
 * Data. Here is the linking of hello.5, which calls print, with a
 * libc.a of three members:
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
 * So a library is a set from which what is needed is drawn, while an
 * object given on the command line is taken whole. This is why libc is
 * a library of many small objects, with one function per file. What is
 * still Undefined when a branch to it is resolved is an error
 * (hello.c:0: undefined: print).
 *
 * {b name<>}, a name with <> after it in the assembly (C's static),
 * belongs to its object. The table's key is the name and a version,
 * which is 0 for the names all objects share, and the object's number
 * for its own names. So two files may each have a tmp<> without them
 * meeting.
 *
 * {b The data's layout} ([layout_data]). The code reaches a global by
 * an offset from a register that holds one fixed address in the data
 * (R12 on arm, 4092 bytes after the data's start), and an instruction's
 * offset is 12 bits and a sign. So what is within 4095 bytes of R12,
 * the data's first 8 KB, costs one instruction, and the rest costs a
 * second instruction and a word of a literal pool. Hence the order:
 *
 *     data_start
 *     | small ones, 64 bytes or less  | the rest with  |  the rest
 *     | (initialized or not)          | DATAs          |  without
 *     '---------- in the file: data_size --------------'-- bss_size --
 *
 * The small variables, which are the many, are near the register. The
 * large arrays are far, where the second instruction is lost in the
 * loop that walks them.
 *
 * {b Why the linker encodes} (the plan's decision 1, and Asm.ml). It
 * encodes after the whole program is laid out, so an address is known
 * whenever a word is made, and there are no relocations, neither in the
 * objects nor here. There is one encoder per machine, shared by the
 * assembler's path and (next) the compiler's. The choices that depend
 * on distances (a literal pool or not, a long branch or not) are made
 * once, knowing them. And the machine is confined to its module.
 *
 * Names: each function says which functions of 5l (goken's linkers/5l,
 * as the Principia book documents it) and of xix (linker/) it
 * corresponds to, so that either can be found from here.
 *
 * References: Ken Thompson, "Plan 9 C Compilers" (Summer 1990 UKUUG
 * Conference), its section "The loader". There external data is
 * allocated "with the smallest variables allocated first", written for
 * the MIPS, whose loads reach +-32K from R30 (see [layout_data], for
 * arm's R12; the same section's reordering of the code is in Follow,
 * which quotes it). Leon Presser and John R. White, "Linkers and
 * Loaders" (ACM Computing Surveys, 1972), the classic survey, which
 * splits the job into allocation, linking, relocation and loading. Here
 * [layout_data] allocates, [load] and [resolve] link, relocation has no
 * pass of its own (the encoder writes final addresses), and loading is
 * done by the kernel's exec. John R. Levine, Linkers and Loaders
 * (2000), for archives and their symbol index, and for the single scan
 * of Unix's ld that makes the order of libraries matter, where [load]
 * scans them all again until nothing new is defined.
 *
 * others:
 * A weak name. C's toolchains have "weak symbols": either a definition
 * that gives way to another, or a reference that may stay undefined
 * and is then 0. 5l has neither. Here a GLOBL with the flag 32 is the
 * second kind: no member of a library is taken for it, and when nothing
 * defines it, a call to it is no call. This is how an ML program links
 * only the units it uses: its start calls every unit's initialization
 * by such a name, and the calls for the units not taken do nothing. *)

open Program

val invert : cond -> cond
val cond_bits : cond -> int
val cond_of_string : string -> cond option
val string_of_cond : cond -> string

(* an opcode from its name, using the machine's [decode] for the
 * machine's own opcodes *)
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

(* [lookup t name version] is 5l's lookup; a new symbol is created as
 * Undefined *)
val lookup : 'm t -> string -> int -> sym

(* the symbol a memory operand names, from the object of [version] *)
val sym_of : 'm t -> int -> Asm.name -> sym

(* [load t files] loads the objects, then from the libraries (.a) the
 * objects that define what is still undefined, until nothing new is
 * defined (5l's objfile, loadlib and ldobj; xix's Load). [needs] gives
 * the names that the machine's rewriting will call, which the libraries
 * must define too (5l's needsdiv). *)
val load : < Cap.open_in; .. > -> 'm t -> decode:(string -> 'm option) -> needs:('m prog list -> string list) -> Fpath.t list -> unit

(* loads objects already in memory, and only them. It is for
 * mini-dotnet's JIT, which assembles its text and encodes it with the
 * passes after load. *)
val load_objects : 'm t -> decode:(string -> 'm option) -> Asm.obj list -> unit

(* A library (lib.a) is a list of objects, each with the names it
 * defines, from which load takes those that define what is undefined.
 * Its file is ix's own, a marshalled value as an object is, and not
 * ar's; mini-ar makes it (Plan 9's ar; xix's Library_file). In the
 * file, a member is its object's source, its bytes and the names it
 * defines. load reads as values only the members it takes, and mini-ar
 * reads none. *)
type def_kind = T | D
type member = string * string * (def_kind * string) list
val member_of : Asm.obj -> member
val member_file : member -> string
(* each member's bytes and the names indexed for it (a text name that
 * a later member defines again is not indexed for that member, as in
 * ar) *)
val index : member list -> (string * string list) list
val read_library : < Cap.open_in; .. > -> Fpath.t -> member list
val write_library : < Cap.open_out; .. > -> Fpath.t -> member list -> unit

(* Sets the branch targets: a BL f(SB) goes to f's TEXT, and a branch
 * to a branch goes to the final one (5l's patch and brloop; xix's
 * Resolve). *)
val resolve : 'm t -> unit

(* Gives each data symbol its offset (5l's dodata; xix's
 * Layout.layout_data). The small ones (<= 64 bytes, bss included) come
 * first, then the data, then the bss, each in the order of 5l's hash
 * table, so that the addresses are the same as goken's. *)
val layout_data : 'm t -> unit

(* the bucket of a name and version in 5l's (Arm) or 7l's hash table,
 * which gives the order of the data's layout and of the symbol table
 * (Symtab) *)
val bucket : Asm.arch -> string -> int -> int

(* the data segment's bytes (5l's datblk; xix's Datagen) *)
val data_bytes : 'm t -> Bytes.t

(* a double's bits as a single's, as 5l rounds them (5l's ieeedtof) *)
val single_bits : float -> int64

(* a float constant as a memory operand, with its symbol and DATA made
 * only once; [single] is for 4 bytes (5l's and 7l's ldobj) *)
val float_constant : 'm t -> float -> single:bool -> Asm.operand

(* the data's pointers, as offsets in the data, sorted (for Mach-O's
 * rebase stream) *)
val pointers : 'm t -> int list

(* the entry's address *)
val entry : 'm t -> string -> int

val rnd : int -> int -> int

(* Takes out the NOPs that 5c -O0 leaves, and a branch to a NOP goes
 * to the next instruction instead (5l's and 7l's noops). *)
val drop_nops : 'm t -> unit
