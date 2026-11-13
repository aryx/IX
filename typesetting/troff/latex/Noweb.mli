(* Noweb: a chunk of code in a document, as noweb writes it.
 *
 *   <<function [[addrule]]>>=        its name, then its lines as they
 *   void addrule(char *head) {       are, up to a line with @ alone or
 *       <<[[addrule()]] locals>>     to the next chunk; a chunk can be
 *   }                                named in them
 *   @
 *
 * Each chunk is given a number, in the file's order; on paper the
 * number shown is the sheet's, with a letter (12b), as Latex.mli
 * says. Its name is
 * written with the number of the chunk that first defines it, both
 * here and where another chunk names it. The first definition says
 * where the chunk is used and where it goes on:
 *
 *   <function addrule 41>=   (used in 12; more in 44)
 *
 * The first reading fills the tables (Latex_state.known: defs, uses),
 * and the second writes from them, because a chunk may be used above
 * its definition.
 *
 * cs-history:
 * Literate programming is Donald Knuth's idea (WEB, 1981, for TeX
 * itself). A program is written as a text for a person, with its code
 * in chunks that are named and ordered for the explanation. One tool
 * makes the program from it (tangle), and another makes the document
 * (weave). Norman Ramsey wrote noweb (1989): the same idea with two
 * marks, <<name>>= and @, and for any language. Its weaver names a
 * chunk by its page and a letter (12b); a page is not known when a
 * document is read. *)

(* [chunk t name] is called once the line <<name>>= was read. It reads
 * the chunk's lines and writes the chunk. *)
val chunk : Latex_state.t -> string -> unit

(* \nowebindex: the chunks by name, each with the chunks that define
 * it *)
val index : Latex_state.t -> unit
