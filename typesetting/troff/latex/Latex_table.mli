(* Latex_table: a tabular, LaTeX's table.
 *
 *   \begin{tabular}{lrp{3cm}}        the columns: a side each (l c r),
 *   \toprule                         or a width (p{}: its text filled)
 *   File & Lines & What \\           a row: its cells cut at &, the
 *   \midrule                         rows at \\, as they are written;
 *   \multicolumn{2}{c}{both} & x \\  a rule is a row
 *   \end{tabular}
 *
 * Each cell is then read apart (Latex_output.inlines_of). A column of
 * long texts with no width is filled in what the line has left, when
 * the table would not fit on it. A table whose cells are blocks (a
 * minipage, a verbatim text) is not a Doc.table, whose cell is a line
 * of text: its cells are written one after the other. *)

(* a length, in the document's ens: 1in, 3cm, 0.5\linewidth of the
 * width given *)
val length : Latex_state.t -> float -> string -> float

(* [tabular t env]: \begin{env} was read (tabular, tabular*, tabularx,
 * longtable); the table is read to its \end and written *)
val tabular : Latex_state.t -> string -> unit
