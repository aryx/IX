(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Value.mli *)

open Ast

type t = Ast.value

let int fmt i = { kind = Int i; fmt }
let string s = { kind = String s; fmt = 's' }
let empty = { kind = List None; fmt = 'X' }

let list vs =
  let rec go = function [] -> None | v :: rest -> Some { value = v; next = go rest } in
  { kind = List (go vs); fmt = 'X' }

let rec elements = function None -> [] | Some (c : cell) -> c.value :: elements c.next

let type_name (v : t) =
  match v.kind with Int _ -> "integer" | Float _ -> "float" | String _ -> "string" | List _ -> "list" | Code _ -> "code"

let formats = "aBbcCdDfFgGiIoOqQrRsSuUVWxXYZ38"

let size = function
  | 'A' | 'B' | 'D' | 'O' | 'Q' | 'R' | 'S' | 'U' | 'X' | 'a' | 's' -> 4
  | 'F' | 'G' | 'V' | 'W' | 'Y' | 'Z' -> 8
  | 'C' | 'b' | 'c' -> 1
  | 'd' | 'o' | 'q' | 'r' | 'u' | 'x' -> 2
  | 'f' | 'g' -> 4
  | '3' | '8' -> 10
  | _ -> 0

let truth (v : t) =
  match v.kind with
  | Int i -> i <> 0L
  | Float f -> f <> 0.0
  | String s -> s <> ""
  | List l -> l <> None
  | Code _ -> false

let rec equal (a : t) (b : t) =
  match a.kind, b.kind with
  | Int x, Int y -> x = y
  | Int x, Float y | Float y, Int x -> Int64.to_float x = y
  | Float x, Float y -> x = y
  | String x, String y -> x = y
  | List x, List y -> cells x y
  | _ -> false

and cells x y =
  match x, y with
  | None, None -> true
  | Some (c : cell), Some (d : cell) ->
      (match c.value.kind, d.value.kind with
       | Int _, Int _ | Float _, Float _ | String _, String _ | List _, List _ -> equal c.value d.value && cells c.next d.next
       | _ -> false)
  | _ -> false

(* the low bits of an integer, as C's casts of acid's patom take them *)
let low bits i = Int64.logand i (Int64.sub (Int64.shift_left 1L bits) 1L)
let signed32 i = Int64.of_int32 (Int64.to_int32 i)

(* the instruction at an address (Proc's, through Das): from the
 * process (core) or the program's file; None when it can't be read *)
let das : (bool -> int64 -> string option) ref = ref (fun _ _ -> None)

(* patom: an atom by its format *)
let atom ~symbol (v : t) =
  let i = match v.kind with Int i -> i | _ -> 0L in
  let wrong () = Printf.sprintf "*%c<%s>*" v.fmt (type_name v) in
  match v.fmt, v.kind with
  | 'c', _ -> String.make 1 (Char.chr (Int64.to_int (low 8 i)))
  | 'C', _ ->
      let c = Int64.to_int (low 8 i) in
      if c < 32 || c >= 127 then Printf.sprintf "%3d" c else "  " ^ String.make 1 (Char.chr c)
  | 'r', _ -> String.make 1 (Char.chr (Int64.to_int (low 8 i)))
  | 'B', _ -> "0b" ^ String.init 32 (fun k -> if Int64.logand i (Int64.shift_left 1L (31 - k)) <> 0L then '1' else '0')
  | 'b', _ -> Printf.sprintf "0x%02Lx" (low 8 i)
  | 'X', _ -> Printf.sprintf "0x%08Lx" (low 32 i)
  | 'x', _ -> Printf.sprintf "0x%04Lx" (low 16 i)
  | 'D', _ -> Int64.to_string (signed32 i)
  | 'd', _ | 'u', _ -> Int64.to_string (low 16 i)
  | 'U', _ -> Int64.to_string (low 32 i)
  | 'Z', _ -> Printf.sprintf "%Lu" i
  | 'V', _ -> Int64.to_string i
  | 'W', _ -> Printf.sprintf "0x%08Lx" i
  | 'Y', _ -> Printf.sprintf "0x%016Lx" i
  | 'o', _ | 'q', _ -> Printf.sprintf "0%011Lo" (low 16 i)
  | 'O', _ | 'Q', _ -> Printf.sprintf "0%06Lo" (low 32 i)
  | ('f' | 'F' | '3' | '8'), Float f -> Printf.sprintf "%g" f
  | ('f' | 'F' | '3' | '8'), _ -> wrong ()
  | ('s' | 'g' | 'G' | 'R'), String s -> s
  | ('s' | 'g' | 'G' | 'R'), _ -> wrong ()
  | ('a' | 'A'), _ -> symbol i
  | ('i' | 'I'), Int a ->
      (match !das false a with Some s -> s | None -> "no instruction")
  | ('i' | 'I'), _ -> wrong ()
  | _ -> ""

let rec show ~symbol (v : t) =
  match v.kind with
  | List l ->
      "{" ^ String.concat ", " (List.map (fun (e : t) ->
        match e.kind with String _ -> "\"" ^ atom ~symbol e ^ "\"" | _ -> show ~symbol e) (elements l)) ^ "}"
  | Code e -> Code.expr e ^ ";\n"
  | _ -> atom ~symbol v
