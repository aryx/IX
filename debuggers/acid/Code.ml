(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Code.mli *)

open Ast

let binop = function
  | Mul -> "*" | Div -> "/" | Mod -> "%" | Add -> "+" | Sub -> "-" | Rsh -> ">>" | Lsh -> "<<"
  | Lt -> "<" | Gt -> ">" | Leq -> "<=" | Geq -> ">=" | Eq -> "==" | Neq -> "!="
  | Land -> "&" | Xor -> "^" | Lor -> "|"

(* pstr: a string in quotes, its escapes written back *)
let str s =
  let b = Buffer.create (String.length s + 2) in
  Buffer.add_char b '"';
  String.iter (fun c ->
    match c with
    | '\000' -> Buffer.add_string b "\\0" | '\n' -> Buffer.add_string b "\\n" | '\r' -> Buffer.add_string b "\\r"
    | '\t' -> Buffer.add_string b "\\t" | '\b' -> Buffer.add_string b "\\b" | '\012' -> Buffer.add_string b "\\f"
    | '\007' -> Buffer.add_string b "\\a" | '\011' -> Buffer.add_string b "\\v" | '\\' -> Buffer.add_string b "\\\\"
    | '"' -> Buffer.add_string b "\\\"" | c -> Buffer.add_char b c) s;
  Buffer.add_char b '"';
  Buffer.contents b

let rec expr (e : expr) =
  match e with
  | Name s -> s
  | Const { kind = Int i; _ } -> Int64.to_string i
  | Const { kind = Float f; _ } -> Printf.sprintf "%g" f
  | Const { kind = String s; _ } -> str s
  | Const _ -> ""
  | Bin (op, a, b) -> "(" ^ expr a ^ binop op ^ expr b ^ ")"
  | Cand (a, b) -> "(" ^ expr a ^ "&&" ^ expr b ^ ")"
  | Cor (a, b) -> "(" ^ expr a ^ "||" ^ expr b ^ ")"
  | Assign (a, b) -> expr a ^ " = " ^ expr b
  | Indm a -> "*" ^ expr a
  | Indc a -> "@" ^ expr a
  | Predec a -> "--" ^ expr a
  | Preinc a -> "++" ^ expr a
  | Postinc a -> expr a ^ "++"
  | Postdec a -> expr a ^ "--"
  | Not a -> "!" ^ expr a
  | Plus a -> expr a
  | Call (f, args, _) -> f ^ "(" ^ String.concat "," (List.map expr args) ^ ")"
  | Construct es -> "{" ^ String.concat "," (List.map expr es) ^ "}"
  | Head a -> "head " ^ expr a
  | Tail a -> "tail " ^ expr a
  | Append (a, b) -> "append " ^ expr a ^ "," ^ expr b
  | Delete (a, b) -> "delete " ^ expr a ^ "," ^ expr b
  | Index (a, b) -> expr a ^ "[" ^ expr b ^ "]"
  | Dot (a, m) -> expr a ^ "." ^ m
  | Frame (f, v) -> f ^ ":" ^ v
  | Cast (t, a) -> "(" ^ t ^ ")" ^ expr a
  | Fmt (a, c) -> expr a ^ "\\" ^ String.make 1 c
  | Eval a -> "eval " ^ expr a
  | What None -> "whatis"
  | What (Some s) -> "whatis " ^ s

let tabs d = String.make d '\t'

(* a body (slist): braces when it is more than one statement *)
let rec body d (s : stmt) =
  match s with
  | Block [ s ] -> body d s
  | Block ss -> tabs (d - 1) ^ "{\n" ^ stmts d ss ^ tabs (d - 1) ^ "}\n"
  | s -> stmt d s

and stmt d (s : stmt) =
  match s with
  | Expr None -> ""
  | Expr (Some e) -> tabs d ^ expr e ^ ";\n"
  | Block ss -> stmts d ss
  | Local ns -> tabs d ^ "local " ^ String.concat ", " ns ^ ";\n"
  | Complex (t, v) -> Printf.sprintf "%scomplex %s %s;\n" (tabs d) t (expr v)
  | If (c, a, None) -> tabs d ^ "if " ^ expr c ^ " then\n" ^ body (d + 1) a
  | If (c, a, Some b) -> tabs d ^ "if " ^ expr c ^ " then\n" ^ body (d + 1) a ^ tabs d ^ "else\n" ^ body (d + 1) b
  | While (c, b) -> tabs d ^ "while " ^ expr c ^ " do\n" ^ body (d + 1) b
  | Return e -> tabs d ^ "return " ^ expr e ^ ";\n"
  | Loop (a, b, s) -> tabs d ^ "loop " ^ expr a ^ ", " ^ expr b ^ " do\n" ^ body (d + 1) s

and stmts d ss = String.concat "" (List.map (stmt d) ss)
