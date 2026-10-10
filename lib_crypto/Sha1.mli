(* SHA-1, the name of every git object (git9 takes it from Plan 9's
 * libsec, sha1.c): a fingerprint of 160 bits for any bytes.
 *
 * A hash function turns bytes of any length into a number of fixed
 * size, the same bytes always the same number, and -- the
 * cryptographic part -- nobody able to find two inputs with the same
 * number, a *collision*, nor an input for a number given. SHA-1 (NSA,
 * 1995, FIPS 180-1) is the construction of its era, Merkle and
 * Damgard's: a function that mixes one block into a small state, run
 * over the message block after block.
 *
 * A message is padded to a multiple of 64 bytes (a 1 bit, zeros, its
 * length in bits as a 64-bit big-endian number) and each 64-byte
 * block stirred into five 32-bit words by 80 rounds; the digest is the
 * five words, big-endian, 20 bytes.
 *
 *     state = 67452301 EFCDAB89 98BADCFE 10325476 C3D2E1F0  (5 words)
 *
 *     message + 1 bit + 0s + its length in bits (64) = blocks of 64 bytes
 *
 *     state --block 1--> state --block 2--> ... --> state = the hash
 *            compress           compress
 *
 * The compression: the block's 16 words stretched to 80 (each the xor
 * of four earlier ones, rotated by 1), then 80 rounds over five words
 * a, b, c, d, e, each round
 *
 *     t = rotl5(a) + f(b, c, d) + e + K + w[i]
 *     e = d;  d = c;  c = rotl30(b);  b = a;  a = t     (mod 2^32)
 *
 * with f and K changing every 20 rounds (choose, parity, majority,
 * parity), and the five words added to the state they started from.
 * With the length in the padding, two messages of one hash must
 * collide in the compression of some block along the way (Merkle's
 * and Damgard's theorem): the whole is as safe as the one function.
 *
 *   Sha1.to_hex (Sha1.string "abc") = "a9993e364706816aba3e25717850c26c9cd0d89d"
 *
 * and, FIPS 180's two other examples, "" is da39a3ee 5e6b4b0d 3255bfef
 * 95601890 afd80709 (what git hash-object would not give for an empty
 * file: an object is hashed with its header, "blob 0" and a zero byte,
 * e69de29b...), a million "a" 34aa973c d4c4daa4 f61eeb2b dbad2731
 * 6534016f.
 *
 * Where it stands: the version control (its Hash, Object, Pack and
 * Store; tiny-vcs too) names every blob, tree and commit by this, so
 * a name is also a check of the bytes and two equal files are stored
 * once; tiny-build knows by it that a file changed. [strings] is for
 * an object's name: the header and the content hashed without being
 * joined. The 32-bit words are
 * in OCaml's ints, masked; Sha256 and Sha512, TLS's hashes, are the
 * same construction with a bigger state (Sha256.mli), and Hmac.mli
 * says what the construction lets an outsider do, the length
 * extension.
 *
 * cs-history:
 * SHA-1 is broken for collisions (the SHAttered attack, 2017, from
 * memory): Marc Stevens' team made two PDF files with one SHA-1, after
 * twelve years of warnings (Wang Xiaoyun's attack on paper, 2005),
 * and it is retired for signatures and certificates. The line goes
 * back to Ron Rivest's MD4 (1990) and MD5 (1991), of the same shape
 * with a 128-bit state; MD5 fell first (collisions in 2004, a forged
 * certificate authority in 2008). Each time the attack was the same
 * kind: differences fed into a block that cancel inside the rounds.
 *
 * road-not-taken:
 * git kept SHA-1 and hardened it (it detects the collisions' known
 * pattern), and git's newer SHA-256 object format is the road not
 * taken here, as it is in git9. A collision needs an attacker who
 * writes both files; a name for one's own files is still a name.
 *
 * References: FIPS PUB 180-4, "Secure Hash Standard" (NIST, 2015;
 * from memory), the algorithm; the test vector above checked against
 * Python's hashlib, as were the two others; RFC 3174 (2001), SHA-1
 * with C code; Ralph Merkle, "One Way Hash Functions and DES", and
 * Ivan Damgard, "A Design Principle for Hash Functions" (both CRYPTO
 * 1989), the construction; Marc Stevens et al., "The first collision
 * for full SHA-1" (CRYPTO 2017). *)

(* 20 bytes *)
type t

val string : string -> t

(* the digest of the concatenation, without building it *)
val strings : string list -> t

val to_hex : t -> string

(* 40 lowercase hex digits, or Invalid_argument *)
val of_hex : string -> t

(* the 20 raw bytes, as in a tree entry or a pack index *)
val of_raw : string -> t
val raw : t -> string
