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

(*****************************************************************************)
(* Changing files *)
(*****************************************************************************)

exception Refused of string

type caps = < Cap.readdir ; Cap.open_in ; Cap.open_out >

let exists (caps : < caps ; .. >) (path : string) : bool =
  match Sys_plan9.dirstat caps path with
  | (_ : Sys_plan9.dir) -> true
  | exception Unix.Unix_error _ -> false

let is_dir (d : Sys_plan9.dir) : bool = d.qid_type land Sys_plan9.dmdir <> 0

let good_name (name : string) : bool = name <> "" && name <> "." && name <> ".." && not (String.contains name '/')

let copy_name ~(taken : string -> bool) (name : string) : string =
  let rec try_ (i : int) =
    let new_name = Printf.sprintf "copy %d of %s" i name in
    if taken new_name then try_ (i + 1) else new_name
  in
  let first = "copy of " ^ name in
  if taken first then try_ 2 else first

let copy_file (caps : < caps ; .. >) (from : string) (dest : string) (perm : int) : unit =
  let from_fd = FS.open_in_fd caps from in
  Fun.protect
    ~finally:(fun () -> Unix.close from_fd)
    (fun () ->
      let to_fd = FS.open_out_fd caps dest perm in
      Fun.protect
        ~finally:(fun () -> Unix.close to_fd)
        (fun () ->
          let buf = Bytes.create 8192 in
          let rec go () =
            let n = Unix.read from_fd buf 0 8192 in
            if n > 0 then
              if Unix.write to_fd buf 0 n = n then go () else raise (Refused (dest ^ ": short write"))
          in
          go ()))

(* the day kept, as mv's; a file server may refuse it, and that is no failure *)
let rec copy_tree (caps : < caps ; .. >) (from : string) (dest : string) : unit =
  if Sys_plan9.is_link caps from then raise (Refused (Filename.basename from ^ ": a link, not copied"));
  if Sys_plan9.is_device caps from then raise (Refused (Filename.basename from ^ ": a pipe or a device, not copied"));
  let d = Sys_plan9.dirstat caps from in
  if is_dir d then (
    FS.mkdir caps dest (d.perm lor 0o700);
    List.iter (fun (e : entry) -> copy_tree caps (join from e.name) (join dest e.name)) (list caps from))
  else copy_file caps from dest d.perm;
  try Sys_plan9.set_mtime caps dest d.mtime with Unix.Unix_error _ -> ()

(* a link removed is the link: is_dir says what it points to, which stays *)
let rec remove (caps : < caps ; .. >) (path : string) : unit =
  if is_dir (Sys_plan9.dirstat caps path) && not (Sys_plan9.is_link caps path) then
    List.iter (fun (e : entry) -> remove caps (join path e.name)) (list caps path);
  FS.remove_any caps path

let check_free (caps : < caps ; .. >) (dest : string) : unit =
  if exists caps dest then raise (Refused (Filename.basename dest ^ " is already there"))

let copy (caps : < caps ; .. >) (from : string) (dest : string) : unit =
  check_free caps dest;
  if String.starts_with ~prefix:(from ^ "/") dest then raise (Refused (Filename.basename from ^ " can't go inside itself"));
  try copy_tree caps from dest
  with e ->
    (try remove caps dest with Unix.Unix_error _ -> ());
    raise e

let rename (caps : < caps ; .. >) (path : string) (name : string) : unit =
  check_free caps (join (Filename.dirname path) name);
  Sys_plan9.rename caps path name

let move (caps : < caps ; .. >) (from : string) (dest : string) : unit =
  if Filename.dirname from = Filename.dirname dest then rename caps from (Filename.basename dest)
  else (
    copy caps from dest;
    remove caps from)

let make_folder (caps : < caps ; .. >) (path : string) : unit =
  check_free caps path;
  FS.mkdir caps path 0o777
