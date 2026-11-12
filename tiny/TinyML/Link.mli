(* tiny-ml's part of a link: it makes a program's start with ml -o
 * prog.start.o lib.a... file.o..., and tiny-ld then links that start
 * with the program's files. Read Compile.mli first.
 *
 * An ML program needs a start and a C program does not, because some
 * code can only be made once the whole program is known:
 *
 *     ml_init      calls the initialization of each unit (a unit's
 *                  toplevel lets are code to run), in link order,
 *                  inside a handler that reports an uncaught exception
 *     ml_globals   the globals of every unit in one table, which are
 *                  the collector's roots (runtime/ml/ml.c), and their
 *                  count, ml_nglobals
 *     curry        the functions that apply a closure to some of its
 *                  arguments, once for each arity the units use
 *
 * TinyML.ml makes the start from the units' interfaces. It is given
 * the files the program is linked from:
 * - an object file, whose interface is next to it (M.tmi next to M.o);
 * - a library, whose members' interfaces are next to the library
 *   (List.tmi next to stdlib.a), taken in the library's order (the one
 *   tiny-ar or ar -t lists). So a library of several files, such as
 *   graphics.a, is linked just as stdlib.a is, its list being inside
 *   it;
 * - other files (the runtimes, C code), which have no interface and
 *   play no part.
 * The order of the units is the order of initialization, which is
 * OCaml's rule: the libraries first, each after those it uses, then
 * the program's units. tiny-ld links the start with the program's
 * files, right after mlsys.o, which calls it. In the Buildfile each
 * program has its own rule and one for its start, which names the
 * same files, and never an interface:
 *
 *     square.start.o: $STDLIB $SQUARE
 *     square: $CRT $MLRT square.start.o $STDLIB $SQUARE $MLEND
 *         ld -map -s -n -o $target $prereq
 *     %.start.o:
 *         ml -o $target $prereq
 *
 * others:
 * OCaml makes the same start at link time (caml_program, caml_globals
 * and caml_curryN): ocamlopt -o prog makes it, then calls the system's
 * linker itself. Here the Buildfile runs the two, one tool per step.
 * C++ took another road for its static constructors: each object file
 * has an .init_array section, which the linker concatenates and the
 * runtime walks before main, so no start is made. A tiny-ld that knew
 * sections by name would let tiny-ml do the same. *)

(* [compile_start units needed] adds the program's start to the
 * assembly being made (Machine's). [units] gives each unit's name and
 * number of globals, in order; [needed] gives the arities of the curry
 * functions they need. *)
val compile_start : (string * int) list -> int list -> unit
