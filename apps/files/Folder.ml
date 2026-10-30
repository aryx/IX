(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Folder.mli *)

type entry = { name : string; is_dir : bool; size : int; mtime : float }
type order = By_name | By_size | By_day

let list (caps : < Cap.readdir ; .. >) (path : string) : entry list =
  List.filter_map
    (fun (d : Sys_plan9.dir) ->
      if d.name = "." || d.name = ".." then None
      else Some { name = d.name; is_dir = d.qid_type land Sys_plan9.dmdir <> 0; size = d.length; mtime = d.mtime })
    (Sys_plan9.dirread caps path)

let sort (order : order) ~(reversed : bool) (entries : entry list) : entry list =
  let by_name (a : entry) (b : entry) = compare a.name b.name in
  let by (a : entry) (b : entry) =
    let c =
      match order with
      | By_name -> by_name a b
      | By_size -> compare a.size b.size
      | By_day -> compare a.mtime b.mtime
    in
    if reversed then -c else c
  in
  let folders, files = List.partition (fun (e : entry) -> e.is_dir) entries in
  List.stable_sort by (List.sort by_name folders) @ List.stable_sort by (List.sort by_name files)

let size_text (n : int) : string =
  let tenths (unit : int) (name : string) =
    let t = n * 10 / unit in
    if t >= 100 then Printf.sprintf "%d %s" (t / 10) name else Printf.sprintf "%d.%d %s" (t / 10) (t mod 10) name
  in
  if n < 1024 then Printf.sprintf "%d bytes" n
  else if n < 1024 * 1024 then tenths 1024 "KB"
  else if n < 1024 * 1024 * 1024 then tenths (1024 * 1024) "MB"
  else tenths (1024 * 1024 * 1024) "GB"

let day_text (t : float) : string =
  let tm = Unix.gmtime t in
  Printf.sprintf "%d-%02d-%02d" (tm.Unix.tm_year + 1900) (tm.Unix.tm_mon + 1) tm.Unix.tm_mday

let parent ~(root : string) (path : string) : string = if path = root then root else Filename.dirname path

let parents ~(root : string) (path : string) : (string * string) list =
  let rec up (p : string) (acc : (string * string) list) =
    if p = root then ("/", p) :: acc
    else if Filename.dirname p = p then (p, p) :: acc
    else up (Filename.dirname p) ((Filename.basename p, p) :: acc)
  in
  up path []

let join (dir : string) (name : string) : string = if dir = "/" then "/" ^ name else dir ^ "/" ^ name
