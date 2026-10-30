(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Place.mli *)

type t = { name : string; lat : float; lon : float; box : (float * float * float * float) option }

let search_url (base : string) (query : string) : string =
  Printf.sprintf "%s/search?%s" base
    (Urlencoded.encode [ ("q", query); ("format", "jsonv2"); ("limit", "1") ])

let number (v : Json.t) : float =
  match v with
  | Json.String s -> (
      match float_of_string_opt s with Some f -> f | None -> failwith ("not a number: " ^ s))
  | _ -> Json.float v

let of_json (text : string) : t list =
  let place (j : Json.t) : t =
    let box =
      match Json.member "boundingbox" j with
      | Json.List [ s; n; w; e ] -> Some (number s, number n, number w, number e)
      | _ -> None
    in
    { name = Json.string (Json.member "display_name" j);
      lat = number (Json.member "lat" j);
      lon = number (Json.member "lon" j);
      box }
  in
  match Json.of_text text with
  | exception Json.Error why -> failwith why
  | j -> ( try List.map place (Json.list j) with Json.Error why -> failwith why)

let zoom_for ~(at_most : int) (p : t) (w : int) (h : int) : int =
  match p.box with
  | None -> at_most
  | Some (south, north, west, east) ->
      let fits (z : int) : bool =
        Mercator.x_of_longitude z east - Mercator.x_of_longitude z west <= w
        && Mercator.y_of_latitude z south - Mercator.y_of_latitude z north <= h
      in
      let rec highest (z : int) : int = if z <= 0 || fits z then z else highest (z - 1) in
      highest at_most

let to_line ((query, p) : string * t) : string =
  let box =
    match p.box with
    | Some (s, n, w, e) -> Printf.sprintf "%g %g %g %g" s n w e
    | None -> ""
  in
  String.concat "\t" [ query; Printf.sprintf "%.6f" p.lat; Printf.sprintf "%.6f" p.lon; box; p.name ]

let of_line (line : string) : (string * t) option =
  match String.split_on_char '\t' line with
  | [ query; lat; lon; box; name ] -> (
      match (float_of_string_opt lat, float_of_string_opt lon) with
      | Some lat, Some lon ->
          let box =
            match List.map float_of_string_opt (String.split_on_char ' ' box) with
            | [ Some s; Some n; Some w; Some e ] -> Some (s, n, w, e)
            | _ -> None
          in
          Some (query, { name; lat; lon; box })
      | _ -> None)
  | _ -> None

let normal (query : string) : string = String.lowercase_ascii (String.trim query)
