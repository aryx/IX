(* Mail_window: mini-pim's mail in a window (plan_mail.md, stage 5), the
   store's messages as Gmail shows them, and Gmail's keys:

       Mail   Conversation   Message   Go             <- the menu bar
       Inbox -- erin@ix                              3 conversations
      +-----------+---------------------------------------------------+
      | Inbox     |  news@ix               weekly          2026-10-29 |
      | All Mail  |# Carol (2)             Re: the plan    2026-10-29 |<- the
      | Drafts    |                                                   |  selected
      | Tasks     |                                                   |
      | People    |                                                   |
      | /plan     |                                                   |
      +-----------+---------------------------------------------------+

   Every action is in the menu bar (Mail, Conversation, Message, Go),
   each item saying its key, Gmail's:

   j k (and the arrows): the next and the previous conversation; o or
   Enter: open it, its messages one under the other, oldest first; u or
   Escape: back to the list; e: archive it; /: search the store, words
   in who sent it and the subject; Tab: Inbox or All Mail (fetched when
   the password is known); g: get the mail, the app password asked once
   and kept while the window is open, never written (or read from the
   store's file password, if the author made one: Mail_sync). Mail > Exit ends
   the program. Unread conversations are in bold.

   Writing (plan_mail.md, stage 7): c a new message; r, a, f a reply,
   a reply to all, a forward of the conversation's newest message
   (Mail_compose). The message is written in the toolkit's widgets
   (lib_gui: To, Cc, Subject, Attach -- files, separated by spaces --
   and the text), kept in the store as a draft at each change, the
   Palm's way; Send (SMTP: Gmail's, or smtp=), Save Draft (or Escape),
   Discard. Go > Drafts lists them; o opens one again.

   The suite's (plan_mail.md, stage 8): z snoozes the conversation
   until a day typed as words (When: monday, in 3 days), archived
   meanwhile and back on top of the Inbox that day, at the next g
   (Mail_sync.wake); t makes its newest message a task, due a day
   typed so, the same item (plan_pim.md, idea 1); Go > Tasks lists the
   tasks not done by their day, the late ones in red, x marks one
   done. p adds the conversation's sender to People (BBDB's way: by a
   key, not every address seen); Go > People lists them, o opens a
   person's page, the mail with them.

   The window shows mini-pim's store (Items), not the server: it opens
   at once, with or without the network, on what the last list kept,
   and g fetches (Mail_sync, one IMAP session). A message opened is
   read from the cache, and fetched into it when the password is known
   (marked read on the server then); else the window says g gets it.

   The flags of the program: user= (the account), server=host:port
   and smtp=host:port (Gmail's by default), plain (no TLS:
   mini-maild), today=2026-10-29 (the tests': else the clock's). The text is drawn
   with Hershey's letters (Glyph_unicode: accents, quotes, dashes),
   each at its place, so a list is in columns. *)

type caps =
  < Cap.network ; Cap.open_in ; Cap.open_out ; Cap.readdir ; Cap.env ; Cap.exit >

type model

(* the store's mailbox, as the flags say *)
val initial : caps -> Playground.flags -> model

val update : caps -> Playground.computer -> model -> model
val view : Playground.computer -> model -> Playground.shape list
