(* mini-ld: Plan 9's loaders, 5l for arm and 7l for arm64. Objects and
 * libraries go in, an executable comes out; between the two, the
 * names are bound, the code and the data are given their addresses,
 * and each instruction, which the assembler and the compilers left
 * as they read it or made it, becomes its machine word.
 *
 *     hello.5 print.5 libc.a          the passes, in the order of [link]
 *        | Link.load         the objects, and of each library the
 *        |                   members that define a name still undefined
 *     Program.t              one list of instructions, a table of
 *        |                   symbols, the DATAs
 *        | Arm.prepare       B.NE to BNE, float constants to the data
 *        | Link.resolve      BL print(SB): to print's TEXT
 *        | Link.layout_data  each variable its offset in the data
 *        | Follow.follow     the code along its flow (5l's order)
 *        | Link.drop_nops
 *        | Arm.rewrite       a TEXT's prologue, RET, DIV as a call
 *        | Arm.layout        each instruction its address; the pools
 *        | Arm.encode        the words, every address now known
 *        | Link.data_bytes
 *     text, data, a size of bss
 *        | Exe.write         behind a header: ELF, a.out, Mach-O, none
 *     a.out
 *
 * Arm64's four passes for -m 7. The machine is a record of functions
 * ([machine] in CLI.ml), the general part (Link, Follow, Exe) never
 * looking inside an instruction.
 *
 * What a linker is for, on two files. main.c calls print, which it
 * does not have; print.c, compiled another day, has it:
 *
 *     main.5:  TEXT main(SB)          print.5:  TEXT print(SB)
 *                BL print(SB)                     ...
 *                                               GLOBL buf(SB), $64
 *
 * Each object names things by their names only, since neither
 * compiler could know where the other's would be. Three jobs follow,
 * the classical ones:
 * - resolution: the name print in main.5 and the TEXT print of
 *   print.5 are one symbol (Link.lookup's table); a name nothing
 *   defines is the error everyone has met, hello.c:0: undefined: print;
 * - allocation: main's code at 0x80a0 (an ELF's for arm: 0x8000 and
 *   the header), print's after it, buf at an offset in the data,
 *   which starts on the page after the text;
 * - relocation: the BL's word must hold the distance from itself to
 *   print, the load of buf its address. A Unix linker patches words
 *   the assembler already made, following the object's relocation
 *   records. Here there is nothing to patch: the words are made
 *   last, from the addresses (Asm says why).
 *
 * Where it stands: every program of ix on arm is this linker's,
 * mini-cc's and mini-ml's objects with mini-ar's libraries, and the
 * kernels too (-H0 -T: no header, the text at the address the
 * board's firmware loads it). Its output is run by mini-5i (Linux's
 * ELF: Elf, Linux; Plan 9's a.out: Plan9), by mini-qemu, and by the
 * kernel's exec, which reads the header Exe wrote.
 *
 * What is ours: the output is goken's 5l's and 7l's byte for byte
 * (the tests compare them), the code is not theirs: one opcode type
 * and not strings, one match per machine where 5l has a table of
 * rules and a switch (Arm), no instruction list linked by pointers.
 * No symbol table is written, so no debugger; no dynamic linking; no
 * profiling (5l's -p).
 *
 * terminology:
 * Loader, linker, link editor. Plan 9 says loader, and the l of 5l
 * is that word, as the ld of Unix was: on the first machines the
 * program that bound the names was also the one that put the result
 * in memory and jumped to it. When the result became a file, to be
 * loaded later by the system's exec, the program kept its name and
 * the job split in two; "linker" and "link editor" are the later
 * words for the first half. Here the loader of the second half is
 * the kernel (and, for a Linux ELF, mini-5i's Linux.load).
 *
 * others:
 * Unix's ld reads its arguments once, left to right, and takes from
 * a library only what is undefined at that moment: hence -lm at the
 * end of the line, and the errors of a line in the wrong order.
 * [Link.load], as 5l, scans the libraries again until nothing new is
 * taken, and the order does not matter.
 *
 * modern:
 * Most of a linker's work today is what this one does not do:
 * shared libraries, whose names are bound when the program starts
 * (or at the first call) by a dynamic loader, ld.so; sections merged
 * and discarded one by one, debugging information larger than the
 * code, the whole program optimized again at the link. Plan 9 links
 * statically and only so, a choice and not an omission: one file is
 * the whole program.
 *
 * The command line: its usage and examples are [help] in CLI.ml, what
 * mini-ld -h prints.
 *
 * References: Ken Thompson, "Plan 9 C Compilers" (1990), section
 * "The loader"; John R. Levine, Linkers and Loaders (2000), the book
 * on the subject, for all that is not here; principia's linkers/5l
 * and its book, xix's linker. *)
type caps = < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

val main : < caps; .. > -> string array -> int
