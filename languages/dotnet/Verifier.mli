(* The verifier: each method's stack, its depth and each slot's type,
 * at each instruction, found by going over the method's paths
 * (ECMA-335, Partition III, 1.8: "verifiability and correctness"); an
 * instruction refused, with its offset, when its operands are not of
 * the types it takes. Its result is the JIT's input (plan_dotnet.md,
 * decision 12): with each slot's type known before the method runs, a
 * slot is a place in the frame, and `add` an add of registers.
 *
 *     static int Rec(int n)          before each instruction:
 *       IL_0000: ldarg.0             []
 *       IL_0001: ldc.i4.2            [int32]
 *       IL_0002: bge.s IL_0006       [int32; int32]   two int32: comparable
 *       IL_0004: ldarg.0             []
 *       IL_0005: ret                 [int32]           the int32 returned
 *       IL_0006: ldarg.0             []                from IL_0002: the same
 *       ...
 *
 * {b The types on the stack} are few (Partition III, 1.1): int32,
 * int64, native int, F (every float), a reference (O), a managed
 * pointer (&), a value type's value. A bool, a char, a short are int32
 * on the stack; the instructions are typed by these (lesson 3).
 *
 * {b The paths} are followed from the first instruction and from each
 * handler's (a catch's starts with its exception), a worklist of the
 * instructions whose stack changed; where two paths join, their stacks
 * must have the same depth and their slots the same kind (a reference
 * and another: a reference). So the IL is a program in a typed
 * language whose types are found, not written: the verifier is its
 * type checker, as the JVM's is (its "type inference" verifier, before
 * Java 6's StackMapTable wrote the types at the joins).
 *
 * It reads the metadata only (Signature's types, the tokens), not the
 * classes as Types loads them: it can go over Microsoft's own library.
 * A reference's class is not checked against what is asked (a Shape
 * where an INamed is: Types would have to load both), nor are the
 * rules of access (private, protected); a kind is: an int32 where a
 * reference is asked is refused.
 *
 * others:
 * The CLR's verifier refused what it could not prove safe, and was the
 * base of .NET's code access security: an unverifiable method needed
 * full trust. .NET Core dropped both (2016): its JIT imports the IL with
 * the same walk, typing the stack, but trusts the program. *)

(* a slot's type: Partition III's stack types, a reference with its
 * type when known (None: null) *)
type vt =
  | Int32
  | Int64
  | Native
  | Float
  | Obj of Signature.t option
  | Ptr of Signature.t
  | Value of Signature.t
  | Gen of Signature.t             (* a type parameter's value: !0, !!0 *)

exception Bad of string

val show : vt -> string

type result = {
  stacks : vt list option array;   (* before each instruction, the top first; None: not reached *)
  instrs : Il.instr array;
}

(* a MethodDef's row verified: Bad with the offset and why *)
val method_ : Image.t -> int -> result

(* every method with a body: how many pass, the others' rows and why *)
val assembly : Image.t -> int * (int * string) list
