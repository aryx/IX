(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* emacs, a program of TinyKernel.ml's: ../../TinyEditorScreen.ml, the
 * editor, run by ../../TinyLibGUI.ml's run_canvas (given to tiny-ml
 * before this file, as one program: the Makefile).
 *
 *     emacs file
 *
 * run_canvas does the rest: the window's size, the keys and the mouse,
 * the raw console (C-x C-c), the screen drawn where it changed. What
 * is here: the editor of the file on a screen of the window's size,
 * its picture (a white ground, its lines), and a key given to it with
 * those it gives itself (a macro's, M-x's), a save done when it asks.
 * The file is the kernel's, in its memory: put keeps it. OCaml compiles
 * it too, for the host (tiny-emacs, ../../sdl/): its calls TinyCalls's,
 * a window's (the editor opened last, its key and view over the GUI's). *)
open TinyCalls
open TinyLibPlayground
open TinyLibGUI
open TinyEditorScreen

let () =
  if u_argc () <> 2 then (ignore (u_write 2 "usage: emacs file\n"); exit 1);
  let file = u_arg 1 in
  let answer e r =
    match r with
    | Continue -> true
    | Save -> (if write_file file (text e) then saved e else say e ("Cannot write " ^ file)); true
    | Quit -> false in
  let rec given e r = answer e r && (match pending e with Some k -> given e (key e k) | None -> true) in
  run_canvas {
    first = (fun w h -> (create (w / 8) (h / 16) file (read_file file), w, h));
    picture = (fun (e, w, h) -> Rect (255, w, h) :: shapes e (h / 16));
    typed = (fun k m -> let (e, _, _) = m in if given e (key e k) then Some m else None);
    moved = (fun _ _ _ m -> Some m) };
  exit 0
