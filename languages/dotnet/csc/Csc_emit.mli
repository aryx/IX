(* The reduced C#'s methods to IL, in one pass over each body, as
 * mini-pascal compiles (its Pascal_compile): an expression's code is
 * written as its type is found. Where a choice needs the types first
 * (an overload by its arguments', a + of a string), they are found by
 * compiling the arguments and throwing the code away (type_of).
 *
 * What C# writes for the machine, and how:
 *   - a string's + is String.Concat (of two strings, or of two objects,
 *     a value boxed), == of strings String.op_Equality;
 *   - foreach over an array is a loop on its index; over a List, its
 *     Enumerator, a struct in a local, MoveNext and Current called on
 *     its address (C#'s finally around it, Dispose, left out);
 *   - an assignment computes its place first (an object, an array and
 *     an index), kept in locals, then the value, then stores: what is
 *     assigned may be used as a value (a = b = c);
 *   - a return inside a try is a leave to the method's end, its value
 *     in a local: IL forbids a ret there;
 *   - an argument out is a local's address (ldloca), a parameter out
 *     a pointer read and written with ldind and stind. *)

type ctx = { w : Writer.t; memo : (string, int) Hashtbl.t }

(* a type in the writer: as a signature, as an instruction's operand *)
val sig_of : ctx -> Csc_types.ty -> Signature.t
val type_token : ctx -> Csc_types.ty -> int
val meth_sig : ctx -> Csc_types.meth -> Signature.meth

(* a method's body to the writer; a constructor's with its fields'
 * initial values and its parent's constructor first *)
val body : ctx -> Csc_types.cls -> Csc_types.meth -> unit
