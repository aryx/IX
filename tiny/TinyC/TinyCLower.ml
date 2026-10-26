(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyCLower.mli *)
open Common
open TinyCTypes
open TinyCTree

(*****************************************************************************)
(* The stack machine *)
(*****************************************************************************)

type ir =
  | Imm of int64
  | Place of place                    (* a variable's address *)
  | Load of ty                        (* the address on top by its value *)
  | Store of ty                       (* value and address by the value *)
  | Op of binop * ty
      (* a b by a op b, of the operands' type; a relation 1 or 0 *)
  | Unop of unop * ty
  | Ext of ty                         (* the value on top to a type *)
  | Dup | Drop
  | Call of string option * int * bool
      (* the name, or the address on top of the arguments; their number;
       * a result *)
  | Label of int | Jmp of int | Jz of int | Jnz of int
  | Ret of bool

let show i =
  let w t = string_of_int (size t) ^ (if unsigned t then "u" else "") in
  let l k = Printf.sprintf "L%d" k in
  match i with
  | Imm v -> "imm " ^ Int64.to_string v | Place (Global s) -> "addr " ^ s
  | Place (Local o) -> Printf.sprintf "frame -%d" o
  | Place (Param o) -> Printf.sprintf "param %d" o
  | Load t -> "load " ^ w t | Store t -> "store " ^ w t
  | Op (o, t) -> "op " ^ binop_name o ^ " " ^ w t
  | Unop (o, _) -> if o = Neg then "neg" else "com" | Ext t -> "ext " ^ w t
  | Dup -> "dup" | Drop -> "drop"
  | Call (f, n, r) ->
      Printf.sprintf "call %s %d%s" (f ||| "*") n (if r then " ->" else "")
  | Label k -> l k ^ ":" | Jmp k -> "jmp " ^ l k | Jz k -> "jz " ^ l k
  | Jnz k -> "jnz " ^ l k | Ret v -> if v then "ret value" else "ret"

(* the current function's, the last first *)
let code : ir list ref = ref []
let emit i = code := i :: !code
let labels = ref 0
let label () = incr labels; !labels

(* the value of e, pushed *)
let rec value (e : expr) : unit =
  match e.d with
  | Const v -> emit (Imm v)
  | Addr p -> emit (Place p)
  | Deref a ->
      value a;
      (match e.t with Arr _ | Struct _ | Func _ -> () | t -> emit (Load t))
  | Cur -> emit (Load e.t)
  | Un (o, a) -> value a; emit (Unop (o, e.t))
  | Bin (o, a, b) -> value a; value b; emit (Op (o, a.t))
  | Cond (c, a, b) ->
      let other = label () and out = label () in
      value c;
      emit (Jz other);
      value a;
      emit (Jmp out);
      emit (Label other);
      value b;
      emit (Label out)
  | Asg (l, r, cur) ->
      value (addr l);
      if cur then emit Dup;
      value r;
      emit (Store l.t)
  | Apply (f, args) ->
      List.iter value args; emit (Call (Some f, List.length args, e.t <> Void))
  | ApplyPtr (f, args) ->
      List.iter value args; value f;
      emit (Call (None, List.length args, e.t <> Void))
  | Conv a ->
      value a;
      (match a.t, e.t with
       | (Arr _ | Ptr _ | Void), _ | _, Void -> ()
       | _ -> emit (Ext e.t))
  | Comma (a, b) -> value a; if a.t <> Void then emit Drop; value b

(* an expression as a statement *)
let for_effect (e : expr) = value e; if e.t <> Void then emit Drop

(* where break and continue go; the labels of a switch's cases *)
type targets = {
  brk : int option; cont : int option; cases : (int64 option * int) list ref }

let rec lower (k : targets) (s : stmt) =
  let jump = function
    | Some l -> emit (Jmp l)
    | None -> error "break or continue outside a loop" in
  match s with
  | Expr e -> for_effect e
  | Block l -> List.iter (lower k) l
  | If (c, a, b) ->
      let other = label () in
      value c;
      emit (Jz other);
      lower k a;
      (match b with
       | Some b ->
           let out = label () in
           emit (Jmp out); emit (Label other); lower k b; emit (Label out)
       | None -> emit (Label other))
  | Do (body, c) ->
      let top = label () and cont = label () and out = label () in
      emit (Label top);
      lower { k with brk = Some out; cont = Some cont } body;
      emit (Label cont); value c; emit (Jnz top); emit (Label out)
  | For (init, c, step, body) ->
      Option.iter for_effect init;
      let top = label () and cont = label () and out = label () in
      emit (Label top);
      Option.iter (fun c -> value c; emit (Jz out)) c;
      lower { k with brk = Some out; cont = Some cont } body;
      emit (Label cont);
      Option.iter for_effect step;
      emit (Jmp top); emit (Label out)
  | Switch (tmp, v, body) ->
      (* the value in a temporary, the cases after the body *)
      for_effect (assign false tmp v);
      let dispatch = label () and out = label () in
      emit (Jmp dispatch);
      let cases = ref [] in
      lower { k with brk = Some out; cases } body;
      let mine = List.rev !cases in
      emit (Jmp out);
      emit (Label dispatch);
      List.iter (fun (c, l) ->
        match c with
        | Some v -> value (binary (R Eq) tmp (num v long_t)); emit (Jnz l)
        | None -> ()) mine;
      emit (Jmp (match List.assoc_opt None mine with
                 | Some l -> l
                 | None -> out));
      emit (Label out)
  | Case v ->
      let l = label () in k.cases := (v, l) :: !(k.cases); emit (Label l)
  | Break -> jump k.brk
  | Continue -> jump k.cont
  | Return None -> emit (Ret false)
  | Return (Some e) -> value e; emit (Ret true)
