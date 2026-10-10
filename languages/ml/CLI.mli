(* mini-ml: an ML compiler, ocaml-light's ocamlopt's twin in behavior.
 * A unit (a .ml file) is read, its names are resolved, its types are
 * checked, and it is compiled through a stack machine into Plan 9's
 * assembly for arm or arm64, which mini-asm's parser makes the object
 * mini-ld links.
 *
 *     x.ml                                the modules, a unit's way
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
 * Three things a C compiler has not shape it (plan_ml.md's Context):
 * the types are inferred (Typing), a function is a value built as the
 * program runs (Lower's closures), and memory is never freed by hand,
 * so the code must leave every value where the collector finds it
 * (Gen's value stack). Each of those interfaces has its part of the
 * story; -dast, -dscope, -dir and -dssa print what is between two
 * passes, and are how to read them.
 *
 * Where it stands. mini-ml is the toolchain's second front end, after
 * mini-cc: it writes the assembler's objects and leaves to the linker
 * what the linker does for C (the frames of C's functions, the large
 * constants, a branch's reach, the executable's format). A program is
 * linked from its units, the standard library's, a start object and
 * the runtime, which is C:
 *
 *     x.ml, y.ml       mini-ml           x.5 y.5    \
 *     lib_core's units mini-ml           List.5 ...  |
 *     the units' names mini-ml -start    start.5     |  mini-ld: the
 *     runtime.c        mini-cc           runtime.5   |  program
 *     lib_core's libc  mini-cc, mini-asm,            |
 *                      mini-ar           libc.a     /
 *
 * mini-mk runs all this from a mkfile, with mini-ml -M for a unit's
 * dependencies. The programs of ix are compiled so, mini-ml itself
 * among them (the fixed point), and the kernel, mini-9pi, which then
 * runs programs compiled by the same compiler.
 *
 * What is ours. The contract is the behavior: a program prints what
 * it prints compiled by ocaml-light's ocamlopt; no listing is
 * compared, so each pass took the smaller road (tests in sequence for
 * a match, a stack machine and no register allocator, a copying
 * collector). The dialect has no functor, no object, no polymorphic
 * variant: a module is a name space known at compile time, flattened
 * by Resolve. No compiled interface: a unit's .mli is read again by
 * each unit that names it. No bytecode and no toplevel.
 *
 * evolution:
 * ML, from a theorem prover's command language to OCaml. In the
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
 * small enough for the PCs of the day: a bytecode interpreter, the
 * ZINC machine. Caml Special Light (1995) added the module system
 * and a compiler to native code, Objective Caml (1996) objects, and
 * OCaml 5 (2022) threads that run in parallel. ocaml-light, the
 * dialect and the reference here, is OCaml 1.07 kept alive: the
 * language before labels, polymorphic variants and GADTs.
 *
 * modern:
 * OCaml's own native compiler has more stations on the same way:
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
 * The command line: [help] in CLI.ml, what mini-ml -h prints. A
 * .mli is only parsed; an error on stderr, and the exit status 1.
 *
 * References: docs/plans/done/plan_ml.md, the decisions and their
 * reasons, and plan_ml_bootstrap.md for mlpp and the fixed point;
 * M. Gordon, R. Milner and C. Wadsworth, "Edinburgh LCF" (Springer
 * LNCS 78, 1979), where ML first is; Xavier Leroy, "The ZINC
 * experiment: an economical implementation of the ML language"
 * (INRIA technical report 117, 1990), Caml Light's design, and still
 * the best account of how an ML is compiled and why; Andrew Appel,
 * "Compiling with Continuations" (1992), Standard ML of New Jersey's
 * way, the other school; N. Courant, J. Lepiller and G. Scherer,
 * "Debootstrapping without Archeology: Stacked Implementations in
 * Camlboot" (The Art, Science, and Engineering of Programming 6(3),
 * 2022). *)

type caps = < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

val main : < caps; .. > -> string array -> int
