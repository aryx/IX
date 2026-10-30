(* DrScheme_draw: what every part of mini-drscheme draws with: where
   things are in the window, a program's text in cells, an image of the
   language. Its window is the Playground's, 1000 by 1000 whatever the
   size on the screen, and it is laid out as DrScheme 209 was on Windows
   XP:

       y    0 +------------------------------------------+
              | title bar                                |  34
           34 +------------------------------------------+
              | Untitled (define ...)  Step Execute Break|  62, the toolbar
           96 +------------------------------------------+
              | Definitions                              |
              |   89 columns, 23 lines                   | 468
              |                                          |
          564 +------------------- ---- -----------------+   8, the divider
          572 +------------------------------------------+
              | Interactions                             | 386
              |   > (fact 5)                             |
              |   120                                    |
          958 +------------------------------------------+
          960 | Language: ... (click)      running 1:0   |  40, the status
         1000 +------------------------------------------+

   The Playground's coordinates have (0, 0) in the centre and y going up,
   for games; a window with lines of text wants its top-left corner and
   y going down. [at] is the one place that knows, and [mouse_at] the way
   back: every other number in the program counts from the corner.

   A program's text is drawn in cells of 11 by 20, a character a shape,
   as a code editor's: a column is a multiplication away, and the mouse
   finds its character by a division. The window's own words (a button,
   the title) are in a proportional font, [caption]. Text_edit knows
   offsets and DrScheme knows lines, so a key going up goes through both:

       "(define x\n  1)\n"     the caret at 12
         place              -> line 1, column 2
         ArrowUp, offset    -> line 0, column 2: the offset 2

   Each character has its colour, the expression at the caret greyed:

       (define (fact n)     parentheses brown, symbols dark blue,
         ;; n is a number   comments orange,
         (cond [else "x"])) constants green: numbers, strings, #t, empty,
                            quote

   [colors] is a small lexer over the whole text, made at each frame, and
   it is not Sexpr_read, for a reason: the text coloured is being typed.
   The reader stops at the first thing wrong, and raises; a colourer must
   go on to the end over a string not yet closed or an extra parenthesis,
   and needs to know no more than where a token ends. It returns an array
   of a colour by offset, so that [text_view] has no lexing to do and
   stays the same for any function from an offset to a colour. [matching]
   counts depth outward from the caret, in the text and not in the forms
   read, for the same reason: DrScheme's way of showing what a closing
   parenthesis closes.

   [picture] is the whole border between the language, which is text and
   numbers and can be tested without a screen (Scheme_image.mli says
   why), and the program that has a window:

       (beside (circle 20 "solid" "red") (circle 20 "solid" "gold"))
         the language: Beside (Circle (20., Solid, "red"), Circle ...)
         | picture
         | Bigbang.beside (Bigbang.circle 20. Solid red) (...)
         | Bigbang.to_shape, then scaled and placed by the caller
         v
       the Playground's shape, for a frame

   It is a fold over the tree: each constructor one of the Bigbang way's
   combinators, which are the same ones under the same names. A colour is
   a name in the language, a word in a string as in 2htdp/image, and the
   names known are a few of those a program of the book uses. A name not
   known is grey rather than a failure: nothing here would say where the
   mistake is, and a grey disc can be seen.

   others:
   mini-emacs's colours come from Highlight_code, the same categories for
   every language, each turning its own tokens into them; Emacs itself
   colours by regular expressions on the lines shown (font-lock), which
   sees little and costs little. For Scheme, whose syntax is parentheses
   and tokens, a small function does it. *)

open Playground

(*****************************************************************************)
(* The window's geometry *)
(*****************************************************************************)

(* from the corner, y going down, to the Playground's centre *)
val at : float -> float -> shape -> shape
val box : color -> float -> float -> float -> float -> shape

(* a rectangle's four sides, each a pixel wide *)
val frame : color -> float -> float -> float -> float -> shape list

(* a character's cell *)
val cw : float
val lh : float
val label : color -> float -> float -> string -> shape list

(* [caption c x y size s]: the words centred on (x, y) *)
val caption : color -> float -> float -> float -> string -> shape

val title_h : float
val toolbar_y : float
val defs_y : float
val defs_h : float
val inter_y : float
val inter_h : float
val status_y : float
val text_x : float

(* the columns of a window's text, and the lines of the Definitions' *)
val cols : int
val rows : int

val chrome : color
val title_blue : color
val dark : color
val error_color : color

(*****************************************************************************)
(* Buttons *)
(*****************************************************************************)

(* the mouse from the Playground's centre to the window's corner *)
val mouse_at : computer -> float * float

(* a button's place: x, y, width, height *)
val inside : float * float -> float * float * float * float -> bool

val step_button : float * float * float * float
val execute_button : float * float * float * float
val break_button : float * float * float * float
val language_button : float * float * float * float

(* [button place icon word enabled]: raised, its icon and its word *)
val button :
  float * float * float * float -> shape list -> string -> bool -> shape list

(*****************************************************************************)
(* The lines of a text *)
(*****************************************************************************)

(* the lines of a text, each with the offset it starts at *)
val lines : string -> (int * string) list

(* the line and column of an offset *)
val place : string -> int -> int * int

(* [offset s line col]: the column taken within the line, the end of the
   text past the last line *)
val offset : string -> int -> int -> int

(*****************************************************************************)
(* A program's text *)
(*****************************************************************************)

(* each character's colour *)
val colors : string -> color array

(* the parenthesis matching the one beside the caret: DrScheme greys
   the expression between them *)
val matching : string -> int -> (int * int) option

(* [text_view ...]: lines of text from line [top], with backgrounds over
   character ranges *)
val text_view :
  at:float * float -> rows:int -> top:int -> string -> (int -> color) ->
  ((int * int) * color) list -> int option -> shape list

(*****************************************************************************)
(* An image *)
(*****************************************************************************)

val picture : Scheme_image.t -> Bigbang.image
