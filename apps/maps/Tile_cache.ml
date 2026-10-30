(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Tile_cache.mli *)

type caps = < Cap.open_in; Cap.open_out >
type entry = { bytes : string; expires : float; etag : string option }

type t = {
  caps : caps;
  dir : string;
  limit : int;
  uses : (string, int * int) Hashtbl.t; (* a file's: the last use, its size *)
  mutable tick : int;
  mutable total : int;
  mutable unsaved : int;
}

(*****************************************************************************)
(* How long it is good *)
(*****************************************************************************)

let lifetime ~(now : float) (headers : Http.header list) : float option =
  let directives =
    match Http.header "Cache-Control" headers with
    | None -> []
    | Some v -> List.map (fun (d : string) -> String.lowercase_ascii (String.trim d)) (String.split_on_char ',' v)
  in
  let max_age =
    List.find_map
      (fun (d : string) ->
        if String.starts_with ~prefix:"max-age=" d then int_of_string_opt (String.sub d 8 (String.length d - 8)) else None)
      directives
  in
  let age =
    match Option.bind (Http.header "Age" headers) int_of_string_opt with Some a -> a | None -> 0
  in
  if List.mem "no-store" directives then None
  else if List.mem "no-cache" directives then Some 0.
  else
    match (max_age, Option.bind (Http.header "Expires" headers) Cookie.date) with
    | Some n, _ -> Some (now +. float_of_int (n - age))
    | None, Some date -> Some date
    | None, None -> Some 0.

(*****************************************************************************)
(* The files *)
(*****************************************************************************)

(* "4/8/5" -> dir/4-8-5 *)
let file (c : t) (name : string) : Fpath.t =
  Fpath.v (Filename.concat c.dir (String.concat "-" (String.split_on_char '/' name)))

let index (c : t) : Fpath.t = Fpath.v (Filename.concat c.dir "index")

let save_index (c : t) : unit =
  let lines =
    Hashtbl.fold
      (fun (name : string) ((tick, size) : int * int) (acc : string list) ->
        Printf.sprintf "%s %d %d\n" name tick size :: acc)
      c.uses []
  in
  (try FS.write c.caps (index c) (String.concat "" lines) with Sys_error _ | Unix.Unix_error _ -> ());
  c.unsaved <- 0

let load_index (c : t) : unit =
  match FS.read_opt c.caps (index c) with
  | None -> ()
  | Some text ->
      List.iter
        (fun (line : string) ->
          match String.split_on_char ' ' line with
          | [ name; tick; size ] -> (
              match (int_of_string_opt tick, int_of_string_opt size) with
              | Some tick, Some size ->
                  Hashtbl.replace c.uses name (tick, size);
                  c.tick <- max c.tick tick;
                  c.total <- c.total + size
              | _ -> ())
          | _ -> ())
        (String.split_on_char '\n' text)

let rec made (caps : caps) (dir : string) : unit =
  if not (Sys.file_exists dir) then begin
    made caps (Filename.dirname dir);
    FS.mkdir caps dir 0o755
  end

let create (caps : < Cap.open_in; Cap.open_out; .. >) ~(dir : string) ~(limit : int) : t option =
  let caps = (caps :> caps) in
  match made caps dir with
  | exception (Sys_error _ | Unix.Unix_error _) -> None
  | () ->
      let c = { caps; dir; limit; uses = Hashtbl.create 500; tick = 0; total = 0; unsaved = 0 } in
      load_index c;
      Some c

(* a use: known, in the index, at the next save *)
let used (c : t) (name : string) (size : int) : unit =
  (match Hashtbl.find_opt c.uses name with
  | Some (_, was) -> c.total <- c.total - was
  | None -> ());
  c.tick <- c.tick + 1;
  c.total <- c.total + size;
  c.unsaved <- c.unsaved + 1;
  Hashtbl.replace c.uses name (c.tick, size);
  if c.unsaved >= 16 then save_index c

(* down to nine tenths of the limit, the oldest first *)
let trimmed (c : t) : unit =
  if c.total > c.limit then begin
    let all =
      Hashtbl.fold (fun (name : string) ((tick, size) : int * int) acc -> (tick, name, size) :: acc) c.uses []
    in
    List.iter
      (fun ((_, name, size) : int * string * int) ->
        if c.total > c.limit / 10 * 9 then begin
          (try FS.remove c.caps (file c name) with Sys_error _ | Unix.Unix_error _ -> ());
          Hashtbl.remove c.uses name;
          c.total <- c.total - size
        end)
      (List.sort compare all);
    save_index c
  end

(*****************************************************************************)
(* A tile *)
(*****************************************************************************)

(* the file: "expires etag\n", then the tile's bytes *)
let find (c : t) (name : string) : entry option =
  match FS.read_opt c.caps (file c name) with
  | None -> None
  | Some text -> (
      match String.index_opt text '\n' with
      | None -> None
      | Some i -> (
          let bytes = String.sub text (i + 1) (String.length text - i - 1) in
          let head = String.sub text 0 i in
          let found (expires : string) (etag : string option) : entry option =
            match float_of_string_opt expires with
            | None -> None
            | Some expires ->
                used c name (String.length text);
                Some { bytes; expires; etag }
          in
          match String.index_opt head ' ' with
          | None -> found head None
          | Some j -> found (String.sub head 0 j) (Some (String.sub head (j + 1) (String.length head - j - 1)))))

let put (c : t) (name : string) (e : entry) : unit =
  (* (down: rounded up, a tile of max-age=0 would be good for half a second) *)
  let head = Printf.sprintf "%.0f%s\n" (floor e.expires) (match e.etag with Some t -> " " ^ t | None -> "") in
  let text = head ^ e.bytes in
  match FS.write c.caps (file c name) text with
  | exception (Sys_error _ | Unix.Unix_error _) -> ()
  | () ->
      used c name (String.length text);
      trimmed c

let size (c : t) : int * int = (Hashtbl.length c.uses, c.total)
