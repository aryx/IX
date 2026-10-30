(* Today: the day as the plan's agenda says it (plan_pim.md, idea 4;
   org-mode's agenda, Outlook Today), what Home shows and the
   terminal's `mini-pim today` prints, read from the store:

       12:30      lunch with alice               <- the day's events
       late       answer Carol                   <- tasks past their day
       due        pay the electricity   62.40    <- a bill, its amount
       back       the plan                       <- back from a snooze
       from Alice lunch?                         <- unread, from a person
                                                    of the address book

   Mail from people only, not every newsletter: Gmail's Important
   without its guessing. Then the day's page (day:2026-10-29), the
   daily note, written in Notes. *)

(* what a line is: an event at its time (None: all day), a task late or
 * due, an item back from a snooze, a conversation not read from a
 * person *)
type kind = At of int option | Late | Due | Back | From of string

(* the tasks not done, not put off to someday (GTD's someday/maybe:
 * someday:), and not snoozed past [today] *)
val to_do : Item.t list -> Civil.date -> Item.t list

(* those of to_do whose day is past, is today *)
val late : Item.t list -> Civil.date -> Item.t list
val due : Item.t list -> Civil.date -> Item.t list

(* [lines items ~account today]: the day, in that order *)
val lines :
  Item.t list -> account:string -> Civil.date -> (kind * string) list

(* today's page's lines, those not empty *)
val page : Item.t list -> Civil.date -> string list

(* [again task]: a repeating task done (a bill each month, repeat:
 * FREQ=MONTHLY;BYMONTHDAY=5), the next one: due its rule's next day
 * after this one's, an id of its day ("task:rent.2026-12-05") *)
val again : Item.t -> Item.t option

