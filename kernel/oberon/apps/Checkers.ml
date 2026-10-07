(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Checkers.mli *)

(* squares of 8 pixels: a pattern 32 wide and 16 high, 8 rows then 8 rows the other way *)
let checks : Display.pattern =
  "\x20\x10\x00\x00" ^ String.concat "" (List.init 8 (fun _ -> "\xff\x00\xff\x00")) ^ String.concat "" (List.init 8 (fun _ -> "\x00\xff\x00\xff"))

let restore (f : Display.frame) =
  Oberon.remove_marks f.x f.y f.w f.h;
  Display.repl_const Black f.x f.y f.w f.h Replace;
  Display.repl_pattern White checks (f.x + 1) f.y (f.w - 1) (f.h - 1)

let rec handle (f : Display.frame) (m : Display.msg) =
  match m with
  | Oberon.Track (_, x, y) -> Oberon.draw_mouse_arrow x y
  | Oberon.Copy c ->
      Oberon.remove_marks f.x f.y f.w f.h;
      c.copied <- Some { (Display.frame handle) with x = f.x; y = f.y; w = f.w; h = f.h }
  | MenuViewers.Extend (_, y, h) | MenuViewers.Reduce (_, y, h) -> if y <> f.y || h <> f.h then begin f.y <- y; f.h <- h; restore f end
  | _ -> ()

let open_ () =
  let x, y = Oberon.allocate_user_viewer () in
  ignore (MenuViewers.new_ (TextFrames.new_menu "CheckerViewer" "System.Close System.Copy System.Grow") (Display.frame handle) TextFrames.menu_h x y)

let () = Modules.command "Checkers.Open" open_
