(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Il_code.mli *)

module S = Signature
module W = Writer

exception Refused of int * string

let refuse (loc : int) (what : string) (stage : string) : 'a =
  raise (Refused (loc, Printf.sprintf "%s: not compiled to .NET yet (plan_dotnet_languages.md, stage %s)" what stage))

(*****************************************************************************)
(* The assembly's classes and members, each made when first needed *)
(*****************************************************************************)

type c = {
  w : W.t;
  runtime : int;                        (* the assembly System.Runtime *)
  console : int;                        (* System.Console, in its own assembly *)
  cls : int;                            (* the unit's class *)
  uname : string;                       (* the unit's name: its types' namespace *)
  memo : (string, int) Hashtbl.t;       (* what is made, by a name of ours *)
  (* in a polymorphic function: its type variables, its method's generic
   * parameters (!!0...) *)
  mutable tvars : (string * S.t) list;
}

let memo (c : c) (key : string) (make : unit -> int) : int =
  match Hashtbl.find_opt c.memo key with
  | Some x -> x
  | None ->
      let x = make () in
      Hashtbl.replace c.memo key x;
      x

let static (ps : S.t list) (r : S.t) : S.meth = { S.has_this = false; generic = 0; vararg = false; ret = r; params = ps }
let instance (ps : S.t list) (r : S.t) : S.meth = { (static ps r) with has_this = true }

let sys (c : c) (name : string) : int =
  memo c ("type " ^ name) (fun () -> if name = "Console" then c.console else W.type_ref c.w c.runtime "System" name)

(* a member of .NET's library: its class, name and signature *)
let lib (c : c) (cls : string) (name : string) (m : S.meth) : int =
  memo c (cls ^ "::" ^ name ^ S.encode_method m) (fun () -> W.member_ref c.w (sys c cls) name m)

(* a class whose constructor takes its fields' values, in order, after
 * calling its parent's ([parent_args], before them): F#'s records and
 * union cases are so, and C# makes one with new T(...) *)
let new_class (c : c) (ns : string) (name : string) (flags : int) (parent : int) (parent_ctor : int) (parent_args : Il.op list)
    (fields : (string * S.t) list) : int * int * int list =
  let cls = W.type_def c.w ns name flags parent in
  let toks = List.map (fun ((n, t) : string * S.t) -> W.field_def c.w cls n 0x0006 t) fields in
  let ctor = W.method_def c.w cls ".ctor" 0x1886 (instance (List.map snd fields) S.Void) in
  let sets = List.concat (List.mapi (fun (i : int) (f : int) -> [ Il.Ldarg 0; Il.Ldarg (i + 1); Il.Stfld f ]) toks) in
  W.set_body c.w ctor [] (Array.of_list (([ Il.Ldarg 0 ] @ parent_args @ [ Il.Call parent_ctor ]) @ sets @ [ Il.Ret ])) [];
  (cls, ctor, toks)

let object_ctor (c : c) : int = lib c "Object" ".ctor" (instance [] S.Void)

(*****************************************************************************)
(* A method's code: the instructions, their labels, the locals *)
(*****************************************************************************)

type code = {
  mutable ops : Il.op list;             (* reversed *)
  mutable n : int;
  labels : (int, int) Hashtbl.t;        (* a label to its instruction *)
  mutable nlabels : int;
  mutable locals : S.t list;            (* reversed *)
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

let new_code () : code =
  { ops = []; n = 0; labels = Hashtbl.create 8; nlabels = 0; locals = []; nlocals = 0; args = Hashtbl.create 4;
    slots = Hashtbl.create 8; clauses = []; pending = 0; captured = Hashtbl.create 4 }

let emit (k : code) (op : Il.op) : unit =
  k.ops <- op :: k.ops;
  k.n <- k.n + 1

let label (k : code) : int =
  k.nlabels <- k.nlabels + 1;
  k.nlabels

let place (k : code) (l : int) : unit = Hashtbl.replace k.labels l k.n

let local (k : code) (ty : S.t) : int =
  k.locals <- ty :: k.locals;
  k.nlocals <- k.nlocals + 1;
  k.nlocals - 1

(* the labels made instructions' numbers, and the body set *)
let finish (c : c) (k : code) (meth : int) : unit =
  let at (l : int) : int = Hashtbl.find k.labels l in
  let ops =
    Array.of_list
      (List.rev_map
         (fun (op : Il.op) ->
           match op with
           | Il.Br l -> Il.Br (at l)
           | Il.Brfalse l -> Il.Brfalse (at l)
           | Il.Brtrue l -> Il.Brtrue (at l)
           | Il.Bcmp (x, u, l) -> Il.Bcmp (x, u, at l)
           | Il.Leave l -> Il.Leave (at l)
           | op -> op)
         k.ops) in
  let clauses =
    List.rev_map
      (fun ((ts, te, hs, he, cls) : int * int * int * int * int) ->
        { W.kind = 0; try_start = at ts; try_end = at te; handler_start = at hs; handler_end = at he; catch = cls })
      k.clauses in
  W.set_body c.w meth (List.rev k.locals) ops clauses

(* a match that no case took: OCaml's Match_failure, here an exception
 * of that message *)
let match_failure (c : c) (k : code) : unit =
  emit k (Il.Ldstr (W.user_string c.w "Match_failure"));
  emit k (Il.Newobj (lib c "Exception" ".ctor" (instance [ S.String ] S.Void)));
  emit k Il.Throw
