(* Keyboard macros: the keys typed between C-x ( and C-x ) are kept,
 * and C-x e types them again. Emacs's, and efuns' Macros. One macro,
 * the last. *)
val start_macro : Efuns.action
val end_macro : Efuns.action
val call_macro : Efuns.action
