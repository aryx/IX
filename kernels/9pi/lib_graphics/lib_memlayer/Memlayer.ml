(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Memlayer.mli *)

open Memimage

type rect = Memimage.rect

let opaque =
  let c = match Memchan.make 0 0x31 with Some c -> c | None -> failwith "grey1" in
  let i = alloc (0, 0, 1, 1) c in
  i.repl <- true;
  i.clipr <- (-0x3FFFFFF, -0x3FFFFFF, 0x3FFFFFF, 0x3FFFFFF);
  fill i 0xffff 0xffff;
  i

let o_s = 10

let layer w = match w.layer with Some l -> l | None -> failwith "not a window"

(* a window's screen coordinates less its own *)
let delta w = let (x0, y0, _, _) = (layer w).screenr and (a, b, _, _) = w.r in (x0 - a, y0 - b)

let shift (x0, y0, x1, y1) (dx, dy) = (x0 + dx, y0 + dy, x1 + dx, y1 + dy)

(* a minus b: up to four rectangles *)
let minus a b =
  match clip a b with
  | None -> [ a ]
  | Some (c0, d0, c1, d1) ->
      let (x0, y0, x1, y1) = a in
      List.filter (fun (p, q, r, s) -> p < r && q < s)
        [ (x0, y0, x1, d0); (x0, d1, x1, y1); (x0, d0, c0, d1); (c1, d0, x1, d1) ]

let rec draw dst r src sp mask mp op =
  Memdraw.draw dst r src sp mask mp op;
  match dst.layer with
  | None -> ()
  | Some _ -> (
      match clip r dst.r with
      | None -> ()
      | Some r -> (match clip r dst.clipr with Some r -> show dst r | None -> ()))

(* a window's rectangle r (its own coordinates) on its screen, where no
 * window in front covers it *)
and show w r =
  let l = layer w in
  let d = delta w in
  let rec front = function [] -> [] | x :: rest -> if x == w then [] else x :: front rest in
  let pieces = List.fold_left (fun ps x -> List.concat (List.map (fun p -> minus p (layer x).screenr) ps))
    [ shift r d ] (front l.lscr.wins) in
  List.iter (fun p -> let (a, b, _, _) = p in draw l.lscr.simage p w (a - fst d, b - snd d) opaque (0, 0) o_s) pieces

(* a screen's rectangle painted anew: its fill, then the windows there
 * from the rearmost *)
let repaint s r =
  let (a, b, _, _) = r in
  draw s.simage r s.sfill (a, b) opaque (0, 0) o_s;
  List.iter (fun w ->
    match clip r (layer w).screenr with
    | Some p -> let (c, e, _, _) = p and d = delta w in draw s.simage p w (c - fst d, e - snd d) opaque (0, 0) o_s
    | None -> ()) (List.rev s.wins)

let screen image fill = { simage = image; sfill = fill; wins = [] }

let alloc s screenr clipr hi lo =
  let w = Memimage.alloc screenr s.simage.chan in
  (match Memimage.clip clipr screenr with Some c -> w.clipr <- c | None -> w.clipr <- clipr);
  if hi = 0xffff && lo = 0xff00 then begin
    (* DNofill: what the screen shows there *)
    let (a, b, _, _) = screenr in
    Memdraw.draw w screenr s.simage (a, b) opaque (0, 0) o_s
  end else fill w hi lo;
  w.layer <- Some { lscr = s; screenr = screenr };
  s.wins <- w :: s.wins;
  show w w.r;
  w

let remove w = let s = (layer w).lscr in s.wins <- List.filter (fun x -> x != w) s.wins

let delete w = remove w; repaint (layer w).lscr (layer w).screenr
let free w = remove w

let tofront ws =
  match ws with
  | [] -> ()
  | w :: _ ->
      let s = (layer w).lscr in
      s.wins <- ws @ List.filter (fun x -> not (List.memq x ws)) s.wins;
      List.iter (fun x -> show x x.r) (List.rev ws)

let torear ws =
  match ws with
  | [] -> ()
  | w :: _ ->
      let s = (layer w).lscr in
      s.wins <- List.filter (fun x -> not (List.memq x ws)) s.wins @ List.rev ws;
      List.iter (fun x -> repaint s (layer x).screenr) ws

let origin w (lx, ly) (sx, sy) =
  let l = layer w in
  let (x0, y0, x1, y1) = l.screenr and (a, b, _, _) = w.r in
  if (sx, sy) = (x0, y0) && (lx, ly) = (a, b) then 0
  else begin
    tofront [ w ];
    let d = (lx - a, ly - b) in
    w.r <- shift w.r d;
    w.clipr <- shift w.clipr d;
    if (sx, sy) = (x0, y0) then 0
    else begin
      l.screenr <- (sx, sy, sx + x1 - x0, sy + y1 - y0);
      repaint l.lscr (x0, y0, x1, y1);
      show w w.r;
      1
    end
  end

let load w r data compressed =
  let n = if compressed then Memimage.cload w r data else Memimage.load w r data in
  (match w.layer with Some _ when n >= 0 -> show w r | _ -> Memimage.flush w r);
  n
