(* A tiny playground: the library that the games of TinyKernel.ml are
 * written with. It keeps the essentials of the author's playground
 * (the full-size version in ix is lib_playground/), which follows the
 * Elm architecture. It is a library written in the subset of ML that
 * both tiny-ml and OCaml accept, and it is given to tiny-ml before the
 * game itself (see plan_tiny_windows.md):
 *
 *     tiny-ml -tm -o tetris.tm calls.ml TinyLibDraw.ml TinyLibPlayground.ml TinyAppTetris.ml tetris.ml
 *     (the last one line: let () = run game)
 *
 * The main idea: {b a game is a value and three functions}. The value
 * is the model, everything the game knows. [view] turns the model into
 * shapes; [key] and [frame] return the new model after a key press and
 * after a thirtieth of a second. A game has no loop, does no drawing,
 * and keeps no state of its own: the library takes care of all that.
 * So a game can be tested without a screen (give it a model and some
 * keys, and check the resulting model), and its picture can be tested
 * without the machine (TinyKernelGraphics.ml draws the shapes on the
 * host).
 *
 *                 +------------ key -------------+
 *                 v                              |
 *     init --> a model --view--> shapes --> redrawn, only when
 *                 ^                              |    the shapes changed
 *                 +----------- frame ------------+
 *                    (every 13 kernel ticks)
 *
 * Here is a whole game, the smallest possible value of [game]: a
 * number in a white box, incremented by each key (the last line is the
 * program):
 *
 *     let game = {
 *       width = 64; height = 32;
 *       init = (fun seed -> 0);
 *       view = (fun n -> [ Rect (255, 64, 32);
 *                          Move (8, 8, Words (0, string_of_int n)) ]);
 *       key = (fun k n -> n + 1);
 *       frame = (fun n -> n) }
 *     let () = run game
 *
 * Its frame function returns its argument unchanged, so between two
 * keys the model stays the same value and view is not even called. A
 * key produces a new number, so only the second shape differs, and the
 * background, the same Rect as before, is not redrawn.
 *
 * What the library takes care of:
 *
 * - {b The loop}: it calls the kernel's ready on the keys until the
 *   time of the next frame; either a key or the time changes the model.
 * - {b Redrawing only when the picture changes}: a model that is the
 *   same value as before is not looked at (compared with !=, since a
 *   function that changes nothing returns its argument), and shapes
 *   equal to those already shown are not redrawn. The shapes are drawn
 *   in an off-screen image, which is then copied to the window in a
 *   single message: nothing flickers, and a window system only has to
 *   show one rectangle. The first shape, the background, is kept
 *   already drawn in an image of its own.
 * - {b The colours}: a shape's colour is a byte, an index in Plan 9's
 *   colour table; the image the kernel needs for that colour is
 *   created the first time it is used.
 *
 * What is dropped from the full playground: floating-point
 * coordinates under a transformation (move, scale, rotate, fade; here
 * a shape is in pixels, at integer positions, with y going down from
 * the top left corner of the window); circles, polygons and images;
 * text in several sizes (the machine has a single 8x16 font); sounds;
 * the mouse; subscriptions and commands (here a game receives every
 * key and every frame); time taken from the host (here a frame is 13
 * kernel ticks, which count machine instructions); and multiple
 * platforms (there is only one: the file descriptor the program draws
 * on).
 *
 * Exercises:
 * - the mouse: a fourth function, reading the program's descriptor 4;
 * - redraw only what changed, for every shape and not just the
 *   background, by comparing the shapes of two models;
 * - circles and polygons, using TinyKernelGraphics.ml's;
 * - a second game: a Snake, or a Pong.
 *
 * Where it stands: below it are TinyCalls (four kernel calls: write,
 * read, ready, ticks) and TinyLibDraw (the drawing messages); above it
 * is TinyAppTetris. It draws on its file descriptor 3 and reads keys on
 * its descriptor 0, so a game runs either on the whole screen or in a
 * window of TinyWindows without knowing which. Playground in
 * lib_playground is the full version, with floats, transformations,
 * the mouse and several platforms.
 *
 * cs-history:
 * Writing a program with a screen as a value plus a few functions on
 * it, with the loop in a library, started as a teaching tool. The
 * big-bang of How to Design Programs (Felleisen, Findler, Flatt and
 * Krishnamurthi, "A Functional I/O System", 2009) takes an initial
 * world and functions for a tick, a key and a picture, so that a
 * beginner can write a game without any assignment. Evan Czaplicki's
 * Elm (2012) started from a different idea, signals that vary over
 * time, but dropped them in 2016 for this shape: model, update, view.
 * From Elm it spread to JavaScript as Redux, and it is now the
 * standard way to explain how a web interface is structured.
 *
 * design:
 * Comparing two models by address before comparing their contents
 * (the != in [run], the == in [same]) is only correct because a model
 * is never mutated: the same address then always means the same
 * contents, forever, and comparing two words answers the question for
 * a whole data structure. With mutable data it would tell nothing.
 * Every system of this family makes the same bargain, and so do
 * TinyVCS's hashes: if things are never changed, knowing whether
 * something changed is free.
 *
 * References:
 *  - E. Czaplicki, "Elm: Concurrent FRP for Functional GUIs" (2012),
 *    and The Elm Architecture
 *  - Elm's Playground package (2019): a game as a model, a view and an
 *    update
 *)

(* what a view is made of: a rectangle (its width, its height, its
 * colour), a text in a colour, shapes together, a shape moved. A text's
 * colour is a byte, and above it the text's style, for the office's
 * words: its colour plus bold, italic, underlined, large (a character
 * 16 by 32), as many as it has *)
type shape = Rect of int * int * int | Words of int * string | Group of shape list | Move of int * int * shape
val bold : int
val italic : int
val underlined : int
val large : int

(* a text's character in its colour and style: its width, its height;
 * what of it is right of its cells (an italic's slant) *)
val char_width : int -> int
val char_height : int -> int
val overhang : int -> int

(* a game: its window's size, its first model from a seed, the model as
 * shapes, the model after a key and after a frame *)
type 'm game = { width : int; height : int; init : int -> 'm; view : 'm -> shape list; key : int -> 'm -> 'm; frame : 'm -> 'm }

(* The program of a game: its loop, with no end (a key or the next
 * frame's time waited for, the picture drawn when the shapes are
 * others) *)
val run : 'm game -> 'a

(* the number after a seed, 1 to 2^30 - 36 (Lehmer's generator) *)
val random : int -> int

(* a shape drawn in an image, its corner at (x, y): messages gathered,
 * which [flush] writes (TinyLibGUI's, which draws a widget and not a
 * picture) *)
val draw : int -> int -> int -> shape -> unit
val flush : unit -> unit

(* a picture: the shapes before (its first, the ground, drawn again
 * only when another), the shapes now; and the two images it is made
 * in, by their numbers (a test's) *)
val show : 'm game -> shape list -> shape list -> unit
val picture : int
val ground : int
