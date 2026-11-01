(* An icon as a text file: a character a pixel, its colours named first.
 *
 *     # a folder
 *     y e8b84a
 *     o a07820
 *     ................
 *     .oooo...........
 *     .oyyyo..........
 *
 * A palette line is a character, a blank, six hexadecimal digits; '.' is
 * no colour at all; # starts a comment. Each row as wide as the first.
 *
 * design:
 * Text, for the same reason as Cursors: a diff shows what changed, a
 * person with an editor can draw one, and no program running all the time
 * has to link a picture decoder. This is how a 1983 icon was made anyway,
 * squares on graph paper (Icons, in apps/files, says more of that). *)

type t = {
  w : int;
  h : int;
  (* w * h pixels, 4 bytes each, as a r8g8b8a8 image is loaded: a, b, g, r *)
  pixels : string;
}

(* None when the text is no icon: an unknown character, rows of two widths *)
val parse : string -> t option
