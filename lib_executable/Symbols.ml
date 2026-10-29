(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Symbols.mli *)

type sym = { value : int; typ : char; name : string }

type t = { syms : sym list; text_start : int; text_end : int; lines : string }

(* 4 bytes, the high first *)
let be32 (s : string) o =
  (Char.code s.[o] lsl 24) lor (Char.code s.[o + 1] lsl 16) lor (Char.code s.[o + 2] lsl 8) lor Char.code s.[o + 3]

(* an a.out for arm (Exe's header): its text at 0x1000 and the
 * header's 32 bytes, the symbols after the data, the lines after them *)
let read (s : string) =
  if String.length s < 32 || be32 s 0 <> 0x647 || be32 s 16 = 0 then None
  else begin
    let text = be32 s 4 and data = be32 s 8 and nsyms = be32 s 16 and nlines = be32 s 28 in
    let start = 32 + text + data in
    let stop = start + nsyms in
    let rec entries o acc =
      if o + 5 > stop then List.rev acc
      else begin
        let value = be32 s o and typ = Char.chr (Char.code s.[o + 4] land 0x7f) in
        let o = o + 5 in
        if typ = 'z' || typ = 'Z' then begin
          (* a NUL, then the files' numbers 2 bytes each, to two NULs *)
          let rec pairs p = if s.[p] = '\000' && s.[p + 1] = '\000' then p else pairs (p + 2) in
          let e = pairs (o + 1) in
          entries (e + 2) ({ value; typ; name = String.sub s (o + 1) (e - o - 1) } :: acc)
        end
        else
          let e = String.index_from s o '\000' in
          entries (e + 1) ({ value; typ; name = String.sub s o (e - o) } :: acc)
      end
    in
    Some { syms = entries start []; text_start = 0x1020; text_end = 0x1020 + text; lines = String.sub s stop nlines }
  end

(* the files' components, by their numbers *)
let files t =
  let h = Hashtbl.create 64 in
  List.iter (fun s -> if s.typ = 'f' then Hashtbl.replace h s.value s.name) t.syms;
  h

let path_in files (z : sym) =
  let b = Buffer.create 64 in
  let rec go i =
    if i + 1 < String.length z.name then begin
      let k = (Char.code z.name.[i] lsl 8) lor Char.code z.name.[i + 1] in
      (match Hashtbl.find_opt files k with
       | Some c ->
           let n = Buffer.length b in
           if n > 0 && Buffer.nth b (n - 1) <> '/' then Buffer.add_char b '/';
           Buffer.add_string b c
       | None -> ());
      go (i + 2)
    end in
  go 0;
  let p = Buffer.contents b in
  if String.length p > 1 then FS.cleanname p else p

let path t z = path_in (files t) z

let is_text s = match s.typ with 'T' | 't' | 'L' | 'l' -> true | _ -> false

let func t addr =
  if addr < t.text_start || addr >= t.text_end then None
  else
    List.fold_left (fun best s -> if is_text s && s.value <= addr then (match best with Some (b : sym) when b.value > s.value -> best | _ -> Some s) else best) None t.syms
    |> Option.map (fun (s : sym) -> s.name, addr - s.value)

(* libmach's pc2line: the global line of [pc]; the table's pc one
 * instruction behind, as the linker started it at the text's start *)
let pc2line t pc =
  let n = String.length t.lines in
  let rec go i pc' line =
    if pc' >= pc then Some line
    else if i >= n then None
    else
      let u = Char.code t.lines.[i] in
      if u = 0 then begin
        (* (signed: from its bytes, as an int has 31 bits where mini-ml
         * builds for arm) *)
        let byte k = Char.code t.lines.[i + 1 + k] in
        let d = if byte 0 < 128 then be32 t.lines (i + 1)
          else - (((255 - byte 0) lsl 24) lor ((255 - byte 1) lsl 16) lor ((255 - byte 2) lsl 8) lor (255 - byte 3)) - 1 in
        go (i + 5) (pc' + 4) (line + d)
      end
      else if u < 65 then go (i + 1) (pc' + 4) (line + u)
      else if u < 129 then go (i + 1) (pc' + 4) (line - (u - 64))
      else go (i + 1) (pc' + (4 * (u - 129)) + 4) line in
  if pc < t.text_start - 4 || pc > t.text_end then None else go 0 (t.text_start - 4) 0

(* each object's history, at the address of the function after it *)
let histories t =
  let rec go acc cur = function
    | [] -> List.rev acc
    | s :: rest when s.typ = 'z' -> go acc (s :: cur) rest
    | s :: rest when is_text s && cur <> [] -> go ((s.value, List.rev cur) :: acc) [] rest
    | _ :: rest -> go acc cur rest in
  go [] [] t.syms

(* the file and its line for a global line: the files open there, a
 * stack, each with the global line its own count is from; an included
 * file's lines added to its includer's at its end (libmach's fline) *)
let local files hist line =
  let rec go stack = function
    | (z : sym) :: rest when z.value <= line ->
        if z.name <> "" then go ((path_in files z, z.value - 1, z.value) :: stack) rest
        else (match stack with
          | (_, _, pushed) :: (p, base, at) :: up -> go ((p, base + (z.value - pushed), at) :: up) rest
          | _ -> [])
    | _ -> stack in
  match go [] hist with (p, base, _) :: _ -> Some (p, line - base) | [] -> None

let file_line t addr =
  match pc2line t addr with
  | None | Some 0 -> None
  | Some line ->
      let hs = List.filter (fun (a, _) -> a <= addr) (histories t) in
      match List.rev hs with
      | (_, hist) :: _ -> local (files t) hist line
      | [] -> None
