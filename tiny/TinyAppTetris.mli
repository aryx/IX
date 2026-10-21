(* A tiny Tetris, a game for TinyKernel.ml built on
 * TinyLibPlayground.ml keeping the essentials of the game, using only
 * integers. The keys: the arrows left and right, up turns the piece,
 * down a row; the space drops it; m the music off and on; q quits.
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
 * Its twin is m-ix's games/puzzle/Tetris.ml, on lib_playground: the
 * author's playground's port of elm-flatris, in Elm's way, where the
 * well is the list of its full cells, a piece four cells turned by
 * computing their places again, and the falling piece's height a
 * float, for the speed of its fall. What is ours is below: the
 * rotations a table of bits, the well an array, integers only (a
 * level's speed is a number of frames); a turn that does not fit is
 * tried one cell to each side, where the twin tries two. Plan 9 has
 * its own, games/4s (not in principia; from memory).
 *
 * The parts that are not obvious:
 *
 * - {b Each rotation of a piece is 16 bits}: a 4 by 4 square, one
 *   hexadecimal digit per row, all stored in a string ([turns]). There
 *   is no table of tables, and turning a piece just means moving to
 *   the next four digits. Here are the T's sixteen digits, 4E00 4640
 *   0E40 4C40; each column of the picture is one rotation, and the
 *   high bit of a digit is the leftmost cell:
 *
 *       4  . # . .     4  . # . .     0  . . . .     4  . # . .
 *       E  # # # .     6  . # # .     E  # # # .     C  # # . .
 *       0  . . . .     4  . # . .     4  . # . .     4  . # . .
 *       0  . . . .     0  . . . .     0  . . . .     0  . . . .
 *
 *   Checking whether a piece fits is then sixteen bit tests against
 *   the well, whatever the piece: nowhere do the rules need a case per
 *   kind of piece.
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
 * What is dropped: the shadow showing where the piece would land,
 * holding a piece aside, wall kicks further than one cell to either
 * side, dealing the seven pieces as a bag, a pause, and high scores.
 * Its sounds are m-ix's (a piece landed, rows gone, four at once, a
 * level, the game over; [sound] says which from two models), and so is
 * its music, Korobeiniki, the melody on a square and an octave bass on
 * a triangle, a tenth faster each level ([music]: the tune a model
 * wants, as [view] is the picture it wants; none when the game is
 * over).
 *
 * Exercises:
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
 * References:
 *  - A. Pajitnov's Tetris (1984)
 *  - https://en.wikipedia.org/wiki/Tetris
 *)

(* a piece (which of the seven, turned how, where), the board (the
 * well's rows, the cells fallen as shapes, what comes next, the
 * score), and the game's model *)
type piece = { kind : int; turn : int; x : int; y : int }
type board = { 
  well : int array;
  ground : TinyLibPlayground.shape;
  next : int;
  seed : int;
  score : int;
  rows : int 
}
type model = { board : board; piece : piece; wait : int; over : bool; quiet : bool }

(* The game, for TinyLibPlayground's run *)
val game : model TinyLibPlayground.game

(* the sounds of a change, from a model to the next *)
val sound : model -> model -> TinyLibPlayground.sound list

(* Korobeiniki's two parts, the melody and the bass *)
val theme : TinyLibPlayground.part list

(* the tune a model wants playing: the theme at its level's pace, None
 * when the game is over or the music is off *)
val music : model -> TinyLibPlayground.tune option

(* a piece's four cells in the well: a column and a row each *)
val cells : piece -> (int * int) list
