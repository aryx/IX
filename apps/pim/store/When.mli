(* When: a day typed as words, the way a person says it (plan_pim.md,
   idea 5: snooze "monday", "in 3 days"; the recognizer's dates, idea
   4, begin here):

       today  tomorrow                     aujourd'hui  demain
       monday ... sunday, mon ... sun      lundi ... dimanche
         (the next one, never today)
       weekend                             (the next Saturday)
       next week  next month               (Monday; the same day)
       in 3 days, in 2 weeks, in 1 month   dans 3 jours, 2 semaines
       nov 5, 5 nov, november 5            5 novembre
         (this year's, next year's when past)
       2026-11-05, 2026/11/05

   English and the author's French, a day only: a time of day is the
   calendar's (plan_pim.md, stage 3). A day is kept in an item as
   ISO 8601's 2026-11-05, which sorts, and which Search's before: and
   after: read. *)

(* [parse ~today words] *)
val parse : today:Civil.date -> string -> Civil.date option

(* today at Greenwich, from the system's clock *)
val today : unit -> Civil.date

(* [ending ~today line]: a line typed to capture a task, its day at its
 * end found ("pay the electricity by friday": "pay the electricity",
 * Friday), the longest tail of words that is a day, a word left before
 * it; a "by", "on", "due" or "pour" before the day dropped *)
val ending : today:Civil.date -> string -> string * Civil.date option
