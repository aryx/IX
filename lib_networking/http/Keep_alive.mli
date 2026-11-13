(* Connections kept: a request is sent on the connection that the last
   one used, instead of on a new one each time.

   HTTP/1.0 closed the connection after each answer: the end of the
   body was the end of the connection, and there was nothing to count.
   A page of forty pictures was then forty connections. Each one paid
   for the three packets of TCP's opening and for its slow start, and,
   since the web is encrypted, for a TLS handshake. Here a handshake is
   some 0.2 s of arithmetic (a key agreed, a chain of certificates
   checked), on top of two round trips.

     without                         with
     ------------------------------  ------------------------------
     connect, handshake              connect, handshake
     GET /a.png   -> 200, closed     GET /a.png   -> 200
     connect, handshake              GET /b.png   -> 200
     GET /b.png   -> 200, closed     GET /c.png   -> 200
     connect, handshake              ... (left open a while)
     GET /c.png   -> 200, closed

   For the connection to stay open, the answer must say by itself where
   it ends, with a Content-Length or a body in chunks (Http.extent). An
   answer that says neither ends when the connection does, and that
   connection is not kept.

   The pool is a list of connections at rest, each with its host, its
   port, and when it was put there. [exchange] takes one for its host
   if there is one (the most recent), or else connects. When the answer
   is whole and the server did not say "Connection: close", the
   connection goes back to the pool. A connection at rest for more than
   [patience] seconds is closed, not used, because servers close theirs
   after some seconds of silence (nginx after 75 by default; many after
   less).

   The one subtlety is that a connection taken from the pool may be
   dead, because the server closed it since, and this is seen only when
   nothing comes back. Then, and only if not one byte of an answer
   came, the request is sent again on a new connection, because nothing
   says that the server read it (RFC 9112, section 9.3.1). For a POST,
   a browser asks less, and so do we: the same rule applies.

   The pool belongs to the program; there are no threads here, so there
   is no mutex around it.

   Here is what it bought in mini-chrome, on discuss.ocaml.org's front
   page (31 style sheets, and 60 avatars each behind a redirection: 150
   requests to three hosts), on 2026-10-04:

                                          closed each    kept
     the pictures (60, two requests each)      15 s          7 s
     the program's CPU for the whole load      18 s          9 s

   (Then, with six threads where there had been four, the pictures took
   4.5 s. The same day, the page's 31 sheets stopped costing a layout
   each, which had been 12 s more: docs/dev/notes_debugging_techniques.txt,
   session 5.)

   cs-history:
   "Connection: Keep-Alive" was an extension of HTTP/1.0 by the servers
   and browsers of 1995 (Netscape's among them). HTTP/1.1 (RFC 2068,
   January 1997) made it the default, and gave the body its framings
   for it, the chunks among them. Jeffrey Mogul's "The Case for
   Persistent-Connection HTTP" (SIGCOMM 1995) and Venkata Padmanabhan
   and Mogul's "Improving HTTP Latency" (1994) are the measurements
   that argued for it.

   modern:
   A browser keeps six connections for each host and sends one request
   at a time on each. HTTP/2 (2015) sends them all at once on one
   connection, as numbered streams. TLS 1.3 can resume a session
   without the whole handshake (with a ticket, which is not done here:
   Tls13.mli).

   Reference: RFC 9112 (HTTP/1.1), section 9: Connection Management. *)

(* [exchange caps ~trust ~host ~port request] is the answer's bytes,
 * whole (its head, and its body as framed), over TLS; Tcp.timeout
 * seconds of silence are an error. It is like Tls_client.exchange,
 * which closes the connection after each answer. *)
val exchange :
  < Cap.network; Cap.open_in; Cap.clock; .. > -> trust:X509.roots -> host:string -> port:int -> string -> (string, string) result

(* [once caps ~trust ~host ~port request] is the same answer on a new
 * connection, which is closed after it; no connection is kept *)
val once :
  < Cap.network; Cap.open_in; Cap.clock; .. > -> trust:X509.roots -> host:string -> port:int -> string -> (string, string) result

(* how long a connection at rest is still used, in seconds *)
val patience : float

(* closes the connections at rest (at a test's end) *)
val clear : unit -> unit

(* how many requests went on a connection already open, since the start *)
val reused : unit -> int
