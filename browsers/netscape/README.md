# browsers/netscape: mini-netscape

Netscape Navigator's window over the engine
([`plan_browser.md`](../../docs/plans/plan_browser.md), stage 7): a
page fetched (`lib_networking`: ix's own TLS 1.3), read
(`browsers/html`), styled (`browsers/css`), laid out and drawn
(`browsers/engine`), in a window of the playground's
(`lib_playground`). Written for ix after the author's mini-chrome's
first window and tab (`~/github/mini-chrome`, `475a979`:
`src/main/MiniChrome.ml`, `src/chrome/Browser_tab.ml`, 1,104 lines
there): two files then, 369 lines of `.ml`; five today, 1,142.

    mini-netscape [url=address]

- `Tab`: a page looked at and the pages before it. `go` asks for a
  page and returns; `step` fetches it, a piece a call: the page and
  its style sheets one after the other (and their `@import`s), laid
  out and shown, then a picture a call. No threads, nothing on its
  way (the plan's decision 6): the window is still during a piece and
  says between two what is being done. http://, https://, file:// or
  a path, data:, about:home.
  A page's scripts run (`browsers/webapi`): their files fetched a
  piece each, then all run; a click is theirs first; a request they
  make (XMLHttpRequest, fetch) is answered by a later piece; their
  timers go by the frame's clock. `scripts=off` on the command line:
  none run; `console=on`: what they print, on the standard error.
- `Netscape`: the window: the grey toolbar (Back, Forward, Reload),
  the Location field, the N (white while a page is on its way), the
  page, the status bar (the link under the mouse, or what the load
  says: "Loading https://... ...", "Loading pictures: 3 of 19"). A
  click follows a link, gives a field the keys, sends a form; the
  wheel, the arrows, Page Up and Down, Space, Home and End scroll;
  Backspace goes back. The cursor is a hand over a link or a button,
  an I-beam over a field (SDL's window; not on Plan 9 yet). Ctrl and
  `+` (or `=`), Ctrl and `-`, Ctrl and the wheel zoom the page, Ctrl
  and `0` back to 100%.
- `Browser_zoom`: mini-chrome's (its `8af888e`), copied: Chrome's
  steps (25% to 500%), each site its own zoom, as long as the program
  runs. The whole page grows: laid out at the window's width divided
  by the zoom (`Tab.resized`), drawn scaled; the zoom is said at the
  right of the status bar.

Built by dune twice: here with the platform that writes a frame to a
file (the tests'), in `sdl/` with a window (`bin/mini-netscape`).

## Since the first version (2026-10-11)

- **The network**: an `https://` connection is kept for the next file
  from its host (`Keep_alive`, mini-chrome's; `keep=off` for a
  connection each) and gzip is asked for (`Zlib.gunzip`). The
  Wikipedia article with its scripts, 250 frames: 20.9 s with
  `keep=off`, 15.2 s kept (12.3 s of it the processor's, 9 of those
  the scripts'); without scripts 9.2 s and 5.0 s.
- **Cookies** (`Cookie`, `Cookie_jar`, mini-chrome's, in
  `lib_networking/http`): said back by each request, kept from each
  answer, read by a page's `document.cookie`.
- **The profile** (`Browser_profile`, ix's own): a directory,
  `~/.config/mini-netscape` (`profile=DIR`, `profile=off`), with
  `cookies.txt` in Netscape's own format (those with a date) and
  `preferences` (the window's size, the sites zoomed); read with
  `Cap.open_in`, written with `Cap.open_out`, found with `Cap.env`.
- **The clock**: a page's `Date` starts at the frame's time (the
  system's in a window, the fixed one in the tests).
- **Letters with accents**, quotes, dashes and some signs
  (`Glyph_unicode`, mini-chrome's, in `browsers/engine`).
- **The window's size**: the page is as wide as the window
  (`lib_playground`'s flag `window=WxH`, asked for by the program).
- **History, bookmarks, tabs** (2026-10-19; the author: "let's add a
  few Chrome and feature to mini-netscape like the omnibox, saved
  history, etc."; bookmarks "as fundamental and classic as the back
  button"). `Places` (ix's own): the pages seen, in the profile's
  `history`, and the bookmarks, in its `bookmarks.html` in Netscape's
  format (Firefox's and Chrome's export) -- Ctrl+D, and the toolbar's
  Bookmarks button shows the file, `about:bookmarks`; `about:history`.
  The Location field offers, as one types, the pages whose address or
  title has the text (the arrows or a click take one), and words are
  searched (DuckDuckGo's page without scripts: Netscape 4's Internet
  Keywords, Chrome's Omnibox). Tabs: Ctrl+T, Ctrl+W, Ctrl+Tab, Ctrl
  and a click for a link behind; the strip under the toolbar when
  there are two (Mozilla's); a tab not shown waits. mini-chrome's
  `Omnibox`, `Bookmarks` and `Window_tabs` are not copied (their text
  field and tab bar are libs/gui's).

- **-v** (2026-10-19, as mini-chrome's): on the standard error, the
  profile's files read and written, each address fetched and what came
  (its status, type and size), `~/.mailcap`, the helper programs run
  and the files given to them (`Logs.info`; `-v` and `-debug` are the
  playground's `Session`'s, the reporter `Logging.setup`).

## Speed (2026-10-11)

Where a load's time went was measured before anything was changed,
and it was not in the scripts (1.2 s of the article's 13): the plan's
account has the table. Four switches, each off giving the simple way
back and the same picture (`tests/perf.sh` runs them):

| flag | what is done when it is not said |
|---|---|
| `keep=off` | an `https://` connection is kept for the next request (`Keep_alive`) |
| `settle=off` | the layout a script's change asks for is owed, and made once (`Tab.settle`) |
| `draw=all` | a line's shapes are built when a frame first shows it (`Browser_draw.later`) |
| `view=each` | the frame's shapes are given back when nothing they read changed (`Netscape.view`) |

The Wikipedia article with its scripts: 16.1 s to 5.9; by mini-ml's
code 16.6 s.

## Not yet

- **Pictures as they come**: a page's pictures (PNG, JPEG, GIF, SVG;
  its `<img>`s and its boxes' backgrounds) are fetched one after the
  other, a connection each, the status bar counting them; the page is
  shown without them meanwhile and laid out again once, after the
  last. A GIF is its first frame.
- **Helper programs** (`Browser_helpers`, Mosaic's and Netscape's
  helper applications; 2026-10-19, in the place of `Pdf_viewer`): what
  the browser does not show is given to a program beside it. A link to
  a film of YouTube's, clicked, goes to `mpv` (the address: mpv plays
  it by yt-dlp), the page staying; a PDF file arrived goes to
  `mini-page` (ix's `page`: `apps/page`), written to a file first; a
  type of `~/.mailcap`'s (`video/mp4; mpv %s`) to its program. The
  profile's `preferences` add theirs, before those (`helper
  youtube.com/watch mpv %u`, `helper application/pdf gv %s`). A rule
  whose program is not on the PATH is left out: on ix without mpv, a
  link to YouTube is followed. `helpers=off`: none (the frames' tests).
  `tests/helpers.sh`: fake programs on the PATH say what they were given.
- A page shown while its scripts run (a long run stops the window:
  mini-chrome's `Js_slice` is not taken); bookmarks' folders, a
  bookmark removed but in an editor; a text field's caret and
  selection in the Location field; an answer's cache (mini-chrome's `Http_cache`); Brotli and Zstandard
  (gzip alone is asked for).
- A file given by a relative path keeps it (`file://browsers/...`): a
  link of its page that starts with `/` goes wrong.
- Greek, Cyrillic and every other script are `?` (`Glyph_unicode` has
  Latin's letters with their marks).
- The window's size on Plan 9's platforms (the flag `window` is SDL's
  and the file's).

## Tests

`tests/frames.sh`: nine sessions on the pages of `tests/pages/` (files,
no network), each its last frame's sum (`frames.expected`): the first
page, a page with its sheet, a link clicked, Back, an address typed and
Enter, a form filled and sent, a `#fragment`, Backspace and Page Down,
a file that is not there. The frames were looked at when recorded
(2026-10-09).

By hand, 2026-10-09, without a window (`-dump-frame`):
`url=https://en.wikipedia.org/wiki/OCaml`, two arrows down: the article
reads (its title, the text and its links, the box at the right), 2.8 s
with the network (the page's 354 KB and its two sheets, three TLS
handshakes). With a window (SDL): started under SDL's dummy driver,
not seen on a screen.
