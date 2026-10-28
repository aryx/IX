(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyKernelDevices.mli *)
open TinyKernelGraphics
open TinyKernelAudio
open TinyKernelMachine
open TinyKernelFiles

(*****************************************************************************)
(* The screen and the mouse (TinyKernelGraphics.ml draws) *)
(*****************************************************************************)

(* The screen is tiny-machine's 1024 by 768 bytes. The images live in the
 * two megabytes below it, and in what the screen leaves of its own
 * megabyte. (Most of the 3 MB below those, from 10 MB, is unused; it could be
 * the images' too. Trying it once changed the recorded paint session's
 * screen, which was taken for a bug: it was paint's ball, which moves
 * with the clock, ending elsewhere because the kernel's work took
 * another time.) The font is the machine's
 * (font.tm, in the image: fonts/plan9.font), its first face made a mask
 * at the boot. A program opens
 * /dev/draw for a connection, whose image 0 is the screen, and writes
 * messages; no pixel is in its partition. *)
let screen = { r = rect 0 0 1024 768; at = 0xf00000; repl = false }
(* the mouse's look a program asks for (www, over a link) is written to
 * the machine's mouse word, which the host shows *)
let () = cursor_hook := (fun kind -> poke mouse_dev kind)
let font =
  arena 0xd00000 0x200000;
  free 0xfc0000 0x3f000;   (* old: 0xf4b000 0xb4000, after 640 by 480 *)
  font_mask (k_font ()) (k_font_size ()) (alloc 16384)

(* the mouse: a box the kernel writes (x, y, the buttons, a word each)
 * when the machine's word changed; the clock: the timer's interrupts
 * counted *)
let mouse = { last = ""; fresh = false; posters = 1 }
let ticks = ref 0

(* the date: the boot's, and the seconds since, 400 ticks each (old:
 * none, the time of the day 0 for every program) *)
let date () = peek date_dev + (!ticks / 400)

(* the earliest time a waiting process asked to be told of (0: none) *)
let alarm = ref 0

(* the machine's time (k_clock's 30 bits) at the last tick counted *)
let counted = ref 0

(* The speaker (plan_tiny_audio.md): tiny-machine plays the ring, 8,192
 * samples, 8,000 a second, and silences what it played. Each open of
 * /dev/audio is a voice: a program writes messages, each a sound or
 * samples (TinyKernelAudio.mli), which the kernel makes into the ring,
 * added to what is there already, so two programs are heard at once and
 * neither waits for the other. A voice's sounds follow one another: the
 * next one goes where the last ended, or, when the speaker passed it, a
 * little ahead of the speaker ([lead], 5 ms, more than a write takes to
 * start); a write waits until all its sounds fit, a ring (a second)
 * ahead of the speaker at most. *)
let ring = 8192
let lead = 40
let played () = peek speaker_dev
let speak v sounds =
  let now = played () in
  if (v.ahead - now) land 0x3fffffff > ring then
    v.ahead <- (now + lead) land 0x3fffffff;
  let total =
    List.fold_left (fun acc snd -> acc + sound_length snd) 0 sounds in
  let missing = total - (ring - ((v.ahead - now) land 0x3fffffff)) in
  if missing > 0 then missing
  else begin
    List.iter (fun snd ->
      mix_sound ring_at ring v.ahead snd;
      v.ahead <- (v.ahead + sound_length snd) land 0x3fffffff) sounds;
    0
  end
