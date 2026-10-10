(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Sierpinski.mli *)

let menu = "System.Close  System.Copy  System.Grow"

(* the pen, and a stroke's length; the eight strokes *)
let x = ref 0
let y = ref 0
let d = ref 0
let e () = Display.repl_const White !x !y !d 1 Paint; x := !x + !d
let n () = Display.repl_const White !x !y 1 !d Paint; y := !y + !d
let w () = x := !x - !d; Display.repl_const White !x !y !d 1 Paint
let s () = y := !y - !d; Display.repl_const White !x !y 1 !d Paint
let diagonal dx dy () = for _i = 1 to !d do Display.dot White !x !y Paint; x := !x + dx; y := !y + dy done
let ne = diagonal 1 1
let nw = diagonal (-1) 1
let sw = diagonal (-1) (-1)
let se = diagonal 1 (-1)

let rec sa i = if i > 0 then begin sa (i - 1); se (); sb (i - 1); e (); e (); sd (i - 1); ne (); sa (i - 1) end
and sb i = if i > 0 then begin sb (i - 1); sw (); sc (i - 1); s (); s (); sa (i - 1); se (); sb (i - 1) end
and sc i = if i > 0 then begin sc (i - 1); nw (); sd (i - 1); w (); w (); sb (i - 1); sw (); sc (i - 1) end
and sd i = if i > 0 then begin sd (i - 1); ne (); sa (i - 1); n (); n (); sc (i - 1); nw (); sd (i - 1) end

let draw_sierpinski (f : Display.frame) =
  let k = ref 0 in
  d := 4;
  while !d * 8 < min f.w f.h do d := !d * 2; incr k done;
  Display.repl_const Black f.x f.y f.w f.h Replace;
  let x0 = ref (f.w / 2) and y0 = ref ((f.h / 2) + !d) in
  for i = 1 to !k do
    x0 := !x0 - !d; d := !d / 2; y0 := !y0 + !d;
    x := f.x + !x0; y := f.y + !y0;
    sa i; se (); sb i; sw (); sc i; nw (); sd i; ne ()
  done

let rec handler (f : Display.frame) (m : Display.msg) =
  match m with
  | Oberon.Track (_, x, y) -> Oberon.draw_mouse_arrow x y
  | MenuViewers.Extend (_, y, h) | MenuViewers.Reduce (_, y, h) -> f.y <- y; f.h <- h; draw_sierpinski f
  | Oberon.Neutralize -> Oberon.remove_marks f.x f.y f.w f.h
  | Oberon.Copy c -> c.copied <- Some { (Display.frame handler) with x = f.x; y = f.y; w = f.w; h = f.h }
  | _ -> ()

let draw () =
  let x, y = Oberon.allocate_user_viewer () in
  ignore (MenuViewers.new_ (TextFrames.new_menu "Sierpinski" menu) (Display.frame handler) TextFrames.menu_h x y)

let () = Modules.command "Sierpinski.Draw" draw
