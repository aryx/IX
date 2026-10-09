(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
 *)
(* ix: after the author's playground's playground/platforms/native_common/Store.ml; written again over the capabilities (docs/plans/plan_office.md) *)

(* See Store.mli *)

let env (caps : < Cap.env ; .. >) (name : string) : string option =
  match CapSys.getenv caps name with "" -> None | s -> Some s | exception Not_found -> None

let dir (caps : < Cap.env ; .. >) : string =
  match env caps "PLAYGROUND_STORE" with
  | Some d -> d
  | None ->
      (* (Plan 9's $home, and a user's files of that kind in its lib/) *)
      match (env caps "HOME", env caps "home") with
      | Some h, _ -> Filename.concat (Filename.concat h ".ix-playground") "documents"
      | None, Some h -> Filename.concat (Filename.concat h "lib") "documents"
      | None, None -> "documents"

(* a directory and those above it, made where they are not (one that
   is there already, or may not be made, is an error left to the
   write that follows) *)
let rec mkdir_p (caps : < Cap.open_out ; .. >) (d : string) : unit =
  if d <> "/" && d <> "." && d <> "" then begin
    mkdir_p caps (Filename.dirname d);
    try FS.mkdir caps d 0o755 with Unix.Unix_error _ -> ()
  end

(* a name is a file's name in the directory, never a path: no '/', and
   no leading '.' (no "..", no hidden file) *)
let file_name (name : string) : string =
  let s = String.map (fun c -> if c = '/' || c = '\\' then '_' else c) name in
  if s = "" || s.[0] = '.' then "_" ^ s else s

let store (caps : < Cap.env ; Cap.open_out ; .. >) (name : string) (bytes : string) : unit =
  let d = dir caps in
  mkdir_p caps d;
  FS.write caps (Fpath.v (Filename.concat d (file_name name))) bytes

let fetch (caps : < Cap.env ; Cap.open_in ; .. >) (name : string) : string option =
  FS.read_opt caps (Fpath.v (Filename.concat (dir caps) (file_name name)))

let stored (caps : < Cap.env ; Cap.readdir ; .. >) : string list =
  match Sys_plan9.dirread caps (dir caps) with
  | entries -> List.sort compare (List.map (fun (e : Sys_plan9.dir) -> e.name) entries)
  | exception Unix.Unix_error _ -> []

let export (caps : < Cap.open_out ; .. >) (name : string) (bytes : string) : unit = FS.write caps (Fpath.v (file_name name)) bytes
