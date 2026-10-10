(* A bar chart, as a part of a compound document (appkit_embed): a
 * label and a number per bar, drawn into whatever rectangle it is
 * given, with a size of its own (300 x 200) for a host to scale.
 *
 * It holds its numbers rather than a sheet: where they come from is
 * the host's business -- TinyOffice *links* a chart to a sheet, and
 * makes the chart again from the sheet's cells whenever it draws it,
 * so the bars follow the cells as they are typed (OLE's linking, beside
 * the embedding of every other part). A chart whose sheet is gone
 * keeps the last numbers it was given. It has no menu and takes no
 * input: it is edited by editing its sheet.
 *
 * (In ix TinyOffice is mini-office, and the link is Document's
 * [link] and [refreshed]: a chart object says which sheet, the main
 * one or an object by its id, and Document makes the part again.)
 * The tallest bar fills the height and the others are in proportion
 * to it; a bar's label is under it and its number over it. It saves
 * a bar a line, the label, a tab, the number.
 *
 * cs-history:
 * The chart of a sheet is the 2 of Lotus 1-2-3 (1983): the
 * worksheet, the graph and the database in one program, over the
 * same cells. VisiCalc's users bought a second program for it,
 * VisiPlot, and carried the numbers over; its author, Mitch Kapor,
 * went on to found Lotus. Excel made the chart a document of its
 * own, linked to its sheet, which is the shape here. *)

val kind : string
val make : (string * float) list -> Component.part
val load : string -> Component.part

(* [of_sheet sheet]: the bars a sheet gives -- column A's labels and
 * column B's numbers, over the first run of rows whose B is a number
 * typed in, not computed: the data, and not the total below it.
 *
 *     A      B
 *     Month  Sales     <- not a number: skipped
 *     Jan    120       <- the bars:  Jan 120, Feb 150, Mar 90
 *     Feb    150
 *     Mar    90
 *                      <- the run ends
 *     Total  =SUM(..)  <- computed: not a bar *)
val of_sheet : Sheet.t -> (string * float) list
