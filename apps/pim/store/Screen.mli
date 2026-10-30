(* Screen: HEY's Screener (Basecamp, 2020; plan_pim.md's innovative
   ideas): the first mail of a new sender waits for one decision, and
   the decision is the sender's, kept, so every later message of theirs
   goes where it was said:

       Imbox        the people one reads (HEY's word: important box)
       The Feed     newsletters, read like a paper, when one wants
       Paper Trail  receipts, kept, not read: Money's (plan_pim.md)
       out          screened out, never seen again (All Mail has it)

   A sender in People is in the Imbox, as one who wrote before the
   Screener was turned on (HEY screens new senders only: a Gmail of
   years would else be all in the Screener). Turned on in the store
   (setting:screener, since:), each decision an item:

       id: sender:news@ix
       stamp: sender
       email: news@ix
       screen: feed

   A conversation's sender is its newest message's not the account's;
   one the account began and nobody answered is the Imbox's. *)

type place = Imbox | Screener | Feed | Paper | Out

(* the day the Screener was turned on, None when it is off *)
val since : Item.t list -> string option

(* the setting's item, the Screener on from [today] *)
val turn_on : Civil.date -> Item.t

(* [decide address place]: the decision's item *)
val decide : string -> place -> Item.t

(* the conversation's sender's address (its first message, the newest) *)
val address : Imap.summary -> string

(* [place items ~account conversation] *)
val place : Item.t list -> account:string -> Imap.summary list -> place
