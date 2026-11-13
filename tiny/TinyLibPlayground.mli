(* A tiny playground. It is the tiny version of lib_playground, the
 * library that games are written with. It keeps the essentials of the author's
 * playground, which follows the Elm architecture.
 *
 * The main idea is that {b a game is a value and three functions} (and
 * two more for its sounds and its music, below). The value is the
 * model, which is everything the game knows. [view] turns the model into
 * shapes; [key] and [frame] return the new model after a key press and
 * after a thirtieth of a second. A game has no loop, does no drawing,
 * and keeps no state of its own: the library takes care of all that.
 * So a game can be tested without a screen (give it a model and some
 * keys, and check the resulting model), and its picture can be tested
 * without the machine (KGraphics.ml draws the shapes on the
 * host).
 *
 *                 +------------ key -------------+
 *                 v                              |
 *     init --> a model --view--> shapes --> redrawn, only when
 *                 ^                              |    the shapes changed
 *                 +----------- frame ------------+
 *                    (every 13 kernel ticks)
 *
 * Here is a whole game, the smallest possible value of [game]. It shows
 * a number in a white box, and each key adds one to it (the last line
 * is the program):
 *
 *     let game = {
 *       width = 64; height = 32;
 *       init = (fun seed -> 0);
 *       view = (fun n -> [ Rect (255, 64, 32);
 *                          Move (8, 8, Words (0, string_of_int n)) ]);
 *       key = (fun k n -> n + 1);
 *       frame = (fun n -> n);
 *       sound = (fun was n -> []);
 *       music = (fun n -> None) }
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
 * - {b The music}: [music] gives the tune a model wants playing, just
 *   as [view] gives the picture it wants shown. For Tetris it is the
 *   theme, played faster at each level, and nothing once the game is over.
 *   Each part of the tune gets a voice of /dev/audio, and at each turn
 *   of its loop the library sends each voice its next notes, up to half
 *   a second ahead. When the tune changes (to a faster pace, say), the new
 *   one goes on from the same place in the notes, as m-ix's change_loop
 *   does; None closes the voices. A note is sent as a sound, so a tune is a
 *   few messages a second and the kernel makes the samples. m-ix's
 *   playground renders the samples itself, which costs a Pi 1 whole
 *   seconds (8 and 14 in notes_audio.md).
 * - {b The colours}: a shape's colour is a byte, which is an index in
 *   Plan 9's colour table; the image the kernel needs for that colour is
 *   created the first time it is used.
 *
 * dropped:
 * From the full playground, this library drops:
 * - floating-point coordinates under a transformation (move, scale,
 *   rotate, fade); here a shape is in pixels, at integer positions,
 *   with y going down from the top left corner of the window;
 * - circles, polygons and images;
 * - text in several sizes (the machine has a single 8x16 font);
 * - ABC's notation and instruments (a tune is notes in Hz on the
 *   kernel's waves);
 * - the mouse;
 * - subscriptions and commands (here a game receives every key and
 *   every frame);
 * - time taken from the host (here a frame is 13 kernel ticks, which
 *   count machine instructions);
 * - multiple platforms (there is only one: the file descriptor the
 *   program draws on).
 *
 * twist:
 * {b A sound comes from what changed}, just as the picture comes from
 * what is. The full playground renders audio from its sources and has
 * no notion of the sound of a model. Here [sound] is given the model
 * before and the model after, and says what is heard (in Tetris: rows
 * cleared, a piece that landed). So a game keeps no record of what it
 * played, and its sounds are tested like its rules, with two models
 * and no speaker. A sound is written to tiny-kernel's /dev/audio as an
 * 11-byte message, and the kernel makes the samples and mixes them
 * with those of the other programs.
 *
 * context:
 * Below this library are TinyLibSystem (write, read, ready, millis,
 * and opening the speaker) and TinyLibDraw (the drawing messages);
 * above it is TinyAppTetris. It draws on fd_draw and reads keys on
 * fd_stdin, so a game runs either on the whole screen or in a window
 * of TinyWindows without knowing which. Playground in lib_playground
 * is the full version, with floats, transformations,
 * the mouse and several platforms.
 *
 * exercises:
 * - the mouse: a fourth function, which reads the program's
 *   descriptor 4;
 * - redraw only what changed, for every shape and not just the
 *   background, by comparing the shapes of two models;
 * - circles and polygons, once KGraphics.ml draws them (ellipses and
 *   filled polygons are among its exercises, for these shapes);
 * - a second game: a Snake, or a Pong;
 * - record and replay: a game is pure and init takes a seed, so the
 *   seed and the keys of each frame reproduce a whole game (demos, bug
 *   reports, tests written as recordings).
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
 * references:
 *  - E. Czaplicki, "Elm: Concurrent FRP for Functional GUIs" (2012),
 *    and The Elm Architecture
 *  - Elm's Playground package (2019): a game as a model, a view and an
 *    update
 *)

(* C-a is Ctrl 'a', and C-_ is Ctrl '_'. [Char] includes Tab. The
 * console gives bytes. A control key is 1 to 31, Enter is '\r' or
 * '\n', Backspace is '\b' or '\127', Escape is '\027', and the arrows
 * of tiny-machine are 128 to 131 (up, down, left, right). Plan 9's console
 * gives runes instead, its arrows among them. *)
type key =
  | Char of char | Ctrl of char | Enter | Backspace | Escape
  | Up | Down | Left | Right

val key_of_byte : char -> key

(* A text's colour is a byte; the bits above it give the style of the
 * office's words: [bold], [italic], [underlined], [large] (16x32
 * characters). [fat_pixels] is for a row of a paint picture instead:
 * each character is a colour letter (see [pixel_letters]) drawn as a
 * 4x4 square. *)
type colour = int
type shape =
  | Rect of colour * int * int
  | Words of colour * string
  | Group of shape list
  | Move of int * int * shape
val bold : int
val italic : int
val underlined : int
val large : int
val fat_pixels : int

(* . white, k black, r red, g green, b blue, y yellow, o orange,
 * p purple, n brown, a grey *)
val pixel_letters : string

(* The size of a character in a colour and style. [overhang] is how far
 * it reaches right of its cell, as an italic's slant does. *)
val char_width : int -> int
val char_height : int -> int
val overhang : int -> int

(* A sound is sfxr's recipe (lib_audio's Sfx.mli) cut down to five
 * numbers. The pitch slides from [hz] to [to_hz] (at most 4,000), [ms]
 * is at most 1,000, and [volume] (0 to 127) fades to nothing by the
 * end. *)
type wave = Square | Triangle | Sawtooth | Noise
type sound = { wave : wave; hz : int; to_hz : int; ms : int; volume : int }

(* [pace] is the unit in milliseconds (an eighth note, say). The parts
 * play together. A note is a pitch in Hz (0 for a rest) and a length in
 * units, at most 1,000 ms. *)
type part = { timbre : wave; level : int; notes : (int * int) list }
type tune = { pace : int; parts : part list }

(* [init] gets a random seed. The sounds of [sound was now] play one
 * after the other; [music] gives None for silence. *)
type 'm game = {
  width : int; height : int; init : int -> 'm; view : 'm -> shape list;
  key : key -> 'm -> 'm; frame : 'm -> 'm;
  sound : 'm -> 'm -> sound list; music : 'm -> tune option;
}

(* The loop of a game. It draws only when the shapes differ, and ends on
 * q or at the end of the keys with Exit.OK, so a game never sees a q. *)
val run : < Cap.open_out; Cap.random; Cap.clock; .. > -> 'm game -> Exit.t

(* [random seed] is the number after [seed], from 1 to 2^30 - 36
 * (Lehmer's generator). *)
val random : int -> int

(* The message for /dev/audio. It is p, the count, then the samples,
 * which are signed bytes at 8,000 a second, at most 8,192 of them. *)
val samples_message : string -> string

(* [draw image x y shape] gathers the drawing messages, and [flush]
 * writes them. TinyLibGUI uses them for widgets, not whole pictures. *)
val draw : TinyLibDraw.image -> int -> int -> shape -> unit
val flush : unit -> unit

(* [show g shown now] draws the shapes [now]. It redraws the ground,
 * which is the first shape, only when it changed. The tests use the
 * image numbers [picture] and [ground]. *)
val show : 'm game -> shape list -> shape list -> unit
val picture : int
val ground : int
