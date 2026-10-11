# lib_crypto: hashes, ciphers, key exchange, signatures

Two origins:

- `Sha1`: ix's own, after principia's `lib_security/libsec`: the name
  of a git object (mini-git, tiny-vcs, tiny-build).
- The thirteen others: the author's playground's `libs/crypto`
  (`~/playground`), what TLS 1.3 stands on, for the browser and the
  programs beside it. The plan:
  [`plan_browser.md`](../docs/plans/plan_browser.md), its stage 2.

Each copied file says in one line where it comes from and what changed
(`ix: the author's playground's <path>; ...`). The lists and the
numbers below are `scripts/playground_copies.sh lib_crypto`'s, against
the playground at `6154076a` (2026-09-30, the hour of mini-chrome's
first version, the plan's base) and at `028d8abf` (2026-10-06): the
same files at both.

## What was copied

26 files, 1,116 lines of `.ml` and 487 of `.mli` there, 1,051 and 921
here (a header of two lines for one of nine; the interfaces' header
comments extended with history and references, `docs/tags.md`):

| module | what |
|---|---|
| `Sha256`, `Sha512` (and SHA-384) | the hashes of TLS's transcript and of a certificate's signature |
| `Hmac`, `Hkdf` | a keyed hash; TLS's key schedule |
| `Chacha20`, `Poly1305`, `Chacha20_poly1305` | the first cipher |
| `Aes`, `Gcm` | the second |
| `Bignum` | numbers of any size, Montgomery's products |
| `X25519` | the key exchanged |
| `Ecdsa` (P-256, P-384), `Rsa` (PKCS#1 v1.5, PSS) | a signature checked: nothing here signs |

And its tests, `tests/` (Testo, dune's only): the standards' vectors
and Python's, 14 tests.

## What changed

- `Sha256`, `Bignum`: bytes to hexadecimal without `String.to_seq`.
- `Chacha20`, `Bignum`: `for _i`, where it was `for _` (mini-ml).
- `tests/Test`: without `Unit_sha1`.

The others only by their header line. mini-ml takes them with their
labels as they are.

## ix's own

- `tests/Vectors.ml`, `Vectors.expected`, `tests/mkfile`: a known
  answer of each module, printed, so that mini-ml's build is run and
  not only compiled (`make test-lite`). By mini-ml for arm64: the same
  24 lines as OCaml's, in 0.35 s where OCaml's takes 0.09.
- **For arm (31-bit ints)**, since 2026-10-11 the same bytes
  (`mini-mk O=5` in `tests/`, run under mini-5i: the 26 lines, 3 min
  37 s). Before, `Chacha20`, `Poly1305`, `Bignum` and what stands on
  it counted in native ints taken to have 63 bits (a limb of 26 bits,
  a product of 52), as the playground's dune file says: "native only,
  as TLS is". Now:
  - `Bignum`: a limb of 14 bits where `Sys.int_size` is below 63 (a
    product and two limbs below 2^28), 26 where it is not; nothing
    else of it changed.
  - `Chacha20`: a word as two ints of 16 bits (`block_halves`) where
    an int is small; the playground's word in an int (`block_wide`)
    where it is not.
  - `Poly1305`: `mac_simple`, ten limbs of 13 bits in loops, is `mac`
    where an int is small; `mac_limbs`, the playground's five limbs of
    26 bits, where it is not.
  - A test holds each pair together (`Unit_ciphers`), on Linux where
    both run.
- `tests/Speed.ml`, `speed.sh`: one kind of work a number of times,
  timed from outside; `mini-5i -s` counts the instructions of the arm
  build, which is the measure below.

## Speed on a small machine (2026-10-11)

The author, of `https://` on mini-9pi: "ok let's speedup crypto".
Measured by `mini-5i -s _mk/5/lib_crypto/tests/speed <what> 1`:
millions of arm instructions for a kilobyte or for one operation, the
program's start taken off. mini-ml's code is about 25 instructions for
each operation of the source (every value through the stack, each
array's bound checked), so what counts is how many operations a byte
or a limb costs.

| | before | after | what changed |
|---|---:|---:|---|
| a program's start | 31.5 | 6.9 | a modulus's constants made when first used (`Bignum.constants`): the curves' five were made at each start |
| AES, a kilobyte | 11.9 | 1.6 | a round in one pass over three tables (`sbox`, `sbox2`, `sbox3`); `encrypt_block_simple` is FIPS 197's four steps |
| GHASH, a kilobyte | about 10 | 2.4 | four bits at a time by Shoup's table, in ints of 16 bits; `ghash_simple` is the bit by bit one, in Int64 |
| AES-GCM, a kilobyte | 22.3 | 4.5 | the two above |
| ChaCha20, a kilobyte | 3.7 | 2.6 | words in two ints of 16 bits (`block_halves`) where int32 was boxed; a word in an int (`block_wide`, the playground's) where ints have 63 bits |
| Poly1305, a kilobyte | 7.7 | 1.3 | ten limbs of 13 bits in loops (`mac_simple`), where it went through `Bignum` |
| SHA-256, a kilobyte | 5.5 | 5.5 | not touched: int32, boxed |
| X25519, a public key | 215 | 159 | `Bignum.mont_mul`'s two rows in one loop, its last subtraction in place (`mont_mul_simple` is the textbook's) |
| ECDSA P-256, a signature checked | 654 | 319 | that, and the two scalar products as one (`Ecdsa.scalar_mult2`, Straus's) |
| RSA 2048, a modulus and its 17 products | 250 | 112 | that, and R and R^2 by doubling 1 mod m where `rem` went a bit at a time over twice the bits |

Each fast version has its simple one beside it and a test that holds
one against the other (`Unit_ciphers`, `Unit_public_key`,
`Vectors`). And beyond `lib_crypto`, in a program that asks for
`https://` (`mini-5i -s _mk/5/networking/mini-curl https://...`,
before it connects: 138 million, now 71):

- `Bignum.of_bytes` gathers the bytes' bits a limb at a time, where it
  made two arrays a byte; on Linux the whole of a fetch of example.com
  went from 720 to 373 million instructions (callgrind), half of it
  having been the 140 roots' keys.
- `X509.roots`: the system's roots are kept as bytes and one is parsed
  when a chain names it as its issuer.
- `Base64.decode` four characters at a time (the roots' file is
  180,000 of them).

Tried and not kept: local names for the product loop's mask and width
(1.5%); `Array.unsafe_get` in it (nothing: mini-ml checks all the
same). Not done: a square of its own, mixed additions and a window in
ECDSA (10 to 15% each); SHA-256 in halves; and the real one, mini-ml's
code for a loop (the product's is 110 instructions for a limb's two
multiplications).
