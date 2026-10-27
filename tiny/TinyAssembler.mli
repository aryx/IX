(* tiny-assembler: tiny-machine's assembly to an object, a file at a
 * time, for tiny-linker. Its usage, by examples, is in [help] (what
 * tiny-assembler -h prints).
 *
 * The machine was designed for it: one format, every instruction 4
 * bytes, every immediate the word's low 16 bits. So an instruction's
 * size is known from its name alone (li and la with a label: two
 * words, lui and ori), and its words are made here, at once, but for
 * what the file cannot know: where a label is. That is left as 0 in the
 * word, and a line of the object says what goes there (the words
 * 30100000, then 20200000 and 17220000, as bytes in the memory's order,
 * the low first):
 *
 *     beq   r1, zero, done        code 00001030
 *                                 reloc 0 pc done
 *     la    r2, table             code 0000202000002217
 *                                 reloc 0 hi table
 *                                 reloc 4 lo table
 *     .word main                  code 00000000
 *                                 reloc 0 word main
 *
 * The object is text, a line an item, in the file's order (the format
 * is t-ix's own):
 *
 *     tiny-object
 *     align 4                     each file starts on a word
 *     label NAME                  here, an address the link chooses
 *     code HEX                    an instruction's words, or data's
 *                                 bytes, in hexadecimal, in the
 *                                 memory's order
 *     reloc OFF KIND TARGET       in the code just before, OFF bytes in:
 *                                 word (all 32 bits), abs (the
 *                                 immediate), hi or lo (the immediate:
 *                                 the address's high or low half), pc
 *                                 (the immediate: the words from the
 *                                 next instruction to TARGET); TARGET a
 *                                 label, or a number (a branch to an
 *                                 address)
 *     space N                     N zeros (.space)
 *     piece                       (.piece) what follows, up to the next
 *                                 one, is left out by the link when
 *                                 nothing reaches it (tiny-ml's
 *                                 functions and static blocks)
 *
 * An .align stays an item: what it pads depends on the address, which
 * only the link knows (v0's kernel aligns its programs on 64 KB). Every
 * label is the program's: the link is one name space, as the
 * compilers write it (tiny-c's statics carry their file's name, tiny-ml's
 * labels their unit's).
 *
 * What makes it small:
 *
 * - {b Sizes before addresses, for free.} No instruction's size
 *   depends on where a label is (no short and long branch: a branch
 *   reaches 128 KB, la any address), so the assembler never waits for
 *   the link to know how big a word is, and the link never moves
 *   anything it placed: Szymanski's problem does not arise.
 * - {b An operand says its kind as it is read}: [instruction] builds
 *   each word by a function of what its operands resolve to, given
 *   the kind of place; a number resolves at once, a label to 0 and a
 *   reloc line.
 * - {b The machine's own instructions} (csrr, csrw, eret, csrrw,
 *   amoswap, wfi: TinyMachineDevices runs them) are assembled for any
 *   program; on tiny-cpu, or in a program of tiny-kernel's, they are
 *   illegal words, as on a real machine in user mode.
 *
 * Where it fits: tiny-c and tiny-ml write the .tm files, tiny-linker
 * reads the objects, tiny-cpu and tiny-machine run the image.
 * (old: TinyMachineCPU.ml's assembler, which read all of a program's
 * .tm files at once and wrote the image, no object between; and before
 * plan_tiny_self_hosting.md, a TinyAssembler.ml for arm64, 7a and 7l
 * made one, in git's history.)
 *
 * Its twin, mini-asm (assembler/), is Plan 9's 5a and 7a (principia's
 * assemblers/5a), and the two are opposites. mini-asm encodes nothing:
 * it parses Plan 9's syntax (TEXT, GLOBL, DATA, the destination last)
 * and marshals the instructions as it read them, the linker choosing
 * each one's words (TinyLinker's plan9-is-cleaner compares the two
 * roads). Here the words are made at once and the object is text, a
 * Unix assembler's way, which costs little since an address goes in
 * five kinds of place (word, abs, hi, lo, pc), not a table per
 * machine. The syntax is ours too, the RISC manuals' (a label and a
 * colon, the destination first, gas's .word and .align, a ; comment);
 * no #include or #define, no TEXT with its frame's size: a function is
 * a label, its frame the compiler's instructions.
 *
 * cs-history:
 * The first assemblers assembled and loaded in one step: the EDSAC's
 * initial orders (David Wheeler, 1949) read orders punched on paper
 * tape as a letter and a decimal address, and stored them in memory as
 * binary. The object came with libraries and with programs too big to
 * translate again after each change: each part translated once, its
 * addresses left open, the parts bound together later.
 *
 * terminology:
 * An assembler translates mnemonics into words but leaves open the
 * addresses it cannot know; a linker puts the objects one after the
 * other and fills them in; a loader puts the result in memory and
 * jumps to it (here tiny-cpu, tiny-machine, or tiny-kernel's exec).
 * Plan 9 calls its linker the loader (5l, 7l: l for load) and gives it
 * most of the assembler's work: its assemblers do not encode.
 *
 * References: M. V. Wilkes, D. J. Wheeler and S. Gill, The Preparation
 * of Programs for an Electronic Digital Computer (1951), the initial
 * orders; T. G. Szymanski, "Assembling Code for Machines with
 * Span-dependent Instructions" (CACM, 1978), the problem a fixed
 * format avoids; J. R. Levine, Linkers and Loaders (2000). *)

(* a file's text (its name for the errors) to its object's text *)
val assemble : string -> string -> string

(* the program: its arguments (-h: how) to its exit status *)
val main : < Cap.argv; Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr; .. > -> int
