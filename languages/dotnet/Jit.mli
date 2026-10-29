(* The JIT's code, as text (plan_dotnet.md, stage 8): a method's IL
 * turned into the machine's instructions, arm's, written as mini-asm
 * reads them (Plan 9's 5a), so that mini-asm assembles it and mini-ld
 * links it. `mini-dotnet -jit -S file.dll` prints it. Its input is
 * the verifier's: at each instruction the stack's depth and each
 * slot's type are known before the method runs, so each slot is a
 * place in the frame, and an instruction a few of the machine's:
 *
 *     static int Rec(int n)              TEXT  Fib_Rec(SB), 0, $16
 *                                        MOVW  R0, a0+0(FP)
 *       IL_0000: ldarg.0         []      MOVW  a0+0(FP), R1
 *                                        MOVW  R1, s0-4(SP)
 *       IL_0001: ldc.i4.2        [i4]    MOVW  $2, R1
 *                                        MOVW  R1, s1-8(SP)
 *       IL_0002: bge.s IL_0006   [i4 i4] MOVW  s0-4(SP), R1
 *                                        MOVW  s1-8(SP), R2
 *                                        CMP   R2, R1
 *                                        BGE   Fib_Rec_5
 *       ...
 *
 * A template JIT (decision 12): each instruction a fixed sequence,
 * the stack's slots in memory, no register kept between two
 * instructions. What it shows is what the types make possible: `add`
 * of two int32 is one ADD, where the interpreter (Machine) looks at
 * two tags, allocates a box, and goes round its loop. A cache of the
 * stack's top in registers would come after, measured.
 *
 * {b Its first methods} are those of int32s only: static, their
 * parameters, locals, result and every stack slot an int32 (a bool, a
 * char), their calls to such methods of the same assembly, no
 * exception clause. Such a method is a function of C's for 5c: its
 * first argument in R0, the others at 4(i+1) on the caller's stack,
 * its result in R0, its frame mini-ld's (TEXT's $size). So a C
 * program calls it, and the tests do: Fib's Rec and Loop, linked with
 * a C program by mini-ld and run under mini-5i, print what the
 * interpreter prints (tests/jit). A division by zero calls
 * jit_divide_by_zero, the runtime's (the test's C).
 *
 * What it refuses is said with the reason: a reference on the stack
 * (a string, an object, an array), a call into the library, an
 * instruction without its template yet, exception clauses. The rest
 * of decision 12 (stage 9): the references on mini-ml's value stack
 * (R10) where its collector finds them, the scalars on the machine's;
 * the library's adapters called as mini-ml calls a closure (ml_vsp
 * stored before, loaded after); a method's entry a cell, a stub that
 * compiles it at its first call; the code in memory both written and
 * run (on mini-9pi a kernel's call yet to choose, the plan's open
 * question; under mini-5i and mini-qemu their caches told).
 *
 * others:
 * .NET's first JIT (2002) compiled a method at its first call through
 * a stub, as here; RyuJIT (2015) builds a tree of the IL, then SSA,
 * and allocates registers. Mono's first JIT was a tree-matching
 * code generator (monoburg); its later one, mini, SSA as RyuJIT's.
 * The JVM's HotSpot interprets first and compiles a method once it is
 * called often (C1, then C2): the tiers .NET Core took in 3.0. *)

(* why a method is not compiled *)
exception Refused of string

(* the assembly's methods that are compiled, as mini-asm's text; how
 * many; the others' rows and why not *)
val assembly : Image.t -> string * int * (int * string) list
