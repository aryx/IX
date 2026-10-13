(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Monitor.mli *)

(* a half second: the shares of the board's time (0 to 1) the
 * processor ran, and ran user programs; the bytes a second each way *)
type point = { busy : float; user : float; inb : float; outb : float }

let kept = 512

type t = {
  period : float;
  mutable points : point list;   (* the newest first, [kept] at most *)
  (* since the last point: instructions run, of which user's, and waited *)
  mutable ran : int; mutable ran_user : int; mutable waited : int;
  mutable last_host : float; mutable last_board : int; mutable last_net : Usernet.totals option;
  mutable text : string;
}

let create ~period =
  { period; points = []; ran = 0; ran_user = 0; waited = 0; last_host = 0.; last_board = 0; last_net = None; text = "starting" }

let sample t cpus =
  List.iter (fun (c : Status.cpu) ->
    t.ran <- t.ran + c.ran; t.waited <- t.waited + c.waited;
    if c.user then t.ran_user <- t.ran_user + c.ran) cpus

let rate (b : float) : string =
  if b >= 1e6 then Printf.sprintf "%.1f MB/s" (b /. 1e6) else if b >= 1e3 then Printf.sprintf "%.0f KB/s" (b /. 1e3) else Printf.sprintf "%.0f B/s" b

let tick t ~host ~board ~(net : Usernet.totals) =
  if t.last_host = 0. then begin t.last_host <- host; t.last_board <- board; t.last_net <- Some net; false end
  else if host -. t.last_host < t.period then false
  else begin
    let dt = host -. t.last_host in
    let total = float_of_int (max 1 (t.ran + t.waited)) in
    let before = match t.last_net with Some n -> n | None -> net in
    let p = { busy = float_of_int t.ran /. total; user = float_of_int t.ran_user /. total;
              inb = float_of_int (net.to_guest - before.to_guest) /. dt; outb = float_of_int (net.from_guest - before.from_guest) /. dt } in
    t.points <- p :: (if List.length t.points >= kept then List.filteri (fun i _ -> i < kept - 1) t.points else t.points);
    (* (never "% ": a shell's prompt, which a session's script waits for on the console) *)
    t.text <-
      Printf.sprintf "cpu %.0f%%, user %.0f%%,  %.1f Mips  x%.2f  net in %s out %s  %d tcp %d udp%s" (100. *. p.busy) (100. *. p.user)
        (float_of_int t.ran /. dt /. 1e6) (float_of_int (board - t.last_board) /. 1e6 /. dt) (rate p.inb) (rate p.outb) net.tcp net.udp
        (match net.events with e :: _ -> "  " ^ e | [] -> "");
    t.ran <- 0; t.ran_user <- 0; t.waited <- 0;
    t.last_host <- host; t.last_board <- board; t.last_net <- Some net;
    true
  end

let line t = t.text

let height = 40

(* a rate as a share of half the strip: 1 MB/s all of it, a tenth of
 * it less for each factor of ten down to 10 B/s *)
let level (b : float) : float = if b < 10. then 0. else Float.min 1. ((log10 b -. 1.) /. 5.)

let strip t ~width =
  let px = Bytes.make (width * height * 3) '\032' in
  let set x y (r, g, b) =
    if x >= 0 && x < width && y >= 0 && y < height then begin
      let i = ((y * width) + x) * 3 in
      Bytes.set px i (Char.chr r); Bytes.set px (i + 1) (Char.chr g); Bytes.set px (i + 2) (Char.chr b)
    end in
  let half = width / 2 and col = 2 in
  (* the frame: a line above, one between the two graphs, the
   * network's middle *)
  for x = 0 to width - 1 do set x 0 (96, 96, 96) done;
  for y = 0 to height - 1 do set half y (96, 96, 96) done;
  let mid = (height + 1) / 2 in
  for x = half + 1 to width - 1 do set x mid (64, 64, 64) done;
  (* the newest column at each graph's right *)
  List.iteri (fun i p ->
    let room = height - 2 in
    let x = half - 1 - (i * col) in
    if x - col + 1 >= 0 then begin
      let busy = int_of_float (p.busy *. float_of_int room +. 0.5) and user = int_of_float (p.user *. float_of_int room +. 0.5) in
      for dx = 0 to col - 1 do
        for h = 0 to busy - 1 do set (x - dx) (height - 1 - h) (if h < user then (120, 220, 120) else (40, 140, 60)) done
      done
    end;
    let x = width - 1 - (i * col) in
    if x - col + 1 > half then begin
      let up = int_of_float (level p.inb *. float_of_int (mid - 2) +. 0.5) and down = int_of_float (level p.outb *. float_of_int (height - mid - 2) +. 0.5) in
      for dx = 0 to col - 1 do
        for h = 1 to up do set (x - dx) (mid - h) (90, 150, 240) done;
        for h = 1 to down do set (x - dx) (mid + h) (240, 150, 60) done
      done
    end) t.points;
  Bytes.unsafe_to_string px
