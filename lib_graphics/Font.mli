(* Text (Plan 9's fonts, the simplest of them: one subfont; libdraw's
 * defont.c and string.c; xix's Font and Text): a font is an image with
 * its characters side by side, a bit a pixel, and for each one where
 * it is there and how it sits on a line. A string is drawn a character
 * at a time, the font's image the mask of a colour. (Not libdraw's
 * cache of characters in the kernel, its 'i', 'l' and 's' messages:
 * for fonts of many subfonts.) *)

type t

(* a line's height; the pixels from its top to the letters' baseline *)
val height : t -> int
val ascent : t -> int

(* Plan 9's default font (Font_default's bytes), its image given to the display *)
val default : Display.t -> t

(* [string dst p color font s]: s drawn from p, the line's top left
 * corner; the point after it. The string's characters are UTF-8's
 * (Utf8); one the font has not is drawn as the font's first. *)
val string : Display.image -> Point.t -> Display.image -> t -> string -> Point.t
(* the string's width, in pixels *)
val width : t -> string -> int
