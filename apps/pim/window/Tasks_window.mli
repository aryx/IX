(* Tasks_window: the suite's tasks (plan_pim.md, stage 5), what has the
   stamp task, whatever else it is (idea 1: a message made a task in
   Mail is the message, here too):

       Pim   Task   List
       To Do                                       3 tasks, 1 snoozed
      +-----------+---------------------------------------------------+
      |#To Do#####| 2026-10-28   answer Carol  (mail)                 |<- late:
      | Done      | 2026-10-30   pay the electricity                  |  in red
      |           | -            buy bread                            |
      +-----------+---------------------------------------------------+

   n captures a task in one line, its day at the end as words ("pay
   the electricity by friday": When.ending, the recognizer's first
   use, plan_pim.md's idea 4); x marks it done (in Done, to do again);
   d sets its day; z snoozes it (until:, idea 5: hidden until that day,
   as a snoozed message is); o opens it: a message in Mail, else its
   page (its fields and its text); Tab shows To Do or Done. Things'
   and Todoist's list, by day, without projects: a task's context is
   what it is stamped on. *)

type caps = Mail_window.caps

type model

(* today= the tests' day, else the clock's *)
val initial : caps -> Playground.flags -> model

(* the store read again, as the suite comes back to the view; [keys]
 * those down now *)
val refresh : caps -> string Set_.t -> model -> model

(* [show caps m id]: the task [id]'s page *)
val show : caps -> model -> string -> model

(* a frame; and what it asks of the suite: a message opened in Mail *)
val update : caps -> Playground.computer -> model -> model * Pim_look.go option

(* the view, under the menu bar and the menus, which the suite draws *)
val view : Playground.computer -> model -> Playground.shape list
