(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Unit_finder.mli *)

(* the project's units: each file name's directories (Lexer.ml, Lexer.mli),
 * each directory's unit names *)
type index = {
  homes : (string, string list) Hashtbl.t;
  names : (string, (string, unit) Hashtbl.t) Hashtbl.t;
}

type t = {
  (* the index, made on the first unit asked for: None until then, and
   * Some None when there is no project *)
  mutable index : index option option;
  make : unit -> index option;
  (* the module names the program's files use *)
  needed : (string, unit) Hashtbl.t;
  (* the directories chosen for the program's units so far *)
  chosen : (string, unit) Hashtbl.t;
}

let unit_of (file : string) : string = String.capitalize_ascii (Filename.remove_extension file)

let found (h : (string, 'a list) Hashtbl.t) (k : string) : 'a list =
  match Hashtbl.find_opt h k with Some l -> l | None -> []

let add (h : (string, 'a list) Hashtbl.t) (k : string) (v : 'a) : unit =
  Hashtbl.replace h k (v :: found h k)

(* (.git, _build, _mk/7, _make-x: a checkout's or a build's, not sources) *)
let skipped (n : string) : bool = n = "" || n.[0] = '.' || n.[0] = '_'

let rec walk (caps : < Cap.readdir; .. >) (idx : index) (d : string) : unit =
  let entries = try CapSys.readdir caps d with Sys_error _ -> [||] in
  Array.sort compare entries;
  Array.iter
    (fun (n : string) ->
      let p = if d = "." then n else Filename.concat d n in
      if skipped n then ()
      else if Filename.check_suffix n ".ml" || Filename.check_suffix n ".mli" then begin
        let u = unit_of n and key = String.capitalize_ascii n in
        if not (List.mem d (found idx.homes key)) then add idx.homes key d;
        let names =
          match Hashtbl.find_opt idx.names d with
          | Some h -> h
          | None -> let h = Hashtbl.create 16 in Hashtbl.replace idx.names d h; h in
        Hashtbl.replace names u ()
      end
      else if (try CapSys.is_directory caps p with Sys_error _ -> false) then walk caps idx p)
    entries

(* the project's root, the first directory above [file] with a
 * dune-project, as the files are named: relative to the current
 * directory when under it *)
let root (caps : < Cap.readdir; .. >) (file : string) : string option =
  let cwd = FS.getcwd caps () in
  let absolute = FS.cleanname (if Filename.is_relative file then Filename.concat cwd file else file) in
  let rec up (d : string) : string option =
    if CapSys.file_exists caps (Filename.concat d "dune-project") then Some d
    else if Filename.dirname d = d then None
    else up (Filename.dirname d) in
  match up (Filename.dirname absolute) with
  | None -> None
  | Some r when r = cwd -> Some "."
  | Some r when String.starts_with ~prefix:(cwd ^ "/") r -> Some (String.sub r (String.length cwd + 1) (String.length r - String.length cwd - 1))
  | Some r -> Some r

let create (caps : < Cap.readdir; .. >) (file : string) : t =
  let make () : index option =
    match root caps file with
    | None -> None
    | Some r ->
        let idx = { homes = Hashtbl.create 1024; names = Hashtbl.create 256 } in
        walk caps idx r;
        Logs.info (fun m -> m "units: the project's at %s, %d names in %d directories" r (Hashtbl.length idx.homes) (Hashtbl.length idx.names));
        Some idx in
  { index = None; make; needed = Hashtbl.create 64; chosen = Hashtbl.create 16 }

let index (t : t) : index option =
  match t.index with
  | Some i -> i
  | None -> let i = t.make () in t.index <- Some i; i

let is_ident (c : char) : bool =
  match c with 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_' | '\'' -> true | _ -> false

(* (a capitalized name before a dot: List.map's List, Lexer.token's Lexer;
 * a comment's or a string's too, which costs only a little precision) *)
let mentions (t : t) (text : string) : unit =
  let n = String.length text in
  let i = ref 0 in
  while !i < n do
    let c = text.[!i] in
    if c >= 'A' && c <= 'Z' && (!i = 0 || not (is_ident text.[!i - 1])) then begin
      let j = ref !i in
      while !j < n && is_ident text.[!j] do incr j done;
      if !j < n && text.[!j] = '.' then Hashtbl.replace t.needed (String.sub text !i (!j - !i)) ();
      i := !j
    end
    else incr i
  done

(* the directories in common, from the top: tiny/TinyML and tiny/TinyC 1 *)
let near (a : string) (b : string) : int =
  let parts (s : string) = List.filter (fun (x : string) -> x <> "" && x <> ".") (String.split_on_char '/' s) in
  let rec common (x : string list) (y : string list) : int =
    match x, y with
    | p :: x, q :: y when p = q -> 1 + common x y
    | _ -> 0 in
  common (parts a) (parts b)

let choose (t : t) (from : string) (name : string) (exts : string list) : string option =
  match index t with
  | None -> None
  | Some idx -> (
      match List.concat_map (fun (e : string) -> found idx.homes (name ^ e)) exts with
      | [] -> None
      | ds ->
          let supplies (d : string) : int =
            match Hashtbl.find_opt idx.names d with
            | None -> 0
            | Some names -> Hashtbl.fold (fun (u : string) () n -> if Hashtbl.mem names u then n + 1 else n) t.needed 0 in
          let score (d : string) : int * int * int =
            ((if Hashtbl.mem t.chosen d then 1 else 0), supplies d, near (Filename.dirname from) d) in
          (* (the best first; among equals, by name) *)
          let ranked =
            List.sort (fun (a : string) (b : string) -> compare (score b, a) (score a, b)) (List.sort_uniq compare ds) in
          match ranked with
          | [] -> None
          | best :: rest ->
              (match rest with
               | next :: _ when score next = score best ->
                   Logs.warn (fun m -> m "unit %s (named in %s): %s or %s, a tie; %s taken (-I or -own to choose)" name from best next best)
               | _ -> ());
              if not (Hashtbl.mem t.chosen best) then
                Logs.info (fun m -> m "unit %s (named in %s): %s, of %d" name from best (List.length ranked));
              Hashtbl.replace t.chosen best ();
              Some best)
