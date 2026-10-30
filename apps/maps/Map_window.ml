(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Map_window.mli *)

module P = Playground

type caps = < Cap.network; Cap.open_in; Cap.open_out; Cap.env >

(*****************************************************************************)
(* Types *)
(*****************************************************************************)

(* a tile in memory: its own picture, or its ancestor's enlarged *)
type tile = { image : Rgba_image.t; sharp : bool; mutable used : int }

type model = {
  z : int;
  cx : int; (* the window's centre, a pixel of the world at zoom z *)
  cy : int;
  grab : (float * float * int * int) option; (* a drag: the mouse and the centre when it began *)
  wheel : float; (* the wheel's notches not yet a zoom's level *)
  store : (string, tile) Hashtbl.t;
  failed : (string, float) Hashtbl.t; (* a tile that failed: when to ask again *)
  ticks : int; (* a frame's number, for the least recently used *)
  generation : int; (* changes with what the store has for the view *)
  said : string; (* what went wrong last *)
}

let kept = 120
let again_after = 30.
let credit = "\xc2\xa9 OpenStreetMap contributors"
let user_agent = "mini-maps/0.1 (+https://github.com/aryx/ix)"
let default_tiles = "https://tile.openstreetmap.org"
let default_cache_megabytes = 32

(*****************************************************************************)
(* A tile *)
(*****************************************************************************)

(* the tile, by the rules of Tile_cache.mli: on the disk and good, it is
 * not asked; on the disk and old, asked if it changed, and shown if the
 * server does not answer; else asked *)
let fetch (caps : caps) (base : string) (cache : Tile_cache.t option) (key : Tiles.key) : (Rgba_image.t, string) result =
  let name = Tiles.name key in
  let now = Unix.gettimeofday () in
  let ask (more : Http.header list) : (Http.response, string) result =
    let said = ("User-Agent", user_agent) :: more in
    let options = { Http_client.defaults with said; keep = true } in
    Result.map snd (Http_client.fetch_with options caps ~post:None (Tiles.url base key))
  in
  let kept (e : Tile_cache.entry) : unit = Option.iter (fun (c : Tile_cache.t) -> Tile_cache.put c name e) cache in
  (* what a server gave: kept if it may be *)
  let given (r : Http.response) : (Rgba_image.t, string) result =
    if r.status <> 200 then Error (Printf.sprintf "%d %s" r.status r.reason)
    else begin
      (match Tile_cache.lifetime ~now r.headers with
      | Some expires -> kept { bytes = r.body; expires; etag = Http.header "ETag" r.headers }
      | None -> ());
      Ok (Png.decode r.body)
    end
  in
  (* (a file cut short by a crash: not a tile, asked again) *)
  let read (e : Tile_cache.entry) : Rgba_image.t option = try Some (Png.decode e.bytes) with Failure _ -> None in
  let afresh () : (Rgba_image.t, string) result =
    match ask [] with Ok r -> given r | Error why -> Error why
  in
  match Option.bind cache (fun (c : Tile_cache.t) -> Tile_cache.find c name) with
  | None -> afresh ()
  | Some e -> (
      match read e with
      | None -> afresh ()
      | Some image when e.expires > now -> Ok image
      | Some image -> (
          let more = match e.etag with Some tag -> [ ("If-None-Match", tag) ] | None -> [] in
          match ask more with
          | Ok r when r.status = 304 ->
              (match Tile_cache.lifetime ~now r.headers with
              | Some expires -> kept { e with expires }
              | None -> ());
              Ok image
          | Ok r when r.status = 200 -> given r
          | Ok _ | Error _ -> Ok image))

(*****************************************************************************)
(* The store *)
(*****************************************************************************)

(* the tiles over [kept], the least recently shown *)
let trimmed (m : model) : unit =
  let over = Hashtbl.length m.store - kept in
  if over > 0 then begin
    let all = Hashtbl.fold (fun (k : string) (t : tile) acc -> (t.used, k) :: acc) m.store [] in
    List.iteri
      (fun (i : int) ((_, k) : int * string) -> if i < over then Hashtbl.remove m.store k)
      (List.sort compare all)
  end

let collected (now : float) (m : model) : model =
  match Tile_worker.take () with
  | [] -> m
  | done_ ->
      let said =
        List.fold_left
          (fun (_ : string) ((key, r) : Tiles.key * (Rgba_image.t, string) result) ->
            let k = Tiles.name key in
            match r with
            | Ok image ->
                Hashtbl.remove m.failed k;
                Hashtbl.replace m.store k { image; sharp = true; used = m.ticks };
                ""
            | Error why ->
                Hashtbl.replace m.failed k (now +. again_after);
                Printf.sprintf "tile %s: %s" k why)
          m.said done_
      in
      trimmed m;
      { m with said; generation = m.generation + 1 }

(* the tile's own picture or, while it has not come, a part of its nearest
 * ancestor that is there, kept in the store *)
let placeholder (m : model) (key : Tiles.key) : Rgba_image.t option =
  let rec up (n : int) : Rgba_image.t option =
    if n > 4 || n > key.z then None
    else
      match Hashtbl.find_opt m.store (Tiles.name (Tiles.ancestor key n)) with
      | Some { sharp = true; image; _ } -> Some (Tiles.enlarged image key n)
      | _ -> up (n + 1)
  in
  up 1

(* what the view shows: each tile marked as used, an enlarged one made if
 * it can be, and those to fetch *)
let in_store (now : float) (m : model) (visible : Tiles.placed list) : model * Tiles.key list =
  let changed = ref false in
  let missing =
    List.filter
      (fun (p : Tiles.placed) ->
        let k = Tiles.name p.key in
        let sharp =
          match Hashtbl.find_opt m.store k with
          | Some t -> t.used <- m.ticks; t.sharp
          | None -> (
              match placeholder m p.key with
              | Some image ->
                  Hashtbl.replace m.store k { image; sharp = false; used = m.ticks };
                  changed := true;
                  false
              | None -> false)
        in
        (not sharp) && match Hashtbl.find_opt m.failed k with Some at -> now >= at | None -> true)
      visible
  in
  let rec unique (seen : string list) (l : Tiles.placed list) : Tiles.key list =
    match l with
    | [] -> []
    | p :: rest ->
        let k = Tiles.name p.key in
        if List.mem k seen then unique seen rest else p.key :: unique (k :: seen) rest
  in
  (trimmed m;
   if !changed then { m with generation = m.generation + 1 } else m),
  unique [] missing

(*****************************************************************************)
(* Update *)
(*****************************************************************************)

let zoomed (dz : int) (px : int) (py : int) (h : int) (m : model) : model =
  let z = max 0 (min Tiles.max_zoom (m.z + dz)) in
  if z = m.z then m
  else
    let cx, cy = Tiles.rezoomed ~dz:(z - m.z) ~px ~py m.cx m.cy in
    let cx, cy = Tiles.centred z cx cy h in
    { m with z; cx; cy; grab = None }

let update (computer : P.computer) (m : model) : model =
  let (P.Time now) = computer.time in
  let mouse = computer.mouse and keys = computer.keyboard in
  let w = int_of_float computer.screen.width and h = int_of_float computer.screen.height in
  let px = int_of_float (Float.round mouse.mx) and py = -int_of_float (Float.round mouse.my) in
  let m = { m with ticks = m.ticks + 1 } in
  let m = collected now m in
  (* the keys typed, each a level: at the window's centre *)
  let m =
    List.fold_left
      (fun (m : model) (c : string) ->
        match c with
        | "+" | "=" -> zoomed 1 0 0 h m
        | "-" -> zoomed (-1) 0 0 h m
        | _ -> m)
      m (Text.chars keys.typed)
  in
  (* the wheel and a double click: at the mouse *)
  let notches = m.wheel +. mouse.mwheel in
  let steps = int_of_float notches in
  let m = { m with wheel = notches -. float_of_int steps } in
  let m = if steps <> 0 then zoomed steps px py h m else m in
  let m = if mouse.mdouble then zoomed 1 px py h m else m in
  (* a drag: the map under the mouse; the arrows *)
  let m =
    match (m.grab, mouse.mdown) with
    | None, true -> { m with grab = Some (mouse.mx, mouse.my, m.cx, m.cy) }
    | Some _, false -> { m with grab = None }
    | Some (mx, my, cx, cy), true ->
        let cx, cy =
          Tiles.centred m.z
            (cx + int_of_float (Float.round (mx -. mouse.mx)))
            (cy + int_of_float (Float.round (mouse.my -. my)))
            h
        in
        { m with cx; cy }
    | None, false -> m
  in
  let dx = (if keys.kright then 8 else 0) - if keys.kleft then 8 else 0 in
  let dy = (if keys.kdown then 8 else 0) - if keys.kup then 8 else 0 in
  let m =
    if dx = 0 && dy = 0 then m
    else
      let cx, cy = Tiles.centred m.z (m.cx + dx) (m.cy + dy) h in
      { m with cx; cy }
  in
  let m, missing = in_store now m (Tiles.in_view m.z m.cx m.cy w h) in
  Tile_worker.want missing;
  (* (mini-ml's threads: the worker's turn) *)
  if Tile_worker.out () then Thread.yield ();
  m

(*****************************************************************************)
(* View *)
(*****************************************************************************)

let text_size = 14.

(* [s]'s letters from [x] on [baseline], and their width *)
let text (color : P.color) (x : float) (baseline : float) (s : string) : P.shape * float =
  let rec place (x0 : float) (acc : (float * string) list) (l : string list) =
    match l with
    | [] -> (List.rev acc, x0)
    | c :: rest ->
        let g = Glyph_unicode.glyph c in
        place (x0 +. (float_of_int (g.right - g.left) *. text_size /. Hershey.units_per_em)) ((x0, c) :: acc) rest
  in
  let at, x1 = place x [] (Text.chars s) in
  (P.letters color { size = text_size; bold = false; italic = false; baseline; at }, x1 -. x)

(* a line of text on a band at the window's foot, from the left or the right *)
let band (w : float) (h : float) (from_right : bool) (s : string) : P.shape list =
  let _, tw = text P.black 0. 0. s in
  let room = tw +. 8. and bh = 20. in
  let left = if from_right then (w /. 2.) -. room else -.w /. 2. in
  let foot = -.h /. 2. in
  let t, _ = text P.black (left +. 4.) (foot +. 6.) s in
  [ P.rectangle (P.rgb 240 240 240) room bh |> P.move (left +. (room /. 2.)) (foot +. (bh /. 2.)); t ]

let where (m : model) : string =
  let lat = Mercator.latitude_of_y m.z m.cy and lon = Mercator.longitude_of_x m.z m.cx in
  Printf.sprintf "%.3f %c  %.3f %c  zoom %d" (Float.abs lat) (if lat >= 0. then 'N' else 'S')
    (Float.abs lon) (if lon >= 0. then 'E' else 'W') m.z

let drawn (w : int) (h : int) (m : model) : P.shape list =
  let fw = float_of_int w and fh = float_of_int h in
  let tile (p : Tiles.placed) : P.shape option =
    match Hashtbl.find_opt m.store (Tiles.name p.key) with
    | None -> None
    | Some t ->
        let half = float_of_int Tiles.size /. 2. in
        Some
          (P.bitmap (float_of_int Tiles.size) (float_of_int Tiles.size) t.image
          |> P.move
               (float_of_int p.left +. half -. (fw /. 2.))
               ((fh /. 2.) -. float_of_int p.top -. half))
  in
  (P.rectangle (P.rgb 200 200 200) fw fh
  :: List.filter_map tile (Tiles.in_view m.z m.cx m.cy w h))
  @ band fw fh false (if m.said = "" then where m else m.said)
  @ band fw fh true credit

(* the same list while nothing it shows changed: a window at rest costs no
 * drawing (the same as mini-netscape's) *)
let last : ((int * int * int * int * int * int * string) * P.shape list) option ref = ref None

let view (computer : P.computer) (m : model) : P.shape list =
  let w = int_of_float computer.screen.width and h = int_of_float computer.screen.height in
  let now = (w, h, m.z, m.cx, m.cy, m.generation, m.said) in
  match !last with
  | Some (was, shapes) when was = now -> shapes
  | _ ->
      let shapes = drawn w h m in
      last := Some (now, shapes);
      shapes

(*****************************************************************************)
(* Entry point *)
(*****************************************************************************)

(* cache=DIR, or the user's; cache=off, none *)
let cache_dir (caps : caps) (flags : P.flags) : string option =
  let env (name : string) : string option =
    match CapSys.getenv caps name with "" -> None | v -> Some v | exception Not_found -> None
  in
  match (List.assoc_opt "cache" flags, env "XDG_CACHE_HOME", env "HOME", env "home") with
  | Some "off", _, _, _ -> None
  | Some dir, _, _, _ -> Some dir
  | None, Some cache, _, _ -> Some (Filename.concat cache "mini-maps")
  | None, None, Some home, _ | None, None, None, Some home -> Some (Filename.concat (Filename.concat home ".cache") "mini-maps")
  | None, None, None, None -> None

let initial (caps : caps) (flags : P.flags) : model =
  let number (name : string) : float option = Option.bind (List.assoc_opt name flags) float_of_string_opt in
  let z =
    match List.assoc_opt "zoom" flags with
    | Some s -> max 0 (min Tiles.max_zoom (int_of_string s))
    | None -> if number "lat" = None then 1 else 12
  in
  let at (name : string) : float = match number name with Some v -> v | None -> 0. in
  let cx, cy = (Mercator.x_of_longitude z (at "lon"), Mercator.y_of_latitude z (at "lat")) in
  if List.assoc_opt "worker" flags = Some "wait" then Tile_worker.mode := Tile_worker.Waited;
  let base = match List.assoc_opt "tiles" flags with Some b -> b | None -> default_tiles in
  let limit =
    match Option.bind (List.assoc_opt "cache-size" flags) int_of_string_opt with
    | Some megabytes -> megabytes * 1_000_000
    | None -> default_cache_megabytes * 1_000_000
  in
  let cache = Option.bind (cache_dir caps flags) (fun (dir : string) -> Tile_cache.create caps ~dir ~limit) in
  Tile_worker.start (fetch caps base cache);
  { z; cx; cy; grab = None; wheel = 0.; store = Hashtbl.create 200; failed = Hashtbl.create 20; ticks = 0; generation = 0; said = "" }
