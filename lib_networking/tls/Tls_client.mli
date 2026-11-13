(* Tls_client: TLS 1.3 over a real socket, with our own TLS
   (Tls13.mli) and the system's trusted roots.

   Tls13 is a pure machine, with bytes in and bytes out. This module is
   the rest:
   - the TCP connection (Tcp.mli);
   - 96 bytes of randomness from /dev/urandom, for the hello's random,
     the session id and the X25519 key (a pure machine rolls no dice);
   - the roots, read once from the system's bundle
     (/etc/ssl/certs/ca-certificates.crt, or where the other systems
     keep it);
   - the chain, checked with those roots at the time of day
     (X509.verify);
   - and the loop that carries the bytes between the socket and the
     machine, never waiting.

   Reading the system's roots and the kernel's randomness is part of
   what reaching a host over TLS means, but ix says it in the type all
   the same, with Cap.open_in beside Cap.network.

   Here is the loop, for one request:

       Http_client      "GET / HTTP/1.1 ..."          the answer's bytes
            | send                                        ^ receive
       Tls13.write: records, sealed          Tls13.read: records opened
            |                                             ^
            v            [step], until the server closes  |
       Unix.write  -------- the socket (Tcp.connect) ---- Unix.read
                            Tls13.received: every byte that came,
                            handshake or data, and what to answer

   What is asked before the handshake is done is queued, and the
   machine's state says when it may go. A chain once checked for a host
   is remembered until its first certificate expires, so a page's
   twenty pictures from one server cost the signatures of one chain,
   not twenty. CertificateVerify is checked every time, because it is
   the proof that the server holds the key now.

   others:
   Where the roots are is each system's own answer, and a client tries
   the places in turn. Debian has one file of PEM
   (/etc/ssl/certs/ca-certificates.crt), Red Hat another, and the BSDs
   and macOS others again. Windows keeps them in its registry, and
   Firefox ships its own list and asks no system. The list itself is
   nearly the same everywhere: it is Mozilla's, which the Linux
   distributions repackage.

   [exchange] is one request and its whole answer, for HTTPS
   (Http_client). (ix: the playground's other face, a Transport.t of
   lines for POP3 and SMTP, is not here.)

   The tests check worked examples. A handshake is made with a local
   `openssl s_server` over each of our two ciphers, with its
   self-signed certificate as the one root trusted, and a page is asked
   for and received. The same is refused when the root is not trusted,
   or when the host is another one. By hand, the examples are the web
   servers that mini-curl is asked for. *)

type t

(* the system's roots, read once *)
val system_roots : < Cap.open_in; .. > -> X509.roots

(* ix: from now on, the certificates of a file (PEM) take the place of
 * the system's roots, for curl's --cacert or for a test's own root *)
val trust_file : < Cap.open_in; .. > -> string -> unit

(* [connect caps ~trust ~host ~port] makes the TCP connection (waiting
 * for it) and sends the ClientHello; the handshake goes on in [step].
 * [trust] is the roots (system_roots, or a test's own). *)
val connect :
  < Cap.network; Cap.open_in; Cap.clock; .. > ->
  trust:X509.roots -> host:string -> port:int -> (t, string) result

(* does what can be done without waiting: it reads bytes and gives them
 * to the machine, and writes the machine's answers *)
val step : t -> unit

val state : t -> Tls13.state

(* the machine, to ask it what it saw (the chain, the cipher) *)
val machine : t -> Tls13.t

(* sends application data once the handshake is done (it is queued
 * before) *)
val send : t -> string -> unit

(* the application data that arrived since the last call *)
val receive : t -> string

(* has the server closed its side, or have we? *)
val ended : t -> bool

(* waits for bytes to come, [seconds] at most *)
val wait : t -> float -> unit

val close : t -> unit

(* [exchange caps ~trust ~host ~port request] connects, sends
 * [request], and reads until the server closes (or until Tcp.timeout
 * seconds of silence) *)
val exchange :
  < Cap.network; Cap.open_in; Cap.clock; .. > -> trust:X509.roots -> host:string -> port:int -> string -> (string, string) result
