(* The descriptions of a unit's values that mini-ml -g writes
 * (plan_debugger.md, the fifth step of decision 14). They are acid's
 * text, kept in the object. mini-ld -g puts them in the program's
 * .acid, and mini-acid runs them after its library. The library's
 * ml(Values.shapes) then prints [Circle 1.5; Rect (3, 4); Empty],
 * where the words alone would say [(1.5); #1(3, 4); 0].
 *
 * They add to lists that the library defines (port.acid); each line
 * adds one more element:
 *
 *     mltypes = append mltypes, {"Values.shape", {}, "variant",
 *         {"Empty"},                          the constant constructors
 *         {"Circle", {"float"}}, {"Rect", {"int"}, {"int"}}};
 *                                             the others, by their tags
 *     mltypes = append mltypes, {"Values.point", {}, "record",
 *         {"x", {"int"}}, {"y", {"int"}}, {"name", {"string"}}};
 *     mltypes = append mltypes, {"Values.t", {"'a"}, "=", {"list", {"'a"}}};
 *     mlglobals = append mlglobals, {"Values.shapes", {"list", {"Values.shape"}}};
 *     mlexns = append mlexns, {"Raise.Bad", {"Raise.shape"}, {"int"}};
 *                                             an exception's arguments
 *     mlsources = append mlsources, {"apps/rio/Rio.ml", "9e10..."};
 *                                             the file's path in ix, MD5
 *
 * A type is a list: its path and its arguments ({"list", {"int"}}).
 * A tuple is "*" and its components, a function is "->", and a
 * variable is its name, "'a". A global is named by its symbol, since
 * the list is read when the program's symbols are not yet set; later,
 * var("Values.shapes") is the address of its word (acid's lexer reads
 * the M.x form). An exception is named by its symbol too, the symbol
 * of its block (the first field of an exception value), so that the
 * runtime can print an uncaught exception's arguments by their types
 * (Printexc). Each type's description is a line of its own, with the
 * same text in every unit that names the type, and mini-ld keeps only
 * one. The predefined types (int, string, list, array...) have no
 * description, because the printer knows them. An abstract type has
 * none either, and is printed as its words.
 *
 * others:
 * DWARF's .debug_info says the same (a DW_TAG_variant_part, a
 * DW_TAG_member each), in a binary form a debugger must parse; here a
 * debugger's language is the format, as 5c -a's (C's: Acid). *)

(* The descriptions of the given values (Typing.global_types) that are
 * in the unit's data (text is its assembly), of the given exceptions
 * that have arguments (Resolve.exceptions), and of the types that they
 * name. *)
val decls : text:string -> (string * Scope.ty) list -> (string * Scope.ty list) list -> string list

(* The line that names the unit's file by its path in ix and gives its
 * MD5 in hexadecimal. The runtime shows a trace's line of code from
 * the copy in /src only when it is the same file (plan_debugger.md,
 * stage 5b). *)
val source : string -> string -> string
