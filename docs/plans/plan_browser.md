# Plan: a browser in ix: mini-netscape, and mini-lynx, mini-curl, mini-httpd and mini-node beside it (`browsers/`, `lib_networking/`, `lib_crypto/`, `lib_graphics/`)

The author (2026-10-09): "I would like to add a mini-netscape, and
maybe a mini-lynx, (and also mini-node, mini-httpd, mini-curl), a bit
like I did in ~/github/mini-chrome and also in the ~/playground with
TinyMoasic.ml, TinyFirefox.ml, etc. But we can't copy all the code
from ~/github/mini-chrome, so I would add what is really just
essential to render wikipedia correctly. We should probably add the
web languages (css, html, javascript) under browsers/ rather than
languages/ this time, and we will probably need to extend
lib_graphics/ in ix with images, like in the ~/playground/."

The short answer: **about 22,500 lines of .ml to copy (119 files),
where mini-chrome's mini-netscape stands on 40,100 (247 files):
13,400 for a Wikipedia article on the screen, 6,400 for the
JavaScript engine (mini-node's), 2,700 for a page's scripts over the
two.** The author (2026-10-09): "we want mini-netscape to have CSS,
html5, and also JS enabled". Two things decide the rest:

- **mini-chrome's mini-netscape does not show Wikipedia.** Its engine
  is Mosaic's (one pass, each element's look the browser's own); the
  article comes out as a list of links, one under the other, with or
  without `css=` (run 2026-10-09, the picture looked at). What shows
  Wikipedia right is mini-chrome's own engine: the cascade and CSS's
  boxes. So mini-netscape here is **Netscape's window over
  mini-chrome's engine**, and Mosaic's engine (979 lines) is not
  copied.
- **Wikipedia is https only**: TLS 1.3, its certificates checked, the
  cryptography under them. No program of this plan but mini-httpd and
  mini-node does anything without it: 3,600 lines before the first
  byte of a page.

Its numbers are `browsers/survey.sh`'s (run 2026-10-09, against
mini-chrome at `8af888e`, 2026-10-07, and the playground at
`028d8abf`, 2026-10-06): the modules a program's main names, and
theirs, by `ocamldep`; `-ml` adds mini-ml's **first** refusal of each
file, `-net` asks Wikipedia for the article.

**The aim** (the author, 2026-10-09: "we don't have to render
perfectly correctly wikipedia, but we want something pretty good for a
reasonable numbers of lines of code"): an article that reads as one,
its columns, its box and its pictures in their places; where a
feature costs many lines for little of the picture, the lines go.

**Status: not started** (the plan only; the survey is in). Of the
decisions, the budget's is agreed (9); the others are proposals.

## What there is to copy from

| mini-chrome's program | files | .ml | .mli |
|---|---:|---:|---:|
| mini-chrome | 311 | 49,441 | 25,118 |
| mini-firefox | 247 | 40,154 | 21,215 |
| mini-netscape | 247 | 40,104 | 21,215 |
| mini-mosaic | 189 | 27,284 | 15,916 |
| mini-lynx | 53 | 6,477 | 3,966 |
| mini-curl | 45 | 5,280 | 3,245 |
| mini-httpd | 2 | 206 | 92 |
| mini-node | 25 | 6,800 | 2,656 |

(The playground's modules under each are in; the files its dune makes,
Brotli's dictionary and the scripts' prelude, are not.) mini-netscape
is that large because one module, `Browser_tab` (782 lines), names the
scripts, the PDF viewer, the sound and every picture format: a browser
that shows one page needs a tab of its own, smaller.

The playground's TinyMosaic, TinyNetscape, TinyFirefox and TinyChrome
(695, 457, 495 and 641 lines) are what mini-chrome's four were before
they moved: the same engines, older. mini-chrome's are the ones to
copy from; for what it left in the playground (the cryptography, JPEG,
the rasterizer), the playground.

## What a Wikipedia article asks for

`https://en.wikipedia.org/wiki/OCaml`, 2026-10-09 (`survey.sh -net`):

- **The network**: TLS 1.3, the key exchanged by X25519, the cipher
  AES-128-GCM with openssl as the client (mini-chrome offers
  ChaCha20-Poly1305 first; which one it is given was not looked at);
  four certificates, all ECDSA (P-256 then
  P-384, signed with SHA-384), the last one signed by an RSA root.
  The page is 354 KB, sent in gzip when gzip alone is asked: no Brotli
  (2,472 lines with its dictionary), no Zstandard (602).
- **The page**: 2 style sheets linked (223 KB and 7 KB) and 13
  `<style>`, 9 tables, 5 scripts. Read without its scripts, as
  mini-chrome reads it (`docs/sites.md`: "None of the 🟢 ones needs
  them to be read").
- **Its sheets**: `display` is `flex` 25 times, `grid` 4 (the page's
  three columns), `table` 7; 48 floats (the box at the article's
  right); `position` absolute, relative, fixed and sticky; 66
  `@media`, 548 `var()`, 166 `calc()`. So flexbox, grid, tables and
  floats all stay, and the custom properties.
- **Its pictures**: 13 PNG, 1 JPEG, 5 SVG (the logo, the icons). No
  WebP (1,371 lines), no GIF, no ICO.
- **Its letters**: Latin with accents (`Glyph_unicode`); the phonetic
  signs and the names in other scripts are `?`, as in mini-chrome.

## What to copy

By where it would go here, with what is cut (`survey.sh`'s `cut`):
Brotli and Zstandard, TLS 1.2 and P-256's key exchange, WebP, ICO and
GIF, WebSocket, and what is there for speed alone (the
stopwatch, the state kept per domain, the animations).

| here | what | from | files | .ml | .mli |
|---|---|---|---:|---:|---:|
| `lib_crypto/` | SHA-256 and 512, ChaCha20, Poly1305, AES and GCM, bignums, RSA, ECDSA (the playground's); HMAC, HKDF, X25519 (mini-chrome's) | both | 13 | 1,116 | 542 |
| `lib_networking/` | `Url`, `Urlencoded`, `Http`, `Cookie`, `Http_cache`; `Asn1`, `Pem`, `X509`, `Tls13`; `Tcp`, `Tls_client`, `Http_client`, `Http_request`, `Keep_alive`, `Cookie_jar`, `Worker`; `Base64`, `Civil`, `Clock` | mini-chrome, 3 the playground's | 19 | 2,406 | 1,673 |
| `lib_compression/` | `Gzip`, over ix's `Zlib` (which has inflate and the CRC) | the playground | 1 | 65 | 53 |
| `lib_graphics/` | `Png`, `Svg` (mini-chrome's); `Jpeg`, `Dct`, `Jpeg_progressive`, `Huffman`, `Curve`, `Blit` (the playground's) | both | 8 | 1,664 | 940 |
| `browsers/html/` | `Dom`; `Html_lexer`, `Html_tree`, `Dtd`, `Entities`, `Charset`; `Forms`, `Line_mode`; `Xml` | mini-chrome | 9 | 1,408 | 933 |
| `browsers/css/` | `Css_syntax`, `Css_values`, `Selectors`, `Css_grid`, `Css_logical`; `Cascade`, `Computed`, `Looks`, `Css`; `ua.css` (63 lines) | mini-chrome | 10 | 2,548 | 929 |
| `browsers/engine/` | the boxes (`Box_tree`, `Box_layout`, `Box_flow`, `Box_inline`, `Table_layout`, `Flex_layout`, `Grid_layout`, `Box_grid`, `Html_layout`, `Hit`, `Box_types`); what draws them (`Browser_boxes`, `Browser_draw`, `Browser_text`, `Browser_picture`, `Stroke_text`, `Glyph_picture`, `Glyph_unicode`, `Svg_shapes`, `Style`); a page (`Browser_page`, `Browser_forms`, `Browser_url`, `Browser_history`, `Fetch`) | mini-chrome | 26 | 4,289 | 2,013 |
| | **the seven: a page fetched, read, laid out and drawn** | | **84** | **about 13,400** | **6,950** |
| `browsers/javascript/` | the language, mini-node's and a page's: `Js_lexer`, `Js_parse`, `Js_ast`; `Js_value`, `Js_props`, `Js_operators`, `Js_utf16`; `Js_eval` and 5 beside it; `Js_builtins`, `Js_globals`, `Js_json`, `Js_promise`, `Js_regexp`; `library.js` (541 lines) | mini-chrome | 20 | 6,448 | 2,292 |
| `browsers/webapi/` | scripts in a page: the document and its elements as a script sees them (`Script_dom`, `Script_document`, `Script_element`, `Script_events`, `Script_host`), the window, its timers and the event loop (`Script_window`, `Event_loop`, `Script_url`, `LocalStorage`), `fetch` and `XMLHttpRequest` under the same-origin policy (`Script_fetch`, `XMLHttpRequest`, `Cors`), a page's scripts and modules run (`Browser_script`, `Script_modules`, `Script_types`); 12 files of JavaScript (1,073 lines) | mini-chrome | 15 | 2,679 | 1,364 |
| | **all nine** | | **119** | **about 22,500** | **about 10,600** |

The programs' own files, to copy or write again over the above:

| program | mini-chrome's | lines | here |
|---|---|---:|---|
| mini-curl | `Curl`, `MiniCurl` | 110 | copied |
| mini-httpd | `Httpd`, `MiniHttpd` | 206 | copied; needs nothing above |
| mini-lynx | `Lynx`, `MiniLynx` (over `Line_mode`) | 109 | copied |
| mini-node | `Node_host`, `MiniNode` | 239 | copied |
| mini-netscape | `MiniNetscape` (470) over `Browser_tab` (782) | 1,252 | the window copied; the tab written again, with scripts and without viewers and WebSocket: its size is not known |

Already here, and not copied again: `Zlib` (the playground's `Zlib`,
`Inflate`, `Deflate`, `Adler32`, `Crc32` in one), `Rgba_image`,
`Framebuffer`, `Fill`, `Stroke`, `Affine`, `Vec2`, `Opti`, `Hershey`
(`lib_graphics/software/`), `Playground`, `Color`, `Lehmer`. Every
value of `Playground` and `Playground_platform` that mini-chrome's
display, tab and `MiniNetscape` name, ix's interfaces have.

**Not in this plan**: WebSocket and the sound a script makes (the
rest of `src/webapi`, 2,811 lines whole); tabs, the omnibox, the profile, the cache on disk,
the developer tools (mini-chrome's `src/chrome` and `src/window`); PDF
and its fonts, video and sound; mini-mosaic.

## What it requires, beyond the copy

1. **The files made what mini-ml takes.** 24 of the 82 `.ml` files of
   the seven compile as they are (crypto: 10 of 13; the javascript
   engine: 3 of 18; a page's scripts: 1 of 15, with 16 optional
   arguments more). Counted in the seven:
   - **85 optional arguments** (59 in the interfaces), the large one:
     TinyOffice had 11. Said by every caller, or a record of options
     where a function has several (`Http.get ?cookie ?agent ?keep`,
     `Box_flow.add_word ?boxed ?owner ?edge`).
   - **Labels**: 1,413 labelled lines in the interfaces. mini-ml takes
     a label where the function is known; `Option.value ~default:` and
     a label through a function value it does not (`aead ~key ~nonce`
     in `Tls13`): rewritten there.
   - **`Bigarray`** (`a.{i}` in `Png`, `Blit`, `Glyph_picture`,
     `Browser_boxes`, `Svg`): ix's `Rgba_image` is a `Bytes`.
   - **`Map.Make`** twice (`Computed`'s custom properties): lib_core's
     `Map_`, or a list. **`Lazy`** (11 lines): lib_core has none.
   - **`for _ = 1 to n`** (`Jpeg`, `Bignum`, `Chacha20`), a result
     type on a `fun` (`fun (c : t) : t -> ...`), `String.to_seq`: the
     line written otherwise.
   - **16 lines of polymorphic variants** (the pictures'), 3 `let
     open`, 2 objects' methods (the capabilities': as ix writes them).
   - **Threads** (`Worker`'s pool, 31 lines of `Mutex`, `Condition`,
     `Thread`): mini-chrome's `threads=off` is the same program
     without, the window waiting for the network. That way first.
2. **The network from an ix program.** On Linux lib_core's `Unix` has
   `socket`, `connect` and `getaddrinfo` in its interface; whether a
   program built by mini-ml reaches them is to be checked (dune's
   build does, by OCaml's own). Each through a capability
   (`Cap.network`), as mini-chrome's `Tcp` does already. `/dev/urandom`
   for TLS's secrets, the root certificates' file
   (`/etc/ssl/certs/ca-certificates.crt`), the clock for a
   certificate's dates.
3. **Pictures drawn.** ix's software platform draws a picture as its
   grey box "until the playground's `Blit` is here" (`lib_playground`'s
   README): `Blit`, then `Image` and `Bitmap` in
   `Shape_render_software`; by the draw device, a picture loaded once
   and drawn, as `Sprite`'s are.
4. **The screen as large as the window.** ix's platforms give a
   program 1,000 units square, scaled into the window: right for a
   game. A browser's page is as wide as its window (mini-chrome asked
   the playground for `screen_follows_window`, its history says): the
   same here, in `sdl/`, `ppm/` and the two Plan 9 platforms.
5. **A build**: dune's and mini-mk's for each directory, `bin/mini-*`
   for the five programs; `ua.css` and `library.js` kept as `.ml`
   files with the text in a string (as `Hershey_futural.ml`: no rule
   in dune nor in mini-mk).
6. **Tests**: mini-chrome's, copied with what they test (Testo, dune
   only): `html` 495 lines, `css` 526, `layout` 695, `network` 805,
   `network_unix` 446 (a TLS server by the `openssl` program),
   `images` 414, `js` 1,382. And **the article kept**: the page, its
   two sheets and its pictures saved once, served by mini-httpd, so
   that a frame can be compared without the network: against
   mini-chrome's frame of the same files: the measure, not the bar.
   Where lines were cut the frame differs, and each difference is
   looked at and kept if the page still reads well (the aim above).
7. **mini-9pi**, which lacks more than the others asked of it:
   - **a name resolved**: its stack has IP, ICMP and TCP, "No UDP yet"
     (`plan_9pi.md`), so no DNS; UDP and a resolver, or a table of
     names;
   - **secrets**: its `#c/random` is `Random.int`, which TLS cannot
     be given;
   - **the date**: a Pi has no clock that keeps it, and a
     certificate's dates are checked against one;
   - **the roots**: a file on its card;
   - **the time it takes**: mini-chrome spends 2.2 s on the article's
     styles and 0.9 s on its boxes, natively on this machine (8 s of
     CPU for the whole load, with scripts), and holds 225 MB; a Pi 1
     has 512 MB and a small fraction of the speed. A page there is
     also thousands of words drawn stroke by stroke. To be measured
     before anything is promised.

## Decisions (proposed)

1. **mini-netscape is Netscape's window over CSS's boxes, with
   scripts** (the author: "CSS, html5, and also JS enabled"). Scripts
   run unless `scripts=off`. HTML5 is taken as what a page of today
   is written in and mini-chrome's reader has: a page read as
   browsers read it (tags left open, tables, the elements of today,
   forms), not `<video>`, `<audio>` nor a canvas; to be said
   otherwise if more was meant. The look
   is `MiniNetscape`'s (the toolbar, the Location field, the "N", the
   status bar and its key); the engine is mini-chrome's. Netscape 4
   had style sheets, badly; the name says the period's window, not its
   engine. The alternative, a faithful Netscape 1 over Mosaic's
   engine, does not show Wikipedia.
2. **The languages under `browsers/`**: `browsers/html/`,
   `browsers/css/`, `browsers/javascript/`, as the author said; XML
   with HTML (it is `Svg`'s reader and 132 lines).
   `languages/README.md` gets a line pointing there.
3. **One `browsers/engine/`, flat**, for mini-chrome's `src/layout`,
   `src/display`, `src/www` and `src/url`: 26 files. Split if it grows.
4. **The programs**: `browsers/netscape/` (`Netscape.ml`,
   mini-netscape), `browsers/lynx/` (mini-lynx),
   `browsers/javascript/` with a `CLI.ml` and a `Main.ml` as
   `languages/scheme/` has (mini-node). mini-curl and mini-httpd in a
   new top-level `networking/`, principia's and xix's name for it.
5. **The libraries**: `lib_networking/http/` and `lib_networking/tls/`
   beside `9p/`; `lib_crypto/` and `lib_compression/` flat as they
   are; the pictures' readers in a new `lib_graphics/images/` (`Png`,
   `Jpeg`, `Svg`), `Blit` and `Curve` in `lib_graphics/software/`
   with what they are beside in the playground. `Base64` to
   `lib_core/`, `Civil` and `Clock` with the network (X.509's dates)
   until another program asks.
6. **No threads at first**: `Fetch` steps its requests on the frame's
   clock, a request that waits stops the window. `Worker` is copied
   when that hurts.
7. **TLS 1.3 only, and both ciphers kept** (AES-GCM is 174 lines, and
   what Wikipedia picks when a client prefers it; ChaCha20 would do
   alone). RSA kept (74 lines): the chain's last signature is RSA's
   unless the root just under it is trusted.
8. **The interfaces' lessons kept**: mini-chrome's `.mli` files open
   with what the module is and its history, which is why they are half
   the `.ml`'s lines. Not a trimming target, as the stdlib's.
9. **Counted in m-IX's budget, all of it** (agreed; the author,
   2026-10-09: "let's count the browser and the code it needs in the
   budget; hopefully with mini-office we will still stay inside the
   100 000 LOC limit; if we go above, it's ok, we can always try to
   reduce later"; and why: "a browser has become a pretty
   indispensible part of an OS", "so we should count it"): `browsers/`, `networking/` and the libraries. As
   they stand the nine are about 22,500 lines of .ml and 10,600 of
   .mli (and 1,614 of JavaScript), where `docs/loc.md` has about
   16,000 left: over the budget before stage 1
   and the trimming, which is the reason for both.
10. **A README in each new directory** (copied, changed, remains), its
    numbers a script's, and each copied file's origin in one `ix:`
    line; `scripts/playground_copies.sh` gains mini-chrome as a second
    source.

## The stages (each checked before the next)

1. **What the article runs.** The article saved (the page, its sheets,
   its pictures); mini-chrome built with a coverage tool (bisect_ppx,
   which this machine has not: to install, the author's call) and run
   on it; the lines never run, by file. That list is what "really
   just essential" is inside a file (and, the aim being pretty good
   and not perfect, what runs for little of the picture goes too), where the survey only cuts whole
   modules: `Computed` (740 lines) and `Box_layout` (899) are the two
   to look at first. The table above is redone from it.
2. **The cryptography and gzip.** `lib_crypto/`, `Gzip`; the
   playground's tests of them (known answers); built by dune and by
   mini-ml.
3. **The network: mini-curl and mini-httpd.** `lib_networking/`,
   `networking/`. Checked: mini-curl reads a page of mini-httpd's;
   mini-chrome's `network` and `network_unix` tests; `mini-curl -v` of
   the article gives mini-chrome's bytes.
4. **HTML: mini-lynx.** `browsers/html/`, `browsers/lynx/`. Checked:
   `mini-lynx -dump` of the saved article is mini-chrome's text, byte
   for byte.
5. **Pictures, and the window's size.** `lib_graphics/images/`,
   `Blit`, a picture drawn by the platforms, the screen as large as
   the window. Checked: mini-chrome's `images` tests; a Playground
   example with a picture, its frame.
6. **CSS and the boxes: a page as a frame.** `browsers/css/`,
   `browsers/engine/`. Checked: mini-chrome's `css` and `layout`
   tests; the saved article's frame by the `ppm` platform against
   mini-chrome-software's.
7. **mini-netscape on Linux.** The window, the tab: a link followed,
   Back, the wheel, a search typed in Wikipedia's field. Scripted
   sessions and their frames (`games/tests/frames.sh`); the real
   Wikipedia by hand.
8. **JavaScript: mini-node.** `browsers/javascript/`. Independent of
   2 to 7: at any time after 1, and before 9. Checked: mini-chrome's `js` tests.
9. **Scripts in a page.** `browsers/webapi/`, the tab's scripts.
   Checked: mini-chrome's `browser` tests of scripts (`Unit_script_dom`,
   `Unit_browser_script`: 728 lines); a page of mini-httpd's with
   jQuery, as mini-chrome's `docs/sites.md` did; Wikipedia with its
   scripts (in mini-chrome its startup script and loader run, two
   modules stop and the page shows as without them: 1 s more).
10. **mini-9pi.** What item 7 above lists, in the order it blocks:
   a name, secrets, the date, then mini-curl there, mini-lynx, and
   mini-netscape in a window of mini-rio, its time measured first.
11. **The docs.** The READMEs, `docs/loc.md`'s row,
    `plan_ml_bootstrap.md`'s ledger for what mini-ml or lib_core
    gained, this plan's Status.

## Open questions

- **How much of the 13,400 lines stage 1 removes.** Not known; the
  survey's cut is by module, and the sheets use most of what the
  engine has (flex, grid, tables, floats, custom properties).
- **The tab without scripts**: how many of `Browser_tab`'s 782 lines
  are left.
- **The article in the repository**: Wikipedia's text is CC BY-SA and
  its pictures have each their own licence. Kept here with its
  attribution, or fetched by a script and compared by sums?
- **The letters**: Hershey's strokes as mini-chrome, or on mini-9pi
  the draw device's font (faster, Plan 9's look, another layout: a
  word's width is the font's)?
- **The same frame as mini-chrome's**: ix's rasterizer is the
  playground's with a `Bytes` for a Bigarray; the same pixels on
  Linux is likely and not checked; under mini-ml on arm seven of the
  examples' frames already differ by a rounding.
- **Sockets by mini-ml on Linux**, and threads there: not looked at.
- **mini-9pi's secrets and date**: from the host through QEMU, from
  the network (a time server needs UDP too), or typed at boot?
- **mini-mosaic**: 979 lines of engine and 698 of window more, for
  the web of 1993. Not asked; cheap once HTML and the network are
  here.

## Status

Not started. 2026-10-09: the survey (`browsers/survey.sh`) and this
plan; the aim and the budget said by the author, and scripts in a
page, which the plan first left out. Run for it, and nothing else: mini-chrome's mini-curl,
mini-netscape and mini-chrome-software on the article, their frames
looked at; `survey.sh`, with `-ml` and `-net`.
