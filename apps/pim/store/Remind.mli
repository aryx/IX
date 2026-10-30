(* Remind: what mini-pim remind says, and when (plan_pim.md, idea 6:
   "reminders that run when the window is closed"). An event with a
   time is said 10 minutes before it, or as many as its remind: field
   says (remind: 0 at its start, remind: no never); a task is said when
   its remind: says, "2026-11-03 9:00". The process (Pim's remind)
   asks each minute what was due in the minutes since it last looked.

       12:20  lunch with alice at 12:30
       9:00   call the bank

   Minutes are the local day's (Zone). *)

(* [due items day ~from ~upto]: the reminders whose minute of [day] is
 * in [from, upto), by minute; past 1440 the next day's *)
val due :
  Item.t list -> Civil.date -> from:int -> upto:int -> (int * Item.t) list

(* the words a reminder says: "lunch with alice at 12:30" *)
val say : Item.t -> string
