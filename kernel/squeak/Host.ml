(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Host.mli *)

module Phys = Machine.Phys

external milliseconds : unit -> int = "squeak_milliseconds"

(* the framebuffer: its address, a row's bytes; a pixel is four bytes,
 * red first *)
let fb = ref 0
let pitch = ref (4 * Squeak.width)

(* what the machine reads: where the mouse is on the Display, its
 * buttons by Smalltalk's colours (4 red, the left; 2 yellow, the
 * right; 1 blue, the middle), and the characters typed, waiting *)
let x = ref (Squeak.width / 2)
let y = ref (Squeak.height / 2)
let buttons = ref 0
let keys : int Queue.t = Queue.create ()
let interrupted = ref false

(* a USB mouse's report: how far it moved (dy downwards, as the
 * Display's), its buttons (1 left, 2 right, 4 middle) *)
let moved (dx : int) (dy : int) (b : int) : unit =
  x := max 0 (min (Squeak.width - 1) (!x + dx));
  y := max 0 (min (Squeak.height - 1) (!y + dy));
  buttons := (if b land 1 <> 0 then 4 else 0) lor (if b land 2 <> 0 then 2 else 0) lor (if b land 4 <> 0 then 1 else 0)

(* a character typed, on the USB keyboard or the serial line; Control-C
 * is not Smalltalk's *)
let typed (code : int) : unit =
  let c = code land 255 in
  if c = 3 then interrupted := true else Queue.add (if c = 10 then 13 else c) keys

let tick_us = 10000

let init () : St_interp.host =
  fb := Machine.fb_init Squeak.width Squeak.height 32;
  (let p = Machine.fb_pitch () in if p > 0 then pitch := p);
  Usbhost.init typed moved;
  Machine.uart_rx_enable ();
  Machine.timer_arm tick_us;
  { St_boot.quiet_host with
    transcript = (fun (s : string) -> Machine.print (String.map (fun (c : char) -> if c = '\r' then '\n' else c) s));
    milliseconds;
    mouse = (fun () -> (!x, !y, !buttons));
    keyboard = (fun () -> Queue.take_opt keys) }

let poll () : bool =
  if not (Machine.timer_pending ()) then Machine.wait_interrupt ();
  if Machine.timer_pending () then begin
    Machine.timer_arm tick_us;
    Usbhost.poll ()
  end;
  let rec uart () : unit =
    let c = Machine.uart_getc () in
    if c >= 0 then begin typed c; uart () end in
  uart ();
  let i = !interrupted in
  interrupted := false;
  i

(* The Display's bytes are the board's as they are (red, green, blue,
 * then a byte the board does not look at): a row at a time, or all at
 * once when the board's rows have no more bytes than the Display's *)
let show ((w, h, pixels) : int * int * Bytes.t) : unit =
  if !fb <> 0 && w = Squeak.width then begin
    let s = Bytes.unsafe_to_string pixels and rows = min h Squeak.height in
    if !pitch = 4 * w then Phys.write_sub !fb s 0 (4 * w * rows)
    else for j = 0 to rows - 1 do Phys.write_sub (!fb + (j * !pitch)) s (4 * w * j) (4 * w) done
  end

(* (alpha, red, green, blue from the second byte on is red, green,
 * blue, then the next pixel's alpha, which the board does not look at) *)
let show32 ((w, h, stride, bits) : int * int * int * Bytes.t) : unit =
  if !fb <> 0 && w = Squeak.width then begin
    let s = Bytes.unsafe_to_string bits and rows = min h Squeak.height in
    if !pitch = stride then Phys.write_sub !fb s 1 ((stride * rows) - 1)
    else for j = 0 to rows - 1 do Phys.write_sub (!fb + (j * !pitch)) s ((stride * j) + 1) ((4 * w) - 1) done
  end
