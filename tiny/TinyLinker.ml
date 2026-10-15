(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* TinyLinker: there is no tiny-linker. This file has no code; it says
 * where t-ix links, and why it has no linker of its own, for who looks
 * for the linker here as principia has a book for it (linkers/:
 * Linker.nw, Plan 9's 5l and 8l) and m-ix a program (linker/:
 * mini-ld, 5l and 7l).
 *
 * A linker has three jobs: bind each name to its definition (main
 * calls print, defined in another file), choose of a library the parts
 * a program uses, and give everything its address and fill those
 * addresses in. t-ix has two toolchains, for two unrelated machines,
 * and each does the three in one function of its assembler:
 *
 *     arm64, a real CPU                     tiny-cpu, a machine of our own
 *
 *     file.s ... (tiny-c, tiny-ml,          file.tm ... (tiny-c -tm, tiny-ml -tm,
 *       7c -S, goken's libc)                  start.tm, libc.tm, sys.tm)
 *        |                                     |
 *     TinyAssembler.ml, [link]              TinyMachine/TinyMachineCPU.ml,
 *        | gather   names bound                [assemble_files]
 *        | reach    the library's                | one after the other,
 *        |          functions used               | their labels one namespace
 *        | expand, lay out, encode               | encoded, every label known
 *     a.out (ELF, at 0x400000)              an image, at 0 (tiny-cpu -o,
 *                                             tiny-machine -o)
 *
 * - {b arm64} (TinyAssembler.ml, tiny-assembler): all the assembly of a
 *   program, its libc's included, read at once; the functions the
 *   entry reaches kept (a library is its reachable functions, where an
 *   archive's index chooses whole objects); every size known before
 *   any address, so one pass lays out and one encodes. Its header
 *   comment (TinyAssembler.mli) tells the history: the EDSAC's initial
 *   orders, Plan 9's loaders that encode, the assembler and the linker
 *   made one.
 * - {b tiny-cpu} (TinyMachineCPU.ml, by tiny-cpu and tiny-machine):
 *   the .tm files of a program assembled together, its runtime and
 *   libc whole (TinyKernel/Makefile: start.tm, libc, then the
 *   program), the labels of all of them one table; "the link is no
 *   more than that". No library is chosen from: what is given is in.
 *
 * Both have the compiler's separate compilation (tiny-c -tm compiles
 * a .c to a .tm, alone) but none of the assembler's: there is no
 * object file, only assembly, and the assembly of a whole program is
 * read again at each link. That is what makes a linker a program of
 * its own (objects with their addresses left open, a format for them,
 * relocations), and what a few thousand lines of assembly at today's
 * speed do not need.
 *
 * design:
 * tiny-cpu's programs need no relocation at all: each is linked at 0,
 * and tiny-kernel runs each at the start of its partition, the
 * machine adding the partition's base to every address (base and
 * bound, docs/notes_tiny_kernel.md). The hardware relocates, so
 * neither the linker nor the loader does: the loader (sys_exec in
 * TinyKernel.ml) copies the image and sets the window.
 *
 * The loaders, for the record: tiny-kernel's sys_exec (above);
 * TinyCPUArm.ml loads an ELF's one segment; tiny-cpu -a writes an
 * a.out for tiny-kernel (TinyMachineCPU.aout), a header of three words
 * whose last one says how much memory the program needs, which
 * sys_exec gives it.
 *
 * References: principia softwarica's linkers/Linker.nw (Plan 9's 5l,
 * explained); linker/CLI.mli (mini-ld, its passes); TinyAssembler.mli
 * (its history and references: Wilkes, Wheeler and Gill; Thompson's
 * "Plan 9 C Compilers"); John R. Levine, Linkers and Loaders (2000),
 * for the three jobs. *)
