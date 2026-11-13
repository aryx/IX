(* Tls12: TLS 1.2's handshake and records, for the servers that have
   not moved to 1.3. It is what Tls13's client falls back to when the
   ServerHello says the older version.

   It has the same goal as 1.3, by an older road: there are more
   messages, they are in the clear until the very end, and the keys are
   made by a function of its own.

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

   The keys: the shared secret of the two keys (X25519) is the
   "pre-master secret". The PRF (HMAC-SHA256 run in a chain, P_hash)
   makes the master secret (48 bytes) from it, and from that the key
   block, which is cut into a key and an IV for each direction:

     master    = PRF(pre_master, "extended master secret", hash(messages))
     key block = PRF(master, "key expansion", server_random + client_random)
     Finished  = PRF(master, "client finished", hash(all messages))   12 bytes

   A record is an AEAD's output as in 1.3, but its type is in the clear
   in its header, and its number is authenticated beside it. With
   AES-GCM, the last 8 bytes of the nonce travel with each record.

   What is here:
   - ECDHE over X25519, P-256 or P-384 (Ecdsa's curves; some servers
     will only do P-384, such as web.maths.unsw.edu.au);
   - the server's signature by RSA (PKCS#1 or PSS) or ECDSA;
   - AES-128-GCM and ChaCha20-Poly1305 with SHA-256;
   - the extended master secret, when the server has it.
   Not here, and such a server is refused: the RSA key exchange (which
   has no forward secrecy), CBC suites, resumption, renegotiation.

   ix: copied from libs/network/tls/Tls12.ml in the author's mini-chrome
   (at its commit 8af888e), with P-384 added. It is counted in make
   loc, because many sites still need it.

   cs-history:
   TLS 1.2 is RFC 5246, of August 2008. It is the version that let a
   suite choose its hash (SHA-256 instead of MD5 and SHA-1), and it
   brought the AEAD ciphers. It carried the web for a decade, through
   the attacks that shaped 1.3: BEAST, CRIME, Lucky Thirteen, POODLE
   and Logjam, each on something that 1.2 still allowed (CBC,
   compression, the RSA exchange, export suites). So a careful 1.2 came
   to mean a short list of suites, the one offered here, and 1.3 (2018)
   is that list made into the whole protocol. The extended master
   secret is RFC 7627 (2015), the answer to the "triple handshake"
   attack: it ties the master secret to the handshake's messages, not
   to the randoms alone.

   modern:
   Browsers removed TLS 1.0 and 1.1 in 2020. 1.2 stays, for the
   servers that were set up once and left, such as a university's or a
   device's.

   References: RFC 5246; RFC 5288 (AES-GCM); RFC 7905 (ChaCha20-
   Poly1305); RFC 8422 (ECDHE, X25519); RFC 7627. *)

(* the suites offered, and what the ClientHello says besides 1.3's
   extensions (the extended master secret, no renegotiation, and the
   one format of the points) *)
val suites : int list
val hello_extensions : string

(* PRF(secret, label, seed), [n] bytes of it *)
val prf : string -> string -> string -> int -> string

type keys = { chacha : bool; key : string; iv : string; seq : int }

(* seal makes a sealed record of a type, whole with its header; open_
   opens one and gives its body's plaintext *)
val seal : keys -> int -> string -> string * keys
val open_ : keys -> int -> string -> (string * keys) option

type t

(* the handshake, taken over at the ServerHello. It is given our X25519
   secret (a P-256 or P-384 secret is made from it), how a chain is
   checked, our random, the server's random, its suite, whether it has
   the extended master secret, and the messages so far. *)
val start :
  secret:string -> verify:(X509.t list -> (unit, string) result) ->
  client_random:string -> server_random:string -> suite:int ->
  extended:bool -> transcript:string -> (t, string) result

(* takes a handshake message, whole with its header, and gives the
   bytes to send and whether the handshake is done, or else why it
   failed *)
val handshake : t -> int -> string -> (t * string * bool, string) result

(* the server's ChangeCipherSpec: what it sends next is encrypted *)
val change_cipher : t -> t

(* a record received: its plaintext (the record itself, before the
   ChangeCipherSpec) *)
val received : t -> int -> string -> (string * t) option

(* a record to send, of application data (23) or an alert (21) *)
val sealed : t -> int -> string -> string * t
val certificates : t -> X509.t list
