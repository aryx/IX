(* Latex_table: a tabular, LaTeX's table.
 *
 *   \begin{tabular}{lrp{3cm}}        the columns: a side for each one
 *   \toprule                         (l c r), or a width (p{}: its text
 *   File & Lines & What \\           is filled). A row: its cells cut
 *   \midrule                         at &, the rows at \\, as they are
 *   \multicolumn{2}{c}{both} & x \\  written; a rule is a row
 *   \end{tabular}
 *
 * Each cell is then read apart (Latex_output.inlines_of). When the
 * table would not fit on the line, a column of long texts that has no
 * width is filled in what the line has left. A table whose cells are
 * blocks (a minipage, a verbatim text) is not a Doc.table, whose cells
 * are lines of text; its cells are written one after the other. *)

(* a length, in the document's ens: 1in, 3cm, or 0.5\linewidth of the
 * width given *)
val length : Latex_state.t -> float -> string -> float

(* [tabular t env] is called once \begin{env} was read (tabular,
 * tabular*, tabularx, longtable). It reads the table up to its \end
 * and writes it. *)
val tabular : Latex_state.t -> string -> unit
