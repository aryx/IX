(* Tls13: a TLS 1.3 client. It does the handshake that agrees on keys
   and checks who the server is, and then sends records encrypted with
   those keys (Eric Rescorla, RFC 8446, 2018).

       client                                         server
       ClientHello: a random, the ciphers we know,
         our X25519 public key (key_share),
         the host (server_name)            -------->
                                           <--------  ServerHello: its X25519 key
                        (both compute the shared secret: X25519.mli;
                         from here on, everything is encrypted)
                                           <--------  EncryptedExtensions
                                                      Certificate: its chain (X509)
                                                      CertificateVerify: the
                                                        transcript signed by its key
                                                      Finished: an HMAC of the
                                                        transcript
       Finished                            -------->
       application data                    <------->  application data

   It takes one round trip. The *transcript* is every handshake message
   so far, hashed (SHA-256), and everything is bound to it. The keys are
   derived from the shared secret and the transcript (the key schedule,
   with HKDF), CertificateVerify signs it, and each Finished is an HMAC
   of it. So a man in the middle who changed a byte of the hello is
   found out.

   The key schedule:

       0 --Extract--> early --Derive("derived")--> salt
       salt, shared secret --Extract--> handshake secret
           --Derive("c hs traffic", CH..SH)--> client handshake keys
           --Derive("s hs traffic", CH..SH)--> server handshake keys
           --Derive("derived")--> salt, 0 --Extract--> master secret
               --Derive("c ap traffic", CH..server Finished)--> client keys
               --Derive("s ap traffic", CH..server Finished)--> server keys

   Each Derive is an HKDF-Expand-Label: HKDF-Expand with the label
   "tls13 ...", its length and a transcript hash as the info.

   A record is a 5-byte header (type, 0x0303, length). Once the keys
   are agreed, it is followed by the AEAD (ChaCha20-Poly1305 or
   AES-128-GCM) of the data and its real type. The nonce is the key's
   IV xored with the record's number, and the header is the associated
   data.

   Ours offers X25519 only, and the two SHA-256 suites
   (TLS_CHACHA20_POLY1305_SHA256 first, then TLS_AES_128_GCM_SHA256).
   It checks the chain with a function that it is given ([verify]:
   X509.verify with the trusted roots and the time), the signature in
   CertificateVerify, and the server's Finished. A server that asks for
   a client certificate (Gmail's SMTP does, optionally) gets an empty
   one. Not done: resumption, 0-RTT, client certificates of our own,
   HelloRetryRequest, and other groups.

   It is a pure machine, as Smtp's is: [received] is given the bytes
   that came and answers with the bytes to send; the socket is
   Tls_client's.

   The tests check a worked example: RFC 8448's "simple 1-RTT
   handshake", with its keys and messages. They check the shared
   secret, every secret of the key schedule, every key and IV, the
   server's encrypted flight decrypted into its four messages, the
   RSA-PSS signature of CertificateVerify, both Finished, the
   application data and the alerts, byte for byte. A whole handshake is
   also made with a local openssl s_server (Tls_client's tests).

   An encrypted record, as [seal] writes it, whatever is inside:

       17 03 03  len    | AEAD of ( data  real type  )    | tag
       type 23, "1.2",  |           ...   22 handshake    | 16 bytes
       2 bytes          |                 23 data, 21 alert

   Where it stands: it sits between Http_client's request and Tcp's
   stream, and Tls_client carries it. It is where lib_crypto's modules
   meet, each for one line of the first drawing: X25519 for the key
   shares, Sha256 for the transcript, Hkdf and Hmac for the schedule and
   Finished, Chacha20_poly1305 or Gcm for the records, and, through
   X509, Rsa or Ecdsa for the certificates and CertificateVerify. There
   are three questions, and three mechanisms: a secret that nobody else
   has (the exchange), the right server (the signature), and nothing
   changed on the way (the transcript in everything, and the AEAD's
   tags). A server that answers in TLS 1.2 (with no supported_versions
   in its ServerHello) is handed to Tls12 from there, for its handshake
   and then its records.

   cs-history:
   From SSL. Netscape made the Secure Sockets Layer for its browser
   and its commerce server, so that a card number could be typed into
   a page. There was SSL 2 (1995, Taher Elgamal's group; version 1 was
   broken before it shipped) and then, redesigned, SSL 3 (1996, Paul
   Kocher with Netscape's Phil Karlton and Alan Freier). The IETF took
   it over as TLS 1.0 (RFC 2246, 1999), a new name for nearly the same
   protocol; 1.1 (2006) and 1.2 (2008) repaired it as attacks came. The
   attacks kept coming: BEAST (2011), CRIME, Lucky Thirteen, POODLE
   (2014), FREAK and Logjam (2015). Nearly all came through something
   old kept for compatibility: a weak cipher still offered, CBC's
   padding, compression, or a downgrade to an earlier version.

   design:
   TLS 1.3 (four years and twenty-eight drafts, 2014 to 2018) is a
   security protocol made by taking things out: RSA key transport (so
   every connection has forward secrecy: a key stolen later decrypts
   nothing recorded before), CBC and RC4 (only AEAD ciphers are left),
   compression, renegotiation, and the choice of arbitrary groups. With
   less to negotiate, the handshake is one round trip instead of two,
   and most of it is encrypted. It was also the first version analysed
   by machine while it was drafted (the Tamarin prover, miTLS), and the
   proofs fed back into the text.

   others:
   Why does a 1.3 record say 0x0303, which is 1.2? When they were tried
   on the real Internet, the drafts failed for a few connections in a
   hundred: firewalls and proxies on the way had been written to what
   TLS 1.2 looked like, and they dropped what did not look like it. So
   1.3 dresses as a 1.2 session being resumed. The hello's version
   field says 1.2, and the real one is in an extension
   (supported_versions). A session id that means nothing is sent (our
   [session_id]). And servers send a ChangeCipherSpec that 1.3 has no
   use for, which [received] ignores. A protocol that leaves a field
   free for later finds, later, that the network has frozen it.

   design:
   The machine does no input or output and rolls no dice. The bytes
   that came are an argument, the bytes to send are a result, and the
   random numbers are arguments too. That is what lets the tests replay
   RFC 8448's trace byte for byte, with no network and no server, and
   it would let the same machine run where there is no socket at all.

   References: RFC 8446, "The Transport Layer Security (TLS) Protocol
   Version 1.3" (2018): 4 the handshake, 5 the records, 7 the key
   schedule; RFC 8448, "Example Handshake Traces for TLS 1.3" (2019);
   Michael Driscoll, "The Illustrated TLS 1.3 Connection"
   (tls13.xargs.org), every byte of one connection explained. *)

(*****************************************************************************)
(* {1 The key schedule and the records} *)
(*****************************************************************************)

val hkdf_expand_label : string -> label:string -> context:string -> int -> string

(* [derive_secret secret label transcript]: the transcript is the
 * messages, concatenated, and it is hashed *)
val derive_secret : string -> string -> string -> string

(* the handshake secret from the shared secret, and the master secret
 * from the handshake secret *)
val handshake_secret : string -> string
val master_secret : string -> string

type cipher = Chacha20_poly1305 | Aes128_gcm

(* a direction's keys, and how many records it has sealed or opened *)
type keys = { cipher : cipher; key : string; iv : string; seq : int }

val traffic_keys : cipher -> string -> keys

(* HMAC(finished_key(secret), hash(transcript)) *)
val finished : string -> string -> string

(* seals a record: it gives the record's bytes, and the keys one record
 * further *)
val seal : keys -> int -> string -> string * keys

(* [open_record keys header body] gives the real content type and the
 * data *)
val open_record : keys -> string -> string -> ((int * string) * keys) option

(*****************************************************************************)
(* {1 The client} *)
(*****************************************************************************)

type t

type state =
  | Handshaking
  | Open (* application data may flow *)
  | Closed (* the server said close_notify *)
  | Failed of string

(* [client ~host ~random ~secret ~session_id ~verify] is the machine,
 * and the ClientHello's record to send first. [random], [secret] (our
 * X25519 key) and [session_id] are 32 random bytes each, and the caller
 * gives them (a pure machine rolls no dice). *)
val client :
  host:string -> random:string -> secret:string -> session_id:string -> verify:(X509.t list -> (unit, string) result) -> t * string

(* takes the bytes that came from the server, and gives the machine and
 * the bytes to send back *)
val received : t -> string -> t * string

val state : t -> state

(* the application data that arrived since the last call *)
val read : t -> t * string

(* application data to send, as records *)
val write : t -> string -> t * string

(* close_notify *)
val close : t -> t * string

(* the server's certificates, once received; the cipher chosen *)
val certificates : t -> X509.t list
val cipher : t -> cipher option
