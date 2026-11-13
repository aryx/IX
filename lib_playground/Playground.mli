(* Playground is Elm's Playground in OCaml: pictures, animations and
   games made of shapes, in three steps, each of which is one
   function.

   A program says what is on the screen as a list of shapes. Each
   shape is a value built by a function ([circle red 20]) and changed
   by others ([move], [rotate], [fade]), and the last one is on top.
   Then:

     picture    shapes                                  a drawing
     animation  time -> shapes                          it moves
     game       computer -> memory -> shapes            it is played:
                computer -> memory -> memory            a view, an update,
                memory                                  where it starts

   Each step keeps what the one before taught and adds one idea: a
   function of time, then a memory and the computer (its mouse, its
   keys, its screen, its clock). Nothing else is to be learned to
   write Pong, and Tetris here is no more than that.

   Under the three is one type, [app], which is Elm's architecture: a
   model, a view of it, and an update that answers a message with a
   new model. The three steps are apps made for the program:

      the platform (Playground_platform: a window, or none)
        |  a frame is due, a key went down, the mouse moved
        v
      subscriptions (Sub)  --  a message  -->  update  -->  the model
                                                  |             |
                              a command (Cmd) <---+             v
                              the platform's to do            view
                                                                |
        the platform draws them   <----   a list of shapes  <---+
        (Shape_render_software: pixels; or the draw device's)

   For a [game] the model is the memory with the computer beside it,
   the messages are the events above folded into the computer, and
   the program's update is called at the tick with both. That is why
   a game reads [computer.keyboard.kleft] and never sees a message
   (Mvu.mli and Immediate.mli say what follows from that for an
   interface).

   A view gives back shapes, not pixels and not calls: the picture is
   data. So the same program runs on every platform, a test compares
   two frames by comparing two lists, a platform may draw again only
   where the list changed (Redraw), and a layer can be written over
   the library with no help from below: a camera is a moved group
   (Camera2d), a tile map is squares (Tilemap), and a widget is
   rectangles and words (Gui).

   Coordinates are the mathematician's and not the screen's: (0, 0)
   is the center, y goes up, and the screen is 1000 by 1000 units
   whatever the window. (Elm's screen is the window's pixels, and it
   was 600 by 600 in the first version of this port.)

   Where it stands. Most of what ix shows on a screen beyond the
   terminal goes through this file: the games, the examples, the
   office suite, mini-drscheme, and mini-netscape, whose page is a
   list of shapes too (Browser_draw). Below it is a platform; on
   mini-9pi that is Plan 9's draw device, in the kernel, by way of
   Plan9_loop.

   Here is what is ours, from the port's own notes (Playground.ml's
   prelude):
   Elm's Playground returns a tree of SVG and is run by the browser;
   here a view is the shapes and an [app] is a record that a platform
   runs, so that there is a platform without a browser. The parts of
   Elm's core it stands on were ported too (Basics, Color, Set, Time,
   Cmd, Sub) rather than replaced by OCaml's, to keep a game written
   for Elm a short way from here.

   cs-history:
   Elm's Playground (the package evancz/elm-playground) is by Evan
   Czaplicki, the author of Elm. It is made for a first hour of
   programming: there is no type to declare, no message and no HTML,
   and a triangle is on the screen in three lines. Its three
   functions are the lesson plan. This port is the author's
   ocaml-elm-playground, from which the playground repository and
   then this directory grew.

   others:
   Others had the same wish and gave other answers. Logo (Wally
   Feurzeig, Seymour Papert and Cynthia Solomon, 1967) has a turtle
   that is told to move and leaves a line; those are commands, where
   this module has values. Processing (Casey Reas and Ben Fry, 2001)
   and PICO-8 (2015) give the two functions of a game's loop (setup
   and draw, or _update and _draw), which change variables and call
   the screen. That is immediate, and there is no model to replay.
   How to Design Programs' big-bang (2004) is the nearest: a world,
   and functions of it (Bigbang.mli builds it over this module).

   References: Playground.elm's own documentation, from which the
   comments below are taken, example by example
   (github.com/evancz/elm-playground); the Elm guide
   (guide.elm-lang.org) for the architecture; the author's
   github.com/aryx/ocaml-elm-playground. *)

(*****************************************************************************)
(* ix: copied from playground/Playground.mli in the author's playground
 * (docs/plans/done/plan_playground.md) *)
(** {1 Entry points } *)
(*****************************************************************************)

(** The main entry points of this library are:
- {!val:picture}
- {!val:animation}
- {!val:game}

The important types are:
- {!type:shape}
- {!type:computer}

*)

(*****************************************************************************)
(** {1 Basic types} *)
(*****************************************************************************)

(** {2 Numbers} *)

(** A number like [1] or [3.14] or [-120].

It is more flexible to use [float] rather han [int] for graphical operations.
Consider using [open Basics] to have the [+], [-], and other
arithmetic operators working on floats instead of having to use
[+.], [-.], etc.
 *)
type number = float

(** {2 Time} *)

(** The current time.

Helpful when making an {!val:animation} with functions like
{!spin}, {!wave}, and {!zigzag}.
*)
type time = Time of number

(** Create an angle that cycles from 0 to 360 degrees over time.

Here is an {!val:animation} with a spinning triangle:

{[
    open Playground

    let view time =
      [ triangle orange 50
          |> rotate (spin 8 time)
      ]

    let app =
      animation view

    let main = Playground.run_app app
]}
It will do a full rotation once every eight seconds. Try changing the [8] to
a [2] to make it do a full rotation every two seconds. It moves a lot faster!
*)
val spin : number -> time -> number

(** Smoothly wave between two numbers.

Here is an {!val:animation} with a circle that resizes:
{[
    open Playground

    view time =
      [ circle lightBlue (wave 50 90 7 time)
      ]

    let app =
      animation view

    let main = Playground.run_app app
]}
The radius of the circle will cycles between 50 and 90 every seven seconds.
It kind of looks like it is breathing.
*)
val wave : number -> number -> number -> time -> number

(** Zig zag between two numbers.

Here is an {!val:animation} with a rectangle that tips back and forth:
{[
    open Playground

    view time =
      [ rectangle lightGreen 20 100
          |> rotate (zigzag -20 20 4 time)
      ]

    let app =
      animation view

    let main = Playground.run_app app
]}
It gets rotated by an angle. The angle cycles from -20 degrees to 20 degrees
every four seconds.
*)
val zigzag : number -> number -> number -> time -> number

(** {2 Colors} *)

(** Represents a color.

The colors below, like [red] and [green], come from the 
{{:https://en.wikipedia.org/wiki/Tango_Desktop_Project}Tango palette}.
It provides a bunch of aesthetically reasonable colors. Each color comes with a
light and dark version, so you always get a set like [lightYellow], [yellow],
and [darkYellow].
*)
type color = Color.t (* Hex of string | Rgb of int * int * int *)

(** RGB stands for Red-Green-Blue. With these three parts, you can create any
color you want. For example:
{[
    let brightBlue = rgb 18 147 216
    let brightGreen = rgb 119 244 8
    let brightPurple = rgb 94 28 221
]}
Each number needs to be between 0 and 255.

It can be hard to figure out what numbers to pick, so try using a color picker
like {{:http://paletton.com/}paletton} to find colors that look nice together. Once you find nice
colors, click on the color previews to get their RGB values.
*)
val rgb : int -> int -> int -> color

val white : color
val black : color
val red : color
val orange : color
val yellow : color
val green : color
val blue : color
val purple : color
val brown : color

val lightYellow : color
val lightPurple : color
val gray : color
val darkGray : color

(** The colors above, in rainbow order: [[red; orange; yellow; green; blue;
purple]]. *)
val rainbow : color list

(** {1:shapes Shapes } *)

(** Shapes help you make a [picture], [animation], or [game].

Read on to see examples of {!circle}, {!rectangle},
{!val:words}, {!image}, and many more!
*)
type shape = {
  x : number;
  y : number;
  angle : number;
  scale : number;
  alpha : number;
  form : form;
}
and form =
    Circle of color * number
  | Oval of color * number * number
  | Rectangle of color * number * number
  | Ngon of color * int * number
  | Polygon of color * (number * number) list
  | Image of number * number * string
  | Bitmap of number * number * Rgba_image.t
  | Pixels of number * number * pixels
  | Words of color * string
  | Letters of color * letters
  | Group of shape list

(* ix: a run of text in Hershey's strokes, as the browser and the word
 * processor draw it (Stroke_text). Each letter is at its place on a
 * baseline, and the run has a look: its size, bold (a wider pen), and
 * italic (a slant). A platform knows it is text, and may keep a
 * letter it has drawn (the software renderer keeps a mask per letter;
 * docs/notes/notes_font.md). *)
and letters = { size : number; bold : bool; italic : bool; baseline : number; at : (number * string) list }

(* ix: a picture in a palette's colours, one byte per pixel, row by
 * row from the top. Each byte is the index of its colour in the
 * palette (256 colours of r g b, so 768 bytes). A game that makes its
 * own pixels this way (mini-doom and mini-quake, with 320 by 200
 * bytes) gives them as they are, and each platform turns them, once,
 * into what its device wants: the screen's own format on Plan 9's
 * draw device (two bytes per pixel at 16 bits, from a table of 256),
 * and RGBA elsewhere (docs/plans/done/plan_playground_framebuffer.md,
 * F2). When it is shown at a whole multiple of its size, each pixel
 * becomes that many by that many; at another size it is scaled as a
 * Bitmap is. *)
and pixels = { pwidth : int; pheight : int; indices : Bytes.t; palette : string }

(** {2 Basic Shapes } *)

(** Make circles:
{[
    let dot = circle red 10
    let sun = circle yellow 300
]}
You give a color and then the radius. So the higher the number, the larger
the circle.
*)
val circle : color -> number -> shape

(** Make ovals:
{[
    let football = oval brown 200 100
]}
You give the color, and then the width and height. So our [football] example
is 200 pixels wide and 100 pixels tall.
*)
val oval : color -> number -> number -> shape

(** Make rectangles. This example makes a red cross:
{[
    open Playground

    let app =
      picture
        [ rectangle red 20 60
        ; rectangle red 60 20
        ]

    let main = Playground.run_app app
]}
You give the color, width, and then height. So the first shape is vertical
part of the cross, the thinner and taller part.
*)
val rectangle : color -> number -> number -> shape

(** Make squares. Here are two squares combined to look like an empty box:
{[
    open Playground

    let app =
      picture
        [ square purple 80
        ; square white 60
        ]

    let main = Playground.run_app app
]}
The number you give is the dimension of each side. So that purple square would
be 80 pixels by 80 pixels.
*)
val square : color -> number -> shape

(** Make triangles. So if you wanted to draw the Egyptian pyramids, you could
do a simple version like this:
{[
    open Playground

    let app =
      picture
        [ triangle darkYellow 200
        ]

    let main = Playground.run_app app
]}
The number is the "radius", so the distance from the center to each point of
the pyramid is [200]. Pretty big!
*)
val triangle : color -> number -> shape

(** Make pentagons:
{[
    open Playground

    let app =
      picture
        [ pentagon darkGray 100
        ]

    let main = Playground.run_app app
]}
You give the color and then the radius. So the distance from the center to each
of the five points is 100 pixels.
*)
val pentagon : color -> number -> shape

(** Make hexagons:
{[
    open Playground

    let app =
      picture
        [ hexagon lightYellow 50
        ]

    let main = Playground.run_app app
]}
The number is the radius, the distance from the center to each point.

If you made more hexagons, you could {!move} them around to make a
honeycomb pattern!
*)
val hexagon : color -> number -> shape

(** Make octogons:
{[
    open Playground

    let app =
      picture
        [ octagon red 100
        ]

    let main = Playground.run_app app
]}
You give the color and radius, so each point of this stop sign is 100 pixels
from the center.
*)
val octagon : color -> number -> shape

(** Make any shape you want! Here is a very thin triangle:
{[
    open Playground

    let app =
      picture
        [ polygon black [ (-10,-20), (0,100), (10,-20) ]
        ]

    let main = Playground.run_app app
]}
{b Note:} If you {!rotate} a polygon, it will always rotate around
[(0,0)]. So it is best to build your shapes around that point, and then use
{!move} or {!group} so that rotation makes more sense.
*)
val polygon : color -> (number * number) list -> shape

(** {2 Images } *)

(** Add some image from the internet:
{[
    open Playground

    let app =
      picture
        [ image 96 96 "https://elm-lang.org/images/turtle.gif"
        ]

    let main = Playground.run_app app
]}
You provide the width, height, and then the URL of the image you want to show.
*)
val image : number -> number -> string -> shape

(** Show an image that your program has in memory, its pixels
    ({!Rgba_image.t}: width x height RGBA bytes), stretched to the width
    and height you give. It can be a video's frames (TinyMediaPlayer), a
    picture your program decoded or computed, or a web page's pictures
    (TinyMosaic):
{[
    let view computer movie = [ bitmap 704. 576. (Movie.frame_at movie computer.time.now) ]
]}
    Where {!image} fetches a file once, this is drawn from its pixels as
    they are when it is shown, so give a new image for a new picture. (A
    backend keeps the images it converted, keyed by the image itself,
    up to some millions of pixels in all, and redoes the work for
    another image. So hundreds of small pictures in a frame, such as a
    page's letters, are fine.) A small image that is enlarged is
    smoothed, like {!image}'s, unless the program's [rendering] says
    [smooth_images = false]. On the web, each new image is encoded as a
    PNG, which is fine for a picture but slow for a video. *)
val bitmap : number -> number -> Rgba_image.t -> shape

(* ix: [pixels w h p] is a picture of palette indices (the type
 * pixels, above) in a box of w by h. As for a bitmap, give a new value
 * for a new picture (a platform compares a frame's shapes with the
 * last frame's). *)
val pixels : number -> number -> pixels -> shape

(** {2 Words } *)

(** Show some words!
{[
    open Playground

    let app =
      picture
        [ words black "Hello! How are you?"
        ]

    let main = Playground.run_app app
]}
You can use {!val:scale} to make the words bigger or smaller.
*)
val words : color -> string -> shape

(* ix: a run of letters (see the type [letters] above) *)
val letters : color -> letters -> shape

(**/**)
(* The font size (in playground units) and font family that the
 * backends use to render {!val:words}. They are not meant to be used
 * by applications (use {!val:scale} to change the size of some
 * words). *)
val words_font_size : number
val words_font_family : string
(**/**)

(** {2 Groups } *)

(** Put shapes together so you can {!move} and {!rotate}
them as a group. Maybe you want to put a bunch of stars in the sky:
{[
    open Playground

    let star =
      group
        [ triangle yellow 20
        ; triangle yellow 20
            |> rotate 180
        ]

    let app =
      picture
        [ star
            |> move 100 100
            |> rotate 5
        ; star
            |> move -120 40
            |> rotate 20
        ; star
            |> move 80 -150
            |> rotate 32
        ; star
            |> move -90 -30
            |> rotate -16
        ]
    let main = Playground.run_app app
]}
*)
val group : shape list -> shape

(** {2 Move Shapes } *)

(** Move a shape by some number of pixels:
{[
    open Playground

    let app =
      picture
        [ square red 100
            |> move -60 60
        ; square yellow 100
            |> move 60 60
        ; square green 100
            |> move 60 -60
        ; square blue 100
            |> move -60 -60
        ]

    let main = Playground.run_app app
]}
*)
val move : number -> number -> shape -> shape

(** Move shapes to the left.
{[
    open Playground

    let app =
      picture
        [ circle yellow 10
            |> moveLeft 80
            |> moveUp 30
        ]

    let main = Playground.run_app app
]}
*)
val move_left : number -> shape -> shape

(** Move shapes to the right.
{[
    open Playground

    let app =
      picture
        [ square purple 20
            |> moveRight 80
            |> moveDown 100
        ]

    let main = Playground.run_app app
]}
*)
val move_right : number -> shape -> shape

(** Move a shape up by some number of pixels. So if you wanted to make a tree
you could move the leaves up above the trunk:
{[
    open Playground

    let app =
      picture
        [ rectangle brown 40 200
        , circle green 100
            |> moveUp 180
        ]

    let main = Playground.run_app app
]}
*)
val move_up : number -> shape -> shape

(** Move a shape down by some number of pixels. So if you wanted to put the sky
above the ground, you could move the sky up and the ground down:
{[
    open Playground

    let app =
      picture
        [ rectangle lightBlue 200 100
            |> moveUp 50
        ; rectangle lightGreen 200 100
            |> moveDown 50
        ]

    let main = Playground.run_app app
]}
*)
val move_down : number -> shape -> shape

(** Move the [x] coordinate of a shape by some amount. Here is a square that
moves back and forth:
{[
    open Playground

    view time =
      [ square purple 20
          |> move_x (wave 4 -200 200 time)
      ]

    let app =
      animation view

    let main = Playground.run_app app
]}
Using [move_x] feels a bit nicer here because the movement may be positive or negative.
*)
val move_x : number -> shape -> shape

(** Move the [y] coordinate of a shape by some amount. Maybe you want to make
grass along the bottom of the screen:
{[
    open Playground

    let update computer memory =
      memory

    let view computer count =
      [ rectangle green computer.screen.width 100
          |> move_y computer.screen.bottom
      ]

    let app =
      game view update 0

    let main = Playground.run_app app
]}
Using [move_y] feels a bit nicer when setting things relative to the bottom or
top of the screen, since the values are negative sometimes.
*)
val move_y : number -> shape -> shape

(** {2:transformations Customize Shapes } *)

(** Make a shape bigger or smaller. So if you wanted some {!words} to
be larger, you could say:
{[
    open Playground

    let app =
      picture
        [ words black "Hello, nice to see you!"
            |> scale 3
        ]

    let main = Playground.run_app app
]}
*)
val scale : number -> shape -> shape

(** Rotate shapes in degrees.
{[
    open Playground

    let app =
      picture
        [ words black "These words are tilted!"
            |> rotate 10
        ]

    let main = Playground.run_app app
]}
The degrees go {b counter-clockwise} to match the direction of the
{{:https://en.wikipedia.org/wiki/Unit_circle} unit circle}.
*)
val rotate : number -> shape -> shape

(** Fade a shape. This lets you make shapes see-through or even completely
invisible. Here is a shape that fades in and out:
{[
    open Playground

    view time =
      [ square orange 30
      ; square blue 200
          |> fade (zigzag 0 1 3 time)
      ]

    let app =
      animation view

    let main = Playground.run_app app
]}
The number has to be between [0] and [1], where [0] is totally transparent
and [1] is completely solid.
*)
val fade : number -> shape -> shape

(*****************************************************************************)
(** {1 Computer } *)
(*****************************************************************************)

(* todo: group *)

val default_width : float
val default_height : float

(** Get the dimensions of the screen. If the screen is 800 by 600, you will see
a value like this:
{[
    { width = 800
    ; height = 600
    ; top = 300
    ; left = -400
    ; right = 400
    ; bottom = -300
    }
]}
This can be nice when used with {!move_y} if you want to put something
on the bottom of the screen, no matter the dimensions.
*)
type screen = {
  width : number;
  height : number;
  top : number;
  left : number;
  right : number;
  bottom : number;
}
val to_screen : number -> number -> screen

(** Figure out what is going on with the mouse.

You could draw a circle around the mouse with a program like this:
{[
    open Playground

    let view computer memory =
      [ circle yellow 40
          |> move_x computer.mouse.x
          |> move_y computer.mouse.y
      ]

    let update computer memory =
      memory

    let app =
      game view update 0

    let main = Playground.run_app app
]}
You could also use [computer.mouse.down] to change the color of the circle
while the mouse button is down.

[mdown] is the left (main) button. [mrdown], which is not in the
original Elm playground, is the right one (e.g. in TinyMinecraft, a
left click removes a block and a right click places one). [mmdown],
not in it either, is the middle one, the wheel pressed (e.g.
mini-soldat throws a grenade with it).

[mdx] and [mdy], not in the original Elm playground either, are how far
the mouse moved since the last frame (y up, like [my]), for turning a
first-person camera: unlike [mx]/[my], they keep counting when the
mouse is captured (hidden, and not stopped by the window's edges; see
{!Playground3d_platform.run_app3d}'s [capture_mouse]).
*)
type mouse = {
  mx : number;
  my : number;
  mdown : bool;
  (** Whether the button was {i released} this frame: a click is a
      press and a release, and it is the release that means "do it"
      (so a press you drag away from and release elsewhere is not a
      click on anything). It is a transient, like {!mdx}: the update
      that follows the release sees it, and the next tick clears it. *)
  mclick : bool;
  mrdown : bool;
  mmdown : bool;
  mdx : number;
  mdy : number;
  (** How far the wheel turned since the last frame, in notches,
      positive when scrolling up (away from you), [0.] most frames.
      It is not in Evan's playground, because a game never scrolls,
      and an application always does. *)
  mwheel : number;
  (** Whether this frame carried a double click. Like {!mclick}, but
      for the second click of a pair; the first one still arrives as an
      ordinary click, so a program that ignores [mdouble] behaves
      exactly as before. *)
  mdouble : bool;
}

(** Figure out what is going on with the keyboard.

If someone is pressing the UP and RIGHT arrows, you will see a value like this:
{[
    { kup = True, kdown = False, kleft = False, kright = True
    , kspace = False, kenter = False, kshift = False, kbackspace = False
    , keys = Set.fromList ["ArrowUp","ArrowRight"]
    }
]}

So if you want to move a character based on arrows, you could write an update
like this:
{[
    let update computer y =
      if computer.keyboard.kup then
        y + 1
      else
        y
]}
Check out {!to_x} and {!to_y} which make this even easier!

{b Note:} The [keys] set will be filled with the name of all keys which are
down right now. So you will see things like ["a"], ["b"], ["c"], ["1"], ["2"],
["Space"], and ["Control"] in there. Check out 
{{:https://developer.mozilla.org/en-US/docs/Web/API/KeyboardEvent/key/Key_Values}this list} to see the
names used for all the different special keys! From there, you can use
[Set.member] to check for whichever key you want. E.g.
[Set.member "Control" computer.keyboard.keys].
*)
type keyboard = {
  kup : bool;
  kdown : bool;
  kleft : bool;
  kright : bool;
  kw : bool;
  ks : bool;
  ka : bool;
  kd : bool;
  kspace : bool;
  kenter : bool;
  kshift : bool;
  kbackspace : bool;
  (** Every key held right now, by name. The names are the browser's
      ({{:https://developer.mozilla.org/en-US/docs/Web/API/KeyboardEvent/key/Key_Values}this
      list}): ["a"], ["1"], ["ArrowUp"], ["Backspace"], ["Enter"],
      ["Tab"], ["Shift"], ["Escape"], whatever backend the program
      runs on, since a native SDL name ("Return", "Left Shift") is
      translated to it. The one exception is the space bar, which is
      ["space"] here and not [" "].

      [Set_.mem "x" computer.keyboard.keys] asks whether a key is
      down; the frame a key {i goes} down (its rising edge) takes
      remembering the frame before, which {!Scene2d.pressed} does. *)
  keys : string Set_.t;
  (** The characters {i typed} this frame, in order: [""] in most
      frames, ["a"] for one key, and more when a key repeats.

      This is not the same question as {!keys}, and the difference is
      the reason it exists: [keys] holds key {i names} ("a", "shift",
      "ArrowLeft"), which is what a game asks ("is left held?"), while
      a text field needs the {i character} a key press produced --
      ["A"] rather than ["a"] with shift, ["e"] with an accent from a
      dead key, whatever a non-US layout puts on that key. Only the
      platform knows that, so it tells us here.

      It is a transient, consumed by the update that sees it:
      {[
        let update computer model =
          { model with name = model.name ^ computer.keyboard.typed }
      ]} *)
  typed : string;
}

(** Turn the LEFT and RIGHT arrows into a number.
{[
    to_x { left = False, right = False, ... } == 0
    to_x { left = True , right = False, ... } == -1
    to_x { left = False, right = True , ... } == 1
    to_x { left = True , right = True , ... } == 0
]}
So to make a square move left and right based on the arrow keys, we could say:
{[
    open Playground

    let view computer x =
      [ square green 40
          |> move_x x
      ]

    let update computer x =
      x + to_x computer.keyboard


    let app =
      game view update 0
    let main = Playground.run_app app
]}
*)
val to_x : keyboard -> number

(** Turn the UP and DOWN arrows into a number.
{[
    to_y { up = False, down = False, ... } == 0
    to_y { up = True , down = False, ... } == 1
    to_y { up = False, down = True , ... } == -1
    to_y { up = True , down = True , ... } == 0
]}

This can be used to move characters around in games just like {!to_x}:
{[
    open Playground

    let view computer (x,y) =
      [ square blue 40
          |> move x y
      ]

    let update computer (x,y) =
      ( x + to_x computer.keyboard
      , y + to_y computer.keyboard
      )

    let app =
      game view update (0,0)

    let main = Playground.run_app app
]}
*)
val to_y : keyboard -> number

val to_x2 : keyboard -> number

val to_y2 : keyboard -> number

(** If you just use [to_x] and [to_y], you will move diagonal too fast. You will go
right at 1 pixel per update, but you will go up/right at 1.41421 pixels per
update.

So [to_xy] turns the arrow keys into an [(x,y)] pair such that the distance is
normalized:
{[
    to_xy { up = True , down = False, left = False, right = False, ... } == (1, 0)
    to_xy { up = True , down = False, left = False, right = True , ... } == (0.707, 0.707)
    to_xy { up = False, down = False, left = False, right = True , ... } == (0, 1)
]}

Now when you go up/right, you are still going 1 pixel per update.
{[
    open Playground

    let view computer (x,y) =
      [ square green 40
          |> move x y
      ]

    let update computer (x,y) =
      let
        (dx,dy) = to_xy computer.keyboard
      in
      (x + dx, y + dy)

    let app =
      game view update (0,0)

    let main = Playground.run_app app
]}
*)
val to_xy : keyboard -> number * number

(** When writing a {!game}, you can look up all sorts of information
about your computer:

  - {!type:mouse} - Where is the mouse right now?
  - {!type:keyboard} - Are the arrow keys down?
  - {!type:screen} - How wide is the screen?
  - {!type:time} - What time is it right now?
  - {!type:flags} - What parameters was the program started with?

So you can use expressions like [computer.mouse.x] and [computer.keyboard.kenter]
in games where you want some mouse or keyboard interaction.
*)
type computer = {
  mouse : mouse;
  keyboard : keyboard;
  screen : screen;
  time : time;
  flags : flags;
}

(** The parameters a program was started with, as [(name, value)] pairs,
    e.g. [[("level", "5"); ("fast", "")]] (a parameter given without a
    value has [""]). They come from outside the program, like Elm's
    flags: the program's [main] reads them with
    [Playground_platform.flags caps] and gives them to
    [Playground_platform.run_app caps flags app]; then every [view] and
    [update] sees them in [computer.flags], unchanged from start to end.

    Natively, they are the command line's arguments without a dash,
    [name=value] or [name] ([dune exec games/arcade/Snake.exe -- level=5 fast]);
    the dashed ones are the playground's own ([-debug], ...). On the
    web, they are the page's URL parameters ([Snake.html?level=5&fast]).

    For example, a game running twice as fast with [speed=fast]:
{[
    let update computer memory =
      let speed =
        match List.assoc_opt "speed" computer.flags with
        | Some "fast" -> 2.
        | _ -> 1.
      in
      ...

    let main caps =
      Playground_platform.run_app caps (Playground_platform.flags caps) app
]}
*)
and flags = (string * string) list

val initial_computer : computer

(**/**)
(* [update_keyboard is_down key keyboard] is the keyboard after a key
 * went down or up, as the platforms make it from their events. It is
 * exported for tinybox's 3D previews, which make a computer
 * themselves. *)
val update_keyboard : bool -> string -> keyboard -> keyboard
(**/**)

(**/**)
(* [flags_of_strings] turns ["level=5"; "fast"] into
 * [("level", "5"); ("fast", "")], splitting at the first '=' and
 * skipping empty strings. This is how the backends turn command-line
 * arguments or URL parameters into flags; it is not meant to be used
 * by applications. *)
val flags_of_strings : string list -> flags
(**/**)


(*****************************************************************************)
(** {1 Randomness} *)
(*****************************************************************************)

(** Random numbers are kept in the model, as in Elm's [Random] without
    the command: a {!seed} is a value, and each draw gives a number and
    the next seed, to keep for the next draw.
{[
    type model = { x : number; seed : seed }

    let update computer model =
      if computer.mouse.click then
        let x, seed = random (-400.) 400. model.seed in
        { x; seed }
      else model

    let app = game view update { x = 0.; seed = initial_seed 42 }
]}
    The same seed gives the same numbers, in every run and on every
    backend, native or web: a game replays the same way (golden frames,
    a bug caught again), and two computers given one seed draw the same
    numbers (plan_networking_teaching.md). OCaml's [Random] gives none
    of that: it has a hidden global state, seeded from the clock. The
    generator is random/Lehmer.mli (Park and Miller's minimal standard). *)
type seed

(** [initial_seed n] makes a seed from any number, e.g. the flag
    seed=n, or the clock at the start for a game that is different each
    time. The seed is made once, then kept in the model. *)
val initial_seed : int -> seed

(** [random lo hi seed] gives a number between [lo] and [hi] ([hi] not
    included), and the next seed. *)
val random : number -> number -> seed -> number * seed

(** [random_int lo hi seed] gives an integer from [lo] to [hi], both
    included. *)
val random_int : int -> int -> seed -> int * seed

(** [pick l seed] gives one of the list's elements (the list must not
    be empty). *)
val pick : 'a list -> seed -> 'a * seed

(*****************************************************************************)
(** {1 The Application} *)
(*****************************************************************************)

(** [init] is given the program's {!flags} (see [Playground_platform.run_app]) *)
type ('model, 'msg) app = {
  init : flags -> 'model * 'msg Cmd.t;
  update : 'msg -> 'model -> 'model * 'msg Cmd.t;
  view : 'model -> shape list;
  subscriptions : 'model -> 'msg Sub.t;
}

(* ix: two things of the playground are not here. One is its any_app
 * and capture, a GADT, which mini-ml does not have; it is a hook for
 * the playground's launcher, not for programs. The other is its
 * module Http (Elm's: a command that asks a server, with the
 * program's Cap.network), which waits until a game here asks the
 * network something. A program that names them does not compile. *)

(** How to draw, for the backends that can honor it, given to
    [Playground_platform.run_app ~rendering]:
    - [antialiasing]: smooth edges (true), or all-or-nothing pixels,
      crisper but jagged (false);
    - [smooth_images]: enlarged images blend their pixels (true), or
      show them as sharp squares (false), which is what pixel art
      sprites, like Mario's, want.

    Each backend maps these to what it has (the software rasterizer
    to its own algorithms, Cairo to its antialias mode and image
    filter, the web to SVG's [shape-rendering] and CSS's
    [image-rendering]), and the software rasterizer's debug keys can
    still change them while the app runs: these are the starting
    values.

    In ix, [run_app] takes no [~rendering]: every platform starts from
    [default_rendering]. *)
type rendering = { antialiasing : bool; smooth_images : bool }

(** Both on *)
val default_rendering : rendering

(** How the program's window behaves, given to
    [Playground_platform.run_app ~window]. A game uses the default
    ([default_window]), and an application changes some of it:

    {[
      (* a game: nothing to say *)
      Playground_platform.run_app app

      (* an application (a browser): its screen is the window, it is
         drawn only when it changes *)
      Playground_platform.run_app
        ~window:{ Playground.default_window with follows_window = true; skip_same_view = true } app
    ]}

    - [screen_size] is the program's screen, for a program made for
      another shape (tinybox's menu, 16:9). None means [default_width]
      by [default_height], 1000 by 1000. (It is not called [screen],
      because that is [computer]'s field, and a program that opens
      Playground writes [computer.screen].) The window starts at that
      shape, and the program is told its size at once ([Sub.on_resize],
      which [game] follows in [computer.screen]). The window still
      scales the picture to fit it, whatever its size. For now, the
      native Cairo platform and the web's (where the browser letterboxes
      it) honor it; the others keep 1000 by 1000.
    - [follows_window] (false) is for an application rather than a
      game: the program's screen is the window itself, as large as the
      user makes it, drawn 1 to 1, with no scaling and no black bars.
      The program is told its size before the first frame and each time
      the window changes ([Sub.on_resize]), and lays itself out again
      (a browser's page at its new width). [screen_size] is then the
      size the window starts at. The native platforms honor it (Cairo's
      and the software one, whose window otherwise never changes size);
      the web's ignores it.
    - [platform_keys] (true) lets the native platforms keep some keys
      for themselves, all with Ctrl, so that a plain key is always the
      program's (a "q" typed in a field). Ctrl+Q quits, and with
      -debug-keys, Ctrl and a key is one of the software platform's
      debug keys. Set it to false for an application that wants every
      key (its own Ctrl+Q): the platform then keeps none, and
      -debug-keys and -keys do nothing. Alt+Enter (full screen) and the
      window's close box are the window's, either way. The web's
      platform ignores it, since the page has no such keys.
    - [skip_same_view] (false), for an application rather than a game:
      a frame whose view is the very list of the frame before
      (physically, [==]) is not drawn again, unless something happened
      to the window since (a key, the mouse, its size, its being
      uncovered). A game's view is a new list at each frame and is
      always drawn. An application at rest (a page being read) then
      costs no drawing at all, instead of a whole frame's drawing sixty
      times a second, provided its view takes the care to give back the
      same list when what it reads of its model is the same. The
      program promises with it that its picture depends on nothing
      else: no animated picture (a GIF's frames are the platform's to
      change), no picture still to come. -uncapped and -debug-keys
      (which measure, and draw their own overlays) draw every frame
      anyway. The native platforms honor it; the web's ignores it (vdom
      already changes only what differs).

    It is a record rather than as many arguments of [run_app]: they are
    set together, once, by the few programs that are not games, and
    there will be others.

    In ix, [run_app] takes no [~window], and no program uses this
    record: a program that wants its screen to be the window asks for
    it with the flag window (Session.window says how). *)
type window = { screen_size : (int * int) option; follows_window : bool; platform_keys : bool; skip_same_view : bool }

(** A game's window: 1000 by 1000 scaled to the window, Ctrl+Q quits,
    and every frame is drawn *)
val default_window : window

(** What the mouse's cursor looks like over the window, set with
    [Playground_platform.set_cursor]:

    - [Arrow], the usual one;
    - [Hand], over what a click follows or presses: a link, a button
      (CSS's [cursor: pointer]);
    - [Text], the I-beam, over text that can be typed in or selected;
    - [Crosshair], for aiming and for drawing;
    - [Hidden], none: a game that draws its own (a sight, a brush) at
      [mouse.x], [mouse.y], or that has no use for one.

    These are the system's own shapes, not pictures of ours: they look
    as every other program's on the machine. *)
type cursor = Arrow | Hand | Text | Crosshair | Hidden

(*****************************************************************************)
(** {1 Playgrounds} *)
(*****************************************************************************)

(** {2 Pictures} *)

type msg1 = Resized1 of int * int

(** Make a picture! Here is a picture of a triangle with an eyeball:
{[
    open Playground

    let app =
      picture
        [ triangle green 150
        ; circle white 40
        ; circle black 10
        ]

    let main = Playground.run_app app
]}
*)
val picture : shape list -> (screen, msg1) app

(** {2 Animations} *)

type msg =
    Tick of number
  | Resized of int * int
  | KeyChanged of bool * string
  | MouseMove of (number * number)
  | MouseMoveBy of (number * number)
  | MouseClick
  | MouseButton of bool
  | RightMouseButton of bool
  | MiddleMouseButton of bool
  | Typed of string
  | MouseWheel of number
  | MouseDouble

type animation

(** Create an animation!

Once you get comfortable using {!val:picture} to layout shapes, you can
try out an [animation]. Here is square that zigzags back and forth:
{[
    open Playground

    view time =
      [ square blue 40
          |> move_x (zigzag -100 100 2 time)
      ]

    let app =
      animation view

    let main = Playground.run_app app
]}
We need to define a [view] to make our animation work.

Within [view] we can use functions like {!spin}, {!wave},
and {!zigzag} to move and rotate our shapes.
*)
val animation : (time -> shape list) -> (animation, msg) app

(** {2 Games} *)

type 'memory game

(** Create a game!

Once you get comfortable with {!val:animation}, you can try making a
game with the keyboard and mouse. Here is an example of a green square that
just moves to the right:
{[
    open Playground

    let view computer offset =
      [ square green 40
          |> moveRight offset
      ]

    let update computer offset =
      offset + 0.03

    let app =
      game view update 0

    let main = Playground.run_app app
]}
This shows the three important parts of a game:
+ [memory] - makes it possible to store information. So with our green square, we save the [offset] in memory. It starts out at [0].
+ [view] - lets us say which shapes to put on screen. So here we move our square right by the [offset] saved in memory.
+ [update] - lets us update the memory. We are incrementing the [offset] by a tiny amount on each frame.

The [update] function is called about 60 times per second, so our little
changes to [offset] start to add up pretty quickly!

This game is not very fun though! Making a [game] also gives you access to the
{!Computer}, so you can use information about the {!type:mouse}
and {!type:keyboard} to make it interactive! So here is a red square that
moves based on the arrow keys:
{[
    open Playground

    let view computer (x,y) =
      [ square red 40
          |> move x y
      ]

    let update computer (x,y) =
      ( x + to_x computer.keyboard
      , y + to_y computer.keyboard
      )

    let app =
      game view update (0,0)

    let main = Playground.run_app app
]}
Notice that in the [update] we use information from the keyboard to update the
[x] and [y] values. These building blocks let you make pretty fancy games!
*)
val game :
  (computer -> 'memory -> shape list) ->
  (computer -> 'memory -> 'memory) -> 'memory -> ('memory game, msg) app
