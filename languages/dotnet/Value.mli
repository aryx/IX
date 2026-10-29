(* The runtime's data: the types as the machine knows them once loaded
 * (a class, its fields laid out, its methods and their slots), and the
 * values it computes with (on the evaluation stack, in the locals, in
 * the objects' fields). Types loads them (from an assembly or from the
 * Library's description), Machine runs the methods over them.
 *
 * {b An object is laid out} (plan_dotnet.md, decision 4): its class,
 * then a string of bytes for its fields that are numbers (int32 at an
 * offset, little-endian, int64, float64...), then an array of its
 * fields that are references. A struct inside an object is flattened
 * into it, its numbers among the numbers, its references among the
 * references. An array is the same thing, its elements one after the
 * other (a stride of bytes and of references each):
 *
 *     class Shape { int x, y; static int count; }
 *     class Rect : Shape { int w, h; string name; }
 *
 *     a Rect     cls ---> Rect   (fields: x 0, y 4, w 8, h 12; name r0)
 *                s   [ x  | y  | w  | h  ]      16 bytes
 *                r   [ name ]
 *
 *     Vec[3]     cls ---> Vec[]  (element: 8 bytes, 0 references)
 *     (a struct) s   [ X0 | Y0 | X1 | Y1 | X2 | Y2 ]
 *
 * So OCaml's collector never sees a number as a pointer: they are apart
 * by construction, where a real CLR gives its collector a map of each
 * class's references. And the JIT's code can reach a field by its
 * offset, not by its name.
 *
 * {b A value carries its type} (decision 5): an int32, an int64, a
 * float, a reference, a struct's copy, a managed pointer. The IL's
 * instructions are typed by what is on the stack (`add`), so the
 * interpreter looks at the tags; the JIT will know them before.
 *
 * {b A managed pointer} (`ref`, ldloca, ldflda, ldelema) is a place:
 * a slot of an array of values (a local, an argument, a reference
 * field or element), or a place in an object's bytes, or a struct
 * inside an object. Not an address: OCaml moves its blocks.
 *
 * Native integers (IntPtr, an array's length) are 32 bits here: no
 * pointer is ever turned into one, and our arrays are short.
 *
 * others:
 * Mono (2004, Miguel de Icaza's) keeps a class's layout in its
 * MonoClass, and a field's offset in its MonoClassField; an object is
 * a header (the vtable, a lock word) and the fields at their offsets,
 * a map of references kept for its collector. Here the map is the
 * split itself. *)

(* a type at run time: a class instantiated, a type parameter replaced *)
type typ =
  | T_void | T_bool | T_char
  | T_i1 | T_u1 | T_i2 | T_u2 | T_i4 | T_u4 | T_i8 | T_u8
  | T_r4 | T_r8 | T_i | T_u
  | T_class of cls         (* a reference type: a class, an interface, string, object *)
  | T_value of cls         (* a value type: a struct, an enum *)
  | T_array of typ         (* T[], its class made when asked (Types.array_class) *)
  | T_byref of typ
  | T_ptr of typ
  | T_var of int           (* the class's type parameter, before instantiation *)
  | T_mvar of int          (* the method's *)

and cls = {
  name : string;           (* its full name, with its arguments: Stack`1<System.Int32> *)
  short : string;          (* Stack`1, as Type.Name says it *)
  kind : kind;
  args : typ array;        (* the instantiation; [||] if not generic *)
  mutable parent : cls option;
  mutable interfaces : cls list;
  mutable fields : field list;       (* its own, in order *)
  mutable methods : meth list;       (* its own *)
  mutable vtable : meth array;       (* by slot: the virtual methods, its parents' first *)
  mutable nbytes : int;              (* an instance's layout, its parents' included *)
  mutable nrefs : int;
  mutable statics : store option;    (* its static fields, made at its loading *)
  mutable init : init;               (* its static constructor *)
  mutable element : typ option;      (* an array's *)
  imap : (string, meth) Hashtbl.t;   (* an interface's method (its key) to its implementation *)
  origin : origin;
}

and kind = Class | Interface | Struct | Enum | Delegate

and init = Not_run | Running | Done

(* where a class comes from: an assembly's TypeDef, or the library *)
and origin =
  | From of image * int                (* the TypeDef's row *)
  | Builtin

and field = {
  fname : string;
  fcls : cls;
  ftype : typ;
  fstatic : bool;
  mutable off : int;       (* in the bytes: a number's offset, a struct's first *)
  mutable roff : int;      (* in the references: a reference's index, a struct's first *)
}

and meth = {
  mname : string;
  mcls : cls;
  static : bool;
  virt : bool;
  abstract : bool;
  newslot : bool;
  params : typ list;       (* not counting `this` *)
  ret : typ;
  generic : int;           (* its type parameters *)
  margs : typ array;       (* their instantiation *)
  key : string;            (* its name and signature as declared ("!0" for T), for MemberRefs *)
  mutable slot : int;      (* in the vtable, -1 if not virtual *)
  mutable body : body;
  def : (image * int) option;        (* its MethodDef's row *)
  cache : (int, resolved) Hashtbl.t; (* its tokens, resolved in its context *)
}

and body =
  | Il_body of int                     (* its RVA, not yet decoded *)
  | Decoded of code
  | Native of (value array -> value)   (* the library's, in OCaml: `this` first *)
  | Runtime                            (* a delegate's, made by the machine *)
  | No_body                            (* abstract *)

and code = {
  instrs : Il.instr array;
  clauses : clause array;              (* the IL's, by indexes *)
  locals : typ array;
  max_stack : int;
}

and clause = {
  ckind : int;             (* 0 catch, 1 filter, 2 finally, 4 fault *)
  tstart : int; tend : int;
  hstart : int; hend : int;
  catch : cls option;
  filter : int;            (* a filter's code, from there to hstart; -1 *)
}

(* a token's meaning, once looked up *)
and resolved =
  | R_type of typ
  | R_field of field
  | R_meth of meth
  | R_string of value

(* an object, an array, a boxed value or a struct's copy *)
and store = {
  cls : cls;
  s : Bytes.t;
  r : value array;
  len : int;               (* an array's elements, 0 for the others *)
  mutable native : native;
}

(* what the library keeps in its objects beside their fields *)
and native =
  | No_native
  | N_list of vec                      (* List<T> *)
  | N_dict of dict                     (* Dictionary<K, V> *)
  | N_buffer of Buffer.t               (* StringBuilder, the interpolation's handler *)
  | N_type of typ                      (* System.Type *)
  | N_delegate of value * meth         (* its target (Null if static), its method *)
  | N_message of string                (* an exception's *)

and vec = { mutable items : value array; mutable count : int }

(* a Dictionary's entries in the order they were added (as .NET's are,
 * when nothing is removed: programs come to rely on it), found by
 * their keys' hash (GetHashCode, maybe a user's: the machine's) *)
and dict = {
  index : (int, int) Hashtbl.t;        (* a hash to its entries, Hashtbl.find_all *)
  mutable keys : value array;
  mutable vals : value array;
  mutable used : int;
}

and value =
  | Null
  | I4 of int32
  | I8 of int64
  | R8 of float
  | Obj of store             (* a reference to an object *)
  | Str of string            (* a reference to a string (Latin-1, decision 7) *)
  | Vt of store              (* a struct, copied as it is moved *)
  | Ptr of place
  | Fn of meth               (* ldftn's native int *)
  | Handle of typ            (* RuntimeTypeHandle (ldtoken) *)
  | Data of string * int     (* a field's initial bytes (FieldRVA), in this
                              * file at this offset: ldtoken's of a field,
                              * for an array's initializer *)

and place =
  | Slot of value array * int          (* a local, an argument, a reference field or element *)
  | Bytes of store * int * typ         (* a number in an object's bytes *)
  | Inside of store * int * int * cls  (* a struct in an object: its first byte and reference *)

(* an assembly loaded *)
and image = {
  img : Image.t;
  aname : string;
  types : (int, cls) Hashtbl.t;        (* by TypeDef row, the non-generic ones *)
  strings : (int, value) Hashtbl.t;    (* ldstr's, so the same literal is the same string *)
}

(* a .NET exception on its way up OCaml's stack, from a throw or from
 * the machine (a null's field, an index out of range) *)
exception Thrown of store

(* a number's size in an object's bytes; 0 for a reference or a struct *)
val scalar_size : typ -> int
(* does it live among the references? *)
val is_ref : typ -> bool

(* a type's name as Type.Name and keys: System.Int32, Stack`1<System.String> *)
val typ_key : typ -> string
(* a method's key: Name(param, ...)ret, over keys *)
val meth_key : string -> typ list -> typ -> string

(* the room of a field or an element of this type: (bytes, references) *)
val footprint : typ -> int * int

(* a value read from bytes and written to them, as its type says *)
val load : Bytes.t -> int -> typ -> value
val store_at : Bytes.t -> int -> typ -> value -> unit

(* the default value of a type: 0, null, a struct's zeros *)
val zero : typ -> value

(* a struct's copy *)
val copy : store -> store
(* a store of this class's layout, its fields zero, [n] elements' for an array *)
val make_store : cls -> int -> store

(* [cls] is [c] or derives from it, or implements it *)
val subclass : cls -> cls -> bool
