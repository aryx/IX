(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Dwarf_line.mli *)

type row = { addr : int; file : string; line : int; stmt : bool; last : bool }
type t = row array

(* a cursor in a section's bytes *)
type cur = { s : string; mutable o : int }

let u8 c = let v = Char.code c.s.[c.o] in c.o <- c.o + 1; v
let un c n = let v = ref 0 in for k = 0 to n - 1 do v := !v lor (u8 c lsl (8 * k)) done; !v
let uleb c =
  let rec go v sh = let b = u8 c in let v = v lor ((b land 0x7f) lsl sh) in if b land 0x80 <> 0 then go v (sh + 7) else v in
  go 0 0
let sleb c =
  let rec go v sh =
    let b = u8 c in
    let v = v lor ((b land 0x7f) lsl sh) in
    if b land 0x80 <> 0 then go v (sh + 7)
    else if b land 0x40 <> 0 && sh + 7 < 63 then v lor (-1 lsl (sh + 7)) else v in
  go 0 0
let cstr c = match String.index_from_opt c.s c.o '\000' with
  | Some e -> let v = String.sub c.s c.o (e - c.o) in c.o <- e + 1; v
  | None -> c.o <- String.length c.s; ""
let strat s o = if o < String.length s then (match String.index_from_opt s o '\000' with Some e -> String.sub s o (e - o) | None -> "") else ""

(* a value of a form (DW_FORM_...), as a string or a number *)
type v = S of string | N of int

let form c ~line_str ~str f =
  match f with
  | 0x08 -> S (cstr c)                         (* string *)
  | 0x1f -> S (strat line_str (un c 4))        (* line_strp *)
  | 0x0e -> S (strat str (un c 4))             (* strp *)
  | 0x0f -> N (uleb c)                         (* udata *)
  | 0x0b -> N (un c 1) | 0x05 -> N (un c 2) | 0x06 -> N (un c 4) | 0x07 -> N (un c 8)
  | 0x1e -> c.o <- c.o + 16; N 0               (* data16: an MD5 *)
  | 0x09 -> let n = uleb c in c.o <- c.o + n; N 0  (* block *)
  | f -> failwith (Printf.sprintf "DWARF: form 0x%x" f)

(* v5's directories or files: a table of entries, each its fields by
 * the formats said first (path 1, its directory's index 2) *)
let entries c ~line_str ~str =
  let nf = u8 c in
  let fmts = List.init nf (fun _ -> let k = uleb c in let f = uleb c in k, f) in
  let n = uleb c in
  List.init n (fun _ ->
    List.fold_left (fun (path, dir) (k, f) ->
      match k, form c ~line_str ~str f with
      | 1, S p -> p, dir
      | 2, N d -> path, d
      | _ -> path, dir) ("", 0) fmts)

let join d f = if f <> "" && f.[0] = '/' then f else if d = "" then f else d ^ "/" ^ f

(* one unit's program run, its rows added to acc *)
let unit_ c ~line_str ~str acc =
  let len = un c 4 in
  let next = c.o + len in
  let version = un c 2 in
  if version >= 5 then c.o <- c.o + 2;    (* address size, segment selector size *)
  let hlen = un c 4 in
  let program = c.o + hlen in
  let min_inst = u8 c in
  if version >= 4 then ignore (u8 c);
  let default_stmt = u8 c <> 0 in
  let line_base = let b = u8 c in if b >= 128 then b - 256 else b in
  let line_range = u8 c in
  let opcode_base = u8 c in
  let lengths = Array.init (max 0 (opcode_base - 1)) (fun _ -> u8 c) in
  let files =
    if version >= 5 then begin
      let dirs = Array.of_list (List.map fst (entries c ~line_str ~str)) in
      let fs = entries c ~line_str ~str in
      Array.of_list (List.map (fun (p, d) -> join (if d < Array.length dirs then dirs.(d) else "") p) fs)
    end else begin
      (* v2 to 4: the directories, then the files, each list to an empty
       * name; a file's number counted from 1, its directory's too (0:
       * the compilation's) *)
      let rec dirs acc = match cstr c with "" -> List.rev acc | d -> dirs (d :: acc) in
      let dirs = Array.of_list ("" :: dirs []) in
      let rec files acc = match cstr c with
        | "" -> List.rev acc
        | f -> let d = uleb c in ignore (uleb c); ignore (uleb c);
               files (join (if d < Array.length dirs then dirs.(d) else "") f :: acc) in
      Array.of_list ("" :: files [])
    end in
  c.o <- program;
  let rows = ref acc in
  let addr = ref 0 and file = ref 1 and line = ref 1 and stmt = ref default_stmt in
  let reset () = addr := 0; file := 1; line := 1; stmt := default_stmt in
  let emit last =
    let f = if !file >= 0 && !file < Array.length files then files.(!file) else "?" in
    rows := { addr = !addr; file = f; line = !line; stmt = !stmt; last } :: !rows in
  while c.o < next do
    let op = u8 c in
    if op >= opcode_base then begin
      let adj = op - opcode_base in
      addr := !addr + (adj / line_range * min_inst);
      line := !line + line_base + (adj mod line_range);
      emit false
    end else
      match op with
      | 0 ->
          let n = uleb c in
          let e = c.o + n in
          (match u8 c with
           | 1 -> emit true; reset ()
           | 2 -> addr := un c (n - 1)
           | _ -> ());
          c.o <- e
      | 1 -> emit false
      | 2 -> addr := !addr + (uleb c * min_inst)
      | 3 -> line := !line + sleb c
      | 4 -> file := uleb c
      | 5 -> ignore (uleb c)
      | 6 -> stmt := not !stmt
      | 8 -> addr := !addr + ((255 - opcode_base) / line_range * min_inst)
      | 9 -> addr := !addr + un c 2
      | 7 | 10 | 11 -> ()
      | op -> for _k = 1 to lengths.(op - 1) do ignore (uleb c) done
  done;
  c.o <- next;
  !rows

let read file (e : Elf_file.t) =
  match Elf_file.section e ".debug_line" with
  | None -> None
  | Some sec ->
      let bytes name = match Elf_file.section e name with Some s -> Elf_file.bytes file s | None -> "" in
      let line_str = bytes ".debug_line_str" and str = bytes ".debug_str" in
      let c = { s = Elf_file.bytes file sec; o = 0 } in
      let rows = ref [] in
      (try while c.o + 4 <= String.length c.s do rows := unit_ c ~line_str ~str !rows done
       with Failure _ | Invalid_argument _ -> ());
      (* (in the order made: a sequence's end before the next's start
       * at the same address) *)
      let a = Array.of_list (List.rev !rows) in
      Array.stable_sort (fun x y -> compare x.addr y.addr) a;
      if a = [||] then None else Some a

(* the last row at or before an address, not a sequence's end *)
let file_line (t : t) a =
  let lo = ref (-1) and hi = ref (Array.length t) in
  while !hi - !lo > 1 do
    let mid = (!lo + !hi) / 2 in
    if t.(mid).addr <= a then lo := mid else hi := mid
  done;
  let i = !lo in
  if i < 0 || t.(i).last then None else Some (t.(i).file, t.(i).line)

(* a path's last components the file's (Down.ml, arch/x.c) *)
let ends_with p f = p = f || (String.length p > String.length f && String.sub p (String.length p - String.length f - 1) (String.length f + 1) = "/" ^ f)

let file_pc (t : t) f l =
  Array.fold_left (fun best r ->
    if r.line = l && r.stmt && not r.last && ends_with r.file f then
      (match best with Some b when b <= r.addr -> best | _ -> Some r.addr)
    else best) None t
