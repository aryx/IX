(* Smtp: sending mail, the Simple Mail Transfer Protocol (Jonathan
   Postel, RFC 821, 1982; RFC 5321, 2008).

   A client connects to a server and they talk, one line each way. The
   client sends a command, and the server sends a reply that starts
   with three digits. The first digit is all a client needs to read: 2
   means done, 3 go on, 4 not now (try later), and 5 never. Here is RFC
   5321's own example (appendix D.1), which the tests replay:

       S: 220 foo.com Simple Mail Transfer Service Ready
       C: EHLO bar.com
       S: 250-foo.com greets bar.com        <- "250-": more lines follow
       S: 250-8BITMIME
       S: 250-SIZE
       S: 250-DSN
       S: 250 HELP                          <- "250 ": the last one
       C: MAIL FROM:<Smith@bar.com>
       S: 250 OK
       C: RCPT TO:<Jones@foo.com>
       S: 250 OK
       C: RCPT TO:<Green@foo.com>
       S: 550 No such user here             <- one recipient refused,
       C: RCPT TO:<Brown@foo.com>              the others still take it
       S: 250 OK
       C: DATA
       S: 354 Start mail input; end with <CRLF>.<CRLF>
       C: Blah blah blah...
       C: ....etc. etc. etc.                <- the RFC's "...etc.", sent
       C: .                                    with its dot doubled (below);
                                               a line of a dot is the end
       S: 250 OK
       C: QUIT
       S: 221 foo.com Service closing transmission channel

   There are two things to see in it. First, the *envelope* (MAIL FROM
   and RCPT TO) is not the message's headers: the server delivers to the
   RCPT TOs, whatever To: says. That is how Bcc: works (its recipients
   are in the envelope and nowhere in the message: [envelope] takes the
   Bcc: out), and how a mailing list works. It is also why anybody can
   send mail as anybody: nothing checks MAIL FROM, nor From:, against
   anything (SPF, DKIM and DMARC, thirty years later, are the patch).
   Second, the *dot*: the message ends at a line of a single ".", so a
   line of the message that starts with a dot is sent with one more dot
   ([stuff]), and the server takes it off ([unstuff]). It is the same
   trick as mbox's ">From".

   The client is a pure state machine. [step] is given each line that
   the server sends, and answers with the lines to send back, so it can
   be driven by a socket, a WebSocket, or a test replaying the RFC. It
   sends several messages in one connection, as Eudora's Send Queued
   Messages did by connecting once, and each message is accepted or
   refused on its own.

   References: RFC 5321, "Simple Mail Transfer Protocol" (John
   Klensin, 2008): 4.1 the commands, 4.2 the replies, 4.5.2 the
   transparency (the dot), appendix D the examples; RFC 821 (Jonathan
   Postel, 1982). *)

(*****************************************************************************)
(* {1 Replies and commands} *)
(*****************************************************************************)

(* a reply line: its code, whether more lines follow ("250-"), and its
 * text *)
val reply_line : string -> (int * bool * string) option

(* a reply, as the lines that a server sends: "250-a", "250 b" *)
val reply : int -> string list -> string list

type command =
  | Helo of string
  | Ehlo of string
  | Mail_from of string (* the address, without its <> *)
  | Rcpt_to of string
  | Data
  | Rset
  | Noop
  | Quit
  | Unknown of string

(* a command line, with the verb in any case *)
val parse_command : string -> command
val command_to_string : command -> string

(*****************************************************************************)
(* {1 The message} *)
(*****************************************************************************)

(* who it is from, who it is to, and the message as it is sent *)
type envelope = { sender : string; recipients : string list; text : string }

(* [envelope ~sender mail]: the recipients are the addresses of To:, Cc:
 * and Bcc:, and the text is the message without its Bcc: *)
val envelope : sender:string -> Mail.t -> envelope

(* the text as the lines after DATA: a dot is doubled where a line
 * starts with one, and the "." that ends the text is added *)
val stuff : string -> string list

(* the lines received after DATA, without the final ".", as a text (with
 * LF) *)
val unstuff : string list -> string

(*****************************************************************************)
(* {1 The client} *)
(*****************************************************************************)

type client

(* what became of a message: it was sent to that many recipients (the
 * others were refused, and their replies are kept), or it was refused
 * whole *)
type outcome = Sent of int * string list | Refused of string

(* [client ~hello ~auth envelopes] is the machine, before the server's
 * greeting. With [auth] (a user and a password), it logs in after
 * EHLO, with AUTH PLAIN (RFC 4954, 2007; RFC 4616). That is the patch,
 * 25 years late, for a protocol that never asked who was sending: a
 * server like Gmail's takes mail to elsewhere only from its own users.
 * The user and the password go as one base64 string:
 * "\000tim\000tanstaaftanstaaf" is "AHRpbQB0YW5zdGFhZnRhbnN0YWFm"
 * (RFC 4616's example). Base64 is no secret, so use it only over
 * TLS. *)
val client : hello:string -> auth:(string * string) option -> envelope list -> client

(* the argument of AUTH PLAIN *)
val plain : user:string -> password:string -> string

(* [step c line]: the server said [line]; it returns the machine, and
 * what to send *)
val step : client -> string -> client * string list

(* the outcomes, in the order of the envelopes, once the server has said
 * goodbye. It is Error when the server never said hello, or when the
 * connection is over with messages untried. *)
val finished : client -> (outcome list, string) result option
