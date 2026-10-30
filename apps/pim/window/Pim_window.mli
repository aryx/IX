(* Pim_window: mini-pim's window, the suite (plan_pim.md, "The views"):
   a Home that launches the views, and the views, Mail, Tasks, People,
   over the one store. The terminal's commands (Pim) are the same
   suite without a window; this is the one to look around in.

       Pim                                                <- the menu bar
       mini-pim                          Thursday 29 October 2026
         +----------+     +----------+     +----------+
         |  [mail]  |     | [ticks]  |     |  [face]  |  <- a tile a view:
         |   Mail   |     |  Tasks   |     |  People  |     a click, or
         | 2 unread |     | 3 to do  |     | 4 people |     m t p
         +----------+     +----------+     +----------+
       Today
       late: answer Carol                                 <- in red
       due today: pay the electricity
       back from snooze: the plan

   Home is the beginning of the plan's Today (idea 4): what is late,
   due, back from a snooze; the calendar's events will join it. The
   suite opens on it (view=mail, tasks or people opens a view: the
   tests').

   In a view the first menu is the suite's, Pim (Home, Mail, Tasks,
   People, each with its key, Ctrl and its number, Outlook's Go menu
   and keys; Exit), then the view's own; the sidebar's foot is the
   switcher, Outlook 2003's buttons. A view asks the suite for another
   (Pim_look.go): a task or a person's mail opens the message in Mail,
   "write to" a person a message in Mail. Each view is read again from
   the store as it is shown, so what one changed (a task made in Mail)
   the other shows.

   Not yet: Calendar, Notes, Money (plan_pim.md's stages 3, 6 and 7),
   a search over every view. *)

type caps = Mail_window.caps

type model

(* the flags: Mail_window's, view= the one opened first *)
val initial : caps -> Playground.flags -> model

val update : caps -> Playground.computer -> model -> model
val view : Playground.computer -> model -> Playground.shape list
