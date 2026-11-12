(* TinyOffice's chart: a sheet's cells drawn as bars, and the sheet's
 * name, by which a chart finds it.
 *
 * A chart's data is one line: the word bars, the name of the sheet it
 * draws, the cells holding its values, and the cells holding its
 * labels, if it has any:
 *
 *     bars budget b1:b3 a1:a3           500
 *                                       ###   120
 *                                       ###   ###    80
 *                                       ###   ###   ###
 *                                      -----------------
 *                                       Rent  Food  Bus
 *
 * A range is cells of a column or of a row. The values are read from
 * the sheet at each view (Sheet's values), so a chart follows its
 * sheet; when a sheet is renamed, its charts are renamed too. A chart
 * is made from a sheet, of the chosen cell's column ([make_chart]).
 *
 * others:
 * mini-office's chart (Part_chart) holds its own numbers, and the
 * document rebuilds it from the sheet it is linked to (as in OLE's
 * linking). Here the chart holds only the link, and its view reads the
 * sheet. A spreadsheet (Lotus 1-2-3, 1983, and those after it) keeps
 * its charts inside it; here they are boxes on the page.
 *)

(* [chart_bars page box] reads the bars from the sheet on the page; a
 * cell that is not a number gives 0. With no bars, the string says why. *)
val chart_bars :
  Model.obj list -> Model.obj -> (string * int) list * string

(* the bars scaled against the largest, values above, labels under *)
val chart_view :
  Model.obj list -> Model.obj ->
  TinyLibPlayground.shape list

(* [name_key office typed key]: Enter gives the name to the selected
 * sheet and to its charts. *)
val name_key : Model.office -> string -> TinyLibPlayground.key -> unit

(* [make_chart office c] charts column c of the selected sheet, from its
 * first number to its last, labelled by the column to its left. *)
val make_chart : Model.office -> int -> unit
