(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* emacs, a program of TinyKernel.ml's: ../TinyEditorScreen.ml, the
 * editor, run by ../TinyLibGUI.ml's run_canvas.
 *
 *     emacs file
 *
 * run_canvas does the rest: the window's size, the keys and the mouse,
 * the raw console (C-x C-c), the screen drawn where it changed. What
 * is here: the editor of the file on a screen of the window's size,
 * its picture (a white ground, its lines), and a key given to it with
 * those it gives itself (a macro's, M-x's), a save done when it asks.
 * The file is the kernel's: on its disk when it has one, else in its
 * memory (put keeps a copy). OCaml compiles it too, for the host
 * (tiny-emacs, sdl/): its system TinyLibSystem's, a window's (the
 * editor opened last, its key and view over the GUI's). *)
module TSys = TinyLibSystem
open TinyLibPlayground
open TinyLibGUI
open TinyEditorScreen

let () =
  TSys.main "emacs" (fun caps argv ->
    if Array.length argv <> 2 then begin
      TSys.eprint caps "usage: emacs file\n";
      Exit.Code 1
    end
    else
      let file = argv.(1) in
        let path = Fpath.v file in
        (* (a new file's text "", and a save that cannot be done said in
         * the editor: TSys's Failures caught) *)
        let text0 = try TSys.read_file caps path with Failure _ -> "" in
        let answer e r =
          match r with
          | Continue -> true
          | Save ->
            (try TSys.write_file caps path (text e); saved e
             with Failure _ -> say e ("Cannot write " ^ file));
            true
          | Quit -> false in
        let rec given e r =
          answer e r
          && (match pending e with Some k -> given e (key e k) | None -> true)
        in
        run_canvas caps {
          first = (fun w h -> (create (w / 8) (h / 16) path text0, w, h));
          picture = (fun (e, w, h) -> Rect (255, w, h) :: shapes e (h / 16));
          typed =
            (fun k m ->
              let (e, _, _) = m in
              if given e (key e k) then Some m else None);
          moved = (fun _ _ _ m -> Some m) };
        Exit.OK)
