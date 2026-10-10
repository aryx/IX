(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Host.mli *)

module Phys = Machine.Phys

external milliseconds : unit -> int = "squeak_milliseconds"
external show16 : int -> int -> string -> int -> int -> unit = "squeak_show16"

(* the framebuffer: its address, a row's bytes; a pixel is Which.depth
 * bits: 32 (four bytes, red first), or 16 (5, 6 and 5 of red, green and
 * blue, as the other kernels') *)
let fb = ref 0
let bytes = Which.depth / 8
let pitch = ref (bytes * Squeak.width)

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

(* [n] pixels of one colour, as the framebuffer's bytes *)
let pixels (n : int) (white : bool) : string =
  let p = if Which.depth = 16 then (if white then "\xff\xff" else "\x00\x00") else if white then "\xff\xff\xff\xff" else "\x00\x00\x00\xff" in
  String.concat "" (List.init n (fun (_ : int) -> p))

let init () : St_interp.host =
  fb := Machine.fb_init Squeak.width Squeak.height Which.depth;
  (let p = Machine.fb_pitch () in if p > 0 then pitch := p);
  (* the world's grey at once: Smalltalk's first picture is seconds away *)
  if !fb <> 0 then begin
    let grey = if Which.depth = 16 then "\x79\xce" else "\xcc\xcc\xcc\xff" in
    let row = String.concat "" (List.init Squeak.width (fun (_ : int) -> grey)) in
    for j = 0 to Squeak.height - 1 do Phys.write (!fb + (j * !pitch)) row done
  end;
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

(* The Display's bytes are the board's as they are at 32 bits (red,
 * green, blue, then a byte the board does not look at): a row at a
 * time, or all at once when the board's rows have no more bytes than
 * the Display's. At 16, a pixel at a time, in C. *)
let show ((w, h, px) : int * int * Bytes.t) : unit =
  if !fb <> 0 && w = Squeak.width then begin
    let s = Bytes.unsafe_to_string px and rows = min h Squeak.height in
    if Which.depth = 16 then show16 !fb !pitch s w 0
    else if !pitch = 4 * w then Phys.write_sub !fb s 0 (4 * w * rows)
    else for j = 0 to rows - 1 do Phys.write_sub (!fb + (j * !pitch)) s (4 * w * j) (4 * w) done
  end

(* (alpha, red, green, blue from the second byte on is red, green,
 * blue, then the next pixel's alpha, which the board does not look at) *)
let show32 ((w, h, stride, bits) : int * int * int * Bytes.t) : unit =
  if !fb <> 0 && w = Squeak.width then begin
    let s = Bytes.unsafe_to_string bits and rows = min h Squeak.height in
    if Which.depth = 16 then show16 !fb !pitch s w 1
    else if !pitch = stride then Phys.write_sub !fb s 1 ((stride * rows) - 1)
    else for j = 0 to rows - 1 do Phys.write_sub (!fb + (j * !pitch)) s ((stride * j) + 1) ((4 * w) - 1) done
  end

(* The pointer: Squeak draws none (a window's host has its own), so the
 * board's is drawn here, over the Display's pixels, after each picture:
 * an arrow's left half, black edged with white. Not before the mouse
 * first moves: the boot's screen is the Display and nothing else. *)
let seen = ref (Squeak.width / 2, Squeak.height / 2)
let pointing = ref false

let pointer_moved () : bool =
  if (!x, !y) <> !seen then begin seen := (!x, !y); pointing := true; true end else false

let pointer () : unit =
  if !pointing && !fb <> 0 then
    for i = 0 to 11 do
      if !y + i < Squeak.height then begin
        let n = min (i + 2) (Squeak.width - !x) in
        let row = if n >= 2 then pixels (n - 1) false ^ pixels 1 true else pixels n false in
        Phys.write (!fb + ((!y + i) * !pitch) + (!x * bytes)) row
      end
    done
