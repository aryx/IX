(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Tab_worker.mli *)

type working = Beside | Waited | Inline

let working : working ref = ref Beside
let lock = Mutex.create ()
let signal = Condition.create ()
let given : (int * Tab.t) option ref = ref None
let made : (int * (Tab.t, exn) result) option ref = ref None
let pieces = ref 0 (* given so far: a piece's number *)
let given_out = ref false
let started = ref false

let worker (caps : < Cap.network; Cap.open_in; .. >) () : unit =
  while true do
    Mutex.lock lock;
    while !given = None do Condition.wait signal lock done;
    let n, tab = Option.get !given in
    given := None;
    Mutex.unlock lock;
    let r = try Ok (Tab.step caps tab) with e -> Error e in
    Mutex.lock lock;
    made := Some (n, r);
    Condition.broadcast signal;
    Mutex.unlock lock
  done

let give (caps : < Cap.network; Cap.open_in; .. >) (tab : Tab.t) : int =
  if not !started then (started := true; Worker_spawn.spawn (worker caps));
  incr pieces;
  given_out := true;
  Mutex.lock lock;
  given := Some (!pieces, tab);
  Condition.broadcast signal;
  Mutex.unlock lock;
  !pieces

let out () : bool = !given_out

let take () : (int * (Tab.t, exn) result) option =
  Mutex.lock lock;
  if !working = Waited && !given_out then while !made = None do Condition.wait signal lock done;
  let r = !made in
  made := None;
  Mutex.unlock lock;
  (match r with Some _ -> given_out := false | None -> ());
  r
