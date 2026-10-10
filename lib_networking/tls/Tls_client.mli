(* Tls_client: TLS 1.3 over a real socket -- our own (Tls13.mli), with
   the system's trusted roots.

   Tls13 is a pure machine, bytes in and bytes out; this is the rest:
   the TCP connection (Tcp.mli), 96 bytes of randomness from
   /dev/urandom (the hello's random, the session id, the X25519 key --
   a pure machine rolls no dice), the roots read once from the system's
   bundle (/etc/ssl/certs/ca-certificates.crt, or where the other
   systems keep it), the chain checked with them at the time of day
   (X509.verify), and the loop that carries the bytes between the socket
   and the machine, never waiting.

   Reading the system's roots and the kernel's randomness is part of
   what reaching a host over TLS means; ix says it in the type all the
   same: Cap.open_in beside Cap.network.

   The loop, for one request:

       Http_client      "GET / HTTP/1.1 ..."          the answer's bytes
            | send                                        ^ receive
       Tls13.write: records, sealed          Tls13.read: records opened
            |                                             ^
            v            [step], until the server closes  |
       Unix.write  -------- the socket (Tcp.connect) ---- Unix.read
                            Tls13.received: every byte that came,
                            handshake or data, and what to answer

   What is asked before the handshake is done is queued; the
   machine's state says when it may go. A chain once checked for a
   host is remembered until its first certificate expires, so a
   page's twenty pictures from one server cost one chain's signatures
   and not twenty; CertificateVerify is checked every time, being the
   proof that the server holds the key now.

   others:
   Where the roots are is each system's own answer, and a client
   tries them in turn: one file of PEM on Debian
   (/etc/ssl/certs/ca-certificates.crt), another on Red Hat, another
   on the BSDs and macOS; Windows keeps them in its registry, and
   Firefox ships its own list and asks no system. The list itself is
   nearly the same everywhere: Mozilla's, which the Linux
   distributions repackage.

   [exchange] is one request and its whole answer, for HTTPS
   (Http_client). (ix: the playground's other face, a Transport.t of
   lines for POP3 and SMTP, is not here.)

   Worked examples (checked by the tests): a handshake with a local
   `openssl s_server` over each of our two ciphers, its self-signed
   certificate the one root trusted, a page asked and received; the same
   refused when the root is not trusted, or the host is another. By
   hand: the web servers mini-curl is asked for. *)

type t

(* the system's roots, read once *)
val system_roots : < Cap.open_in; .. > -> X509.t list

(* ix: the certificates of a file (PEM) in the system's place from now
 * on: curl's --cacert, a test's own root *)
val trust_file : < Cap.open_in; .. > -> string -> unit

(* [connect caps ~trust ~host ~port]: the TCP connection made (waiting
 * for it) and the ClientHello sent; the handshake goes on in [step].
 * [trust]: the roots (system_roots, or a test's own) *)
val connect : < Cap.network; Cap.open_in; .. > -> trust:X509.t list -> host:string -> port:int -> (t, string) result

(* what can be done without waiting: bytes read and given to the
 * machine, its answers written *)
val step : t -> unit

val state : t -> Tls13.state

(* the machine, to ask it what it saw (the chain, the cipher) *)
val machine : t -> Tls13.t

(* application data: sent once the handshake is done (queued before) *)
val send : t -> string -> unit

(* the application data arrived since the last call *)
val receive : t -> string

val close : t -> unit

(* [exchange caps ~trust ~host ~port request]: connect, send [request],
 * read until the server closes (or Tcp.timeout seconds of silence) *)
val exchange : < Cap.network; Cap.open_in; .. > -> trust:X509.t list -> host:string -> port:int -> string -> (string, string) result
