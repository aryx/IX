(* Js_scope, Js_frame, Js_quicken and Js_compile: their worked examples, a name found the fast way where the
 * simple way finds it (each program run on both, the two answers the
 * same and the one expected), in the corners where a remembered place
 * could be wrong: a name shadowed, a function called from two places,
 * a with, a switch entered by two cases, a function of many names *)
(* ix: the author's mini-chrome's tests/js/Unit_js_scope.mli (its 8af888e) (docs/plans/plan_browser.md) *)
val tests : Testo.t list
