(* Mail_window: mini-pim's mail in a window (plan_mail.md, stage 5), the
   store's messages as Gmail shows them, and Gmail's keys:

       Inbox -- erin@ix                              3 conversations
      +-----------+---------------------------------------------------+
      | Inbox     |  news@ix               weekly          2026-10-29 |
      | All Mail  |# Carol (2)             Re: the plan    2026-10-29 |<- the
      |           |                                                   |  selected
      | /plan     |                                                   |
      +-----------+---------------------------------------------------+

   j k (and the arrows): the next and the previous conversation; o or
   Enter: open it, its messages one under the other, oldest first; u or
   Escape: back to the list; e: archive it; /: search the store, words
   in who sent it and the subject; Tab: Inbox or All Mail (fetched when
   the password is known); g: get the mail, the app password asked once
   and kept while the window is open, never written. Unread
   conversations are in bold.

   The window shows mini-pim's store (Items), not the server: it opens
   at once, with or without the network, on what the last list kept,
   and g fetches (Mail_sync, one IMAP session). A message opened is
   read from the cache, and fetched into it when the password is known
   (marked read on the server then); else the window says g gets it.

   The flags of the program: user= (the account), server=host:port
   (Gmail's by default), plain (no TLS: mini-maild). The text is drawn
   with Hershey's letters (Glyph_unicode: accents, quotes, dashes),
   each at its place, so a list is in columns. *)

type caps = < Cap.network ; Cap.open_in ; Cap.open_out ; Cap.readdir ; Cap.env >

type model

(* the store's mailbox, as the flags say *)
val initial : caps -> Playground.flags -> model

val update : caps -> Playground.computer -> model -> model
val view : Playground.computer -> model -> Playground.shape list
