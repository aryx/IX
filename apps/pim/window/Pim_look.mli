(* Pim_look: what mini-pim's views share, so the suite looks one
   program and not three (plan_pim.md, "The views"): the views
   themselves and how one asks for another, the menu bar, the letters,
   the title bar, a list's rows, the sidebar.

       Pim   Mail   Conversation   Message   Mailbox   <- the menu bar:
       Inbox -- erin@ix              3 conversations      the suite's
      +-----------+--------------------------------------+ Pim menu, then
      | Inbox     |  Carol (2)   Re: the plan            |  the view's
      | All Mail  |                                      |
      | Drafts    |                                      |
      |           |                                      |
      | Home      |                                      |<- the suite's
      |#Mail######|                                      |   switcher, at
      | Tasks     |                                      |   the sidebar's
      | People    |                                      |   foot (Pim_window)
      +-----------+--------------------------------------+

   The picture is in the playground's units, the origin at the
   window's centre and y up; the text Hershey's letters
   (Glyph_unicode), each at its place, so a list is in columns. *)

(* the suite's views: Home, the launcher; the components *)
type view = Home | Mail | Tasks | People

(* what a view asks of the suite: another view; a message opened in
 * Mail (its item's id); a message written to someone *)
type go = View of view | Message of string | Write of string

(* the views' names, in the switcher's order *)
val views : (view * string) list

(* the sizes: the menu bar, the letters, a list's row, the sidebar's
 * width, the title bar *)
val menu_bar : float
val size : float
val row : float
val side : float
val bar : float

val ink : Playground.color
val grey : Playground.color
val blue : Playground.color
val red : Playground.color

(* the menu [i]'s title, at the window's top left (0: the suite's) *)
val menu_box : Playground.computer -> int -> Widget.box

(* [chosen computer ~first menus]: the menus asked for this frame (every
 * frame: immediate mode), the first at [first], and the command of the
 * item chosen, if one was *)
val chosen :
  Playground.computer -> first:int -> (string * (string * 'c) list) list ->
  'c option

(* a string's width in the letters *)
val width : string -> float

(* [text color ~bold ~room x baseline s]: [s]'s letters, those past
 * [room] left out *)
val text :
  Playground.color -> bold:bool -> room:float -> float -> float -> string ->
  Playground.shape

(* a text's lines cut at [room], at the spaces *)
val wrap : float -> string -> string list

(* what an item is called: its subject (a message's), its title or
 * name, else its text's first line *)
val title : Item.t -> string

(* what is printable of what was typed; a string less its last letter *)
val printable : string -> string
val without_last : string -> string

(* the window's places: its left edge, the top under the menu bar,
 * where a view's text begins right of the sidebar, its width *)
type area = { left : float; top : float; x0 : float; room : float }

val area : Playground.computer -> area

(* the title bar: the title on the left, [right] on the right *)
val title_bar : Playground.computer -> string -> string -> Playground.shape list

(* the baseline of a list's row [i] under the title bar *)
val row_y : area -> int -> float

(* the selected row's band, its baseline [y] *)
val selected : area -> float -> Playground.shape

(* [sidebar a entries]: the sidebar's places from the top, each its
 * name and whether it is the one shown *)
val sidebar : area -> (string * bool) list -> Playground.shape list

(* "3 conversations", "1 task" *)
val count : int -> string -> string
