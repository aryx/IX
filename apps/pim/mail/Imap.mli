(* Imap: reading mail kept on the server, the Internet Message Access
   Protocol (Mark Crispin, 1986; IMAP4rev1, RFC 3501, 2003), Gmail's
   way in for a program.

   POP (1984) carried a mailbox home and emptied the server; IMAP
   leaves it there and looks at it from anywhere, which is why the
   phone and this program agree on what is read. It is harder to read
   than SMTP, and the difficulty is the lesson:

   - Commands are *tagged*, so that several can be in flight, and the
     server's answer to one ends with a line of the same tag:

       C: a3 UID SEARCH X-GM-RAW "from:alice"
       S: * SEARCH 4 9 12                    <- untagged: data
       S: a3 OK SEARCH completed             <- tagged: a3 is done

     Untagged lines also come unasked: "* 13 EXISTS", a message arrived
     while another command ran. A client takes them whenever they come.

   - *Literals*: "{1234}" at a line's end, then that many bytes, so
     that a message, any bytes, travels inside a line-based protocol:

       S: * 2 FETCH (UID 9 BODY[] {44}       <- the line, its count
       S: Subject: lunch                        44 bytes, CR LF and all,
       S:                                        that are not lines of
       S: Noon at the usual place?               the protocol
       S: )                                  <- the line goes on

   - The data is a syntax of its own, read by [read] here: atoms
     (FLAGS, \Seen, BODY[HEADER]), quoted strings, NIL, and lists in
     parentheses, nested. "* 2 FETCH (UID 9 FLAGS (\Seen))" is
     [Atom "2"; Atom "FETCH"; List [Atom "UID"; Atom "9"; Atom "FLAGS";
     List [Atom "\Seen"]]]. (Numbers are atoms: Gmail's thread ids are
     64 bits, more than an int on a 32-bit arm.)

   - *UIDs*: a message's number in its mailbox that does not change,
     while its sequence number (2 above) shifts when one before it goes;
     a client asks by UID (UID SEARCH, UID FETCH). UIDVALIDITY, given
     at SELECT, says when the UIDs were renumbered and a cache must go.

   Gmail's extensions (X-GM-EXT-1): X-GM-LABELS, a message's labels
   (Gmail has labels, not folders; "INBOX" is the label \Inbox, and
   archiving is taking it off); X-GM-THRID, its conversation; X-GM-RAW,
   a search in Gmail's own syntax, done by Gmail.

   The headers are asked as BODY.PEEK[HEADER.FIELDS (...)], read by
   Mail.parse, rather than as IMAP's ENVELOPE, a structure of its own
   with no References: (which conversations need where there is no
   Gmail). PEEK: looking is not reading; BODY[], the whole message,
   marks it read (\Seen).

   Worked examples (checked by the tests): the FETCH above read, its
   literal the message; the client against mini-maild's machine
   (Imap_server): a login, INBOX selected, its messages searched,
   their headers, a body, a label taken off.

   Reference: RFC 3501, "INTERNET MESSAGE ACCESS PROTOCOL - VERSION
   4rev1" (Mark Crispin, 2003): 6 the commands, 7 the responses, 9 the
   formal syntax; Google's "Gmail IMAP Extensions"
   (developers.google.com/gmail/imap/imap-extensions). *)

(*****************************************************************************)
(* {1 The responses} *)
(*****************************************************************************)

type value = Atom of string | String of string | List of value list | Nil

type response =
  (* a tagged status ("a3 OK ...", Some "a3"), or an untagged one
   * ("* OK [UIDVALIDITY 3] ...", None): its word (OK, NO, BAD, BYE,
   * PREAUTH) and the text after it, as it is *)
  | Status of string option * string * string
  (* any other untagged response: "* SEARCH 4 9" *)
  | Data of value list
  (* "+ ...": go on (IDLE, a literal the client sends) *)
  | Continue of string

(* [read ~line ~bytes]: the next response, its literals read with
 * [bytes] (Lines.line and Lines.bytes); None when the connection
 * ended *)
val read : line:(unit -> string option) -> bytes:(int -> string option) ->
  response option

(* the values of a text with no literal: a command's arguments *)
val values : string -> value list

(* a string as IMAP writes it: quoted, its backslashes and double
 * quotes escaped *)
val quote : string -> string

(* [pairs l]: "(UID 9 FLAGS (\Seen))"'s list as [("UID", Atom "9");
 * ("FLAGS", List ...)], the names in upper case *)
val pairs : value list -> (string * value) list

(* an atom's or a string's text; "" else *)
val text : value -> string

(* flags or labels as a list: "(\\Inbox \"my label\")", one with a space
 * quoted *)
val list : string list -> string

(* a list's texts; [] for what is not a list *)
val texts : value -> string list

(* "1,3:5": a set of UIDs as IMAP writes it *)
val uid_set : int list -> string

(*****************************************************************************)
(* {1 The client} *)
(*****************************************************************************)

type t

val connect : Lines.t -> (t, string) result

(* [command t "UID SEARCH ALL"]: sent with the next tag, the responses
 * read until its own; the untagged ones, or the tagged NO or BAD's
 * text *)
val command : t -> string -> (response list, string) result

val login : t -> user:string -> password:string -> (unit, string) result

(* the mailbox's UIDVALIDITY *)
val select : t -> string -> (string, string) result

(* LIST "" "*": each mailbox's attributes and name. Gmail's own are
 * known by an attribute (RFC 6154), not by their names, which are in
 * the account's language: \All is [Gmail]/All Mail in English, and
 * [Gmail]/Tous les messages in French; \Sent, \Drafts, \Trash *)
val mailboxes : t -> ((string list * string) list, string) result

(* the UIDs a search gives, in order: "ALL", "UNSEEN",
 * "X-GM-RAW \"from:alice\"" *)
val search : t -> string -> (int list, string) result

(* what a list of messages shows *)
type summary = {
  uid : int;
  flags : string list; (* \Seen, \Answered, ... *)
  labels : string list; (* Gmail's: \Inbox, \Important, travel ... *)
  thread : string; (* Gmail's conversation, "" when none *)
  msgid : string; (* Gmail's id of the message, the same in every
                     mailbox, where a UID is the mailbox's; "" when none *)
  headers : Mail.t; (* From, To, Cc, Subject, Date and the ids, no body *)
}

val summaries : t -> int list -> (summary list, string) result

(* the whole message, LF; marked read *)
val message : t -> int -> (string, string) result

(* [store t uids change]: "+FLAGS (\\Seen)", "-X-GM-LABELS (\\Inbox)" *)
val store : t -> int list -> string -> (unit, string) result

val logout : t -> unit
