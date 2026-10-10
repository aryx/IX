(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Fpath.mli: inspired by Daniel Bünzli's fpath, whose interface and
 * behaviour this follows; bundled here just for mini-ml (dune's builds
 * take the real library). *)

type t = string

let v s =
  if s = "" then invalid_arg "Fpath.v: an empty path";
  let b = Buffer.create (String.length s) in
  String.iteri (fun i c -> if not (c = '/' && i > 0 && s.[i - 1] = '/') then Buffer.add_char b c) s;
  Buffer.contents b

let to_string p = p
let pp ppf p = Format.pp_print_string ppf p

let is_dir p = p.[String.length p - 1] = '/'
let add_seg p seg =
  if String.contains seg '/' then invalid_arg ("Fpath.add_seg: " ^ seg);
  if is_dir p then p ^ seg else p ^ "/" ^ seg
let append p q = if q.[0] = '/' then q else if is_dir p then p ^ q else p ^ "/" ^ q
let ( / ) = add_seg
let ( // ) = append

(* where the last segment that is not empty starts, and ends *)
let last p =
  let stop = if is_dir p && String.length p > 1 then String.length p - 1 else String.length p in
  let start = match String.rindex_from_opt p (stop - 1) '/' with Some i when stop > 1 -> i + 1 | _ -> 0 in
  start, stop

let base p = let start, _ = last p in if p = "/" then "./" else if start = 0 then p else String.sub p start (String.length p - start)

let parent p =
  let start, stop = last p in
  match String.sub p start (stop - start) with
  | "/" -> p
  | "." | ".." -> (if is_dir p then p else p ^ "/") ^ "../"
  | _ -> if start = 0 then "./" else String.sub p 0 start

(* where the last segment's extension starts, or its end; /, . and ..
 * have no extension, and take none *)
let named p = let start, stop = last p in not (List.mem (String.sub p start (stop - start)) [ "/"; "."; ".." ])
let ext_start p =
  let start, stop = last p in
  match String.rindex_from_opt p (stop - 1) '.' with Some i when i > start && named p -> i | _ -> stop

let dotted e = if e <> "" && e.[0] <> '.' then "." ^ e else e
let has_ext e p = let _, stop = last p in let i = ext_start p in String.sub p i (stop - i) = dotted e && e <> ""
let set_ext e p =
  let _, stop = last p in
  if named p then String.sub p 0 (ext_start p) ^ dotted e ^ String.sub p stop (String.length p - stop) else p
let rem_ext p = set_ext "" p
