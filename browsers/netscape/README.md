# browsers/netscape: mini-netscape

Netscape Navigator's window over the engine
([`plan_browser.md`](../../docs/plans/plan_browser.md), stage 7): a
page fetched (`lib_networking`: ix's own TLS 1.3), read
(`browsers/html`), styled (`browsers/css`), laid out and drawn
(`browsers/engine`), in a window of the playground's
(`lib_playground`). Written for ix after the author's mini-chrome's
first window and tab (`~/github/mini-chrome`, `475a979`:
`src/main/MiniChrome.ml`, `src/chrome/Browser_tab.ml`, 1,104 lines
there): two files, 369 lines of `.ml`.

    mini-netscape [url=address]

- `Tab`: a page looked at and the pages before it. `go` asks for a
  page and returns; `step` fetches it, a piece a call: the page and
  its style sheets one after the other (and their `@import`s), laid
  out and shown, then a picture a call. No threads, nothing on its
  way (the plan's decision 6): the window is still during a piece and
  says between two what is being done. http://, https://, file:// or
  a path, data:, about:home.
- `Netscape`: the window: the grey toolbar (Back, Forward, Reload),
  the Location field, the N (white while a page is on its way), the
  page, the status bar (the link under the mouse, or what the load
  says: "Loading https://... ...", "Loading pictures: 3 of 19"). A
  click follows a link, gives a field the keys, sends a form; the
  wheel, the arrows, Page Up and Down, Space, Home and End scroll;
  Backspace goes back. The cursor is a hand over a link or a button,
  an I-beam over a field (SDL's window; not on Plan 9 yet).

Built by dune twice: here with the platform that writes a frame to a
file (the tests'), in `sdl/` with a window (`bin/mini-netscape`).

## Not yet

- **Pictures as they come**: a page's pictures (PNG, JPEG, GIF, SVG;
  its `<img>`s and its boxes' backgrounds) are fetched one after the
  other, a connection each, the status bar counting them; the page is
  shown without them meanwhile and laid out again once, after the
  last. A GIF is its first frame. A PDF file is shown (`Pdf_viewer`, mini-chrome's: `plan_pdf.md`,
  stage F): its pages are pictures drawn as they come into view.
- **Scripts** (stage 9), cookies, a connection kept, gzip.
- **The window's size**: the page is as wide as the playground's
  screen, 1,000 units, scaled into the window (the plan's "What it
  requires", 4).
- **By mini-mk**: mini-ml compiles the two files; the program is not
  linked by it yet (the playground's and lib_graphics's units to name,
  as `games/mkgames` does, while lib_graphics's folders are being
  moved), so there is no mini-netscape for mini-9pi nor run by
  mini-ml's code.
- A file given by a relative path keeps it (`file://browsers/...`): a
  link of its page that starts with `/` goes wrong.
- A letter with an accent is `?`, the article's three columns are one
  (the plan's table of what is added back).

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
