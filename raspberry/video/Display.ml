(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* The screen and the input devices are a record of functions at the
 * edge (plan_pi.md, decision 9). It shows the board's framebuffer, and
 * reads back the keys pressed and the mouse moved in the window. The
 * display is SDL's (Sdl_display, the executable's one module that
 * links a C library), or none (with -nographic, and in the tests, a
 * QMP screendump writes the framebuffer as PPM). *)

type event =
  | Key of int * bool              (* a HID usage, down *)
  | Motion of int * int            (* the mouse moved, relative *)
  | At of int * int                (* the mouse's place in the window, when it is not grabbed (tiny-machine's) *)
  | Button of int * bool           (* a mouse button (1 left, 2 right, 4 middle), down *)
  | Wheel of int                   (* -1 up *)
  | Quit

(* a strip under the screen and a line for the window's title
 * (Monitor's): [rows] of the screen's width, three bytes a pixel;
 * [stamp] another number when they have changed *)
type meter = { stamp : int; text : string; rows : int; pixels : string }

type t = {
  present : Framebuffer.geometry -> string -> unit;   (* the pixels as the kernel wrote them *)
  poll : unit -> event list;
}

let none = { present = (fun _ _ -> ()); poll = (fun () -> []) }
