(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Hilbert.mli *)

let menu = "System.Close  System.Copy  System.Grow"

(* the pen, and a stroke's length; a stroke to the east, north, west, south *)
let x = ref 0
let y = ref 0
let d = ref 0
let e () = Display.repl_const White !x !y !d 1 Paint; x := !x + !d
let n () = Display.repl_const White !x !y 1 !d Paint; y := !y + !d
let w () = x := !x - !d; Display.repl_const White !x !y !d 1 Paint
let s () = y := !y - !d; Display.repl_const White !x !y 1 !d Paint

(* the curve of order i, in its four orientations *)
let rec ha i = if i > 0 then begin hd (i - 1); w (); ha (i - 1); s (); ha (i - 1); e (); hb (i - 1) end
and hb i = if i > 0 then begin hc (i - 1); n (); hb (i - 1); e (); hb (i - 1); s (); ha (i - 1) end
and hc i = if i > 0 then begin hb (i - 1); e (); hc (i - 1); n (); hc (i - 1); w (); hd (i - 1) end
and hd i = if i > 0 then begin ha (i - 1); s (); hd (i - 1); w (); hd (i - 1); n (); hc (i - 1) end

(* the curves of every order that fits the frame, one over the other *)
let draw_hilbert (f : Display.frame) =
  let k = ref 0 in
  d := 8;
  while !d * 2 < min f.w f.h do d := !d * 2; incr k done;
  Display.repl_const Black f.x f.y f.w f.h Replace;
  let x0 = ref (f.w / 2) and y0 = ref (f.h / 2) in
  for i = 1 to !k do
    d := !d / 2; x0 := !x0 + (!d / 2); y0 := !y0 + (!d / 2);
    x := f.x + !x0; y := f.y + !y0;
    ha i
  done

let rec handler (f : Display.frame) (m : Display.msg) =
  match m with
  | Oberon.Track (_, x, y) -> Oberon.draw_mouse_arrow x y
  | MenuViewers.Extend (_, y, h) | MenuViewers.Reduce (_, y, h) -> f.y <- y; f.h <- h; draw_hilbert f
  | Oberon.Neutralize -> Oberon.remove_marks f.x f.y f.w f.h
  | Oberon.Copy c -> c.copied <- Some { (Display.frame handler) with x = f.x; y = f.y; w = f.w; h = f.h }
  | _ -> ()

let draw () =
  let x, y = Oberon.allocate_user_viewer () in
  ignore (MenuViewers.new_ (TextFrames.new_menu "Hilbert" menu) (Display.frame handler) TextFrames.menu_h x y)

let () = Modules.command "Hilbert.Draw" draw
