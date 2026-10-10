# networking: mini-curl, mini-httpd

The network's small programs, each one file, over `lib_networking/`
(`tcp`, `tls`, `http`) and `lib_crypto/`
([`plan_browser.md`](../docs/plans/plan_browser.md), stage 3). Written
for ix after the author's mini-chrome's `tools/curl` and `tools/httpd`
(`~/github/mini-chrome`).

- **mini-curl** (`Curl.ml`): a URL's bytes; `-i`, `-L`, `-v`, `-f`,
  `-d`, `-o`, `--cacert`. https:// by ix's own TLS 1.3, the system's
  roots. Not mini-chrome's: `-A`, cookies between redirections.
- **mini-httpd** (`Httpd.ml`): a directory served to this machine,
  one client at a time, GET only. Not mini-chrome's: the WebSocket it
  echoes, the types of `.ico`, `.wav` and `.ps`.

Built by dune (`bin/mini-curl`, `bin/mini-httpd`) and by mini-mk
(`_mk/7/networking/`).

Tests, no network but this machine's: `tests/served.sh` (mini-curl
reads what mini-httpd serves, 19 cases; the system's curl reads the
same) and `tests/tls.sh` (mini-curl against `openssl s_server`: two
ciphers, ECDSA and RSA; a root not trusted and another name refused).
Each takes the programs' directory: dune's by default.

By hand, 2026-10-09: `mini-curl -L https://en.wikipedia.org/wiki/OCaml`
gives the article's 354,169 bytes, in 0.9 s by dune's build and 1.6 s
by mini-ml's (arm64), the same bytes.
