(* C's expressions to IL, for mini-cc -dotnet: a typed tree
 * (Check.complex, managed: a member a Dot, an array's address its own
 * type) pushed on IL's stack, its l-values places.
 *
 * A place is what an assignment, ++ or += reads and writes: a slot (an
 * argument, a local), an array's element (a global, a boxed variable),
 * a field (a member), a Ptr's ( *p ). What it needs is pushed once, kept
 * in a temporary when it has effects, so that *p++ += 2 computes p++
 * once:
 *
 *     *p++ += 2     t = p; p = p.Add(1)      (the place: Pptr t)
 *                   t.Set(t.Get() + 2)
 *
 * The typing leaves C's machine in the tree: a pointer's offset is
 * bytes, the index converted to the pointer's type and multiplied by
 * the element's size; p - q is bytes divided by it. Here an offset is
 * made elements again ([elements]: a product by the size is the index,
 * a constant divided, else a division), and p - q is Ptr.Diff
 * multiplied, which the typing's division undoes.
 *
 * print and sprint's formats are compiled where they are (Cil_strings),
 * their arguments computed first, in order. *)

open Cil_types

(* the file's globals: name, type when first seen, field (an array) *)
val globals : (string * Tree.typ * int) list ref
val reset : unit -> unit

(* a global's field, made at its first use *)
val global : c -> int -> string -> Tree.typ -> int

(* a variable of a function: an argument or local, or a local holding
 * an array (a C array; Boxed: a scalar or structure whose address is
 * taken, one element) *)
type var = Slot of bool * int | Boxed of int | Array_var of int

(* a function being compiled: the variables by key *)
type fn = {
  c : c;
  k : code;
  fname : string;
  vars : (string, var) Hashtbl.t;
}

(* a variable's key: name, offset, type (two blocks' may share one) *)
val key : Tree.sym -> int -> Tree.typ -> string

(* a function's method, by name and type: made at its first call or its
 * definition *)
val func_method : c -> int -> string -> Tree.typ -> int

val const : fn -> int -> Tree.typ -> int64 -> unit

(* n pushed; a value given (a structure's copy); given to a place of a
 * type (malloc's array of it); for effects only *)
val expr : fn -> Tree.expr -> unit
val value : fn -> Tree.expr -> unit
val assigned : fn -> Tree.typ -> Tree.expr -> unit
val drop : fn -> Tree.expr -> unit

(* &l: a Ptr to its array's first element, or a function's delegate *)
val address : fn -> Tree.expr -> unit

(* to the label if n's truth is the bool *)
val branch : fn -> Tree.expr -> bool -> int -> unit
