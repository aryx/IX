(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Tile_worker.mli *)

type mode = Beside | Waited

let mode : mode ref = ref Beside
let lock = Mutex.create ()
let signal = Condition.create ()
let wanted : Tiles.key list ref = ref []
let fetching : Tiles.key option ref = ref None
let made : (Tiles.key * (Rgba_image.t, string) result) list ref = ref []

let worker (fetch : Tiles.key -> (Rgba_image.t, string) result) () : unit =
  while true do
    Mutex.lock lock;
    while !wanted = [] do Condition.wait signal lock done;
    let key = List.hd !wanted in
    wanted := List.tl !wanted;
    fetching := Some key;
    Mutex.unlock lock;
    let r = try fetch key with Failure why -> Error why in
    Mutex.lock lock;
    fetching := None;
    made := (key, r) :: !made;
    Condition.broadcast signal;
    Mutex.unlock lock;
    (* (mini-ml's threads: the window's turn, between two tiles) *)
    Thread.yield ()
  done

let start (fetch : Tiles.key -> (Rgba_image.t, string) result) : unit =
  Worker_spawn.spawn (worker fetch)

let want (keys : Tiles.key list) : unit =
  Mutex.lock lock;
  (* (Waited: one a frame, so a frame's tiles are known) *)
  let busy = !fetching <> None || !made <> [] in
  let asked = List.filter (fun (k : Tiles.key) -> Some k <> !fetching) keys in
  wanted :=
    (match (!mode, asked) with
    | Beside, _ -> asked
    | Waited, k :: _ when not busy -> [ k ]
    | Waited, _ -> []);
  if !wanted <> [] then Condition.broadcast signal;
  Mutex.unlock lock

let take () : (Tiles.key * (Rgba_image.t, string) result) list =
  Mutex.lock lock;
  if !mode = Waited then
    while !wanted <> [] || !fetching <> None do Condition.wait signal lock done;
  let r = List.rev !made in
  made := [];
  Mutex.unlock lock;
  r

let out () : bool =
  Mutex.lock lock;
  let r = !wanted <> [] || !fetching <> None || !made <> [] in
  Mutex.unlock lock;
  r
