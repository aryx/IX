(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Roads.mli *)

type t = {
  lat : float array;
  lon : float array;
  x : float array;
  y : float array;
  shrink : float;
  first : int array;
  origin : int array;
  target : int array;
  millis : int array;
  metres : int array;
  name : int array;
  names : string array;
  linked : bool array;
  top_speed : float;
}

let max_side = 0.5
let all_roads_side = 0.1

(* km/h, by what the road says it is; the list is also what is asked for *)
let speeds : (string * float) list =
  [ ("motorway", 110.); ("trunk", 90.); ("primary", 70.); ("secondary", 60.);
    ("tertiary", 50.); ("unclassified", 40.); ("residential", 30.);
    ("living_street", 10.); ("motorway_link", 60.); ("trunk_link", 50.);
    ("primary_link", 40.); ("secondary_link", 40.); ("tertiary_link", 30.) ]

let minor = [ "residential"; "living_street" ]

let all_roads ((s, w, n, e) : float * float * float * float) : bool =
  n -. s <= all_roads_side && e -. w <= all_roads_side

let url (base : string) ((s, w, n, e) as box : float * float * float * float) : string =
  let wanted (c : string) : bool = all_roads box || not (List.mem c minor) in
  let classes = String.concat "|" (List.filter wanted (List.map fst speeds)) in
  let query =
    Printf.sprintf
      "[out:json][timeout:60];way[\"highway\"~\"^(%s)$\"]\
       [\"access\"!~\"^(private|no)$\"](%.3f,%.3f,%.3f,%.3f);\
       out body;>;out skel qt;"
      classes s w n e
  in
  Printf.sprintf "%s/api/interpreter?%s" base (Urlencoded.encode [ ("data", query) ])

let metres_a_degree = 111_195.

(* the way's directions: forward, backward *)
let directions (highway : string) (tag : string -> string) : bool * bool =
  match tag "oneway" with
  | "yes" | "true" | "1" -> (true, false)
  | "-1" | "reverse" -> (false, true)
  | "no" -> (true, true)
  | _ ->
      if tag "junction" = "roundabout" || highway = "motorway"
      then (true, false)
      else (true, true)

(* union-find, by halving; the largest piece's nodes *)
let largest_piece (nodes : int) (origin : int array) (target : int array) : bool array =
  let parent = Array.init nodes (fun (i : int) -> i) in
  let rec root (i : int) : int =
    let p = parent.(i) in
    if p = i then i
    else begin
      parent.(i) <- parent.(p);
      root parent.(i)
    end
  in
  Array.iteri (fun (e : int) (a : int) -> parent.(root a) <- root target.(e)) origin;
  let count = Array.make nodes 0 in
  for i = 0 to nodes - 1 do
    let r = root i in
    count.(r) <- count.(r) + 1
  done;
  let best = ref 0 in
  Array.iteri (fun (i : int) (c : int) -> if c > count.(!best) then best := i) count;
  Array.init nodes (fun (i : int) -> nodes > 0 && root i = !best)

let of_json (text : string) : t =
  let elements =
    try Json.list (Json.member "elements" (Json.of_text text))
    with Json.Error why -> failwith why
  in
  let kind (e : Json.t) : string = Json.string (Json.member "type" e) in
  try
    let nodes = List.filter (fun (e : Json.t) -> kind e = "node") elements in
    let ways = List.filter (fun (e : Json.t) -> kind e = "way") elements in
    let lat = Array.of_list (List.map (fun (e : Json.t) -> Json.float (Json.member "lat" e)) nodes) in
    let lon = Array.of_list (List.map (fun (e : Json.t) -> Json.float (Json.member "lon" e)) nodes) in
    let count = Array.length lat in
    (* (an id is a float: past 2^31, more than a 32-bit int) *)
    let index : (float, int) Hashtbl.t = Hashtbl.create (2 * count + 1) in
    List.iteri
      (fun (i : int) (e : Json.t) -> Hashtbl.replace index (Json.float (Json.member "id" e)) i)
      nodes;
    let middle =
      if count = 0 then 0. else (Array.fold_left (+.) 0. lat /. float_of_int count)
    in
    let shrink = cos (middle *. Float.pi /. 180.) in
    let x = Array.map (fun (l : float) -> l *. shrink *. metres_a_degree) lon in
    let y = Array.map (fun (l : float) -> l *. metres_a_degree) lat in
    let named : (string, int) Hashtbl.t = Hashtbl.create 1000 in
    let names = ref [] in
    let name_of (s : string) : int =
      match Hashtbl.find_opt named s with
      | Some i -> i
      | None ->
          let i = Hashtbl.length named in
          Hashtbl.replace named s i;
          names := s :: !names;
          i
    in
    (* the edges, as (from, to, millis, metres, name); those of a node
     * missing from the answer left out *)
    let top = ref 1. in
    let edges = ref [] in
    let edge (speed : float) (name : int) (a : int) (b : int) : unit =
      let dx = x.(a) -. x.(b) and dy = y.(a) -. y.(b) in
      let m = sqrt ((dx *. dx) +. (dy *. dy)) in
      let ms = int_of_float (ceil (m /. speed *. 1000.)) in
      edges := (a, b, ms, int_of_float (ceil m), name) :: !edges
    in
    List.iter
      (fun (w : Json.t) ->
        let tags = Json.member "tags" w in
        let tag (k : string) : string =
          match tags with
          | Json.Assoc _ -> (
              match Json.member k tags with Json.String s -> s | _ -> "")
          | _ -> ""
        in
        let highway = tag "highway" in
        match List.assoc_opt highway speeds with
        | None -> ()
        | Some kmh ->
            let speed = kmh /. 3.6 in
            if speed > !top then top := speed;
            let name = name_of (tag "name") in
            let forward, backward = directions highway tag in
            let rec steps (l : Json.t list) : unit =
              match l with
              | a :: (b :: _ as rest) ->
                  (match
                     ( Hashtbl.find_opt index (Json.float a),
                       Hashtbl.find_opt index (Json.float b) )
                   with
                  | Some a, Some b ->
                      if forward then edge speed name a b;
                      if backward then edge speed name b a
                  | _ -> ());
                  steps rest
              | _ -> ()
            in
            steps (Json.list (Json.member "nodes" w)))
      ways;
    (* by origin: a node's edges together *)
    let all = Array.of_list !edges in
    let total = Array.length all in
    let first = Array.make (count + 1) 0 in
    Array.iter
      (fun ((a, _, _, _, _) : int * int * int * int * int) ->
        first.(a + 1) <- first.(a + 1) + 1)
      all;
    for i = 1 to count do
      first.(i) <- first.(i) + first.(i - 1)
    done;
    let next = Array.sub first 0 (count + 1) in
    let origin = Array.make total 0 and target = Array.make total 0 in
    let millis = Array.make total 0 and metres = Array.make total 0 in
    let name = Array.make total 0 in
    Array.iter
      (fun ((a, b, ms, m, n) : int * int * int * int * int) ->
        let e = next.(a) in
        next.(a) <- e + 1;
        origin.(e) <- a;
        target.(e) <- b;
        millis.(e) <- ms;
        metres.(e) <- m;
        name.(e) <- n)
      all;
    { lat; lon; x; y; shrink; first; origin; target; millis; metres; name;
      names = Array.of_list (List.rev !names);
      linked = largest_piece count origin target;
      top_speed = !top }
  with Json.Error why -> failwith why

let nearest (g : t) (lat : float) (lon : float) : (int * float) option =
  if Array.length g.lat = 0 then None
  else begin
    let px = lon *. g.shrink *. metres_a_degree and py = lat *. metres_a_degree in
    let best = ref (-1) and far = ref infinity in
    Array.iteri
      (fun (i : int) (on : bool) ->
        if on then begin
          let dx = g.x.(i) -. px and dy = g.y.(i) -. py in
          let d = (dx *. dx) +. (dy *. dy) in
          if d < !far then begin
            far := d;
            best := i
          end
        end)
      g.linked;
    if !best < 0 then None else Some (!best, sqrt !far)
  end
