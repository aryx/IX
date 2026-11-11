(* tiny-linker: tiny-assembler's objects to an image for tiny-machine,
 * or to an a.out for tiny-kernel. Its usage, by examples, is in [help]
 * (what tiny-linker -h prints).
 *
 * Passes over the objects' items, in the order of the command line:
 *
 *     a.o b.o ...      (TinyLibMachine's items, marshalled)
 *        | read        each object's items: labels, alignments,
 *        |             code with its relocs, zeros (-debug: said)
 *        | sweep       the pieces nothing reaches left out: what an
 *        |             object without pieces names, and what that
 *        |             names... (tiny-ml's functions and static
 *        |             blocks are pieces: a library costs a program
 *        |             only what it calls)
 *        | (-n gather) the text's pieces first, the data's from the
 *        |             next 4 KB (.text and .data say which a piece is)
 *        | layout      every item its address from 0, every label its
 *        |             own (one name space: twice is an error)
 *        | fill        each reloc's place: the label's address, or
 *        |             what it makes (its half, a branch's offset)
 *     image            the memory's first bytes: the CPU starts at 0
 *     (-a n: a.out)    a header (a magic number, the image's size, the
 *                      memory asked for; with -n another magic number
 *                      and the text's size) then the image
 *     (-s: symbols)    an a.out (of 1 MB unless -a), its labels after
 *                      the image, the compilers' local ones left out
 *                      (TinyLibMachine): debug's, Plan 9's a.out symbol
 *                      table; the loader reads the header's size only
 *     (-map: out.map)  "address label" a line, by address: tiny-prof's
 *
 * twin:
 * mini-ld (linker/) is Plan 9's 5l and 7l (principia's
 * linkers/5l), goken's output byte for byte. Kept: the three classical
 * jobs, resolution, allocation and relocation. Dropped, as what 5l
 * does for its machine and its system: choosing and encoding the
 * instructions (the assembler did), the code laid along its flow
 * (mini-ld's Follow), literal pools, the prologues a linker writes for
 * a TEXT, libraries (mini-ar's archives, below), ELF's and Mach-O's
 * headers: the a.out's is three words of its own.
 *
 * kept:
 * {b The layout is the one the assembler made when it linked} (a file
 * on a word, an .align on its address): an object without pieces, all
 * of tiny-c's and the hand-written .s, is placed as it was, and the
 * split checked byte for byte on make check's images
 * (plan_tiny_self_hosting.md, step 3).
 *
 * twist:
 * Added, against the twin:
 * - {b The sweep}, which neither 5l nor mini-ld has (a library's
 *   member is taken whole there): what nothing reaches is left out.
 * - {b An archive's members all linked}, in its order, as if each
 *   object were given (tiny-ar's, TinyLibMachine's format): the sweep
 *   leaves out what nothing reaches, so a member is not chosen by what
 *   another needs, as 5l's and Unix's ld's are. An archive packages a
 *   library (TinyLibCore/stdlib.a, every ML program's), its order the
 *   one its units start in.
 * - {b A place is filled by encoding again}: the word is decoded
 *   (TinyLibMachine.decode), its immediate replaced, and encoded, so
 *   [encode]'s checks say what does not fit (an addi of an address
 *   above 32 KB, a branch too far), as they did when the assembler
 *   linked; there is no table of where each kind of instruction keeps
 *   its field.
 * - -s writes the labels as text lines, where 5l writes a binary table
 *   (debugging.c's putsymb: a value, a type letter, a name) and a
 *   table of the pcs' source lines beside it.
 *
 * exercises:
 * - identical pieces folded: two pieces of the same bytes and the same
 *   relocations kept once, found by their hash (gold's --icf).
 *
 * others:
 * Wirth's Oberon (Project Oberon, 1992) links modules as they are
 * loaded, an object's fixups chained through the code itself; Go's
 * linker descends from Plan 9's, and moved the encoding to its
 * assembler in 2014, for speed.
 *
 * plan9-is-cleaner:
 * Plan 9's assemblers do not encode: an object holds the instructions
 * as parsed, and the linker, which knows every address, chooses each
 * one's form, a branch short or long by where its target is. Unix's
 * encode, and leave relocations, with a table per machine of all the
 * ways an address can sit in an instruction. A machine of one format
 * makes the two the same: the assembler encodes, and the linker's one
 * way to fill a place is the encoder. *)

(* what tiny-linker asks for: the objects read, the image written *)
type caps = < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

(* the image's order: the objects', .text and .data ignored; or all the
 * text first, then all the data (-n) *)
type sections = In_order | Text_first

(* an address in the image, from 0 *)
type address = int

(* a link's result: the image; the labels, each with its address, by
 * address (-map's lines, -s's); where the data starts, with the text
 * first (Text_first, -n; None in the objects' order) *)
type linked = {
  image : string;
  addresses : (TinyLibMachine.label * address) list;
  data_start : address option;
}

(* The pipeline, a step a function (main opens and writes the files):
 *
 *     x.o lib.a ...  Fpath.t, each
 *       | opened     Chan.i
 *       | read       TinyLibMachine.line list list: an object, or an
 *                    archive's
 *       | link       linked: the image, the labels' addresses
 *       | contents   string: the image, or an a.out (output)
 *     x              (and x.map, map's lines, with -map)
 *
 * An object file's items (TinyLibMachine's of_object), each said with
 * -debug; an archive's objects, in its order; an error said with the
 * file (Chan.origin) *)
val read : Chan.i -> TinyLibMachine.line list list

(* [link order objects]: the objects, each its items, linked *)
val link : sections -> TinyLibMachine.line list list -> linked

(* what the output file is: the image alone, for tiny-cpu and
 * tiny-machine; or an a.out for tiny-kernel, asking for that much
 * memory in bytes (-a), with its labels after the image but the
 * compilers' local ones (Aout_labels, -s: 1 MB unless -a says). An
 * a.out is a header of three words, a magic number, the image's size,
 * the memory, then the image, linked at 0; with a data_start (-n), a
 * fourth word, it, and another magic number *)
type output = Image | Aout of int | Aout_labels of int

(* the output file's bytes *)
val contents : output -> linked -> string

(* -map's: each label's line, its address in hexadecimal and its name,
 * by address *)
val map : linked -> string

(* the program: its arguments (its name first; -h: how) to how it ends *)
val main : < caps; .. > -> string array -> Exit.t
