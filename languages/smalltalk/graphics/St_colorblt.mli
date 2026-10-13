(* St_colorblt: BitBlt in colour, Squeak's (Dan Ingalls again, 1996:
   "Back to the Future", section "BitBlt"; notes_squeak.md section 3).

   St_bitblt's Form has one bit a pixel. Squeak's has a depth, the
   bits of a pixel, its fourth field (nil, or none: 1):

     depth 1    a bit, 1 black                 rows padded to 16 bits
     depth 8    a byte, a colour's number in   rows padded to 32 bits
                a palette (Color.st's: 0
                transparent, then 6 by 6 by 6
                reds, greens and blues)
     depth 32   four bytes: alpha, red,        a row 4 * width bytes
                green, blue; alpha 0
                transparent, 255 opaque

   BitBlt is the same primitive, the same fourteen fields, a pixel now
   a number of 8 or 32 bits instead of one bit. Three things are new:

   - the 16 rules work on every bit of the two pixels: rule 3 still
     stores, rule 6 still reverses. And rules past 15, which are no
     longer functions of bits but arithmetic on a pixel's parts:

       rule 24  alpha blend: the source over the destination, as much
                as the source's alpha says (depth 32 only). For each
                of red, green and blue, a the source's alpha:

                  result = (s * a + d * (255 - a) + 127) / 255

                red (255, 0, 0) of alpha 128 over white: 255, then
                (0 * 128 + 255 * 127 + 127) / 255 = 127 twice: pink.
                The result's alpha: a + d's alpha * (255 - a) / 255.
       rule 25  paint: the source where it is not 0, the destination
                where it is -- a sprite, 0 its transparent colour.

   - the colour map, a fifteenth field: a table (a ByteArray, an entry
     for each value a source pixel may have, each a destination's
     pixel: 1 byte, 4 at depth 32) through which every source pixel
     goes first. It is how a Form of one depth is drawn on a Form of
     another, and how text gets a colour: the glyphs have one bit a
     pixel, the map says what 0 and 1 become -- nothing, and the ink.
     The source of a map has a depth of 1 or 8 (256 entries at most);
     with no map, the two Forms have the same depth.

   - the halftone is a Form of the destination's depth, of any size,
     repeated over it: a single pixel is a plain colour, and with no
     source, rule 3 fills a rectangle with it, rule 24 tints it.

   And the rectangle is clipped to the source too: what is outside the
   source Form is not drawn (St_bitblt reads white there).

   [blit ~simple:true] is the definition, a pixel at a time. What runs
   does the cases that are most of a screen's drawing faster: a
   rectangle filled with one colour and a Form stored as it is, a row
   at a time; a glyph, whose zeros are skipped a byte at a time. A
   test checks that they agree.

   A pixel of 32 bits is an OCaml int of 31 (an arm's has no more):
   its alpha on 7 bits, red, green and blue whole. Opaque and
   transparent are exact; an alpha in between loses its last bit when
   a pixel goes through a rule a pixel at a time (the rows copied
   whole do not). The code only shifts and masks it, and never
   compares two of them.

   Where it stands: the primitive 96 of Squeak's system
   (St_primitives), under everything Morphic draws (Squeak.mli); the
   hosts take the Display from [rgba], or from [bits32] with no copy.

   cs-history:
   Rule 24 is the "over" of Thomas Porter and Tom Duff ("Compositing
   Digital Images", SIGGRAPH 1984, at Lucasfilm), on the alpha channel
   that Ed Catmull and Alvy Ray Smith had added to a picture in the
   1970s: a fourth number a pixel, how much of it the pixel covers.
   Their paper keeps the colours already multiplied by the alpha, so
   that over is s + d * (1 - a) and a picture can be put over another
   and the result over a third in any grouping; the formula above
   multiplies as it draws, the simpler thing for a source that is one
   colour or one Form. The same Duff wrote rc (shell's CLI.mli).

   others:
   Plan 9's draw (Memdraw, lib_graphics's Draw) is this primitive
   after the same history, cut down further: in place of the rules,
   one operation, a source through a mask over a destination, the mask's
   alpha doing what the rule, the halftone and the colour map do
   here. A plain colour is an image of one pixel repeated, as the
   halftone above. Text is a mask with the ink as the source, where
   here it is a source of one bit and a map.

   terminology:
   Depth 8 is *indexed* colour: the pixel is a number in a table, the
   palette, and changing the table changes the picture. Depth 32 is
   *direct* colour: the pixel is the colour. A palette of 6 by 6 by 6
   is the 216 colours the first web browsers kept to on screens of
   256, for the same reason: every mix in equal steps.

   References: Dan Ingalls and others, "Back to the Future" (OOPSLA
   1997), the section on BitBlt: depths from 1 to 32 bits, and the
   BitBlt written in Smalltalk and translated to C. Thomas Porter and
   Tom Duff, "Compositing Digital Images" (SIGGRAPH 1984). draw(2)
   and draw(3) of Plan 9's manual. *)

type oop = St_memory.oop

(* a Form's bits (each row [stride] bytes), width, height and depth *)
type form = { bits : Bytes.t; w : int; h : int; stride : int; depth : int }

(* the bytes of a row: [stride ~depth w] *)
val stride : depth:int -> int -> int

(* a pixel read and written, at any depth; inside the Form *)
(* a pixel of 32 bits from its four bytes, and its alpha on 8 bits again
 * (see above: 31 bits here, the alpha on 7) *)
val pack : int -> int -> int -> int -> int
val alpha : int -> int

val get : form -> int -> int -> int
val put : form -> int -> int -> int -> unit

(* [combine ~rule ~depth s d]: the source's pixel on the
 * destination's. Rules 0 to 15, 24 (depth 32) and 25. *)
val combine : rule:int -> depth:int -> int -> int -> int

(* a copy asked, as St_bitblt's, with the map of the source's pixels to
 * the destination's, if any *)
type copy = { dest : form; source : form option; map : int array option; halftone : form option; rule : int; dx : int; dy : int; sx : int; sy : int }

(* as St_bitblt.blit: the destination's pixels of the rectangle (x0 and
 * y0 in, x1 and y1 out; inside the Form, and what (sx, sy) puts on it
 * inside the source), each combined with the source's pixel -- through
 * [map], an entry a pixel, if any; no source, all ones -- and-ed with
 * the halftone's. [~simple]: a pixel at a time, the definition. *)
val blit : simple:bool -> copy -> int * int * int * int -> unit

(* the primitive 96, copyBits, of a system whose Forms may have a
 * depth: St_bitblt's when every Form has one bit a pixel, no map and
 * a rule under 16. False if a field is not what it should, or the
 * depths do not go together. *)
val copy_bits : St_memory.t -> oop -> bool

(* a Form's width, height and pixels, for the host: four bytes a pixel,
 * red, green, blue and alpha, row after row, at any depth -- a bit
 * black or white, a number of the palette looked up *)
val rgba : St_memory.t -> oop -> (int * int * Bytes.t) option

(* a Form of 32 bits as it is, nothing copied, for a host that can show
 * it so: its width, its height, a row's bytes, and its pixels, four
 * bytes each (alpha, red, green, blue). None for another depth. *)
val bits32 : St_memory.t -> oop -> (int * int * int * Bytes.t) option
