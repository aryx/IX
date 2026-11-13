(* ELF executables, 32 and 64 bits, little-endian. This module reads
 * what a loader needs: the machine, the entry and the loadable
 * segments.
 *
 *   hello.exe (arm32, mini-ld -H7):  entry 0x80cc
 *     LOAD 0x0000a0 -> 0x80a0 filesz 0x6ee8 memsz 0x6ee8  R E
 *     LOAD 0x007000 -> 0xf000 filesz 0x09c8 memsz 0x0bd0  RWE
 *
 * Each LOAD line is an order to the loader: put these bytes of the
 * file at that address. The second one's memsz is larger than its
 * filesz. The 0x208 bytes of difference are not in the file; they are
 * the bss, which is to be zeroed. That is all exec needs, and all that
 * Linux.load does with it.
 *
 * Where it stands: it reads what the linker's Exe writes (Exe's header
 * draws the same file from the writer's side). mini-5i uses it to load
 * a program, and mini-qemu to load a kernel given as an ELF and to name
 * its functions ([symbols], -symbols).
 *
 * terminology:
 * Segments and sections are ELF's two tables over the same bytes. A
 * segment (a program header, a LOAD) is for running, and has an
 * address and rights. A section (.text, .data, .symtab) is for the
 * tools, and has a name and a kind, so that a linker can merge it and
 * a debugger find the symbols. A loader reads only the first table,
 * and a linker's input has only the second. This module reads the
 * sections for one thing, the symbol table.
 *
 * References: the System V ABI's ELF chapter and ARM's ELF supplement
 * (ELF for the Arm Architecture); readelf, run, for the example. *)

type machine = Arm | Aarch64 | Other of int

type segment = { offset : int; vaddr : int; paddr : int; filesz : int; memsz : int; exec : bool }

type t = { machine : machine; entry : int; segments : segment list }

exception Bad of string

val parse : string -> t

(* the symbols defined in a section, as (value, name) pairs in no
 * order. mini-qemu's -symbols uses them to show a PC as a function's
 * name. *)
val symbols : string -> (int64 * string) list
