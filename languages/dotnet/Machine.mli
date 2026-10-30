(* The machine: a method's IL run, an instruction at a time, on an
 * evaluation stack of tagged values (ECMA-335, Partition III). The
 * reference that the JIT will be checked against (plan_dotnet.md,
 * decision 12: what the JIT does not compile, this runs).
 *
 * A call is a frame: the method's arguments, its locals (their types
 * from the StandAloneSig of its header), its stack (as deep as its
 * .maxstack), its pc. A call in the IL is a call of OCaml's here, so the
 * .NET stack is OCaml's; the frames are also kept in a list, for the
 * exceptions' first pass and for -trace.
 *
 *     Fib::Rec(20)                 args [| I4 20 |]   locals [||]
 *       IL_0000: ldarg.0           stack [ I4 20 ]
 *       IL_0001: ldc.i4.2          stack [ I4 20; I4 2 ]
 *       IL_0002: bge.s IL_0006     both int32: 20 >= 2, to IL_0006
 *       IL_0006: ldarg.0  ...
 *       IL_0009: call Fib::Rec     a frame of its own, its result pushed
 *
 * {b An instruction is typed by its operands} (lesson 3): `add` looks
 * at its two values' tags, int32 and int32, int64 and int64, floats.
 *
 * {b Value types are copied} (lesson 4): a struct loaded from a local,
 * a field or an element is a copy (Value.copy); `ldloca`, `ldflda`,
 * `ldelema` make a managed pointer instead, through which a struct is
 * changed in place, and a struct's method gets its `this` so.
 *
 * {b Exceptions have two passes}, as the CLR's: when an exception is
 * thrown, the frames are searched for a `catch` that takes it, without
 * running anything; if none does, the program stops there ("Unhandled
 * exception"), its `finally` blocks not run. Else the frames are left
 * one by one (an OCaml exception, Value.Thrown), each running its
 * `finally` blocks on the way, until the catch. A `leave` out of a try
 * runs the `finally` blocks it leaves.
 *
 *     try { Check(0) }            Check: 100 / 0, DivideByZeroException
 *     catch (Refused) {...}       pass 1: Try's frame, this clause: no;
 *     catch (DivideByZero) {...}           this one: yes
 *     finally {...}               pass 2: Check's frame left; Try's
 *                                 catch runs, then its leave the finally
 *
 * A class's static constructor runs before its first static field is
 * read or written, its first static method called, its first object
 * made.
 *
 * others:
 * The JVM's interpreter (HotSpot's "template interpreter") is the same
 * loop written in the machine's code, one template an opcode; its
 * stack's slots are not tagged since javac's opcodes say their types.
 * Mono's interpreter (2017) and .NET's (for iOS, WebAssembly) first
 * turn the IL into a code of their own, typed, as the verifier would.
 *
 * Its parts: Frame (a call's frame, the frames running, an exception's
 * first pass and the machine's own exceptions), Arith (what the
 * instructions do to numbers: add, compare, convert), and here the
 * places (fields, elements, pointers), the classes at run time (boxes,
 * casts, static constructors), the calls and the loop. *)

open Value

(* a method called with its arguments (`this` first), its result *)
val invoke : meth -> value array -> value

(* asked at a method's first call (its body still Il_body) for its
 * code by the JIT, which then is its body (Native); None, the
 * interpreter's. Jit_run.jit with -jit; by default none *)
val jit : (meth -> (value array -> value) option) ref

(* the program's entry point run with the command line's arguments:
 * Main's result, 0 if it returns none *)
val run_main : image -> string list -> int

(* the machine's services to the library (Library.hooks) *)
val install : unit -> unit
