(* TinyOffice's text box: its data, how it is laid out in its box, how
 * it is edited as it is shown (WYSIWYG), and its view.
 *
 * A text box's data is its text with a mark where the style changes:
 *
 *     A \{b}bold\{} word, and \{il}large italic\{}.
 *
 * A style is written as its letters between \{ and } (b bold, i
 * italic, u underlined, l large); \{} goes back to plain, and \\ is a
 * backslash. While the box is edited, its data is decoded into two
 * strings of the same length, the characters and their styles (a byte
 * per character: bold 1, italic 2, underlined 4, large 8). These are
 * the doc of Model, and they are encoded back when the editing ends:
 *
 *     txt   A bold word
 *     sty   00111100000         (one byte per character; 1 is bold)
 *
 * The layout fills the box's width a word at a time. Each character
 * takes its style's width in the kernel's fonts, and a line is as tall
 * as its largest character. [index_at] is the inverse: it turns a click
 * into a place in the text. The file's Markdown (File) is made from the
 * same two strings.
 *
 * modern:
 * A word processor keeps its text in a piece table (the Alto's Bravo
 * had one, and so does lib_gui's Text_edit, which mini-office's text
 * uses), so that an edit costs a few pieces whatever the text's length.
 * Here each edit rebuilds the two strings, since a box's text is
 * small.
 *)

(* [decode] turns a text box's data into its characters and their
 * styles; [encode] turns them back into data. *)
val decode : string -> string * string
val encode : string -> string -> string

(* [px] and [ln] give the x and line of each character, plus one entry
 * for the end; [top] and [tall] give the top and height of each line. *)
type laid = { px : int array; ln : int array; top : int array; tall : int array }
val lay_out : int -> string -> string -> laid

(* the index of the character nearest (x, y) *)
val index_at : laid -> string -> string -> int -> int -> int

(* from the first character to just after the last *)
val selection : Model.doc -> int * int

(* Nothing is selected after it; what is typed next takes the style of
 * the character before. *)
val go_to : Model.doc -> int -> unit

(* replaces the selection *)
val put_text : Model.doc -> string -> string -> unit

(* [restyle d style] sets a style on the selection, or removes it when
 * the whole selection already has it. With nothing selected, it applies
 * to what is typed next. The style 0 is plain. *)
val restyle : Model.doc -> int -> unit

(* [clipboard] holds what was cut or copied, as characters and their
 * styles; [copy] copies the selection there. *)
val clipboard : (string * string) ref
val copy : Model.doc -> unit

(* [edit office i x y selecting] starts editing box i at (x, y). *)
val edit : Model.office -> int -> int -> int -> bool -> unit

(* The keys are in TinyOffice.mli's table. The box grows to show the
 * whole text. *)
val write_key :
  Model.office -> Model.doc -> TinyLibPlayground.key -> unit

(* [text_view box txt sty editing] draws the lines that fit, a word per
 * run of one style, and the selection and cursor while editing. *)
val text_view :
  Model.obj -> string -> string -> Model.doc option ->
  TinyLibPlayground.shape list
