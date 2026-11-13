(* XPM is a picture written as text: its palette, then its rows of
   characters.

   XPM (X PixMap) was written by Daniel Dardailler and Colas Nahaboo
   at Groupe Bull in 1989, for the icons of the X Window System, and
   Arnaud Le Hors took it on in 1990. The first version was C, and the
   second (1990) was plain text. The third (1991), the one still
   written, is C again: an array of strings that a program can #include
   and compile in, with the picture visible in the source:

     /* XPM */
     static char *hero[] = {
     "10 3 3 1",          width, height, colors, characters per pixel
     ". c None",          the palette: a character, then its color
     "R c #dc281e",       ('c': for a color display), None transparent
     "K c #643214",
     "...RRRR...",        the rows, one character per pixel
     "..RRRRRRR.",
     ".KKK...KKK"
     };

   That is exactly how the games here type their sprites (Sprite.pixels
   is strings and a palette of characters), and it is what makes XPM
   the file format for them: a sprite editor writes it, a text editor
   can edit it, GIMP and ImageMagick open and save it, and a game
   embeds it at build time (games/README-tools.md).

   The subset read here is what those tools write for small pictures:
   - one character per pixel;
   - a color given by its 'c' key, as None, as #rrggbb (or
     #rrrrggggbbbb, 16 bits a channel, of which the high byte is
     kept), or as one of a few names (black, white, red, green, blue);
   - the other keys ('m' monochrome, 'g' gray, 's' symbolic) are
     skipped.
   It does not read two or more characters per pixel (needed by
   pictures of more than 90 or so colors), the hotspot, the extensions
   (XPMEXT), or X11's 750 color names.

   It is independent of the Playground (its colors are RGB triples) and
   in pure OCaml, so the web backend can use it too. Sprite.of_xpm and
   Sprite.to_xpm convert to and from the Playground's colors.

   Where it stands in ix: lib_playground's Sprite reads it, for the
   games' pictures, and nothing else does. The three other readers
   beside it (Png, Jpeg, Gif) are for pictures that come from
   elsewhere. Plan 9 has the same idea in its own way: an image file
   (image(6), Display.file) starts with its format and rectangle as
   text, and a cursor or an icon is typed in C as hexadecimal rows.

   why-study:
   It is a picture format with no compression, no byte order, no chunk
   and no checksum, read and written in a hundred lines: what is left
   when a picture is small enough for none of these to matter. It shows
   what the other formats add. It also shows that a file one can read
   is a file one can fix and compare: a changed sprite is a changed
   line in the repository's history.

   Reference: Arnaud Le Hors, "XPM Manual, The X PixMap Format", version
   3.4 (Groupe Bull, 1996). *)
(* ix: copied from libs/graphics/images/xpm/Xpm.mli in the author's
 * playground (docs/plans/done/plan_playground.md) *)

(* a color: red, green, blue from 0 to 255, or None for transparent *)
type color = (int * int * int) option

(* a picture: the C array's name, the palette, and the rows from the
 * top *)
type t = { name : string; colors : (char * color) list; rows : string list }

(* [parse text] is the picture in an XPM file. For example, the one
 * above gives
 * { name = "hero"; colors = [ ('.', None); ('R', Some (220, 40, 30));
 * ('K', Some (100, 50, 20)) ]; rows = [ "...RRRR..."; ... ] }. Only the
 * strings count (between double quotes, outside comments), so the C
 * around them can be laid out any way. It raises Failure, saying what
 * is wrong, on what this subset does not read or on a picture that
 * does not add up (a row of the wrong width, a character not in the
 * palette). *)
val parse : string -> t

(* [print t] is the file, laid out as above. [parse] gives [t] back
 * when its colors are all in the forms that [print] writes (#rrggbb,
 * None). *)
val print : t -> string
