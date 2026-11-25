(* tiny-machine's files of programs: the objects and the archives that
 * the compilers, tiny-as and tiny-ar write and tiny-ld reads, and the
 * symbols that tiny-ld writes beside or after a program, which tiny-prof
 * and debug read. TinyLibMachine is the machine's code itself: the
 * instructions, the lines of assembly, their encoding; this module is
 * what goes in a file, which the same tools share. It plays the role of
 * m-ix's lib_executable/ (Symbols, Elf_file) and of the part of Plan 9's
 * libmach that knows the format of executables and their symbol tables
 * (principia's debuggers/libmach).
 *
 * Everything here is compiled by tiny-ml too, so that the toolchain runs
 * on tiny-kernel, and a file written on the host is read on tiny-machine
 * and back (plain).
 *)

(*****************************************************************************)
(* The objects *)
(*****************************************************************************)

(* to_object marshals the lines after a magic line; of_object raises
 * TinyLibMachine.Error on bytes that are not an object, or on an object
 * of an older format. *)
val to_object : TinyLibMachine.line list -> string
val of_object : string -> TinyLibMachine.line list

(* [plain bytes] is a marshalled value's bytes made the same whichever
 * Marshal wrote them: OCaml 5's sets two bits in a large block's
 * header that OCaml 4's and tiny-ml's leave clear, and they are
 * cleared. to_object's bytes are plain; tiny-ml uses it for a unit's
 * interface. So what the host's tools write and what the same tools
 * write on tiny-machine are the same bytes, with OCaml 4 and 5. *)
val plain : string -> string

(* An archive is a library: named objects in order, all of which tiny-ld
 * links. TinyLibMachine.Error is raised when a member is not an object,
 * a name has a blank, or the bytes are not an archive. *)
val is_archive : string -> bool
val to_archive : (string * string) list -> string
val of_archive : string -> (string * string) list

(*****************************************************************************)
(* The symbols *)
(*****************************************************************************)

(* A program's labels, as tiny-ld writes them: "address label" lines,
 * the address in hexadecimal, in a map next to the image (-map, read by
 * tiny-prof) or after the image in an a.out (-s, read by debug, as in
 * Plan 9's a.out symbol table). tiny-prof names the function where an
 * instruction was counted; debug names where a program stopped and
 * finds where to set a breakpoint (b main).
 *
 * A label that a compiler makes inside a function (tiny-ml's
 * TinyBrowser.L12, tiny-cc's tm.L51) is left out: an address after it
 * belongs to the function before it. The labels of a loop in assembly
 * (row_copy2) are kept, as they tell which loop.
 *
 * mini-ld in m-ix writes no symbol table. Plan 9's 5l writes a binary
 * one (principia's linkers/5l, debugging.c): a value, a type letter (T,
 * D, B) and a name per symbol, then a table from pcs to source lines,
 * which libmach reads for db and acid. Here a label is a line of text,
 * with no kind and no source lines. *)

type label = string
type address = int                    (* from the start of the image *)
type symbols = (label * address) array  (* sorted by address *)

(* Whether a compiler made the label inside a function. *)
val local : label -> bool

(* Gives browse for TinyBrowser.f151_browse; an anonymous function keeps
 * its whole name. *)
val clean : label -> string

(* Reads the "address label" lines, leaving out the local labels. *)
val labels : string -> symbols

(* The function pc is in (the last label at or before it), its name
 * cleaned, and its address. *)
val find : symbols -> address -> (string * address) option

(* A label's address, found by its name or its cleaned name (main,
 * browse). *)
val address : symbols -> string -> int option

(*****************************************************************************)
(* The manifests *)
(*****************************************************************************)

(* What tiny-ld linked into a program, for the tools that read a program
 * whole, mini-analyze first (docs/plans/plan_analyzer_build_manifest.md):
 * the objects it took, in their order (in the Buildfile's links, the
 * order the units start in), and the source of each, so that a reader
 * knows the exact files of the program, its platform's among them
 * (TinyLibCore's, TinyLibSystem/tinykernel's), without being told them.
 * tiny-ld writes it with its map (-map: out.manifest), marshalled after
 * a magic line, as an object.
 *
 * An object's path is as tiny-ld was given it; a source is a project
 * path, from the project's top (-project: where it is from tiny-ld's
 * directory, . by default; the kernel's link, in TinyKernel/, says ..),
 * as mini-ld's are. A source is found beside its object, x.o's x.ml,
 * x.c or x.s, and an
 * archive member's beside the archive (TinyLibCore/stdlib.a's List.o is
 * TinyLibCore/List.ml); a start object (rc.start.o), which tiny-ml made
 * from the units' names, has none. No compile's flags: t-IX generates
 * no source and compiles each unit the same way (the Buildfile's MLC),
 * so the files are all a reader needs. lib_executable/Manifest has the same
 * types, mini-ld's; the constructors and fields are prefixed,
 * tiny-ml's being one name space. *)

type taken =
  | Command_line            (* given to the linker *)
  | Archive_member of string  (* a member of this archive *)

(* a path in the project, from its top (assembler/Asm.ml), or absolute
 * for a file outside it (a lexer a build made elsewhere) *)
type ppath = Ppath of string

type linked = {
  l_object : string;        (* x.o as the linker was given it; a member's name *)
  l_source : ppath option;  (* x.ml, x.c or x.s *)
  l_taken : taken;
}

type manifest = {
  m_program : string;       (* the output's name, rc *)
  m_units : linked list;    (* in the link's order *)
}

(* [manifest program objects source]: source gives an object's source *)
val manifest :
  string -> (string * taken) list -> (string -> taken -> string option) ->
  manifest

val to_manifest : manifest -> string
