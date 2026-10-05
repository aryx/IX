(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Prtree.mli *)
open Tree
open Tree_helpers

(* the -x dump: a function's tree, one node per line, indented *)
let rec show_expr (x : expr) =
  let sub = List.map show_expr in
  let node name args = "(" ^ String.concat " " (name :: args) ^ ")" in
  let s =
    match x.e with
    | Name (s, _, o) -> if o <> 0 then Printf.sprintf "%s%+d" s.name o else s.name
    | Const v -> Int64.to_string v
    | Fconst f -> Printf.sprintf "%g" f
    | Str s | Lstr s -> Printf.sprintf "%S" s
    | Reg r -> Printf.sprintf "R%d" r
    | Indreg (r, o) -> Printf.sprintf "%d(R%d)" o r
    | Unary (o, a) -> node (unop_name o) (sub [ a ])
    | Binary (o, a, b) -> node (binop_name o) (sub [ a; b ])
    | Assign (o, a, b) -> node (match o with Some o -> "AS" ^ binop_name o | None -> "AS") (sub [ a; b ])
    | Cond (a, b, c) -> node "COND" (sub [ a; b; c ])
    | Call (f, args) -> node "FUNC" (sub (f :: args))
    | Elem (a, s) -> node "ELEM" (sub [ a ] @ [ s.name ])
    | Dot (a, o) -> node "DOT" (sub [ a ] @ [ string_of_int o ])
    | Sizeof a -> node "SIZE" (sub [ a ])
    | Sizeof_type t -> node "SIZE" [ show_type (Some t) ]
    | Typed a -> show_expr a
  in
  if x.t == untyped then s else s ^ ":" ^ tname x.t.etype

let prtree (title : string) (s : stmt) =
  let b = Buffer.create 256 in
  let line d fmt = Printf.ksprintf (fun s -> Buffer.add_string b (String.make (2 * d) ' ' ^ s ^ "\n")) fmt in
  let rec go d = function
    | Expr x -> line d "%s" (show_expr x)
    | Block l -> List.iter (go d) l
    | If (c, a, b) -> line d "IF %s" (show_expr c); go (d + 1) a; Option.iter (fun b -> line d "ELSE"; go (d + 1) b) b
    | While (c, s) -> line d "WHILE %s" (show_expr c); go (d + 1) s
    | Dowhile (s, c) -> line d "DO"; go (d + 1) s; line d "WHILE %s" (show_expr c)
    | For (i, c, st, s) ->
        line d "FOR %s" (match c with Some c -> show_expr c | None -> "");
        go (d + 1) i; go (d + 1) st; go (d + 1) s
    | Switch (x, s) -> line d "SWITCH %s" (show_expr x); go (d + 1) s
    | Case (Some x) -> line d "CASE %s" (show_expr x)
    | Case None -> line d "DEFAULT"
    | Label l -> line d "%s:" l.lsym.name
    | Goto l -> line d "GOTO %s" l.lsym.name
    | Break -> line d "BREAK"
    | Continue -> line d "CONTINUE"
    | Return (x, _) -> line d "RETURN %s" (match x with Some x -> show_expr x | None -> "")
    | Used l -> line d "USED %s" (String.concat " " (List.map show_expr l))
    | Set l -> line d "SET %s" (String.concat " " (List.map show_expr l))
  in
  line 0 "== %s ==" title;
  go 0 s;
  Buffer.contents b
