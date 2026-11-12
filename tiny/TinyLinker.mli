(* tiny-ld: links tiny-as's objects into an image for tiny-machine, or
 * into an a.out for tiny-kernel. Its usage, by examples, is in [help]
 * in TinyLinker.ml (what tiny-ld -h prints).
 *
 * It makes several passes over the items of the objects, in the order
 * of the command line:
 *
 *     a.o b.o ...      (TinyLibMachine's items, marshalled)
 *        | read        the items of each object: labels, alignments,
 *        |             code with its relocs, zeros (printed by -debug)
 *        | sweep       leaves out the pieces that nothing reaches,
 *        |             starting from what the objects without pieces
 *        |             name, then what those name, and so on.
 *        |             tiny-ml's functions and static blocks are
 *        |             pieces, so a library costs a program only what
 *        |             it calls
 *        | (-n gather) puts the text pieces first, and the data pieces
 *        |             from the next 4 KB boundary (.text and .data say
 *        |             which kind a piece is)
 *        | layout      gives every item an address, starting from 0,
 *        |             and every label its own address (there is one
 *        |             name space: a label defined twice is an error)
 *        | fill        writes in each reloc's place the label's
 *        |             address, or what is computed from it (a half
 *        |             of it, a branch's offset)
 *     image            the first bytes of memory: the CPU starts at 0
 *     (-a n: a.out)    a header (a magic number, the size of the image,
 *                      the memory requested; with -n, another magic
 *                      number and the size of the text), then the image
 *     (-s: symbols)    an a.out (of 1 MB unless -a is given), with its
 *                      labels after the image, except the local labels
 *                      of the compilers (see TinyLibMachine). This is
 *                      debug's symbol table, like Plan 9's a.out; the
 *                      loader reads only the size from the header
 *     (-map: out.map)  one "address label" line per label, sorted by
 *                      address, for tiny-prof
 *
 * twin:
 * mini-ld (linker/) is Plan 9's 5l and 7l (principia's linkers/5l),
 * and matches goken's output byte for byte. tiny-ld keeps the three
 * classical jobs of a linker: resolution, allocation and relocation.
 * It drops what 5l does for its particular machine and system:
 * choosing and encoding the instructions (here the assembler did it),
 * laying out the code along its control flow (mini-ld's Follow),
 * literal pools, the prologues that the linker writes for a TEXT,
 * libraries (mini-ar's archives; see below), and the headers of ELF
 * and Mach-O. Our a.out header is three words of our own.
 *
 * kept:
 * {b The layout is the same as when the assembler did the linking} (a
 * file starts on a word, an .align aligns its address). An object
 * without pieces, as are all of tiny-cc's and the hand-written .s
 * files, is placed exactly as it was. This was checked byte for byte on
 * the images of make check when the linker was split from the
 * assembler (plan_tiny_self_hosting.md, step 3).
 *
 * twist:
 * What tiny-ld adds compared to its twin:
 * - {b The sweep}, which neither 5l nor mini-ld has (there, a library
 *   member is taken whole): what nothing reaches is left out.
 * - {b All the members of an archive are linked}, in its order, as if
 *   each object had been given on the command line (the archive is
 *   tiny-ar's, in TinyLibMachine's format). Since the sweep leaves out
 *   what nothing reaches, there is no need to choose members by what
 *   another member needs, as 5l and Unix's ld do. An archive packages a
 *   library (TinyLibCore/stdlib.a, used by every ML program), in the
 *   order in which its units are initialized.
 * - {b A place is filled by encoding again.} The word is decoded
 *   (TinyLibMachine.decode), its immediate is replaced, and it is
 *   encoded again. So [encode]'s checks report what does not fit (an
 *   addi of an address above 32 KB, a branch too far), as they did when
 *   the assembler linked. There is no table of where each kind of
 *   instruction keeps its field.
 * - -s writes the labels as lines of text, where 5l writes a binary
 *   table (debugging.c's putsymb: a value, a type letter, a name),
 *   followed by a table mapping pcs to source lines.
 *
 * exercises:
 * - folding identical pieces: two pieces with the same bytes and the
 *   same relocations kept once, found by their hash (gold's --icf).
 *
 * others:
 * Wirth's Oberon (Project Oberon, 1992) links modules as they are
 * loaded, with an object's fixups chained through the code itself.
 * Go's linker descends from Plan 9's, and moved the encoding to its
 * assembler in 2014, for speed.
 *
 * plan9-is-cleaner:
 * Plan 9's assemblers do not encode. An object holds the instructions
 * as they were parsed, and the linker, which knows every address,
 * chooses the form of each one, for example a short or long branch
 * depending on where its target is. Unix's assemblers encode, and leave
 * relocations, with a table per machine of all the ways an address can
 * sit in an instruction. A machine with a single instruction format
 * makes the two the same: the assembler encodes, and the linker's only
 * way to fill a place is to call the encoder. *)

type caps = < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

(* In_order keeps the objects' order, ignoring .text and .data;
 * Text_first (-n) puts all the text first, then all the data. *)
type sections = In_order | Text_first

type address = int                    (* in the image, from 0 *)

(* addresses is sorted by address (for -map and -s). data_start is None
 * unless the text comes first (-n). *)
type linked = {
  image : string;
  addresses : (TinyLibMachine.label * address) list;
  data_start : address option;
}

(* The pipeline, one function per step (main opens and writes the
 * files):
 *
 *     x.o lib.a ...  Fpath.t, each
 *       | opened     Chan.i
 *       | read       TinyLibMachine.line list list: an object, or the
 *                    objects of an archive
 *       | link       linked: the image and the labels' addresses
 *       | contents   string: the image, or an a.out (output)
 *     x              (and x.map, the lines of map, with -map)
 *
 * read prints each item with -debug, and reports an error with the
 * file (Chan.origin). *)
val read : Chan.i -> TinyLibMachine.line list list

val link : sections -> TinyLibMachine.line list list -> linked

(* Image is for tiny-cpu and tiny-machine. Aout n is an a.out for
 * tiny-kernel asking for n bytes of memory (-a); Aout_labels adds the
 * labels after the image, but the compilers' local ones (-s; 1 MB
 * unless -a). An a.out's header is three words (a magic number, the
 * image's size, the memory), then the image, linked at 0; with a
 * data_start (-n), a fourth word, it, and another magic number. *)
type output = Image | Aout of int | Aout_labels of int

val contents : output -> linked -> string

(* One line per label, the address in hexadecimal, by address. *)
val map : linked -> string

(* The arguments start with the program's name; -h tells how. *)
val main : < caps; .. > -> string array -> Exit.t
