(* Js_globals: what libraries look for first -- Object's helpers
 * (defineProperty with a value or a getter, entries, values...),
 * Number's, isFinite, Symbol (a unique key, Symbol.for, hidden from
 * for-in), Map and Set (their order, NaN as a key, in a for-of and a
 * spread); and an undeclared name assigned to, a global *)
(* ix: the author's mini-chrome's tests/js/Unit_js_globals.mli (its 8af888e) (docs/plans/plan_browser.md) *)
val tests : Testo.t list
