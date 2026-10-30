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
  Logs.debug (fun m -> m "store: writing %s" (Item.id item));
  mkdir_p caps (Filename.concat t.dir "items");
  FS.write caps (Fpath.v (path t "items" (Item.id item))) (Item.to_string item)

let all (caps : < Cap.open_in; Cap.readdir; .. >) (t : t) : Item.t list =
  let dir = Filename.concat t.dir "items" in
  if not (Sys.file_exists dir) then begin
    Logs.debug (fun m -> m "store: no %s yet" dir);
    []
  end
  else
    let names = Array.to_list (Sys.readdir dir) in
    Logs.debug (fun m -> m "store: reading %d items of %s" (List.length names) dir);
    List.map
      (fun name -> Item.parse (FS.read caps (Fpath.v (Filename.concat dir name))))
      (List.sort compare names)

let cached (caps : < Cap.open_in; .. >) (t : t) (key : string) : string option =
  Logs.debug (fun m -> m "store: the cache's %s" key);
  FS.read_opt caps (Fpath.v (path t "cache" key))

let cache (caps : < Cap.open_out; .. >) (t : t) (key : string)
    (bytes : string) : unit =
  mkdir_p caps (Filename.concat t.dir "cache");
  FS.write caps (Fpath.v (path t "cache" key)) bytes

let remove (caps : < Cap.open_out; .. >) (t : t) (id : string) : unit =
  let p = path t "items" id in
  if Sys.file_exists p then FS.remove caps (Fpath.v p)

let secret (caps : < Cap.env; Cap.open_in; .. >) (name : string) :
    (string option, string) result =
  let file = Filename.concat (place caps) name in
  match Unix.stat file with
  | exception Unix.Unix_error _ ->
      Logs.info (fun m -> m "store: no %s" file);
      Ok None
  | st when st.st_perm land 0o077 <> 0 ->
      Error
        (Printf.sprintf "%s: others may read it (chmod 600 %s), not used"
           file file)
  | _ ->
      Logs.info (fun m -> m "store: reading %s" file);
      Ok (FS.read_opt caps (Fpath.v file))

