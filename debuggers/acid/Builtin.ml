(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Builtin.mli *)

open Ast

type caps = < Cap.open_in >

let error fmt = Printf.ksprintf (fun s -> raise (Eval.Error s)) fmt

let one name = function [ v ] -> v | _ -> error "%s(value)" name

let str name v = match (one name v).kind with String s -> s | _ -> error "%s(string)" name

(* strtoull's base 0 on a prefix of digits (atoi "12x" is 12) *)
let atoi s =
  let s = String.trim s in
  let n = String.length s in
  let neg = n > 0 && s.[0] = '-' in
  let s = if neg || (n > 0 && s.[0] = '+') then String.sub s 1 (n - 1) else s in
  let base, s =
    if String.length s > 2 && (String.sub s 0 2 = "0x" || String.sub s 0 2 = "0X") then 16, String.sub s 2 (String.length s - 2)
    else if String.length s > 1 && s.[0] = '0' then 8, String.sub s 1 (String.length s - 1)
    else 10, s in
  let digit c = match c with
    | '0' .. '9' -> Char.code c - 48 | 'a' .. 'f' -> Char.code c - 87 | 'A' .. 'F' -> Char.code c - 55 | _ -> 99 in
  let rec go i acc = if i < String.length s && digit s.[i] < base then go (i + 1) (Int64.add (Int64.mul acc (Int64.of_int base)) (Int64.of_int (digit s.[i]))) else acc in
  let v = go 0 0L in
  if neg then Int64.neg v else v

(* itoa's format (acidfmt): one of Plan 9's for an integer, %d by
 * default: its flags and width, then u, l, h, # (%ux: unsigned
 * hexadecimal), then the verb; x with 0x as principia's (acid's xfmt) *)
let itoa i f =
  match f with
  | None -> Int64.to_string i
  | Some f ->
      (match String.index_opt f '%' with
       | None -> f
       | Some k ->
           let j = ref (k + 1) in
           while !j < String.length f && (f.[!j] = '0' || f.[!j] = '-' || (f.[!j] >= '1' && f.[!j] <= '9')) do incr j done;
           let flags = String.sub f (k + 1) (!j - k - 1) in
           while !j < String.length f && String.contains "ulh#" f.[!j] do incr j done;
           if !j >= String.length f then error "itoa: bad format";
           let width = try int_of_string (if flags <> "" && flags.[0] = '-' then String.sub flags 1 (String.length flags - 1) else flags) with Failure _ -> 0 in
           let digits = match f.[!j] with
             | 'x' -> Printf.sprintf "0x%Lx" (Int64.logand i 0xffffffffL) | 'X' -> Printf.sprintf "%LX" i | 'o' -> Printf.sprintf "%Lo" i
             | 'u' -> Printf.sprintf "%Lu" i | 'c' -> String.make 1 (Char.chr (Int64.to_int i land 255))
             | _ -> Int64.to_string i in
           let pad = String.make (max 0 (width - String.length digits)) (if flags <> "" && flags.[0] = '0' then '0' else ' ') in
           let body = if flags <> "" && flags.[0] = '-' then digits ^ pad else pad ^ digits in
           String.sub f 0 k ^ body ^ String.sub f (!j + 1) (String.length f - !j - 1))

let init (caps : < caps; .. >) =
  let def name f = Hashtbl.replace Eval.builtins name f in
  def "print" (fun vs -> Eval.print vs; Value.empty);
  def "fmt" (function
    | [ v; { kind = Int c; _ } ] when String.contains Value.formats (Char.chr (Int64.to_int c land 255)) ->
        { v with fmt = Char.chr (Int64.to_int c) }
    | [ _; _ ] -> error "bad format"
    | _ -> error "fmt(obj, fmt)");
  def "fmtof" (fun vs -> Value.int 'D' (Int64.of_int (Char.code (one "fmtof" vs).fmt)));
  def "fmtsize" (fun vs -> Value.int 'D' (Int64.of_int (Value.size (one "fmtsize" vs).fmt)));
  def "atoi" (fun vs -> Value.int 'V' (atoi (str "atoi" vs)));
  def "atof" (fun vs -> { kind = Float (try float_of_string (String.trim (str "atof" vs)) with Failure _ -> 0.); fmt = 'f'; comt = None });
  def "itoa" (function
    | [ { kind = Int i; _ } ] -> Value.string (itoa i None)
    | [ { kind = Int i; _ }; { kind = String f; _ } ] -> Value.string (itoa i (Some f))
    | _ -> error "itoa(integer [, fmt])");
  def "error" (fun vs -> raise (Eval.Error (str "error" vs)));
  (* an item's index in a list, -1 when not there (integers, floats and
   * strings compared; a list never matches) *)
  def "match" (function
    | [ item; { kind = List l; _ } ] ->
        let same (a : value) (b : value) = match a.kind, b.kind with
          | Int x, Int y -> x = y | Float x, Float y -> x = y | String x, String y -> x = y | _ -> false in
        let rec find i = function [] -> -1L | v :: rest -> if same item v then i else find (Int64.add i 1L) rest in
        Value.int 'D' (find 0L (Value.elements l))
    | [ _; _ ] -> error "match(obj, list): need list"
    | _ -> error "match(obj, list): arg count");
  def "access" (fun vs -> Value.int 'X' (match FS.read_opt caps (Fpath.v (str "access" vs)) with Some _ -> 1L | None -> 0L));
  (* a file's lines, without their newlines; {} when it cannot be read
   * (port.acid's findsrc) *)
  def "file" (fun vs ->
    match FS.read_opt caps (Fpath.v (str "file" vs)) with
    | Some text ->
        let lines = String.split_on_char '\n' text in
        let lines = match List.rev lines with "" :: rest -> List.rev rest | _ -> lines in
        Value.list (List.map Value.string lines)
    | None -> Value.empty);
  def "readfile" (fun vs ->
    match FS.read_opt caps (Fpath.v (str "readfile" vs)) with
    | Some s when s <> "" -> Value.string s
    | _ -> Value.empty)
