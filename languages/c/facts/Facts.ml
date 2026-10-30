(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Facts.mli *)

(* the facts, the last first, and the ones said already *)
let lines : string list ref = ref []
let said : (string, unit) Hashtbl.t = Hashtbl.create 1021

(* the function being read, and its temporaries' and its calls' numbers *)
let scope : string ref = ref "_init"
let temps : int ref = ref 0
let calls : int ref = ref 0

(* a fact's argument: a name, or a number (an argument's position) *)
type arg = Sym of string | Num of int

let quote (s : string) : string =
  let b = Buffer.create (String.length s + 2) in
  Buffer.add_char b '\'';
  String.iter (fun (c : char) -> if c = '\'' || c = '\\' then Buffer.add_char b '\\'; Buffer.add_char b c) s;
  Buffer.add_char b '\'';
  Buffer.contents b

let sym (s : string) : arg = Sym s

let added : (string -> arg list -> unit) ref = ref (fun (_ : string) (_ : arg list) -> ())

let fact (relation : string) (args : arg list) : unit =
  let show = function Sym s -> quote s | Num n -> string_of_int n in
  let line = relation ^ "(" ^ String.concat ", " (List.map show args) ^ ")." in
  if not (Hashtbl.mem said line) then begin
    Hashtbl.add said line ();
    lines := line :: !lines;
    !added relation args
  end

let text () : string = String.concat "\n" (List.rev !lines) ^ "\n"

let temp () : string =
  incr temps;
  Printf.sprintf "%s__t%d" !scope !temps

let field (s : Tree.sym) : string = "_fld__" ^ s.name

(* a name as the analysis's variable: a local is its function's *)
let variable (x : Tree.expr) (s : Tree.sym) (c : Tree.cls) : string =
  let v : string =
    match c with
    | Tree.Cauto | Tree.Cparam | Tree.Clocal -> !scope ^ "__" ^ s.name
    | _ -> s.name in
  (* an array's elements are one place, which the array's name points to *)
  if x.t.etype = Tree.Tarray then fact "point_to" [ sym v; sym ("_array_elt_" ^ v) ];
  v

(* the allocators: each call's result points to a place of its own *)
let allocators : string list = [ "malloc"; "mallocz"; "calloc"; "realloc"; "kalloc"; "smalloc"; "xalloc"; "emalloc"; "sbrk" ]

(* the variable that holds an expression's value; None: nothing a
 * pointer could be (a constant, a comparison) *)
let rec value (x : Tree.expr) : string option =
  match x.e with
  | Tree.Name (s, c, _) -> Some (variable x s c)
  | Tree.Const _ | Tree.Fconst _ | Tree.Reg _ | Tree.Indreg _ | Tree.Sizeof_type _ -> None
  | Tree.Sizeof _ -> None
  | Tree.Str _ | Tree.Lstr _ ->
      let t = temp () in
      fact "point_to" [ sym t; sym (Printf.sprintf "_str_in_%s_line_%d" !scope x.line) ];
      Some t
  | Tree.Typed a -> value a
  | Tree.Unary (Tree.Ind, { e = Tree.Binary (Tree.Add, a, i); _ }) ->
      (* a[i] *)
      ignore (value i);
      load "assign_array_elt" (value a)
  | Tree.Unary (Tree.Ind, a) -> load "assign_content" (value a)
  | Tree.Unary (Tree.Addr, a) -> address a
  | Tree.Unary ((Tree.Cast | Tree.Preinc | Tree.Predec | Tree.Postinc | Tree.Postdec | Tree.Pos), a) -> value a
  | Tree.Unary (_, a) ->
      ignore (value a);
      None
  | Tree.Binary ((Tree.Add | Tree.Sub), a, b) -> (
      (* a pointer moved is the same pointer here *)
      let va = value a in
      let vb = value b in
      match va with Some _ -> va | None -> vb)
  | Tree.Binary (Tree.Comma, a, b) ->
      ignore (value a);
      value b
  | Tree.Binary (_, a, b) ->
      ignore (value a);
      ignore (value b);
      None
  | Tree.Assign (_, l, r) ->
      let v = value r in
      store l v;
      v
  | Tree.Cond (c, a, b) -> (
      ignore (value c);
      let va = value a in
      let vb = value b in
      match (va, vb) with
      | None, None -> None
      | _ ->
          let t = temp () in
          Option.iter (fun (v : string) -> fact "assign" [ sym t; sym v ]) va;
          Option.iter (fun (v : string) -> fact "assign" [ sym t; sym v ]) vb;
          Some t)
  | Tree.Call (f, args) -> call x f args
  | Tree.Elem (a, s) ->
      let t = temp () in
      Option.iter (fun (v : string) -> fact "assign_load_field" [ sym t; sym v; sym (field s) ]) (structure a);
      Some t
  | Tree.Dot (a, _) -> value a

(* p = *q, p = a[i]: a temporary for what is read *)
and load (relation : string) (from : string option) : string option =
  match from with
  | None -> None
  | Some v ->
      let t = temp () in
      fact relation [ sym t; sym v ];
      Some t

(* the variable that holds a structure's address, for x.m and x->m *)
and structure (a : Tree.expr) : string option =
  match a.e with
  | Tree.Unary (Tree.Ind, p) -> value p
  | _ -> address a

(* &x *)
and address (a : Tree.expr) : string option =
  match a.e with
  | Tree.Name (s, c, _) ->
      let v = variable a s c in
      (* (a function's name and an array's are their address already) *)
      if a.t.etype = Tree.Tfunc || a.t.etype = Tree.Tarray then Some v
      else begin
        let t = temp () in
        fact "assign_address" [ sym t; sym v ];
        Some t
      end
  | Tree.Unary (Tree.Ind, { e = Tree.Binary (Tree.Add, arr, i); _ }) -> (
      ignore (value i);
      match value arr with
      | None -> None
      | Some v ->
          let t = temp () in
          fact "assign_array_element_address" [ sym t; sym v ];
          Some t)
  | Tree.Unary (Tree.Ind, p) -> value p
  | Tree.Elem (b, s) -> (
      match structure b with
      | None -> None
      | Some v ->
          let t = temp () in
          fact "assign_field_address" [ sym t; sym v; sym (field s) ];
          Some t)
  | Tree.Unary (Tree.Cast, b) | Tree.Typed b -> address b
  | _ ->
      ignore (value a);
      None

(* l = v *)
and store (l : Tree.expr) (v : string option) : unit =
  let put (relation : string) (target : string option) : unit =
    match (target, v) with
    | Some t, Some v -> fact relation [ sym t; sym v ]
    | _ -> () in
  match l.e with
  | Tree.Name (s, c, _) -> put "assign" (Some (variable l s c))
  | Tree.Unary (Tree.Ind, { e = Tree.Binary (Tree.Add, a, i); _ }) ->
      ignore (value i);
      put "assign_array_deref" (value a)
  | Tree.Unary (Tree.Ind, p) -> put "assign_deref" (value p)
  | Tree.Elem (a, s) -> (
      match (structure a, v) with
      | Some t, Some v -> fact "assign_store_field" [ sym t; sym (field s); sym v ]
      | _ -> ())
  | Tree.Unary (Tree.Cast, a) | Tree.Typed a -> store a v
  | _ -> ignore (value l)

and call (x : Tree.expr) (f : Tree.expr) (args : Tree.expr list) : string option =
  let values = List.map value args in
  let direct : string option =
    match f.e with
    | Tree.Name (s, c, _) when f.t.etype = Tree.Tfunc && c <> Tree.Cauto && c <> Tree.Cparam -> Some s.name
    | _ -> None in
  let t = temp () in
  match direct with
  | Some name when List.mem name allocators ->
      fact "point_to" [ sym t; sym (Printf.sprintf "_malloc_in_%s_line_%d" !scope x.line) ];
      Some t
  | _ ->
      incr calls;
      let site = sym (Printf.sprintf "_in_%s_line_%d_%d" !scope x.line !calls) in
      List.iteri
        (fun (i : int) (v : string option) ->
          Option.iter (fun (v : string) -> fact "argument" [ site; Num (i + 1); sym v ]) v)
        values;
      fact "call_ret" [ site; sym t ];
      (match direct with
       | Some name -> fact "call_direct" [ site; sym name ]
       | None -> (
           (* a pointer's star called and the pointer called are the same call *)
           let target : string option = match f.e with Tree.Unary (Tree.Ind, p) -> value p | _ -> value f in
           match target with
           | Some v -> fact "call_indirect" [ site; sym v ]
           | None -> ()));
      Some t

let rec statement (s : Tree.stmt) : unit =
  match s with
  | Tree.Expr x -> ignore (value x)
  | Tree.Block l -> List.iter statement l
  | Tree.If (c, a, b) ->
      ignore (value c);
      statement a;
      Option.iter statement b
  | Tree.While (c, a) | Tree.Dowhile (a, c) | Tree.Switch (c, a) ->
      ignore (value c);
      statement a
  | Tree.For (start, test, step, body) ->
      statement start;
      Option.iter (fun (c : Tree.expr) -> ignore (value c)) test;
      statement step;
      statement body
  | Tree.Return (Some x, _) -> Option.iter (fun (v : string) -> fact "assign" [ sym ("ret_" ^ !scope); sym v ]) (value x)
  | Tree.Used l | Tree.Set l -> List.iter (fun (x : Tree.expr) -> ignore (value x)) l
  | Tree.Case _ | Tree.Label _ | Tree.Goto _ | Tree.Break | Tree.Continue | Tree.Return (None, _) -> ()

(* the parameters' places in the frame, in order, as Declare.argmark
 * lays them: a parameter is known in the body by its place *)
let parameter_offsets (f : Tree.sym) : int list =
  match f.typ with
  | None -> []
  | Some t ->
      let offset = ref (match t.link with Some r -> Declare.align 0 r Declare.Aarg0 | None -> 0) in
      let rec go (p : Tree.typ option) : int list =
        match p with
        | None -> []
        | Some p ->
            offset := Declare.align !offset p Declare.Aarg1;
            let here = !offset in
            offset := Declare.align !offset p Declare.Aarg2;
            here :: go p.down in
      go t.down

(* the parameters the body names: each with its place *)
let rec parameters_in (x : Tree.expr) (acc : (string * int) list ref) : unit =
  let sub (a : Tree.expr) : unit = parameters_in a acc in
  match x.e with
  | Tree.Name (s, Tree.Cparam, offset) -> if not (List.mem_assoc s.name !acc) then acc := (s.name, offset) :: !acc
  | Tree.Name _ | Tree.Const _ | Tree.Fconst _ | Tree.Str _ | Tree.Lstr _ | Tree.Reg _ | Tree.Indreg _ | Tree.Sizeof_type _ -> ()
  | Tree.Unary (_, a) | Tree.Elem (a, _) | Tree.Dot (a, _) | Tree.Sizeof a | Tree.Typed a -> sub a
  | Tree.Binary (_, a, b) | Tree.Assign (_, a, b) -> sub a; sub b
  | Tree.Cond (a, b, c) -> sub a; sub b; sub c
  | Tree.Call (f, args) -> sub f; List.iter sub args

let rec parameters_of (s : Tree.stmt) (acc : (string * int) list ref) : unit =
  let expr (x : Tree.expr) : unit = parameters_in x acc in
  match s with
  | Tree.Expr x -> expr x
  | Tree.Block l -> List.iter (fun (s : Tree.stmt) -> parameters_of s acc) l
  | Tree.If (c, a, b) -> expr c; parameters_of a acc; Option.iter (fun (s : Tree.stmt) -> parameters_of s acc) b
  | Tree.While (c, a) | Tree.Dowhile (a, c) | Tree.Switch (c, a) -> expr c; parameters_of a acc
  | Tree.For (start, test, step, body) ->
      parameters_of start acc; Option.iter expr test; parameters_of step acc; parameters_of body acc
  | Tree.Return (Some x, _) -> expr x
  | Tree.Used l | Tree.Set l -> List.iter expr l
  | Tree.Case _ | Tree.Label _ | Tree.Goto _ | Tree.Break | Tree.Continue | Tree.Return (None, _) -> ()

let func (f : Tree.sym) (body : Tree.stmt) : unit =
  scope := f.name;
  temps := 0;
  calls := 0;
  fact "point_to" [ sym f.name; sym f.name ];
  fact "return" [ sym f.name; sym ("ret_" ^ f.name) ];
  let named : (string * int) list ref = ref [] in
  parameters_of body named;
  List.iteri
    (fun (i : int) (offset : int) ->
      List.iter
        (fun ((name, o) : string * int) ->
          if o = offset then fact "parameter" [ sym f.name; Num (i + 1); sym (f.name ^ "__" ^ name) ])
        !named)
    (parameter_offsets f);
  statement body;
  scope := "_init"

(* the member at an offset of a global's type, the innermost, an
 * array's element's when it is an array of structures *)
let rec member (t : Tree.typ) (o : int) : Tree.sym option =
  match t.etype with
  | Tree.Tarray -> (match t.link with Some e when e.width > 0 -> member e (o mod e.width) | _ -> None)
  | Tree.Tstruct | Tree.Tunion ->
      let rec find (m : Tree.typ option) =
        match m with
        | None -> None
        | Some m when o >= m.offset && o < m.offset + max m.width 1 -> (
            match member m (o - m.offset) with Some f -> Some f | None -> m.tsym)
        | Some m -> find m.down in
      find t.link
  | _ -> None

let global (s : Tree.sym) (x : Tree.expr) (o : int) : unit =
  let array : bool = match s.typ with Some t -> t.etype = Tree.Tarray | None -> false in
  if array then fact "point_to" [ sym s.name; sym ("_array_elt_" ^ s.name) ];
  (* a structure's member, by its name as x->f is (Dev consdev = { "cons", consread }) *)
  let put (v : string) : unit =
    match Option.bind s.typ (fun t -> member t o) with
    | Some f -> fact "assign_store_field" [ sym s.name; sym (field f); sym v ]
    | None -> fact (if array then "assign_array_deref" else "assign") [ sym s.name; sym v ] in
  (* a global's initializer is a constant: a name in it is an address,
   * whether the & is still there or the typing has taken it *)
  let rec named (x : Tree.expr) : Tree.expr option =
    match x.e with
    | Tree.Name _ -> Some x
    | Tree.Typed a | Tree.Unary ((Tree.Cast | Tree.Addr), a) -> named a
    | _ -> None in
  match named x with
  | Some n -> Option.iter put (address n)
  | None -> Option.iter put (value x)
