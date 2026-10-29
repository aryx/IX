(* Conversations: messages shown as Gmail shows them, a conversation a
   line (its messages by Gmail's X-GM-THRID, or Mail_thread's where
   there is none), and the few words of a message a list shows. What
   the command line's list and the window's both draw from. *)

(* the summaries as conversations, each its messages newest first, the
 * conversation with the newest message first; the summaries given
 * oldest first (by UID) *)
val group : Imap.summary list -> Imap.summary list list

(* is any message of it unread? *)
val unread : Imap.summary list -> bool

(* a header's value, its encoded words decoded; "" when none *)
val header : Mail.t -> string -> string

(* who sent it: the display name, else the address *)
val who : Mail.t -> string

(* its date's day, "2026-10-29"; "" when none *)
val day : Mail.t -> string
