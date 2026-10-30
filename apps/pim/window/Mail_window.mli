(* Mail_window: mini-pim's mail in a window (plan_mail.md, stage 5), the
   store's messages as Gmail shows them, and Gmail's keys:

       Pim   Mail   Conversation   Message   Mailbox  <- the menu bar
       Inbox -- erin@ix                              3 conversations
      +-----------+---------------------------------------------------+
      | Inbox     |  news@ix               weekly          2026-10-29 |
      | All Mail  |# Carol (2)             Re: the plan    2026-10-29 |<- the
      | Drafts    |                                                   |  selected
      | /plan     |                                                   |
      +-----------+---------------------------------------------------+

   A view of the suite (Pim_window: its Pim menu, its switcher at the
   sidebar's foot). Every action is in the menu bar (Mail,
   Conversation, Message, Mailbox), each item saying its key, Gmail's:

   j k (and the arrows): the next and the previous conversation; o or
   Enter: open it, its messages one under the other, oldest first; u or
   Escape: back to the list; e: archive it; /: search the store, words
   in who sent it and the subject; Tab: Inbox or All Mail (fetched when
   the password is known); g: get the mail, the app password asked once
   and kept while the window is open, never written (or read from the
   store's file password, if the author made one: Mail_sync). Unread
   conversations are in bold.

   HEY's Screener (Screen), once Mail > Turn On the Screener: the Inbox
   is four lists (the Imbox, the Screener, the Feed, the Paper Trail,
   in the Mailbox menu and the sidebar), a conversation in the one its
   sender's decision says; a new sender's waits in the Screener, y
   lets them in, n screens them out (All Mail still has them); Mailbox
   > Sender: Feed, Paper Trail decide for the sender of the selected
   conversation anywhere.

   Writing (plan_mail.md, stage 7): c a new message; r, a, f a reply,
   a reply to all, a forward of the conversation's newest message
   (Mail_compose). The message is written in the toolkit's widgets
   (lib_gui: To, Cc, Subject, Attach -- files, separated by spaces --
   and the text), kept in the store as a draft at each change, the
   Palm's way; Send (SMTP: Gmail's, or smtp=), Save Draft (or Escape),
   Discard. Mailbox > Drafts lists them; o opens one again.

   The suite's (plan_mail.md, stage 8): z snoozes the conversation
   until a day typed as words (When: monday, in 3 days), archived
   meanwhile and back on top of the Inbox that day, at the next g
   (Mail_sync.wake); t makes its newest message a task, due a day
   typed so, the same item (plan_pim.md, idea 1), then in the suite's
   Tasks (Tasks_window). p adds the conversation's sender to People
   (BBDB's way: by a key, not every address seen; People_window). i
   adds an invitation (a text/calendar part, iMIP) to the Calendar,
   linked to its mail (Events.of_ics).

   The window shows mini-pim's store (Items), not the server: it opens
   at once, with or without the network, on what the last list kept,
   and g fetches (Mail_sync, one IMAP session). A message opened is
   read from the cache, and fetched into it when the password is known
   (marked read on the server then); else the window says g gets it.

   The flags of the program: user= (the account), server=host:port
   and smtp=host:port (Gmail's by default), plain (no TLS:
   mini-maild), today=2026-10-29 (the tests': else the clock's). *)

type caps =
  < Cap.network ; Cap.open_in ; Cap.open_out ; Cap.readdir ; Cap.env ; Cap.exit >

type model

(* the store's mailbox, as the flags say *)
val initial : caps -> Playground.flags -> model

(* the store read again, as the suite comes back to the view; [keys]
 * those down now, not pressed again *)
val refresh : caps -> string Set_.t -> model -> model

(* [show caps m id]: the conversation of the message whose item is [id]
 * opened (a task's, a person's page's) *)
val show : caps -> model -> string -> model

(* [write m to_]: a new message to [to_] *)
val write : model -> string -> model

(* a message written from a mailto: link (Mailto: its to, cc, subject
 * and text; a bcc said, left out) *)
val write_mailto : model -> Mailto.t -> model

(* the conversation read, its messages fetched: their items' ids and
 * the messages (Found_window's, x); none when not reading *)
val opened : model -> (string * Mail.t) list

val update : caps -> Playground.computer -> model -> model

(* the view, under the menu bar and the menus, which the suite draws *)
val view : Playground.computer -> model -> Playground.shape list
