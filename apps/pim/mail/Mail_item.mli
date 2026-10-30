(* Mail_item: a message as an item of mini-pim's store (Item.mli), what
   makes the mail the suite's (plan_mail.md, "what makes it the
   suite's"; plan_pim.md, idea 1):

       id: mail:1784                  <- Gmail's X-GM-MSGID: the same in
       stamp: message                    every mailbox, where a UID is
       account: bob@gmail.com            the mailbox's
       mailbox: INBOX                 <- where it was last listed, and
       uid: 12                           its UID there
       in: INBOX 12                   <- its UID in each mailbox listed
       in: [Gmail]/All Mail 345          in (a UID is a mailbox's)
       thread: 1784                   <- Gmail's conversation
       labels: (\Inbox travel)        <- as IMAP writes them (Imap.list)
       flags: (\Seen)
       from: Alice <alice@ix>         <- its headers, unfolded, the ones
       subject: the plan                 Imap.summaries asks
       ...

   Written by each list, so that a list without the network shows what
   the last one did; its body is not in it but in the store's cache,
   once read. What the server says replaces what the item said; what a
   person added (a stamp "task", a due date) stays. *)

(* the item's id of a summary: "mail:" and its X-GM-MSGID (its UID when
 * the server gives none) *)
val id : Imap.summary -> string

(* [update ~account ~mailbox summary old]: the item, made, or [old]
 * with the server's fields replaced *)
val update : account:string -> mailbox:string -> Imap.summary ->
  Item.t option -> Item.t

(* the summary an item stands for, to be shown as a listed one *)
val summary : Item.t -> Imap.summary

(* [listed items ~account ~mailbox]: the summaries of the messages
 * listed in that mailbox once, with their UID there (in: lines, one a
 * mailbox), INBOX's those still labelled \Inbox, by UID *)
val listed : Item.t list -> account:string -> mailbox:string ->
  Imap.summary list

(* the key of a message's bytes in the store's cache *)
val key : Item.t -> string

(* [gone item ~mailbox]: no longer in [mailbox] (a list found it not
 * there: archived elsewhere, on Gmail's site, a phone); its in: line
 * taken off, and in INBOX its \Inbox *)
val gone : Item.t -> mailbox:string -> Item.t

(* the item's UID in [mailbox], if it was listed there *)
val uid_in : Item.t -> string -> int option

