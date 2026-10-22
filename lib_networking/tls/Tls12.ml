(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's libs/network/tls/Tls12.ml (its 8af888e);
 * P-384, and the curves by Ecdsa (mini-chrome's P256 not copied) *)

(* See Tls12.mli *)

let u8 (n : int) : string = String.make 1 (Char.chr (n land 0xff))
let u16 (n : int) : string = u8 (n lsr 8) ^ u8 n
let u24 (n : int) : string = u8 (n lsr 16) ^ u16 n

let u64 (n : int) : string =
  String.init 8 (fun i -> Char.chr ((n lsr (8 * (7 - i))) land 0xff))

let get8 (s : string) (i : int) : int = Char.code s.[i]
let get16 (s : string) (i : int) : int = (get8 s i lsl 8) lor get8 s (i + 1)
let get24 (s : string) (i : int) : int = (get8 s i lsl 16) lor get16 s (i + 1)
let vec8 (s : string) : string = u8 (String.length s) ^ s
let vec16 (s : string) : string = u16 (String.length s) ^ s

(* ECDHE with the server's key signed by RSA or ECDSA; AES-128-GCM or
 * ChaCha20-Poly1305; SHA-256 *)
let suites = [ 0xc02f; 0xc02b; 0xcca8; 0xcca9 ]
let chacha_suite (suite : int) : bool = suite = 0xcca8 || suite = 0xcca9

let hello_extensions : string =
  let ext typ data = u16 typ ^ vec16 data in
  (* extended_master_secret; renegotiation_info: none; ec_point_formats:
   * uncompressed *)
  ext 0x0017 "" ^ ext 0xff01 (vec8 "") ^ ext 0x000b (vec8 "\000")

(*****************************************************************************)
(* The keys *)
(*****************************************************************************)

let hash = Sha256.digest
let hmac = Hmac.sha256

(* P_hash: A(0) = the seed, A(i) = HMAC(secret, A(i-1)); the output is
 * HMAC(secret, A(1) + seed), HMAC(secret, A(2) + seed), ... *)
let prf (secret : string) (label : string) (seed : string) (n : int) : string =
  let seed = label ^ seed in
  let rec go a out =
    if String.length out >= n then String.sub out 0 n
    else
      let a = hmac secret a in
      go a (out ^ hmac secret (a ^ seed))
  in
  go seed ""

type keys = { chacha : bool; key : string; iv : string; seq : int }

(* the server's curve, by its number: X25519 (None), P-256, P-384; and
 * the length of a key of it *)
let curve_of (id : int) : (Ecdsa.curve option * int) option =
  match id with
  | 0x001d -> Some (None, 32)
  | 0x0017 -> Some (Some Ecdsa.p256, 65)
  | 0x0018 -> Some (Some Ecdsa.p384, 97)
  | _ -> None

(* our secret on a NIST curve: as many bytes as the curve has, made of
 * the X25519 one (32 random bytes, by SHA-512); a scalar past n is
 * the same as its remainder *)
let scalar (curve : Ecdsa.curve) (secret : string) : string =
  String.sub (Sha512.digest secret) 0 (Ecdsa.size curve)

let public_key (curve : Ecdsa.curve option) (secret : string) : string =
  match curve with
  | None -> X25519.public_key secret
  | Some c -> Option.get (Ecdsa.multiply c (scalar c secret) (Ecdsa.generator c))

(* the shared secret: X25519's, or the x of the product (RFC 8422) *)
let shared (curve : Ecdsa.curve option) (secret : string) (server : string) :
    string option =
  match curve with
  | None -> Some (X25519.scalar_mult secret server)
  | Some c ->
      Option.map
        (fun p -> String.sub p 1 (Ecdsa.size c))
        (Ecdsa.multiply c (scalar c secret) server)

(*****************************************************************************)
(* The records *)
(*****************************************************************************)

(* what is authenticated beside a record: its number, type, version, length *)
let aad (k : keys) (typ : int) (length : int) : string =
  u64 k.seq ^ u8 typ ^ u16 0x0303 ^ u16 length

(* ChaCha20: the IV xored with the record's number (RFC 7905), as 1.3 does *)
let xored (k : keys) : string =
  String.mapi
    (fun i c ->
      if i < 4 then c
      else Char.chr (Char.code c lxor ((k.seq lsr (8 * (11 - i))) land 0xff)))
    k.iv

let seal (k : keys) (typ : int) (data : string) : string * keys =
  let aad = aad k typ (String.length data) in
  let body =
    if k.chacha then Chacha20_poly1305.seal ~key:k.key ~nonce:(xored k) ~aad data
    else
      (* AES-GCM: 4 bytes of the key block, then 8 sent with the record
       * (RFC 5288) *)
      let explicit = u64 k.seq in
      explicit ^ Gcm.seal ~key:k.key ~nonce:(k.iv ^ explicit) ~aad data
  in
  (u8 typ ^ u16 0x0303 ^ vec16 body, { k with seq = k.seq + 1 })

let open_ (k : keys) (typ : int) (body : string) : (string * keys) option =
  let n = String.length body in
  let plain =
    if k.chacha then
      if n < 16 then None
      else
        Chacha20_poly1305.open_ ~key:k.key ~nonce:(xored k)
          ~aad:(aad k typ (n - 16)) body
    else if n < 24 then None
    else
      Gcm.open_ ~key:k.key ~nonce:(k.iv ^ String.sub body 0 8)
        ~aad:(aad k typ (n - 24)) (String.sub body 8 (n - 8))
  in
  Option.map (fun p -> (p, { k with seq = k.seq + 1 })) plain

(*****************************************************************************)
(* The handshake *)
(*****************************************************************************)

type waiting = Certificate | Key_exchange | Hello_done | Finished | Done

type t = {
  secret : string; (* our X25519 secret *)
  verify : X509.t list -> (unit, string) result;
  randoms : string * string; (* ours, the server's *)
  chacha : bool;
  extended : bool;
  waiting : waiting;
  transcript : string;
  chain : X509.t list;
  server_key : string;
  curve : Ecdsa.curve option; (* the exchange's, None for X25519 *)
  asked : bool; (* the server asked for our certificate *)
  master : string;
  write : keys option;
  read : keys option; (* the server's, once it said ChangeCipherSpec *)
  reading : bool;
}

let start ~(secret : string) ~(verify : X509.t list -> (unit, string) result)
    ~(client_random : string) ~(server_random : string) ~(suite : int)
    ~(extended : bool) ~(transcript : string) : (t, string) result =
  if not (List.mem suite suites) then
    Error "TLS 1.2: a cipher suite we did not offer"
  else
    Ok
      { secret; verify; randoms = (client_random, server_random);
        chacha = chacha_suite suite; extended; waiting = Certificate;
        transcript; chain = []; server_key = ""; curve = None; asked = false;
        master = ""; write = None; read = None; reading = false }

(* a Certificate message's chain: three bytes of length, then each
 * certificate after its own three *)
let chain_of (body : string) : (X509.t list, string) result =
  let stop = 3 + get24 body 0 in
  let rec go i acc =
    if i + 3 > stop then Ok (List.rev acc)
    else
      let len = get24 body i in
      match X509.parse (String.sub body (i + 3) len) with
      | Ok c -> go (i + 3 + len) (c :: acc)
      | Error e -> Error e
  in
  go 3 []

(* ServerHelloDone: our key, the keys made, and our Finished under them *)
let answer (t : t) : t * string =
  let client_random, server_random = t.randoms in
  (* asked for a certificate: an empty list of them *)
  let none = if t.asked then u8 11 ^ u24 3 ^ u24 0 else "" in
  let exchange =
    let b = vec8 (public_key t.curve t.secret) in
    u8 16 ^ u24 (String.length b) ^ b
  in
  let transcript = t.transcript ^ none ^ exchange in
  (* (a point not of the curve was refused when it came) *)
  let pre_master = Option.get (shared t.curve t.secret t.server_key) in
  let master =
    if t.extended then
      prf pre_master "extended master secret" (hash transcript) 48
    else prf pre_master "master secret" (client_random ^ server_random) 48
  in
  let key_len, iv_len = if t.chacha then (32, 12) else (16, 4) in
  let block =
    prf master "key expansion" (server_random ^ client_random)
      ((2 * key_len) + (2 * iv_len))
  in
  let part at len = String.sub block at len in
  let write =
    { chacha = t.chacha; key = part 0 key_len;
      iv = part (2 * key_len) iv_len; seq = 0 } in
  let read =
    { chacha = t.chacha; key = part key_len key_len;
      iv = part ((2 * key_len) + iv_len) iv_len; seq = 0 } in
  let finished =
    u8 20 ^ u24 12 ^ prf master "client finished" (hash transcript) 12 in
  let record, write = seal write 22 finished in
  ( { t with transcript = transcript ^ finished; master; write = Some write;
             read = Some read; waiting = Finished },
    u8 22 ^ u16 0x0303 ^ vec16 (none ^ exchange)
    ^ "\x14\x03\x03\x00\x01\x01" ^ record )

let handshake (t : t) (typ : int) (msg : string) :
    (t * string * bool, string) result =
  let body = String.sub msg 4 (String.length msg - 4) in
  let after = { t with transcript = t.transcript ^ msg } in
  match (t.waiting, typ) with
  | Certificate, 11 -> (
      match chain_of body with
      | Error e -> Error e
      | Ok [] -> Error "no certificate"
      | Ok chain ->
          Result.map
            (fun () -> ({ after with chain; waiting = Key_exchange }, "", false))
            (t.verify chain))
  | Key_exchange, 12 -> (
      (* a named curve (3) and its key; then the signature's scheme and
       * bytes *)
      let named = String.length body >= 8 && get8 body 0 = 3 in
      let len = if named then get8 body 3 else 0 in
      match if named then curve_of (get16 body 1) else None with
      | Some (curve, size) when len = size && String.length body >= 8 + len ->
          let params = String.sub body 0 (4 + len) in
          let scheme = get16 body (4 + len) in
          let signature = String.sub body (8 + len) (get16 body (6 + len)) in
          let client_random, server_random = t.randoms in
          let server_key = String.sub body 4 len in
          let message = client_random ^ server_random ^ params in
          if not (X509.verify_scheme (List.hd t.chain) ~scheme ~message
                    ~signature) then
            Error
              (Printf.sprintf
                 "the server's key exchange is not signed by its certificate \
                  (scheme %04x)" scheme)
          else if shared curve t.secret server_key = None then
            Error "TLS 1.2: the server's key is not a point of the curve"
          else
            Ok ({ after with server_key; curve; waiting = Hello_done }, "",
                false)
      | _ -> Error "TLS 1.2: a key exchange not on X25519, P-256 or P-384")
  | Hello_done, 13 -> Ok ({ after with asked = true }, "", false)
  | Hello_done, 14 ->
      let t, out = answer after in
      Ok (t, out, false)
  | Finished, 20 ->
      if t.reading && body = prf t.master "server finished" (hash t.transcript) 12
      then Ok ({ after with waiting = Done }, "", true)
      else Error "the server's Finished does not check"
  (* a HelloRequest, later: no renegotiation, not answered *)
  | Done, 0 -> Ok (t, "", true)
  | _ -> Error (Printf.sprintf "TLS 1.2: an unexpected handshake message (%d)" typ)

let change_cipher (t : t) : t = { t with reading = true }

let received (t : t) (typ : int) (body : string) : (string * t) option =
  match (t.reading, t.read) with
  | true, Some k ->
      Option.map (fun (plain, k) -> (plain, { t with read = Some k }))
        (open_ k typ body)
  | _ -> Some (body, t)

let sealed (t : t) (typ : int) (data : string) : string * t =
  match t.write with
  | Some k ->
      let record, k = seal k typ data in
      (record, { t with write = Some k })
  | None -> ("", t)

let certificates (t : t) : X509.t list = t.chain
