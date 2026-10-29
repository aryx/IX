(* Search: over every item of the store, Gmail's syntax where it fits
   (plan_pim.md, idea 4), so a search is said one way for mail, tasks,
   people and notes alike:

       alice lunch          words: in any field's value, or the text
       "the plan"           a phrase, quoted
       from:alice           a field's value: from: to: cc: subject:,
       due:2026-11          and any other a person gave an item
       is:task              a stamp; is:unread, is:read: a message's
       label:travel         a message's labels (label:inbox)
       before:2026-12-01    the item's day (due:, else when:, else a
       after:2026/10/01        message's date), before it, or on it and
                               after
       -is:message          not

   Every term must hold (Gmail's AND); a case is not a difference. A
   term name:value where name is no field of the item matches as a
   word, so an id ("contact:alice") is found wherever it is named.

   The server's search is not this: mini-pim -q and the window's / on
   Gmail's side send X-GM-RAW, which searches the whole mailbox, the
   bodies too; this one searches what the store has. *)

type t

val parse : string -> t
val matches : t -> Item.t -> bool

(* [search query items]: those that match, in their order *)
val search : string -> Item.t list -> Item.t list

(* the item's day, the one before: and after: compare: its due:, else
 * its when: (YYYY-MM-DD at its start), else a message's Date:, in the
 * zone it was written in *)
val day : Item.t -> Civil.date option

(* "2026-11-05" or "2026/11/05" *)
val date : string -> Civil.date option
