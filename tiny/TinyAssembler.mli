(* tiny-as: assembles tiny-machine's assembly into an object for
 * tiny-ld, one file at a time. Its usage, by examples, is in [help] in
 * TinyAssembler.ml (what tiny-as -h prints).
 *
 * Read TinyMachine/TinyMachineCPU.mli first. It has the machine, its
 * instructions (addi, lui, ori, beq, jal...), the pseudo-instructions
 * that this file adds (li and la, which put a value or a label's
 * address in a register; mov, call, ret, j, nop), and a listing worked
 * out by hand. TinyLibMachine.mli has the rest:
 * - the words of the instructions, which this file makes;
 * - the lines that a text is parsed into (parse, here, is the only
 *   code that reads assembly text); the compilers make the same lines;
 * - their encoding, TinyLibMachine's assemble, which the compilers call
 *   directly.
 * So this program is only for assembly written by hand: the kernel's
 * kentry.s, the runtime's start.s, the steps, the tests.
 *
 * tiny-machine's instructions were designed to keep this assembler
 * simple: there is one format, every instruction is 4 bytes, and every
 * immediate is the low 16 bits of the word. Only the
 * pseudo-instructions are bigger: la, and li unless its number is
 * small, are two words, lui then ori. So the size of a line is known as
 * soon as it is read, from its name and whether its operand is a number
 * or a label, and never depends on a label's address. Its words are
 * made here, at once, except for what the file cannot know: where a
 * label is. That part is left as 0 in the word, and the word's chunk in
 * the object carries a reloc that says what goes there: its offset, its
 * kind of place, and its target.
 *
 *     beq   r1, zero, done        words 30100000, (0, Pc, Name "done")
 *     la    r2, table             words 20200000 17220000,
 *                                 (0, Hi, Name "table"), (4, Lo, ...)
 *     .word main                  a word 0, (0, Full, Name "main")
 *
 * The object is a list of TinyLibMachine's lines, encoded, in the
 * file's order, and marshalled (TinyLibMachine.mli says what each line
 * is; tiny-ld -debug prints them). Every label is global to the
 * program: the link has a single name space, and the compilers write
 * their labels accordingly (tiny-cc's statics carry their file's name,
 * tiny-ml's labels their unit's).
 *
 * twin:
 * mini-asm (assembler/) is Plan 9's 5a and 7a (principia's
 * assemblers/5a), and the two assemblers are opposites. mini-asm
 * encodes nothing: it parses Plan 9's syntax (TEXT, GLOBL, DATA, the
 * destination last) and marshals the instructions as it read them, and
 * the linker chooses the words of each one (the plan9-is-cleaner:
 * paragraph of TinyLinker.mli compares the two roads). Here the words
 * are made at once, the way Unix assemblers do it. This costs little,
 * since an address goes in only five kinds of place (word, abs, hi,
 * lo, pc), not in a table per machine.
 *
 * The syntax is ours too, the one of RISC manuals: a label followed by
 * a colon, the destination first, gas's .word and .align, and ; for
 * comments. There is no #include or #define, and no TEXT with the size
 * of the frame: a function is just a label, and its frame is made by
 * the compiler's instructions.
 *
 * kept:
 * What makes it small:
 *
 * - {b Sizes are known before addresses, for free.} No instruction's
 *   size depends on where a label is (there are no short and long
 *   branches: a branch reaches 128 KB, and la reaches any address). So
 *   the assembler never waits for the link to know how big a word is,
 *   and the link never moves anything it placed: Szymanski's problem
 *   does not arise.
 * - {b An operand tells its kind as soon as it is read.} [instruction]
 *   builds each word with a function of what its operands resolve to,
 *   given the kind of place. A number resolves at once; a label
 *   resolves to 0 and a reloc.
 * - {b The machine's own instructions} (csrr, csrw, eret, csrrw,
 *   amoswap, wfi, which TinyMachineDevices runs) are assembled for any
 *   program. On tiny-cpu, or in a program on tiny-kernel, they are
 *   illegal words, as on a real machine in user mode.
 *
 * context:
 * People write the .s files (tiny-cc -S and tiny-ml -S print theirs,
 * to be read). tiny-ld reads the objects, both these and the
 * compilers'. tiny-cpu and tiny-machine run the image.
 *
 * cs-history:
 * The first assemblers assembled and loaded in one step: the EDSAC's
 * initial orders (David Wheeler, 1949) read orders punched on paper
 * tape as a letter and a decimal address, and stored them in memory as
 * binary. Object files came later, with libraries and with programs too
 * big to translate again after each change: each part was translated
 * once, its addresses left open, and the parts were bound together
 * later.
 *
 * design:
 * The object is marshalled, as mini-asm's and mini-ld's are. What a
 * text format would show, tiny-ld -debug prints, using the show
 * function on lines that mini-ml derives. A magic line comes first,
 * because tiny-ml's Marshal stops the program on bytes it cannot read.
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
 *  - M. V. Wilkes, D. J. Wheeler and S. Gill, The Preparation of
 *    Programs for an Electronic Digital Computer (1951): the initial
 *    orders
 *  - T. G. Szymanski, "Assembling Code for Machines with Span-dependent
 *    Instructions" (CACM, 1978): the problem a fixed format avoids
 *  - J. R. Levine, Linkers and Loaders (2000)
 *)

(* What tiny-as needs: to read its file and write its object. *)
type caps = < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

(* The pipeline, one function per step (main opens and closes the
 * files):
 *
 *     x.s           Fpath.t
 *       | opened    Chan.i
 *       | read      (int * TinyLibMachine.line list) list: for each line
 *       |           of text, its number and its lines (from parse)
 *       | encode    TinyLibMachine.line list, the object
 *       | write     Chan.o, marshalled
 *     x.o
 *
 * With -S, the lines read are printed back by print_line, the text the
 * compilers' -S writes. TinyAssembler_test.sh checks the law:
 * assembling that text gives the same object as the original file.
 *
 * [parse text]: a line's labels, then its instruction or directive
 * (.word a, b gives one Word each). A ; starts a comment. Raises
 * TinyLibMachine.Error. *)
val parse : string -> TinyLibMachine.line list

(* Lines numbered from 1, none for a blank line or a comment. An error
 * is reported with the file (Chan.origin) and the line. *)
val read : Chan.i -> (int * TinyLibMachine.line list) list

(* [encode file lines]: file names the errors. *)
val encode :
  string -> (int * TinyLibMachine.line list) list -> TinyLibMachine.line list

(* Marshalled by TinyLibMachine.to_object, as tiny-ld reads it. *)
val write : Chan.o -> TinyLibMachine.line list -> unit

(* The arguments start with the program's name; -h tells how. *)
val main : < caps; .. > -> string array -> Exit.t
