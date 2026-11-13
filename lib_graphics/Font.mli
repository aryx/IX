(* Text (Plan 9's fonts, in their simplest form, one subfont; libdraw's
 * defont.c and string.c; xix's Font and Text). A font is an image with
 * its characters side by side, a bit for each pixel, and a table that
 * says, for each character, where it is in the image and how it sits
 * on a line. A string is drawn one character at a time, with the
 * font's image as the mask of a colour. (There is no libdraw's cache of
 * characters in the kernel, with its 'i', 'l' and 's' messages: it is
 * for fonts of many subfonts.)
 *
 * The font's image is one strip, and a character is the columns from
 * its x to the next character's x:
 *
 *       x:   0      6     11  13      19
 *            +------+-----+--+------+---     top and bottom: the rows
 *            |  ##  |###  |  | ###  |        where the character has
 *            | #  # |#  # |# |#     |        pixels on; left: where it
 *            | #### |###  |  |#     |        starts from the pen (it
 *            | #  # |#  # |# |#     |        may be negative); width:
 *            | #  # |###  |# | ###  |        how far the pen then moves,
 *            +------+-----+--+------+---     not the count of columns
 *
 * So the table has one entry more than the font has characters, and the
 * last entry's x is the end of the image. A character without pixels
 * (the space) is two entries with the same x. Font_default's bytes are
 * that, as Plan 9 writes a subfont in a file:
 *
 *     5 numbers of 12 characters    the image: its depth (0 means a
 *                                   bit for each pixel) and its
 *                                   rectangle
 *     its rows                      (width + 7) / 8 bytes each
 *     3 numbers of 12 characters    n characters, the height, the ascent
 *     6 bytes, n + 1 times          x (2 bytes, the low one first),
 *                                   top, bottom, left, width
 *
 * Drawing a character is then one message to the device: Draw.draw with
 * three different images. The colour is src, the font's strip is the
 * mask, taken at (x, top), and on dst the rectangle is that many
 * columns wide, at the pen plus left. Nothing in the kernel knows what
 * a letter is.
 *
 * Here is where it stands: this is one of three kinds of font in ix.
 * Here a letter is a picture, right at one size and drawn by a copy;
 * the windows' text uses it (mini-rio, Menu, a terminal). Hershey's
 * letters are a pen's strokes, of any size. Truetype, Cff and Type1
 * read letters as outlines of curves, which are filled (Outline); a
 * PDF file's text uses them.
 *
 * wib:
 * There is one subfont, the 256 characters of Latin-1, held whole. A
 * font of Plan 9 is a small text file that lists ranges of characters,
 * and for each range the file of a subfont, which is read when a
 * character of the range is first drawn. So a font may cover all of
 * Unicode and cost only what the text on the screen uses. And libdraw
 * loads the characters used into an image in the kernel and sends a
 * string as one message, with the characters' numbers there, where
 * this module sends 45 bytes for each letter.
 *
 * cs-history:
 * The subfonts are why Plan 9 could be, in 1992, the first system in
 * which every program read and wrote Unicode. Ken Thompson and Rob Pike
 * designed UTF-8 for it (Utf8), and the fonts were made so that a
 * screen of Greek, Russian and Japanese needed neither a font of tens
 * of thousands of pictures in memory nor a program that knew which
 * characters were which.
 *
 * References: font(6) and subfont(2) of Plan 9's manual, for the file
 * read here and the cache not done; cachechars(2), for the cache; Rob
 * Pike and Ken Thompson, "Hello World" (USENIX, Winter 1993), on UTF-8
 * and the fonts of ranges. *)

type t

(* [height] is a line's height; [ascent] is the number of pixels from
 * its top to the letters' baseline *)
val height : t -> int
val ascent : t -> int

(* returns Plan 9's default font (Font_default's bytes), with its image
 * given to the display *)
val default : Display.t -> t

(* [string dst p color font s] draws s from p, the line's top left
 * corner, and returns the point after it. The string's characters are
 * in UTF-8 (Utf8); a character the font does not have is drawn as the
 * font's first one. *)
val string : Display.image -> Point.t -> Display.image -> t -> string -> Point.t
(* returns the string's width, in pixels *)
val width : t -> string -> int
