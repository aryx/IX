(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

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

open TinyPlayground

(*****************************************************************************)
(* Pieces *)
(*****************************************************************************)

(* the falling piece: which of the seven (I J L O S T Z), how many
 * quarter turns, where its square of 4 by 4 is in the well (its top
 * left cell's column and row; a row above the well is negative) *)
type piece = { kind : int; turn : int; x : int; y : int }

(* a kind's four turns, a turn four rows from the top, a row a
 * hexadecimal digit, its high bit the left cell *)
let turns =
  "0F00222200F04444" ^ "8E0064400E2044C0" ^ "2E0044600E80C440" ^ "6600660066006600" ^ "6C00462006C08C40"
  ^ "4E0046400E404C40" ^ "C60026400C604C80"

(* a kind's colour, a byte of the table: cyan, blue, orange, yellow, green, purple, red *)
let colours = "\050\054\248\252\063\180\240"

let digit c = if c >= 'A' then Char.code c - 55 else Char.code c - 48
let filled kind turn row col = (digit turns.[(((kind * 4) + turn) * 4) + row] lsr (3 - col)) land 1 = 1

(* a piece's four cells in the well: a column and a row each *)
let cells (p : piece) =
  let rec from row col acc =
    if row = 4 then acc
    else if col = 4 then from (row + 1) 0 acc
    else from row (col + 1) (if filled p.kind p.turn row col then (p.x + col, p.y + row) :: acc else acc)
  in
  from 0 0 []

(*****************************************************************************)
(* The model *)
(*****************************************************************************)

(* What changes when a piece lands: the well (200 cells, a row after
 * the other from the top; 0 an empty one, else a kind and 1), as
 * shapes with the panel beside it; the next piece's kind; the random
 * numbers' state; the score, the rows removed *)
type board = { well : int array; ground : shape; next : int; seed : int; score : int; rows : int }

(* and what changes as it falls: the piece, the frames before it goes
 * down a row, whether the game is over *)
type model = { board : board; piece : piece; wait : int; over : bool }

(* a piece is where it may be: in the well's sides and floor (its top
 * may be over the well), on no cell taken *)
let fits (well : int array) p = List.for_all (fun (c, r) -> c >= 0 && c < 10 && r < 20 && (r < 0 || well.((r * 10) + c) = 0)) (cells p)

(* the frames a row takes: a second, a tenth less each level, a level every ten rows *)
let delay rows = max 3 (30 - (3 * (rows / 10)))

(*****************************************************************************)
(* The picture *)
(*****************************************************************************)

(* a cell is 16 pixels, the well's corner at (8, 8) *)
let cell kind col row = Move (8 + (16 * col), 8 + (16 * row), Rect (Char.code colours.[kind], 15, 15))
let shown (p : piece) = Group (List.map (fun (c, r) -> cell p.kind c r) (List.filter (fun (_, r) -> r >= 0) (cells p)))

let white = 255
let grey = 0xaa

(* the well's cells and the panel: its numbers, the next piece *)
let ground_of (well : int array) next score rows =
  let rec taken i acc = if i = 200 then acc else taken (i + 1) (if well.(i) = 0 then acc else cell (well.(i) - 1) (i mod 10) (i / 10) :: acc) in
  let line y name n = Group [ Move (184, y, Words (grey, name)); Move (184, y + 16, Words (white, string_of_int n)) ] in
  let panel =
    Group [ Move (184, 8, Words (white, "TETRIS")); line 48 "score" score; line 96 "rows" rows; line 144 "level" (rows / 10) ] in
  let coming = Group [ Move (184, 192, Words (grey, "next")); shown { kind = next; turn = 0; x = 11; y = 13 } ] in
  Group (Rect (0, 288, 336) :: Move (8, 8, Rect (0x11, 160, 320)) :: panel :: coming :: taken 0 [])

let banner =
  Move (16, 136, Group [ Rect (white, 144, 48); Move (2, 2, Rect (0, 140, 44)); Move (36, 6, Words (white, "GAME OVER")); Move (20, 24, Words (grey, "space: again")) ])

let view m = if m.over then [ m.board.ground; shown m.piece; banner ] else [ m.board.ground; shown m.piece ]

(*****************************************************************************)
(* The rules *)
(*****************************************************************************)

(* the next piece enters at the top, another one is next: the game is
 * over if it has no room *)
let enter (well : int array) next seed score rows =
  let piece = { kind = next; turn = 0; x = 3; y = 0 } in
  let seed = random seed in
  let b = { well = well; ground = ground_of well (seed mod 7) score rows; next = seed mod 7; seed = seed; score = score; rows = rows } in
  { board = b; piece = piece; wait = delay rows; over = not (fits well piece) }

let start seed =
  let seed = random (1 + (seed land 0xffff)) in
  enter (Array.make 200 0) (seed mod 7) seed 0 0

(* the piece lands: its cells are the well's, in another well; the full
 * rows are removed (the others copied from the bottom, a full one
 * passed over); the score, by how many at once *)
let land_ m =
  let b = m.board in
  let well = Array.make 200 0 in
  for i = 0 to 199 do well.(i) <- b.well.(i) done;
  List.iter (fun (c, r) -> if r >= 0 then well.((r * 10) + c) <- m.piece.kind + 1) (cells m.piece);
  let left = Array.make 200 0 in
  let full r = let rec from c = c = 10 || (well.((r * 10) + c) <> 0 && from (c + 1)) in from 0 in
  let rec down r into n =
    if r < 0 then n
    else if full r then down (r - 1) into (n + 1)
    else (for c = 0 to 9 do left.((into * 10) + c) <- well.((r * 10) + c) done; down (r - 1) (into - 1) n)
  in
  let n = down 19 19 0 in
  let gain = if n = 0 then 0 else if n = 1 then 100 else if n = 2 then 300 else if n = 3 then 500 else 800 in
  enter left b.next b.seed (b.score + 4 + (gain * (1 + (b.rows / 10)))) (b.rows + n)

(* the piece somewhere else, if it may be there: else the same model *)
let moved m p = if fits m.board.well p then { board = m.board; piece = p; wait = m.wait; over = false } else m

(* a row down, or landed *)
let fall m =
  let p = m.piece in
  let lower = { kind = p.kind; turn = p.turn; x = p.x; y = p.y + 1 } in
  if fits m.board.well lower then { board = m.board; piece = lower; wait = delay m.board.rows; over = false } else land_ m

let rec drop m = let p = m.piece in if fits m.board.well { kind = p.kind; turn = p.turn; x = p.x; y = p.y + 1 } then drop (fall m) else land_ m

let frame m =
  if m.over then m
  else if m.wait > 1 then { board = m.board; piece = m.piece; wait = m.wait - 1; over = false }
  else fall m

(* the arrows (128 up: a quarter turn, where it is, or a cell to the
 * left, or to the right; 129 down; 130 left; 131 right), the space *)
let key k m =
  let p = m.piece in
  if m.over then (if k = 32 then start m.board.seed else m)
  else if k = 130 then moved m { kind = p.kind; turn = p.turn; x = p.x - 1; y = p.y }
  else if k = 131 then moved m { kind = p.kind; turn = p.turn; x = p.x + 1; y = p.y }
  else if k = 129 then fall m
  else if k = 32 then drop m
  else if k = 128 then begin
    let turned dx = { kind = p.kind; turn = (p.turn + 1) mod 4; x = p.x + dx; y = p.y } in
    let a = moved m (turned 0) in
    if a != m then a else (let b = moved m (turned (-1)) in if b != m then b else moved m (turned 1))
  end
  else m

let game = { width = 288; height = 336; init = start; view = view; key = key; frame = frame }
