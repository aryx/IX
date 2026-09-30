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

(* the type's name as written, its parameters applied *)
let applied (d : Ast.type_decl) =
  match d.tparams with
  | [] -> d.tname
  | [ a ] -> spf "'%s %s" a d.tname
  | ps -> spf "(%s) %s" (String.concat ", " (List.map (fun a -> "'" ^ a) ps)) d.tname

(* the printer of a type, an expression *)
let rec printer (t : Ast.ty) =
  match t with
  | Tvar a -> "poly_" ^ a
  | Tarrow _ -> "(fun _ -> \"<fun>\")"
  | Ttuple ts ->
      let xs = List.mapi (fun i _ -> spf "x%d" (i + 1)) ts in
      spf "(fun (%s) -> \"(\" ^ %s ^ \")\")" (String.concat ", " xs)
        (String.concat " ^ \", \" ^ " (List.map2 (fun x t -> spf "%s %s" (printer t) x) xs ts))
  | Tconstr ([ "int" ], []) -> "string_of_int"
  | Tconstr ([ "bool" ], []) -> "string_of_bool"
  | Tconstr ([ "float" ], []) -> "string_of_float"
  (* not %S nor %C: ocaml-light's printf has neither *)
  | Tconstr ([ "string" ], []) -> "(fun s -> \"\\\"\" ^ String.escaped s ^ \"\\\"\")"
  | Tconstr ([ "char" ], []) -> "(fun c -> \"'\" ^ Char.escaped c ^ \"'\")"
  | Tconstr ([ "unit" ], []) -> "(fun () -> \"()\")"
  | Tconstr ([ "list" ], [ t ]) -> spf "(fun l -> \"[\" ^ String.concat \" \" (List.map %s l) ^ \"]\")" (printer t)
  | Tconstr ([ "array" ], [ t ]) ->
      spf "(fun a -> \"[|\" ^ String.concat \" \" (Array.to_list (Array.map %s a)) ^ \"|]\")" (printer t)
  | Tconstr ([ "option" ], [ t ]) -> spf "(function None -> \"None\" | Some x -> \"(Some \" ^ %s x ^ \")\")" (printer t)
  | Tconstr ([ "ref" ], [ t ]) -> spf "(fun r -> \"(ref \" ^ %s !r ^ \")\")" (printer t)
  | Tconstr (path, args) ->
      let rec last = function [ x ] -> [ fname x ] | m :: l -> m :: last l | [] -> [] in
      let f = String.concat "." (last path) in
      if args = [] then f else spf "(%s %s)" f (String.concat " " (List.map printer args))

let args ts = List.mapi (fun i t -> spf "x%d" (i + 1), t) ts

let case (c, ts) =
  match args ts with
  | [] -> spf "  | %s -> %S" c c
  | [ (x, t) ] -> spf "  | %s %s -> \"(%s \" ^ %s %s ^ \")\"" c x c (printer t) x
  | xs ->
      spf "  | %s (%s) -> \"(%s \" ^ %s ^ \")\"" c (String.concat ", " (List.map fst xs)) c
        (String.concat " ^ \" \" ^ " (List.map (fun (x, t) -> spf "%s %s" (printer t) x) xs))

let body (d : Ast.type_decl) =
  match d.tkind, d.tmanifest with
  | Variant cs, _ -> "function\n" ^ String.concat "\n" (List.map case cs)
  | Record ls, _ ->
      spf "fun (r : %s) ->\n  \"{\" ^ %s ^ \"}\"" (applied d)
        (String.concat " ^ \" \" ^ " (List.map (fun (l, _, t) -> spf "\"(%s \" ^ %s r.%s ^ \")\"" l (printer t) l) ls))
  | Abstract, Some t -> spf "fun x -> %s x" (printer t)
  | Abstract, None -> raise (Error (spf "show: %s is abstract" d.tname))
  | Hole, _ -> raise (Error (spf "show: %s = _ without its .mli's" d.tname))

let show ds =
  let one i (d : Ast.type_decl) =
    spf "%s %s%s = %s" (if i = 0 then "let rec" else "and") (fname d.tname)
      (String.concat "" (List.map (fun a -> " poly_" ^ a) d.tparams)) (body d)
  in
  "\n" ^ String.concat "\n" (List.mapi one ds) ^ "\n"

let show_sig ds =
  let one (d : Ast.type_decl) =
    spf "val %s : %s%s -> string" (fname d.tname)
      (String.concat "" (List.map (fun a -> spf "('%s -> string) -> " a) d.tparams)) (applied d)
  in
  "\n" ^ String.concat "\n" (List.map one ds) ^ "\n"
