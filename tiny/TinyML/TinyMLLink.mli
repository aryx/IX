(* tiny-ml's part of a link: a program's start, ml -o prog.start.o
 * lib.a... file.o..., which tiny-ld then links with the program's
 * files. Read TinyMLCompile.mli first.
 *
 * Why an ML program needs a start, and a C program does not: code that
 * only the whole program can make.
 *
 *     ml_init      each unit's initialization (its toplevel's lets are
 *                  code to run), called in the link's order, in a
 *                  handler that says an exception nothing caught
 *     ml_globals   every unit's globals in one table, the collector's
 *                  roots (runtime/ml.c), and their count, ml_nglobals
 *     curry        the functions that apply a closure to some of its
 *                  arguments, for the arities the units use, once
 *
 * TinyML.ml makes it from the units' interfaces, given the files the
 * program is linked from: an object with its interface beside it (M.tmi
 * beside M.o), and a library's members, each's interface beside the
 * library (List.tmi beside stdlib.a), in the library's order (tiny-ar's,
 * ar -t's), so that a library of several files, a graphics.a, is linked
 * as stdlib.a is, its list in itself; the other files (the runtimes',
 * C's) have no interface, and no part in it. The units' order is the
 * initializations', OCaml's rule: the libraries first, each after those
 * it uses, then the program's units. tiny-ld links the start with
 * the program's files, right after mlsys.o, which calls it. In the
 * Buildfile, each program is its rule and its start's, which names the
 * same files, and never an interface:
 *
 *     square.start.o: $STDLIB $SQUARE
 *     square: $CRT $MLRT square.start.o $STDLIB $SQUARE $MLEND
 *         ld -map -s -n -o $target $prereq
 *     %.start.o:
 *         ml -o $target $prereq
 *
 * others:
 * OCaml makes the same start at the link, caml_program, caml_globals
 * and caml_curryN, by ocamlopt -o prog, which then calls the system's
 * linker itself; here the Buildfile runs the two, a tool for each step
 * (old, 2026-11-12, a day: ml ran tiny-ld, as ocamlopt). C++ took
 * another road for its static constructors: each object's in an
 * .init_array section, which the linker puts together and the runtime
 * walks before main, no start made; a tiny-ld that knew sections by
 * name would let tiny-ml do the same. (old: the start made from every
 * unit's .tmi, given in their order, a list for each program in the
 * Buildfile) *)

(* [compile_start units needed]: the program's start, in the assembly
 * being made (TinyMLMachine's): the units, each its name and how many
 * globals, in their order; the arities of the curry functions they
 * need *)
val compile_start : (string * int) list -> int list -> unit
