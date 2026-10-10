(* Text (Plan 9's fonts, the simplest of them: one subfont; libdraw's
 * defont.c and string.c; xix's Font and Text): a font is an image with
 * its characters side by side, a bit a pixel, and for each one where
 * it is there and how it sits on a line. A string is drawn a character
 * at a time, the font's image the mask of a colour. (Not libdraw's
 * cache of characters in the kernel, its 'i', 'l' and 's' messages:
 * for fonts of many subfonts.)
 *
 * The font's image is one strip, and a character is the columns from
 * its x to the next character's x:
 *
 *       x:   0      6     11  13      19
 *            +------+-----+--+------+---     top and bottom: the rows
 *            |  ##  |###  |  | ###  |        the character has pixels
 *            | #  # |#  # |# |#     |        on; left: where it starts
 *            | #### |###  |  |#     |        from the pen (it may be
 *            | #  # |#  # |# |#     |        negative); width: how far
 *            | #  # |###  |# | ###  |        the pen then moves, which
 *            +------+-----+--+------+---     is not the columns' count
 *
 * so the table has one entry more than the font has characters, the
 * last one's x the image's end, and a character without pixels (the
 * space) is two entries with the same x. Font_default's bytes are
 * that, as Plan 9 writes a subfont in a file:
 *
 *     5 numbers of 12 characters    the image: its depth (0: a bit a
 *                                   pixel) and its rectangle
 *     its rows                      (width + 7) / 8 bytes each
 *     3 numbers of 12 characters    n characters, the height, the ascent
 *     6 bytes, n + 1 times          x (2 bytes, the low one first),
 *                                   top, bottom, left, width
 *
 * A character drawn is then one message of the device's, Draw.draw
 * with three different images: the colour as src, the font's strip
 * as mask, taken at (x, top), and on dst the rectangle that many
 * columns wide at the pen plus left. Nothing in the kernel knows
 * what a letter is.
 *
 * Where it stands: this is one of three kinds of font in ix. Here a
 * letter is a picture, right at one size and drawn by a copy: the
 * windows' text (mini-rio, Menu, a terminal). Hershey's letters are
 * a pen's strokes, of any size. Truetype, Cff and Type1 read letters
 * as outlines of curves, filled (Outline): a PDF file's.
 *
 * wib:
 * One subfont, the 256 characters of Latin-1, held whole. A font of
 * Plan 9 is a small text file that lists ranges of characters and
 * for each the file of a subfont, read when a character of the range
 * is first drawn: a font may cover all of Unicode and cost what the
 * text on the screen uses. And libdraw loads the characters used
 * into an image in the kernel and sends a string as one message, the
 * characters' numbers there, where this sends 45 bytes a letter.
 *
 * cs-history:
 * The subfonts are why Plan 9 could be, in 1992, the first system
 * whose every program read and wrote Unicode: Ken Thompson and Rob
 * Pike designed UTF-8 for it (Utf8), and the fonts were made so that
 * a screen of Greek, Russian and Japanese needed neither a font of
 * tens of thousands of pictures in memory nor a program that knew
 * which characters were which.
 *
 * References: font(6) and subfont(2) of Plan 9's manual, the file
 * read here and the cache not done; cachechars(2), the cache; Rob
 * Pike and Ken Thompson, "Hello World" (USENIX, Winter 1993), UTF-8
 * and the fonts of ranges. *)

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
