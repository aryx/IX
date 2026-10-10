(* St_bitblt: Form and BitBlt, the one drawing primitive (Blue Book,
   chapter 18; Dan Ingalls, "The Smalltalk Graphics Kernel", Byte,
   August 1981).

   A Form is a picture of one bit per pixel, 1 black: its fields are
   its bits (a ByteArray, each row padded to 16 bits, as the Alto's
   words, most significant bit leftmost), its width and its height.

   BitBlt ("bit block transfer") copies a rectangle of a source Form
   onto a destination Form, combining each source bit s with the
   destination's bit d by one of 16 rules -- all the functions of two
   bits, the rule's number their truth table read from (s, d) = (0, 0):

     rule 0  0        clear         rule 3  s        store
     rule 1  s and d                rule 6  s xor d  reverse
     rule 4  not s and d  erase     rule 7  s or d   paint (under)
     rule 15 1        fill          ...

   the result's bit being (rule >> (3 - (2 s + d))) & 1. Before that,
   the source is and-ed with a halftone, a 16 by 16 pattern aligned on
   the destination (a gray); no source means all ones, no halftone
   too. And the whole is clipped to a rectangle.

   Everything the Smalltalk-80 display did -- text, windows, lines,
   scrolling, the cursor -- was this one primitive, called with
   different Forms and rules. Ingalls's version worked a 16-bit word
   at a time, shifting and masking the source's words onto the
   destination's. Here the definition is written a pixel at a time
   ([blit ~simple:true]), and what runs is the same a byte at a time,
   eight pixels by one and, or and not: the source's bits shifted to
   line up with the destination's bytes, a mask at each end of a row.
   A test checks that the two agree, on every rule.

   A BitBlt's fields: destForm sourceForm halftoneForm combinationRule
   destX destY width height sourceX sourceY clipX clipY clipWidth
   clipHeight.

   A rule read as its truth table, rule 6 (0110 in binary), reverse:

     s d   bit of 6          a cursor drawn with it over d = 1 0 1 1:
     0 0   0                   s        0 1 1 0
     0 1   1  d kept           d        1 0 1 1
     1 0   1                   d xor s  1 1 0 1    the cursor shows
     1 1   0  d reversed       again    1 0 1 1    and is gone: d is back

   which is why a cursor, a selection and a rubber band were drawn in
   reverse: what was under them needs no saving.

   Where it stands: St_primitives's 96, called by the kernel's BitBlt
   class (Graphics.st): a Form filled or shown, a Pen's line, a
   copyBits of its nib at each point, all come down to it. Squeak's
   system has St_colorblt.mli's instead, which is this one when every
   Form has one bit a pixel. The same primitive under another name is
   mini-9pi's draw (Memdraw, and lib_graphics's Draw for a program):
   one operation for the whole screen there too.

   cs-history:
   BitBlt was written by Dan Ingalls at Xerox PARC in 1975, for
   Smalltalk-72's overlapping windows on the Alto, whose screen was a
   bitmap in the machine's own memory, 606 by 808 bits. The name is
   an instruction's, in the style of the PDP-10's block transfer, BLT.
   Newman and Sproull's textbook (1979) called it RasterOp, the name
   the workstations took. It is what made a bitmap screen usable on a
   slow machine: one inner loop, in microcode, to make fast, and
   everything else on the screen written in the language above it.

   evolution:
   Rob Pike and Bart Locanthi's Blit terminal (Bell Labs, 1982) was
   named after it, and its bitblt went on into Plan 9. X11's graphics
   context has the same 16 functions, GXclear to GXset, and Windows's
   BitBlt 256, a pattern being a third input. With colour and an
   alpha, a function of bits says little, and the rules became those
   of compositing (Porter and Duff, 1984): Squeak added rules past 15
   (St_colorblt.mli), and Plan 9 replaced bitblt by draw, a source
   through a mask over a destination, in its third edition (2000).

   References: the Blue Book, chapter 18, "The Graphics Kernel", has
   BitBlt in Smalltalk, a word at a time: copyBits and its copyLoop
   are the specification. Dan Ingalls, "The Smalltalk Graphics
   Kernel" (Byte, August 1981). William Newman and Robert Sproull,
   "Principles of Interactive Computer Graphics" (second edition,
   1979). Rob Pike, Bart Locanthi and John Reiser, "Hardware/Software
   Trade-offs for Bitmap Graphics on the Blit" (Software: Practice
   and Experience, 1985): a bitblt compiled as it is called (from
   memory). *)

type oop = St_memory.oop

(* a Form's bits (each row [stride] bytes), width and height *)
type form = { bits : Bytes.t; w : int; h : int; stride : int }

(* a copy asked, BitBlt's own fields: the destination, the source if
 * any, the halftone if any, the rule (0 to 15), and where: the source's
 * (sx, sy) goes on the destination's (dx, dy) *)
type copy = { dest : form; source : form option; halftone : form option; rule : int; dx : int; dy : int; sx : int; sy : int }

(* [blit ~dest ~source ~halftone ~rule ~dx ~dy ~sx ~sy (x0, y0, x1, y1)]:
 * the destination's pixels of the rectangle (x0 and y0 in, x1 and y1
 * out; inside the Form), each combined with the source's pixel that
 * (sx, sy) puts on (dx, dy); no source, all ones. A Form may be its own
 * source. [~simple]: a pixel at a time, the definition. *)
val blit : simple:bool -> copy -> int * int * int * int -> unit

(* the primitive 96, copyBits: false if a field is not what it should *)
val copy_bits : St_memory.t -> oop -> bool

(* how many copyBits since the start: the host redraws the Display when
 * it changed *)
val changes : unit -> int

(* for St_colorblt, the same primitive with colours: one more copyBits,
 * and a field read as an integer (a Float rounded), if it is one *)
val count_change : unit -> unit
val int_field : St_memory.t -> oop -> int -> int option

(* a Form's width, height and pixels (true black), for the host *)
val form : St_memory.t -> oop -> (int * int * (int -> int -> bool)) option
