(* Big bang brings the world programs of How to Design Programs on top
   of the Playground.

   How to Design Programs (Matthias Felleisen, Robert Bruce Findler,
   Matthew Flatt and Shriram Krishnamurthi, MIT Press, 2001, second
   edition 2018, free at https://htdp.org) teaches programming with
   pictures and games, in Racket, with two libraries. 2htdp/image has
   images that compose (a circle beside a square, above a text).
   2htdp/universe has [big-bang], which runs a "world program": a
   world (any value), a function that draws it, and functions that
   make the next world when time passes, when a key is pressed, or
   when the mouse moves. Its classic first game is a rocket landing:

     Racket:  (big-bang 0
                [to-draw (lambda (y) (place-image ROCKET 50 y SCENE))]
                [on-tick add1]
                [stop-when (lambda (y) (> y 300))])

     OCaml:   big_bang 0.
                ~to_draw:(fun y -> place_image rocket 50. y scene)
                { handlers with on_tick = Some (fun y -> y +. 1.);
                                stop_when = Some (fun y -> y > 300.) }

   (see examples/BigBangRocket.ml, and examples/BigBangWorm.ml, HtDP's
   worm game). Like Logo.mli, this module takes a way of programming
   from elsewhere, taught to children for decades, and makes it a
   layer of the playground.

   Big-bang is Elm's architecture before Elm (it is in HtDP's
   teachpacks from 2004; Elm is from 2012): the world is the model,
   [to_draw] is the view, and the handlers are the update. So
   [big_bang] is a thin layer over Playground.game, and what it adds
   is small but real:

   - Images that know their size, and compose ([beside], [above],
     [overlay], [place_image]): the playground's shapes don't carry
     their size, and every game places everything by hand. Here an image
     is a shape and its width and height.

   - Events rather than states: the playground says which keys are down
     (polling); big-bang calls [on_key] once when a key is pressed, with
     its name ("left", " ", "a"). The events come from comparing the keys
     down now with the ones down at the last frame ([key_events]). It
     is the same trick as Scene2d.pressed, and the way most event
     systems are built on top of hardware that only has states.

   - HtDP's coordinates in a scene: they start from its top-left
     corner, with y going down, as on most screens and in most drawing
     programs. The playground's are centered, with y going up.

   Is the playground a superset of big-bang, then? Almost, for the game
   loop: to_draw and on_tick are view and update (a slower tick rate is a
   counter), key and mouse events come from the states, and stop_when
   is a flag in the model. But not quite, because big-bang has four
   things:
     1. images measured, text included: HtDP can measure (text "Score"
        24 "black"); here a text's width is only estimated ([text]),
        because the playground's words are drawn by each backend's own
        font (the software rasterizer's Hershey font could measure them:
        an exercise);
     2. the final world as a value: in Racket, (big-bang ...) returns
        the last world when the program stops, so runs can follow each
        other and be tested; run_app returns nothing, and can't in a
        browser, where the loop is callbacks;
     3. images compared for equality, which HtDP's tests do
        ((check-expect (render w) ...)): shapes are data here, but
        nothing promises it;
     4. universe, several world programs and a server exchanging
        messages: Universe.mli (the worlds, this module's big_bang with
        a mailbox) and Universe_server.mli (the universe).
   And the playground has what big-bang doesn't: animations as functions
   of time (spin, wave), the screen's size, sound (Audio), 3D.

   Is it worth it? For a reader of HtDP, yes: its book, exercises and
   courses can be followed nearly line for line in OCaml. For others,
   it is a second way to write the same programs as Playground.game,
   and a beginner should not learn both: pick one. The book's real
   value is its design recipe (data definitions, signatures, examples
   written before the code), which is a way of teaching, not a
   library. The library is the small part, which is why this module
   is small and is not all of 2htdp. It has no pinholes and no
   alignment arguments ("top", "left"); its colors are the
   playground's rather than strings, and its modes are a variant
   rather than "solid" and "outline".

   Where it stands: BigBangRocket and BigBangWorm are written with
   it, and it is the screen of mini-drscheme (DrScheme), ix's small
   DrRacket. A Scheme program's images are drawn by this module's
   combinators, and its (big-bang ...) is run by the editor, which
   calls the handlers on ticks, keys and the mouse.

   cs-history:
   The book came out of a project, TeachScheme! (Felleisen and his
   students at Rice University, 1995), which held that a first
   course fails for two reasons that are not the student's: a
   language too big to give good error messages, and an environment
   made for professionals. Its answers were DrScheme (now DrRacket),
   with its ladder of teaching languages, each a subset that can say
   what was meant when it refuses a program, and the design recipe.
   Games came later and were a problem: a game reads the keyboard
   and draws, and the course was functional. big-bang is the
   solution -- the effects are the library's, the student writes
   only functions from a world to a world -- and it is the same
   solution Elm found for the browser some years on.

   References: the book (htdp.org); Felleisen, Findler, Flatt and
   Krishnamurthi, "A Functional I/O System, or, Fun for Freshman
   Kids" (ICFP 2009), the paper on big-bang and universe; Findler et
   al., "DrScheme: A Programming Environment for Scheme" (Journal of
   Functional Programming, 2002).
*)

open Playground

(*****************************************************************************)
(* {1 Images} *)
(*****************************************************************************)

(* an image: a picture that knows its width and height *)
type image

type mode = Solid | Outline

val circle : number -> mode -> color -> image (* its radius *)
val ellipse : number -> number -> mode -> color -> image (* width, height *)
val rectangle : number -> number -> mode -> color -> image
val square : number -> mode -> color -> image

(* an equilateral triangle, pointing up, with sides of this length *)
val triangle : number -> mode -> color -> image

(* [text str size color] is [size] pixels high. Its width is
 * estimated, at 0.6 of the size per character (see above). *)
val text : string -> number -> color -> image

(* a white scene framed in black, of this width and height, to place
 * images on *)
val empty_scene : number -> number -> image

(* [overlay top bottom] puts [top] over [bottom], with their centers
 * together. The result is as big as the bigger one. *)
val overlay : image -> image -> image

(* [beside a b] puts [a] left of [b], with their centers level. For
 * example, a 20 x 10 image beside a 30 x 40 one is 50 x 40. *)
val beside : image -> image -> image

(* [above a b] puts [a] over [b], with their centers aligned. A
 * 20 x 10 image above a 30 x 40 one is 30 x 50. *)
val above : image -> image -> image

(* [place_image i x y scene] puts [i]'s center at (x, y) in [scene],
 * counted from the scene's top-left corner, with y going down. The
 * result has the scene's size. What sticks out is not cut off, as
 * HtDP does, because the playground cannot clip. *)
val place_image : image -> number -> number -> image -> image

val width : image -> number
val height : image -> number

(* the image as a playground shape, centered on (0, 0) *)
val to_shape : image -> shape

(*****************************************************************************)
(* {1 Events} *)
(*****************************************************************************)

(* [key_events before now] gives the keys pressed since [before], and
 * the ones released, by their HtDP names: "left", "right", "up",
 * "down", " ", "\r", "escape", and the letters as themselves. For
 * example, with "ArrowLeft" down before, and "ArrowLeft" and "a" now,
 * it gives (["a"], []). *)
val key_events : keyboard -> keyboard -> string list * string list

(* [mouse_event before now] says what the mouse did since [before], by
 * its HtDP name ("button-down", "button-up", "drag", "move"), if it
 * did anything *)
val mouse_event : mouse -> mouse -> string option

(*****************************************************************************)
(* {1 The world} *)
(*****************************************************************************)

(* big_bang's model holds the world, and what it keeps to make
 * events *)
type 'w world

(* [big_bang init ~to_draw handlers] is the world program starting with
 * [init]. [to_draw] draws the world (its image centered on the
 * screen). [on_tick] makes the next world every [tick_rate] seconds
 * (1/60 means every frame; HtDP's default is 1/28). [on_key] and
 * [on_release] are called when a key is pressed and released, and
 * [on_mouse] when the mouse moves or its button goes down or up
 * ("button-down", "button-up", "drag", "move"), at (x, y) in the
 * scene's coordinates. [stop_when] ends it, drawing [last_picture] if
 * it is given.
 * ix: the handlers are a record, each Some f or None. [handlers] has
 * none and ticks every frame, so a program names the ones it has:
 *   big_bang 0. ~to_draw:draw { handlers with on_tick = Some next }
 * (In the playground they are optional arguments: ~on_tick:next.) *)
type 'w handlers = {
  on_tick : ('w -> 'w) option;
  tick_rate : number;
  on_key : ('w -> string -> 'w) option;
  on_release : ('w -> string -> 'w) option;
  on_mouse : ('w -> number -> number -> string -> 'w) option;
  stop_when : ('w -> bool) option;
  last_picture : ('w -> image) option;
}

val handlers : 'w handlers
val big_bang : 'w -> to_draw:('w -> image) -> 'w handlers -> ('w world game, msg) app
