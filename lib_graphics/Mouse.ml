(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Mouse.mli *)

type state = { pos : Point.t; buttons : int; msec : int }

type t = { reads : bytes Event.channel }

(* a read of /dev/mouse: a letter (m, or r when the screen's size
 * changed) and four numbers of 12 characters: x, y, the buttons, the
 * time in milliseconds *)
let init (caps : < Cap.mouse; Cap.fork; .. >) =
  { reads = Source.reader caps (Unix.openfile "/dev/mouse" [ Unix.O_RDONLY ] 0) 49 }

let state_of (b : bytes) =
  let num k = try int_of_string (String.trim (Bytes.sub_string b (1 + (12 * k)) 12)) with _ -> 0 in
  if Bytes.length b < 49 then { pos = Point.zero; buttons = 0; msec = 0 }
  else { pos = Point.v (num 0) (num 1); buttons = num 2; msec = num 3 }

let receive (m : t) = Event.wrap (Event.receive m.reads) state_of
