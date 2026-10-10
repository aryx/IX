# lib_networking: 9P, and the web's protocols

- `9p/`: 9P2000, Plan 9's file protocol; ix's own
  ([`plan_rio.md`](../docs/plans/plan_rio.md)).
- `tcp/`, `tls/`, `http/`: a URL fetched, over TCP or inside TLS 1.3,
  for the browser and the programs beside it
  ([`plan_browser.md`](../docs/plans/plan_browser.md), its stage 3):
  the author's playground's `libs/networking` (`~/playground`), what
  mini-chrome's first version stood on. `networking/` has the
  programs, mini-curl and mini-httpd.

Each copied file says in one line where it comes from and what changed
(`ix: the author's playground's <path>; ...`). The lists and the
numbers below are `scripts/playground_copies.sh lib_networking`'s,
against the playground at `6154076a` (2026-09-30, the hour of
mini-chrome's first version, the plan's base).

## What was copied

| here | module | there |
|---|---|---|
| `http/` | `Url`, `Urlencoded`, `Http` | `libs/networking/protocols` |
| `http/` | `Http_client` | `libs/networking/unix` |
| `tcp/` | `Tcp` | `libs/networking/unix` |
| `tls/` | `Asn1`, `Pem`, `X509`, `Tls13` | `libs/networking/tls` |
| `tls/` | `Tls_client` | `libs/networking/unix` |
| `tls/` | `Base64`; `Civil`, `Clock` | `libs/core`; `libs/core/time` |
| `tests/` | `Unit_url`, `Unit_urlencoded`, `Unit_http`, `Unit_x509`, `Unit_tls13`, `Rfc8448`, `tls/*.pem` | `libs/networking/tests` |

14 modules, 1,556 lines of `.ml` and 931 of `.mli` there, 1,448 and
937 here. Under them, `lib_crypto/`.

The dependencies go one way: `tcp` (ix_tcp), then `tls` (ix_tls: the
machine, `Tls13`, is pure; `Tls_client` carries its bytes over a
socket), then `http` (ix_http: `Http_client` over both).

## What changed

No optional argument, as everywhere in ix (mini-ml has none):

- `Http.request_to_string ~body`; `Clock.to_string ~seconds`.
- `Tcp`: no `?timeout`: `Tcp.timeout`, 30 s, and a read waits by
  `select` (lib_core's `Unix` has no `SO_RCVTIMEO`). A name is asked of
  `Dns` when `getaddrinfo` knows none (below). The capability is not
  asked for the host by a method (`caps#network`): it is in the type,
  as in ix's other programs.
- `Tls_client`: `~trust` is said by the caller (`system_roots caps`, or
  a test's); `trust_file`, for mini-curl's `--cacert`; the roots and
  `/dev/urandom` read with `Cap.open_in` (`FS`); no mutex round the
  chains already checked, there being no threads; no `Transport` of
  lines (POP3, SMTP).
- `Http_client`: `~post` an option, five redirections, `get_once` is
  `once`.
- `X509`, `Tls13`, `Http`: three lines for mini-ml (`Option.value
  ~default`, a labelled function chosen by a `match` given its type,
  `Option.to_result`).
- `tests/Unit_x509`: its files found from ix's root too.

## From mini-chrome of today (2026-10-11)

`http/`'s `Keep_alive` (an https:// connection kept for the next
request to its host), `Cookie` and `Cookie_jar` (RFC 6265), and in
`Http` a response's extent (`extent`, `whole`), `values`, and gzip
asked for and read (`Zlib.gunzip`, lib_compression's); their tests
(`Unit_cookie`, and in `Unit_http`). Changed: no mutex nor lock (no
threads), no optional argument (`~script`, `Cookie_jar.create
cookies`), a date's seconds in floats. `Http_client`'s `options`
(`said`, `keep`, `jar`) and its `_with` functions are ix's. Not
taken: Brotli, Zstandard, `Http_cache`, `Http_request`, WebSocket.

## ix's own

- `tcp/Dns` (62 lines): a name's addresses asked of the name server of
  `/etc/resolv.conf`, one UDP packet. mini-ml's `Unix.getaddrinfo` has
  no resolver (an address in numbers, `/etc/hosts`); OCaml's has the C
  library's, and `Dns` is then not reached. What mini-9pi will ask
  with, once it has UDP.
- lib_core's `Unix` gained `getsockname` and `setsockopt SO_REUSEADDR`
  (mini-httpd's).

## What remains in the playground

Of the files the first version stood on: `Http_request` (the same
request without blocking, 217 lines) and `Worker` (a pool of threads,
62): the plan's decision 6, "no threads at first"; `Transport` (32).
And the rest of `libs/networking`: WebSocket, IRC, mail (SMTP, POP3,
MIME), the games' netcode, the servers, `Tls_tunnel`, their tests
(`unix/tests`: here `networking/tests/tls.sh` does `Unit_tls_client`'s
work with the program).

## Checked

`tests/Test.exe` (32 tests, Testo, dune's only). mini-ml compiles every
file. `networking/tests/served.sh` and `tls.sh` on dune's programs and
on mini-ml's.
