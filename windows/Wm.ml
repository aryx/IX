(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Wm.mli *)

let windows : Window.t list ref = ref []
let ids = ref 0

let find id = List.find_opt (fun (w : Window.t) -> w.id = id) !windows
let current () = match !windows with w :: _ when not w.hidden -> Some w | _ -> None
let at (p : Point.t) = List.find_opt (fun (w : Window.t) -> not w.hidden && Rectangle.contains w.image.r p) !windows
let hidden () = List.filter (fun (w : Window.t) -> w.hidden) !windows

let border (p : Point.t) : (Window.t * int) option =
  match at p with
  | Some w when Window.on_border w p ->
      let part x lo hi = if x < lo + 20 then 0 else if x > hi - 20 then 2 else 1 in
      let r = w.image.r in
      Some (w, 3 * part p.y r.min.y r.max.y + part p.x r.min.x r.max.x)
  | _ -> None

let front (w : Window.t) =
  (match !windows with old :: _ when old != w -> Window.send old (Window.Front false) | _ -> ());
  windows := w :: List.filter (fun x -> x != w) !windows;
  Display.top w.image;
  Window.send w (Window.Front true)

let fits r = Rectangle.dx r >= 100 && Rectangle.dy r >= 50

let create caps desk font served r =
  incr ids;
  match Window.make desk !ids r font with
  | w -> front w; Processes_winshell.start caps w served
  | exception Failure m -> prerr_string ("rio: no new window: " ^ m ^ "\n")

let reshape (w : Window.t) r = front w; Window.send w (Window.Reshape r)

let delete caps (w : Window.t) =
  Processes_winshell.note caps w "hangup";
  windows := List.filter (fun x -> x != w) !windows;
  Window.quit w;
  (match !windows with next :: _ -> front next | [] -> ())

let hide (w : Window.t) =
  Window.send w (Window.Hide true);
  windows := List.filter (fun x -> x != w) !windows @ [ w ];
  (match !windows with next :: _ when not next.hidden -> front next | _ -> ())

let show (w : Window.t) = Window.send w (Window.Hide false); front w
