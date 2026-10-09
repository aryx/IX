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

let create caps desk font srv r command =
  incr ids;
  match Window.make desk !ids r font with
  | w -> front w; Processes_winshell.start caps w srv command; Some w
  | exception Failure m -> prerr_string ("rio: no new window: " ^ m ^ "\n"); None

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

let bottom (w : Window.t) =
  let shown, hidden = List.partition (fun (x : Window.t) -> not x.hidden) (List.filter (fun x -> x != w) !windows) in
  windows := shown @ [ w ] @ hidden;
  Display.bottom w.image;
  Window.send w (Window.Front false);
  (match !windows with next :: _ when next != w && not next.hidden -> front next | _ -> ())

(* (rio's newrect) *)
let news = ref 0

let control caps make (screen : Rectangle.t) (w : Window.t) (c : Wctl.command) =
  match (match c.id with Some id -> find id | None -> if List.memq w !windows then Some w else None) with
  | None -> ()
  | Some w -> (
      match c.verb with
      | Wctl.New ->
          let at = 32 + (16 * !news) in
          news := (!news + 1) mod 10;
          let r = c.place (Rectangle.v at at (at + min 600 (Rectangle.dx screen - 8)) (at + min 400 (Rectangle.dy screen - 8))) in
          if fits r then
            Option.iter (fun fresh ->
                Option.iter (fun on -> Window.send fresh (Window.Scroll on)) c.scrolling;
                if c.hidden then hide fresh) (make r c.arg)
      | Wctl.Resize -> let r = c.place w.image.r in if fits r && r <> w.image.r then reshape w r
      | Wctl.Move ->
          (* (its place only: the size is the window's) *)
          let r : Rectangle.t = c.place w.image.r in
          let r = Rectangle.v r.min.x r.min.y (r.min.x + Rectangle.dx w.image.r) (r.min.y + Rectangle.dy w.image.r) in
          if r <> w.image.r then reshape w r
      | Wctl.Top | Wctl.Current -> if not w.hidden then front w
      | Wctl.Bottom -> if not w.hidden then bottom w
      | Wctl.Hide -> if not w.hidden then hide w
      | Wctl.Unhide -> if w.hidden then show w
      | Wctl.Delete -> delete caps w
      | Wctl.Scroll -> Window.send w (Window.Scroll true)
      | Wctl.Noscroll -> Window.send w (Window.Scroll false))
