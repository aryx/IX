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

**The base, since 2026-10-09: mini-chrome's first version, 14,400
lines of .ml, and what a site asks for added back** ("The way",
below). What follows it is today's mini-chrome, the ceiling.

The short answer then: **about 22,500 lines of .ml to copy (119 files),
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

The numbers are a ceiling: mini-chrome's files as they are, where
the author wants what is truly essential of each (below).

**Status: stages 2, 3, 4, 5 (but the window's size), 6, 7 (a first one) and 8 done: the cryptography
(`lib_crypto/`), the network (`lib_networking/`; mini-curl and
mini-httpd in `networking/`), HTML and mini-lynx (`browsers/html/`,
`browsers/lynx/`), JavaScript and mini-node (`browsers/javascript/`),
CSS (`browsers/css/`), the boxes and their shapes
(`browsers/engine/`), and a first mini-netscape
(`browsers/netscape/`): the Wikipedia article is fetched, laid out and
shown in its window with its pictures, its scripts not run.**
Left: the window's size (stage 5), scripts in a page (9), the program
built by mini-mk, mini-9pi (10), `docs/loc.md` (11). Of the decisions, the budget's is agreed (9) and the base;
the others are proposals, followed as written until said otherwise.
"Status", at the end, has each stage's account.

## The way: mini-chrome's first version, then what a site asks for

The author (2026-10-09, stage 1's cuts read): "maybe let's start with
one of the first version of mini-chrome? and add back stuff that was
added in later versions, so we can control things a bit better and see
whether we need them by just trying our mini-netscape on websites
(including wikipedia). Note that already the first version of
mini-chrome was relying on libraries that are not yet in m-ix like the
images, so we will also need to add that".

So the base is **mini-chrome's first commit, `475a979` (2026-09-30:
the playground's TinyChrome moved), on the playground of that hour,
`6154076a`**, and not today's files cut down. `browsers/first_version.sh`
takes both out of their histories, builds them and counts them (run
2026-10-09):

| here | the first version, .ml | .mli | today's (the ceiling, below) |
|---|---:|---:|---:|
| `lib_crypto/` (the playground's) | 1,116 | 487 | 1,116 |
| `lib_networking/` (the playground's then: `Url`, `Urlencoded`, `Http`, `Transport`; `Asn1`, `Pem`, `X509`, `Tls13`; `Tcp`, `Tls_client`, `Http_client`, `Http_request`, `Worker`; `Base64`, `Civil`, `Clock`) | 1,867 | 1,121 | 2,406 |
| `lib_compression/` (no gzip asked then) | 0 | 0 | 65 |
| `lib_graphics/` (the playground's `Png`, `Jpeg`, `Dct`, `Svg`, `Huffman`, `Curve`, `Blit`) | 1,602 | 702 | 1,664 |
| `browsers/html/` | 1,185 | 638 | 1,408 |
| `browsers/css/` (`Looks` 290: the browser's own sheet was OCaml) | 2,119 | 733 | 2,548 |
| `browsers/engine/` (`Box_layout` one file of 1,268, `Html_layout`, `Flex_layout`, `Table_layout`, `Hit`; the display's five; `Browser_page`, `Browser_forms`, `Browser_url`, `Browser_history`; `Linebreak`, `Style`) | 3,552 | 1,179 | 4,289 |
| **the seven** | **11,441** | **4,860** | **13,400** |
| `browsers/javascript/` (7 files) | 2,238 | 597 | 6,448 |
| `browsers/webapi/` (`Browser_script` alone) | 724 | 153 | 2,679 |
| **all nine** | **14,403** | **5,610** | **22,500** |

(The engine's row is the survey's less `Css` and `Base64`, which two
rows have.) Beside them, the first version's own tab and window:
`Browser_tab` 464 lines, `MiniChrome` 640; its viewers of sound and
video, its `about:` pages and its developer tools are not taken.

**What it shows today** (the same script: each site loaded without a
screen, 1,400 by 900, the frames looked at):

- **Wikipedia's article reads**: the title, the tabs, the text with
  its links, the box at the right with its logo, the Contents. Not
  there: the three columns (the Contents are above the article, for
  want of a grid), a letter with an accent (`J?r?me`), the page as
  wide as the window (it is 900 wide in the middle of a 1,400 window),
  the search field.
- **Hacker News is right.**
- 27 s of processor for the article's 420 frames and 243 MB (today's:
  5 s, the same memory): the first thing a Pi will ask back.

**What is added back, and when.** Each thing mini-chrome gained since
is a commit, or a few (`survey.sh -log`; stage 1's table of cuts
names them): it comes here when a site tried shows the want of it,
with the site and the lines it cost said in the directory's README.
In the order the article asks, as far as the frames say:

| what | mini-chrome's commit | lines there |
|---|---|---:|
| the page laid out at the window's width | `864e2cd` | to count |
| a letter with a mark, quotes and dashes (`Glyph_unicode`) | `438c2a1` | 214 |
| CSS grid: the article's three columns (`Css_grid`, `Grid_layout`, `Box_grid`) | `add433e` | 447 |
| a page's styles three times cheaper; a letter drawn as one picture made once (a frame 74 ms to 8) | `1b41d96`, `dff5a1b` | 47 + 117 |
| gzip asked and read (the article is 354 KB plain) | `4b33db0` | 7, and `Gzip` 65 |
| a connection kept between requests (`Keep_alive`) | `b19d1ad` | 107 |
| cookies | `bc739f9` | 253 |
| the programs beside: mini-curl, mini-httpd, mini-lynx; mini-node | `d3e138f`, later | 110, 206, 109; 239 |

The rest (today's 8,100 lines more: the language of today, the
libraries' wants, modules, promises, frames, `fetch`) waits for a site
that needs it. Stage 1's coverage stays as the measure of what
Wikipedia runs in today's files: a commit brought back is cut by it.

**What this settles**: AES-GCM and RSA come as the first version has
them (the playground's `lib_crypto` whole: decision 7 as written);
there is no `async` function at first, so no coroutine on a thread;
mini-netscape's window is written over the first version's
`Browser_tab`, which has no PDF, no sound's scripts, no WebSocket.

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

By where it would go here, whole modules only (the next section cuts
inside them), with what is cut (`survey.sh`'s `cut`):
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
and its fonts (`plan_pdf.md`, its stage F, after this plan's stage 5),
video and sound; mini-mosaic.

## Not a copy as it is: what is truly essential

The author (2026-10-09): "ideally we don't have to copy as is the code
from ~/github/mini-chrome for the css, js, etc. but can cut down a
little and take only what is truly essential (might be hard to judget
sometimes, maybe the git log history might show the original code and
fixes added later and why)".

So the tables above are the ceiling, a module cut or kept whole, and
each file is then read and cut. Two things say what to cut, neither
alone:

- **mini-chrome's history** (`survey.sh -log`: a file's lines in its
  first commit, now, and the commits that changed it). Its first
  commit, 2026-09-30, is the playground's TinyChrome moved, which
  "Hacker News and Wikipedia loaded" (`docs/history.md`), the
  article's columns one above the other for want of a grid. In eight
  days and 164 commits, the same files:

  | | first commit | now |
  |---|---:|---:|
  | `browsers/html/` | 1,185 | 1,408 |
  | `browsers/css/` | 2,119 | 2,548 |
  | `browsers/engine/` (its files of mini-chrome) | 3,416 | 4,222 |
  | `browsers/javascript/` | 2,238 | 6,448 |
  | `browsers/webapi/` | 724 | 2,679 |

  (A file that was not there may be a new thing, `Grid_layout`, or an
  old one split or brought from the playground later, the network's:
  the log says which.) The commits say why a thing came, most by the
  site that asked for it: "a negative padding is none (LWN)",
  "Gmail's loading screen and frame: an animation's end, z-index",
  React for GitHub, Polymer for YouTube, the speed of 4 MB of Ember.
  What came for Wikipedia, or for every page, stays; what came for a
  site that is not the aim is the first to go. The language grew the
  most, three times, and for the sites that are all scripts: its
  first commit's 2,238 lines ran the scripts of the playground's own
  pages (which others, not looked at), and is the nearer measure of what a
  Netscape's scripts need.
- **What the article runs** (stage 1's coverage): the history cannot
  say that a line of the first commit is never reached, nor that a
  later fix is what makes the article's box sit right.

Hard to judge sometimes, as the author says: a cut is tried, the
article's frame looked at, and kept if the page still reads well. What
was cut and why goes in the directory's README ("remains"), so that it
can come back.

## Stage 1: what the article runs, and the cuts proposed

`browsers/coverage.sh` (run 2026-10-09; a minute and a half once
built): mini-chrome and the playground copied, built with bisect_ppx
(the 4.14.2 switch has it), and the article loaded eight times by
mini-chrome-software without a screen (the first screen, scrolled to
its end, 1400 wide for its three columns, a link clicked; each
without scripts and with them; `threads=off cache=off`), once by
mini-curl and once by mini-lynx. `browsers/coverage.py` cuts each file
in its top-level definitions and says which were never run; `-v` names
them. The frames were looked at: the article reads as one at 1400.

| here | .ml | in definitions never run | more, in branches (an estimate) |
|---|---:|---:|---:|
| `lib_crypto/` | 1,116 | 208 | 27 |
| `lib_networking/` | 2,406 | 619 | 353 |
| `lib_compression/` | 65 | 11 | 19 |
| `lib_graphics/` | 1,664 | 300 | 211 |
| `browsers/html/` | 1,408 | 177 | 209 |
| `browsers/css/` | 2,548 | 232 | 487 |
| `browsers/engine/` | 4,289 | 581 | 671 |
| **the seven, without scripts** | **13,496** | **2,128 (16%)** | **1,977** |
| `browsers/javascript/` | 6,448 | 720 | 1,654 |
| `browsers/webapi/` | 2,679 | 375 | 741 |
| **the two, with scripts** | **9,127** | **1,095 (12%)** | **2,395** |

The second column is solid: a function that has code and none of it
ran. The third is not: a point is where an expression starts, the
lines after one not reached are counted up to the next; and a branch
not taken by this article (an error said, a tag left open another
way) is often one the next article takes. Half of it is a fair guess.

What the coverage cannot say: a form sent and a text typed (the
script's keys did not reach the field: `Forms`' submission and
`Browser_forms`, 79 lines, are counted never run and stay), Back, a
page of `http://`, and anything of another article (a progressive
JPEG, a GIF, a certificate signed by RSA).

**The cuts proposed**, the two voices together (the coverage's
definitions, `-v`; the history's commit). Each is the author's to
take or leave:

| what | lines | the coverage | the history |
|---|---:|---|---|
| `Http_request` and `Worker`: a request stepped without blocking, the pool | 285 | 208 never run (https, `threads=off`: `Http_client` does it, the window waiting) | decision 6 |
| `Http_cache`, and `Http`'s server side (`parse_request`, `response`, `reason`: mini-httpd's, to its own file) | 82 + 43 | never run | the cache on disk came with `02ee2ce`, for speed |
| `Aes`, `Gcm`: the second cipher | 174 | 130 never run: Wikipedia gives mini-chrome ChaCha20-Poly1305 | decision 7 kept both |
| `Rsa`, and `Bignum`'s part for it | 74 + about 20 | 55 never run: the chain ends at an ECDSA root this machine trusts | decision 7 kept it; other sites' chains are RSA's |
| TLS 1.2's part of `Tls13` | about 48 | 84 lines in branches not taken | `290f7b5`, "for the servers that have no 1.3" |
| `Civil` (all but a date to days), `Clock`'s printing, `Base64.encode`, `Cookie`'s own calendar | about 90 | never run | |
| `Jpeg_progressive`, `Jpeg`'s restarts | 101 | never run: the one JPEG is a baseline one | other articles' photographs may be progressive: to check on three of them first |
| `Png.encode` and what it alone names; `Blit`'s smooth scaling; `Curve`'s splines and lengths; `Dct.fdct`; `Gzip.compress` | 67 + 55 + 42 + 14 + 11 | never run (a browser reads pictures) | the playground's, for its own programs |
| `Svg_shapes` (an `<svg>` written in the page), `Box_layout.svg_size` | 113 | 90 never run | `78c1306`, for tinybox in a page |
| the printers: `Selectors.to_string`, `Html_lexer.to_string`, `Dom.to_lines`, `Cascade.explain`, `Browser_page.explain` | 41 + 30 + 23 + 39 + 21 | never run | the developer tools' and `Css_census`'s, not copied; a test that prints one keeps it |
| `Browser_page.with_frames`, `import_of` (an `<iframe>`, `@import`) | 53 | never run | `7e46433` (frames), a deck of Slipshow's |
| `Stroke_text.glyph_segments` (`letters=segments`), `Box_tree.scaled` (`transform: scale`), `Html_layout.greedy`, `Looks`'s colours and sizes of Mosaic's | 47 + 33 + 22 + 35 | never run | `dff5a1b`, `a09ff1f`; Mosaic's engine |
| `Cascade`'s styles kept from one styling to the next | about 120 | run | `8bb127e`: speed, for pages a script restyles; to measure with scripts on before it goes |
| a grid item between named lines; `@layer` | about 67 | `Grid_layout.along` and `Css_grid.line` never run | `e74db65`, GitHub and BBC News |
| **the seven** | **about 1,750** | | |
| ES modules and import maps: `Script_modules`, `Js_parse`'s `import` and `export`, `Js_eval`'s modules | 134 + 75 + 23 | 93 + 75 + 23 never run | `0be05e5`, "today's scripts" |
| generators and `yield`, `with`, a direct `eval` | about 75 | never run | `e74db65`, `41893a5` (GitHub, Vue) |
| `Js_ast`'s printers | 141 | never run | a function's own text (`e0794fc`, Gmail) names them: a function then prints as its source's slice, or `[native code]` |
| `Js_slice` (the window alive while a script runs) | 96 | 50 never run | `2e1af05`, Discourse; needs threads |
| `Script_fetch`'s `Response`, `Cors`, shadow trees, frames' scripts, WebSocket's event, `popstate` | about 150 | never run | `252d296`, `eb9dd13`, `5a1f93e`, `b38d51e` |
| a string in UTF-16's units: `Js_utf16` | about 230 | 81 never run or not taken | `c786db0`, Gmail; a string is then its bytes, `length` wrong past ASCII |
| **the two** | **about 900** | | |

So **about 2,650 lines of the 22,600 by whole definitions** (12%), and
perhaps 2,000 more inside the functions that stay, found when each
file is read: **about 18,000 to 20,000 lines of .ml**, where m-IX has
23,900 left of its 125,000 (`docs/loc.md`, 2026-10-09; the plan's
"16,000 left" was the 100,000's). The interfaces follow in
proportion. That is less than hoped: the article's two sheets use
what the engine has, as the survey said, and Wikipedia's own scripts
(jQuery under its loader) reach 4,575 of the language's 6,448 lines
and 1,893 of the page's 2,679, to show the page as without them.

**Found on the way, for "What it requires":**

- **`async` and `await` stand on a thread** (`Js_coroutine`: a
  `Mutex`, a `Condition`, a thread a coroutine), and the article's
  scripts run them (all its definitions but one). So "no threads at first" has
  no `async` function, unless a coroutine is written another way (the
  function's body cut at each `await` by the evaluator: not small).
  With `Js_promise` it is 305 lines.
- **Without threads a request is `Http_client`'s, blocking**, not
  `Http_request`'s stepped on the frame's clock as decision 6 said: 27
  requests one after the other, the window still (14 s for the first
  screen here, 5 of them the processor's).
- **A connection kept** (`Keep_alive`, 107 lines, `b19d1ad`, for
  speed) is run and stays: without it each of the 27 requests is a TLS
  handshake, an X25519 and the chain's signatures checked by `Bignum`,
  which a Pi would feel (not measured).

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
   - **ints of 31 bits** (stage 2, run): `Chacha20`, `Poly1305` and
     `Bignum` (so `X25519`, `Ecdsa`, `Rsa`) count in native ints taken
     to be 63 bits wide, and give other bytes built for arm; the
     hashes, `Aes` and `Gcm` are right there (`lib_crypto/README.md`).
     Limbs of 13 bits, or `Int64`, in those three, before any TLS on a
     Pi 1; and the vectors took 31 s under mini-5i for 0.35 s on
     arm64;
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
   until another program asks. **mini-office asks for the pictures
   first** (2026-10-09): `plan_office.md`'s stage 7 ("A picture from a
   file") copies `Huffman`, `Png`, `Dct`, `Jpeg_progressive`, `Jpeg`
   and `Blit` to these places, writes `Image_file` (the format by the
   file's first bytes) and has the platforms draw `Playground.Bitmap`.
   Whichever plan comes to it first does it; the other takes it as it
   is.
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

Since the base is the first version: a stage copies **its** files
(`first_version.sh`'s two trees), not today's; stage 1 is done; a
stage's "mini-chrome's tests" are the first version's (`html` 426
lines, `css` 326, `layout` 552, `js` 289, `browser` 261; the
playground's own for its libraries); mini-curl, mini-lynx and
mini-httpd are today's small mains over the first version's network
and `Line_mode`; and after stage 7 comes **the sites**: mini-netscape
tried on Wikipedia and a few others, and the table above gone
through, a thing at a time.

1. **What is essential.** The article saved (the page, its sheets,
   its pictures). Then, for each file of the tables, two lists: the
   lines the article never runs (mini-chrome built with a coverage
   tool, bisect_ppx; run with scripts and without), and what its history
   added and for which site (`survey.sh -log`, then the commits
   read). From both, a list of cuts by file, with the lines each
   saves, for the author to read before any file is copied; the
   tables redone from it. The language and a page's scripts first:
   they are 9,100 of the 22,500 lines and grew the most.
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
   example with a picture, its frame. If `plan_office.md`'s stage 7
   is done by then, what is left here is `Svg`, `Curve`, a picture by
   its URL (`Fetch`, `Browser_picture`) and the window's size.
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

The zoom (2026-10-10; the author: "let's add the Ctrl-+ (I don't
remember the keys) to enlarge the font on a page, like we do in
mini-chrome"; and, of what is to come: "don't forget to pass the caps
if you do IO on the filesystem, to save preferences, bookmarks,
cookies, etc."): mini-chrome's `Browser_zoom` (its `8af888e`, 30
lines; `browsers/netscape/`): Ctrl and + or =, Ctrl and -, Ctrl and 0,
Ctrl and the wheel; Chrome's steps, a site its own. The whole page
grows, as there: `Tab.resized` lays it out at the window's width
divided by the zoom, `Netscape` draws it scaled and divides the
mouse's place and what is scrolled by it; the zoom at the right of the
status bar. Checked: `frames.sh`, 21 sessions: the 16 of before
unchanged, and zoom-in (looked at), zoom-out (looked at), zoom-reset
(the frame of pictures), zoom-wheel (the frame of zoom-in), zoom-link
(a link clicked in the page at 125%: the menu, looked at); mini-ml
compiles `browsers` (46 files). Not run: the SDL window. Not done:
the zooms kept from a run to the next (mini-chrome's profile; nothing
is written to a file yet, and what will be goes through a capability).

The window's manners (2026-10-10; the author: "a few nice things are
missing from mini-chrome: first the cursor change when it hovers a
link; then the mousewheel works to scroll, finally would be good to
show when things are loading because clicking a link right now is very
"blind""). No platform of ix's sent the wheel nor had a cursor:
`Playground_platform.set_cursor` (SDL's system cursors; nothing yet on
Plan 9 nor in `ppm/`), the wheel from SDL's events and from Plan 9's
buttons 4 and 5 (`Plan9_loop`), and `wheel(notches):n` in a script
(`Input_script`). `Tab` loads in pieces: `go`, `visit`, `back`,
`forward`, `reload`, `click` and `key` ask and take no capability;
`step` fetches the page with its sheets, then a picture a call, and
lays the page out again after the last; `busy`, `under` (a link, a
field, a button). `Netscape` calls `step` once between two frames
drawn, says "Loading ..." and "Loading pictures: 3 of 19" in the status
bar, turns its N white meanwhile, and asks for a hand over a link or a
button and an I-beam over a field. Checked: `frames.sh`, 16 sessions:
the 11 of before unchanged, the pictures' two with more frames and the
same sums, and three new, looked at (`loading`, `wheel`, `asked`);
mini-ml compiles `browsers` and `lib_playground`. Not run: the SDL
window on a screen, so neither the cursor nor a real wheel was seen;
Plan 9's wheel. Not done: a page shown while its sheets come; the page
laid out as each picture comes; Stop.

Stage 5, the pictures (2026-10-10; the author: "the png and jpeg and
so on are now in ix/, and we also recently added PDF, so we can
continue and add support for those in mini-netscape now"; the PDF was
already there, `plan_pdf.md`'s stage F). The playground's `Gif` (147
lines; `lib_graphics/images/`) over its `Lzw` (104; `lib_compression/`)
and its `Svg` (504; `lib_graphics/svg/`, a directory of its own:
`images/` is built before `software/`, whose `Fill` and `Stroke` it
calls), with their tests (`Unit_gif` and its four files, `Unit_svg`):
the pixels a `Bytes`, a path's tokens types, `Svg.render_in` for
currentColor. `Browser_picture.decode` is mini-chrome's again (PNG and
JPEG by `Image_file`), `Browser_boxes` draws an `<svg>` written in the
page, and `Tab.with_pictures` fetches a page's `<img>`s and its
boxes' backgrounds after its sheets, one after the other, then lays
the page out once more. Checked: the images' tests and Svg's 7; mini-ml compiles
`lib_compression`, `lib_graphics` and `browsers` (45 files);
`frames.sh`'s two new sessions (`pictures.html`: a PNG with alpha, a
JPEG, a GIF, an SVG file, an `<svg>`, one that is missing, a
background; a picture in a link followed) and the eleven of before;
**the live Wikipedia article with its logo, the OCaml logo and its
icons, the frame looked at: 11.2 s and 176 MB**, where it was 2.8 s
without pictures (a TLS connection a picture: `Keep_alive` is not
back). Not done: the window's size; pictures on their way while the
page is read (decision 6: nothing is on its way); a GIF's animation; a
background picture tiled (the first version draws it once); nothing of
this run by mini-ml's code (mini-netscape is not linked by mini-mk).

Stage 7, a first mini-netscape (2026-10-09): `browsers/engine/` gains
mini-chrome's first version's `Browser_page`, `Browser_forms`,
`Browser_url`, `Browser_history` and `Linebreak` (675 lines there);
`browsers/netscape/`, written for ix: `Tab` (a page and its history;
the page, then its sheets, fetched one after the other by
`Http_client`, no threads) and `Netscape` (the window: toolbar,
Location, the N, the status bar), 369 lines of .ml where the first
version's tab and window are 1,104. Built by dune for the ppm platform
(the tests') and for SDL (`bin/mini-netscape`). Checked:
`browsers/netscape/tests/frames.sh`, nine sessions on local pages (a
link, Back, an address typed, a form sent, a #fragment, the keys, a
file not there), their frames looked at; by hand, without a window,
**`url=https://en.wikipedia.org/wiki/OCaml`: the article fetched with
its two sheets over ix's TLS, laid out, drawn and scrolled, 2.8 s**;
mini-ml compiles the 44 files of `browsers/`. Not done: pictures;
scripts in a page (stage 9: `Browser_script` not copied, and the
language to grow first); **the program by mini-mk** (not linked by
mini-ml yet: the playground's units, while lib_graphics is being
moved), so nothing of the window is run by mini-ml's code; the
window's size (the page is 1,000 units wide); the SDL window seen on a
screen (started under SDL's dummy driver only); the search typed in
Wikipedia's field (a form of a local page was).

Stage 6, the shapes (2026-10-09): mini-chrome's first version's
`src/display` in `browsers/engine/` (5 modules and `Style`, 543 lines
of .ml here), over ix's `Playground`, `Hershey` and `Rgba_image` as
they are; `tests/Frame.ml`, a page as a PPM without a window (dune's).
**The Wikipedia article is drawn and reads, 1,400 by 900** (the frame
looked at: the title, the text and its links, the box at the right),
in 0.8 s whole by OCaml's build. No picture is read
(`Browser_picture.decode` says Broken: `Png` and `Jpeg` are another
session's work in progress, `Svg` and `Gif` not begun) and an inline
`<svg>` is not drawn. A bug of mini-chrome's tree builder found and
fixed (`</table>` with a cell open: `docs/plans/bugs/mini_chrome.md`,
new). Checked: mini-ml compiles the 37 files of `browsers/`; the
engine's 61 tests and the 44 of HTML still pass; mini-lynx's text of
the article unchanged. Not done: `Frame` by mini-mk (the playground's
and lib_graphics's units to link: lib_graphics's folders are being
moved by the other session), so the display is compiled by mini-ml
and not run by it; no recorded frame as a test; `src/www`, the tab,
the window: stage 7.

Of stage 5's pictures, by `plan_pdf.md` (2026-10-09): the playground's
`Png`, `Jpeg`, `Dct`, `Jpeg_progressive`, `Huffman`, `Curve` and
`Blit` are here (`lib_graphics/images/`, `geometry/`, `core/`,
`lib_compression/`), made what mini-ml takes; `Svg` is not.

Stage 6, the boxes (2026-10-09): `browsers/engine/`, mini-chrome's
first version's `src/layout`, 5 modules (2,243 lines of .ml here, 631
of .mli) and its 61 tests; `Html_layout.layout` takes a record of
options, a line breaker has no label. `tests/Boxes.ml`: a page as its
boxes, printed, built by mini-mk too. Checked: the 61 tests; mini-ml
compiles every file of `browsers/` (31); `tests/boxes.sh` on both
builds; **the Wikipedia article with its two sheets, 1,400 wide: the
same 1,436 lines of boxes by OCaml's build and by mini-ml's**, 0.32 s
and 1.03 s of styles and boxes (the plan's "2.2 s on the article's
styles" was today's mini-chrome's, with its scripts). Not done: the
display, a page, the tab (the other half of stage 6 and stage 7),
which need a picture drawn (`plan_office.md`'s stage 7, in progress
in another session) and the window's size.

Stage 6, its first half (2026-10-09): `browsers/css/`, mini-chrome's
first version's 7 modules (2,138 lines of .ml here with `Ua_sheet`'s
59, 739 of .mli) and its 30 tests. Six optional arguments are pairs of
functions (the README). Checked: the 30 tests; mini-ml compiles the 8
files. Nothing run by mini-ml's build yet: no program stands on CSS
before the engine.

Stage 8 (2026-10-09): `browsers/javascript/`, mini-chrome's first
version's 7 modules (2,205 lines of .ml here, 599 of .mli) and its 30
tests; mini-node (`CLI.ml`, `Main.ml`, 47 lines), written for ix. The
`~this` label is gone (61 places: a function out of a constructor,
mini-ml knows no labels of), two polymorphic variants are types, a
local exception is at the top. Checked: the 30 tests; mini-ml compiles
the 9 files; `tests/scripts.sh`: `language.js`'s 18 lines the same by
OCaml's build, by mini-ml's and by Node. **Found: the first version's
language is a small subset** (no `in`, `switch`, `do`, `finally`,
bitwise operators, `delete`, `JSON.parse`...; the README's list):
jQuery will not run on it, so stage 9 begins with mini-chrome's
commits that grew the language (`e74db65` and after), which this
plan's "all nine" row of 14,403 lines did not count. And: the parser
is by hand, as mini-chrome's, where ix's rule is ocamlyacc: kept, to
be confirmed.

Stage 4 (2026-10-09): `browsers/html/`, mini-chrome's first version's
8 modules (1,150 lines of .ml here, 641 of .mli) and its 44 tests;
nine optional arguments written otherwise (`Dom.element_with`,
`Dom.attribute_any`...; the README); `Line_mode`'s blocks and table
rows added back (`d3e138f`, 11 lines), the first thing of the table
"What is added back". `browsers/lynx/Lynx.ml` (120 lines), written
for ix after mini-chrome's. `scripts/option_value.py`: `Option.value
~default` as a match, for the copies to come. Checked: the 44 tests;
mini-ml compiles the 9 files; **`mini-lynx -dump` of the article
(mini-curl's 354,169 bytes) is today's mini-chrome's mini-lynx's
text, byte for byte**, by dune's build and by mini-ml's (0.08 s and
0.26 s); `browsers/lynx/tests/session.sh` on both. Not done: the
article is not saved in the repository (its licence, an open
question), so that comparison is by hand; arm, Plan 9.

Stage 3 (2026-10-09): `lib_networking/tcp`, `tls` and `http`, 14
modules of the playground's (1,448 lines of .ml, 937 of .mli) and
`Dns`, ix's own (62: mini-ml's `getaddrinfo` has no resolver, which
answers "Sockets by mini-ml on Linux" below: they work, a name needed
this); `networking/Curl.ml` and `Httpd.ml` (247 lines), written for ix
after mini-chrome's; lib_core's `Unix` gained `getsockname` and
`setsockopt SO_REUSEADDR`. No optional argument is left; no threads
(`Http_request`, `Worker` and `Transport` not copied: decision 6).
`Base64` is with `tls/`, not in `lib_core/` as decision 5 said: one
user, and lib_core's units are listed in mkconfig. Checked: the
playground's 32 tests of these modules (Testo); mini-ml compiles the
19 files; `networking/tests/served.sh` (mini-curl reads what mini-httpd
serves, 19 cases) and `tls.sh` (against `openssl s_server`, both
ciphers, ECDSA and RSA, two refusals), each on dune's programs and on
mini-ml's; by hand, `mini-curl -L https://en.wikipedia.org/wiki/OCaml`:
354,169 bytes, the same by both, 0.9 s and 1.6 s. Not done:
mini-chrome's `network_unix` tests as they are (Testo over a server in
a thread); "`mini-curl -v` gives mini-chrome's bytes" (the User-Agent
differs, the body was not compared with mini-chrome's); arm, Plan 9;
`make test-lite` whole.

Stage 2 (2026-10-09; the author: "let's start the plan browser and
mini-netscape!"): the playground's `libs/crypto` in `lib_crypto/`,
13 modules, 1,038 lines of .ml and 487 of .mli, with its tests (14,
Testo) and a README. Three lines changed for mini-ml (`String.to_seq`
twice, `for _` twice); the labels stay. No `Gzip`: the first version
asks for none (the table of what is added back has it). ix's own:
`lib_crypto/tests/Vectors.ml`, a known answer of each module printed,
built by mini-mk too. Checked: dune's build, the 14 tests; mini-ml
compiles the 14 files (`compile_ix.sh lib_crypto`); the vectors built
by mini-ml for arm64 say OCaml's 24 lines. **For arm they do not**
(item 7 above, stage 10's). Not run: `make test-lite` whole (the two
jobs added to it were run by hand).

The base (2026-10-09): mini-chrome's first version, the author's
choice; `browsers/first_version.sh`, its table and the two frames
looked at (above). mini-ml on the first version's files (`survey.sh
-ml` with the two trees): 25 of the 77 compile as they are (crypto 10
of 13, the network 5 of 16, the pictures 2 of 7, HTML 1 of 8, CSS 1
of 7, the engine 5 of 18, the language 1 of 7, a page's scripts 0 of
1); the refusals are those of "What it requires", item 1: optional
arguments first, then `a.{i}`, `for _`, a label through a function
value, polymorphic variants (`Svg`, `Js_regexp`), a local exception
(`Js_value`).

Stage 1 (2026-10-09): `browsers/coverage.sh` and `coverage.py`, the
table of what the article runs and the cuts proposed (above);
`survey.sh -files`. Run: the ten loads, twice (the second by the
script whole: the same numbers but `lib_networking/`'s with scripts,
598 for 561, a request more or less answered); the frames at 1000 and
1400 looked at, and the scrolled one. Not done: **the article saved**
(its licence is an open question, below, and a saved page needs its
addresses rewritten to be served by mini-httpd: stage 6 is where it
is first needed); the commits read one by one (their subjects and the
lines each added to each file, not their diffs); no cut tried, no
file being here.

Before: 2026-10-09: the survey (`browsers/survey.sh`) and this
plan; the aim and the budget said by the author, and scripts in a
page, which the plan first left out; and that the code is cut down,
not copied as it is, with mini-chrome's history as a guide. Run for it, and nothing else: mini-chrome's mini-curl,
mini-netscape and mini-chrome-software on the article, their frames
looked at; `survey.sh`, with `-ml` and `-net`.
