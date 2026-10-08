(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Source.mli: OCaml's threads (a read waits alone: the others run) *)

let reader (_ : < Cap.fork; .. >) fd n =
  let ch = Event.new_channel () and buf = Bytes.create (min n 4000) in
  let rec loop () =
    let k = try Unix.read fd buf 0 (Bytes.length buf) with Unix.Unix_error _ -> 0 in
    Event.sync (Event.send ch (Bytes.sub buf 0 k));
    if k > 0 then loop () in
  ignore (Thread.create loop ());
  ch

let alarm (_ : < Cap.fork; .. >) =
  let ch = Event.new_channel () and asked = Event.new_channel () in
  let rec loop () = Unix.sleepf (Event.sync (Event.receive asked)); Event.sync (Event.send ch ()); loop () in
  ignore (Thread.create loop ());
  ((fun d -> Event.sync (Event.send asked d)), ch)

let timer (_ : < Cap.fork; .. >) d =
  let ch = Event.new_channel () in
  let rec loop () = Unix.sleepf d; Event.sync (Event.send ch ()); loop () in
  ignore (Thread.create loop ());
  ch
