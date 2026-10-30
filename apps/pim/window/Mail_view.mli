(* Mail_view: the mail's picture, Mail_window's split at its 870 lines:
   the title bar (the mailbox, or the question asked), the sidebar (the
   mailboxes, the Screener's lists), and the list of conversations, the
   one read with what Detect finds underlined, or the message being
   written; and where the writing's widgets are, which the window's
   keys (Gui's immediate mode) and the picture both need. *)

(* the message's fields (To, Cc, Subject, Attach), its text, its
 * buttons (Send, Save Draft, Discard): under the title bar, right of
 * the sidebar *)
val field_box : Playground.computer -> int -> Widget.box
val area_box : Playground.computer -> Widget.box
val button_box : Playground.computer -> int -> Widget.box

(* how many rows the list shows, how many lines the reading; the lines
 * of the conversation read (its scrollbar's length); the lists'
 * bottom *)
val list_fits : Playground.computer -> int
val reading_fits : Playground.computer -> int
val lines : Playground.computer -> Mail_model.model -> int
val bottom : Playground.computer -> float

(* the list's name: Inbox, Starred, The Screener... *)
val name : Mail_model.model -> string

(* the view, under the menu bar and the menus, which the suite draws *)
val view : Playground.computer -> Mail_model.model -> Playground.shape list
