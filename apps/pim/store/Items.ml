(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Items.mli *)

type t = { dir : string }

let place (caps : < Cap.env; .. >) : string =
  let env name =
    match CapSys.getenv caps name with
    | "" -> None
    | s -> Some s
    | exception Not_found -> None
  in
  match (env "PIM_STORE", env "HOME", env "home") with
  | Some d, _, _ -> d
  | None, Some h, _ -> Filename.concat h ".ix-pim"
  | None, None, Some h -> Filename.concat (Filename.concat h "lib") "pim"
  | None, None, None -> "pim"

let at (dir : string) : t = { dir }

(* a directory and those above it, made where they are not *)
let rec mkdir_p (caps : < Cap.open_out; .. >) (d : string) : unit =
  if d <> "/" && d <> "." && d <> "" && not (Sys.file_exists d) then begin
    mkdir_p caps (Filename.dirname d);
    try FS.mkdir caps d 0o755 with Unix.Unix_error _ -> ()
  end

(* an id as a file's name: no '/', no leading '.' *)
let file_name (id : string) : string =
  let s = String.map (fun c -> if c = '/' || c = '\\' then '_' else c) id in
  if s = "" || s.[0] = '.' then "_" ^ s else s

let path (t : t) (part : string) (name : string) : string =
  Filename.concat (Filename.concat t.dir part) (file_name name)

let find (caps : < Cap.open_in; .. >) (t : t) (id : string) : Item.t option =
  Option.map Item.parse (FS.read_opt caps (Fpath.v (path t "items" id)))

let save (caps : < Cap.open_out; .. >) (t : t) (item : Item.t) : unit =
  mkdir_p caps (Filename.concat t.dir "items");
  FS.write caps (Fpath.v (path t "items" (Item.id item))) (Item.to_string item)

let all (caps : < Cap.open_in; Cap.readdir; .. >) (t : t) : Item.t list =
  let dir = Filename.concat t.dir "items" in
  if not (Sys.file_exists dir) then []
  else
    List.map
      (fun name -> Item.parse (FS.read caps (Fpath.v (Filename.concat dir name))))
      (List.sort compare (Array.to_list (Sys.readdir dir)))

let cached (caps : < Cap.open_in; .. >) (t : t) (key : string) : string option =
  FS.read_opt caps (Fpath.v (path t "cache" key))

let cache (caps : < Cap.open_out; .. >) (t : t) (key : string)
    (bytes : string) : unit =
  mkdir_p caps (Filename.concat t.dir "cache");
  FS.write caps (Fpath.v (path t "cache" key)) bytes
