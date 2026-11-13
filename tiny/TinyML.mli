(* A tiny ML compiler for tiny-machine. This file is the driver, and
 * the passes are in TinyML/. Its full-size twin is mini-ml
 * (languages/ml/, planned in docs/plans/plan_ml.md), which behaves like
 * ocaml-light's native compiler: the same dialect, modules, and the
 * kernel as a target. tiny-ml is what is left of an ML compiler when
 * the language is small and the code only needs to be correct. Its
 * usage, by examples, is in [help] in TinyML.ml, which is what
 * tiny-ml -h prints.
 *
 * It reads ML files, one unit per file (with -c, a single file, after
 * the interfaces of the units it uses), and writes assembly for
 * tiny-machine (the CPU of TinyMachineCPU.ml), where words are 4 bytes
 * and integers are 31 bits. The runtime is in C, in runtime/ml/ml.c,
 * compiled by tiny-cc: it has the allocator, Cheney's collector, the
 * primitives, and the code that prints an uncaught exception. The
 * program's own main gives the runtime its memory. The program
 * tiny-ml was made for is TinyKernel.ml, a kernel in ML. The kernel
 * reaches the machine through externals (functions written in C or
 * assembly), so the compiler needs no special primitive for it.
 *
 * How a file is compiled:
 *
 *     file.ml ...         one unit per file (with -c, the M.tmi files
 *        |                of the units it names, found by -I)
 *        | lexer, parser     tokens, then a tree, by recursive descent
 *        | type checker      checks the types; records the index of each
 *        |                   label, and which comparisons are on
 *        |                   integers
 *        | compiler          finds the free variables of each function,
 *        |                   turns patterns into tests, marks tail
 *        |                   calls; the result is one [ir] list per
 *        |                   function, the code of a stack machine
 *        | machine           turns the list into assembly, and static
 *        |                   blocks into .word directives
 *     file.o holds the assembly lines, encoded by TinyLibMachine's
 *     assemble, for tiny-ld (with -c, M.tmi is written too); with -S,
 *     file.s holds them as text
 *
 * Each pass is a module in TinyML/. Its .mli has its types and its
 * functions. In the order they run, which is also the best order to
 * read them:
 *
 *     Lexer.mli    the tokens ([token]) and lex
 *     Tree.mli     the tree: [ty], [expr], [pat], and a unit's [item]s;
 *                    the tables of constructors and labels
 *     Formats.mli  Printf's formats, turned into concatenations
 *     Parser.mli   parse: the text of a file to its [item]s
 *     Types.mli    type_unit: types the items (Hindley-Milner)
 *     Machine.mli  the stack machine ([ir]) and how it becomes
 *                    assembly, TinyLibMachine.mli's [line]s
 *     Compile.mli  bind: the typed tree to the stack machine
 *     Link.mli     the start of a program, made at link time
 *
 * This file is the program around them. compile_unit runs a unit's
 * items through the passes; Link makes a program's start; and this
 * file writes the interface (M.tmi) that a unit leaves for the units
 * compiled after it.
 *
 * What a value looks like at run time (runtime/ml/ml.c has the same
 * picture, seen from the C side):
 *
 *     a word:   2n+1        the integer n: 10 is 21, false is 1, true
 *                           is 3, a constant constructor is its number
 *          or   an even address, that of a block's first field
 *                    |
 *                    v
 *      | header | field 0 | field 1 | ...     a tuple, a record, a ref,
 *        size << 10, with the tag in          a constructor's arguments,
 *        the low byte                         an array: one word per field
 *
 *      | header, tag 247 | unary code | n-ary code | free variables...
 *                           a function value (a closure)
 *      | header, tag 252 | the bytes...       a string: holds no values
 *
 * And where values live, which is what the collector needs to know:
 *
 *     the value stack, top in r12       the machine stack, top in sp
 *       a function's frame:               return addresses
 *         its closure                     C frames (the runtime's)
 *         its parameters                  the record of each try: both
 *         its variables                   stack tops, the handler's
 *         one slot per register, filled   address, the previous record
 *         at a call or an allocation
 *       every word is a value: these    never holds a value: the
 *       are the roots, along with the   collector never looks at it
 *       program's globals
 *
 * Between two calls a value may sit in r1..r11. A collection can
 * happen only at a call or an allocation. At those two moments all
 * the registers are stored in their slots and read back afterwards,
 * because the collector moves blocks.
 *
 * The language:
 * - Values: integers (31 bits), characters, strings, booleans, unit,
 *   tuples, lists, variants (type declarations, polymorphic and
 *   recursive), arrays (Array.make, length, get and set, a.(i),
 *   a.(i) <- v), references, and exceptions (declared, raised, caught).
 * - Records, with mutable fields: e.l, e.l <- v, { l = e; ... }, and
 *   { l; ... } for { l = l; ... }. Patterns can be records too, where _
 *   stands for the fields not named, as in { view; update = u; _ }.
 *   { e with l = e'; ... } makes a copy of the same type.
 * - Constructs: let, let rec, and, fun, function, match with guards, as
 *   and or-patterns (without variables), if, sequences, while, for, and
 *   type annotations (p : t). There is also external, which the
 *   standard library uses (TinyLibCore/, written in ML; see below).
 * - Types are Hindley-Milner with the value restriction.
 * - Strings can span several lines. {|quoted strings|} are read too,
 *   as in OCaml (for a help text).
 * - ix's capabilities are parsed and then ignored. An object type in an
 *   annotation, or declared under a name, means any type, and a
 *   coercion to one, (e :> t), is just e. OCaml checks them when it
 *   builds the same file.
 * - A type can be given a second name, as in type word = piece list,
 *   also with parameters, as in Seq's type 'a t = unit -> 'a node.
 * - A module is a file, which we call a unit (M.x, open M). Its types,
 *   constructors and labels are M.t and M.C, and are also found bare in
 *   the units that open M (see design: below). This is how two units
 *   can each have their own Add.
 * - Inside a unit, module N = struct ... end may hold values only. The
 *   units after it name them N.x, or open M.N (as with open
 *   Fpath_.Operators). Inside N, a name is not found by its short name.
 * - module A = M gives a unit another name (module ISA =
 *   TinyLibMachine); M.x still means M.x.
 * - An attribute, [@@deriving show] or another, is read and dropped
 *   (OCaml derives show when building on the host). The format in
 *   Logs.debug (fun m -> m "fmt" args) is read as a Printf format
 *   (Formats).
 * - Operators are OCaml's: any run of operator characters, defined by
 *   let ( // ) = .... The precedence of an operator is that of its
 *   first character. A prefix operator starts with !, ~ or ?.
 * - Left out: modules inside modules, types inside them, functors,
 *   floats, labeled arguments, objects, or-patterns that bind names,
 *   character ranges and inline records. The tools and the toolchain
 *   were rewritten without them.
 *
 * The behavior follows ocaml-light's arm64 ocamlopt, which was the
 * contract, quirks included (plan_tiny_self_hosting.md removes the
 * quirks, since OCaml is now the reference):
 * - Arguments, tuples and record fields are evaluated right to left,
 *   except a.(i) <- v, which evaluates i, then a, then v.
 * - stdout is buffered by 4096 bytes, and the buffer is lost on an
 *   uncaught exception.
 * - An uncaught exception is printed as ocaml-light's printexc.c
 *   prints it, with exit status 2.
 * - A division by zero gives whatever the machine's div gives, instead
 *   of raising an exception.
 * - An out-of-bounds index into a string or an array is a fatal error.
 * - The empty array is a static block (OCaml's atom).
 *
 * twin:
 * mini-ml's simple back end (Gen) has the same design: a stack machine
 * kept in registers, the values on a stack of their own, and Cheney's
 * collector in C (decision 5 of plan_ml.md covers both compilers).
 * mini-ml has no functors either. The differences are these: mini-ml's
 * parser is made with ocamlyacc, while tiny-ml's is recursive descent;
 * mini-ml writes Plan 9's assembly for arm and arm64, and has -O and an
 * SSA back end with a register allocator, while tiny-ml has one machine
 * and no optimization. On one point tiny-ml goes further: mini-ml has no
 * compiled interface (each unit that names another reads its .mli
 * again), while tiny-ml writes M.tmi, like OCaml's .cmi, which also
 * records where each value is, something an .mli does not say.
 *
 * kept:
 * What keeps it small while still being an ML compiler:
 * - {b Types are checked, then forgotten.} The checker (Hindley-Milner,
 *   with Rémy's levels for generalization) is a pass whose result the
 *   code generator uses in only two places: a comparison whose operands
 *   are integers is inlined, while the others call the runtime's
 *   polymorphic compare; and a record label becomes its field's index.
 *   Everything else has one representation: a word, which is either an
 *   integer 2n+1 or a pointer to a block (a header, then fields).
 * - {b A record is a tuple, and a label has a type scheme like a
 *   constructor's}. The scheme is %l(record, field), and it is
 *   instantiated at each use. When
 *   the type of e is already known (from an annotation such as
 *   (p : proc)), the label is looked up in that record type, so two
 *   records can share a label name. This is OCaml's type-directed
 *   disambiguation, done cheaply (ocaml-light just takes the label
 *   declared last).
 * - {b A stack machine in between.} It is the same design as TinyC's
 *   (TinyC/Lower.mli), written again here (Machine). Each expression
 *   pushes its value, the stack is kept in r1..r11, and a pattern
 *   becomes a sequence of tests, each jumping to the next clause when
 *   it fails.
 * - {b A value stack for the roots} (decision 5 of plan_ml.md, which is
 *   Henderson's shadow stack). The variables of each function, and the
 *   registers spilled at a call or an allocation, are words on a stack
 *   of values whose top is in r12. After a call to C, which preserves
 *   no register, r12 is reloaded from ml_vsp. The machine stack holds
 *   return addresses, C frames and exception handlers, but never a
 *   value. So the collector finds every root without a frame table,
 *   and can move the blocks: it is Cheney's copying collector, in C.
 * - {b Closures, and direct calls of known functions.} A function is a
 *   block [unary code; n-ary code; free variables...]. Applying an
 *   unknown function passes one argument at a time through the first
 *   field. For an arity above 1, that field holds a curry function
 *   (ml_currynk), which gathers the arguments in blocks and then calls
 *   the n-ary code, like ocaml-light's caml_curryN. Calling a let-bound
 *   function with all its arguments calls its n-ary code directly, and
 *   a function without free variables is a static block. Calls in tail
 *   position are jumps, so a let rec loop runs in constant space.
 * - {b Units, and a link that leaves out what nothing uses.} A file is
 *   a unit. Its symbols are prefixed with its name
 *   (TinyLibGUI.f12_layout), its toplevel code is in TinyLibGUI.init,
 *   and the values it computes are in its table of globals. Compiled
 *   alone (-c), a unit writes its interface, M.tmi, which the units
 *   after it read. Like OCaml's .cmi, it is a marshalled record with
 *   the types and constructors the unit added, and for each name, where
 *   its value is (a static closure or a global) and its type (the one
 *   from M.mli when there is one). A program's main (ml_start, which
 *   calls each unit's init in order, plus the curry functions and the
 *   tables) is made from the interfaces.
 * - {b A unit is a module.} Its names are M.x in the units after it, or
 *   x after open M. Stdlib is open in all units. The standard library,
 *   which is the modules of TinyLibCore/, makes the first units of
 *   every program. Each
 *   is compiled once (-L ., in TinyLibCore/), and a unit reads the
 *   interfaces of those it names from a directory (/lib/ml, or the one
 *   given by -L). A type, a constructor and a label belong to their
 *   unit (M.t, M.C), and are found bare in that unit, in what it opens,
 *   and in Stdlib (see design: below).
 * - {b Each function and static block is a piece} (.piece), and tiny-ld
 *   leaves out a piece that nothing reaches. A toplevel function has no
 *   free variable, so its closure is static and the init code does not
 *   name it. So a library costs a program only what it calls:
 *   tiny-kernel's calc is 153 KB, and would be 206 KB with all of its
 *   libraries.
 * - {b Exceptions with no assembly in the runtime.} try pushes a record
 *   on the machine stack: the stack pointer, r12, the handler's
 *   address, and the previous record. raise restores both stack
 *   pointers from the latest record and jumps. The handler's address is
 *   what a call that jumps over the handler leaves in lr, as with
 *   setjmp.
 * - {b Its own frames.} The compiler writes the prologue and epilogue
 *   of each function itself, so a tail call can pop the frame and jump.
 * - {b The standard library is in ML.} raise, the operators, ref, ! and
 *   := are externals whose names give the instruction ("%add").
 *   print_string and ^ name C functions of the runtime. List.map and
 *   the others are ML code, in TinyLibCore/'s units, and only what the
 *   program uses is linked (see above).
 *
 * dropped:
 * Compared with OCaml's ocamlopt, tiny-ml leaves out the parts of the
 * language that mini-ml leaves out too: functors, classes and objects
 * (except the capabilities' object types, which are read and ignored),
 * polymorphic variants, GADTs and optional arguments. Compared with
 * mini-ml, it leaves out the floats and the labeled arguments (the
 * language left out above), the help for debugging, and the young
 * generation. There is no -g, so there is no table from pcs to the
 * lines of the .ml and no description of the types of the values. An
 * uncaught exception is therefore printed without the trace of its
 * calls, and tiny-kernel's debug names functions, not lines.
 * [@@deriving show] is read and dropped, while mini-ml's mlpp derives
 * the printers, so a tree is printed by hand or on the host. Every
 * collection copies all that is alive, which costs most to a program
 * with many old blocks.
 *
 * twist:
 * {b Printf without a type for formats.} A call of Printf.sprintf,
 * ksprintf or bprintf whose format is a string written at the call is
 * rewritten by the parser into the concatenation it makes (Formats), so
 * the type checker never sees a format and nothing reads it at run time.
 * mini-ml types a format as OCaml does, with a format4 type computed
 * from the string, and its Printf interprets the format as the program
 * runs. The price is that a format must be written at the call, and
 * that only %d %s %c %x %S are read.
 *
 * context:
 * tiny-ml compiles every ML program of tiny-kernel, starting with the
 * kernel and tiny-ml itself, and OCaml compiles the same files on the
 * host. Its runtime is C compiled by TinyC, and its assembly is
 * TinyMachineCPU's. The stack machine with its stack kept in registers
 * comes from TinyC, so the two compilers read as one design used
 * twice; what differs is everything C does not have (type inference,
 * closures, patterns, a collector). The ML compiler that compiles ix
 * itself is the other one, mini-ml (with Typing, Resolve, and one back
 * end per machine).
 *
 * exercises:
 * Each is cheap thanks to the stack machine or the value stack:
 * - arm32: a second back end for the stack machine (the one for
 *   tiny-machine took 150 lines);
 * - inline allocation: keep the heap pointer and limit in two
 *   registers, and call the collector only when a block does not fit;
 * - fewer spills: at a call, spill only the registers below the
 *   arguments (the arguments are passed in registers and could stay
 *   there);
 * - a switch on constructor tags instead of one test per clause;
 * - exhaustiveness warnings (Maranget, "Warnings for pattern
 *   matching", 2007);
 * - a -debug flag that prints the typed tree, with [@@deriving show]
 *   and Logs.debug, as tiny-ld and tiny-shell do.
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
 * (1996). ocaml-light, whose outputs this compiler first matched, is
 * OCaml 1.07 without objects and functors (plan_ml.md).
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
 * design:
 * Names have no pass of their own, only one rule, taken from Caml
 * Light. A type, a constructor, a record label and a value belong to
 * the unit that declares them: they are M.t, M.C and M.x in global
 * tables (in Tree: cons, record_labels, abbreviations, declared; and
 * the value tables of Types and Compile). A bare name in a unit means
 * the one in scope: the unit's own, then those of the units it opens
 * (the latest open first), then Stdlib's, which is open in all
 * (Names, in Tree.ml). The parser qualifies each name as it reads it,
 * so a declaration is usable at once, no environment is threaded
 * through the passes, and the meaning of a name comes from the source,
 * not from the order in which the interfaces were read. This rule
 * replaced bare strings for types, constructors and labels, where the
 * one declared or read last won. Every place where two units' names
 * met then needed a rule of its own, until In_channel's t and Fpath's
 * t became the same name, and In_channel.input took a string whenever
 * Fpath's interface was read last. OCaml finds a constructor or a type
 * by the type it is used at; tiny-ml cannot, so a bare name from a
 * unit that is not open must be the only one with that name, and two
 * candidates are an error that asks which one is meant (M.C). OCaml
 * goes further, with paths of stamped identifiers in an environment.
 * m-ix's mini-ml has a Resolve pass, after which a type is its
 * declaration itself (Scope's tdecl, with its full path) and no name
 * is looked up again: more code, in a pass of its own.
 *
 * references:
 * The related work section of plan_ml.md lists them too:
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

(* Appends the functions' code and <unit>.init, the toplevel code, to
 * the assembly. Returns the names defined and the number of globals. *)
val compile_unit :
  (Tree.item * int) list -> (string * Compile.binding) list * int

(* tiny-ml -h tells how to use it. ml -o prog.start.o lib.a... file.o...
 * makes the start, which only the whole program can make
 * (TinyML/Link.mli). *)
val main :
  < Cap.open_in; Cap.open_out; Cap.readdir; Cap.stdout; Cap.stderr; .. > ->
  string array -> Exit.t
