(* SHA-1 gives the name of every git object (git9 takes it from Plan 9's
 * libsec, sha1.c). It is a fingerprint of 160 bits for any bytes.
 *
 * A hash function turns bytes of any length into a number of fixed
 * size. The same bytes always give the same number, and (this is the
 * cryptographic part) nobody is able to find two inputs with the same
 * number, a *collision*, nor an input for a given number. SHA-1 (NSA,
 * 1995, FIPS 180-1) uses the construction of its era, Merkle and
 * Damgard's: a function that mixes one block into a small state is
 * run over the message, block after block.
 *
 * A message is padded to a multiple of 64 bytes (a 1 bit, zeros, and
 * its length in bits as a 64-bit big-endian number), and each 64-byte
 * block is stirred into five 32-bit words by 80 rounds. The digest is
 * the five words, big-endian, so 20 bytes.
 *
 *     state = 67452301 EFCDAB89 98BADCFE 10325476 C3D2E1F0  (5 words)
 *
 *     message + 1 bit + 0s + its length in bits (64) = blocks of 64 bytes
 *
 *     state --block 1--> state --block 2--> ... --> state = the hash
 *            compress           compress
 *
 * In the compression, the block's 16 words are stretched to 80 (each
 * new one is the xor of four earlier ones, rotated by 1), and then 80
 * rounds run over five words a, b, c, d, e. Each round does
 *
 *     t = rotl5(a) + f(b, c, d) + e + K + w[i]
 *     e = d;  d = c;  c = rotl30(b);  b = a;  a = t     (mod 2^32)
 *
 * with f and K changing every 20 rounds (choose, parity, majority,
 * parity). At the end the five words are added to the state they
 * started from. Because the length is in the padding, two messages
 * with the same hash must collide in the compression of some block
 * along the way (Merkle's and Damgard's theorem), so the whole is as
 * safe as that one function.
 *
 *   Sha1.to_hex (Sha1.string "abc") = "a9993e364706816aba3e25717850c26c9cd0d89d"
 *
 * There are two more examples, the last one FIPS 180-1's. "" gives
 * da39a3ee 5e6b4b0d 3255bfef 95601890 afd80709, which is not what git
 * hash-object gives for an empty file: git hashes an object with its
 * header, "blob 0" and a zero byte, and gets e69de29b... A million
 * "a" give 34aa973c d4c4daa4 f61eeb2b dbad2731 6534016f.
 *
 * Where it stands: the version control (its Hash, Object, Pack and
 * Store, and tiny-vcs too) names every blob, tree and commit by this
 * hash. So a name is also a check of the bytes, and two equal files
 * are stored once. tiny-build uses it to know that a file changed.
 * [strings] is for an object's name: the header and the content are
 * hashed without being joined. The 32-bit words are kept in OCaml's
 * ints, masked. Sha256 and Sha512, TLS's hashes, are the same
 * construction with a bigger state (Sha256.mli), and Hmac.mli says
 * what the construction lets an outsider do: the length extension.
 *
 * cs-history:
 * SHA-1 is broken for collisions (the SHAttered attack, 2017): Marc
 * Stevens' team made two PDF files with the same SHA-1, after twelve
 * years of warnings (Wang Xiaoyun's attack on paper, 2005), and SHA-1
 * is now retired for signatures and certificates. The line goes back
 * to Ron Rivest's MD4 (1990) and MD5 (1991), which have the same shape
 * with a 128-bit state. MD5 fell first (collisions in 2004, a forged
 * certificate authority in 2008). Each time the attack was of the same
 * kind: differences fed into a block that cancel each other inside the
 * rounds.
 *
 * road-not-taken:
 * git kept SHA-1 and hardened it (it detects the collisions' known
 * pattern), and git's newer SHA-256 object format is the road not
 * taken here, as it is in git9. A collision needs an attacker who
 * writes both files; a name for one's own files is still a name.
 *
 * References: FIPS PUB 180-4, "Secure Hash Standard" (NIST, 2015),
 * the algorithm (the test vector above was checked against Python's
 * hashlib, as were the two others); RFC 3174 (2001), SHA-1 with C
 * code; Ralph Merkle, "One Way Hash Functions and DES", and Ivan
 * Damgard, "A Design Principle for Hash Functions" (both CRYPTO 1989),
 * the construction; Marc Stevens et al., "The first collision for full
 * SHA-1" (CRYPTO 2017). *)

(* 20 bytes *)
type t

val string : string -> t

(* the digest of the concatenation, without building it *)
val strings : string list -> t

(* the digest of the pieces [next ()] gives until "", with none of them
 * kept: a file is digested as it is read (as tiny-build does on
 * tiny-kernel, for a file of 8 MB in a process of 16 MB) *)
val reads : (unit -> string) -> t

val to_hex : t -> string

(* 40 hex digits, in either case. It raises Invalid_argument when the
 * length is not 40, and Failure on a digit that is not hex. *)
val of_hex : string -> t

(* the 20 raw bytes, as in a tree entry or a pack index *)
val of_raw : string -> t
val raw : t -> string
