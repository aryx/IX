(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* The screen and the input devices, a record of functions at the edge
 * (plan_pi.md, decision 9): the board's framebuffer shown, the keys
 * pressed and the mouse moved in the window read back. SDL's (Sdl_display, the executable's
 * one module linking a C library), or none (-nographic, the tests: a
 * QMP screendump writes the framebuffer as PPM). *)

type event =
  | Key of int * bool              (* a HID usage, down *)
  | Motion of int * int            (* the mouse moved, relative *)
  | Button of int * bool           (* a mouse button (1 left, 2 right, 4 middle), down *)
  | Wheel of int                   (* -1 up *)
  | Quit

type t = {
  present : Framebuffer.geometry -> string -> unit;   (* the pixels as the kernel wrote them *)
  poll : unit -> event list;
}

let none = { present = (fun _ _ -> ()); poll = (fun () -> []) }
