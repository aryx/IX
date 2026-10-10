(* A spreadsheet, as a part of a compound document (appkit_embed):
 * TinyExcel's engine and its drawing (Sheet, Sheet_view) behind the
 * four functions a document asks of a part. Active, a click selects a
 * cell and typing goes straight into it -- Enter to put it in, Escape
 * to leave it -- since a part has no formula bar of its own.
 *
 * It has a natural size, its columns and rows at Sheet_view's cell
 * size, so a host may scale it (Component.draw_in) where a text
 * would reflow. It saves as Sheet.to_string, a cell a line, and
 * that text is all a chart linked to it reads (Document.refreshed):
 * the chart never sees the part, only what it saves. As a
 * spreadsheet document's body it is the same part, made with more
 * columns and rows. *)

val kind : string
(* [make ~cols ~rows sheet]: 3 columns and 5 rows (the playground's
 * default, and [load]'s) are a table in a document; a sheet that is
 * the document asks for more *)
val make : cols:int -> rows:int -> Sheet.t -> Component.part
val load : string -> Component.part
