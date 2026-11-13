(* Lines: a connection that carries lines, over TCP or over TLS, for the
   mail's protocols (SMTP here, IMAP next).

   SMTP and IMAP are dialogues of lines ending in CR LF, and their
   machines are pure (Smtp.step takes a line from the server, and gives
   out the lines to send back). What is left is the socket. The bytes
   that come must be cut into lines, whatever pieces they came in, and
   the lines are sent with their CR LF; for IMAP's literals, a count of
   bytes is read as they are. The connection goes over TLS (Tls_client)
   for Gmail, whose ports speak TLS from the first byte (465 for SMTP,
   993 for IMAP: "implicit TLS", RFC 8314). It goes over plain TCP for
   mini-maild, on this machine.

       Smtp.step   "250 OK"  ->  ["MAIL FROM:<a@ix>"]
            ^ line                  | send_line
            |                       v
       [line]: the bytes cut     "MAIL FROM:<a@ix>\r\n"
       at "\n", "\r" taken off      |
            ^                       v
       Tls_client.receive or     Tls_client.send or
       Tcp.arrived                Tcp.send_all

   (ix: the playground's Transport.t was this: a record of lines over
   TCP, TLS or a WebSocket. lib_networking's README says that it was
   left out when TLS was copied. Here there are only the two kinds that
   a mail program needs.)

   A line is waited for Tcp.timeout seconds at most; a server that says
   nothing for that long, or closes, ends the dialogue.

   The tests check a worked example, against mini-maild's machine on the
   other side of a pair of sockets: [talk] with Smtp's client sends a
   message, and its outcome is Sent to one. *)

type t

(* [plain caps ~host ~port] is TCP, with nothing over it *)
val plain :
  < Cap.network; Cap.open_in; .. > -> host:string -> port:int ->
  (t, string) result

(* [tls caps ~trust ~host ~port] is TLS from the first byte *)
val tls :
  < Cap.network; Cap.open_in; Cap.clock; .. > -> trust:X509.roots -> host:string ->
  port:int -> (t, string) result

(* a connection already made (a test's end of a socketpair) *)
val of_fd : Unix.file_descr -> t

(* sends a line, with its CR LF added *)
val send_line : t -> string -> unit

(* the next line, with its CR LF taken off; None when the other side has
 * closed, or has said nothing for Tcp.timeout seconds *)
val line : t -> string option

(* [bytes t n] is the next [n] bytes, as they are (for an IMAP literal:
 * a message inside a line, "{1234}" and then that many bytes) *)
val bytes : t -> int -> string option

(* [talk conn step machine finished] gives each line that comes to
 * [step], and sends what it answers, until [finished machine] or until
 * the connection ends. It returns the machine as it was then. *)
val talk : t -> ('m -> string -> 'm * string list) -> 'm -> ('m -> bool) -> 'm

(* why the connection ended, when it was not closed: the TLS handshake
 * failed, or the certificate was refused *)
val why : t -> string option

val close : t -> unit
