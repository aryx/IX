(* ELF executables, 32 and 64 bits, little-endian: what a loader needs
 * (the machine, the entry, the loadable segments).
 *
 *   hello.exe (arm32, mini-ld -H7):  entry 0x80cc
 *     LOAD 0x0000a0 -> 0x80a0 filesz 0x6ee8 memsz 0x6ee8  R E
 *     LOAD 0x007000 -> 0xf000 filesz 0x09c8 memsz 0x0bd0  RWE
 *
 * Each LOAD line is an order to the loader: these bytes of the file
 * at that address. The second one's memsz is larger than its
 * filesz: the 0x208 bytes of difference are not in the file, they
 * are the bss, to be zeroed. That is all exec needs, and all
 * Linux.load does with it.
 *
 * Where it stands: the reader of what the linker's Exe writes (its
 * header draws the same file from the writer's side), for mini-5i
 * to load a program and for mini-qemu to load a kernel given as an
 * ELF and name its functions ([symbols], -symbols).
 *
 * terminology:
 * Segments and sections, ELF's two tables over the same bytes. A
 * segment (a program header, a LOAD) is for running: an address and
 * rights. A section (.text, .data, .symtab) is for the tools: a
 * name and a kind, for a linker to merge and a debugger to find the
 * symbols. A loader reads only the first table and a linker's input
 * has only the second; this module reads the sections for one
 * thing, the symbol table.
 *
 * References: the System V ABI's ELF chapter and ARM's ELF supplement
 * (ELF for the Arm Architecture); readelf, run, for the example. *)

type machine = Arm | Aarch64 | Other of int

type segment = { offset : int; vaddr : int; paddr : int; filesz : int; memsz : int; exec : bool }

type t = { machine : machine; entry : int; segments : segment list }

exception Bad of string

val parse : string -> t

(* the symbols defined in a section, (value, name), in no order: for
 * mini-qemu's -symbols, a PC as a function's name *)
val symbols : string -> (int64 * string) list
