(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyLibPlayground.mli *)

open TinyLibDraw
open TinyCalls

(* a rectangle of a colour (its width, its height), words of a colour,
 * shapes together, a shape moved (to the right, down) *)
type shape = Rect of int * int * int | Words of int * string | Group of shape list | Move of int * int * shape
let bold = 256
let italic = 512
let underlined = 1024
let large = 2048
let fat_pixels = 4096

let char_width c = if c land fat_pixels <> 0 then 4 else if c land large <> 0 then 16 else 8
let char_height c = if c land fat_pixels <> 0 then 4 else if c land large <> 0 then 32 else 16
let overhang c = if c land italic <> 0 then char_width c / 2 else 0

(* a fat pixel's colour by its letter, and its byte in the palette *)
let pixel_letters = ".krgbyopna"
let pixel_bytes = "\255\000\240\042\054\252\231\129\130\136"

(* a row of fat pixels' letters as the kernel's bytes, joined two by
 * two (an unknown letter white) *)
let fat_bytes s =
  let rec byte c k = if k >= String.length pixel_letters then '\255' else if pixel_letters.[k] = c then pixel_bytes.[k] else byte c (k + 1) in
  let rec pieces i = if i >= String.length s then [] else String.make 1 (byte s.[i] 0) :: pieces (i + 1) in
  let rec pairs l = match l with a :: b :: rest -> (a ^ b) :: pairs rest | l -> l in
  let rec join l = match l with [] -> "" | [ x ] -> x | l -> join (pairs l) in
  join (pieces 0)

(* a sound: a wave, a pitch from hz to to_hz, so many milliseconds, a
 * volume falling to nothing (TinyKernelAudio.mli) *)
type wave = Square | Triangle | Sawtooth | Noise
type sound = { wave : wave; hz : int; to_hz : int; ms : int; volume : int }

(* a tune: its pace (the milliseconds of a unit), its parts, each a
 * wave, a volume and notes (a pitch in Hz, 0 a rest; a length in
 * units) *)
type part = { timbre : wave; level : int; notes : (int * int) list }
type tune = { pace : int; parts : part list }

(* a game: its picture's size; its first model, from a seed; the model
 * as shapes (the first ones under the next; the first of all is the
 * ground, below); the model after a key
 * (its byte: the arrows are 128 to 131, up, down, left, right), and
 * after a frame; the sounds of a change, from a model to the next; the
 * tune the model wants playing, if any *)
type 'm game = {
  width : int; height : int; init : int -> 'm; view : 'm -> shape list; key : int -> 'm -> 'm; frame : 'm -> 'm;
  sound : 'm -> 'm -> sound list; music : 'm -> tune option;
}

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

(* our images: 0 is the window, 1 the picture off it, 2 the ground, a
 * colour's byte c 3 + c *)
let picture = 1
let ground = 2
let made = Array.make 256 false
let ink c =
  let c = c land 255 in
  if not made.(c) then (made.(c) <- true; put (d_colour (3 + c) c));
  3 + c

let rec draw dst x y shape =
  match shape with
  | Rect (c, w, h) -> put (d_fill dst (ink c) x y (x + w) (y + h))
  | Words (c, s) ->
      put (if c < 256 then d_text dst (ink c) x y s
           else if c land fat_pixels <> 0 then d_styled dst (ink c) x y 16 (fat_bytes s)
           else d_styled dst (ink c) x y (c lsr 8) s)
  | Group l -> List.iter (draw dst x y) l
  | Move (dx, dy, s) -> draw dst (x + dx) (y + dy) s

(* A model's shapes, after those shown: the first one is the ground,
 * what is under the others and changes less (a game's field, where a
 * piece moves over it). It has an image of its own, drawn again only
 * when it is another ground; the picture is that image, a copy the
 * kernel makes, and the other shapes on it; then the picture goes on
 * the window. (old: every shape at each picture: a Tetris's hundred
 * cells, a hundred messages through two pipes, for a piece's move) *)
let show g shown shapes =
  (match shapes with
   | first :: rest ->
       if (match shown with was :: _ -> was != first && was <> first | [] -> true) then draw ground 0 0 first;
       put (d_draw picture ground (-1) 0 0 g.width g.height 0 0);
       List.iter (draw picture 0 0) rest
   | [] -> ());
  put (d_draw 0 picture (-1) 0 0 g.width g.height 0 0);
  flush ()

(* whether these are other shapes than those shown: the ground the same
 * value, or equal, and the rest equal *)
let same shown shapes =
  match shown, shapes with
  | was :: others, first :: rest -> (was == first || was = first) && others = rest
  | _ -> shown = shapes

(*****************************************************************************)
(* The sound *)
(*****************************************************************************)

(* a sound as tiny-kernel's /dev/audio takes it, a message
 * (TinyKernelAudio.mli): s, the wave, the pitch from and to, the
 * milliseconds, the volume *)
let sound_message snd =
  msg 's' [ (match snd.wave with Square -> 0 | Triangle -> 1 | Sawtooth -> 2 | Noise -> 3); snd.hz; snd.to_hz; snd.ms; snd.volume ]

(* samples, a byte each, signed, 8,000 a second, as /dev/audio takes them:
 * p, how many, then them *)
let samples_message s = msg 'p' [ String.length s ] ^ s

(* where they are played: tiny-kernel's speaker, -1 when there is none *)
let speaker = ref (-1)
let play sounds = if !speaker >= 0 && sounds <> [] then ignore (u_write !speaker (List.fold_left (fun acc snd -> acc ^ sound_message snd) "" sounds))

(* The music: a voice of /dev/audio a part (the kernel mixes them, and
 * the sounds), its next note, and the time its notes so far end at, in
 * ms of the kernel's clock. At each turn of the loop each part is given
 * its notes up to half a second ahead, a sound each (a rest a sound at
 * volume 0), and its voice plays them one after the other: so a tune is
 * a few messages a second, made into samples by the kernel. A part that
 * fell behind (the program busy) goes on from now. Another tune (a
 * level's faster pace) goes on from the same notes, as m-ix's
 * change_loop; none closes the voices, and the next tune starts at its
 * beginning. *)
type voice = { vfd : int; mutable vnext : int; mutable vuntil : int }
let voices = ref []
let ahead = 500

let feed pace p v now =
  let n = List.length p.notes in
  if v.vuntil < now then v.vuntil <- now;
  let rec gather acc =
    if n = 0 || v.vuntil >= now + ahead then acc
    else begin
      let (hz, len) = List.nth p.notes (v.vnext mod n) in
      let ms = len * pace in
      v.vnext <- (v.vnext + 1) mod n;
      v.vuntil <- v.vuntil + ms;
      gather (acc ^ sound_message { wave = p.timbre; hz; to_hz = hz; ms; volume = if hz = 0 then 0 else p.level })
    end in
  let m = gather "" in
  if m <> "" && v.vfd >= 0 then ignore (u_write v.vfd m)

let play_music tune =
  match tune, !voices with
  | None, [] -> ()
  | None, vs -> List.iter (fun v -> if v.vfd >= 0 then ignore (u_close v.vfd)) vs; voices := []
  | Some t, vs ->
      let now = u_ticks () * 5 / 2 in
      (match vs with [] -> voices := List.map (fun _ -> { vfd = u_open "/dev/audio" 1; vnext = 0; vuntil = now }) t.parts | _ -> ());
      let rec each parts vs = match parts, vs with p :: ps, v :: rest -> feed t.pace p v now; each ps rest | _ -> () in
      each t.parts !voices

(*****************************************************************************)
(* The loop *)
(*****************************************************************************)

(* A frame, in the kernel's ticks: a tick is 2.5 ms of the machine's
 * time whatever its speed, so 13 ticks are about a thirtieth of a
 * second. *)
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
    if model != seen then play (g.sound seen model);
    play_music (g.music model);
    let shapes = if model != seen then g.view model else shown in
    if not (same shown shapes) then show g shown shapes;
    if u_ready keys 1 next = 0 then begin
      let s = u_read 0 16 in
      if s = "" then exit 0;
      let rec typed i m = if i >= String.length s then m else if s.[i] = 'q' then exit 0 else typed (i + 1) (g.key (Char.code s.[i]) m) in
      loop (typed 0 model) model shapes next
    end
    else loop (g.frame model) model shapes (if u_ticks () > next + period then u_ticks () + period else next + period)
  in
  put (d_image picture 0 0 g.width g.height 0 ^ d_image ground 0 0 g.width g.height 0);
  speaker := u_open "/dev/audio" 1;
  let first = g.init (u_seed ()) in
  let shapes = g.view first in
  show g [] shapes;
  loop first first shapes (u_ticks () + period)
