# browsers: mini-netscape, mini-lynx, and what they stand on

A browser for ix ([`plan_browser.md`](../docs/plans/plan_browser.md)):
Netscape Navigator's window over an engine copied and adapted from
the author's mini-chrome (`~/github/mini-chrome`), with ix's own
network and TLS 1.3 under it. Everything here builds twice: by dune
with OCaml 4.14, and by mini-mk with ix's own mini-ml.

    make                                         # dune: bin/mini-netscape, mini-lynx, mini-node
    bin/mini-netscape url=https://en.wikipedia.org/wiki/OCaml
    bin/mini-lynx https://news.ycombinator.com
    bin/mini-node browsers/javascript/tests/scripts/errors.js

    (cd browsers/netscape && NPROC=32 mini-mk)   # the same by mini-ml: _mk/7/browsers/netscape/mini-netscape

Each directory has its own README (what was copied, what changed,
what remains); this one is the map, and where mini-netscape stands
against mini-chrome.

## A page's way

    address ──► lib_networking ──► html ──► css ──► engine ──► lib_playground
                (DNS, TCP, TLS,    (Dom)    (styles) (boxes,     (a window: SDL,
                 HTTP, cookies)       │                shapes)     or a frame in a file)
                                      ▼
                              javascript + webapi
                              (the page's scripts change the Dom:
                               styled and laid out again)

| directory | what | lines of `.ml` |
|---|---|---:|
| [`html/`](html/README.md) | HTML read into a tree (`Dom`), the entities, the DTD's rules | 1,192 |
| [`css/`](css/README.md) | style sheets read, selectors matched, the cascade, each element's computed style | 2,283 |
| [`engine/`](engine/README.md) | the boxes laid out (blocks, inlines, floats, flex, grid, tables), drawn as the playground's shapes, letters as pen strokes | 4,044 |
| [`javascript/`](javascript/README.md) | the language: parser, evaluator, values, the standard objects; `mini-node` | 7,676 |
| [`webapi/`](webapi/README.md) | what a page's script sees: `document`, elements, events, timers, `fetch`, `XMLHttpRequest`, modules, `localStorage` | 3,740 |
| [`netscape/`](netscape/README.md) | the window, the tab, the profile, the zoom, the helper programs (mpv, mini-page) | 1,142 |
| [`lynx/`](lynx/README.md) | a page as text in a terminal | 162 |

Outside: `lib_networking/` (DNS, TLS 1.3, HTTP, `Keep_alive`,
`Cookie_jar`), `lib_crypto/`, `lib_compression/` (inflate, gzip),
`lib_graphics/` (PNG, JPEG, GIF, SVG, PDF, Hershey's letters),
`lib_playground/` (the program's model, view and update; its
platforms), and `networking/` (`mini-curl`, `mini-httpd`).

Which version of mini-chrome each part is: `html/`, `css/` and
`engine/` are **its first version** (`475a979`, 2026-09-30, the
playground's TinyChrome moved), with the grid of two days later; `javascript/` and `webapi/` are **its
tree of 2026-10-10**, rewritten to what mini-ml takes (no optional
argument, no `Lazy.t`, no mutex).

## mini-netscape

    mini-netscape [url=address] [scripts=off] [console=on] [strict=on] [profile=dir|off] [window=WxH]
                  [keep=off] [settle=off] [draw=all] [view=each]

An address is `http://`, `https://`, `file://`, a path, `data:` or
`about:home`. `strict=on`: a page's script that does not parse is
refused whole and a DOM method this browser lacks throws, as before
`plan_browser.md`'s C; by default both are passed over, with a
warning in the console. The second line's flags turn an optimization off, each
giving the simple way back and the same picture
([`netscape/README.md`](netscape/README.md), "Speed").

- **The window**: Back, Forward, Reload, the Location field, the N,
  the status bar. A click follows a link or gives a field the keys;
  the wheel, the arrows, Page Up and Down, Space, Home and End scroll;
  Backspace goes back; Ctrl with `+`, `-`, `0` or the wheel zooms, a
  site at a time.
- **The profile**, `~/.config/mini-netscape`: `cookies.txt` (Netscape's
  own format) and `preferences` (the window's size, the sites zoomed),
  read and written through capabilities.
- **No threads**: a load is pieces, one a frame (`Tab.step`): the
  page, its sheets, its scripts' files, then a picture a piece. The
  window is still during a piece.
- **Without a window**, for the tests and for a look:
  `_build/default/browsers/netscape/Netscape.exe -dump-frame 250 out.ppm -fixed-time 1000 url=... profile=off`.

The live Wikipedia OCaml article with its scripts, 250 frames: 5.9 s
by dune's build, 16.6 s by mini-ml's (2026-10-11).

## Tests and tools

| what | where |
|---|---|
| the window's sessions, 27, each its last frame's sum, on both builds | `netscape/tests/frames.sh [dir]` |
| the profile and cookies against a small server | `netscape/tests/profile.sh` |
| a load's time, each switch off in turn; `-callgrind` for a profile | `netscape/tests/perf.sh` |
| a terminal session | `lynx/tests/session.sh` |
| unit tests (Testo, dune's only) | `dune test browsers/css browsers/html browsers/engine browsers/webapi browsers/javascript` |
| mini-ml takes every file | `languages/ml/tests/compile_ix.sh browsers` |

The numbers behind the plan: `survey.sh` (what each of mini-chrome's
programs stands on, what mini-ml says of each file, a file's history),
`coverage.sh` and `coverage.py` (what of mini-chrome a Wikipedia
article runs), `first_version.sh` (mini-chrome's first commit built
and run).

## The gaps with mini-chrome (2026-10-11)

From the two trees side by side (ix at `99fddcc`, mini-chrome's
working tree over its `8af888e`) and the plan's notes; the two were
not run on the same sites. mini-chrome is the ceiling, not the aim:
the author asked for "only what is truly essential", so some of this
list is a choice.

The language and the web API are level. The gaps, by what a reader of
a page sees first:

**Layout and CSS**

- The grid is here since this list was first written (mini-chrome's
  first, its `add433e`: the Wikipedia article's three columns), not
  what it gained since: an item between lines, `span`, `grid-row` and
  `grid-column`, `repeat(auto-fill)`.
- The site-driven fixes of mini-chrome's eight days after its first
  commit are not here: z-index, an animation's end, a negative
  padding, and what LWN, Gmail, GitHub and YouTube asked for. (The
  two layouts were the same size before the grid, 2,350 lines: the gap is what the
  lines do, not their number.)
- The cascade has no index of its rules (mini-chrome's `Cascade.key`):
  styles are 0.15 s a layout on the article.
- `html/` and `css/` are the first versions too (1,192 and 2,178
  lines; 1,408 and 2,548 there).

**The browser around the page**

- One tab. No tabs, omnibox, menus, bookmarks, history kept, or
  back-forward cache (`Window_tabs`, `Omnibox`, `Bookmarks`, `Places`,
  `Bfcache`).
- No cache of answers (`Browser_cache`), no developer tools, no pages
  for the memory and the processor, no replay.
- No toolkit (`libs/gui`: scrollbar, clipboard, field, menu):
  mini-netscape draws its own toolbar and field, and has no scrollbar.
- A page is not shown while its sheets and scripts come, and the
  window is still while a long script runs (mini-chrome's `Tab_jobs`,
  `Window_update`, `Js_slice`).

**The network**

- Requests one at a time, about 2.5 s of waits a load of the article;
  mini-chrome asks for several at once, with workers and domains,
  which mini-ml has not.
- No Brotli or Zstandard (gzip alone), no WebSocket, a plain `http://`
  connection not kept.
- Three TLS handshakes a load, their arithmetic at the top of the
  profile (`Bignum.redc_mul`).

**Pictures, sound, letters**

- No audio or video (Ogg, Vorbis, Opus; `src/viewers/Media`), no WebP
  or ICO; a GIF is its first frame.
- Letters are pen strokes (Hershey's) only; mini-chrome also has
  outline fonts (TrueType, CFF, Type 1) and `Glyph_picture` (how much
  of it a page's text uses, against a PDF's, was not looked at).
- Latin with its accents; Greek, Cyrillic and the other scripts are
  `?`.

**Smaller**

- `Object.prototype.toString.call(e)` of an error is its text, not
  `[object Error]`.
- mini-chrome's own pages (`src/about`, `src/www`) but `about:home`.
- Under mini-9pi: stage 10, paused (the load takes 542 MB by mini-ml's
  build; a process there has 352).

What would be next, by what it gives for its lines: several requests
at once and a page shown while it loads, which both want a design
without threads.
