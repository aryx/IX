# lib_networking: 9P and the web's protocols

- `9p/`: 9P2000, Plan 9's file protocol; ix's own
  ([`plan_rio.md`](../docs/plans/done/plan_rio.md)).
- `tcp/`, `tls/`, `http/`: a URL fetched, over TCP or inside TLS 1.3
  (or 1.2, for the servers that have no 1.3),
  for the browser and the programs beside it
  ([`plan_browser.md`](../docs/plans/plan_browser.md), its stage 3):
  the author's playground's `libs/networking` (`~/playground`), what
  mini-chrome's first version stood on. `networking/` has the
  programs, mini-curl and mini-httpd.

A game's netcode, over `tcp/`'s `Udp`, is `lib_playground/netcode/`
(old: `netcode/` here; its README).

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
| `tls/` | `Tls12` (2026-10-22, P-384 added) | mini-chrome's `libs/network/tls` |
| `tls/` | `Base64`; `Civil`, `Clock` | `libs/core`; `libs/core/time` |
| `tests/` | `Unit_url`, `Unit_urlencoded`, `Unit_http`, `Unit_x509`, `Unit_tls13`, `Rfc8448`, `tls/*.pem` | `libs/networking/tests` |

14 modules, 1,556 lines of `.ml` and 931 of `.mli` there, 1,542 and
1,379 here (the interfaces' header comments extended, `docs/tags.md`).
Under them, `lib_crypto/`.

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

- `tcp/Udp`'s `host`, `join`, `send`, `arrived`, `other`: a game's
  socket, never waited on. Linux's asks select before each read; Plan
  9's (`tcp/plan9/Udp`) is a conversation of `/net/udp`, announced
  with headers for the host, read by a process of its own (lib_core's
  `Source`). lib_core's `Unix` gained `recvfrom` and
  `sendto_substring` for it, and mini-9pi's UDP `announce` and
  `headers` (`kernels/9pi/network/ip/Udp`).

- `tcp/Dns` (62 lines): a name's addresses asked of the name server of
  `/etc/resolv.conf`, one UDP packet. mini-ml's `Unix.getaddrinfo` has
  no resolver (an address in numbers, `/etc/hosts`); OCaml's has the C
  library's, and `Dns` is then not reached. What mini-9pi asks with
  (2026-10-11), its server `/net/ndb`'s `dns=`.
- `tcp/Udp` (a question and its answer) and, for Plan 9, `tcp/plan9/Tcp`
  and `tcp/plan9/Udp` (mini-mk `O=5 OS=plan9`, found after Linux's and
  taken): no socket, a connection is `/net/tcp`'s files (clone, ctl's
  `connect a!port`, data), as libc's dial. What was a socket's alone
  is behind them: `Tcp.arrived` (what can be read without waiting;
  on Plan 9 a read that waits) and `Tcp.wait`, which `Tls_client` now
  asks where it had `set_nonblock`, `EAGAIN` and `select`; `Dns` asks
  `Udp` and gives addresses as text. Not done on Plan 9: giving up
  after a silence (no select: an alarm's note), mini-httpd.
- lib_core's `Unix` gained `getsockname` and `setsockopt SO_REUSEADDR`
  (mini-httpd's).

## What remains in the playground

Of the files the first version stood on: `Http_request` (the same
request without blocking, 217 lines) and `Worker` (a pool of threads,
62): the plan's decision 6, "no threads at first".
And the rest of `libs/networking`: WebSocket, IRC, mail (SMTP, POP3,
MIME), the netcode's server (lib_playground/netcode's README), the
servers, `Tls_tunnel`, their tests
(`unix/tests`: here `networking/tests/tls.sh` does `Unit_tls_client`'s
work with the program).

## Checked

`tests/Test.exe` (32 tests, Testo, dune's only). mini-ml compiles every
file. `networking/tests/served.sh` and `tls.sh` on dune's programs and
on mini-ml's.
