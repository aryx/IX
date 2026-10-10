(* A frame that shows a text and lets the hand edit it (Oberon's
 * TextFrames): the lines from a position of the text, in their fonts,
 * a scroll bar at its left; a caret, where what is typed goes; a
 * selection. Every viewer's menu and most viewers' contents are one.
 *
 * The mouse, in the text: the left key sets the caret, the right key
 * selects (from where it goes down to where it goes up), the middle
 * key calls the command whose name is under it (M.P: Oberon.call; the
 * word is underlined while the key is held, and the right key pressed
 * meanwhile gives it up). A second key pressed while the first is held, an
 * interclick: right then left, the selection deleted; right then
 * middle, it is copied to the caret; left then middle, the latest
 * selection is copied here; left then right, it takes the looks at the
 * caret. In the scroll bar: left, the line pointed at goes to the
 * top; right, the text goes back; middle, to the place in the text
 * that the height in the bar says.
 *
 * A frame is told of its text's changes by a message, Update, that
 * the text's notifier broadcasts: several frames may show one text.
 *
 * Simpler than Oberon's: a change draws again the line it is in, or
 * from that line to the frame's bottom when lines are made or gone,
 * and scrolling draws the frame again, where Oberon moves what is on
 * the screen (CopyBlock) and draws only what is new.
 *
 * Where it stands: Texts has the characters and knows no screen;
 * this module has the screen's side, which lines of which text are
 * where, and is the largest of the system, as in Oberon (856 lines
 * of 4,598 there). It is the one place where the three keys' meaning
 * is, so every text of the system (a menu, the log, a directory's
 * listing, a file) is edited and clicked the same way.
 *
 * design:
 * Model and views, kept apart by a broadcast. A change is made to
 * the text (Texts.insert, delete), which knows nothing of frames;
 * the text's notifier sends Update to every viewer, and each frame
 * that shows this text draws what changed. So the caret's frame is
 * not a special case, and System.Copy's second view of a text
 * follows the first with no code for it. It is Smalltalk's
 * model-view-controller without the name, and what a user
 * interface library of today calls observers or reactive state.
 *
 * others:
 * The interclicks are acme's chords: there, the left key held and
 * the middle pressed cuts, the right pastes; Rob Pike took them
 * from Oberon. Both need three keys and a hand that learns them;
 * the rest of the world chose one key and menus, then keys of the
 * keyboard (the ctrl-c, ctrl-x and ctrl-v that are here too).
 * mini-rio's text and mini-emacs, in this tree, are the two other
 * ways.
 *
 * References: "Project Oberon", chapter 5, "The text system" (the
 * frames after the texts; the mouse's keys are in chapter 2's
 * description of the user's side); TextFrames.Mod of Project
 * Oberon 2013. *)

(* the standard sizes: a menu's height, the scroll bar's width *)
val menu_h : int
val bar_w : int

(* a text changed: what, the text, from where to where *)
exception Update of Texts.op * Texts.t * int * int
(* a stretch of a text, to copy at the caret of the frame that has it *)
exception Copy_over of Texts.t * int * int

(* the text of a file, its changes shown by the frames that have it *)
val text : string -> Texts.t
(* a menu's frame: a name, " | ", the commands; black on white *)
val new_menu : string -> string -> Display.frame
(* a text's frame, its first line the one at that position *)
val new_text : Texts.t -> int -> Display.frame

(* what was last deleted or copied (ctrl-x, ctrl-c: ctrl-v's) *)
val tbuf : Texts.buffer ref
(* it, taken (Edit.Recall) *)
val recall : unit -> Texts.buffer

(* A text frame's own state, for a command that works on one (Edit's).
 * [this f]: f's, if f is a text frame (Oberon's type test, F IS
 * TextFrames.Frame: here a message, which a text frame answers). *)
type t
val this : Display.frame -> t option
val text_of : t -> Texts.t
(* the caret's position, if the frame has the caret *)
val caret : t -> int option
val set_caret : t -> int -> unit
val remove_caret : t -> unit
val remove_selection : t -> unit
(* the line at that position becomes the frame's first *)
val show : t -> int -> unit
