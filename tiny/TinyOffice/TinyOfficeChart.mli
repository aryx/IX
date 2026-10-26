(* TinyOffice's chart: a sheet's cells drawn as bars, and the sheet's
 * name, by which a chart finds it.
 *
 * A chart's data is a line: bars, the sheet it draws by its name, the
 * cells of its values, and of its labels if it has some:
 *
 *     bars budget b1:b3 a1:a3           500
 *                                       ###   120
 *                                       ###   ###    80
 *                                       ###   ###   ###
 *                                      -----------------
 *                                       Rent  Food  Bus
 *
 * a range being cells of a column or of a row. The values are the
 * sheet's at each view (TinyOfficeSheet's values), so a chart follows
 * its sheet; a sheet renamed, its charts are too. A chart is made from
 * a sheet, of the chosen cell's column (make_chart).
 *
 * others:
 * mini-office's chart (Part_chart) holds its numbers, and its document
 * makes it again from the sheet it is linked to (OLE's linking); here
 * the chart holds only the link, and its view reads the sheet. A
 * spreadsheet (Lotus 1-2-3, 1983, and those after it) has its charts
 * inside it; here they are boxes of the page.
 *)

(* [chart_bars page box]: a chart's bars, each its label and its value
 * (a cell that is not a number, 0), from its sheet on the page; or,
 * none, why *)
val chart_bars :
  TinyOfficeModel.obj list -> TinyOfficeModel.obj -> (string * int) list * string

(* [chart_view page box]: a bar a value, as tall as its share of the
 * largest, its value above it, its label under it; the axis *)
val chart_view :
  TinyOfficeModel.obj list -> TinyOfficeModel.obj ->
  TinyLibPlayground.shape list

(* [name_key office typed key]: a key while the selected sheet's name is
 * typed: a character, Backspace, Enter (the name given, to the charts
 * of the sheet too), C-g *)
val name_key : TinyOfficeModel.office -> string -> int -> unit

(* [make_chart office c]: a chart of column c of the selected sheet,
 * beside it (under it, if the page is too narrow): its cells from the
 * first number to the last, the column at its left their labels *)
val make_chart : TinyOfficeModel.office -> int -> unit
