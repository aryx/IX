(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Input.mli *)

let left = 4
let middle = 2
let right = 1

let x = ref (Display.width / 2)
let y = ref (Display.height / 2)
let keys = ref 0
let queue : char Queue.t = Queue.create ()

let poll = ref (fun () -> ())
let mouse () = !poll (); !keys, !x, !y
let available () = Queue.length queue
let read () = Queue.pop queue

let moved dx dy buttons =
  x := max 0 (min (Display.width - 1) (!x + dx));
  y := max 0 (min (Display.height - 1) (!y - dy));
  keys := (if buttons land 1 <> 0 then left else 0) lor (if buttons land 4 <> 0 then middle else 0) lor (if buttons land 2 <> 0 then right else 0)

let typed c = Queue.push c queue
