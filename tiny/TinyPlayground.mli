(* A tiny playground: what a game of TinyKernel.ml's is written on, the
 * essential of the author's playground (ix's twin is lib_playground/),
 * which is Elm's architecture. A library, in tiny-ml's ML and OCaml's,
 * given to tiny-ml before the game (plan_tiny_windows.md):
 *
 *     tiny-ml -tm -o tetris.tm calls.ml TinyDraw.ml TinyPlayground.ml TinyTetris.ml tetris.ml
 *     (the last one line: let () = run game)
 *
 * The idea kept: {b a game is a value and three functions}. Its model,
 * all that it knows; [view], the model as shapes; [key] and [frame],
 * the model after a key and after a thirtieth of a second. No loop, no
 * drawing, no state of its own: the library has them. So a game is
 * tested without a screen (a model, some keys, the model after), and
 * its picture without a machine (the shapes drawn by TinyGraphics.ml on
 * the host).
 *
 *                 +------------ key -------------+
 *                 v                              |
 *     init --> a model --view--> shapes --> the picture, when they
 *                 ^                              |    are other shapes
 *                 +----------- frame ------------+
 *                    (13 of the kernel's ticks)
 *
 * A whole game, a number in a white box that each key makes one more
 * (the smallest value of [game]; the last line is the program):
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
 * Its frame gives its argument back, so between two keys the model is
 * the same value and view is not even called; a key makes another
 * number, the shapes differ in their second, and the ground, the
 * same Rect, is not drawn again.
 *
 * What is the library's:
 *
 * - {b The loop}: the kernel's ready on the keys until the next frame's
 *   time; a key or the time changes the model.
 * - {b The picture, when it is another one}: a model that is the same
 *   value as before is not looked at (!=: a function that changes
 *   nothing gives its argument back), and shapes equal to those shown
 *   are not drawn. The shapes are drawn in an image off the window,
 *   then that image on the window in one message: nothing flickers,
 *   and a window system shows one rectangle. The first shape, the
 *   ground, is kept drawn in an image of its own.
 * - {b The colours}: a shape's colour is a byte of Plan 9's table; the
 *   image the kernel wants for it is made at its first use.
 *
 * Dropped, the playground's: numbers that are floats under a
 * transformation (move, scale, rotate, fade: a shape here is pixels,
 * its place whole numbers, y down from the window's top left corner),
 * circles, polygons, images, words of several sizes (the machine's one
 * font, 8 by 16), sounds, the mouse, subscriptions and commands (a game
 * here gets every key and every frame), a time that is the host's (a
 * frame is 13 of the kernel's ticks: the machine's instructions), and
 * the platforms (one: the descriptor a program draws on).
 *
 * Exercises:
 * - the mouse: a fourth function, and the program's descriptor 4;
 * - only what changed drawn, for every shape and not the ground alone:
 *   the shapes of two models compared;
 * - a circle and a polygon, with TinyGraphics.ml's;
 * - a second game: a Snake, a Pong.
 *
 * Where it stands: under it TinyCalls (four of the kernel's calls:
 * write, read, ready, ticks) and TinyDraw (the messages); over it
 * TinyTetris. It draws on its descriptor 3 and reads its 0, so a game
 * runs on the screen or in a window of TinyWindows without knowing.
 * lib_playground's Playground is the whole one, with floats, a
 * transformation, the mouse and several platforms.
 *
 * cs-history:
 * A program with a screen written as a value and a few functions of
 * it, with the loop in a library, was made for teaching: How to
 * Design Programs's big-bang (Felleisen, Findler, Flatt and
 * Krishnamurthi, "A Functional I/O System", 2009) takes a first
 * world and functions for a tick, a key and a picture, so that a
 * beginner writes a game with no assignment. Evan Czaplicki's Elm
 * (2012) began elsewhere, with signals that vary in time, and
 * dropped them in 2016 for this shape, model, update, view; from Elm
 * it went to JavaScript as Redux, and is now how most interfaces on
 * the web are explained.
 *
 * design:
 * Comparing two models by their address before comparing by their
 * content (the != in [run], the == in [same]) is sound only because
 * a model is never written: the same address is then the same
 * content, for ever, and one comparison of two words answers for a
 * whole structure. With data that can be written it answers nothing.
 * It is the bargain of every system of this family, and of TinyVCS's
 * hashes: do not change a thing, and knowing whether it changed is
 * free.
 *
 * References: E. Czaplicki, "Elm: Concurrent FRP for
 * Functional GUIs" (2012) and The Elm Architecture; Elm's Playground
 * package (2019), a game as a model, a view and an update. *)

(* what a view is made of: a rectangle (its width, its height, its
 * colour), a text in a colour, shapes together, a shape moved *)
type shape = Rect of int * int * int | Words of int * string | Group of shape list | Move of int * int * shape

(* a game: its window's size, its first model from a seed, the model as
 * shapes, the model after a key and after a frame *)
type 'm game = { width : int; height : int; init : int -> 'm; view : 'm -> shape list; key : int -> 'm -> 'm; frame : 'm -> 'm }

(* The program of a game: its loop, with no end (a key or the next
 * frame's time waited for, the picture drawn when the shapes are
 * others) *)
val run : 'm game -> 'a

(* the number after a seed, 1 to 2^30 - 36 (Lehmer's generator) *)
val random : int -> int

(* a picture: the shapes before (its first, the ground, drawn again
 * only when another), the shapes now; and the two images it is made
 * in, by their numbers (a test's) *)
val show : 'm game -> shape list -> shape list -> unit
val picture : int
val ground : int
