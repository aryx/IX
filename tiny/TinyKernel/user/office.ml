(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* office, a program of TinyKernel.ml's: ../../TinyOffice.ml, the page,
 * run by ../../TinyLibGUI.ml's run_canvas (given to tiny-ml before this
 * file, as one program: the Makefile).
 *
 *     office file
 *
 * run_canvas does the rest: the window's size, the keys and the mouse,
 * the raw console (C-x C-c), the page drawn where it changed. What is
 * here: the page of the file at the window's size, a key and the mouse
 * given to it, a save done when either asks. The file is the kernel's, in
 * its memory: put keeps it. Not OCaml's to compile: it names the
 * kernel's calls. *)
open TinyOffice
open TinyLibGUI

let () =
  if u_argc () <> 2 then (ignore (u_write 2 "usage: office file\n"); exit 1);
  let file = u_arg 1 in
  let answer o r =
    match r with
    | Continue -> Some o
    | Save -> (if write_file file (text o) then saved o else say o ("Cannot write " ^ file)); Some o
    | Quit -> None in
  run_canvas {
    first = (fun w h -> create w h file (read_file file));
    picture = view;
    typed = (fun k o -> answer o (key o k));
    moved = (fun x y b o -> answer o (mouse o x y b)) };
  exit 0
