(* Imap_server: the server's side of IMAP, for mini-maild, as a machine.
   A line from the client goes in, and the lines of the response come
   out (a literal, which is a message's bytes, goes inside its line:
   "BODY[] {44}\r\n" and then the bytes). The messages and their flags
   are in a store that the program gives it.

   It speaks the subset that mini-pim speaks to Gmail, Gmail's
   extensions included, so that the tests talk to this server and never
   to Gmail:
   - CAPABILITY, LOGIN (any password), LIST, SELECT and EXAMINE;
   - UID SEARCH (ALL, SEEN, UNSEEN, the words of X-GM-RAW with from:
     and subject:, X-GM-MSGID);
   - UID FETCH (UID, FLAGS, RFC822.SIZE, X-GM-LABELS, X-GM-THRID,
     X-GM-MSGID, BODY[], BODY.PEEK[], BODY[HEADER],
     BODY[HEADER.FIELDS (...)]);
   - UID STORE (FLAGS and X-GM-LABELS, set, added or taken off, and
     .SILENT);
   - NOOP and LOGOUT.
   There are two mailboxes, as in Gmail. INBOX holds the messages
   labelled \Inbox, and All Mail holds all of them; its name is the
   store's (Gmail's is in the account's language), and LIST says it is
   \All. A conversation (X-GM-THRID) is the UID of its first message,
   as found by Mail_thread.

   Not here: a client's literals (a LOGIN's password is quoted), IDLE,
   sequence numbers outside UID commands, MOVE, APPEND, EXPUNGE.

   Reference: RFC 3501, 6 the commands, 7 the responses. *)

(* a message as kept: its text (with LF), its flags and its labels *)
type message = { uid : int; text : string; flags : string list;
                 labels : string list }

(* [messages] gives a user's messages, oldest first, and [change] sets a
 * message's flags and labels; [all_mail] is the name of the mailbox
 * that holds all of them ([Gmail]/All Mail) *)
type store = {
  all_mail : string;
  messages : string -> message list;
  change : string -> int -> flags:string list -> labels:string list -> unit;
}

type t

(* a session, and its greeting *)
val start : unit -> t * string list

val step : store -> t -> string -> t * string list

(* has the client said LOGOUT? *)
val ended : t -> bool
