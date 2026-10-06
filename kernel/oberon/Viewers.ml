(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Viewers.mli *)

type viewer = { frame : Display.frame; mutable state : int; menu_h : int }

exception Restore
exception Modify of int * int
exception Suspend

(* a track: its viewers from the lowest, the last one its filler
 * (Oberon's is a ring from the filler; the lowest starts at y = 0) *)
type track = { tx : int; tw : int; mutable viewers : viewer list }

let tracks : track list ref = ref []
let cur_w = ref 0
let min_h = ref 1
let dh = Display.height
let backup : viewer option ref = ref None

let send (v : viewer) m = Display.send v.frame m
let top (v : viewer) = v.frame.y + v.frame.h

let track_at x = List.find_opt (fun t -> x >= t.tx && x < t.tx + t.tw) !tracks
let track_of (v : viewer) = List.find (fun t -> List.memq v t.viewers) !tracks
let filler t = List.nth t.viewers (List.length t.viewers - 1)

let init_track w h (fil : viewer) =
  if fil.state = 0 then begin
    let f = fil.frame in
    f.x <- !cur_w; f.w <- w; f.y <- 0; f.h <- h;
    fil.state <- 1;
    tracks := !tracks @ [ { tx = !cur_w; tw = w; viewers = [ fil ] } ];
    cur_w := !cur_w + w
  end

(* the track's viewers below the one that has y, that one, those above *)
let rec split y below = function
  | u :: (_ :: _ as above) when y > top u -> split y (u :: below) above
  | u :: above -> List.rev below, u, above
  | [] -> invalid_arg "Viewers.split"

let open_ (v : viewer) x y =
  match track_at x with
  | Some t when v.state = 0 ->
      let below, u, above = split (min y dh) [] t.viewers in
      let y = max (min y dh) (u.frame.y + !min_h) in
      let f = v.frame and uf = u.frame in
      f.x <- t.tx; f.w <- t.tw; f.y <- uf.y;
      if above <> [] && y > top u - !min_h then begin
        (* too little of u would be left: v has its place *)
        f.h <- uf.h;
        send u Suspend; u.state <- 0;
        t.viewers <- below @ (v :: above)
      end
      else begin
        f.h <- y - uf.y;
        let h = top u - y in
        send u (Modify (y, h)); uf.y <- y; uf.h <- h;
        t.viewers <- below @ (v :: u :: above)
      end;
      v.state <- 2
  | _ -> ()

let next (v : viewer) =
  let t = track_of v in
  let rec after = function a :: b :: _ when a == v -> b | _ :: l -> after l | [] -> List.hd t.viewers in
  after t.viewers

let change (v : viewer) y =
  if v.state > 1 then begin
    let u = next v in
    let uf = u.frame in
    let y = min y dh in
    let y = if u.state > 1 && y > top u - !min_h then top u - !min_h else y in
    if y >= v.frame.y + !min_h then begin
      let h = top u - y in
      send u (Modify (y, h)); uf.y <- y; uf.h <- h;
      v.frame.h <- y - v.frame.y
    end
  end

let close (v : viewer) =
  if v.state > 1 then begin
    let t = track_of v and u = next v in
    send v Suspend; v.state <- 0; backup := Some v;
    let y = v.frame.y and h = v.frame.h + u.frame.h in
    send u (Modify (y, h)); u.frame.y <- y; u.frame.h <- h;
    t.viewers <- List.filter (fun w -> w != v) t.viewers
  end

let recall () = !backup

let this x y =
  if y < 0 || y >= dh then None
  else Option.bind (track_at x) (fun t -> List.find_opt (fun v -> y < top v) t.viewers)

let locate x h =
  match track_at x with
  | None -> invalid_arg "Viewers.locate"
  | Some t ->
      let fil = filler t and bot = List.hd t.viewers in
      let others = List.filter (fun v -> v != fil && v != bot) t.viewers in
      let higher (a : viewer) (b : viewer) = if b.frame.h > a.frame.h then b else a in
      let alt = match others with
        | [] -> bot
        | first :: rest -> List.fold_left (fun (a : viewer) v -> if a.frame.h < h then higher a v else a) first rest in
      fil, bot, alt, List.fold_left higher fil (List.filter (fun v -> v != fil) t.viewers)

let broadcast m = List.iter (fun t -> List.iter (fun v -> send v m) t.viewers) !tracks
