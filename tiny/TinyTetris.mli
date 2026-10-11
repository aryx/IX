(* A tiny Tetris, a game of TinyKernel.ml's on TinyPlayground.ml: the
 * essential of the game (the author's playground has one, ix's twin is
 * games/puzzle/Tetris.ml, after elm-flatris). Written anew, in
 * integers, in tiny-ml's ML and OCaml's (plan_tiny_windows.md):
 *
 *     ./tiny-machine -window tiny-kernel
 *     $ tiny-windows             then a window, and in it:
 *     $ tetris
 *     the arrows: left, right, up turns the piece, down a row;
 *     the space drops it; q quits
 *
 * A well of 10 by 20 cells; seven pieces of four cells, each with its
 * colour, one falling, the next one shown; a row filled is removed and
 * what is over it comes down; a piece that cannot enter ends the game.
 * A level every ten rows, the pieces falling faster.
 *
 * It is a value of TinyPlayground's [game]: a model and three
 * functions, with no loop, no clock and no drawing here. So its rules
 * are tested on the host by keys and frames given to these functions,
 * the well printed as text (tests/TinyTetris_test.sh), and its picture
 * by TinyGraphics.ml.
 *
 * How, where it is not the obvious:
 *
 * - {b A piece is 16 bits a turn}: a square of 4 by 4, a hexadecimal
 *   digit a row, in a string ([turns]): no table of tables, and a
 *   piece turned is the next four digits. The T's sixteen digits,
 *   4E00 4640 0E40 4C40, a turn a column of this picture, a digit's
 *   high bit the left cell:
 *
 *       4  . # . .     4  . # . .     0  . . . .     4  . # . .
 *       E  # # # .     6  . # # .     E  # # # .     C  # # . .
 *       0  . . . .     4  . # . .     4  . # . .     4  . # . .
 *       0  . . . .     0  . . . .     0  . . . .     0  . . . .
 *
 *   Whether a piece fits is then sixteen tests of a bit against the
 *   well, whatever the piece: no case by kind anywhere in the rules.
 * - {b The well is an array that is never written once in a model}: a
 *   piece that lands makes another one. A model is then a value like
 *   any other, kept or compared, though ML's arrays can be written.
 * - {b The ground is the model's}: the well's cells, the score and the
 *   next piece as shapes, made when a piece lands and kept in the
 *   model. The playground draws its first shape again only when it is
 *   another one, so a piece that moves is five shapes, not a hundred.
 *
 * Dropped: the piece's shadow where it would land, a piece held aside,
 * the turns' kicks off a wall beyond a cell to either side, the seven
 * pieces dealt as a bag, a pause, the best scores, sounds.
 *
 * Exercises:
 * - the shadow; a pause; the bag of seven;
 * - a row's end shown before it is removed (a frame or two of white);
 * - two wells side by side, a second player's keys.
 *
 * cs-history:
 * Alexey Pajitnov wrote Tetris in 1984 at the Computing Centre of
 * the Soviet Academy of Sciences in Moscow, on an Electronika 60, a
 * Soviet machine of the PDP-11's family with a terminal that showed
 * only text: the first cells were pairs of brackets. The pieces are
 * the seven shapes four squares can make, mirror images counted
 * apart (Solomon Golomb's tetrominoes, which gave the name with
 * tennis). It spread from machine to machine by copies before any
 * contract existed, and Nintendo's Game Boy (1989) made it the game
 * everyone had played. A screen of characters, a well of 10 by 20,
 * four moves: it was a small program on a small machine from the
 * first day, which is why it is this machine's first game.
 *
 * modern:
 * What is dropped above is mostly what was added after 1984 and is
 * now fixed by the game's owners in a guideline: the seven pieces
 * dealt as a shuffled bag so that none is long awaited, a table of
 * kicks tried when a turn does not fit, a piece held, the shadow.
 * The original dealt at random and turned in place; here the deal is
 * random too, and a turn that does not fit tries a cell to either
 * side.
 *
 * References: A. Pajitnov's Tetris (1984);
 * https://en.wikipedia.org/wiki/Tetris. *)

(* a piece (which of the seven, turned how, where), the board (the
 * well's rows, the cells fallen as shapes, what comes next, the
 * score), and the game's model *)
type piece = { kind : int; turn : int; x : int; y : int }
type board = { well : int array; ground : TinyPlayground.shape; next : int; seed : int; score : int; rows : int }
type model = { board : board; piece : piece; wait : int; over : bool }

(* The game, for TinyPlayground's run *)
val game : model TinyPlayground.game

(* a piece's four cells in the well: a column and a row each *)
val cells : piece -> (int * int) list
