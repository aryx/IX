(* mini-office's view: the start screen, the pages with their objects,
 * a presentation's show, the menu bar and the status line.
 *
 * A function from the model to a list of shapes, back to front; what
 * is later in the list covers what is before it:
 *
 *   the desk             a grey rectangle
 *   the sheets of paper  a white rectangle a page, and its shadow
 *   [page_shapes]        the main part, or the text's letters and the
 *                        caret; each page's header and footer, their
 *                        fields filled; the objects in their order,
 *                        each on a white box (but one in front of the
 *                        text), with its frame and corners if selected
 *   the bars             the menu bar's and the status line's grounds,
 *                        over the pages scrolled under them
 *   File_menu.view       a dialog's panel, if one is up
 *   Gui.draw ()          the widgets the update asked for this frame:
 *                        the menus, a dialog's buttons and list
 *
 * Nothing is remembered of the frame before and nothing is erased:
 * the whole picture is said again at each frame, and what makes that
 * affordable is below this program: a view is data, so a platform
 * compares a frame's shapes with the last one's and draws again only
 * where they differ (Redraw). That is why a page's letters are given
 * as one group, the same value while the page is the same: one
 * comparison, not thousands.
 *
 * design:
 * [page_shapes] is written once and used three times: on the screen
 * with the caret and the selection, in the show without them and
 * scaled to the screen, and by Office_export, which writes the same
 * shapes to a PDF. So the slide shown and the page printed cannot
 * differ from the one edited: there is no second drawing code to
 * keep in step. It costs a flag, [chrome], for what belongs to the
 * editing and not to the document. *)

(* what is on the pages, in the screen's coordinates (Office_page's
   origin): with [chrome] the caret, the selection and an object's
   frame, without them what the show and Export (Office_export) take *)
val page_shapes : chrome:bool -> Document.doc -> Office_model.model -> Playground.shape list

val view : Playground.computer -> Office_model.model -> Playground.shape list
