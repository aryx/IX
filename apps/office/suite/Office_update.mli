(* mini-office's update: a frame's mouse and keys given to the start
 * screen, the File menu's dialog, the menus, the object edited in
 * place, the page.
 *
 * Who gets a frame's input, in the order the code asks. The first
 * that applies takes the frame; inside the last, each line is tried
 * in turn:
 *
 *   a File dialog is up     File_menu.dialog, and nothing else
 *   the start screen        its Open..., its five tiles
 *   the show                next slide, the one before, Escape
 *   a page being edited:
 *     the menu bar          Gui.menu_in for each menu; an item chosen
 *                           is Office_edit.command, or File_menu's.
 *                           A menu open stops here (Gui.modal)
 *     the mouse on the page a drag going on; its release; or a press:
 *                           on a corner of the selected object (it is
 *                           resized), on an object (selected, moved),
 *                           on the text (the caret goes there), in a
 *                           page's margin (its header or footer)
 *     the keys, and the     to the object edited in place
 *     mouse again           (Component.input_in), or the object
 *                           selected (Delete, Escape), or the main
 *                           part, or the text (typing)
 *     the wheel, the        the pages scrolled
 *     page keys
 *
 * An object's three states are made of two clicks: a press selects
 * it and may drag it; a press and release without moving, on the one
 * already selected, starts editing it in place, the menu bar then its
 * own; Escape, or a press elsewhere, puts it down. Editing in place
 * is nothing but the line above: the part is given the computer and
 * its box, and answers with the part it has become.
 *
 * It is one function from the model to the model, with no effect but
 * the File menu's, which is why the capabilities come this far and
 * no further: the parts and the kits are given none, and cannot
 * reach a file.
 *
 * design:
 * There is no event, no handler and no table of which widget has
 * the focus. Routing is the order of the tests above, read top to
 * bottom, and a modal state is a test near the top. It is the
 * simplest thing that works and it is honest about its cost: every
 * new way to take the mouse is a new line in this one function,
 * which must be put at the right height. A retained toolkit moves
 * that knowledge into a tree of widgets and the rules for walking
 * it (Retained.mli; the browser's events, which go down the tree
 * and bubble back up). *)

(* where the start screen's five kinds and its Open... are (the view's too) *)
val tile : int -> Widget.box

val open_button : Widget.box

(* a frame: the computer's mouse and keys, the model after them. The
   capabilities are the File menu's: a document stored, fetched, the
   store listed. [exported]: the document as the bytes Export writes
   (Office_export.pdf: given, the view's shapes being what it writes
   and the view coming after this) *)
val update : File_menu.caps -> exported:(Office_model.model -> string) -> Playground.computer -> Office_model.model -> Office_model.model
