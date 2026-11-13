(* mini-ml: an ML compiler, a twin in behavior of ocaml-light's ocamlopt.
 * A unit (a .ml file) is read, its names are resolved, its types are
 * checked, and it is compiled through a stack machine into Plan 9's
 * assembly for arm or arm64, which mini-asm's parser turns into the
 * object that mini-ld links.
 *
 *     x.ml                                the modules a unit goes through
 *        | Lexer       ocamllex's: a table of keywords, comments nest
 *     tokens
 *        | Parser      ocamlyacc's: the grammar of the subset
 *     Ast.structure -- Pp: mlpp's constructs rewritten in the text
 *        |             ([%bits ...]: Bits; [@@deriving show]: Derive),
 *        |             which is then parsed again
 *        | Resolve     each name replaced by what it denotes; another
 *        |             unit's names from its .mli, read as source
 *     Scope.item list
 *        | Typing      Hindley-Milner: it checks, and nothing after it
 *        |             reads a type (-unsafe-types: not run)
 *        | Lower       patterns to tests and jumps, functions to
 *        |             closures, primitives to instructions
 *     Ir.unit_      -- Opti: tails, eqs (-O)
 *        | Gen         the stack machine's stack in registers; arm or
 *        |             arm64, a record each
 *        |             (-ssa: Ssa_build, Alloc and Emit, through Ssa)
 *     Plan 9's assembly, a text (-S prints it)
 *        | Parser_asm  mini-asm's parser, called here: no file between
 *     Asm.obj          x.5 or x.7 (-gas: Gas, GNU's assembly, x.s)
 *
 * Three things that a C compiler does not have shape it (plan_ml.md's
 * Context): the types are inferred (Typing), a function is a value
 * built as the program runs (Lower's closures), and memory is never
 * freed by hand, so the code must leave every value where the
 * collector finds it (Gen's value stack). Each of those interfaces
 * tells its part of the story. -dast, -dscope, -dir and -dssa print
 * what is between two passes, and they are how to read the passes.
 *
 * Where it stands. mini-ml is the toolchain's second front end, after
 * mini-cc. It writes the assembler's objects and leaves to the linker
 * what the linker does for C (the frames of C's functions, the large
 * constants, a branch's reach, the executable's format). A program is
 * linked from its units, the standard library's units, a start object
 * and the runtime, which is in C:
 *
 *     x.ml, y.ml       mini-ml           x.5 y.5    \
 *     lib_core's units mini-ml           List.5 ...  |
 *     the units' names mini-ml -start    start.5     |  mini-ld: the
 *     runtime.c        mini-cc           runtime.5   |  program
 *     lib_core's libc  mini-cc, mini-asm,            |
 *                      mini-ar           libc.a     /
 *
 * mini-mk runs all this from a mkfile, with mini-ml -M for a unit's
 * dependencies. The programs of ix are compiled this way, mini-ml
 * itself among them (the fixed point), and so is the kernel, mini-9pi,
 * which then runs programs compiled by the same compiler.
 *
 * What is ours. The contract is the behavior: a program prints what
 * it prints when compiled by ocaml-light's ocamlopt. No listing is
 * compared, so each pass took the smaller road (tests in sequence for
 * a match, a stack machine and no register allocator, a copying
 * collector). The dialect has no functors, no objects and no
 * polymorphic variants: a module is a name space known at compile
 * time, which Resolve flattens. There is no compiled interface: a
 * unit's .mli is read again by each unit that names it. There is no
 * bytecode and no toplevel.
 *
 * evolution:
 * ML went from a theorem prover's command language to OCaml. In the
 * 1970s Robin Milner's group at Edinburgh wrote LCF, a prover whose
 * user programs its proof strategies; the language for that, the
 * "meta language", ML, had to make sure a value of type thm was only
 * ever made by the inference rules: hence a type checker that a
 * program cannot get around, types inferred so that they are not a
 * burden, and exceptions for a strategy that fails. The language
 * outgrew the prover: Standard ML (proposed in 1983, its Definition
 * in 1990) on one side, and at INRIA Caml (1987), compiled for the
 * Categorical Abstract Machine it is named after. Xavier Leroy's
 * Caml Light (1990, with Damien Doligez's collector) was a rewrite
 * small enough for the PCs of the day, with a bytecode interpreter,
 * the ZINC machine. Caml Special Light (1995) added the module system
 * and a compiler to native code, Objective Caml (1996) added objects,
 * and OCaml 5 (2022) added threads that run in parallel. ocaml-light,
 * which is the dialect and the reference here, is OCaml 1.07 kept
 * alive: the language as it was before labels, polymorphic variants
 * and GADTs.
 *
 * modern:
 * OCaml's own native compiler has more stations on the same road:
 * Parsetree, Typedtree (the types are kept, and the pattern matching
 * compiler and the unboxing of floats read them), Lambda, Clambda or
 * Flambda (closures made explicit, functions inlined), Cmm (a C
 * without types), Mach (instructions chosen, registers allocated by
 * graph coloring), Linear, then an assembly text given to the
 * system's assembler. A .mli is compiled to a .cmi, and a digest of
 * it in each object makes the linker refuse two units that were
 * compiled against two versions of an interface; here nothing checks
 * that, and a mkfile's dependencies must be right.
 *
 * others:
 * Compiling without checking. Because nothing after Typing reads a
 * type, a program that OCaml has checked compiles here with
 * -unsafe-types, and the back end was written and tested before the
 * type checker. camlboot bootstraps OCaml from an interpreter with
 * no type checker on the same observation: ML's types say whether a
 * program is right, and not what it means.
 *
 * design:
 * One word for each value. An int is 2n+1, with its low bit set;
 * anything else (a float, an int32, a string, a tuple, a closure) is
 * the address of a block whose header says its size and tag. This is
 * OCaml's choice, for the same reasons. Polymorphism costs nothing:
 * List.map, a
 * Hashtbl, compare and every closure are one compiled code for all
 * types, and nothing of a type is kept at run time (Typing is the
 * last to read one). The collector is exact for free: a word with its
 * low bit set is not a pointer, so the collector may move every block
 * (Cheney's copy, and the young generation: see gc.c) and find each
 * root on the value stack. The price is paid by numbers: a float is a
 * block (a new one at each operation), an int has one bit less than
 * the machine's word (31 on arm, so an int32 cannot be an int), and
 * arithmetic undoes and redoes the tag. The simple path pays this
 * price. The optimizations take it back locally, where a function's
 * code shows the type: inside a function, Untag keeps an int without
 * its tag, and Unbox keeps a float out of its block, and a block or a
 * tag is made only where the value leaves (a call, a store, a
 * return). A flag switches off each of these passes.
 *
 * others:
 * There are other ways. MLton (Stephen Weeks, 2006) compiles the whole
 * program at once and copies each polymorphic function for each type
 * it is used at, so that no int is tagged and no float boxed; but no
 * unit is compiled alone, and the compiler is several times larger.
 * JavaScript's engines box numbers too: V8 tags small ints (its Smi,
 * 31 bits on a 32-bit machine, as here) and makes any other number a
 * heap block, then unboxes them in its optimizing tier, as Unbox does;
 * JavaScriptCore and LuaJIT put a double in the word itself
 * (NaN-boxing: a pointer or an int hidden in a NaN's spare bits),
 * which needs 64-bit words, not the Pi's arm. A conservative
 * collector (Boehm and Weiser, 1988) needs no tag at all, taking any
 * word that looks like an address for one, but then no block may
 * move: no copying, no generation, a heap that fragments. ocamlopt
 * itself unboxes the floats a function's code keeps (Cmmgen) and
 * flambda more; GHC's unboxed types (Int#, Double#) let the program
 * say where. mini-ml's int32 is the case where this design costs
 * most: on arm each int32 is a block, and each operation is a call of
 * the runtime (ints.c) until Lower and Emit do it in place.
 *
 * The command line is described by [help] in CLI.ml, which is what
 * mini-ml -h prints. A .mli is only parsed. An error is printed on
 * stderr, and the exit status is 1.
 *
 * References: docs/plans/done/plan_ml.md, the decisions and their
 * reasons, and plan_ml_bootstrap.md for mlpp and the fixed point;
 * M. Gordon, R. Milner and C. Wadsworth, "Edinburgh LCF" (Springer
 * LNCS 78, 1979), where ML first appears; Xavier Leroy, "The ZINC
 * experiment: an economical implementation of the ML language"
 * (INRIA technical report 117, 1990), Caml Light's design, and still
 * the best account of how an ML is compiled and why; Andrew Appel,
 * "Compiling with Continuations" (1992), the way of Standard ML of New
 * Jersey, the other school; Xavier Leroy, "Unboxed objects and
 * polymorphic typing" (POPL 1992); Stephen Weeks, "Whole-Program
 * Compilation in MLton" (ML Workshop 2006); Hans-J. Boehm and Mark
 * Weiser, "Garbage collection in an uncooperative environment"
 * (Software: Practice and Experience 18(9), 1988); N. Courant, J. Lepiller and G. Scherer,
 * "Debootstrapping without Archeology: Stacked Implementations in
 * Camlboot" (The Art, Science, and Engineering of Programming 6(3),
 * 2022). *)

type caps = < Cap.open_in; Cap.open_out; Cap.readdir; Cap.stdout; Cap.stderr >

val main : < caps; .. > -> string array -> int

(* What mini-analyze -flow (analyzers/ml/Ml_flow) shares with the
 * command: the steps on the way to Lower. *)

(* a file's text and tree, with mlpp's constructs rewritten *)
val parse : < caps; .. > -> Fpath.t -> (string * Ast.source, string) result

exception Rejected of string

(* resolves the unit's names (dirs says where the units it names are)
 * and makes mlpp's classes into dictionaries. It returns the unit's
 * text, its tree and its names, or raises Rejected with the message
 * when this cannot be done. *)
val classes :
  < caps; .. > -> Fpath.t list -> lenient:bool -> string -> string ->
  Ast.structure -> string * Ast.structure * Scope.item list

(* a typed unit as Lower's stack machine, before Opti. It uses Fold's
 * constants at the machine's width, Typing's hints (none when unsafe),
 * and, when inlining, the summaries of the units it names (looked for
 * in the objdir where they are written, then in the dirs). *)
val lower :
  < caps; .. > -> unsafe:bool -> Asm.arch -> Fpath.t -> Fpath.t list ->
  string -> Scope.item list -> Ir.unit_
