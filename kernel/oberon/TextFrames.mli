(* A frame that shows a text and lets the hand edit it (Oberon's
 * TextFrames): the lines from a position of the text, in their fonts,
 * a scroll bar at its left; a caret, where what is typed goes; a
 * selection. Every viewer's menu and most viewers' contents are one.
 *
 * The mouse, in the text: the left key sets the caret, the right key
 * selects (from where it goes down to where it goes up), the middle
 * key is for a command (the commands' stage: the word is only
 * underlined). A second key pressed while the first is held, an
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
 * the screen (CopyBlock) and draws only what is new. *)

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
