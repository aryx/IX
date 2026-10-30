(* The instructions: CIL's opcodes as a table (a byte or two, a name,
 * an operand), a method's IL decoded to them, and their inverse, an
 * instruction's bytes (for Writer). ECMA-335, Partition III.
 *
 * The machine is a stack machine whose instructions are typed by what
 * is on the stack, not by their name: `add` adds two int32, two int64
 * or two floats, where the JVM has iadd, ladd, fadd, dadd. So the IL is
 * small (226 opcodes, the survey's programs use 86), and a pass must
 * know each slot's type before it can compile a method (the verifier,
 * the JIT); the interpreter (Machine) knows it by the tag of each value.
 *
 *     static int Rec(int n)              IL_0000: ldarg.0
 *     {                                  IL_0001: ldc.i4.2
 *       if (n < 2) return n;             IL_0002: bge.s IL_0006
 *       return Rec(n - 1) + Rec(n - 2);  IL_0004: ldarg.0
 *     }                                  IL_0005: ret
 *                                        IL_0006: ldarg.0
 *                                        IL_0007: ldc.i4.1
 *                                        IL_0008: sub
 *                                        IL_0009: call int32 Fib::Rec(int32)
 *                                        IL_000e: ldarg.0
 *                                        ...
 *
 * Many opcodes are one instruction in several sizes: ldarg.0 (1 byte),
 * ldarg.s 4 (2), ldarg 300 (4); br.s and br. Decoded, they are one
 * constructor of [op] (Ldarg 0): the machine has one case where the
 * file has three, and the name is kept beside for the listing.
 * A branch's target is the instruction's index in the method's array
 * once decoded, not a byte offset.
 *
 * others:
 * The JVM's bytecode (1995) is CIL's model: a stack, locals by number,
 * a method's code in its class's file. Its opcodes say their types
 * (iload, aload, fadd) because Java's first implementation was an
 * interpreter that would not keep tags; CIL (2000) was always meant to
 * be compiled, so its opcodes leave the types to be inferred. *)

(* a load's, a store's, a conversion's type *)
type kind = K_i1 | K_u1 | K_i2 | K_u2 | K_i4 | K_u4 | K_i8 | K_u8
          | K_i | K_u | K_r4 | K_r8 | K_ref

type binop = Add | Sub | Mul | Div | Div_un | Rem | Rem_un
           | And | Or | Xor | Shl | Shr | Shr_un
           | Add_ovf | Add_ovf_un | Mul_ovf | Mul_ovf_un | Sub_ovf | Sub_ovf_un

(* a conditional branch's comparison, with .un: unsigned, or unordered
 * for floats *)
type cmp = Eq | Ne | Ge | Gt | Le | Lt

type op =
  | Nop
  | Break
  | Ldarg of int | Ldarga of int | Starg of int
  | Ldloc of int | Ldloca of int | Stloc of int
  | Ldnull
  | Ldc_i4 of int32 | Ldc_i8 of int64 | Ldc_r of float
  | Dup | Pop
  | Jmp of int | Call of int | Calli of int | Callvirt of int
  | Ret
  | Br of int
  | Brfalse of int | Brtrue of int
  | Bcmp of cmp * bool * int        (* bool: .un *)
  | Switch of int array
  | Ldind of kind | Stind of kind
  | Binop of binop
  | Neg | Not
  | Conv of kind * bool * bool       (* .ovf, .un *)
  | Conv_r_un
  | Cpobj of int | Ldobj of int | Stobj of int
  | Ldstr of int
  | Newobj of int
  | Castclass of int | Isinst of int
  | Unbox of int | Unbox_any of int | Box of int
  | Throw | Rethrow
  | Ldfld of int | Ldflda of int | Stfld of int
  | Ldsfld of int | Ldsflda of int | Stsfld of int
  | Newarr of int | Ldlen
  | Ldelema of int
  | Ldelem of kind | Ldelem_any of int
  | Stelem of kind | Stelem_any of int
  | Refanyval of int | Mkrefany of int | Refanytype
  | Ckfinite
  | Ldtoken of int
  | Endfinally
  | Leave of int
  | Ceq | Cgt of bool | Clt of bool
  | Ldftn of int | Ldvirtftn of int
  | Arglist | Localloc | Endfilter
  | Initobj of int
  | Cpblk | Initblk
  | Sizeof of int
  (* the prefixes, an instruction of their own here *)
  | Constrained of int
  | Prefix of string                (* tail., volatile., readonly., unaligned., no. *)

type instr = {
  at : int;                         (* its offset in the method's IL *)
  name : string;                    (* as written: ldarg.0, br.s *)
  op : op;
}

exception Bad_il of string

(* a method's IL, its branches' targets as indexes in the array *)
val decode : string -> instr array
(* the index of the instruction at an offset (Not_found if none: an
 * exception clause's offsets are turned with it) *)
val index : instr array -> int -> int

(* the opcodes as they are written, for the listing and the writer:
 * (its bytes, 1 or 2, as a number: 0xFE01 for ceq, its name) *)
val opcodes : (int * string) list

(* an instruction's tokens, renumbered (the writer's, once its rows
 * are laid out) *)
val map_tokens : (int -> int) -> op -> op

(* what an instruction takes from the stack and leaves on it; a call's,
 * a ret's from the signature given *)
val stack_effect : (int -> int * bool) -> bool -> op -> int * int

(* an instruction's bytes, its branches' targets as offsets: the
 * shortest form (ldarg.0, ldc.i4.s); a branch in its long form, as the
 * writer cannot know the distance before it has laid the code out *)
val encode : Buffer.t -> op -> unit
