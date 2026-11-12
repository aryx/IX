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

let show i =
  let w t =
    string_of_int (Types.size t) ^ (if Types.unsigned t then "u" else "") in
  let l k = Printf.sprintf "L%d" k in
  match i with
  | Imm v -> "imm " ^ Int64.to_string v
  | Place (Tree.Global s) -> "addr " ^ s
  | Place (Tree.Local o) -> Printf.sprintf "frame -%d" o
  | Place (Tree.Param o) -> Printf.sprintf "param %d" o
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

(* the file's labels, each a new number: a label's name is the file's
 * (Machine's lab), not its function's *)
let labels = ref 0
let label () : label = incr labels; !labels

(* the value of e pushed: its code given to emit *)
let rec value (emit : ir -> unit) (e : Tree.expr) : unit =
  let value = value emit in
  match e.d with
  | Tree.Const v -> emit (Imm v)
  | Tree.Addr p -> emit (Place p)
  | Tree.Deref a ->
      value a;
      (match e.t with
       | Types.Arr _ | Types.Struct _ | Types.Func _ -> ()
       | t -> emit (Load t))
  | Tree.Cur -> emit (Load e.t)
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
      value (Tree.addr l);
      (* (the address again, for Cur's load) *)
      if kind = Tree.Asg_update then emit Dup;
      value r;
      emit (Store l.t)
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

let lower_function (body : Tree.stmt) : ir list =
  let code = ref [] in
  let emit i = code := i :: !code in
  lower emit { brk = None; cont = None; cases = ref [] } body;
  List.rev !code
