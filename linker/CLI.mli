(* mini-ld is Plan 9's loader: 5l for arm and 7l for arm64. Objects and
 * libraries go in, and an executable comes out. In between, the names
 * are bound, the code and the data are given their addresses, and each
 * instruction, which the assembler and the compilers left as they read
 * it or made it, becomes its machine word.
 *
 *     hello.5 print.5 libc.a          the passes, in the order of [link]
 *        | Link.load         the objects, and from each library the
 *        |                   members that define a name still undefined
 *     Program.t              one list of instructions, a table of
 *        |                   symbols, and the DATAs
 *        | Arm.prepare       B.NE to BNE, float constants to the data
 *        | Link.resolve      BL print(SB) to print's TEXT
 *        | Link.layout_data  each variable gets its offset in the data
 *        | Follow.follow     the code along its flow (5l's order)
 *        | Link.drop_nops
 *        | Arm.rewrite       a TEXT's prologue, RET, DIV as a call
 *        | Arm.layout        each instruction gets its address; the pools
 *        | Arm.encode        the words, now that every address is known
 *        | Link.data_bytes
 *     text, data, a size of bss
 *        | Exe.write         behind a header: ELF, a.out, Mach-O, or none
 *     a.out
 *
 * For -m 7, Arm64's four passes are used instead. The machine is a
 * record of functions ([machine] in CLI.ml), and the general part
 * (Link, Follow, Exe) never looks inside an instruction.
 *
 * Here is what a linker is for, on two files. main.c calls print, which
 * it does not have; print.c, compiled another day, has it:
 *
 *     main.5:  TEXT main(SB)          print.5:  TEXT print(SB)
 *                BL print(SB)                     ...
 *                                               GLOBL buf(SB), $64
 *
 * Each object names things by their names only, since neither compiler
 * could know where the other's things would be. Three jobs follow, the
 * classical ones:
 * - resolution: the name print in main.5 and the TEXT print of print.5
 *   are one symbol (in Link.lookup's table). A name that nothing defines
 *   is the error everyone has met, hello.c:0: undefined: print;
 * - allocation: main's code goes at 0x80a0 (for an ELF on arm, that is
 *   0x8000 plus the header), print's after it, and buf at an offset in
 *   the data, which starts on the page after the text;
 * - relocation: the BL's word must hold the distance from itself to
 *   print, and the load of buf must hold buf's address. A Unix linker
 *   patches words that the assembler already made, following the
 *   object's relocation records. Here there is nothing to patch: the
 *   words are made last, from the addresses (Asm says why).
 *
 * Where it stands: every program of ix on arm is linked by this linker,
 * from mini-cc's and mini-ml's objects and mini-ar's libraries, and so
 * are the kernels (-H0 -T: no header, and the text at the address where
 * the board's firmware loads it). Its output is run by mini-5i (Linux's
 * ELF with Elf and Linux; Plan 9's a.out with Plan9), by mini-qemu, and
 * by the kernel's exec, which reads the header Exe wrote.
 *
 * What is ours: the output is the same as goken's 5l's and 7l's, byte
 * for byte (the tests compare them), but the code is not theirs. There
 * is one opcode type and not strings, one match per machine where 5l
 * has a table of rules and a switch (Arm), and no instruction list
 * linked by pointers. A symbol table, and a table from pcs to lines,
 * are written only with -g (linker/debug/Symtab says how). There is no
 * dynamic linking, and no profiling (5l's -p).
 *
 * terminology:
 * Loader, linker, link editor. Plan 9 says loader, and the l of 5l is
 * that word, as the ld of Unix was. On the first machines the program
 * that bound the names was also the one that put the result in memory
 * and jumped to it. When the result became a file, to be loaded later
 * by the system's exec, the program kept its name and the job split in
 * two; "linker" and "link editor" are the later words for the first
 * half. Here the loader of the second half is the kernel (and, for a
 * Linux ELF, mini-5i's Linux.load).
 *
 * others:
 * Unix's ld reads its arguments once, from left to right, and takes
 * from a library only what is undefined at that moment. Hence -lm goes
 * at the end of the line, and a line in the wrong order gives errors.
 * [Link.load], like 5l, scans the libraries again until nothing new is
 * taken, so the order does not matter.
 *
 * modern:
 * Most of a linker's work today is what this one does not do: shared
 * libraries, whose names are bound when the program starts (or at the
 * first call) by a dynamic loader, ld.so; sections merged and discarded
 * one by one; debugging information larger than the code; and the whole
 * program optimized again at link time. Plan 9 links statically and
 * only so, which is a choice and not an omission: one file is the whole
 * program.
 *
 * The usage and examples of the command line are in [help] in CLI.ml,
 * which is what mini-ld -h prints.
 *
 * References: Ken Thompson, "Plan 9 C Compilers" (1990), section
 * "The loader"; John R. Levine, Linkers and Loaders (2000), the book on
 * the subject, for all that is not here; principia's linkers/5l and its
 * book, and xix's linker. *)
type caps = < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

val main : < caps; .. > -> string array -> int
