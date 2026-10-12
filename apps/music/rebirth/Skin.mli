(* A skin: mini-rebirth's panel as pictures (ix's own;
 * docs/plans/plan_audio.md, stage 6). The playground's TinyReBirth
 * draws its machines with flat rectangles and its toolkit's widgets;
 * Propellerhead's ReBirth RB-338 (1997), which it is after, was a
 * photograph of a rack: brushed aluminium, knobs that catch the light,
 * the TR-808's coloured keys. That look was most of its charm, and it
 * was a set of bitmaps a user could replace: a "mod" was a skin (and
 * new drum samples), hundreds were made, and the idea went from there
 * to the players and the instruments that followed.
 *
 * Here the bitmaps are not files and not the original's (which are
 * Propellerhead's): they are computed when first asked, a function of
 * a pixel's place for each kind of thing, from a palette:
 *
 *     a palette (the colours of      a skin: the pictures,
 *     each machine's metal, of  -->  made when first shown, kept
 *     its ink, of the lights)
 *        |
 *        +- panel k      brushed metal, lit from above: a streak a row
 *        |               (noise stretched along x), a bevel, a seam
 *        +- knob f       a cap and its skirt, shaded as a cone under a
 *        |               light at the top left, its pointer at f; one
 *        |               picture an angle (64 of them, as asked)
 *        +- key, cell    a step's button (the 808's four colours), a
 *        |               303's little window; lit or not
 *        +- lamp, switch, button, screw, rail, window
 *
 * So a skin is a few numbers, and another one is another palette:
 * [all] has the RB-338's (silver 303s, a black 808, a pale 909) and a
 * dark one. A picture is drawn by the playground as a Bitmap, at its
 * size in the playground's units: a pixel a unit in a window of 1000.
 *
 * The same pictures on every machine: the noise is a hash of the
 * pixel's place in integers of 30 bits, no random numbers, no floats
 * where a rounding could differ.
 *
 * design:
 * Computed, not drawn by hand and loaded: no picture file to carry on
 * the card, no reader to link, and a skin is text one can read. What
 * is lost is what a hand gives (a logo's lettering, a photograph's
 * dirt); a skin from files, as the original's mods, is the natural
 * next step (lib_graphics reads PNG).
 *
 * References: Propellerhead Software, ReBirth RB-338 (1997; free since
 * 2005, withdrawn in 2017 at Roland's request). *)

(* what a skin is made from: each panel's metal and ink (0 and 1 the
 * two 303s, 2 the 808, 3 the 909, 4 the effects, 5 the transport), the
 * 808's four colours of keys and the 909's one, the lamps, what a
 * window (a display) shows, and the wall behind the rack *)
type palette = {
  name : string;
  metal : (int * int * int) array;
  ink : (int * int * int) array;
  keys808 : (int * int * int) array;
  key909 : int * int * int;
  lamp : int * int * int;
  playing : int * int * int;
  glow : int * int * int;
  cap : int * int * int;
  wall : int * int * int;
}

type t

val make : palette -> t
val palette : t -> palette

(* the skins there are, the first the usual *)
val all : palette list

(* a colour of the palette, for the playground's shapes *)
val color : int * int * int -> Color.t

(* the colour of what is written on a button's cap *)
val on_cap : t -> Color.t

(* the panel [k], [w] by [h] pixels *)
val panel : t -> int -> int -> int -> Rgba_image.t

(* a knob of [d] pixels pointing at [fraction] (0 to 1, the toolkit's
 * angles: Look.knob_angle) *)
val knob : t -> int -> float -> Rgba_image.t

(* a drum machine's step key (the machine 2 or 3, the step), its lamp:
 * 0 off, 1 a hit, 2 the step playing *)
val key : t -> int -> int -> int -> Rgba_image.t

(* a 303's step window, the step playing or not *)
val cell : t -> bool -> Rgba_image.t

(* a switch (on: its lamp lit), a button of [w] by [h] (held or not), a
 * display's window of [w] by [h], a rail of [h] with its screws *)
val switch : t -> bool -> Rgba_image.t
val button : t -> int -> int -> Rgba_image.t
val window : t -> int -> int -> Rgba_image.t
val rail : t -> int -> Rgba_image.t
