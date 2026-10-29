(* The reduced C#'s types and names: the program's classes and the
 * library's, a member looked for in a class and its parents, and the
 * overloads (C#'s 7.5.3, reduced: the candidate whose arguments
 * convert at the least cost, the first of equals).
 *
 * The library is not read from Microsoft's reference assemblies, as
 * csc does: it is mini-dotnet's own description of System (Library),
 * the same data the runtime runs, so a member mini-csc accepts is one
 * mini-dotnet has. Microsoft's dotnet has them all too, by name and
 * signature (a MemberRef), which is how one assembly runs on both.
 *
 *     Console.WriteLine(n + 1)          n an int
 *       methods System.Console "WriteLine": 9 candidates
 *       (int) costs 0, (long) 1, (double) 1, (object) 2: (int)
 *
 *     C#'s conversions (6.1): the same type 0; int to long or double, a
 *     class to its parent or an interface, null to a reference 1; a
 *     value to object (a box) 2. *)

exception Error of string * int
val error : int -> string -> 'a

(* a type: the program's classes and the library's by their record *)
type ty =
  | Void | Bool | Char | Int | Long | Double | String | Object | Null
  | Class of cls * ty list
  | Array of ty
  | Var of int                       (* a library class's type parameter *)
  | MVar of int                      (* a library method's *)
  | Ref of ty                        (* out, ref: an address *)

and cls = {
  name : string;
  short : string;
  kind : kind;
  user : Csc_ast.class_decl option;
  spec : Library.spec option;
  mutable parent : ty option;
  mutable ifaces : ty list;
  mutable fields : field list;
  mutable methods : meth list;
  mutable token : int;               (* the writer's: a TypeDef, a TypeRef *)
}

and kind = K_class | K_interface | K_struct

and field = {
  fname : string;
  ftype : ty;
  fstatic : bool;
  fowner : cls;
  finit : Csc_ast.expr option;
  mutable ftoken : int;
}

and meth = {
  mname : string;
  mowner : cls;
  mstatic : bool;
  mvirtual : bool;                   (* virtual, abstract, override, or an interface's *)
  mabstract : bool;
  moverride : bool;
  mparams : ty list;                 (* as declared: Var for a library class's T *)
  pnames : string list;
  mret : ty;
  mgeneric : int;
  body : Csc_ast.stmt option;
  init : (bool * Csc_ast.expr list) option;    (* a constructor's base(...) or this(...) *)
  mutable mtoken : int;
  mutable implements : bool;         (* a class's method an interface asks: virtual final *)
}

(* the classes by name, the program's and the library's met so far;
 * the namespaces of the usings, System always *)
val classes : (string, cls) Hashtbl.t
val usings : string list ref

val show : ty -> string
val is_value : ty -> bool
(* the library's keys of the primitives: "System.Int32", Int *)
val primitives : (string * ty) list

(* a class of the library's, by its full name *)
val lib_class : string -> cls option
(* a type of the text, at a line *)
val resolve : int -> Csc_ast.ty -> ty
(* a type with a generic class's arguments (Var) and a method's (MVar) *)
val subst : ty list -> ty list -> ty -> ty

val same : ty -> ty -> bool
(* an implicit conversion's cost, None if there is none *)
val convertible : ty -> ty -> int option
(* the methods of a name in a type, its parents and interfaces, their
 * parameters instantiated; the best of them for arguments' types *)
val methods : ty -> string -> (meth * ty list) list
val best : int -> string -> (meth * ty list) list -> ty list -> meth * ty list
val field : ty -> string -> field option
