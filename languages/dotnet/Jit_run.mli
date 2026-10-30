(* The JIT run in mini-dotnet (plan_dotnet.md, decision 12; stage 9
 * begun on arm64, Linux): `mini-dotnet -jit file.dll`. At a method's
 * first call, the interpreter asks here for its code: the methods Jit
 * takes from its assembly are all compiled then, once (Jit.program's
 * text), the text read by mini-asm's parser and encoded by mini-ld's
 * passes (Link, Arm64: the encoders as a library, as decision 12 has
 * it), the bytes made executable (Code_memory), and each method's entry
 * called as a closure of mini-ml's:
 *
 *     Machine.invoke m args       m's first call
 *       | jit m                   its assembly's methods compiled once
 *       |   Jit.program           the text: methods and entries (arm64)
 *       |   Parser_asm.parse      an object of mini-asm's
 *       |   Link, Arm64           laid out at 0, encoded: bytes
 *       |   Code_memory.load      executable: an address
 *       v
 *     m.body <- Native f          f args: the int32s as ints, the entry
 *                                 called, its int an I4
 *
 * The code has no absolute address of its own (branches and the
 * literal pool are relative to the pc), so it is encoded at 0 and runs
 * where it is mapped. A method the JIT does not take stays the
 * interpreter's, which calls the JIT's as any Native method.
 *
 * The whole assembly at the first call, not a method at its own: its
 * methods call each other by BL, without cells (decision 12's stub
 * and cell, for a method compiled at its own first call, come with
 * the references). *)

(* the code of a method (its assembly's image, its row), when the JIT
 * takes it and can run here; None: the interpreter's *)
val jit : < Cap.open_in; .. > -> Value.meth -> (Value.value array -> Value.value) option

(* how many methods were compiled, for -s *)
val compiled : int ref
