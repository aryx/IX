(* tiny-linker: tiny-assembler's objects to an image for tiny-machine,
 * or to an a.out for tiny-kernel. Its usage, by examples, is in [help]
 * (what tiny-linker -h prints).
 *
 * Passes over the objects' items, in the order of the command line:
 *
 *     a.o b.o ...      (TinyAssembler.mli has the format)
 *        | read        each object's lines: labels, alignments,
 *        |             code with its relocs, zeros
 *        | sweep       the pieces nothing reaches left out: what an
 *        |             object without pieces names, and what that
 *        |             names... (tiny-ml's functions and static
 *        |             blocks are pieces: a library costs a program
 *        |             only what it calls)
 *        | layout      every item its address from 0, every label its
 *        |             own (one name space: twice is an error)
 *        | fill        each reloc's place: the label's address, or
 *        |             what it makes (its half, a branch's offset)
 *     image            the memory's first bytes: the CPU starts at 0
 *     (-a n: a.out)    a header (a magic number, the image's size, the
 *                      memory asked for) then the image
 *     (-map: out.map)  "address label" a line, by address: tiny-prof's
 *
 * What makes it small:
 *
 * - {b A place is filled by encoding again}: the word is decoded
 *   (TinyMachineCPU.decode), its immediate replaced, and encoded, so
 *   [encode]'s checks say what does not fit (an addi of an address
 *   above 32 KB, a branch too far), as they did when the assembler
 *   linked; there is no table of where each kind of instruction keeps
 *   its field.
 * - {b No library yet}: every object given is linked whole. An archive
 *   (objects one after the other, a member linked when it defines what
 *   another needs) is plan_tiny_self_hosting.md's step 5, with
 *   TinyLibCore/.
 * - {b The layout is the one the assembler made when it linked} (a
 *   file on a word, an .align on its address): an object without
 *   pieces, all of tiny-c's and the hand-written .tm, is placed as it
 *   was, and the split checked byte for byte on make check's images
 *   (plan_tiny_self_hosting.md, step 3).
 *
 * plan9-is-cleaner:
 * Plan 9's assemblers do not encode: an object holds the instructions
 * as parsed, and the linker, which knows every address, chooses each
 * one's form, a branch short or long by where its target is. Unix's
 * encode, and leave relocations, with a table per machine of all the
 * ways an address can sit in an instruction. A machine of one format
 * makes the two the same: the assembler encodes, and the linker's one
 * way to fill a place is the encoder.
 *
 * others:
 * Wirth's Oberon (Project Oberon, 1992) links modules as they are
 * loaded, an object's fixups chained through the code itself; Go's
 * linker descends from Plan 9's, and moved the encoding to its
 * assembler in 2014, for speed. *)

(* the objects (a name, its text), linked: the image, and each label
 * with its address, by address *)
val link : (string * string) list -> string * (string * int) list

(* an executable for tiny-kernel: a header of three words (a magic
 * number, the image's size, the memory the program asks for in bytes),
 * then the image, linked at 0; the memory first (old: ~memory, a
 * label, which tiny-ml does not read) *)
val aout : int -> string -> string

(* the program: its arguments (-h: how) to its exit status *)
val main : < Cap.argv; Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr; .. > -> int
