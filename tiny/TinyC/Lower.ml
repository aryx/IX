(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Lower.mli *)

(*****************************************************************************)
(* The stack machine *)
(*****************************************************************************)

(* a place in a function's code, a number *)
type label = int

type ir =
  | Imm of int64
  | Place of Tree.place               (* a variable's address *)
  | Load of Types.ty                     (* the address on top by its value *)
  | Store of Types.ty                    (* value and address by the value *)
  | Op of Tree.binop * Types.ty
      (* a b by a op b, of the operands' type; a relation 1 or 0 *)
  | Unop of Tree.unop * Types.ty
  | Ext of Types.ty                      (* the value on top to a type *)
  | Dup | Drop
  | Call of Types.sym option * int * bool
      (* the name, or the address on top of the arguments; their number;
       * a result *)
  | Label of label | Jmp of label | Jz of label | Jnz of label
  | Ret of bool
  | Get of Tree.place * Types.ty         (* a variable's value *)
  | Set of Tree.place * Types.ty         (* the value on top, kept, stored
                                          * in a variable *)

let show i =
  let w t =
    string_of_int (Types.size t) ^ (if Types.unsigned t then "u" else "") in
  let l k = Printf.sprintf "L%d" k in
  let place p =
    match p with
    | Tree.Global s -> "addr " ^ s
    | Tree.Local o -> Printf.sprintf "frame -%d" o
    | Tree.Param o -> Printf.sprintf "param %d" o in
  match i with
  | Imm v -> "imm " ^ Int64.to_string v
  | Place p -> place p
  | Load t -> "load " ^ w t | Store t -> "store " ^ w t
  | Op (o, t) -> "op " ^ Tree.binop_name o ^ " " ^ w t
  | Unop (o, _) -> if o = Tree.Neg then "neg" else "com"
  | Ext t -> "ext " ^ w t
  | Dup -> "dup" | Drop -> "drop"
  | Call (f, n, r) ->
      Printf.sprintf "call %s %d%s"
        (match f with Some f -> f | None -> "*") n (if r then " ->" else "")
  | Label k -> l k ^ ":" | Jmp k -> "jmp " ^ l k | Jz k -> "jz " ^ l k
  | Jnz k -> "jnz " ^ l k | Ret v -> if v then "ret value" else "ret"
  | Get (p, t) -> "get " ^ place p ^ " " ^ w t
  | Set (p, t) -> "set " ^ place p ^ " " ^ w t

(* the file's labels, each a new number: a label's name is the file's
 * (Machine's lab), not its function's *)
let labels = ref 0
let label () : label = incr labels; !labels

(*****************************************************************************)
(* The variables that can be kept in registers *)
(*****************************************************************************)

(* A local or a parameter of 1 or 4 bytes (a char, an int, a pointer)
 * whose address is never taken is read and written by Get and Set, and
 * Machine keeps it in a register when one is free. Such a variable is
 * only ever Deref (Addr p) in the tree: &x is a bare Addr p (Tree.addr),
 * and so is a struct's member or an array's element. *)
let scalar (t : Types.ty) =
  match t with
  | Types.Int (k, _) -> k = 1 || k = 4
  | Types.Ptr _ -> true
  | _ -> false

(* the variable of e, when e is one that Get and Set read and write *)
let in_register = ref []
let variable (e : Tree.expr) =
  match e.d with
  | Tree.Deref a ->
      (match a.d with
       | Tree.Addr p when List.mem_assoc p !in_register -> Some p
       | _ -> None)
  | _ -> None

(* The function's variables that can be kept in registers, the heaviest
 * first, with their type and their weight: their uses, each 8 times
 * heavier in a loop. A variable that is anywhere else than in a scalar
 * Deref (Addr p) has its address taken. *)
let variables (body : Tree.stmt) : (Tree.place * (Types.ty * int)) list =
  let seen = ref [] and taken = ref [] in
  let use p t k =
    match List.assoc_opt p !seen with
    | Some (t, n) -> seen := (p, (t, n + k)) :: List.remove_assoc p !seen
    | None -> seen := (p, (t, k)) :: !seen in
  let rec expr k (e : Tree.expr) =
    match e.d with
    | Tree.Deref a ->
        (match a.d with
         | Tree.Addr (Tree.Global _) -> ()
         | Tree.Addr p when scalar e.t -> use p e.t k
         | _ -> expr k a)
    | Tree.Addr p -> taken := p :: !taken
    | Tree.Const _ | Tree.Cur -> ()
    | Tree.Un (_, a) -> expr k a
    | Tree.Conv a -> expr k a
    | Tree.Bin (_, a, b) -> expr k a; expr k b
    | Tree.Asg (a, b, _) -> expr k a; expr k b
    | Tree.Comma (a, b) -> expr k a; expr k b
    | Tree.Cond (c, a, b) -> expr k c; expr k a; expr k b
    | Tree.Apply (_, l) -> List.iter (expr k) l
    | Tree.ApplyPtr (f, l) -> expr k f; List.iter (expr k) l in
  let rec stmt k (s : Tree.stmt) =
    match s with
    | Tree.Expr e -> expr k e
    | Tree.Block l -> List.iter (stmt k) l
    | Tree.If (c, a, b) -> expr k c; stmt k a; Option.iter (stmt k) b
    | Tree.Do (body, c) -> stmt (8 * k) body; expr (8 * k) c
    | Tree.For (init, c, step, body) ->
        Option.iter (expr k) init;
        Option.iter (expr (8 * k)) c;
        Option.iter (expr (8 * k)) step;
        stmt (8 * k) body
    | Tree.Switch (tmp, v, body) -> expr k tmp; expr k v; stmt k body
    | Tree.Return (Some e) -> expr k e
    | Tree.Case _ | Tree.Break | Tree.Continue | Tree.Return None -> () in
  stmt 1 body;
  List.filter (fun (p, _) -> not (List.mem p !taken)) !seen
  |> List.sort (fun (_, (_, a)) (_, (_, b)) -> compare b a)

(*****************************************************************************)
(* Lowering *)
(*****************************************************************************)

(* in x op= y, the variable x when it is read and written by Get and Set:
 * Cur is then its Get, not a load of the address kept below *)
let cur = ref None

(* the value of e pushed: its code given to emit *)
let rec value (emit : ir -> unit) (e : Tree.expr) : unit =
  let value = value emit in
  match e.d with
  | Tree.Const v -> emit (Imm v)
  | Tree.Addr p -> emit (Place p)
  | Tree.Deref a ->
      (match variable e with
       | Some p -> emit (Get (p, e.t))
       | None ->
           value a;
           (match e.t with
            | Types.Arr _ | Types.Struct _ | Types.Func _ -> ()
            | t -> emit (Load t)))
  | Tree.Cur ->
      (match !cur with
       | Some p -> emit (Get (p, e.t))
       | None -> emit (Load e.t))
  | Tree.Un (o, a) -> value a; emit (Unop (o, e.t))
  | Tree.Bin (o, a, b) -> value a; value b; emit (Op (o, a.t))
  | Tree.Cond (c, a, b) ->
      let other = label () and out = label () in
      value c;
      emit (Jz other);
      value a;
      emit (Jmp out);
      emit (Label other);
      value b;
      emit (Label out)
  | Tree.Asg (l, r, kind) ->
      let outer = !cur in
      (match variable l with
       | Some p ->
           cur := Some p;
           value r;
           emit (Set (p, l.t))
       | None ->
           value (Tree.addr l);
           (* (the address again, for Cur's load) *)
           if kind = Tree.Asg_update then emit Dup;
           cur := None;
           value r;
           emit (Store l.t));
      cur := outer
  | Tree.Apply (f, args) ->
      List.iter value args;
      emit (Call (Some f, List.length args, e.t <> Types.Void))
  | Tree.ApplyPtr (f, args) ->
      List.iter value args; value f;
      emit (Call (None, List.length args, e.t <> Types.Void))
  | Tree.Conv a ->
      value a;
      (match a.t, e.t with
       | (Types.Arr _ | Types.Ptr _ | Types.Void), _ | _, Types.Void -> ()
       | _ -> emit (Ext e.t))
  | Tree.Comma (a, b) ->
      value a; if a.t <> Types.Void then emit Drop; value b

(* an expression as a statement *)
let for_effect emit (e : Tree.expr) =
  value emit e; if e.t <> Types.Void then emit Drop

(* where break and continue go; the labels of a switch's cases *)
type targets = {
  brk : label option; cont : label option;
  cases : (int64 option * label) list ref }

let rec lower (emit : ir -> unit) (k : targets) (s : Tree.stmt) =
  let value = value emit and for_effect = for_effect emit
  and lower = lower emit in
  let jump = function
    | Some l -> emit (Jmp l)
    | None -> Types.error "break or continue outside a loop" in
  match s with
  | Tree.Expr e -> for_effect e
  | Tree.Block l -> List.iter (lower k) l
  | Tree.If (c, a, b) ->
      let other = label () in
      value c;
      emit (Jz other);
      lower k a;
      (match b with
       | Some b ->
           let out = label () in
           emit (Jmp out); emit (Label other); lower k b; emit (Label out)
       | None -> emit (Label other))
  | Tree.Do (body, c) ->
      let top = label () and cont = label () and out = label () in
      emit (Label top);
      lower { k with brk = Some out; cont = Some cont } body;
      emit (Label cont); value c; emit (Jnz top); emit (Label out)
  | Tree.For (init, c, step, body) ->
      Option.iter for_effect init;
      let top = label () and cont = label () and out = label () in
      emit (Label top);
      Option.iter (fun c -> value c; emit (Jz out)) c;
      lower { k with brk = Some out; cont = Some cont } body;
      emit (Label cont);
      Option.iter for_effect step;
      emit (Jmp top); emit (Label out)
  | Tree.Switch (tmp, v, body) ->
      (* the value in a temporary, the cases after the body *)
      for_effect (Tree.assign Tree.Asg_set tmp v);
      let dispatch = label () and out = label () in
      emit (Jmp dispatch);
      let cases = ref [] in
      lower { k with brk = Some out; cases } body;
      let mine = List.rev !cases in
      emit (Jmp out);
      emit (Label dispatch);
      List.iter (fun (c, l) ->
        match c with
        | Some v ->
            value (Tree.binary (Tree.R Tree.Eq) tmp (Tree.num v Types.vlong_t));
            emit (Jnz l)
        | None -> ()) mine;
      emit (Jmp (match List.assoc_opt None mine with
                 | Some l -> l
                 | None -> out));
      emit (Label out)
  | Tree.Case v ->
      let l = label () in k.cases := (v, l) :: !(k.cases); emit (Label l)
  | Tree.Break -> jump k.brk
  | Tree.Continue -> jump k.cont
  | Tree.Return None -> emit (Ret false)
  | Tree.Return (Some e) -> value e; emit (Ret true)

(* A value dropped does not need what only computed it from the value
 * below with a constant: x++ as a statement is x += 1, then - 1, then
 * dropped, and the - 1 goes. *)
let rec unused (code : ir list) =
  match code with
  | Ext _ :: rest -> unused rest
  | Op (Tree.A (Tree.Add | Tree.Sub), _) :: Imm _ :: rest -> unused rest
  | _ -> code

let lower_function (body : Tree.stmt) =
  let code = ref [] in
  let emit i =
    code := (match i with Drop -> Drop :: unused !code | _ -> i :: !code) in
  in_register := variables body;
  lower emit { brk = None; cont = None; cases = ref [] } body;
  List.rev !code, !in_register
