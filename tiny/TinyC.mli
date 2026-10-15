(* A tiny C compiler for arm64, in one file, that goes through an
 * intermediate language of its own.
 *
 * The full-size compiler in ix, mini-cc (languages/c/), is a faithful
 * byte-for-byte twin of Plan 9's 5c and 7c: it has their front end,
 * their trees, their code generator, and a record per machine. This
 * file is what is left when the code only needs to be correct. (Its
 * usage, with examples, is in [help] below, which is what tiny-c -h
 * prints.) It reads one C file and writes its arm64 assembly, in
 * Plan 9 syntax, for TinyAssembler. It follows 7c's calling
 * convention, so the program can call goken's libc (compiled by 7c)
 * and libc can call the program back (main).
 *
 * With -tm, it targets the other machine instead, TinyCPU
 * (TinyMachineCPU.ml). It uses the same front end and stack machine,
 * plus a second back end of 100 lines and a runtime of its own in
 * TinyCRuntime/ (built by TinyKernel/steps/Makefile): start.tm holds
 * the program start and the system calls, udivmod.tm the unsigned
 * division, and the rest of libc is C compiled by tiny-c -tm. On that
 * machine pointers are 4 bytes and long long is refused, because the
 * machine is 32 bits. The stack machine was designed so that both
 * back ends print the same output, on TinyC_tests/ and on random
 * programs without long long (TinyC_fuzz.py --32).
 *
 * A file goes through these steps, each with its own type:
 *
 *     file.c
 *        | tokens     with #includes inlined and #defines expanded
 *        | the parser recursive descent producing typed trees, [expr]
 *        |            and [stmt], with conversions made explicit
 *        | lower      turns a function's tree into stack machine
 *        |            code, an [ir] list (what -ir prints)
 *        | machine    (or machine_tm) turns that list into assembly,
 *        |            keeping the stack depth d in register Rd
 *     file.s (or file.tm), for tiny-assembler (or tiny-cpu)
 *
 * Here is one function, int f(int a, int b) { return a + b * 2; }, as
 * printed by -ir and by the default back end:
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
 * The first argument arrives in R0 and is stored into its stack slot,
 * next to the second argument which is already there (7c's
 * convention). A variable is accessed by pushing its address and then
 * loading it, and every operation on ints is followed by a sign
 * extension. With -tm, the first four lines become addi and ldw, then
 * li r3, 2, mul r2, r2, r3 and add r1, r1, r2, with no extension
 * (a register is already an int there), and the result goes in r13.
 * The cost is visible too: nine instructions, where an optimizing
 * compiler with both arguments in registers would need only one, an
 * add with a shifted second operand.
 *
 * What makes it small while still being a C compiler:
 *
 * - {b A stack machine in between} (IR, below): expressions become
 *   pushes and operations on a stack, and statements become labels
 *   and jumps; [-ir] prints it. The compiler plan left open the
 *   question of what an intermediate language buys compared to
 *   emitting machine instructions directly. Here is the answer: the
 *   front end knows nothing about registers or instructions, the back
 *   end knows nothing about C (its 120 lines are the whole machine),
 *   each can be read and tested on its own, and a second machine is
 *   just a second back end (-tm). The price is code quality: no
 *   Sethi-Ullman ordering, no addressing modes, and a load or store
 *   for every variable reference.
 * - {b The stack is in registers.} The back end keeps the stack
 *   machine's stack in R1..R15 (depth d in Rd), so a push is a MOV and
 *   an operation is one instruction on two registers, as in Wirth's
 *   compilers. Only a call needs to save the live values below its
 *   arguments, into the frame. An expression deeper than 15 is
 *   refused.
 * - {b Types at parse time, trees as variants.} Each expression is
 *   built already typed, with its conversions made explicit (a Conv
 *   node, scaled pointer arithmetic). Statements are a tree too
 *   ([stmt]), which [lower] turns into stack machine code, so parsing,
 *   lowering and code generation are three separate walks, each over
 *   its own type. The operators are variants, split so that every
 *   match is exhaustive; [&&], [||] and [!] are expressed with [?:],
 *   and [while] with [for].
 * - {b Values in 64 bits.} A register holds a value extended from its
 *   type, and each operation on an int is followed by an extension
 *   (SXTW, MOVWU), so the machine's 64-bit instructions work for every
 *   width.
 * - {b 7c's frames and arguments}: the first argument is in R0, the
 *   others in 8-byte slots from 8(R31) upward (n(FP) for the callee),
 *   the result in R0, locals below SP, and the frame is laid out as
 *   7l does it (TinyAssembler's TEXT). So libc's functions, including
 *   variadic ones like print, are called exactly as 7c calls them.
 *
 * The language supported: char, short, int, long (4 bytes, as in
 * Plan 9) and long long, signed and unsigned; pointers, arrays,
 * structs (members, . and ->, but not passed by value); enums; void;
 * globals with initializers (numbers, strings, addresses, and arrays
 * of them); static, extern, typedef; functions and prototypes, and
 * calls to variadic functions; function pointers (C's inside-out
 * declarators, and calls through any expression, as needed by tiny-os's
 * system call table and devices); every operator, including op=, ++,
 * --, ?:, casts, sizeof and the comma, with constant expressions
 * folded (for an array size or a case); if, while, do, for, switch,
 * break, continue, return and blocks; #include "file" and #define of a
 * name. Left out, because of what each would cost here: floats,
 * unions, bitfields, structs by value, goto, macros with arguments,
 * and #if.
 *
 * Exercises, each cheap because the stack machine sits between the
 * front end and the machines:
 * - a third back end: arm32 (with 5c's calling convention, for mini-5i
 *   and the Pi1), or x86-64; the -tm back end took 100 lines;
 * - running the stack machine: a 60-line interpreter of its code would
 *   give a third semantics against which to compare the two back ends
 *   (and would run the programs without goken);
 * - peephole passes on the stack machine code, each a match on a list
 *   (McKeeman's idea): folding an operation on two constants,
 *   following a jump to a jump, removing a load right after a store
 *   to the same place;
 * - Sethi and Ullman's ordering: evaluating the deeper operand of an
 *   operation first keeps the stack shallower (useful with the 12
 *   registers of -tm);
 * - long long on -tm, as a value in a pair of registers; floats, as a
 *   second register class on the same stack (started once, then
 *   abandoned).
 *
 * Status: TinyAssembler reads what it writes for arm64, and
 * TinyMachineCPU's assembler reads what it writes with -tm. It
 * compiles TinyML's runtime (whose collector and primitives are in
 * C), TinyKernel's programs, and t6, a kernel in C, together with its
 * own programs. TinyML's code generator reuses this file's stack
 * machine and register stack for another language. Its twin, mini-cc,
 * has what this one leaves out: 7c's trees rewritten using Sethi and
 * Ullman's numbers, addressing modes, a register allocator, a peephole
 * pass, and an object file format.
 *
 * cs-history:
 * C was created by Dennis Ritchie (Bell Labs, 1972), out of Ken
 * Thompson's B (1969), which was itself Martin Richards's BCPL (1967)
 * cut down to fit a small machine. B and BCPL had a single type, the
 * machine word; C got its types when the PDP-11 brought bytes and
 * words of different sizes. BCPL's compiler already stopped at code
 * for an abstract stack machine, O-code, with a small back end for
 * each computer. That is how BCPL moved from machine to machine, and
 * it is the plan of this file. Steve Johnson's portable C compiler
 * (late 1970s) did the same for C using trees, and it took C and Unix
 * beyond the PDP-11.
 *
 * comeback:
 * Pascal's P-code (Zurich, 1970s; interpreted by the UCSD system) was
 * also stack machine code placed between a language and the machines.
 * Optimizing compilers abandoned it in favor of code with named
 * values, three addresses per operation, and then SSA (as in LLVM),
 * where the uses of a value are easy to find and change. Stack code
 * came back as the format that gets shipped: the Java virtual machine
 * (1995), then WebAssembly (2017), because it is compact and can be
 * checked in one pass.
 *
 * others:
 * Several small C compilers were written to be read. Small-C (Ron
 * Cain, Dr. Dobb's Journal, 1980) compiled a subset of C and was the
 * first one many people typed in. lcc (from Fraser and Hanson's book)
 * matches trees against a description of the machine. Fabrice
 * Bellard's tcc (grown out of his OTCC of 2001) goes in one pass from
 * text to machine code in memory, with no intermediate language at
 * all. Rui Ueyama's chibicc (2019) builds a tree and then emits code
 * that pushes and pops the real stack, and it is written as a history
 * of small commits. chibicc is the closest to this file: its stack is
 * the machine's, while ours is in registers.
 *
 * modern:
 * A production compiler does not keep the values of an expression in
 * a fixed stack of registers. It gives every value a name, computes
 * where each one is live, and puts values that are never live at the
 * same time in the same register (graph coloring: Gregory Chaitin,
 * 1982; or linear scan). A variable then stays in a register for a
 * whole loop, whereas here it is loaded and stored at each use.
 *
 * References:
 *  - Niklaus Wirth, Compiler Construction (1996): registers used as a
 *    stack of the expression's values, and one-pass recursive descent
 *  - Ken Thompson, "Plan 9 C Compilers" (1990): the calling
 *    convention this code shares with 7c
 *  - Kernighan and Ritchie, The C Programming Language (1988),
 *    appendix A: the grammar followed here
 *  - R. Sethi and J. D. Ullman, "The Generation of Optimal Code for
 *    Arithmetic Expressions" (JACM, 1970)
 *  - W. M. McKeeman, "Peephole Optimization" (CACM, 1965)
 *  - C. Fraser and D. Hanson, A Retargetable C Compiler: Design and
 *    Implementation (1995): lcc, a C compiler whose machines are its
 *    back ends
 *)

(* one declaration or function, from the tokens: parsed, typed, its
 * code for the stack machine, then the assembly added to the output *)
val external_decl : unit -> unit

(* the program: a file of C to a file of assembly (-h: how) *)
val main : < Cap.argv; Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr; Cap.exit; .. > -> unit
