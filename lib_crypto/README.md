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

26 files, 1,116 lines of `.ml` and 487 of `.mli` there, 1,038 and 487
here (a header of two lines for one of nine):

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
- **For arm (31-bit ints) it is wrong**: `Chacha20`, `Poly1305`,
  `Bignum` and what stands on it (`X25519`, `Ecdsa`, `Rsa`) give other
  bytes (`mini-mk O=5` in `tests/`, run under mini-5i: 31 s). The
  hashes, `Hmac`, `Hkdf`, `Aes` and `Gcm` are right there: they count
  in `Int32` and `Int64`. The others count in native ints taken to
  have 63 bits (a limb of 26 bits, a product of 52), as the
  playground's dune file says: "native only, as TLS is". The plan's
  stage 10 (mini-9pi) has it.

## What remains in the playground

`Sha1` (ix has its own, another interface) and `tests/Unit_sha1`.
