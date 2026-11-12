(* A tiny Tetris, a game for TinyKernel.ml built on TinyLibPlayground.ml.
 * It keeps the essentials of the game and uses only integers. The keys:
 * the left and right arrows move the piece, up turns it, down moves it
 * down a row; space drops it; m turns the music off and on; q quits.
 *
 * The rules: the well is 10 by 20 cells. There are seven pieces of four
 * cells, each with its own colour; one piece is falling, and the next
 * one is shown. When a row is full it is removed and everything above
 * it moves down. The game ends when a new piece cannot enter the well.
 * Every ten rows the level goes up and the pieces fall faster.
 *
 * The game is a value of TinyLibPlayground's [game] type: a model and
 * three functions. There is no loop, no clock and no drawing in this
 * file.
 *
 * twin:
 * m-ix's games/puzzle/Tetris.ml is its twin, built on lib_playground.
 * It is the author's playground's port of elm-flatris, written in Elm's
 * way: the well is the list of its full cells, a piece is four cells
 * turned by computing their places again, and the falling piece's
 * height is a float, for the speed of its fall. What differs here is
 * explained below: the rotations are a table of bits, the well is an
 * array, and we use integers only (a level's speed is a number of
 * frames). A turn that does not fit is retried one cell to each side,
 * where the twin tries two. Plan 9 has its own Tetris, games/4s (not in
 * principia; from memory).
 *
 * kept:
 * The parts that are not obvious:
 *
 * - {b The well is an array that is never modified once it is in a
 *   model}: when a piece lands, a new array is made. So a model is a
 *   value like any other, that can be kept or compared, even though
 *   arrays in ML are mutable.
 * - {b The background belongs to the model}: the cells of the well,
 *   the score and the next piece are turned into shapes when a piece
 *   lands, and those shapes are kept in the model. The playground only
 *   redraws its first shape when it changes, so a moving piece costs
 *   five shapes, not a hundred.
 *
 * dropped:
 * The shadow showing where the piece would land, holding a piece aside,
 * wall kicks further than one cell to either side, dealing the seven
 * pieces as a bag, a pause, and high scores. The sounds are kept from
 * m-ix: a piece landing, rows cleared, four rows at once, a new level,
 * and the game over; [sound] picks them by comparing two models. The
 * music is m-ix's too: Korobeiniki, with the melody on a square wave
 * and an octave bass on a triangle, a tenth faster at each level.
 * [music] gives the tune a model wants, as [view] gives the picture it
 * wants, and gives none when the game is over.
 *
 * twist:
 * {b Each rotation of a piece is 16 bits}: a 4 by 4 square, one
 * hexadecimal digit per row, all stored in a string ([turns]). There
 * is no table of tables, and turning a piece just means moving to
 * the next four digits. Here are the T's sixteen digits, 4E00 4640
 * 0E40 4C40; each column of the picture is one rotation, and the
 * high bit of a digit is the leftmost cell:
 *
 *     4  . # . .     4  . # . .     0  . . . .     4  . # . .
 *     E  # # # .     6  . # # .     E  # # # .     C  # # . .
 *     0  . . . .     4  . # . .     4  . # . .     4  . # . .
 *     0  . . . .     0  . . . .     0  . . . .     0  . . . .
 *
 * Checking whether a piece fits is then sixteen bit tests against
 * the well, whatever the piece: nowhere do the rules need a case per
 * kind of piece, where the twin, games/puzzle/Tetris.ml, keeps a
 * piece's cells and turns them with a function (rotate).
 *
 * exercises:
 * - the shadow; a pause; the bag of seven;
 * - showing a completed row before it is removed (a frame or two of
 *   white);
 * - two wells side by side, with keys for a second player.
 *
 * cs-history:
 * Alexey Pajitnov wrote Tetris in 1984 at the Computing Centre of the
 * Soviet Academy of Sciences in Moscow, on an Electronika 60, a Soviet
 * machine of the PDP-11 family whose terminal could only show text:
 * the first cells were pairs of brackets. The pieces are the seven
 * shapes that four squares can make, counting mirror images as
 * distinct (Solomon Golomb's tetrominoes, which, combined with tennis,
 * gave the game its name). It spread from machine to machine through
 * copies before any contract existed, and Nintendo's Game Boy (1989)
 * made it the game everyone had played. A character screen, a 10 by 20
 * well, four moves: it was a small program on a small machine from day
 * one, which is why it is this machine's first game.
 *
 * modern:
 * Most of what is dropped above was added after 1984 and is now fixed
 * by the game's owners in a guideline: the seven pieces dealt as a
 * shuffled bag so that no piece is awaited too long, a table of kicks
 * tried when a rotation does not fit, holding a piece, and the shadow.
 * The original dealt pieces at random and rotated them in place; here
 * the deal is random too, and a rotation that does not fit tries
 * shifting one cell to either side.
 *
 * references:
 *  - A. Pajitnov's Tetris (1984)
 *  - https://en.wikipedia.org/wiki/Tetris
 *)

(* [kind] is which of the seven pieces, [turn] its rotation. *)
type piece = { kind : int; turn : int; x : int; y : int }
type board = { 
  well : int array;
  ground : TinyLibPlayground.shape; (* fallen cells, score, next piece *)
  next : int;
  seed : int;
  score : int;
  rows : int (* the rows cleared *)
}
(* [wait] counts the frames before the piece goes down a row. *)
type model = { board : board; piece : piece; wait : int; over : bool; quiet : bool }

(* The game, for TinyLibPlayground's run *)
val game : model TinyLibPlayground.game

(* the sounds of a change, from one model to the next *)
val sound : model -> model -> TinyLibPlayground.sound list

(* Korobeiniki's two parts, the melody and the bass *)
val theme : TinyLibPlayground.part list

(* The theme at the pace of the level, or None when the game is over or
 * the music is off. *)
val music : model -> TinyLibPlayground.tune option

(* a piece's four cells in the well, as (column, row) *)
val cells : piece -> (int * int) list

(* The program tetris. It runs until a q or the end of the keys. *)
val main : < Cap.open_out; Cap.random; Cap.clock; .. > -> string array -> Exit.t
