(* Scheme_image: HtDP's images as values, 2htdp/image's.

   How to Design Programs (Felleisen, Findler, Flatt and Krishnamurthi,
   2001; its second edition, 2018) starts with pictures, not numbers:
   (circle 10 "solid" "red") is a value, printed in DrScheme's
   Interactions as the red disc itself, and images compose --
   (beside (circle 10 "solid" "red") (square 20 "outline" "blue")) --
   the way numbers add. A child's first programs draw.

   An image here is its description, a tree, and what it knows is its
   size; drawing it is the host's (mini-drscheme draws it with the
   Playground's Bigbang way, playground/ways/Bigbang.mli, whose
   combinators are the same). So the language stays pure text and
   numbers, and a test can ask an image's width.

       beside a b     side by side, centered vertically
       above a b      one over the other, centered horizontally
       overlay a b    a on top of b, their centers together
       place-image a x y scene
                      a's center at (x, y) of the scene, from its
                      top-left corner, y going down; cut to the scene

   A text's width is estimated from its length, as the Bigbang way's
   is: the host's font is not the language's to measure.

       (beside (circle 10 "solid" "red") (square 20 "outline" "blue"))
         = Beside (Circle (10., Solid, "red"),
                   Rectangle (20., 20., Outline, "blue"))
         width 40, height 20: the widths added, the taller's height

   cs-history:
   Pictures as values that combine are Peter Henderson's "Functional
   Geometry" (1982): Escher's Square Limit from a few tiles and the
   operations beside, above and rot, each taking pictures and giving
   a picture. SICP took it as its example of a language built by
   combination (section 2.2.4, "A Picture Language"), and HtDP made
   it a child's first data type. The worlds over it (big-bang: a
   state, a function from it to a picture, a function to the next
   state at each tick) are from the same group: a program with a
   window and a clock, and no assignment anywhere.

   References: Peter Henderson, "Functional Geometry" (LISP and
   Functional Programming, 1982). Matthias Felleisen, Robert Findler,
   Matthew Flatt and Shriram Krishnamurthi, "A Functional I/O System,
   or, Fun for Freshman Kids" (ICFP 2009), for big-bang. The Racket
   documentation's 2htdp/image, whose names and argument orders
   these are. *)

type mode = Solid | Outline

type t =
  | Circle of float * mode * string (* radius, mode, colour name *)
  | Ellipse of float * float * mode * string
  | Rectangle of float * float * mode * string
  | Triangle of float * mode * string (* equilateral, its side *)
  | Text of string * float * string (* the string, its size, the colour *)
  | Scene of float * float (* empty-scene: white, framed *)
  | Beside of t * t
  | Above of t * t
  | Overlay of t * t
  | Place of t * float * float * t

val width : t -> float
val height : t -> float

(* the expression that makes it, (circle 10 "solid" "red"): how the
   teaching languages print an image in text, the stepper's *)
val to_string : t -> string
