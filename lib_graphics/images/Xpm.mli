(* XPM: a picture as text, its palette and its rows of characters.

   XPM (X PixMap) was written by Arnaud Le Hors at Groupe Bull in 1989,
   for the icons of the X Window System. Its third version (1991) made
   the file a piece of C, an array of strings a program could #include
   and compile in, the picture visible in the source:

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

   That is exactly how the games here type their sprites (Sprite.pixels:
   strings, and a palette of characters), and what makes XPM the file
   format for them: a sprite editor writes it, a text editor can edit
   it, GIMP and ImageMagick open and save it, and a game embeds it at
   build time (games/README-tools.md).

   The subset read here is what those tools write for small pictures:
   one character per pixel; a color given by its 'c' key, as None, as
   #rrggbb (or #rrrrggggbbbb, 16 bits a channel, of which the high byte
   is kept), or as one of a few names (black, white, red, green, blue);
   the other keys ('m' monochrome, 'g' gray, 's' symbolic) skipped. Not
   read: two or more characters per pixel (pictures of more than 90 or
   so colors), the hotspot and extensions (XPMEXT), X11's 750 color
   names.

   Independent of the Playground (colors are RGB triples), pure OCaml,
   so the web backend can use it too; Sprite.of_xpm and Sprite.to_xpm
   give it the Playground's colors.

   Where it stands in ix: read by lib_playground's Sprite, for the
   games' pictures, and by nothing else; the three other readers
   beside it (Png, Jpeg, Gif) are for pictures that come from
   elsewhere. Plan 9 has the same idea in its own way: an image file
   (image(6), Display.file) starts with its format and rectangle as
   text, and a cursor or an icon is typed in C as hexadecimal rows.

   why-study:
   A picture format with no compression, no byte order, no chunk and
   no checksum, read and written in a hundred lines: what is left when a
   picture is small enough for none of it to matter. It shows what
   the other formats add, and that a file one can read is a file one
   can fix and compare: a sprite changed is a line changed in the
   repository's history.

   Reference: Arnaud Le Hors, "XPM Manual, The X PixMap Format", version
   3.4 (Groupe Bull, 1996). *)
(* ix: the author's playground's libs/graphics/images/xpm/Xpm.mli (docs/plans/plan_playground.md) *)

(* a color: red, green, blue from 0 to 255, or None, transparent *)
type color = (int * int * int) option

(* a picture: the C array's name, the palette, the rows from the top *)
type t = { name : string; colors : (char * color) list; rows : string list }

(* [parse text]: the picture in an XPM file, e.g. the one above gives
 * { name = "hero"; colors = [ ('.', None); ('R', Some (220, 40, 30));
 * ('K', Some (100, 50, 20)) ]; rows = [ "...RRRR..."; ... ] }. Only the
 * strings count (between double quotes, outside comments), so the C
 * around them can be laid out any way. Raises Failure, saying what, on
 * what this subset does not read or a picture that does not add up (a
 * row of the wrong width, a character not in the palette). *)
val parse : string -> t

(* [print t]: the file, laid out as above; [parse] gives [t] back when
 * its colors are all in the forms [print] writes (#rrggbb, None) *)
val print : t -> string
