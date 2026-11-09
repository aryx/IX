(* tiny-assembler: tiny-machine's assembly to an object, one file at a
 * time, for tiny-linker. Its usage, by examples, is in [help] (what
 * tiny-assembler -h prints).
 *
 * Read TinyMachine/TinyMachineCPU.mli first: it has the machine, its
 * instructions (addi, lui, ori, beq, jal...), the pseudo-instructions
 * this file adds (li and la, a value or a label's address put in a
 * register; mov, call, ret, j, nop), and a listing worked out by hand.
 * TinyMachine/TinyMachineISA.mli has the instructions' words, which
 * this file makes.
 *
 * tiny-machine's instructions were designed to keep this assembler
 * simple: one format, every instruction 4 bytes, every immediate the
 * word's low 16 bits. Only the
 * pseudo-instructions are bigger: la, and li unless its number is small,
 * are two words, lui then ori. So a line's size is known as it is
 * read, from its name and whether its operand is a number or a label,
 * never from a label's address; and its words are made here, at once,
 * but for what the file cannot know: where a label is. That is left as
 * 0 in the word, and the word's chunk in the object carries a reloc
 * saying what goes there, its offset, its kind of place, its target:
 *
 *     beq   r1, zero, done        words 30100000, (0, Pc, Name "done")
 *     la    r2, table             words 20200000 17220000,
 *                                 (0, Hi, Name "table"), (4, Lo, ...)
 *     .word main                  a word 0, (0, Word, Name "main")
 *
 * The object is TinyMachineISA's items, in the file's order, marshalled
 * (that file has what each is; tiny-linker -debug says them). Every label
 * is the program's: the link is one name space, as the compilers write
 * it (tiny-c's statics carry their file's name, tiny-ml's labels their
 * unit's).
 *
 * twin:
 * mini-asm (assembler/) is Plan 9's 5a and 7a (principia's
 * assemblers/5a), and the two are opposites. mini-asm encodes nothing:
 * it parses Plan 9's syntax (TEXT, GLOBL, DATA, the destination last)
 * and marshals the instructions as it read them, the linker choosing
 * each one's words (TinyLinker's plan9-is-cleaner compares the two
 * roads). Here the words are made at once, a Unix assembler's way,
 * which costs little since an address goes in five kinds of place
 * (word, abs, hi, lo, pc), not a table per machine.
 * The syntax is ours too, the RISC manuals' (a label and a colon, the
 * destination first, gas's .word and .align, a ; comment); no #include
 * or #define, no TEXT with its frame's size: a function is a label, its
 * frame the compiler's instructions.
 *
 * kept:
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
 * context:
 * tiny-c and tiny-ml write the .tm files, tiny-linker reads the
 * objects, tiny-cpu and tiny-machine run the image. (old:
 * TinyMachineCPU.ml's assembler, which read all of a program's .tm
 * files at once and wrote the image, no object between; and before
 * plan_tiny_self_hosting.md, a TinyAssembler.ml for arm64, 7a and 7l
 * made one, in git's history.)
 *
 * cs-history:
 * The first assemblers assembled and loaded in one step: the EDSAC's
 * initial orders (David Wheeler, 1949) read orders punched on paper
 * tape as a letter and a decimal address, and stored them in memory as
 * binary. The object came with libraries and with programs too big to
 * translate again after each change: each part translated once, its
 * addresses left open, the parts bound together later.
 *
 * design:
 * The object is marshalled, as mini-asm's and mini-ld's are (old: text,
 * a line an item, "code HEX" and "reloc OFF KIND TARGET": cat hello.o
 * showed each word beside its relocs, but at the cost of a format of
 * t-ix's own, written here and read back by TinyLinker). What the text
 * showed, tiny-linker -debug says, by the items' show that mini-ml
 * derives. A magic line comes first, since tiny-ml's Marshal stops the
 * program on bytes it cannot read.
 *
 * terminology:
 * An assembler translates mnemonics into words but leaves open the
 * addresses it cannot know; a linker puts the objects one after the
 * other and fills them in; a loader puts the result in memory and
 * jumps to it (here tiny-cpu, tiny-machine, or tiny-kernel's exec).
 * Plan 9 calls its linker the loader (5l, 7l: l for load) and gives it
 * most of the assembler's work: its assemblers do not encode.
 *
 * references:
 * M. V. Wilkes, D. J. Wheeler and S. Gill, The Preparation of Programs
 * for an Electronic Digital Computer (1951), the initial orders; T. G.
 * Szymanski, "Assembling Code for Machines with Span-dependent
 * Instructions" (CACM, 1978), the problem a fixed format avoids; J. R.
 * Levine, Linkers and Loaders (2000). *)

(* what tiny-assembler asks for: its file read, its object written *)
type caps = < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

(* a file's text to its object's text, the file opened by the caller
 * (its name in the errors: Chan.origin) *)
val assemble : Chan.i -> string

(* the program: its arguments (its name first; -h: how) to how it ends *)
val main : < caps; .. > -> string array -> Exit.t
