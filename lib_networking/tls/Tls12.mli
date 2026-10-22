(* Tls12: TLS 1.2's handshake and records, for the servers that have
   not moved to 1.3 -- what Tls13's client falls back to when the
   ServerHello says the older version.

   The same goal as 1.3 by an older road: more messages, in the clear
   until the very end, and keys made by a function of its own.

     ClientHello            -->                     (Tls13's, offering both)
                            <--  ServerHello        version 1.2, a suite
                            <--  Certificate        in the clear
                            <--  ServerKeyExchange  its ECDHE key, signed with
                                                    the certificate's key over
                                                    both randoms and the key
                            <--  ServerHelloDone
     ClientKeyExchange      -->                     our ECDHE key
     ChangeCipherSpec       -->                     "what follows is encrypted"
     Finished               -->                     the first encrypted record
                            <--  ChangeCipherSpec
                            <--  Finished
     application data      <-->

   The keys: the two keys' shared secret (X25519) is the "pre-master
   secret"; the PRF -- HMAC-SHA256 run in a chain, P_hash -- makes of it
   the master secret (48 bytes), and of that the key block, cut into a
   key and an IV for each direction:

     master    = PRF(pre_master, "extended master secret", hash(messages))
     key block = PRF(master, "key expansion", server_random + client_random)
     Finished  = PRF(master, "client finished", hash(all messages))   12 bytes

   A record is an AEAD's output as in 1.3, but its type is in the clear
   in its header and its number is authenticated beside it; with
   AES-GCM the nonce's last 8 bytes travel with each record.

   What is here: ECDHE over X25519, P-256 or P-384 (Ecdsa's curves:
   some servers will only P-384, web.maths.unsw.edu.au), the server's
   signature by RSA (PKCS#1 or PSS) or ECDSA, AES-128-GCM and
   ChaCha20-Poly1305 with SHA-256, the extended master secret when the
   server has it. Not here, and such a server is refused: the RSA key
   exchange (no forward secrecy), CBC suites, resumption,
   renegotiation.

   ix: the author's mini-chrome's libs/network/tls/Tls12.ml (its
   8af888e), P-384 added; not in make loc (an alternative: the web
   that has moved to 1.3 needs none of it).

   cs-history:
   TLS 1.2 is RFC 5246, of August 2008: the version that let a suite
   choose its hash (SHA-256 for MD5 and SHA-1) and brought the AEAD
   ciphers. It carried the web for a decade, through the attacks that
   shaped 1.3 -- BEAST, CRIME, Lucky Thirteen, POODLE, Logjam, each on
   something 1.2 still allowed (CBC, compression, RSA exchange, export
   suites) -- so that a careful 1.2 came to mean a short list of
   suites, the one offered here, and 1.3 (2018) is that list made the
   whole protocol. The extended master secret is RFC 7627 (2015), the
   answer to the "triple handshake" attack: the master secret tied to
   the handshake's messages, not to the randoms alone.

   modern:
   Browsers removed TLS 1.0 and 1.1 in 2020; 1.2 stays, for the servers
   that were set up once and left: a university's, a device's.

   References: RFC 5246; RFC 5288 (AES-GCM); RFC 7905 (ChaCha20-
   Poly1305); RFC 8422 (ECDHE, X25519); RFC 7627. *)

(* the suites offered, and what the ClientHello says besides 1.3's
   extensions (the extended master secret, no renegotiation, the
   points' one format) *)
val suites : int list
val hello_extensions : string

(* PRF(secret, label, seed), [n] bytes of it *)
val prf : string -> string -> string -> int -> string

type keys = { chacha : bool; key : string; iv : string; seq : int }

(* a record of a type sealed, whole with its header; and one opened:
   its body's plaintext *)
val seal : keys -> int -> string -> string * keys
val open_ : keys -> int -> string -> (string * keys) option

type t

(* the handshake taken over at the ServerHello: our X25519 secret (a
   P-256 or P-384 one is made of it), how a chain is checked, our
   random, the server's, its suite, whether it has the extended master
   secret, the messages so far *)
val start :
  secret:string -> verify:(X509.t list -> (unit, string) result) ->
  client_random:string -> server_random:string -> suite:int ->
  extended:bool -> transcript:string -> (t, string) result

(* a handshake message, whole with its header: the bytes to send, and
   whether the handshake is done -- or why it failed *)
val handshake : t -> int -> string -> (t * string * bool, string) result

(* the server's ChangeCipherSpec: what it sends next is encrypted *)
val change_cipher : t -> t

(* a record received: its plaintext (itself, before the
   ChangeCipherSpec) *)
val received : t -> int -> string -> (string * t) option

(* a record to send, of application data (23) or an alert (21) *)
val sealed : t -> int -> string -> string * t
val certificates : t -> X509.t list
