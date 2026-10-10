(* mini-cc: a C compiler, Plan 9's 5c (arm) and 7c (arm64) in one
 * program. A file is read once, a function at a time: its body is
 * parsed into a tree, typed, made instructions, and forgotten; at the
 * end the instructions are written as the object mini-ld links.
 *
 *     x.c                              the modules, a function's way
 *        | Pre       #include, #define: inputs pushed on a stack, as
 *        |           the lexer meets them; no pass of its own
 *     characters
 *        | Lexer     ocamllex's; a name is a type's or not by its
 *        |           symbol, which the parser has just declared
 *     tokens
 *        | Parser    ocamlyacc's, cc.y's grammar; its actions call
 *        |           Declare: a type built around a name, scopes,
 *        |           offsets in the frame, initializers made data
 *     Tree.stmt      a function's body (-x prints it: Prtree)
 *        | Check     each expression typed, its conversions made
 *        |           nodes, its constants folded (Com64: on arm, a
 *        |           vlong's operators made calls)
 *        |
 *        |-- compat (the default): 5c's and 7c's code, the same bytes
 *        |     Acom, Cgen with Regs and Multiply; Arm or Arm64
 *        '-- simple (-simple): the same behavior, a simpler way
 *              Lower, to Ir's stack machine; Opti (-O); Gen; Peep
 *     Emit.prog      Plan 9's instructions (-S prints them)
 *        | Emit.obj
 *     Asm.obj        x.5 or x.7: what mini-asm makes of a .s
 *
 * (-facts and -flow stop on the way and print Datalog facts: Facts,
 * Ir_facts.) The front end is one for both machines, Machines says
 * what it must know of each (the sizes, what goes in a register), and
 * a back end is given to it as four functions (Check.xcom and
 * outstring, Declare.gextern and on_function), set here.
 *
 * Where it stands. The compiler never gives an address and never
 * encodes an instruction: it writes MOVW x+0(FP),R4 as a value of the
 * assembler's types, exactly what mini-asm writes for the same line
 * of a .s (mini-cc -S f.c | mini-asm makes mini-cc f.c's object), and
 * mini-ld does the rest for both: frames, constants too large for an
 * instruction, branches' reach, division on arm, the executable. The
 * C it compiles every day is lib_core's libc and mini-ml's runtime;
 * mini-ml is the linker's other client, and its back end and this
 * compiler's second one are one design, TinyC's.
 *
 * What is ours. Two back ends on one front end, to compare them on
 * the same C: compat is a twin of goken's 5c -O0 and 7c -O0, its
 * listings the same byte for byte (the contract that keeps it
 * honest), simple is free of it and a third of the size, and Opti says
 * what it takes to catch up. One code generator and a record a
 * machine, where Plan 9 has a directory a machine, copies that
 * drifted (plan_cc.md counted: 77% the same). Trees as variants
 * (Tree). Not here: 5c's registerization and peephole (reg.c,
 * peep.c; Opti's regs and Peep are simple's, freely), and the
 * warnings.
 *
 * evolution:
 * C, from a typeless language to this one. Martin Richards's BCPL
 * (1967) had one type, the machine's word; Ken Thompson's B (1969),
 * for the first Unix on the PDP-7, was BCPL squeezed into 8K bytes.
 * The PDP-11 broke the word: it had bytes, and soon floating point,
 * and a language where everything is a word could address neither
 * well. Dennis Ritchie added types to B (char, int, pointers and
 * arrays, with the rule that an array's name becomes a pointer to
 * its first element), called it NB and then, in 1972, C; structures
 * came in 1973, and with them the Unix kernel was rewritten in it.
 * "The C Programming Language" (Kernighan and Ritchie, 1978) was
 * the definition until ANSI's (1989), which added prototypes, and
 * C99. Plan 9's C is ANSI's less some and plus some, the
 * restrictions mostly "due to personal preference", Thompson says:
 * no #if; unnamed members of a structure.
 *
 * cs-history:
 * The compilers. Ritchie's own, for the PDP-11, was written for
 * that machine. Steve Johnson's pcc (1978) was the one written to
 * be moved: a front end by yacc, and a code generator driven by
 * tables of templates for a machine; it is what carried Unix to the
 * Interdata and the VAX, and many C compilers of the 1980s were
 * ports of it. Thompson's compilers for Plan 9 (1990) started over
 * with another split: one front end, a small back end written by
 * hand for each machine ("less than 500 lines of C" for the code
 * generator), and a linker that finishes the instructions. His own
 * verdict: they "compile quickly, load slowly, and produce medium
 * quality object code", and porting one is "a couple of weeks'
 * work". They became Go's first compilers (6g, 8g and 5g were 6c,
 * 8c and 5c with another front end), translated to Go in 2015.
 *
 * plan9-is-cleaner:
 * A Unix cc is a driver that runs four programs: the preprocessor
 * writes a text, the compiler reads it and writes assembly, the
 * assembler reads that and writes an object, the linker links. Here
 * the first three are one program with no text between them, and
 * the compiler for another machine is the same program with another
 * letter (-m 5, -m 7; in Plan 9 5c, vc, 8c): there is no native
 * compiler and no cross compiler, since none knows which machine it
 * runs on. A program is built for every machine from one tree by
 * setting a variable in a mkfile.
 *
 * terminology:
 * The letters. Plan 9 names a machine's tools by one character: 5c,
 * 5a, 5l the compiler, assembler and linker for arm, and x.5 their
 * object; 8 is the 386, 6 amd64, v the MIPS, k the SPARC, q the
 * PowerPC. 7 was the Alpha's; arm64 took it later, as here. What
 * Unix calls the linker Plan 9 calls the loader.
 *
 * modern:
 * gcc and clang put between the tree and the instructions what is
 * not here at all: a form in SSA (Ssa, in mini-ml) on which dozens
 * of passes run, inlining across files, vectors, and tables
 * that describe each machine. Their code is much faster than a
 * compiler of this kind makes, and they are millions of lines.
 * Fabrice Bellard's tcc is at the other end: one pass, no tree,
 * code written as the text is parsed.
 *
 * The command line: [help] in CLI.ml, what mini-cc -h prints.
 *
 * References: Ken Thompson, "Plan 9 C Compilers" (in principia's
 * compilers/docs/compiler.ms; first as "A New C Compiler", Proc.
 * Summer 1990 UKUUG Conference): ten pages, the design this follows
 * and the source of the quotations in this directory; Rob Pike, "How
 * to Use the Plan 9 C Compiler", for the dialect and the letters;
 * Dennis Ritchie, "The Development of the C Language" (History of
 * Programming Languages II, 1993), for why C is as it is; S. C.
 * Johnson, "A Portable Compiler: Theory and Practice" (POPL 1978);
 * B. W. Kernighan and D. M. Ritchie, "The C Programming Language"
 * (1978; second edition 1988), appendix A, the grammar;
 * docs/plans/done/plan_cc.md, the decisions and the counts;
 * principia's compilers book (Compiler.nw) and xix's compiler, the
 * same program in C explained and in OCaml. *)

type caps = < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

val main : < caps; .. > -> string array -> int
