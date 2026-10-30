(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Map_worker.mli *)

type mode = Beside | Waited

let mode : mode ref = ref Beside
let lock = Mutex.create ()
let signal = Condition.create ()
let wanted : Tiles.key list ref = ref []
let jobs : (unit -> unit) list ref = ref []
let fetching : Tiles.key option ref = ref None
let running = ref false
let made : (Tiles.key * (Rgba_image.t, string) result) list ref = ref []

let worker (fetch : Tiles.key -> (Rgba_image.t, string) result) () : unit =
  while true do
    Mutex.lock lock;
    while !wanted = [] && !jobs = [] do Condition.wait signal lock done;
    (match !jobs with
    | job :: rest ->
        jobs := rest;
        running := true;
        Mutex.unlock lock;
        (* (what the job says of its own failure is in its result) *)
        (try job () with _ -> ());
        Mutex.lock lock;
        running := false
    | [] ->
        let key = List.hd !wanted in
        wanted := List.tl !wanted;
        fetching := Some key;
        Mutex.unlock lock;
        let r = try fetch key with e -> Error (Printexc.to_string e) in
        Mutex.lock lock;
        fetching := None;
        made := (key, r) :: !made);
    Condition.broadcast signal;
    Mutex.unlock lock;
    (* (mini-ml's threads: the window's turn, between two pieces) *)
    Thread.yield ()
  done

let start (fetch : Tiles.key -> (Rgba_image.t, string) result) : unit =
  Worker_spawn.spawn (worker fetch)

let want (keys : Tiles.key list) : unit =
  Mutex.lock lock;
  (* (Waited: one a frame, so a frame's tiles are known) *)
  let busy = !fetching <> None || !made <> [] || !running || !jobs <> [] in
  let asked = List.filter (fun (k : Tiles.key) -> Some k <> !fetching) keys in
  wanted :=
    (match (!mode, asked) with
    | Beside, _ -> asked
    | Waited, k :: _ when not busy -> [ k ]
    | Waited, _ -> []);
  if !wanted <> [] then Condition.broadcast signal;
  Mutex.unlock lock

let job (f : unit -> unit) : unit =
  Mutex.lock lock;
  jobs := !jobs @ [ f ];
  Condition.broadcast signal;
  Mutex.unlock lock

let pending () : bool = !wanted <> [] || !fetching <> None || !running || !jobs <> []

let take () : (Tiles.key * (Rgba_image.t, string) result) list =
  Mutex.lock lock;
  if !mode = Waited then while pending () do Condition.wait signal lock done;
  let r = List.rev !made in
  made := [];
  Mutex.unlock lock;
  r

let out () : bool =
  Mutex.lock lock;
  let r = pending () || !made <> [] in
  Mutex.unlock lock;
  r
