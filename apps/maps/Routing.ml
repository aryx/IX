(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Routing.mli *)

module P = Playground

type t = {
  from : string;
  goal : string;
  points : (float * float) array;
  millis : int;
  metres : int;
  settled : int;
  nodes : int;
  steps : (string * int) list;
}

type box = float * float * float * float

let kept_for = 30. *. 86400.

(* a road further than this from a place is not its road: a click at sea *)
let road_at_most = 2000.

(*****************************************************************************)
(* The extract *)
(*****************************************************************************)

let in_box ((s, w, n, e) : box) (p : Place.t) : bool =
  p.lat >= s && p.lat <= n && p.lon >= w && p.lon <= e

(* around both places: a route may leave the straight line *)
let box_of (a : Place.t) (b : Place.t) : box =
  let margin (d : float) : float = Float.max 0.02 (d *. 0.15) in
  let dlat = margin (Float.abs (a.lat -. b.lat)) in
  let dlon = margin (Float.abs (a.lon -. b.lon)) in
  ( Float.min a.lat b.lat -. dlat, Float.min a.lon b.lon -. dlon,
    Float.max a.lat b.lat +. dlat, Float.max a.lon b.lon +. dlon )

let too_big ((s, w, n, e) : box) : bool =
  n -. s > Roads.max_side || e -. w > Roads.max_side

let header ((s, w, n, e) : box) (now : float) : string =
  Printf.sprintf "%.3f %.3f %.3f %.3f %.0f\n" s w n e now

(* the file's box and answer, if it holds a recent one *)
let read_kept (caps : < Cap.open_in; .. >) (now : float) (file : Fpath.t) : (box * string) option =
  match FS.read_opt caps file with
  | None -> None
  | Some text -> (
      match String.index_opt text '\n' with
      | None -> None
      | Some i -> (
          let first = String.sub text 0 i in
          let rest = String.sub text (i + 1) (String.length text - i - 1) in
          match List.map float_of_string_opt (String.split_on_char ' ' first) with
          | [ Some s; Some w; Some n; Some e; Some at ] when now -. at < kept_for ->
              Some ((s, w, n, e), rest)
          | _ -> None))

(* the graph of the last extract, in memory *)
let last : (box * Roads.t) option ref = ref None

(* Overpass is silent until it has it all, for most of a minute at times *)
let asked (caps : < Cap.network; Cap.open_in; .. >) (url : string) : (Http.response, string) result =
  let usual = !Tcp.timeout in
  Tcp.timeout := 90.;
  let r = Map_http.get caps ~more:[] url in
  Tcp.timeout := usual;
  r

(* the graph for those two places: from memory, from the file, or asked *)
let graph (caps : < Cap.network; Cap.open_in; Cap.open_out; .. >) ~(base : string)
    ~(dir : string option) (a : Place.t) (b : Place.t) : (Roads.t, string) result =
  (* (a town's route is not made over an extract without its streets) *)
  let covers (box : box) : bool =
    in_box box a && in_box box b && Roads.all_roads box = Roads.all_roads (box_of a b)
  in
  let now = Unix.gettimeofday () in
  let file = Option.map (fun (d : string) -> Fpath.v (Filename.concat d "roads")) dir in
  let made (box : box) (text : string) : (Roads.t, string) result =
    match Roads.of_json text with
    | g ->
        last := Some (box, g);
        Ok g
    | exception Failure why -> Error why
  in
  match !last with
  | Some (box, g) when covers box -> Ok g
  | _ -> (
      match Option.bind file (read_kept caps now) with
      | Some (box, text) when covers box -> made box text
      | _ ->
          let box = box_of a b in
          if too_big box then
            Error
              (Printf.sprintf "too far for a small extract: %g degrees at most"
                 Roads.max_side)
          else (
            match asked caps (Roads.url base box) with
            | Error why -> Error why
            | Ok r when r.status <> 200 ->
                Error (Printf.sprintf "%d %s" r.status r.reason)
            | Ok r ->
                let result = made box r.body in
                (* (only what was understood is kept) *)
                (match (result, file) with
                | Ok _, Some f -> (
                    try FS.write caps f (header box now ^ r.body)
                    with Sys_error _ | Unix.Unix_error _ -> ())
                | _ -> ());
                result))

(*****************************************************************************)
(* The route *)
(*****************************************************************************)

(* consecutive edges of one road as one step *)
let steps_of (g : Roads.t) (edges : int list) : (string * int) list =
  let add (acc : (string * int) list) (e : int) : (string * int) list =
    let name = g.names.(g.name.(e)) in
    match acc with
    | (n, m) :: rest when n = name -> (n, m + g.metres.(e)) :: rest
    | _ -> (name, g.metres.(e)) :: acc
  in
  List.rev (List.fold_left add [] edges)

let find (caps : < Cap.network; Cap.open_in; Cap.open_out; .. >) ~(base : string)
    ~(dir : string option) ~(dijkstra : bool) (a : Place.t) (b : Place.t) : (t * int option, string) result =
  (* (it runs in the worker, which must outlive a thing too large for this
   * machine: an answer past a 32-bit string's 16 MB) *)
  match
    try graph caps ~base ~dir a b with
    | Failure why | Invalid_argument why -> Error why
    | Out_of_memory | Stack_overflow -> Error "too large for this machine"
  with
  | Error why -> Error why
  | Ok g -> (
      let near (p : Place.t) : (int, string) result =
        match Roads.nearest g p.lat p.lon with
        | Some (n, far) when far <= road_at_most -> Ok n
        | _ -> Error (Printf.sprintf "no road near %s" p.name)
      in
      match (near a, near b) with
      | Error why, _ | _, Error why -> Error why
      | Ok na, Ok nb -> (
          match Route.search g ~guess:true na nb with
          | None -> Error "no way between them by the roads known"
          | Some r ->
              let point (n : int) : float * float = (g.lat.(n), g.lon.(n)) in
              let points = point na :: List.map (fun (e : int) -> point g.target.(e)) r.edges in
              let plain =
                if not dijkstra then None
                else
                  Option.map (fun (d : Route.t) -> d.settled)
                    (Route.search g ~guess:false na nb)
              in
              Ok
                ( { from = a.name; goal = b.name; points = Array.of_list points;
                    millis = r.millis; metres = r.metres; settled = r.settled;
                    nodes = Array.length g.lat; steps = steps_of g r.edges },
                  plain )))

(*****************************************************************************)
(* In words *)
(*****************************************************************************)

let length_words (metres : int) : string =
  if metres < 1000 then Printf.sprintf "%d m" metres
  else Printf.sprintf "%d.%d km" (metres / 1000) (metres mod 1000 / 100)

let time_words (millis : int) : string =
  let minutes = (millis + 30_000) / 60_000 in
  if minutes < 60 then Printf.sprintf "%d min" minutes
  else Printf.sprintf "%d h %02d" (minutes / 60) (minutes mod 60)

let summary (r : t) : string =
  Printf.sprintf "%s, %s" (length_words r.metres) (time_words r.millis)

let lines (r : t) (plain : int option) : string list =
  let road ((name, metres) : string * int) : string =
    Printf.sprintf "%8s  %s" (length_words metres)
      (if name = "" then "(a road with no name)" else name)
  in
  [ r.from; "to " ^ r.goal; summary r ]
  @ List.map road r.steps
  @ [ Printf.sprintf "A* settled %d nodes of %d" r.settled r.nodes ]
  @ (match plain with
    | Some n -> [ Printf.sprintf "Dijkstra settled %d" n ]
    | None -> [])
  @ [ "times by road class: no traffic, no turn restrictions";
      "Roads (c) OpenStreetMap contributors, ODbL" ]

(*****************************************************************************)
(* On the map *)
(*****************************************************************************)

let width = 2.

let shapes (r : t) ~(z : int) ~(cx : int) ~(cy : int) (fw : float) (fh : float) : P.shape list =
  let color = P.rgb 40 90 220 in
  let pixel ((lat, lon) : float * float) : int * int =
    (Mercator.x_of_longitude z lon - cx, Mercator.y_of_latitude z lat - cy)
  in
  let on_window (x : int) (y : int) : bool =
    Float.abs (float_of_int x) <= fw && Float.abs (float_of_int y) <= fh
  in
  (* a segment as a quadrilateral across it *)
  let segment ((ax, ay) : int * int) ((bx, by) : int * int) : P.shape =
    let x0 = float_of_int ax and y0 = -.float_of_int ay in
    let x1 = float_of_int bx and y1 = -.float_of_int by in
    let dx = x1 -. x0 and dy = y1 -. y0 in
    let len = sqrt ((dx *. dx) +. (dy *. dy)) in
    let nx = -.dy /. len *. width and ny = dx /. len *. width in
    P.polygon color
      [ (x0 +. nx, y0 +. ny); (x1 +. nx, y1 +. ny); (x1 -. nx, y1 -. ny); (x0 -. nx, y0 -. ny) ]
  in
  let close ((ax, ay) : int * int) ((bx, by) : int * int) : bool =
    abs (ax - bx) < 3 && abs (ay - by) < 3
  in
  let drawn = ref [] in
  let at = ref (pixel r.points.(0)) in
  Array.iter
    (fun (p : float * float) ->
      let next = pixel p in
      if not (close !at next) then begin
        let ax, ay = !at and bx, by = next in
        if on_window ax ay || on_window bx by then drawn := segment !at next :: !drawn;
        at := next
      end)
    r.points;
  !drawn
