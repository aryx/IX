(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* A tiny playground: what a game of TinyKernel.ml's is written on, the
 * essential of the author's playground (ix's twin is lib_playground/),
 * which is Elm's architecture. A library, in tiny-ml's ML and OCaml's,
 * given to tiny-ml before the game (plan_tiny_windows.md):
 *
 *     tiny-ml -tm -o tetris.tm calls.ml TinyDraw.ml TinyPlayground.ml TinyTetris.ml tetris.ml
 *     (the last one line: let () = run game)
 *
 * The idea kept: {b a game is a value and three functions}. Its model,
 * all that it knows; [view], the model as shapes; [key] and [frame],
 * the model after a key and after a thirtieth of a second. No loop, no
 * drawing, no state of its own: the library has them. So a game is
 * tested without a screen (a model, some keys, the model after), and
 * its picture without a machine (the shapes drawn by TinyGraphics.ml on
 * the host).
 *
 * What is the library's:
 *
 * - {b The loop}: the kernel's ready on the keys until the next frame's
 *   time; a key or the time changes the model.
 * - {b The picture, when it is another one}: a model that is the same
 *   value as before is not looked at (!=: a function that changes
 *   nothing gives its argument back), and shapes equal to those shown
 *   are not drawn. The shapes are drawn in an image off the window,
 *   then that image on the window in one message: nothing flickers,
 *   and a window system shows one rectangle.
 * - {b The colours}: a shape's colour is a byte of Plan 9's table; the
 *   image the kernel wants for it is made at its first use.
 *
 * Dropped, the playground's: numbers that are floats under a
 * transformation (move, scale, rotate, fade: a shape here is pixels,
 * its place whole numbers, y down from the window's top left corner),
 * circles, polygons, images, words of several sizes (the machine's one
 * font, 8 by 16), sounds, the mouse, subscriptions and commands (a game
 * here gets every key and every frame), a time that is the host's (a
 * frame is 13 of the kernel's ticks: the machine's instructions), and
 * the platforms (one: the descriptor a program draws on).
 *
 * Exercises:
 * - the mouse: a fourth function, and the program's descriptor 4;
 * - only what changed drawn: the shapes of two models compared;
 * - a circle and a polygon, with TinyGraphics.ml's;
 * - a second game: a Snake, a Pong.
 *
 * References (from memory): E. Czaplicki, "Elm: Concurrent FRP for
 * Functional GUIs" (2012) and The Elm Architecture; Elm's Playground
 * package (2019), a game as a model, a view and an update. *)

open TinyDraw
open TinyCalls

(* a rectangle of a colour (its width, its height), words of a colour,
 * shapes together, a shape moved (to the right, down) *)
type shape = Rect of int * int * int | Words of int * string | Group of shape list | Move of int * int * shape

(* a game: its picture's size; its first model, from a seed; the model
 * as shapes (the first ones under the next); the model after a key
 * (its byte: the arrows are 128 to 131, up, down, left, right), and
 * after a frame *)
type 'm game = { width : int; height : int; init : int -> 'm; view : 'm -> shape list; key : int -> 'm -> 'm; frame : 'm -> 'm }

(* Random numbers for a game's model, which keeps the state: the state
 * after s, a number from 1 to m - 1 (use it modulo what is wanted).
 * Lehmer's generator, 16807 s modulo m, by Schrage's division so that
 * no product passes the machine's 31 bits; m is the largest prime
 * under 2^30 (that 16807 gives every number before coming back was
 * not checked) *)
let random s =
  let m = 1073741789 in
  let n = (16807 * (s mod 63886)) - (9787 * (s / 63886)) in
  if n > 0 then n else n + m

(*****************************************************************************)
(* The picture *)
(*****************************************************************************)

(* messages gathered, written past a kilobyte and at a picture's end *)
let gathered = ref ""
let flush () = if !gathered <> "" then (ignore (u_write 3 !gathered); gathered := "")
let put m = gathered := !gathered ^ m; if String.length !gathered > 1024 then flush ()

(* our images: 0 is the window, 1 the picture off it, a colour's byte c 2 + c *)
let picture = 1
let made = Array.make 256 false
let ink c =
  let c = c land 255 in
  if not made.(c) then (made.(c) <- true; put (d_colour (2 + c) c));
  2 + c

let rec draw x y shape =
  match shape with
  | Rect (c, w, h) -> put (d_fill picture (ink c) x y (x + w) (y + h))
  | Words (c, s) -> put (d_text picture (ink c) x y s)
  | Group l -> List.iter (draw x y) l
  | Move (dx, dy, s) -> draw (x + dx) (y + dy) s

(* a model's shapes: in the picture, then the picture on the window *)
let show g shapes =
  List.iter (draw 0 0) shapes;
  put (d_draw 0 picture (-1) 0 0 g.width g.height 0 0);
  flush ()

(*****************************************************************************)
(* The loop *)
(*****************************************************************************)

(* a frame, in the kernel's ticks: a thirtieth of a second of a machine
 * of 8 million instructions a second, a tick 20,000 *)
let period = 13

(* The game, until a q or the keys' end: the model's shapes when it is
 * another model than the last looked at, shown when they are other
 * shapes than those shown (a game's model changes at each frame if it
 * counts them; its picture when a piece moved); then a key or the next
 * frame's time waited for, whichever is first (a frame's time is a
 * period after the last one's, so that thirty are a second whatever
 * they cost; from now when a frame is more than one late: a game does
 * not run to catch up). *)
let run g =
  let keys = Array.make 1 0 in
  let rec loop model seen shown next =
    let shapes = if model != seen then g.view model else shown in
    if shapes <> shown then show g shapes;
    if u_ready keys 1 next = 0 then begin
      let s = u_read 0 16 in
      if s = "" then exit 0;
      let rec typed i m = if i >= String.length s then m else if s.[i] = 'q' then exit 0 else typed (i + 1) (g.key (Char.code s.[i]) m) in
      loop (typed 0 model) model shapes next
    end
    else loop (g.frame model) model shapes (if u_ticks () > next + period then u_ticks () + period else next + period)
  in
  put (d_image picture 0 0 g.width g.height 0);
  let first = g.init (u_ticks ()) in
  let shapes = g.view first in
  show g shapes;
  loop first first shapes (u_ticks () + period)
