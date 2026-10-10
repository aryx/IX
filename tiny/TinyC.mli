(* A tiny C compiler for arm64, in one file, through an intermediate
 * language of its own. mini-cc (languages/c/) is 5c's and 7c's twin,
 * byte for byte: their front end, their trees, their code generator,
 * and a record per machine. This is what is left when the code need
 * only be correct (its usage, by examples: [help] below, what tiny-c -h
 * prints): one C file in, its arm64 assembly out, in Plan 9's syntax, for
 * TinyAssembler, with 7c's calling convention, so that the program
 * calls goken's libc (7c's code) and libc calls it back (main).
 *
 * Or, with -tm, for the other machine, TinyCPU (TinyLibCPU.ml): the
 * same front end and stack machine, a second back end of 100 lines,
 * with a runtime of its own, in TinyC/libc/ (tiny-os's Makefile does
 * the above): the start and the system calls in start.tm, the unsigned
 * division in udivmod.tm, the rest of libc in C, compiled by tiny-c -tm. There
 * pointers are 4 bytes and a long long is refused: the machine is 32
 * bits. That the two back ends print the
 * same, on TinyC_tests/ and on random programs without long long
 * (TinyC_fuzz.py --32), is what the stack machine was for.
 *
 * A file's way, each step a type of its own:
 *
 *     file.c
 *        | tokens     the #includes in their place, the #defines expanded
 *        | the parser by recursive descent: typed trees, [expr] and
 *        |            [stmt], the conversions made explicit as it goes
 *        | lower      a function's tree to the stack machine's code,
 *        |            an [ir] list: what -ir prints
 *        | machine    (or machine_tm) that list to assembly, the
 *        |            stack's depth d kept in register Rd
 *     file.s (or file.tm), for tiny-assembler (or tiny-cpu)
 *
 * and one function through it, int f(int a, int b) { return a + b *
 * 2; }, as -ir and the default back end print it:
 *
 *     the stack machine   its stack, after   arm64
 *                                            TEXT  f(SB), $0
 *                                            MOVW  R0, p+0(FP)
 *     param 0             &a                 MOV   $p+0(FP), R1
 *     load 4              a                  MOVW  0(R1), R1
 *     param 8             a &b               MOV   $p+8(FP), R2
 *     load 4              a b                MOVW  0(R2), R2
 *     imm 2               a b 2              MOV   $2, R3
 *     op * 4              a b*2              MUL   R3, R2;  SXTW R2, R2
 *     op + 4              a+b*2              ADD   R2, R1;  SXTW R1, R1
 *     ret value                              MOV   R1, R0;  RETURN
 *
 * The first argument comes in R0 and is put in its slot, where the
 * second already is (7c's convention); a variable is an address
 * pushed and a load; an operation on ints is followed by its
 * extension. With -tm the same list is addi and ldw for the first
 * four lines, li r3, 2, mul r2, r2, r3 and add r1, r1, r2 with no
 * extension (a register is an int there), the result in r13. The
 * cost shows too: nine instructions, where a compiler that optimizes
 * and has both arguments in registers needs one, an add whose second
 * operand is shifted.
 *
 * What makes it small, and still a C compiler:
 *
 * - {b A stack machine in between} (IR, below): expressions become
 *   pushes and operations on a stack, statements labels and jumps;
 *   [-ir] prints it. The question the compiler's plan left open, what
 *   an intermediate language buys against writing the machine's
 *   instructions directly, has this answer here: the front end knows
 *   no register and no instruction, the back end no C (its 120 lines
 *   are the whole machine), and each can be read, and tested, alone;
 *   and a second machine is a second back end (-tm).
 *   What it costs is the code's quality: no Sethi-Ullman order, no
 *   addressing modes, a load or a store per variable reference.
 * - {b The stack is in registers.} The back end keeps the machine's
 *   stack in R1..R15 (depth d in Rd), so a push is a MOV and an
 *   operation one instruction on two registers, as in Wirth's
 *   compilers; only a call saves what is live below its arguments, to
 *   the frame. An expression deeper than 15 is refused.
 * - {b Types at parse time, trees as variants.} Each expression is
 *   built typed, with its conversions made explicit (a Conv node, a
 *   pointer's arithmetic scaled); statements are a tree too ([stmt]),
 *   which [lower] turns into the stack machine's code, so parsing,
 *   lowering and the machine are three walks, each of its own type.
 *   The operators are variants, split so that every match is
 *   exhaustive; [&&], [||] and [!] are made of [?:], [while] of
 *   [for].
 * - {b Values in 64 bits.} Registers hold a value extended from its
 *   type, and an operation on an int is followed by its extension
 *   (SXTW, MOVWU): the machine's 64-bit instructions do for every
 *   width.
 * - {b 7c's frames and arguments}: the first argument in R0, the
 *   others in 8-byte slots at 8(R31) up (the callee's n(FP)), the
 *   result in R0, locals below SP, and the frame 7l's (TinyAssembler's
 *   TEXT): so libc's functions, variadic ones included (print), are
 *   called as 7c calls them.
 *
 * The language: char short int long (4 bytes, as Plan 9's) and long
 * long, unsigned and signed; pointers, arrays, structs (members, . and
 * ->; not passed by value); enums; void; globals with initializers
 * (numbers, strings, addresses, arrays of them); static, extern,
 * typedef; functions and prototypes, calls to variadic ones; function
 * pointers (C's declarators inside out, a call through any expression:
 * tiny-os's system call table and devices); every operator, with op=,
 * ++, --, ?:, casts, sizeof and the comma, constant expressions folded
 * (an array's size, a case); if, while, do, for, switch,
 * break, continue, return, blocks; #include "file", #define of a name.
 * Left out, by what each would cost here: floats, unions, bitfields,
 * structures by value, goto, the preprocessor's macros with arguments
 * and its #if.
 *
 * Exercises, each cheap because the stack machine stands between the
 * front end and the machines:
 * - a third back end: arm32 (5c's calls, for mini-5i and the Pi1), or
 *   x86-64; -tm's was 100 lines;
 * - the stack machine run: an interpreter of its code, 60 lines, a
 *   third semantics for the test to compare the two back ends with (and
 *   the programs' outputs without goken);
 * - peephole passes on the stack machine's code, each a match on a list
 *   (McKeeman's): an operation on two constants folded, a jump to a
 *   jump followed, a store then a load of the same place;
 * - Sethi and Ullman's order: an operation's deeper operand evaluated
 *   first, so the stack stays shallower (the 12 registers of -tm);
 * - long long on -tm, a value in a pair of registers; floats, a second
 *   register class on the same stack (started once, left).
 *
 * Where it stands: what it writes TinyAssembler reads (arm64) or
 * TinyLibCPU's assembler (-tm). It compiles TinyML's runtime (its
 * collector and primitives are C), tiny-os's kernels v6 and t6 and
 * their programs, and TinyKernel's programs; TinyML's code generator
 * is this file's stack machine and register stack again, for another
 * language. Its twin, mini-cc, has what this leaves out: 7c's trees
 * rewritten by Sethi and Ullman's numbers, addressing modes, a
 * register allocator, a peephole pass, and an object file.
 *
 * cs-history:
 * C is Dennis Ritchie's (Bell Labs, 1972), out of Ken Thompson's B
 * (1969), itself Martin Richards's BCPL (1967) cut to fit a small
 * machine: B and BCPL had one type, the machine's word, and C's types
 * came when the PDP-11 had bytes and words of different sizes. BCPL's
 * compiler already stopped at a code for an abstract stack machine,
 * O-code, with a small back end per computer: that is how BCPL moved
 * from machine to machine, and this file's plan. Steve Johnson's
 * portable C compiler (1978) did the same for C with trees, and took
 * C and Unix off the PDP-11.
 *
 * comeback:
 * A stack machine's code between a language and the machines is
 * Pascal's P-code too (Zurich, 1970s; UCSD's system ran it
 * interpreted). Compilers that optimize left it for code with named
 * values, three addresses an operation, then SSA (LLVM's), where a
 * value's uses are easy to find and change. The stack code came back
 * as what is shipped: the Java virtual machine's (1995), then
 * WebAssembly's (2017), compact, and checked in one pass over it.
 *
 * others:
 * The small C compilers written to be read: Small-C (Ron Cain, Dr.
 * Dobb's Journal, 1980), a subset, the first many people typed in;
 * lcc (Fraser and Hanson's book), with trees matched against a
 * machine's description; Fabrice Bellard's tcc (2001), one pass from
 * the text to machine code in memory, no intermediate at all; Rui
 * Ueyama's chibicc (2019), a tree then code that pushes and pops the
 * real stack, written as a history of small commits. The last is the
 * nearest: its stack is the machine's, where ours is in registers.
 *
 * modern:
 * A production compiler does not keep an expression's values in a
 * fixed stack of registers. It gives every value a name, finds for
 * each where it is live, and puts in one register the values never
 * live together (graph colouring: Gregory Chaitin, 1982; or a linear
 * scan); a variable then lives in a register for a whole loop, where
 * here it is loaded and stored at each use.
 *
 * References: Niklaus Wirth, Compiler Construction (1996), for the
 * registers as a stack of the expression's values, and the one-pass
 * recursive descent; Ken Thompson, "Plan 9 C Compilers" (1990), for
 * the calling convention this code shares with 7c's; Kernighan and
 * Ritchie, The C Programming Language (1988), appendix A, the grammar
 * followed; R. Sethi and J. D. Ullman, "The Generation of Optimal Code
 * for Arithmetic Expressions" (JACM, 1970; from memory); W. M.
 * McKeeman, "Peephole Optimization" (CACM, 1965; from memory); C.
 * Fraser and D. Hanson, A Retargetable C Compiler: Design and
 * Implementation (1995; from memory), lcc, a C compiler whose machines
 * are its back ends. *)

(* one declaration or function, from the tokens: parsed, typed, its
 * code for the stack machine, then the assembly added to the output *)
val external_decl : unit -> unit

(* the program: a file of C to a file of assembly (-h: how) *)
val main : < Cap.argv; Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr; Cap.exit; .. > -> unit
