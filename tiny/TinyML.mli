(* A tiny ML compiler for arm64, in one file. mini-ml (languages/ml/,
 * planned: docs/plans/plan_ml.md) is ocaml-light's native compiler's
 * twin in behavior: its dialect, its modules, the kernel as its target.
 * This is what is left of an ML compiler when the language is small and
 * the code need only be correct (its usage, by examples: [help] below,
 * what tiny-ml -h prints): one ML file in (or several, one after the
 * other as one program, an open M read and left), its arm64 assembly out, in Plan 9's syntax, for
 * TinyAssembler; the runtime (the allocator, Cheney's collector, the
 * primitives, the printing of an uncaught exception) in C, compiled by
 * tiny-c; goken's libc under both. A program prints what ocaml-light's
 * ocamlopt makes it print, on arm64: that is the test.
 *
 * Or, with -tm, for tiny-machine (TinyLibCPU.ml's CPU): the same front
 * end and stack machine, a second back end (machine_tm), words of 4
 * bytes and integers of 31 bits, the runtime's common part
 * (TinyML/core.c) compiled by tiny-c -tm, and the program's own main
 * giving it memory. TinyKernel.ml is its program: a kernel in ML, its
 * machine reached through externals (functions of C or of assembly),
 * so the compiler has no primitive for it.
 *
 * A file's way:
 *
 *     file.ml ...
 *        | lex, the parser   tokens to a tree, by recursive descent
 *        | the types         checked; a label's index and which
 *        |                   comparisons are of integers written down
 *        | from the tree to  a function's free variables found, its
 *        | the stack machine patterns made tests, its tail calls
 *        |                   marked: an [ir] list a function
 *        | machine_arm64     (or machine_tm) the list to assembly, and
 *        |                   the static blocks to DATA
 *     file.s (or file.tm), for tiny-assembler (or tiny-machine's)
 *
 * What a value is when it runs (TinyML/core.c has the same picture,
 * being the other side of it):
 *
 *     a word:   2n+1        the integer n: 10 is 21, false 1, true 3,
 *                           a constructor without arguments its number
 *          or   an address, even, of a block's first field
 *                    |
 *                    v
 *      | header | field 0 | field 1 | ...     a tuple, a record, a ref,
 *        size << 10, the tag in the           a constructor's arguments,
 *        low byte                             an array: each field a word
 *
 *      | header, tag 247 | unary code | n-ary code | free variables...
 *                           a function's value, a closure
 *      | header, tag 252 | the bytes...       a string: no value inside
 *
 * and where values are, which is what the collector must know:
 *
 *     the value stack, top R26          the machine stack, top R31
 *       a function's frame:               return addresses
 *         its closure                     C's frames, the runtime's
 *         its parameters                  a try's record: the two tops,
 *         its variables                   the handler's address, the
 *         a slot per register, filled     record before
 *         at a call or an allocation
 *       every word a value: the roots,  never a value: never looked at
 *       with the program's globals
 *
 * Between two calls a value may sit in R1..R15; at a call or an
 * allocation, the two moments a collection can happen, they are all
 * in their slots, and read back after: the collector moves blocks.
 *
 * The language: integers (63 bits), characters, strings, booleans,
 * unit, tuples, lists, variants (type declarations, polymorphic,
 * recursive), records (mutable fields; e.l, e.l <- v, { l = e; ... }),
 * arrays (Array.make, length, get and set, a.(i), a.(i) <- v), references, exceptions (declared, raised, caught); let, let rec,
 * and, fun, function, match with guards, as and or-patterns (without
 * variables), if, sequences, while, for; (p : t), annotations;
 * external, for the prelude (below: the Pervasives and List functions
 * a program uses, in ML); Hindley-Milner's types with the value
 * restriction. Left out: modules (String.length is one name), record
 * patterns and { r with ... }, floats, labels, objects,
 * functors, and type abbreviations.
 *
 * What makes it small, and still an ML compiler:
 *
 * - {b Types checked, then forgotten.} The checker (Hindley-Milner,
 *   Rémy's levels for generalization) is a pass whose result the code
 *   generator reads at two places: a comparison whose operands are
 *   integers is inlined, the others call the runtime's polymorphic
 *   compare; a record's label is its field's index. Everything else is
 *   one representation: a word, an integer 2n+1 or a pointer to a
 *   block (a header, then fields).
 * - {b A record is a tuple, a label a constructor's kind of scheme}:
 *   %l(record, field), instantiated at each use. A label is looked up
 *   in the record e already is when its type is known (an annotation,
 *   (p : proc)), so two records may share one: OCaml's type-directed
 *   disambiguation, cheaply (ocaml-light's labels: the last declared).
 * - {b A stack machine in between}, TinyC's (IR, below): expressions
 *   push their value, the stack in R1..R15, and a pattern is a
 *   sequence of tests, each jumping to the next clause.
 * - {b A value stack for the roots} (plan_ml.md, decision 5;
 *   Henderson's shadow stack): each function's variables, and the
 *   registers spilled at a call or an allocation, are words of a stack
 *   of values whose top is R26, a register 7c never allocates. The
 *   machine's stack holds return addresses, C's frames and exception
 *   handlers, never a value; so the collector finds every root without
 *   a frame table, and moves them: Cheney's copying collector, in C.
 * - {b Closures, and calls of known functions.} A function is a block
 *   [unary code; n-ary code; free variables...]. Applying an unknown
 *   function passes one argument at a time through the first field;
 *   for an arity above 1 that is a curry function (ml_currynk), which
 *   gathers the arguments in blocks and calls the n-ary code, as
 *   ocaml-light's caml_curryN. A call of a let-bound function with
 *   all its arguments calls its n-ary code directly; a function
 *   without free variables is a static block. Calls in tail position
 *   are jumps, so a let rec loop runs in constant space.
 * - {b Exceptions without assembly in the runtime.} try pushes a
 *   record on the machine stack (the stack pointer, R26, the handler's
 *   address, the previous record); raise restores the two stack
 *   pointers from the latest and jumps. The handler's address is
 *   what a BL over it leaves in R30, as setjmp.
 * - {b Its own frames.} Every function is TEXT $-8, a frame
 *   TinyAssembler leaves alone: the prologue and epilogue are the
 *   compiler's, so a tail call can undo the frame and jump.
 * - {b The prelude is ML}: raise, the operators, ref, ! and := are
 *   externals whose names say the instructions ("%add"); print_string
 *   or ^ name C functions of the runtime; List.map and the others are
 *   ML, compiled with the program, and only what the program uses is
 *   linked (TinyAssembler keeps what the entry reaches).
 *
 * Its behavior follows ocaml-light's arm64 ocamlopt, the contract,
 * quirks included: right-to-left evaluation of arguments, tuples and
 * a record's fields, but a.(i) <- v's, i, a, then v;
 * stdout buffered by 4096 bytes and lost on an uncaught exception;
 * that exception printed as ocaml-light's printexc.c prints it, with
 * the exit status 2; division by zero is 0 (SDIV's), not an
 * exception; a string's or an array's index out of bounds a fatal
 * error; an array's empty block static (OCaml's atom).
 *
 * Exercises, each cheap because of the stack machine or the value
 * stack:
 * - arm32: a third back end of the stack machine (-tm's was 150 lines);
 * - allocation inline: the heap's pointer and limit in two registers,
 *   the collector called only when the block doesn't fit;
 * - fewer spills: at a call, only the registers below the arguments
 *   (the arguments are passed in registers, and could stay there);
 * - a switch on the constructors' tags instead of a test per clause;
 * - exhaustiveness warnings (Maranget, "Warnings for pattern
 *   matching", 2007).
 *
 * Where it stands: TinyKernel, TinyGraphics, TinyWindows,
 * TinyPlayground and TinyTetris are its programs (with -tm), and OCaml
 * compiles the same files; its runtime is C for TinyC, and its
 * assembly TinyAssembler's. The stack machine and the stack kept in
 * registers are TinyC's, so the two compilers read as one design used
 * twice: what differs is all that C does not have (types inferred,
 * closures, patterns, a collector). The ML that compiles ix is the
 * other one, mini-ml (Typing, Resolve, and a back end by machine).
 *
 * cs-history:
 * ML is the Meta Language of Edinburgh's LCF, a proof assistant
 * (Robin Milner and others, 1973 to 1978): the language in which a
 * user wrote proof strategies. Its types were there to make cheating
 * impossible, a theorem being a value of an abstract type that only
 * the inference rules could build; its exceptions were a strategy
 * that fails; and inference was there so that a mathematician did not
 * have to write the types. The language outlived the prover's
 * needs: Standard ML (1980s), Caml at INRIA (1985), Xavier Leroy's
 * and Damien Doligez's Caml Light (1990), small enough for a PC, and
 * OCaml (1996). ocaml-light, whose outputs this compiler is held to,
 * is OCaml 1.07 without its objects and functors (plan_ml.md).
 *
 * design:
 * One representation for every value, a word, is what makes
 * polymorphism free: List.map is compiled once and works on a list of
 * anything, since it only moves words. The price is paid elsewhere:
 * an integer loses a bit to say it is not a pointer, a float would
 * live in a block of its own, and comparing two values of unknown
 * type is a walk at run time. The other road compiles a function
 * again for each type it is used at (MLton, C++'s templates, Rust):
 * no tag, no box, more code, and the whole program needed at once.
 *
 * modern:
 * OCaml and Go keep values in the machine's registers and stack, and
 * the compiler writes for each call site a table saying which slots
 * hold pointers; the collector walks the stack with it. That costs
 * nothing while the program runs and much in the compiler and the
 * runtime (the stack must be parsed, in assembly or with care). The
 * second stack here costs a store and a load for each live value
 * around every call, and nearly no code; LLVM offers the same trade
 * under the name shadow stack.
 *
 * others:
 * MinCaml (Eijiro Sumii, 2005) is the ML compiler usually read first:
 * about two thousand lines of OCaml to SPARC, a pass a file (typing,
 * K-normal form, closure conversion, register allocation), no
 * polymorphism, no data types, no collector. Andrew Appel's Compiling
 * with Continuations (1992) is the book of the road through CPS, that
 * of Standard ML of New Jersey.
 *
 * References: Robin Milner, "A Theory of Type Polymorphism in
 * Programming" (1978); Didier Rémy's levels, as Oleg Kiselyov's "How
 * OCaml type checker works" (2013) explains them; Andrew Wright, "Simple
 * imperative polymorphism" (1995), the value restriction; C. J. Cheney,
 * "A nonrecursive list compacting algorithm" (CACM, 1970); Fergus
 * Henderson, "Accurate garbage collection in an uncooperative
 * environment" (ISMM 2002); Simon Marlow and Simon Peyton Jones,
 * "Making a fast curry" (ICFP 2004); Xavier Leroy, "The ZINC experiment"
 * (1990), the representation of values (all from memory; plan_ml.md's
 * related work has them). *)

(* a toplevel phrase, parsed and typed *)
type item

(* the program's phrases (each with its line) to assembly, added to the
 * output: every function's code, and ml_init, the toplevel *)
val compile : (item * int) list -> unit

(* the program: files of ML to a file of assembly (-h: how) *)
val main : < Cap.argv; Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr; Cap.exit; .. > -> unit
