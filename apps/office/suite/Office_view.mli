(* mini-office's view: the start screen, the pages with their objects,
 * a presentation's show, the menu bar and the status line. *)

(* what is on the pages, in the screen's coordinates (Office_page's
   origin): with [chrome] the caret, the selection and an object's
   frame, without them what the show and Export (Office_export) take *)
val page_shapes : chrome:bool -> Document.doc -> Office_model.model -> Playground.shape list

val view : Playground.computer -> Office_model.model -> Playground.shape list
