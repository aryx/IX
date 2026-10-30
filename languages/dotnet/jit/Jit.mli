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
 * {b Addresses}: a local's or an argument's (ldloca, ldarga: ref x,
 * out x, an int's x.ToString()) is nothing at run time, the local
 * being the code's and not the interpreter's: it is followed from
 * where it is pushed to the call-out that takes it, which is given the
 * local's value (the interpreter makes it a cell, Ptr (Slot ...)) and
 * gives back the new one, which the code puts in the local. A field's,
 * an element's (ldflda, ldelema) and a ref parameter are the
 * interpreter's Ptr, a reference to the code, read and written by
 * call-outs (ldind, stind). A delegate's method (ldftn) is followed
 * the same way to its newobj, the interpreter making it there.
 *
 * {b Generics}: a method of a generic class, or a generic method, is
 * compiled for each instance at the instance's first call
 * (instance_code), its type arguments its own: a T an int32 in
 * Stack<int>'s code, a reference in Stack<string>'s, the fields where
 * that instance's class has them; its calls all call-outs, run in its
 * context (T[]'s ldelem.any, constrained. callvirt, ldobj, stobj too).
 * So each instance has its code, as .NET's for value types; .NET shares
 * one code between the instances of references, a dictionary of the
 * types beside it.
 *
 * {b try, catch, finally}: a try's handler is a record on ML's own
 * chain of handlers, as ML's try pushes (Gen's ml_try: the stack
 * pointer, the value stack's top, where a raise comes back, the
 * record before; ml_handler's address the runtime's), pushed at the
 * try's start by jit_try, which returns 0, and where a raise returns
 * again with the exception; and a frame of the method's on
 * Frame.frames meanwhile, so that the first pass sees the try's
 * clauses. The handler asks the interpreter (a call-out: Machine.run's
 * rule) whether its catch takes the exception, else raises it again;
 * a finally keeps it, runs, and at its endfinally raises it again. A
 * leave pops the records and frames of the trys it leaves, the inner
 * first, each finally run on the way and coming back (its continuation
 * a number in the frame).
 *
 *     try {                    MOV $..., R1; BL jit_out0   (its frame)
 *                              MOV $record, R0; BL jit_try
 *                              CMP $0, R0; BNE handler
 *       ...                    the body's code
 *     } catch (E e) {          (handler: the exception to a call-out,
 *                               caught: on the stack, else raised)
 *
 * {b Structs}: a struct's value is the interpreter's Vt, a reference
 * to the code (its store where Obj has it: a field read the same),
 * copied where the IL copies it, a load (ldloc, ldarg, dup: a
 * call-out, Value.copy), so that two slots never share a store; a
 * struct local its zeros at the start (.locals init), as a constructor
 * called on its address writes in it; a field of a struct through its
 * address (its own methods' this), a struct field, ldtoken: call-outs.
 *
 * {b int64s, doubles}: the interpreter's I8 and R8, references to the
 * code, their arithmetic, conversions and comparisons (and every
 * checked operation) call-outs, a branch on them the interpreter's
 * test, then the code's branch: compiled, not fast.
 *
 * What it refuses is said with the reason: an address at a jump or
 * given to the code itself, an instruction without its template yet,
 * a filter or a fault clause; and in -S's text a generic method or
 * class (an instance's code is only made at run time).
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
 * {b On arm} (mini-dotnet for Plan 9: mini-9pi, mini-5i), the same
 * code with references, 5c's names and words of 4 bytes, the value
 * stack's top R10; and two things arm64 has not to do. An int's 31
 * bits there do not hold an int32: one crosses to ML (an argument of
 * a call-out, an entry's result) tagged when it fits, else boxed
 * (jit_box: an Int32's block), and one from ML is either (TST $1).
 * The Pi 1's ARMv6 has no division: the runtime's unsigned one
 * (jit_udiv), the signs in the templates.
 *
 * others:
 * .NET's first JIT (2002) compiled a method at its first call through
 * a stub, as here; RyuJIT (2015) builds a tree of the IL, then SSA,
 * and allocates registers. Mono's first JIT was a tree-matching
 * code generator (monoburg); its later one, mini, SSA as RyuJIT's.
 * The JVM's HotSpot interprets first and compiles a method once it is
 * called often (C1, then C2): the tiers .NET Core took in 3.0.
 *
 * history:
 * L. Peter Deutsch and Allan Schiffman's Smalltalk-80 (POPL 1984):
 * the first JIT, a method translated to the machine's code at its
 * first call and cached, the bytecode kept; and the inline cache, a
 * send's last class and method remembered at the call site.
 * Self (Craig Chambers, David Ungar, Urs Hölzle, Stanford, 1989-1995):
 * code customized to the receiver's class, polymorphic inline caches
 * (1991), adaptive optimization (a method recompiled once hot, by
 * what its caches saw), deoptimization back to the interpreter's
 * frames. Its people made Strongtalk, which Sun bought (1997) to make
 * HotSpot (1999).
 * Inferno's Dis (Phil Winterbottom, Rob Pike, 1997, "The Design of
 * the Inferno Virtual Machine"): the other choice of machine, memory
 * to memory, three operands (add a, b, c), not a stack; so close to
 * the processor's that its JIT, at a module's load, is a translation
 * an instruction at a time, no stack to model. IL's stack, as the
 * JVM's, is smaller to write and to verify; this JIT models it at
 * compile time (a slot per depth), which Dis needs not.
 * V8 (Lars Bak, of Self, Strongtalk and HotSpot; Google, 2008):
 * JavaScript compiled at first, no interpreter (full-codegen), the
 * hidden classes and inline caches of Self; Crankshaft (2010) the
 * optimizing tier, then Ignition, an interpreter again, and TurboFan
 * (2016): tiers as HotSpot's.
 * Tracing JITs, the other road: not a method compiled but a loop's
 * path as it runs, HP's Dynamo (2000) on machine code, TraceMonkey
 * (Andreas Gal, Michael Franz, 2009) for JavaScript, LuaJIT 2 (Mike
 * Pall, 2009) the best known.
 * Here: Deutsch and Schiffman's scheme (a method at its first call,
 * templates, no optimizer) with HotSpot's tiers, without Self's
 * caches: IL's calls are typed, a virtual one found by its class's
 * slot (Types), no guess to cache. *)

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
 * the bottom first, the form of each (Word: its value; Addr: a local's
 * address, its value given, to be put in a cell, and given back: the
 * call-out's answer then an array, the result, then their new values;
 * Made: nothing given, the value the instruction at that index makes,
 * ldftn's Fn), and its result's *)
type form = Word | Addr | Made of int
(* what a call-out does: an instruction run; for a try (its clause's
 * index), its frame pushed for the first pass and popped, the
 * exception caught or let go, raised again, rethrown; a struct copied
 * (loaded), a local's zeros (a struct's, an int64's, a double's); a
 * branch's test of int64s or doubles (1 or 0) *)
type op = Run | Enter of int | Leave_try | Catch of int | Reraise | Rethrow | Copy | Init of int
  | Test of Il.cmp * bool | Truthy
type site = { srow : int; sat : int; sargs : kind list; sform : form list; sret : kind option; sop : op }

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
val prepare : mach -> Value.image -> prepared
val rows : prepared -> int list
(* those it does not take, and why *)
val refused : prepared -> (int * string) list
val symbol_of : prepared -> int -> string

(* the runtime's functions, by their static closures' addresses: in
 * each piece of code (each its own copy). [throws] by name,
 * jit_divide_by_zero, jit_null, jit_range, of unit, which raise; [out]
 * the call-outs', by their operands (0 to outs), each taking the
 * call-out's number then the operands; [compile] the compiler's, of a
 * method's number; on arm [box], of an int32's two halves, tagged,
 * which returns its Int32 (an int32 past 31 bits crosses so) *)
val runtime : mach:mach -> throws:(string * int) list -> out:int array -> compile:int -> box:int ->
  handler:int -> string

(* the code at the start: for each method an entry, `Sym_entry`, which
 * mini-ml calls as a closure of one argument, an array of the
 * arguments (an int32 a tagged int), and which returns the result
 * likewise; and its stub, `Sym_stub`, which calls jit_compile with the
 * method's [number], then the method through its [cell]. The text, the
 * entries' symbols, the stubs' *)
val stubs : prepared -> cell:(int -> int) -> number:(int -> int) -> runtime:string ->
  string * (int * string) list * (int * string) list

(* jit_sp, a closure's code of unit returning the stack pointer in
 * words (a limit of the stack's put below it) *)
val sp_code : mach -> string

(* a method's code, at its first call: its text (`Sym`, then the
 * runtime's), its call-outs numbered from [base]; the machine's stack
 * pointer checked against [limit] (in words: jit_overflow below it) *)
val method_code : prepared -> int -> cell:(int -> int) -> base:int -> limit:int -> handler:int -> runtime:string ->
  string * site list

(* an instance of a generic method (of a generic class, or generic
 * itself), its type arguments those of the Value.meth: compiled alone,
 * at its own first call, each instance its code (a T an int32 in one,
 * a reference in another; its fields where the instance has them).
 * Its text (the method, its entry calling it directly, the runtime's),
 * the entry's symbol, its call-outs from [base]; None if refused *)
val instance_code : mach -> Value.meth -> base:int -> limit:int -> handler:int -> runtime:string ->
  (string * string * site list) option
