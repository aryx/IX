(* mini-ml -g's descriptions of a unit's values (plan_debugger.md,
 * decision 14's fifth step): acid's text, in the object, which mini-ld
 * -g puts in the program's .acid and mini-acid runs after its library,
 * whose ml(Values.shapes) then prints [Circle 1.5; Rect (3, 4); Empty]
 * where the words alone say [(1.5); #1(3, 4); 0].
 *
 * Two lists, the library's (port.acid), each line one more element:
 *
 *     mltypes = append mltypes, {"Values.shape", {}, "variant",
 *         {"Empty"},                          the constant constructors
 *         {"Circle", {"float"}}, {"Rect", {"int"}, {"int"}}};
 *                                             the others, by their tags
 *     mltypes = append mltypes, {"Values.point", {}, "record",
 *         {"x", {"int"}}, {"y", {"int"}}, {"name", {"string"}}};
 *     mltypes = append mltypes, {"Values.t", {"'a"}, "=", {"list", {"'a"}}};
 *     mlglobals = append mlglobals, {"Values.shapes", {"list", {"Values.shape"}}};
 *
 * A type is a list: its path and its arguments ({"list", {"int"}}), a
 * tuple's "*" and its components, a function's "->", a variable's
 * "'a". A global by its symbol's name, read when the program's
 * symbols are not yet set: var("Values.shapes") is its word's address
 * later (the M.x acid's lexer reads). Each type's description a line
 * of its own, the same text in every unit naming it: mini-ld keeps
 * one. The predefined
 * (int, string, list, array...) have none: the printer knows them; an
 * abstract type none: its words.
 *
 * others: DWARF's .debug_info says the same (a DW_TAG_variant_part, a
 * DW_TAG_member each), in a binary form a debugger must parse; here a
 * debugger's language is the format, as 5c -a's (C's: Acid). *)

(* the descriptions of the values given (Typing.global_types) that are
 * in the unit's data (text, its assembly), and of the types they name *)
val decls : text:string -> (string * Scope.ty) list -> string list
