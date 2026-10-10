(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Browser_profile.mli *)

type t = { zooms : Browser_zoom.t; window : (int * int) option }

let empty : t = { zooms = Browser_zoom.empty; window = None }
let lines (s : string) : string list = List.filter (fun l -> l <> "") (List.map String.trim (String.split_on_char '\n' s))

(*****************************************************************************)
(* preferences *)
(*****************************************************************************)

let to_string (p : t) : string =
  (match p.window with Some (w, h) -> Printf.sprintf "window %d %d\n" w h | None -> "")
  ^ String.concat "" (List.map (fun (host, z) -> Printf.sprintf "zoom %s %g\n" host z) p.zooms)

let of_string (s : string) : t =
  let first = List.hd Browser_zoom.levels and last = List.nth Browser_zoom.levels (List.length Browser_zoom.levels - 1) in
  let zoom (line : string) : (string * float) option =
    match String.split_on_char ' ' line with
    | [ "zoom"; host; z ] -> ( match float_of_string_opt z with Some z when z >= first && z <= last && z <> 1. -> Some (host, z) | _ -> None)
    | _ -> None
  in
  let window (line : string) : (int * int) option =
    match List.map int_of_string_opt (String.split_on_char ' ' line) with
    | [ None; Some w; Some h ] when String.starts_with ~prefix:"window " line && w >= 100 && h >= 100 && w <= 10000 && h <= 10000 -> Some (w, h)
    | _ -> None
  in
  { zooms = List.filter_map zoom (lines s); window = List.find_map window (lines s) }

(*****************************************************************************)
(* cookies.txt *)
(*****************************************************************************)

let http_only = "#HttpOnly_"
let flag (b : bool) : string = if b then "TRUE" else "FALSE"

let cookies_to_string (jar : Cookie.jar) : string =
  let line (c : Cookie.cookie) : string option =
    match c.expires with
    | None -> None
    | Some expires ->
        Some
          (Printf.sprintf "%s%s\t%s\t%s\t%s\t%.0f\t%s\t%s\n" (if c.http_only then http_only else "") c.domain (flag (not c.host_only)) c.path (flag c.secure) expires c.name c.value)
  in
  "# Netscape HTTP Cookie File\n" ^ String.concat "" (List.filter_map line jar)

let cookies_of_string ~(now : float) (s : string) : Cookie.jar =
  let cookie (i : int) (line : string) : Cookie.cookie option =
    let line, only = if String.starts_with ~prefix:http_only line then (String.sub line (String.length http_only) (String.length line - String.length http_only), true) else (line, false) in
    match String.split_on_char '\t' line with
    | [ domain; under; path; secure; expires; name; value ] when domain <> "" && domain.[0] <> '#' && name <> "" -> (
        match float_of_string_opt expires with
        | Some expires when expires > now ->
            (* the jar has the newest first: the file's order is its age *)
            Some { name; value; domain; host_only = under <> "TRUE"; path; expires = Some expires; secure = secure = "TRUE"; http_only = only; created = now -. float_of_int i }
        | _ -> None)
    | _ -> None
  in
  List.filter_map (fun c -> c) (List.mapi cookie (List.filter (fun l -> l <> "") (String.split_on_char '\n' s)))

(*****************************************************************************)
(* The directory *)
(*****************************************************************************)

let default_dir (caps : < Cap.env; .. >) : string option =
  let env (name : string) : string option = match CapSys.getenv caps name with "" -> None | v -> Some v | exception Not_found -> None in
  match (env "XDG_CONFIG_HOME", env "HOME") with
  | Some config, _ -> Some (Filename.concat config "mini-netscape")
  | None, Some home -> Some (Filename.concat (Filename.concat home ".config") "mini-netscape")
  | None, None -> None

let load (caps : < Cap.open_in; .. >) ~(dir : string) : t * Cookie.jar =
  let read (name : string) : string = match FS.read_opt caps (Fpath.v (Filename.concat dir name)) with Some s -> s | None -> "" in
  (of_string (read "preferences"), cookies_of_string ~now:(Unix.gettimeofday ()) (read "cookies.txt"))

let write (caps : < Cap.open_out; .. >) ~(dir : string) (name : string) (perm : int) (text : string) : (unit, string) result =
  let rec make (dir : string) : unit =
    if not (Sys.file_exists dir) then begin
      make (Filename.dirname dir);
      FS.mkdir caps dir 0o700
    end
  in
  try
    make dir;
    FS.write_perm caps perm (Fpath.v (Filename.concat dir name)) text;
    Ok ()
  with Sys_error why | Failure why -> Error why | Unix.Unix_error (e, _, _) -> Error (Filename.concat dir name ^ ": " ^ Unix.error_message e)

let save (caps : < Cap.open_out; .. >) ~(dir : string) (p : t) : (unit, string) result = write caps ~dir "preferences" 0o644 (to_string p)
let save_cookies (caps : < Cap.open_out; .. >) ~(dir : string) (jar : Cookie.jar) : (unit, string) result = write caps ~dir "cookies.txt" 0o600 (cookies_to_string jar)
