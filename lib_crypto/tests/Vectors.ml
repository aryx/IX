(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* A known answer of each module, printed: what mini-ml's build of the
 * library says, compared with Vectors.expected (vectors.sh). Test.ml's
 * vectors are the same and more, but Testo's, so dune's only. *)

let unhex (s : string) : string = String.init (String.length s / 2) (fun i -> Char.chr (int_of_string ("0x" ^ String.sub s (2 * i) 2)))
let hex : string -> string = Sha256.hex
let say (name : string) (v : string) : unit = print_endline (name ^ " " ^ v)
let bool (b : bool) : string = if b then "true" else "false"

let () =
  say "sha256" (hex (Sha256.digest "abc"));
  say "sha384" (hex (Sha512.digest384 "abc"));
  say "sha512" (hex (Sha512.digest "abc"));
  (* RFC 4231's test case 2, RFC 5869's test case 1 *)
  say "hmac256" (hex (Hmac.sha256 "Jefe" "what do ya want for nothing?"));
  say "hmac384" (hex (Hmac.sha384 "Jefe" "what do ya want for nothing?"));
  let prk = Hkdf.extract ~hmac:Hmac.sha256 ~salt:(unhex "000102030405060708090a0b0c") (String.make 22 '\x0b') in
  say "hkdf" (hex (Hkdf.expand ~hmac:Hmac.sha256 prk ~info:(unhex "f0f1f2f3f4f5f6f7f8f9") 42));
  (* RFC 8439: 2.3.2, 2.5.2, 2.8.2 *)
  say "chacha20" (hex (Chacha20.block ~key:(String.init 32 Char.chr) ~nonce:(unhex "000000090000004a00000000") 1));
  say "poly1305" (hex (Poly1305.mac ~key:(unhex "85d6be7857556d337f4452fe42d506a80103808afb0db2fd4abff6af4149f51b") "Cryptographic Forum Research Group"));
  let key = unhex "808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f" and nonce = unhex "070000004041424344454647" in
  let aad = unhex "50515253c0c1c2c3c4c5c6c7" in
  let text = "Ladies and Gentlemen of the class of '99: If I could offer you only one tip for the future, sunscreen would be it." in
  let sealed = Chacha20_poly1305.seal ~key ~nonce ~aad text in
  say "chacha20-poly1305" (hex sealed);
  say "opened" (bool (Chacha20_poly1305.open_ ~key ~nonce ~aad sealed = Some text));
  say "refused" (bool (Chacha20_poly1305.open_ ~key ~nonce ~aad ("x" ^ String.sub sealed 1 (String.length sealed - 1)) = None));
  (* FIPS 197's C.1; the GCM paper's test case 3 *)
  say "aes" (hex (Aes.encrypt_block (Aes.expand (String.init 16 Char.chr)) (unhex "00112233445566778899aabbccddeeff")));
  let key = unhex "feffe9928665731c6d6a8f9467308308" and nonce = unhex "cafebabefacedbaddecaf888" in
  let text = unhex "d9313225f88406e5a55909c5aff5269a86a7a9531534f7da2e4c303d8a318a721c3c0c95956809532fcf0e2449a6b525b16aedf5aa0de657ba637b391aafd255" in
  let sealed = Gcm.seal ~key ~nonce ~aad:"" text in
  say "gcm" (hex sealed);
  say "opened" (bool (Gcm.open_ ~key ~nonce ~aad:"" sealed = Some text));
  (* RFC 7748's 6.1: Alice's public key, and the secret she shares with Bob *)
  let a = unhex "77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a" in
  say "x25519" (hex (X25519.public_key a));
  say "shared" (hex (X25519.scalar_mult a (unhex "de9edb7d7b7dc1b4d35b61c2ece435373f8343c85b78674dadfc7e146f882b4f")));
  let m = Bignum.modulus (Bignum.of_hex "ffffffff00000001000000000000000000000000ffffffffffffffffffffffff") in
  say "bignum" (Bignum.to_hex (Bignum.pow_mod m (Bignum.of_hex "123456789abcdef0123456789abcdef") (Bignum.of_hex "fedcba9876543210")));
  say "p256" (bool (Ecdsa.generator_ok Ecdsa.p256));
  say "p384" (bool (Ecdsa.generator_ok Ecdsa.p384));
  (* Unit_public_key's first P-256 signature (Python's), and its message changed *)
  let public = unhex "047e187524a24419dfa93fb20725377d19674242bd5db44d5c8ca2526a7537e5d9f8f525fbbfbb716424617ed8169b5836d41c69e56971bb8c06ea09899332707f" in
  let r = Bignum.of_hex "8cb6fcb5ea9cd6064056d9675befeccd3a99e29be795cfe9a8941bb636a27723" and s = Bignum.of_hex "9d5cb560d25c260c0a3b68c3921a5328e2a9f1bbe5074e0485eeacbf1126c947" in
  say "ecdsa" (bool (Ecdsa.verify Ecdsa.p256 ~public ~hash:(Sha256.digest (unhex "3baf6024f6360c13f64b615e3a68585090301f44ec2731a7c8efdab5dc6bbf0614665cd0e8b8bdcf63543007a52bcf")) ~r ~s));
  say "ecdsa, changed" (bool (Ecdsa.verify Ecdsa.p256 ~public ~hash:(Sha256.digest "x") ~r ~s));
  (* Unit_public_key's RSA key and signatures *)
  let n = Bignum.of_hex "c6c33c68489bdebc8deaba56e28c132201f02a36e27f97c098221cf0c54968464f651ce962810987c84a4d89e65a13f13a98f75799fdb50b2085bf004d3f2d58e0f6c9ac8b36135faaa249e48a31d8127c1e8f6bb75a8e9686877811ba7b71593a1fb0db2ea2e6d6133f70f2e7a920f038ab7f760a18bb50b5f18e788884c70f4688d006e9db159be3e12664b5a7ee78b7f11e8ac930dd207e93d6c3685321de58b94378d0e7b67548b18f99f045e59b45940cfb1b74253d8faccc7da03794a202e8ef7454cd6552e680d64784dfaae89164d8745631298f74254f123fae3910dcd8077e57a4bbd89b85977c52b0505effd19513fd3d984197644ab49efb2c57" and e = Bignum.of_int 65537 in
  let message = "I am the message a certificate would be." in
  say "rsa" (bool (Rsa.verify_pkcs1 ~n ~e Rsa.Sha256 ~message ~signature:(unhex "6e94007afde9632929ad8fb829b3875f6c223502728d21a9156cfd833fed462e04f8e900d6b4fbf6e5be8aba146bee83a84ffca0838274a28bc7e71c1ae38bd7fd8293ff97199fb72923a3ef1264e5c0471253c71f3a267a6daef5effc0ec9358f460158e728d02dd145ec30b8f60e3b2abf018e91293a8d6dc72adbd8ac3ef3e1ebd2d900ef997a28ff007853036e1b90a224be9a162d367e3d7ef5afe8a9946f8a6ca27dbd0f2cbd6ecee68d7f4e4feb6034022e10136881d46361a2a2db9ea3783ad544e29a4f09ebd49ad21abf37097f955afdf38700de81ef47595fc177adc240b23fbfe0443b5afeae435820646a751f11273f06d3722dbc3270bb357b")));
  say "rsa-pss" (bool (Rsa.verify_pss ~n ~e Rsa.Sha256 ~message ~signature:(unhex "72f89cd6c0059134447295d172767258e03038a3424c6d9e00c38dbec8e1180ebec73af8beb0d57081bca23de48ae4441279a3dd44e5eb9ef51e0e259124f586c12b00888061b7d1422140ac0a81bd24fb776c7f6d2a8ba91e7d49544342fe9090d430a49be48f384ec1595cb1414c1865672866cd1a029c57bb501ac81abe4738e1b4bf966ee32b05ded927a2fddc85657f2ff555b64d7a7c30b537a57ec992829728d4714fe3c511872ddc5bbd952bdc13775bb7fc6c8da6b3f297d50f70579d006893145b5b3bf3b406e53ed484a3a7f97740a88c0325b2ace698c056c3d3715ebe1e29e3c0489a224ebf92d968dd1ebb19c829a61d4aa401756feedc5f3e")));
  say "rsa, changed" (bool (Rsa.verify_pkcs1 ~n ~e Rsa.Sha256 ~message:"x" ~signature:(unhex "6e94007afde9632929ad8fb829b3875f6c223502728d21a9156cfd833fed462e04f8e900d6b4fbf6e5be8aba146bee83a84ffca0838274a28bc7e71c1ae38bd7fd8293ff97199fb72923a3ef1264e5c0471253c71f3a267a6daef5effc0ec9358f460158e728d02dd145ec30b8f60e3b2abf018e91293a8d6dc72adbd8ac3ef3e1ebd2d900ef997a28ff007853036e1b90a224be9a162d367e3d7ef5afe8a9946f8a6ca27dbd0f2cbd6ecee68d7f4e4feb6034022e10136881d46361a2a2db9ea3783ad544e29a4f09ebd49ad21abf37097f955afdf38700de81ef47595fc177adc240b23fbfe0443b5afeae435820646a751f11273f06d3722dbc3270bb357b")))
