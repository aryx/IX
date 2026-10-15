(* A tiny ML compiler for arm64, in one file. Its full-size twin is
 * mini-ml (languages/ml/, planned in docs/plans/plan_ml.md), which
 * behaves like ocaml-light's native compiler: same dialect, modules,
 * and the kernel as a target. This file is what is left of an ML
 * compiler when the language is small and the code only needs to be
 * correct. Its usage, by examples, is in [help] below, which is what
 * tiny-ml -h prints.
 *
 * It reads one ML file (or several, compiled one after the other as a
 * single program, where an open M is accepted and ignored) and writes
 * its arm64 assembly, in Plan 9's syntax, for TinyAssembler. The
 * runtime (the allocator, Cheney's collector, the primitives, and the
 * printing of an uncaught exception) is in C, compiled by tiny-c, and
 * goken's libc sits under both. The test is that a program prints
 * exactly what ocaml-light's ocamlopt makes it print on arm64.
 *
 * With -tm, it compiles instead for tiny-machine (the CPU of
 * TinyMachineCPU.ml). It uses the same front end and stack machine
 * with a second back end (machine_tm), 4-byte words and 31-bit
 * integers. The common part of the runtime (TinyMLRuntime/core.c) is
 * compiled by tiny-c -tm, and the program's own main gives it memory.
 * TinyKernel.ml is the program it was made for: a kernel in ML, which
 * reaches the machine through externals (functions in C or assembly),
 * so the compiler needs no special primitive for it.
 *
 * How a file is compiled:
 *
 *     file.ml ...
 *        | lexer, parser     tokens to a tree, by recursive descent
 *        | type checker      checks types; records each label's index
 *        |                   and which comparisons are on integers
 *        | tree to stack     finds each function's free variables,
 *        | machine           turns patterns into tests, marks tail
 *        |                   calls: one [ir] list per function
 *        | machine_arm64     (or machine_tm) turns the list into
 *        |                   assembly, and static blocks into DATA
 *     file.s (or file.tm), for tiny-assembler (or tiny-machine)
 *
 * What a value looks like at run time (TinyMLRuntime/core.c has the
 * same picture, from the other side):
 *
 *     a word:   2n+1        the integer n: 10 is 21, false is 1, true
 *                           is 3, a constant constructor is its number
 *          or   an even address, of a block's first field
 *                    |
 *                    v
 *      | header | field 0 | field 1 | ...     a tuple, a record, a ref,
 *        size << 10, with the tag in          a constructor's arguments,
 *        the low byte                         an array: one word a field
 *
 *      | header, tag 247 | unary code | n-ary code | free variables...
 *                           a function value (a closure)
 *      | header, tag 252 | the bytes...       a string: holds no values
 *
 * And where values live, which is what the collector needs to know:
 *
 *     the value stack, top in R26       the machine stack, top in R31
 *       a function's frame:               return addresses
 *         its closure                     C frames (the runtime's)
 *         its parameters                  a try's record: both stack
 *         its variables                   tops, the handler's address,
 *         one slot per register, filled   the previous record
 *         at a call or an allocation
 *       every word is a value: these    never holds a value: the
 *       are the roots, along with the   collector never looks at it
 *       program's globals
 *
 * Between two calls a value may sit in R1..R15. At a call or an
 * allocation, the only two moments when a collection can happen, all
 * of them are stored in their slots and read back afterwards, because
 * the collector moves blocks.
 *
 * The language: integers (63 bits), characters, strings, booleans,
 * unit, tuples, lists, variants (type declarations, polymorphic and
 * recursive), records (mutable fields; e.l, e.l <- v, { l = e; ... },
 * and { l; ... } for { l = l; ... }; in patterns too, where _ stands
 * for the fields not named, as in { view; update = u; _ }),
 * arrays (Array.make, length, get and set, a.(i), a.(i) <- v),
 * references, and exceptions (declared, raised, caught). The constructs
 * are let, let rec, and, fun, function, match with guards, as and
 * or-patterns (without variables), if, sequences, while, for, and type
 * annotations (p : t). There is external, used by the prelude (the
 * Pervasives and List functions a program uses, written in ML; see
 * below). Types are Hindley-Milner with the value restriction. Strings
 * can span several lines. ix's capabilities are parsed and then ignored:
 * an object type in an annotation, or declared under a name, means any
 * type, and a coercion to one, (e :> t), is just e; OCaml checks them
 * when it builds the same file. A type can have a second name, as in
 * type word = piece list, without parameters. Left out: modules
 * (String.length is just one name), { r with ... }, floats, labels,
 * objects and functors.
 *
 * What keeps it small while still being an ML compiler:
 *
 * - {b Types are checked, then forgotten.} The checker (Hindley-Milner,
 *   with Rémy's levels for generalization) is a pass whose result the
 *   code generator uses in only two places: a comparison whose operands
 *   are integers is inlined, while the others call the runtime's
 *   polymorphic compare; and a record label becomes its field's index.
 *   Everything else has one representation: a word, which is either an
 *   integer 2n+1 or a pointer to a block (a header, then fields).
 * - {b A record is a tuple, and a label has a scheme like a
 *   constructor's}: %l(record, field), instantiated at each use. When
 *   the type of e is already known (from an annotation such as
 *   (p : proc)), a label is looked up in that record type, so two
 *   records can share a label name. This is OCaml's type-directed
 *   disambiguation, done cheaply (ocaml-light just takes the last
 *   declared label).
 * - {b A stack machine in between}, the same as TinyC's (IR, below):
 *   each expression pushes its value, the stack is kept in R1..R15, and
 *   a pattern becomes a sequence of tests, each jumping to the next
 *   clause on failure.
 * - {b A value stack for the roots} (plan_ml.md, decision 5;
 *   Henderson's shadow stack): each function's variables, and the
 *   registers spilled at a call or an allocation, are words on a stack
 *   of values whose top is R26, a register that 7c never allocates.
 *   The machine stack holds return addresses, C frames and exception
 *   handlers, but never a value. So the collector finds every root
 *   without a frame table, and can move them: it is Cheney's copying
 *   collector, in C.
 * - {b Closures, and direct calls of known functions.} A function is a
 *   block [unary code; n-ary code; free variables...]. Applying an
 *   unknown function passes one argument at a time through the first
 *   field; for an arity above 1, that field holds a curry function
 *   (ml_currynk), which gathers the arguments in blocks and then calls
 *   the n-ary code, like ocaml-light's caml_curryN. Calling a let-bound
 *   function with all its arguments calls its n-ary code directly, and
 *   a function without free variables is a static block. Calls in tail
 *   position are jumps, so a let rec loop runs in constant space.
 * - {b Exceptions with no assembly in the runtime.} try pushes a record
 *   on the machine stack (the stack pointer, R26, the handler's address,
 *   and the previous record); raise restores both stack pointers from
 *   the latest record and jumps. The handler's address is what a BL
 *   jumping over the handler leaves in R30, as with setjmp.
 * - {b Its own frames.} Every function is declared TEXT $-8, a frame
 *   that TinyAssembler leaves alone: the compiler writes the prologue
 *   and epilogue itself, so a tail call can pop the frame and jump.
 * - {b The prelude is in ML.} raise, the operators, ref, ! and := are
 *   externals whose names give the instruction ("%add"); print_string
 *   and ^ name C functions of the runtime; List.map and the others are
 *   ML compiled with the program, and only what the program uses is
 *   linked (TinyAssembler keeps only what the entry point reaches).
 *
 * Its behavior follows ocaml-light's arm64 ocamlopt, which is the
 * contract, quirks included: arguments, tuples and record fields are
 * evaluated right to left, except a.(i) <- v, which evaluates i, then
 * a, then v; stdout is buffered by 4096 bytes and the buffer is lost on
 * an uncaught exception; that exception is printed the way
 * ocaml-light's printexc.c prints it, with exit status 2; division by
 * zero gives 0 (what SDIV does) instead of raising an exception; an
 * out-of-bounds index into a string or an array is a fatal error; and
 * the empty array is a static block (OCaml's atom).
 *
 * Exercises, each cheap thanks to the stack machine or the value stack:
 * - arm32: a third back end for the stack machine (the -tm one took
 *   150 lines);
 * - inline allocation: keep the heap pointer and limit in two
 *   registers, and call the collector only when a block does not fit;
 * - fewer spills: at a call, spill only the registers below the
 *   arguments (the arguments are passed in registers and could stay
 *   there);
 * - a switch on constructor tags instead of one test per clause;
 * - exhaustiveness warnings (Maranget, "Warnings for pattern
 *   matching", 2007).
 *
 * Where it stands: TinyKernel, TinyKernelGraphics, TinyWindows,
 * TinyLibPlayground and TinyAppTetris are its programs (compiled with
 * -tm), and OCaml compiles the same files. Its runtime is C compiled by
 * TinyC, and its assembly is TinyAssembler's. The stack machine, with
 * its stack kept in registers, comes from TinyC, so the two compilers
 * read as one design used twice: what differs is everything C does not
 * have (type inference, closures, patterns, a collector). The ML
 * compiler that compiles ix itself is the other one, mini-ml (with
 * Typing, Resolve, and one back end per machine).
 *
 * cs-history:
 * ML is the Meta Language of Edinburgh's LCF, a proof assistant (Robin
 * Milner and others, 1973 to 1978): it was the language in which users
 * wrote proof strategies. Its types were there to make cheating
 * impossible, since a theorem was a value of an abstract type that only
 * the inference rules could build; its exceptions were how a strategy
 * failed; and type inference was there so that mathematicians did not
 * have to write types. The language outlived the prover's needs:
 * Standard ML (1980s), Caml at INRIA (1985), Xavier Leroy's and Damien
 * Doligez's Caml Light (1990), small enough for a PC, and OCaml
 * (1996). ocaml-light, whose outputs this compiler must match, is OCaml
 * 1.07 without objects and functors (plan_ml.md).
 *
 * design:
 * Using one representation for every value, a word, is what makes
 * polymorphism free: List.map is compiled once and works on a list of
 * anything, since it only moves words around. The price is paid
 * elsewhere: an integer loses a bit to say it is not a pointer, a float
 * would need a block of its own, and comparing two values of unknown
 * type means walking them at run time. The other road compiles a
 * function again for each type it is used at (MLton, C++ templates,
 * Rust): no tags, no boxes, but more code, and the whole program is
 * needed at once.
 *
 * modern:
 * OCaml and Go keep values in the machine's registers and stack, and
 * the compiler writes, for each call site, a table saying which slots
 * hold pointers; the collector uses it to walk the stack. That costs
 * nothing while the program runs, but a lot in the compiler and the
 * runtime (the stack must be parsed, in assembly or with great care).
 * The second stack used here costs a store and a load for each live
 * value around every call, but almost no code. LLVM offers the same
 * trade-off under the name shadow stack.
 *
 * others:
 * MinCaml (Eijiro Sumii, 2005) is the ML compiler people usually read
 * first: about two thousand lines of OCaml compiling to SPARC, one pass
 * per file (typing, K-normal form, closure conversion, register
 * allocation), with no polymorphism, no data types, and no collector.
 * Andrew Appel's Compiling with Continuations (1992) is the book about
 * the other road, through CPS, the one taken by Standard ML of New
 * Jersey.
 *
 * References (plan_ml.md's related work lists them too):
 *  - Robin Milner, "A Theory of Type Polymorphism in Programming"
 *    (1978)
 *  - Didier Rémy's levels, as explained in Oleg Kiselyov's "How OCaml
 *    type checker works" (2013)
 *  - Andrew Wright, "Simple imperative polymorphism" (1995): the value
 *    restriction
 *  - C. J. Cheney, "A nonrecursive list compacting algorithm" (CACM,
 *    1970)
 *  - Fergus Henderson, "Accurate garbage collection in an uncooperative
 *    environment" (ISMM 2002)
 *  - Simon Marlow and Simon Peyton Jones, "Making a fast curry"
 *    (ICFP 2004)
 *  - Xavier Leroy, "The ZINC experiment" (1990): the representation of
 *    values
 *)

(* a toplevel phrase, parsed and typed *)
type item

(* the program's phrases (each with its line) to assembly, added to the
 * output: every function's code, and ml_init, the toplevel *)
val compile : (item * int) list -> unit

(* the program: files of ML to a file of assembly (-h: how) *)
val main : < Cap.argv; Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr; Cap.exit; .. > -> unit
