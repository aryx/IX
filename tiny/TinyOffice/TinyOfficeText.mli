(* TinyOffice's text box: its data, how it is laid out in its box, how
 * it is edited as it is shown (WYSIWYG), and its view.
 *
 * A text box's data is its text with a mark where the style changes:
 *
 *     A \{b}bold\{} word, and \{il}large italic\{}.
 *
 * the style's letters between \{ and } (b bold, i italic, u underlined,
 * l large), \{} plain, \\ a backslash. Being edited it is decoded into
 * two strings of the same length, the characters and their styles (a
 * byte each: bold 1, italic 2, underlined 4, large 8), the doc of
 * TinyOfficeModel, and encoded back when the editing ends:
 *
 *     txt   A bold word
 *     sty   00111100000         (one byte a character; 1: bold)
 *
 * The layout fills the box's width a word at a time, each character in
 * its style's width (the kernel's fonts), a line as tall as its largest
 * character; a click is a place in the text (index_at), the inverse.
 * The file's Markdown (TinyOfficeFile) is made from the same two
 * strings.
 *
 * modern:
 * a word processor keeps its text in a piece table (the Alto's Bravo
 * had one, and mini-office's text is lib_gui's Text_edit, another), so
 * that an edit costs a few pieces whatever the text's length; here each
 * edit makes the two strings again, a box's text being small.
 *)

(* a text box's data, as its characters and their styles, and back *)
val decode : string -> string * string
val encode : string -> string -> string

(* A text laid out as the office shows it, in a width in pixels, from its
 * characters and their styles: each character's place (and the end's),
 * its x and its line; each line's top and height *)
type laid = { px : int array; ln : int array; top : int array; tall : int array }
val lay_out : int -> string -> string -> laid

(* [index_at laid txt sty x y]: the place in the text nearest (x, y) *)
val index_at : laid -> string -> string -> int -> int -> int

(* the selection, from its first character to after its last *)
val selection : TinyOfficeModel.doc -> int * int

(* the cursor put at i, no selection, what is typed next in the style
 * of the character before *)
val go_to : TinyOfficeModel.doc -> int -> unit

(* the selection replaced by a text and its styles *)
val put_text : TinyOfficeModel.doc -> string -> string -> unit

(* a style of the selection set, or taken off when all of it has it;
 * nothing selected, of what is typed next; 0 plain *)
val restyle : TinyOfficeModel.doc -> int -> unit

(* what was cut or copied, its characters and their styles; the
 * selection copied there *)
val clipboard : (string * string) ref
val copy : TinyOfficeModel.doc -> unit

(* [edit office i x y selecting]: box i's text edited, its cursor where
 * (x, y) is, the left button selecting from there if it is down *)
val edit : TinyOfficeModel.office -> int -> int -> int -> bool -> unit

(* a key in the text being edited (TinyOffice.mli's table); the box
 * grows to show it all *)
val write_key : TinyOfficeModel.office -> TinyOfficeModel.doc -> int -> unit

(* [text_view box txt sty editing]: a word for each run of characters
 * of a style on a line, the lines that fit; being edited, its selection
 * and its cursor *)
val text_view :
  TinyOfficeModel.obj -> string -> string -> TinyOfficeModel.doc option ->
  TinyLibPlayground.shape list
