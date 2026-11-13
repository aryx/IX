(* An icon as a text file, with one character per pixel and its colours
 * named first.
 *
 *     # a folder
 *     y e8b84a
 *     o a07820
 *     ................
 *     .oooo...........
 *     .oyyyo..........
 *
 * A palette line is a character, a blank and six hexadecimal digits.
 * '.' is no colour at all, and # starts a comment. Each row is as wide
 * as the first.
 *
 * design:
 * Icons are text for the same reason as Cursors: a diff shows what
 * changed, a person with an editor can draw one, and no program running
 * all the time has to link a picture decoder. This is how a 1983 icon
 * was made anyway, as squares on graph paper (Icons, in apps/files, says
 * more about that). *)

type t = {
  w : int;
  h : int;
  (* w * h pixels, 4 bytes each, as a r8g8b8a8 image is loaded: a, b, g, r *)
  pixels : string;
}

(* None when the text is not an icon: it has an unknown character, or
 * rows of two widths *)
val parse : string -> t option

(* the icon twice as wide and as high, each pixel made four: the size the
 * desk shows *)
val doubled : t -> t
