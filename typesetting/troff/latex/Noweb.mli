(* Noweb: a chunk of code in a document, noweb's.
 *
 *   <<function [[addrule]]>>=        its name, then its lines as they
 *   void addrule(char *head) {       are, to a line with @ alone or to
 *       <<[[addrule()]] locals>>     the next chunk; a chunk named in
 *   }                                them
 *   @
 *
 * A chunk is given a number, in the file's order. Its name is written
 * with the number of the chunk that first defines it, here and where
 * another chunk names it; the first definition says where it is used
 * and where it goes on:
 *
 *   <function addrule 41>=   (used in 12; more in 44)
 *
 * The first reading fills the tables (Latex_state.known: defs, uses),
 * the second writes from them: a chunk is used above its definition.
 *
 * cs-history:
 * Literate programming is Donald Knuth's (WEB, 1981, for TeX itself):
 * a program written as a text for a person, its code in chunks named
 * and ordered for the explanation, from which one tool makes the
 * program (tangle) and another the document (weave). noweb is Norman
 * Ramsey's (1989): the same with two marks, <<name>>= and @, and any
 * language. Its weaver says a chunk by its page and a letter (12b);
 * a page is not known when a document is read. *)

(* [chunk t name]: the line <<name>>= was read; the chunk's lines are
 * read and the chunk written *)
val chunk : Latex_state.t -> string -> unit

(* \nowebindex: the chunks by name, each with the chunks that define it *)
val index : Latex_state.t -> unit
