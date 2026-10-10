(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Wam_compile.mli *)

module P = Prolog
module M = Prolog_machine

type ctx = {
  m : M.t;
  preds : (string, Wam.pred) Hashtbl.t;
  mutable xneed : int;
  mutable aux : int;
}

let create (m : M.t) : ctx = { m; preds = Hashtbl.create 255; xneed = 0; aux = 0 }

let fail_addr : Wam.addr = { code = [| Wam.Fail |]; pc = 0 }

let new_pred (name : string) (arity : int) (kind : Wam.kind) : Wam.pred =
  { name; arity; kind; entry = fail_addr; linked = []; codes = [] }

let intern (ctx : ctx) (name : string) (arity : int) : Wam.pred =
  let k = M.key name arity in
  match Hashtbl.find_opt ctx.preds k with
  | Some p -> p
  | None ->
      let p = new_pred name arity Wam.Unknown in
      Hashtbl.replace ctx.preds k p;
      p

(*****************************************************************************)
(* The index *)
(*****************************************************************************)

(* the clauses to try, in order: one is its code, several a choice point *)
let block (codes : Wam.instr array list) : Wam.addr =
  match codes with
  | [] -> fail_addr
  | [ c ] -> { code = c; pc = 0 }
  | first :: rest ->
      let n = List.length codes in
      let b = Array.make n Wam.Fail in
      b.(0) <- Wam.Try { code = first; pc = 0 };
      List.iteri
        (fun (i : int) (c : Wam.instr array) ->
          let a : Wam.addr = { code = c; pc = 0 } in
          b.(i + 1) <- (if i + 2 = n then Wam.Trust a else Wam.Retry a))
        rest;
      { code = b; pc = 0 }

type key = No_key | Atom_key of string | Int_key of int | Struct_key of string

let key_of (c : Prolog_db.clause) : key =
  match c.head with
  | P.Struct (_, first :: _) -> (
      match first with
      | P.Atom a -> Atom_key a
      | P.Int n -> Int_key n
      | P.Struct (f, _) -> Struct_key f
      | _ -> No_key)
  | _ -> No_key

(* a key's clauses, the last first: its own and those with a variable there *)
type group = Wam.instr array list ref

let index (cs : Prolog_db.clause list) (codes : Wam.instr array list) : Wam.addr =
  let keys = List.map key_of cs in
  if List.length cs < 2 || List.for_all (fun (k : key) -> k = No_key) keys then block codes
  else begin
    let atoms : (string, group) Hashtbl.t = Hashtbl.create 17 in
    let ints : (int, group) Hashtbl.t = Hashtbl.create 17 in
    let structs : (string, group) Hashtbl.t = Hashtbl.create 17 in
    let vars : group = ref [] in
    List.iter2
      (fun (k : key) (code : Wam.instr array) ->
        match k with
        | No_key ->
            vars := code :: !vars;
            Hashtbl.iter (fun (_ : string) (g : group) -> g := code :: !g) atoms;
            Hashtbl.iter (fun (_ : int) (g : group) -> g := code :: !g) ints;
            Hashtbl.iter (fun (_ : string) (g : group) -> g := code :: !g) structs
        | Atom_key a -> (
            match Hashtbl.find_opt atoms a with
            | Some g -> g := code :: !g
            | None -> Hashtbl.replace atoms a (ref (code :: !vars)))
        | Int_key n -> (
            match Hashtbl.find_opt ints n with
            | Some g -> g := code :: !g
            | None -> Hashtbl.replace ints n (ref (code :: !vars)))
        | Struct_key f -> (
            match Hashtbl.find_opt structs f with
            | Some g -> g := code :: !g
            | None -> Hashtbl.replace structs f (ref (code :: !vars))))
      keys codes;
    let s : Wam.switch =
      { on_var = block codes;
        atoms = Hashtbl.create (Hashtbl.length atoms + 1);
        ints = Hashtbl.create (Hashtbl.length ints + 1);
        structs = Hashtbl.create (Hashtbl.length structs + 1);
        other = block (List.rev !vars) } in
    Hashtbl.iter (fun (a : string) (g : group) -> Hashtbl.replace s.atoms a (block (List.rev !g))) atoms;
    Hashtbl.iter (fun (n : int) (g : group) -> Hashtbl.replace s.ints n (block (List.rev !g))) ints;
    Hashtbl.iter (fun (f : string) (g : group) -> Hashtbl.replace s.structs f (block (List.rev !g))) structs;
    { code = [| Wam.Switch_on_term s |]; pc = 0 }
  end

(*****************************************************************************)
(* A clause *)
(*****************************************************************************)

(* a body's goal, as it will be compiled *)
type goal =
  | Call of Wam.pred * P.term list
  | Inline of string * (M.t -> P.term array -> bool) * P.term list
  | Neck
  | Cut of P.term
  | Fail
  | Catch_enter of P.term * P.term
  | Catch_exit

let rec flatten (t : P.term) (rest : P.term list) : P.term list =
  match t with
  | P.Struct (",", [ a; b ]) -> flatten a (flatten b rest)
  | t -> t :: rest

let rec has_cut (t : P.term) : bool =
  match t with
  | P.Atom "!" -> true
  | P.Struct (("," | ";" | "->"), [ a; b ]) -> has_cut a || has_cut b
  | _ -> false

(* a condition's cut is its own: call/1 keeps it there *)
let cond (t : P.term) : P.term = if has_cut t then P.Struct ("call", [ t ]) else t

(* the clause's cuts inside a disjunction or after an arrow: to the level kept *)
let rec replace_cuts (level : P.term) (used : bool ref) (t : P.term) : P.term =
  match t with
  | P.Atom "!" ->
      used := true;
      P.Struct ("$cut", [ level ])
  | P.Struct (",", [ a; b ]) -> P.Struct (",", [ replace_cuts level used a; replace_cuts level used b ])
  | P.Struct (";", [ a; b ]) -> P.Struct (";", [ replace_cuts level used a; replace_cuts level used b ])
  | P.Struct ("->", [ c; t ]) -> P.Struct ("->", [ c; replace_cuts level used t ])
  | t -> t

(* a term's variables, each once, in the order met *)
let locals (t : P.term) : int list =
  let acc : int list ref = ref [] in
  let rec go (t : P.term) : unit =
    match t with
    | P.Local k -> if not (List.mem k !acc) then acc := k :: !acc
    | P.Struct (_, args) -> List.iter go args
    | _ -> () in
  go t;
  List.rev !acc

let rec position (k : int) (ks : int list) : int =
  match ks with
  | k' :: rest -> if k = k' then 0 else 1 + position k rest
  | [] -> 0

let rec clause (ctx : ctx) (c : Prolog_db.clause) : Wam.instr array =
  (* the goals; the level a cut cuts to is one more variable *)
  let level : P.term = P.Local c.nvars in
  let level_used = ref false in
  let calls = ref 0 in
  let named (name : string) (args : P.term list) : goal =
    match Hashtbl.find_opt ctx.m.procs (M.key name (List.length args)) with
    | Some (M.Det f) -> Inline (name, f, args)
    | _ ->
        incr calls;
        Call (intern ctx name (List.length args), args) in
  let goal_of (t : P.term) : goal list =
    match t with
    | P.Atom "!" ->
        if !calls = 0 then [ Neck ]
        else begin
          level_used := true;
          [ Cut level ]
        end
    | P.Atom "true" -> []
    | P.Atom ("fail" | "false") -> [ Fail ]
    | P.Atom "$catch_exit" -> [ Catch_exit ]
    | P.Struct ("$catch_enter", [ catcher; recovery ]) -> [ Catch_enter (catcher, recovery) ]
    | P.Struct ("$cut", [ l ]) -> [ Cut l ]
    | P.Struct ((";" | "->"), [ _; _ ]) | P.Struct ("\\+", [ _ ]) ->
        let p, args = aux ctx (replace_cuts level level_used t) in
        incr calls;
        [ Call (p, args) ]
    | P.Atom name -> [ named name [] ]
    | P.Struct (name, args) -> [ named name args ]
    | t ->
        (* a variable, or what is no goal: call/1 says so when it runs *)
        incr calls;
        [ Call (intern ctx "call" 1, [ t ]) ] in
  let goals : goal list =
    List.rev (List.fold_left (fun (acc : goal list) (t : P.term) -> List.rev_append (goal_of t) acc) [] (flatten c.body [])) in
  let last_is_call : bool = match List.rev goals with Call _ :: _ -> true | _ -> false in
  let env : bool = !calls >= 2 || (!calls = 1 && not last_is_call) in
  (* the variables: how many times, and in which chunks *)
  let nv = c.nvars + 1 in
  let occ = Array.make nv 0 and first = Array.make nv (-1) and perm = Array.make nv false in
  let rec visit (chunk : int) (t : P.term) : unit =
    match t with
    | P.Local k ->
        occ.(k) <- occ.(k) + 1;
        if first.(k) < 0 then first.(k) <- chunk else if first.(k) <> chunk then perm.(k) <- true
    | P.Struct (_, args) -> List.iter (fun (a : P.term) -> visit chunk a) args
    | _ -> () in
  let head_args : P.term list = match c.head with P.Struct (_, args) -> args | _ -> [] in
  List.iter (fun (a : P.term) -> visit 0 a) head_args;
  if !level_used then visit 0 level;
  let chunk = ref 0 and widest = ref (List.length head_args) in
  List.iter
    (fun (g : goal) ->
      match g with
      | Call (_, args) ->
          List.iter (fun (a : P.term) -> visit !chunk a) args;
          widest := max !widest (List.length args);
          incr chunk
      | Inline (_, _, args) ->
          List.iter (fun (a : P.term) -> visit !chunk a) args;
          widest := max !widest (List.length args)
      | Cut l -> visit !chunk l
      | Catch_enter (a, b) -> visit !chunk a; visit !chunk b
      | Neck | Fail | Catch_exit -> ())
    goals;
  (* the registers: Yn for the permanent, Xn above the arguments for the others *)
  let next_x = ref !widest and next_y = ref 0 in
  let regs : Wam.reg array =
    Array.init nv (fun (k : int) ->
        if perm.(k) then begin
          incr next_y;
          Wam.Y (!next_y - 1)
        end
        else begin
          incr next_x;
          Wam.X (!next_x - 1)
        end) in
  let seen = Array.make nv false in
  let out : Wam.instr list ref = ref [] in
  let emit (i : Wam.instr) : unit = out := i :: !out in
  let fresh_x () : int =
    incr next_x;
    !next_x - 1 in
  (* a structure's argument that is no structure *)
  let unify_arg (a : P.term) : unit =
    match a with
    | P.Local k ->
        if occ.(k) = 1 then emit (Wam.Unify_void 1)
        else if seen.(k) then emit (Wam.Unify_value regs.(k))
        else begin
          seen.(k) <- true;
          emit (Wam.Unify_variable regs.(k))
        end
    | a -> emit (Wam.Unify_constant a) in
  (* the head: a structure inside another is matched after it *)
  let rec get_struct (f : string) (args : P.term list) (r : int) : unit =
    emit (Wam.Get_structure (f, List.length args, r));
    let later : (int * P.term) list ref = ref [] in
    List.iter
      (fun (a : P.term) ->
        match a with
        | P.Struct _ ->
            let t = fresh_x () in
            emit (Wam.Unify_variable (Wam.X t));
            later := (t, a) :: !later
        | a -> unify_arg a)
      args;
    List.iter
      (fun ((t, a) : int * P.term) -> match a with P.Struct (g, gargs) -> get_struct g gargs t | _ -> ())
      (List.rev !later) in
  (* the body: a structure inside another is built before it *)
  let rec put_struct (f : string) (args : P.term list) (target : int) : unit =
    let inner : int list =
      List.rev
        (List.fold_left
           (fun (acc : int list) (a : P.term) ->
             match a with
             | P.Struct (g, gargs) ->
                 let t = fresh_x () in
                 put_struct g gargs t;
                 t :: acc
             | _ -> -1 :: acc)
           [] args) in
    emit (Wam.Put_structure (f, List.length args, target));
    List.iter2 (fun (a : P.term) (t : int) -> if t >= 0 then emit (Wam.Unify_value (Wam.X t)) else unify_arg a) args inner in
  let put_args (args : P.term list) : unit =
    List.iteri
      (fun (i : int) (a : P.term) ->
        match a with
        | P.Local k ->
            if seen.(k) then emit (Wam.Put_value (regs.(k), i))
            else begin
              seen.(k) <- true;
              emit (Wam.Put_variable (regs.(k), i))
            end
        | P.Struct (f, fargs) -> put_struct f fargs i
        | a -> emit (Wam.Put_constant (a, i)))
      args in
  if env then emit (Wam.Allocate !next_y);
  if !level_used then begin
    seen.(c.nvars) <- true;
    emit (Wam.Get_level regs.(c.nvars))
  end;
  List.iteri
    (fun (i : int) (a : P.term) ->
      match a with
      | P.Local k ->
          if occ.(k) = 1 then ()
          else if seen.(k) then emit (Wam.Get_value (regs.(k), i))
          else begin
            seen.(k) <- true;
            emit (Wam.Get_variable (regs.(k), i))
          end
      | P.Struct (f, fargs) -> get_struct f fargs i
      | a -> emit (Wam.Get_constant (a, i)))
    head_args;
  let left = ref (List.length goals) in
  let reg_of (t : P.term) : Wam.reg = match t with P.Local k -> regs.(k) | _ -> Wam.X 0 in
  List.iter
    (fun (g : goal) ->
      decr left;
      match g with
      | Call (p, args) ->
          put_args args;
          if !left = 0 then begin
            if env then emit Wam.Deallocate;
            emit (Wam.Execute p)
          end
          else emit (Wam.Call p)
      | Inline (name, f, args) ->
          put_args args;
          emit (Wam.Builtin (name, List.length args, f))
      | Neck -> emit Wam.Neck_cut
      | Cut l -> emit (Wam.Cut (reg_of l))
      | Fail -> emit Wam.Fail
      | Catch_enter (a, b) -> emit (Wam.Catch_enter (reg_of a, reg_of b))
      | Catch_exit -> emit Wam.Catch_exit)
    goals;
  if not last_is_call then begin
    if env then emit Wam.Deallocate;
    emit Wam.Proceed
  end;
  ctx.xneed <- max ctx.xneed !next_x;
  Array.of_list (List.rev !out)

(* a disjunction, an if-then-else or a negation: a predicate of the
 * variables it has, and the goal that calls it *)
and aux (ctx : ctx) (t : P.term) : Wam.pred * P.term list =
  let ks = locals t in
  let n = List.length ks in
  let rec rename (t : P.term) : P.term =
    match t with
    | P.Local k -> P.Local (position k ks)
    | P.Struct (f, args) -> P.Struct (f, List.map rename args)
    | t -> t in
  let head : P.term = if n = 0 then P.Atom "$aux" else P.Struct ("$aux", List.init n (fun (i : int) -> P.Local i)) in
  let conj (a : P.term) (b : P.term) : P.term = P.Struct (",", [ a; b ]) in
  let cut : P.term = P.Atom "!" in
  let bodies : P.term list =
    match t with
    | P.Struct (";", [ P.Struct ("->", [ c; th ]); el ]) -> [ conj (cond c) (conj cut th); el ]
    | P.Struct (";", [ a; b ]) -> [ a; b ]
    | P.Struct ("->", [ c; th ]) -> [ conj (cond c) (conj cut th) ]
    | P.Struct ("\\+", [ g ]) -> [ conj (cond g) (conj cut (P.Atom "fail")); P.Atom "true" ]
    | t -> [ t ] in
  ctx.aux <- ctx.aux + 1;
  let p = new_pred ("$aux" ^ string_of_int ctx.aux) n Wam.Fixed in
  let codes : Wam.instr array list =
    List.map
      (fun (b : P.term) ->
        let c : Prolog_db.clause = { head; body = rename b; nvars = n; id = 0; erased = false } in
        clause ctx c)
      bodies in
  p.codes <- List.mapi (fun (i : int) (code : Wam.instr array) -> (i, code)) codes;
  p.entry <- block codes;
  (p, List.map (fun (k : int) -> P.Local k) ks)

let link (ctx : ctx) (p : Wam.pred) (cs : Prolog_db.clause list) : unit =
  let old : (int, Wam.instr array) Hashtbl.t = Hashtbl.create 17 in
  List.iter (fun ((id, code) : int * Wam.instr array) -> Hashtbl.replace old id code) p.codes;
  p.codes <-
    List.map
      (fun (c : Prolog_db.clause) ->
        match Hashtbl.find_opt old c.id with
        | Some code -> (c.id, code)
        | None -> (c.id, clause ctx c))
      cs;
  p.linked <- cs;
  p.entry <- index cs (List.map (fun ((_, code) : int * Wam.instr array) -> code) p.codes)

(*****************************************************************************)
(* The listing *)
(*****************************************************************************)

(* (Xn and An are the same register: An where an argument is meant) *)
let reg_text (r : Wam.reg) : string =
  match r with Wam.X i -> "X" ^ string_of_int (i + 1) | Wam.Y i -> "Y" ^ string_of_int (i + 1)

let listing (ops : P.ops) (p : Wam.pred) : string =
  let b = Buffer.create 1024 in
  let printed : Wam.pred list ref = ref [] in
  let rec pred (p : Wam.pred) : unit =
    printed := p :: !printed;
    (* an address: a clause's label, or the clauses a choice point tries *)
    let rec label (a : Wam.addr) : string =
      let rec find (i : int) (codes : (int * Wam.instr array) list) : string =
        match codes with
        | (_, code) :: rest -> if code == a.code then "L" ^ string_of_int i else find (i + 1) rest
        | [] ->
            if a.code == fail_addr.code then "fail"
            else
              String.concat "|"
                (List.map
                   (fun (i : Wam.instr) ->
                     match i with Wam.Try t | Wam.Retry t | Wam.Trust t -> label t | _ -> "?")
                   (Array.to_list a.code)) in
      find 1 p.codes in
    let const (t : P.term) : string = P.to_string ops ~quoted:true t in
    let functor_ (f : string) (n : int) : string = P.atom_text true f ^ "/" ^ string_of_int n in
    let arg (i : int) : string = "A" ^ string_of_int (i + 1) in
    let text (i : Wam.instr) : string =
      match i with
      | Wam.Get_variable (r, i) -> "get_variable " ^ reg_text r ^ ", " ^ arg i
      | Wam.Get_value (r, i) -> "get_value " ^ reg_text r ^ ", " ^ arg i
      | Wam.Get_constant (c, i) -> "get_constant " ^ const c ^ ", " ^ arg i
      | Wam.Get_structure (".", 2, i) -> "get_list " ^ arg i
      | Wam.Get_structure (f, n, i) -> "get_structure " ^ functor_ f n ^ ", " ^ arg i
      | Wam.Put_variable (r, i) -> "put_variable " ^ reg_text r ^ ", " ^ arg i
      | Wam.Put_value (r, i) -> "put_value " ^ reg_text r ^ ", " ^ arg i
      | Wam.Put_constant (c, i) -> "put_constant " ^ const c ^ ", " ^ arg i
      | Wam.Put_structure (".", 2, i) -> "put_list " ^ arg i
      | Wam.Put_structure (f, n, i) -> "put_structure " ^ functor_ f n ^ ", " ^ arg i
      | Wam.Unify_variable r -> "unify_variable " ^ reg_text r
      | Wam.Unify_value r -> "unify_value " ^ reg_text r
      | Wam.Unify_constant c -> "unify_constant " ^ const c
      | Wam.Unify_void n -> "unify_void " ^ string_of_int n
      | Wam.Allocate n -> "allocate " ^ string_of_int n
      | Wam.Deallocate -> "deallocate"
      | Wam.Call q -> "call " ^ functor_ q.name q.arity
      | Wam.Execute q -> "execute " ^ functor_ q.name q.arity
      | Wam.Proceed -> "proceed"
      | Wam.Builtin (name, n, _) -> "builtin " ^ functor_ name n
      | Wam.Fail -> "fail"
      | Wam.Try a -> "try " ^ label a
      | Wam.Retry a -> "retry " ^ label a
      | Wam.Trust a -> "trust " ^ label a
      | Wam.Switch_on_term s ->
          let rows : string list ref = ref [] in
          Hashtbl.iter (fun (k : string) (a : Wam.addr) -> rows := (P.atom_text true k ^ ": " ^ label a) :: !rows) s.atoms;
          Hashtbl.iter (fun (k : int) (a : Wam.addr) -> rows := (string_of_int k ^ ": " ^ label a) :: !rows) s.ints;
          Hashtbl.iter (fun (k : string) (a : Wam.addr) -> rows := (P.atom_text true k ^ "(...): " ^ label a) :: !rows) s.structs;
          String.concat "\n        "
            (("switch_on_term " ^ arg 0) :: ("a variable: " ^ label s.on_var) :: List.sort String.compare !rows)
          ^ "\n        another: " ^ label s.other
      | Wam.Neck_cut -> "neck_cut"
      | Wam.Get_level r -> "get_level " ^ reg_text r
      | Wam.Cut r -> "cut " ^ reg_text r
      | Wam.Catch_enter (c, r) -> "catch_enter " ^ reg_text c ^ ", " ^ reg_text r
      | Wam.Catch_exit -> "catch_exit"
      | Wam.Stop -> "stop" in
    let line (i : Wam.instr) : unit = Buffer.add_string b ("    " ^ text i ^ "\n") in
    Buffer.add_string b (functor_ p.name p.arity ^ ":\n");
    (* (one clause: its code is the entry) *)
    (match p.codes with
     | [ _ ] -> ()
     | [] -> line Wam.Fail
     | _ -> Array.iter line p.entry.code);
    let made : Wam.pred list ref = ref [] in
    List.iteri
      (fun (i : int) ((_, code) : int * Wam.instr array) ->
        Buffer.add_string b (Printf.sprintf "L%d:\n" (i + 1));
        Array.iter
          (fun (i : Wam.instr) ->
            line i;
            match i with
            | Wam.Call q | Wam.Execute q -> (
                match q.kind with
                | Wam.Fixed -> if not (List.memq q !made) then made := q :: !made
                | _ -> ())
            | _ -> ())
          code)
      p.codes;
    List.iter (fun (q : Wam.pred) -> if not (List.memq q !printed) then pred q) (List.rev !made) in
  pred p;
  Buffer.contents b
