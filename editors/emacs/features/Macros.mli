(* Keyboard macros: the keys typed between C-x ( and C-x ) are kept,
 * and C-x e types them again. They are Emacs's, and efuns' Macros.
 * There is one macro, the last one.
 *
 *     C-x (  C-a # C-n  C-x )         a # before this line, and down
 *     C-x e  C-x e  C-x e             three more lines commented
 *
 * The keys are kept as their names, given again to
 * Top_window.handle_key. This works because all the editor does comes
 * from its keys, one after the other, with nothing asked on the side.
 * The tests rely on the same property (a session is a line of keys:
 * mini-emacs-tty -keys).
 *
 * cs-history:
 * This is the oldest way to extend an editor, and the one Emacs's
 * name comes from: its first commands were macros, though of TECO's
 * commands and not of keys (Start.mli). A keyboard macro asks its
 * writer to know no language: it is what one would type, kept. vi's
 * dot, which types the last change again, is the same idea made one
 * key. *)
val start_macro : Efuns.action
val end_macro : Efuns.action
val call_macro : Efuns.action
