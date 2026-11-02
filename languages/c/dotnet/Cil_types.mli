(* C's types as .NET's, for mini-cc -dotnet (plan_dotnet_languages.md,
 * stage 5, decision 4): a managed C, whose values are the CTS's, so
 * that a C# or ML program can take them as they are. What C does
 * that the CTS's types do not allow is refused at compile time, as
 * C++/CLI's safe mode (/clr:safe) refused it.
 *
 *     C                        .NET
 *     char, short, int, long   int8, int16, int32, int32 (Plan 9's long)
 *     vlong, float, double     int64, float32, float64
 *     unsigned ...             uint8 ... uint64
 *     int a[3][4]              int32[] of 12: an array of arrays one array
 *     struct Node              a class, Node: its members fields, its
 *                              arrays and structures made by its
 *                              constructor; copied by Clone (=)
 *     T*                       Ptr<T>: an array and an index; 0 is null
 *     int ( * )(int, char* )   Func<int32, Ptr<int8>, int32>
 *     void*                    Ptr<object>: malloc's, given a type
 *
 * A pointer is a pair, not a managed reference (int32&): a reference
 * can neither be kept in a field nor moved, and C's pointers are kept
 * in structures (a Node's next) and moved (p++). The pair moves within
 * its array and .NET checks each access against the array's bounds:
 * arithmetic past the end is caught when the pointer is used, not
 * when it is made. Ptr's methods: Get and Set ( *p ), Add (p + n, in
 * elements), Diff (p - q, Ptr's indexes), Eq (p == q: both null, or
 * one array and one index):
 *
 *     int a[10], *p = &a[3];      p    Ptr<int32> { a = the array; i = 3 }
 *     *p = 100;                   p.Set(100), as a.[3] <- 100
 *     p++;                        p = p.Add(1)
 *
 * A variable whose address is taken (&x, x a scalar or a structure)
 * lives in an array of one element, so that its Ptr has an array; a
 * global always does (its address may be taken in a function not yet
 * read). Each slot (a local, a parameter, a result) of a char or a
 * short is an int32, as C passes them; an array's element and a
 * member keep their width (stelem.i1 truncates, ldelem.i1 extends).
 *
 * others: decision 4's first plan was C++/CLI's int32& for a pointer
 * into an array. Microsoft's C++/CLI (2005) compiled all of C++ with
 * /clr (unverifiable: raw pointers into the native heap) and refused
 * pointers with /clr:safe, where a program used .NET's handles (T^);
 * Ptr here is the safe C a fat pointer makes, as Cyclone's (2002) and
 * CCured's (2002) did for safety on native machines. *)

exception Refused of int * string

(* not in the managed C: the line, what *)
val refuse : int -> string -> 'a

(* a structure's class: its token, constructor, Clone, and each member's
 * offset, type and field *)
type strukt = {
  stok : int;
  sctor : int;
  sclone : int;
  fields : (int * Tree.typ * int) list;
}

(* the assembly being made: its writer, references, the program's class
 * (its functions, globals, literals), what is made by a name of ours *)
type c = {
  w : Writer.t;
  runtime : int;
  console : int;
  cls : int;
  memo : (string, int) Hashtbl.t;
  mutable structs : (Tree.typ * strukt) list;
  mutable classes : (Tree.typ * int) list;
}

val memo : c -> string -> (unit -> int) -> int
val static : Signature.t list -> Signature.t -> Signature.meth
val instance : Signature.t list -> Signature.t -> Signature.meth
(* System's class (IO.Stream: System.IO's), a member of it *)
val sys : c -> string -> int
val lib : c -> string -> string -> Signature.meth -> int

(* a method's code: the instructions (reversed), the labels' places,
 * the locals *)
type code = {
  mutable ops : Il.op list;
  mutable n : int;
  labels : (int, int) Hashtbl.t;
  mutable nlabels : int;
  mutable locals : Signature.t list;
  mutable nlocals : int;
}

val new_code : unit -> code
val emit : code -> Il.op -> unit
val label : code -> int
val place : code -> int -> unit
val local : code -> Signature.t -> int
(* the code a method's body, its branches' labels made indexes *)
val finish : c -> code -> int -> unit
(* ldc.i4 *)
val ldc : code -> int -> unit

(* an array's element, under its arrays; the elements of an array type *)
val base : Tree.typ -> Tree.typ
val count : int -> Tree.typ -> int

(* the Ptr class, made at the start, and its members for an element's
 * type *)
val make_ptr_class : c -> unit
val ptr_of : c -> Signature.t -> Signature.t
val ptr_ctor : c -> Signature.t -> int
val ptr_get : c -> Signature.t -> int
val ptr_set : c -> Signature.t -> int
val ptr_add : c -> Signature.t -> int
val ptr_diff : c -> Signature.t -> int
val ptr_eq : c -> Signature.t -> int
val ptr_array : c -> Signature.t -> int
val ptr_index : c -> Signature.t -> int

(* a type's token, as newarr takes it *)
val token_of : c -> Signature.t -> int

(* a C type where it is stored (an array's element, a member); what a
 * pointer's array holds; a function pointer's delegate; a function's
 * parameters, and a slot's type (a char an int32) *)
val cts : c -> int -> Tree.typ -> Signature.t
val pointee : c -> int -> Tree.typ -> Signature.t
val delegate : c -> int -> Tree.typ -> Signature.t
val params : c -> int -> Tree.typ -> Signature.t list
val slot : c -> int -> Tree.typ -> Signature.t

(* a structure's class, its token alone (what its members may need of
 * it, being made) *)
val struct_class : c -> int -> Tree.typ -> int
val struct_info : c -> int -> Tree.typ -> strukt

(* a new array of a type's base elements, their number pushed by the
 * function; a structure's made each *)
val new_array : c -> code -> int -> Tree.typ -> (unit -> unit) -> unit
val type_token : c -> int -> Tree.typ -> int
val load_kind : c -> int -> Tree.typ -> Il.kind
val store_kind : c -> int -> Tree.typ -> Il.kind

(* a function pointer's Invoke, its delegate's constructor *)
val invoke : c -> int -> Tree.typ -> int
val delegate_ctor : c -> int -> Tree.typ -> int
