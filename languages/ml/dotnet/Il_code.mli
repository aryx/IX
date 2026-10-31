(* What mini-ml -dotnet's lowering writes with (Lower_il.mli): the
 * assembly being made and the members of .NET's library it names, each
 * made once (a TypeRef, a MemberRef, by a name of ours); and a method's
 * code as it is made, its labels resolved to the instructions' numbers
 * at the end (IL's branches are offsets), its locals, its protected
 * regions. mini-tiger's emitter has the same, for the same Writer. *)

(* what is not compiled yet: its line, what it is *)
exception Refused of int * string

(* refused: the line, what, the stage of plan_dotnet_languages.md
 * that will have it *)
val refuse : int -> string -> string -> 'a

type c = {
  w : Writer.t;
  runtime : int;                        (* the assembly System.Runtime *)
  console : int;                        (* System.Console, in its own assembly *)
  cls : int;                            (* the unit's class *)
  uname : string;                       (* the unit's name *)
  memo : (string, int) Hashtbl.t;       (* what is made, by a name of ours *)
}

(* [make]'s token, made once by that name *)
val memo : c -> string -> (unit -> int) -> int

(* a static method's signature, an instance one's *)
val static : Signature.t list -> Signature.t -> Signature.meth
val instance : Signature.t list -> Signature.t -> Signature.meth

(* a class of System's, a member of one: its class, name, signature *)
val sys : c -> string -> int
val lib : c -> string -> string -> Signature.meth -> int

(* a class (namespace, name, flags, parent, the parent's constructor
 * and what it is given) whose constructor takes its fields' values, in
 * order: the class, its constructor, its fields *)
val new_class :
  c -> string -> string -> int -> int -> int -> Il.op list -> (string * Signature.t) list -> int * int * int list

val object_ctor : c -> int

type code = {
  mutable ops : Il.op list;             (* reversed *)
  mutable n : int;
  labels : (int, int) Hashtbl.t;        (* a label to its instruction *)
  mutable nlabels : int;
  mutable locals : Signature.t list;    (* reversed *)
  mutable nlocals : int;
  args : (int, int) Hashtbl.t;          (* a variable's argument *)
  slots : (int, int) Hashtbl.t;         (* a variable's local *)
  (* a try's labels: start, end, its handler's start and end; the class caught *)
  mutable clauses : (int * int * int * int * int) list;
  (* the values on the stack under the expression being made: a try
   * must start with none (IL's rule), so one inside an operand is
   * refused *)
  mutable pending : int;
  (* in a closure's Invoke: a variable it captured, its field of this *)
  captured : (int, int) Hashtbl.t;
}

val new_code : unit -> code
val emit : code -> Il.op -> unit

(* a label, then where it is: the next instruction *)
val label : code -> int
val place : code -> int -> unit

(* a local of a type: its number *)
val local : code -> Signature.t -> int

(* the code made the method's body: labels to instructions' numbers *)
val finish : c -> code -> int -> unit

(* a match that no case took: OCaml's Match_failure, thrown *)
val match_failure : c -> code -> unit
