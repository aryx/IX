(* Smtp_server: the server's side of SMTP, the post office's counter,
   as a pure machine: a line of the client's in, the reply's lines out,
   and the message when one has been taken.

       client                         Smtp_server               maildrop
       EHLO pim          ->  250-ix greets pim, 250 AUTH PLAIN
       AUTH PLAIN AGFs.. ->  235 (any password: a test's server)
       MAIL FROM:<a@ix>  ->  250
       RCPT TO:<bob@ix>  ->  250       (another domain: 550, no relay)
       DATA              ->  354
       ... the message
       .                 ->  250 queued   --- a delivery ------>  bob

   It takes mail for its own domain only ("bob@ix", or "bob"), and adds
   a Received: line on top saying from whom and when (every server a
   message crosses adds one: read bottom up, they are its route). Mail
   for elsewhere is refused, 550: a server that passed it on was an
   *open relay*, which every server was in the 1980s, until the spam of
   the 1990s made them all close.

   mini-maild runs it over a socket; the tests run it against Smtp's
   client, a line at a time.

   (ix: the SMTP half of the author's playground's
   libs/networking/unix/Mail_server.ml, as a machine of its own, its
   sockets and its POP3 half left; AUTH PLAIN added, as Gmail asks it.)

   Reference: RFC 5321, 4.1 the commands, 4.4 the Received: line; RFC
   4954, AUTH. *)

type t

(* a message taken: who it is for (the users of the domain), and the
 * message with its Received: line *)
type delivery = { users : string list; mail : Mail.t }

(* [start ~domain]: a session, and its greeting *)
val start : domain:string -> t * string list

(* [step t ~now line]: [now], the seconds since the epoch, for the
 * Received: line *)
val step : t -> now:float -> string -> t * string list * delivery option

(* has the client said QUIT? *)
val ended : t -> bool
