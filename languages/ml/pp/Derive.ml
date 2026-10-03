(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* See Derive.mli *)

exception Error of string

let spf = Printf.sprintf

let fname name = if name = "t" then "show" else "show_" ^ name
let pname name = if name = "t" then "pp" else "pp_" ^ name

(* the type's name as written, its parameters applied *)
let applied (d : Ast.type_decl) =
  match d.tparams with
  | [] -> d.tname
  | [ a ] -> spf "'%s %s" a d.tname
  | ps -> spf "(%s) %s" (String.concat ", " (List.map (fun a -> "'" ^ a) ps)) d.tname

(* The code is ppx_deriving's, a call of Format for each of its
 * fprintf's directives: a string, a box opened ("@[<2>") or closed
 * ("@]"), a space or nothing where a line may break ("@ ", "@,"). *)
let str s = spf "Format.pp_print_string fmt %S" s
let box n = spf "Format.pp_open_box fmt %d" n
let close = "Format.pp_close_box fmt ()"
let space = "Format.pp_print_space fmt ()"
let cut = "Format.pp_print_cut fmt ()"
let seq l = "(" ^ String.concat "; " l ^ ")"
(* [a; sep; b; sep; c] *)
let rec between sep = function [] -> [] | [ x ] -> [ x ] | x :: r -> x :: sep @ between sep r

(* the code printing x, of type t, on fmt *)
let rec print (t : Ast.ty) x =
  let text f = spf "Format.pp_print_string fmt (%s)" (f x) in
  match t with
  | Tvar a -> spf "poly_%s fmt %s" a x
  | Tarrow _ -> str "<fun>"
  | Tlabel (_, t) -> print t x
  | Trecord _ -> raise (Error "show: a record here, not a constructor's argument")
  | Ttuple ts ->
      let xs = List.mapi (fun i _ -> spf "x%d" (i + 1)) ts in
      spf "(let (%s) = %s in %s)" (String.concat ", " xs) x
        (seq ([ str "("; box 0 ] @ between [ str ","; space ] (List.map2 print ts xs) @ [ close; str ")" ]))
  | Tconstr ([ "int" ], []) -> text (spf "string_of_int %s")
  | Tconstr ([ "bool" ], []) -> text (spf "string_of_bool %s")
  | Tconstr ([ "float" ], []) -> text (spf "string_of_float %s")
  (* not %S nor %C: ocaml-light's printf has neither *)
  | Tconstr ([ "string" ], []) -> text (spf "\"\\\"\" ^ String.escaped %s ^ \"\\\"\"")
  | Tconstr ([ "char" ], []) -> text (spf "\"'\" ^ Char.escaped %s ^ \"'\"")
  | Tconstr ([ "unit" ], []) -> str "()"
  | Tconstr ([ ("list" | "array" as k) ], [ t ]) ->
      let o, c, fold = if k = "list" then "[", "]", "List.fold_left" else "[|", "|]", "Array.fold_left" in
      seq [ box 2; str o;
            spf "ignore (%s (fun sep x -> if sep then %s; %s; true) false %s)" fold (seq [ str ";"; space ]) (print t "x") x;
            cut; str c; close ]
  | Tconstr ([ "option" ], [ t ]) ->
      spf "(match %s with None -> %s | Some x -> %s)" x (str "None") (seq [ str "(Some "; print t "x"; str ")" ])
  | Tconstr ([ "ref" ], [ t ]) -> seq [ str "ref ("; print t (spf "!(%s)" x); str ")" ]
  | Tconstr (path, args) ->
      let rec last = function [ y ] -> [ pname y ] | m :: l -> m :: last l | [] -> [] in
      spf "%s%s fmt %s" (String.concat "." (last path))
        (String.concat "" (List.map (fun a -> spf " (fun fmt x -> %s)" (print a "x")) args)) x

(* the fields of a record: "l = v; ...", each in a box *)
let fields m get ls =
  between [ str ";"; space ]
    (List.mapi (fun i (l, _, t) ->
       seq [ box 0; str ((if i = 0 then m else "") ^ l ^ " ="); space; print t (get l); close ]) ls)

(* M.C; (M.C x); (M.C (x, y)); M.C {l = x; ...} *)
let case m (c, ts) =
  match ts with
  | [ Ast.Trecord ls ] ->
      spf "  | %s r -> %s" c (seq ([ box 2; str (m ^ c ^ " {"); cut ] @ fields "" (fun l -> "r." ^ l) ls @ [ close; str "}" ]))
  | [] -> spf "  | %s -> %s" c (str (m ^ c))
  | [ t ] -> spf "  | %s x1 -> %s" c (seq [ str "("; box 2; str (m ^ c); space; print t "x1"; close; str ")" ])
  | ts ->
      let xs = List.mapi (fun i _ -> spf "x%d" (i + 1)) ts in
      spf "  | %s (%s) -> %s" c (String.concat ", " xs)
        (seq ([ str "("; box 2; str (m ^ c ^ " ("); cut ] @ between [ str ","; space ] (List.map2 print ts xs)
              @ [ cut; str "))"; close ]))

let body m (d : Ast.type_decl) =
  match d.tkind, d.tmanifest with
  | Variant cs, _ -> "function\n" ^ String.concat "\n" (List.map (case m) cs)
  | Record ls, _ ->
      spf "fun (r : %s) ->\n  %s" (applied d)
        (seq ([ box 2; str "{ " ] @ fields m (fun l -> "r." ^ l) ls @ [ space; str "}"; close ]))
  | Abstract, Some t -> spf "fun x -> %s" (print t "x")
  | Abstract, None -> raise (Error (spf "show: %s is abstract" d.tname))
  | Hole, _ -> raise (Error (spf "show: %s = _ without its .mli's" d.tname))

(* whether the group's types name one of them: a let rec only then (an
 * unused rec is an error in dune's default profile) *)
let recursive (ds : Ast.type_decl list) =
  let names = List.map (fun (d : Ast.type_decl) -> d.tname) ds in
  let rec named (t : Ast.ty) =
    match t with
    | Tvar _ -> false
    | Tarrow (a, b) -> named a || named b
    | Tlabel (_, t) -> named t
    | Trecord ls -> List.exists (fun (_, _, t) -> named t) ls
    | Ttuple ts -> List.exists named ts
    | Tconstr (path, args) -> (match path with [ x ] -> List.mem x names | _ -> false) || List.exists named args
  in
  List.exists (fun (d : Ast.type_decl) ->
    (match d.tmanifest with Some t -> named t | None -> false)
    || match d.tkind with
       | Variant cs -> List.exists (fun (_, ts) -> List.exists named ts) cs
       | Record ls -> List.exists (fun (_, _, t) -> named t) ls
       | Abstract | Hole -> false) ds

(* pp_t on a formatter, then show_t: pp_t into a buffer *)
let show m ds =
  let m = m ^ "." in
  let params (d : Ast.type_decl) = String.concat "" (List.map (fun a -> " poly_" ^ a) d.tparams) in
  let pp i (d : Ast.type_decl) =
    spf "%s %s%s fmt = %s" (if i = 0 then (if recursive ds then "let rec" else "let") else "and") (pname d.tname)
      (params d) (body m d)
  in
  let show (d : Ast.type_decl) =
    spf "let %s%s x =\n  let b = Buffer.create 64 in\n  let fmt = Format.formatter_of_buffer b in\n  %s%s fmt x; Format.pp_print_flush fmt (); Buffer.contents b"
      (fname d.tname) (params d) (pname d.tname) (params d)
  in
  String.concat "\n" (List.mapi pp ds @ List.map show ds) ^ "\n"

let show_sig ds =
  let one (d : Ast.type_decl) =
    let ps f = String.concat "" (List.map (fun a -> spf "(Format.formatter -> '%s -> unit) -> " a) d.tparams) ^ f in
    spf "val %s : %s\nval %s : %s" (pname d.tname) (ps (spf "Format.formatter -> %s -> unit" (applied d)))
      (fname d.tname) (ps (spf "%s -> string" (applied d)))
  in
  String.concat "\n" (List.map one ds) ^ "\n"
