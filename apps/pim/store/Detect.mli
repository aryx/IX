(* Detect: what a message's text says that the suite could keep
   (plan_pim.md, idea 4: "the same recognizer runs over mail, as Data
   Detectors: a date, a person, an amount in a message, underlined, and
   a key makes it an event, a contact, a posting"; Apple's, Mac OS 8,
   1997):

       Lunch on tuesday at 12:30? It's 24,50 € a head.
                ~~~~~~~~~~~~~~~~        ~~~~~~~
       Dan Brown <dan@ix> comes too.     a day and its time, an
       ~~~~~~~~~~~~~~~~~                 amount, an address

   A day is When's words (Capture's time after it, "at" between): two
   or three words ("nov 5", "in 3 days", "next week"), or one of the
   few that are a day alone (today, tomorrow, the weekdays, English and
   French, an ISO date), so that "may" or "sun" in a sentence are none.
   An amount is a number with a currency sign stuck to it or a word
   beside it ($62.40, 62,40€, 24,50 €, EUR 12, 30 dollars): the last
   separator followed by two digits the cents'. An address is a word
   with an @ inside, its name the capitalized words before it when it
   is written <so>. Each is found once, the first time, within a line. *)

type kind =
  | Day of Civil.date * int option (* the time, minutes after midnight *)
  | Amount of Money.cents
  | Address of string * string (* the name ("" for none), the address *)

(* [said] as it is in the text, [line] the line it is in *)
type found = { said : string; kind : kind; line : string }

(* [find ~today text]: by line, in the order of the text *)
val find : today:Civil.date -> string -> found list

(* where a string begins in another *)
val index : string -> string -> int option

(* "62,40" -> 6240, "1,937.60" -> 193760 *)
val cents_of : string -> int option
