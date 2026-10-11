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
  - `Chacha20`: its words are `int32`, as the hashes' (one version).
  - `Poly1305`: `mac_simple`, the definition on `Bignum`'s numbers
    (mod 2^130 - 5), is `mac` where an int is small; `mac_limbs`, the
    playground's five limbs of 26 bits, where it is not. A test holds
    one against the other at each length to 70.
  - The link order: `Bignum` before `Poly1305` (the mkfiles): after
    it, its limb's width was still 0 when Poly1305's field was made,
    and the program did not start.
- `tests/Speed.ml`, `speed.sh`: one kind of work a number of times,
  timed from outside. A kilobyte or one operation, in seconds
  (2026-10-11; the start's time taken off for mini-5i, 2.2 s):

  | | OCaml | mini-ml, arm64 | mini-ml, arm, under mini-5i |
  |---|---:|---:|---:|
  | SHA-256 | 0.0001 | 0.0015 | 0.4 |
  | ChaCha20 | 0.0001 | 0.0009 | 0.3 |
  | Poly1305 | 0.0001 | 0.0001 | 0.5 |
  | AES-GCM | 0.0007 | 0.0033 | 1.4 |
  | X25519, a public key | 0.0035 | 0.017 | 11.5 |
  | ECDSA P-256, a signature checked | 0.011 | 0.052 | 35 |
  | RSA 2048, a modulus and its 17 products | 0.007 | 0.025 | 14 |

  (the first two columns from 100 runs, less the start's 0.01 s, so
  their smallest numbers are rough.) ChaCha20 in `int32` was not
  timed against the ints it replaced.
