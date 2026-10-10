(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Bits.mli *)

exception Error of string

let error fmt = Printf.ksprintf (fun m -> raise (Error m)) fmt

type kind = Unsigned | Signed | Bool

type field =
  | Fixed of string          (* its digits, 0 1 x *)
  | Named of string * int * kind
  | Skip of int

let width = function Fixed d -> String.length d | Named (_, n, _) | Skip n -> n

let is_digits s = s <> "" && String.for_all (fun c -> c = '0' || c = '1' || c = 'x') s
let is_number s = s <> "" && String.for_all (fun c -> c >= '0' && c <= '9') s
let is_name s = s <> "" && String.for_all (fun c -> c = '_' || c = '\'' || c = '.' || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')) s

let field tok =
  if is_digits tok then Fixed tok
  else
    match String.index_opt tok ':' with
    | None -> error "%s: not a field (name:n, name:sn, name:b, 0110, _:n)" tok
    | Some i ->
        let name = String.sub tok 0 i and spec = String.sub tok (i + 1) (String.length tok - i - 1) in
        let n s = if is_number s && int_of_string s > 0 then int_of_string s else error "%s: a width expected" tok in
        if name = "_" then Skip (n spec)
        else if not (is_name name) then error "%s: not a name" tok
        else if spec = "b" then Named (name, 1, Bool)
        else if spec <> "" && spec.[0] = 's' then Named (name, n (String.sub spec 1 (String.length spec - 1)), Signed)
        else Named (name, n spec, Unsigned)

(* the fields, each with its lowest bit *)
let parse payload =
  let toks = String.split_on_char ' ' (String.map (fun c -> if c = '\n' || c = '\t' then ' ' else c) payload) in
  let fields = List.map field (List.filter (( <> ) "") toks) in
  let total = List.fold_left (fun n f -> n + width f) 0 fields in
  if total <> 32 then error "the fields make %d bits, not 32" total;
  let names = List.filter_map (function Named (x, _, _) -> Some x | _ -> None) fields in
  List.iter (fun x -> if List.length (List.filter (( = ) x) names) > 1 then error "%s: twice" x) names;
  let _, placed = List.fold_left (fun (hi, acc) f -> let lo = hi - width f in (lo, (f, lo) :: acc)) (32, []) fields in
  List.rev placed

let ones n = (1 lsl n) - 1

(* w's n bits from lo; the top field needs no mask: w has 32 bits *)
let bits w lo n =
  let shifted = if lo = 0 then w else Printf.sprintf "(%s lsr %d)" w lo in
  if lo + n = 32 then shifted else Printf.sprintf "(%s land 0x%x)" shifted (ones n)

(* a run of fixed bits, cut in pieces of 30 at most, from the low end *)
let rec chunks digits lo =
  let n = String.length digits in
  if n <= 30 then [ (digits, lo) ]
  else chunks (String.sub digits 0 (n - 30)) (lo + 30) @ [ (String.sub digits (n - 30) 30, lo) ]

let test w (digits, lo) =
  let n = String.length digits in
  let mask = ref 0 and value = ref 0 in
  String.iteri (fun i c ->
    let b = n - 1 - i in
    if c <> 'x' then mask := !mask lor (1 lsl b);
    if c = '1' then value := !value lor (1 lsl b)) digits;
  if !mask = 0 then None
  else if !mask = ones n then Some (Printf.sprintf "%s = 0x%x" (bits w lo n) !value)
  else Some (Printf.sprintf "%s land 0x%x = 0x%x" (bits w lo n) !mask !value)

let pattern payload w =
  let fields = parse payload in
  let tests =
    List.concat_map (fun (f, lo) -> match f with Fixed d -> List.filter_map (test w) (chunks d lo) | _ -> []) fields
  in
  let binds =
    List.filter_map (fun (f, lo) ->
      match f with
      | Named (x, n, Unsigned) -> Some (x, bits w lo n)
      | Named (x, _, Bool) -> Some (x, Printf.sprintf "%s = 1" (bits w lo 1))
      | Named (x, n, Signed) -> let s = 1 lsl (n - 1) in Some (x, Printf.sprintf "((%s lxor 0x%x) - 0x%x)" (bits w lo n) s s)
      | Fixed _ | Skip _ -> None) fields
  in
  (String.concat " && " tests, binds)

let expr payload =
  let shift e lo = if lo = 0 then e else Printf.sprintf "(%s lsl %d)" e lo in
  let parts =
    List.concat_map (fun (f, lo) ->
      match f with
      | Fixed d when String.contains d 'x' -> error "%s: an x in an expression" d
      | Fixed d ->
          List.filter_map (fun (d, lo) -> let v = int_of_string ("0b" ^ d) in if v = 0 then None else Some (shift (Printf.sprintf "0x%x" v) lo))
            (chunks d lo)
      | Skip _ -> error "_: in an expression"
      | Named (x, _, Bool) -> [ shift (Printf.sprintf "(if %s then 1 else 0)" x) lo ]
      | Named (x, n, (Unsigned | Signed)) -> [ shift (Printf.sprintf "(%s land 0x%x)" x (ones n)) lo ]) (parse payload)
  in
  match parts with [] -> "0" | _ -> "(" ^ String.concat " lor " parts ^ ")"
