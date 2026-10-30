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
 * {b Arm64's} (-m 7) are the same templates in 7c's convention: W
 * instructions on an int32 (ADDW...), a slot of 8 bytes, and a branch
 * over a move where arm has a conditional one (CSET mini-ld does not
 * encode). That code is the one mini-dotnet runs (Jit_run, `-jit`),
 * each method with an entry mini-ml calls as a closure ([program]).
 *
 * {b With references} (arm64's, in mini-dotnet: the assembly loaded,
 * its fields laid out by Types), instance methods too, and methods of
 * strings, objects, arrays: a reference, the interpreter's value, has
 * its slot on mini-ml's value stack (R26), where its collector finds
 * it and moves it, an int32 its slot on the machine's:
 *
 *     static int Sum(Node l)         l: a word of the value stack
 *       ldarg.0; ldfld Node::Value   MOV v(R26), R1; CMP $1, R1 (null?)
 *                                    MOV 0(R1), R1      Obj's store
 *                                    MOV 8(R1), R1      its bytes
 *                                    MOVW 0(R1), R1     the field
 *       callvirt Shape::Area()       MOV $7, R1 (call-out 3); MOV v, R2
 *                                    BL jit_out1(SB)    Machine.exec
 *
 * A field, an array's element and length are read and written by the
 * code (a reference stored but by a call-out: the collector's write
 * barrier); the rest, a call into the library, to a virtual method or
 * a constructor, new, ldstr, a static field, a cast, a box, throw, is
 * a call-out: an ML function called with the operands (an int32
 * tagged), which runs that instruction in the interpreter
 * (Machine.exec) and returns what it pushes. A call to a static method
 * compiled is a BL. A null and an index out of range call the
 * runtime's, which throw.
 *
 * What it refuses is said with the reason: a struct, an int64, a
 * double, a pointer on the stack, an instruction without its template
 * yet, exception clauses, a generic method or class.
 *
 * {b A method is compiled at its first call} (stubs, method_code): it
 * is called through its cell, a word holding its code's address, at
 * first its stub's, which compiles it, sets the cell, and calls it;
 * then the code itself:
 *
 *     caller: MOV $cell, R16; MOV 0(R16), R16; BL (R16)
 *               cell --> Rec_stub: compile Rec (jit_compile), the cell
 *                                  now Rec's code; call it; return
 *               cell --> Rec       (each call after)
 *
 * What is left of decision 12: the code on arm, under mini-5i and on
 * mini-9pi (segflush; mini-5i's and mini-qemu's caches told).
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

(* arm's (5c's), or arm64's (7c's: the same templates, W instructions
 * on the low 32 bits, a slot of 8 bytes, no conditional move) *)
type mach = Arm | Arm64

(* a slot's kind: an int32 (a native int) on the machine's stack, a
 * reference (the interpreter's value) on mini-ml's *)
type kind = I | R

(* a call-out: an instruction of a method (its row, its index) the
 * interpreter runs for the code (Machine.exec), its operands' kinds,
 * the bottom first, and its result's *)
type site = { srow : int; sat : int; sargs : kind list; sret : kind option }

(* the assembly's methods that are compiled, as mini-asm's text; how
 * many; the others' rows and why not. With the assembly loaded (and
 * arm64's), references too, the call-outs by their stubs' names *)
val assembly : mach -> Image.t -> Value.image option -> string * int * (int * string) list

(* the most operands of a call-out *)
val outs : int

(* In mini-dotnet (Jit_run), on arm64, with references: an assembly's
 * methods compiled each at its first call (decision 12). Each has a
 * cell, a word at an address that holds its code's address, its
 * stub's until then, and is called through it. *)

(* the assembly's methods the JIT takes, verified, their symbols *)
type prepared
val prepare : Value.image -> prepared
val rows : prepared -> int list
val symbol_of : prepared -> int -> string

(* the runtime's functions, by their static closures' addresses: in
 * each piece of code (each its own copy). [throws] by name,
 * jit_divide_by_zero, jit_null, jit_range, of unit, which raise; [out]
 * the call-outs', by their operands (0 to outs), each taking the
 * call-out's number then the operands; [compile] the compiler's, of a
 * method's number *)
val runtime : throws:(string * int) list -> out:int array -> compile:int -> string

(* the code at the start: for each method an entry, `Sym_entry`, which
 * mini-ml calls as a closure of one argument, an array of the
 * arguments (an int32 a tagged int), and which returns the result
 * likewise; and its stub, `Sym_stub`, which calls jit_compile with the
 * method's [number], then the method through its [cell]. The text, the
 * entries' symbols, the stubs' *)
val stubs : prepared -> cell:(int -> int) -> number:(int -> int) -> runtime:string ->
  string * (int * string) list * (int * string) list

(* a method's code, at its first call: its text (`Sym`, then the
 * runtime's), its call-outs numbered from [base] *)
val method_code : prepared -> int -> cell:(int -> int) -> base:int -> runtime:string -> string * site list
