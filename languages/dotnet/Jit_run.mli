(* The JIT run in mini-dotnet (plan_dotnet.md, decision 12; stage 9
 * begun on arm64, Linux): `mini-dotnet -jit file.dll`. At the first
 * call of one of an assembly's methods, the interpreter asks here for
 * its code: the methods Jit takes are found then (verified), each
 * given a cell (Code_memory.cells), an entry and a stub (Jit.stubs),
 * the text read by mini-asm's parser and encoded by mini-ld's passes
 * (Link, Arm64: the encoders as a library, as decision 12 has it), the
 * bytes made executable (Code_memory), and each method's entry called
 * as a closure of mini-ml's; a method is compiled when its stub is
 * first called (compile), the same way:
 *
 *     Machine.invoke m args       the first call of one of them
 *       | jit m                   its assembly's methods prepared
 *       |   Jit.stubs             entries and stubs (arm64)
 *       |   Parser_asm.parse      an object of mini-asm's
 *       |   Link, Arm64           laid out at 0, encoded: bytes
 *       |   Code_memory.load      executable: an address
 *       v
 *     m.body <- Native f          each method's: f args, the int32s as
 *                                 ints, the entry called, its result an
 *                                 I4 or the reference
 *     the entry -> m's cell -> m's stub -> compile: Jit.method_code,
 *                                 encoded, loaded, the cell set
 *
 * The code has no absolute address of its own (branches and the
 * literal pool are relative to the pc), so it is encoded at 0 and runs
 * where it is mapped. A method the JIT does not take stays the
 * interpreter's, which calls the JIT's as any Native method.
 *
 * The call-outs (Jit.site): the code calls jit_outN, a static
 * closure here of the call-out's number and its N operands, which
 * runs the instruction in its method's code (Machine.exec) on them as
 * the interpreter's values, and gives back what it pushes. So the
 * code calls the library, the interpreter and the methods compiled
 * (their Native) as the interpreter does, through it.
 *
 * A method's code calls another compiled through the other's cell, so
 * a method never called is never compiled (fib.dll: 3 of 4). *)

(* the code of a method (its assembly's image, its row), when the JIT
 * takes it and can run here; None: the interpreter's *)
val jit : < Cap.open_in; .. > -> Value.meth -> (Value.value array -> Value.value) option

(* how many methods were compiled, for -s *)
val compiled : int ref
