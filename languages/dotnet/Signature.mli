(* Signatures: the types of a field, a method, a method's locals, a
 * generic type's instantiation, as the blobs encode them (ECMA-335,
 * II.23.2). They stay at the metadata's level: a class is a token
 * (TypeDef, TypeRef or TypeSpec), a type parameter its number; the
 * loader (Types) gives them their meaning in a context.
 *
 *     static int Rec(int n)     00 01 08 08
 *                               |  |  |  the parameter: int32 (0x08)
 *                               |  |  the return type: int32
 *                               |  one parameter
 *                               no `this`, not generic
 *
 *     Dictionary<string, int>   15 12 <TypeRef> 02 0E 08
 *                               generic instance of a class, 2 arguments
 *
 * A number in a blob is compressed: 1, 2 or 4 bytes as its size needs
 * (Image.compressed's rule), a token too, its table in the low 2 bits
 * (TypeDefOrRef).
 *
 * others:
 * The JVM writes its signatures as text, `(I)I` for Rec, `Ljava/lang/
 * String;` for a class, read by a small parser; .NET's are bytes, which
 * name a class by its row rather than by its name and so are shorter,
 * but need the tables to be read. *)

type t =
  | Void
  | Bool
  | Char
  | I1 | U1 | I2 | U2 | I4 | U4 | I8 | U8
  | R4 | R8
  | I | U                     (* native int: a pointer's size *)
  | String
  | Object
  | TypedRef
  | Class of int              (* a reference type, by its token *)
  | ValueType of int          (* a value type (a struct, an enum) *)
  | Var of int                (* the class's type parameter number n: !0 *)
  | MVar of int               (* the method's: !!0 *)
  | Ptr of t                  (* an unmanaged pointer *)
  | ByRef of t                (* a managed one: `ref`, `out` *)
  | SzArray of t              (* T[], from 0 *)
  | Array of t * int          (* T[,]: its rank *)
  | GenericInst of t * t list (* List<int>: Class or ValueType, and the arguments *)
  | FnPtr of meth

and meth = {
  has_this : bool;            (* an instance method: `this` its argument 0 *)
  generic : int;              (* its type parameters, 0 if none *)
  vararg : bool;
  ret : t;
  params : t list;
}

(* the blobs, by what they describe *)
val field : string -> t
val method_ : string -> meth
val locals : string -> t list
val type_spec : string -> t
val method_spec : string -> t list
(* a property's: its type *)
val property : string -> t

(* a token in the TypeDefOrRef encoding (II.23.2.8) as a token *)
val type_token : int -> int

(* as ildasm writes it, the classes named by the function given *)
val show : (int -> string) -> t -> string
val show_meth : (int -> string) -> string -> meth -> string
