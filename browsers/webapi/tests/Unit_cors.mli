(* Tests of Cors: an address's origin (the port of its scheme left out,
 * no host: null), the interface's worked example of what is the same
 * origin, and who may read an answer by its
 * Access-Control-Allow-Origin. *)
(* ix: the author's mini-chrome's tests/browser/Unit_cors.mli (its 8af888e) (docs/plans/plan_browser.md) *)

val tests : Testo.t list
