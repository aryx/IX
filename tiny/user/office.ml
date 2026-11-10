(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* office, a program of TinyKernel.ml's: ../TinyOffice.ml, the page,
 * run by ../TinyLibGUI.ml's run_canvas.
 *
 *     office file
 *
 * run_canvas does the rest: the window's size, the keys and the mouse,
 * the raw console (C-x C-c), the page drawn where it changed. What is
 * here: the page of the file at the window's size, a key and the mouse
 * given to it, a save done when either asks. The file is the kernel's: on
 * its disk when it has one, else in its memory (put keeps a copy). OCaml
 * compiles it too, for the host (tiny-office, sdl/): its system
 * TinyLibSystem's, a window's (the office opened last, its key and mouse
 * over the GUI's). *)
module TSys = TinyLibSystem
open TinyLibGUI
open TinyOffice

let () =
  TSys.main "office" (fun caps argv ->
    if Array.length argv <> 2 then begin
      TSys.eprint caps "usage: office file\n";
      Exit.Code 1
    end
    else
      let file = argv.(1) in
        let path = Fpath.v file in
        let text0 = try TSys.read_file caps path with Failure _ -> "" in
        let answer o r =
          match r with
          | Continue -> Some o
          | Save ->
            (try TSys.write_file caps path (text o); saved o
             with Failure _ -> say o ("Cannot write " ^ file));
            Some o
          | Quit -> None in
        run_canvas caps {
          first = (fun w h -> create w h path text0);
          picture = view;
          typed = (fun k o -> answer o (key o k));
          moved = (fun x y b o -> answer o (mouse o x y b)) };
        Exit.OK)
