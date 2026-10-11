(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* One kind of work, a number of times, to be timed from outside
 * (speed.sh): where a handshake's and a record's time goes on a small
 * machine, where an int has 31 bits and a limb 14. *)

let unhex (s : string) : string = String.init (String.length s / 2) (fun i -> Char.chr (int_of_string ("0x" ^ String.sub s (2 * i) 2)))

let () =
  let what = if Array.length Sys.argv > 1 then Sys.argv.(1) else "" and n = if Array.length Sys.argv > 2 then int_of_string Sys.argv.(2) else 1 in
  let key = Sha256.digest "a key" and nonce = String.make 12 '\001' and kilobyte = String.make 1024 'x' in
  for _i = 1 to n do
    match what with
    | "nothing" -> ()
    | "sha256" -> ignore (Sha256.digest kilobyte)
    | "chacha20" -> ignore (Chacha20.encrypt ~key ~nonce ~counter:1 kilobyte)
    | "poly1305" -> ignore (Poly1305.mac ~key kilobyte)
    | "poly1305-simple" -> ignore (Poly1305.mac_simple ~key kilobyte)
    | "gcm" -> ignore (Gcm.seal ~key:(String.sub key 0 16) ~nonce ~aad:"" kilobyte)
    | "aes" -> let k = Aes.expand (String.sub key 0 16) in for b = 0 to 63 do ignore (Aes.encrypt_block k (String.sub kilobyte (16 * b) 16)) done
    | "ghash" -> ignore (Gcm.ghash (String.sub key 0 16) kilobyte)
    | "x25519" -> ignore (X25519.public_key key)
    | "p256" -> ignore (Ecdsa.generator_ok Ecdsa.p256)
    | "ecdsa" ->
        (* Vectors' signature *)
        let public = unhex "047e187524a24419dfa93fb20725377d19674242bd5db44d5c8ca2526a7537e5d9f8f525fbbfbb716424617ed8169b5836d41c69e56971bb8c06ea09899332707f" in
        let r = Bignum.of_hex "8cb6fcb5ea9cd6064056d9675befeccd3a99e29be795cfe9a8941bb636a27723" and s = Bignum.of_hex "9d5cb560d25c260c0a3b68c3921a5328e2a9f1bbe5074e0485eeacbf1126c947" in
        ignore (Ecdsa.verify Ecdsa.p256 ~public ~hash:key ~r ~s)
    | "rsa" ->
        (* a modulus of 2048 bits made up (odd), the public exponent's 17 products *)
        let m = Bignum.of_bytes (String.concat "" (List.init 8 (fun i -> Sha256.digest (string_of_int i))) ^ "\001") in
        ignore (Bignum.pow_mod (Bignum.modulus m) (Bignum.of_bytes (String.make 250 'x')) (Bignum.of_int 65537))
    | _ -> prerr_endline "usage: speed nothing|sha256|chacha20|poly1305|poly1305-simple|gcm|aes|ghash|x25519|p256|ecdsa|rsa [times]"; exit 2
  done
