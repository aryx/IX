(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Wm.mli *)

let windows : Window.t list ref = ref []
(* those of a layer, in no order: [windows] and what is done with it are
 * what they were without any *)
let layered : Window.t list ref = ref []
let ids = ref 0

let all () = !layered @ !windows
let find id = List.find_opt (fun (w : Window.t) -> w.id = id) (all ())
let current () = match !windows with w :: _ when not w.hidden -> Some w | _ -> None

let of_layer l = List.filter (fun (w : Window.t) -> w.layer = l) !layered
let shown_at (p : Point.t) (w : Window.t) = not w.hidden && Rectangle.contains w.image.r p
(* a popup or a panel there, over any window *)
let above (p : Point.t) =
  match List.find_opt (shown_at p) (of_layer Window.Popup) with
  | Some w -> Some w
  | None -> List.find_opt (shown_at p) (of_layer Window.Panel)

let at (p : Point.t) =
  match above p with
  | Some _ -> None
  | None -> List.find_opt (shown_at p) !windows

let layer_at (p : Point.t) =
  match above p, at p with
  | Some w, _ -> Some w
  | None, Some _ -> None
  | None, None -> List.find_opt (shown_at p) (of_layer Window.Desk)

let popups () = List.filter (fun (w : Window.t) -> not w.hidden) (of_layer Window.Popup)
let hidden () = List.filter (fun (w : Window.t) -> w.hidden) !windows

(* the panels, then the popups, back on top *)
let on_top () =
  List.iter (fun (w : Window.t) -> Display.top w.image) (of_layer Window.Panel);
  List.iter (fun (w : Window.t) -> Display.top w.image) (of_layer Window.Popup)

let restack (w : Window.t) = if w.layer = Window.Desk then Display.bottom w.image else on_top ()

let work_of (screen : Rectangle.t) (taken : Rectangle.t list) : Rectangle.t =
  List.fold_left (fun (work : Rectangle.t) (r : Rectangle.t) ->
      if r.min.x <= work.min.x && r.max.x >= work.max.x then
        if r.min.y <= work.min.y && r.max.y > work.min.y then Rectangle.v work.min.x r.max.y work.max.x work.max.y
        else if r.max.y >= work.max.y && r.min.y < work.max.y then Rectangle.v work.min.x work.min.y work.max.x r.min.y
        else work
      else if r.min.y <= work.min.y && r.max.y >= work.max.y then
        if r.min.x <= work.min.x && r.max.x > work.min.x then Rectangle.v r.max.x work.min.y work.max.x work.max.y
        else if r.max.x >= work.max.x && r.min.x < work.max.x then Rectangle.v work.min.x work.min.y r.min.x work.max.y
        else work
      else work)
    screen taken

let work screen =
  work_of screen (List.filter_map (fun (w : Window.t) -> if w.hidden then None else Some w.image.r) (of_layer Window.Panel))

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
  on_top ();
  Window.send w (Window.Front true)

let fits r = Rectangle.dx r >= 100 && Rectangle.dy r >= 50
(* (a panel may be thin) *)
let fits_layer (l : Window.layer) r = if l = Window.Normal then fits r else Rectangle.dx r > 0 && Rectangle.dy r > 0

(* (a command's label: its name, the first word without its directory) *)
let label_of (c : Wctl.command) =
  if c.label <> "" then c.label
  else if c.arg = "" then ""
  else Filename.basename (List.hd (String.split_on_char ' ' c.arg))

let create caps desk font srv r (c : Wctl.command) =
  incr ids;
  match Window.make desk !ids r font c.layer with
  | w ->
      if c.layer = Window.Normal then front w
      else begin layered := w :: !layered; restack w end;
      if label_of c <> "" then Window.send w (Window.Label (label_of c));
      w.ends <- c.arg <> "" && not c.hold;
      Processes_winshell.start caps w srv ~cd:c.cd c.arg;
      Some w
  | exception Failure m -> prerr_string ("rio: no new window: " ^ m ^ "\n"); None

(* (one of a layer keeps its place among the layers, and the keyboard
 * stays where it is) *)
let raise_ (w : Window.t) = if w.layer = Window.Normal then front w else restack w

let reshape (w : Window.t) r = raise_ w; Window.send w (Window.Reshape r)

let delete caps (w : Window.t) =
  Processes_winshell.note caps w "hangup";
  windows := List.filter (fun x -> x != w) !windows;
  layered := List.filter (fun x -> x != w) !layered;
  Window.quit w;
  if w.layer = Window.Normal then (match !windows with next :: _ -> front next | [] -> ())

let hide (w : Window.t) =
  Window.send w (Window.Hide true);
  if w.layer = Window.Normal then begin
    windows := List.filter (fun x -> x != w) !windows @ [ w ];
    (match !windows with next :: _ when not next.hidden -> front next | _ -> ())
  end

let show (w : Window.t) = Window.send w (Window.Hide false); raise_ w

let desks_down () = List.iter (fun (d : Window.t) -> Display.bottom d.image) (of_layer Window.Desk)

let bottom (w : Window.t) =
  let shown, hidden = List.partition (fun (x : Window.t) -> not x.hidden) (List.filter (fun x -> x != w) !windows) in
  windows := shown @ [ w ] @ hidden;
  Display.bottom w.image;
  desks_down ();
  Window.send w (Window.Front false);
  (match !windows with next :: _ when next != w && not next.hidden -> front next | _ -> ())

(* (rio's newrect) *)
let news = ref 0

let control caps make (screen : Rectangle.t) (w : Window.t option) (c : Wctl.command) =
  let room : Rectangle.t = work screen in
  let placed r = match c.area with Some f -> f room | None -> c.place r in
  match (match c.id with Some id -> find id | None -> (match w with Some w when List.memq w (all ()) -> Some w | _ -> None)), c.verb with
  (* (a new one needs no window: the root's wctl, one that has gone) *)
  | _, Wctl.New ->
      let x = room.min.x + 32 + (16 * !news) and y = room.min.y + 32 + (16 * !news) in
      news := (!news + 1) mod 10;
      let wide = min 600 (Rectangle.dx room - 8) and high = min 400 (Rectangle.dy room - 8) in
      (* (so far down the area that it would go under a panel: where it fits) *)
      let y = if y + high > room.max.y then room.min.y else y in
      let r = match c.layer, c.area with
        | Window.Desk, None -> c.place screen
        | _ -> placed (Rectangle.v x y (x + wide) (y + high)) in
      if fits_layer c.layer r then
        Option.iter (fun fresh ->
            Option.iter (fun on -> Window.send fresh (Window.Scroll on)) c.scrolling;
            if c.hidden then hide fresh) (make r c)
  | None, _ -> ()
  | Some w, _ -> (
      match c.verb with
      | Wctl.New | Wctl.Exit -> ()
      | Wctl.Resize -> let r = placed w.image.r in if fits_layer w.layer r && r <> w.image.r then reshape w r
      | Wctl.Move ->
          (* (its place only: the size is the window's) *)
          let r : Rectangle.t = placed w.image.r in
          let r = Rectangle.v r.min.x r.min.y (r.min.x + Rectangle.dx w.image.r) (r.min.y + Rectangle.dy w.image.r) in
          if r <> w.image.r then reshape w r
      | Wctl.Top | Wctl.Current -> if not w.hidden then raise_ w
      | Wctl.Bottom -> if not w.hidden && w.layer = Window.Normal then bottom w
      | Wctl.Hide -> if not w.hidden then hide w
      | Wctl.Unhide -> if w.hidden then show w
      | Wctl.Delete -> delete caps w
      | Wctl.Scroll -> Window.send w (Window.Scroll true)
      | Wctl.Noscroll -> Window.send w (Window.Scroll false))
