(* Mail_model: the mail's window's state (Mail_window's keys change it,
   Mail_view draws it), and where it is read from: the store's items
   of the account and the mailbox (Mail_item.listed), as conversations
   (Conversations.group), the Inbox's split by the Screener (Screen),
   those back from a snooze on top; the store's drafts. A third of what
   was Mail_window, split at its 870 lines.

       Mail_model  ---load--->  model  <---update---  Mail_window
                                  |                   (keys, menus,
                                  v                    the server)
                              Mail_view  (the picture) *)

type caps =
  < Cap.network ; Cap.open_in ; Cap.open_out ; Cap.readdir ; Cap.env ; Cap.exit >

(* what waits for the password *)
type action = Fetch | Open | Archive | Star of bool | Send | Snooze of Civil.date
type asking = Password | Search | Until | Due
type mode = Browsing | Reading | Composing | Asking of asking

type model = {
  account : string;
  server : Mail_sync.server;
  smtp : Mail_sync.server;
  mailbox : string; (* INBOX, All Mail, or the store's drafts *)
  (* the Screener (Screen): on or not, the Inbox's list shown, how many
   * wait in the Screener *)
  screening : bool;
  screen : Screen.place;
  waiting : int;
  password : string option; (* kept while the window is open *)
  query : string; (* the search's words, "" for none *)
  conversations : Imap.summary list list;
  drafts : Mail_compose.draft list; (* the drafts mailbox's *)
  today : Civil.date; (* today= (the tests'), else the clock's *)
  selected : int;
  (* the conversation opened: its messages, oldest first, each its text
   * when the cache has it *)
  reading : (Imap.summary * string option) list;
  scroll : int; (* the first line of the conversation shown *)
  mode : mode;
  (* the message written: its fields, its text being edited, and the
   * mode its window goes back to *)
  draft : Mail_compose.draft;
  body : Text_edit.t;
  back_to : mode;
  field : string; (* what is typed after a question *)
  after : action option;
  status : string;
  held : string Set_.t; (* the keys down at the last frame *)
}

val store : caps -> Items.t

(* the drafts' mailbox, the store's, not the server's *)
val drafts : string

(* the conversations and the drafts read again from the store *)
val load : caps -> model -> model

(* the flags: user=, server=, smtp=, plain, today= (Mail_window.mli) *)
val initial : caps -> Playground.flags -> model

(* the sidebar's places, from the top: a name, its mailbox, the
 * Screener's list when it is the Inbox *)
val places : model -> (string * string * Screen.place) list

(* the store read again, [keys] those down now *)
val refresh : caps -> string Set_.t -> model -> model
