# Plan: tiny-browser: `www`, tiny-kernel's browser, that reads Wikipedia with its pictures, under 2,000 lines

The author (2026-10-15): "is it doable to have a tiny-browser?",
"running on the tiny-machine"; then: "The ideal target would be to be
able to read some wikipedia pages, and to render them in a not too bad
way, while still having a browser in less than 2000 LOC, and the https
and TLS part handle by TinyMachinePeer or something". Of this plan's
first version: "we can extend slot to be bigger, why not 10MB?
machines nowadays have plenty of memory. www is fine. pictures are
definitely worth it! That's what made mosaic and the web popular
compared to text-only protocols (e.g., gopher)"; "but let's call it
TinyBrowser.ml, not TinyAppBrowser.ml, because a Browser is really an
essential part of an OS nowadays"; "and principia-softwarica level
worth a book".

**Done (2026-10-16)**: steps 0 to 7, in eleven commits (382c451e,
fb689e46, cbc0b9cc, c381724b, 650a4ce0, 3b5644d2, c979f7be, e077d5f2,
122907e7, df446928, 539519f2), and tiny-prof (bfe2320c), made to find
where the scrolling's time went. `www OCaml` on tiny-kernel, on the
screen or in a window of tiny-windows, shows Wikipedia's article with
its links and pictures, and scrolls by the wheel. The browser is 1,495
lines (`TinyBrowser.ml` and its `.mli`) and `user/www.ml` 17, under the
2,000 wanted. Step 8, the wire faster, was not done: the author found
the speed "fast enough for me right now". What differs from the
sections below is said in section 12, step by step; what was not done
is in "Left".

As first written, a plan from reading (`tiny/`, `browsers/`,
plan_tiny_network.md, plan_browser.md) and from measuring Wikipedia
(2026-10-15, below). The line counts of what exists are `wc -l`; those
of what is planned are guesses; the times are reckoned from
plan_tiny_network.md's measures, not run.

## 1. The demo

In tiny-kernel, in a window of `windows` or on the whole screen:

    $ www OCaml

- **The article's lead is on the screen in a few seconds**, its title,
  its first paragraphs, the infobox's lines, and the rest of the
  article comes in under it while one reads, as a page did over a
  modem: the machine shows what it has as soon as it has laid it out.
- **Then its pictures fill their places**: the OCaml logo in the
  infobox, the photograph of the POPL 2024 award, the small icons,
  each painted a row at a time into the box kept for it, as `wiki`'s
  Glenda is. The text does not move when they come.
- **A link is blue and underlined; a click on it follows it**: OCaml,
  then ML, then Robin Milner. `b` (or Backspace) goes back; `g` asks
  for an address. Space and `-` page down and up, the wheel and the
  arrows scroll.
- **It is the article, not a summary**: the sections, the lists, the
  code in its boxes, the tables, the references at the end; Wikipedia's
  page as Wikipedia sends it, read by the machine.
- **With the other two**: in a window of tiny-windows, the browser
  beside a shell, the graphics, the windows and the network at once
  (as `wiki` is).

The pictures are the point, not a finish: Gopher (1991) had links and
documents and a menu a screen; what Mosaic (1993) added was `<img>`,
the picture in the page among its words, and it was Mosaic that
people took up. A browser that shows text only is Gopher with tags.

The name: `www` was the first browser's command after Tim
Berners-Lee's own, CERN's line-mode browser (Nicola Pellow, 1991).
The file is `tiny/TinyBrowser.ml`, not a `TinyAppXxx`: a browser is
today a part of the system as the shell and the window system are,
and it sits with them (`TinyShell`, `TinyWindows`), not with `calc`
and `tetris`.

**A book's worth**: as the kernel and the window system, the browser
is one of the programs that a book of the system (principia
softwarica's kind) would give a volume. So its code is written to be
read in order, its parts the chapters of section 5, each a stage of
the page's way (section 4), and its comments say why; a literate book
(`.nw`) made from it is later work, not this plan's.

**What is honest to say on the page** (as `wiki`'s): the machine does
not speak TLS and does not decode JPEG or PNG. The other end of its
wire is a gateway that does the Internet's encrypted half (names,
TLS, HTTP/1.1's chunks, gzip, redirections), hands the page's bytes
over unchanged, and gives a picture as its pixels in the machine's
256 colours at the size the page asks; everything from the first `<`
on is the machine's: reading the HTML, the layout, where the pictures
go, the drawing, the links.

## 2. What Wikipedia sends

`OCaml`, 2026-10-15, by curl:

| what | bytes | CORS (a page may fetch it) |
|---|---:|---|
| `https://en.wikipedia.org/wiki/OCaml` (the page with its skin) | 354,260 | no |
| `.../w/index.php?title=OCaml&action=render` (the article alone) | 271,277 | no |
| `.../api/rest_v1/page/html/OCaml` (Parsoid's HTML, the article alone) | 257,035 | **yes** (`*`) |
| `Plan_9_from_Bell_Labs`, with its skin | 592,918 | no |
| the award's photograph, `thumb.wikimedia.org/...250px-Award_for_OCaml_at_POPL_2024.jpg` | 15,513 (JPEG) | **yes** (`*`) |

In the REST HTML of OCaml:

- **34 KB of it is text** (outside tags, scripts and styles). The
  tags' attributes are 188 KB; Parsoid's `data-mw` alone 34 KB.
  Keeping only `href`, `class` and the spans would leave 135 KB; only
  `href` and the spans, 105 KB. Stripping on the peer would halve the
  bytes, not divide them by seven.
- **2,962 tags**: `span` 1,377 (most of them the code's colours),
  `a` 626, `li` 236, `link` 88, `div` 79, `p` 65, `i` 57, `sup` 52 (the
  references' `[1]`), `tr` 43, `td` 40, `pre` 35, `section` 28, `h3`
  18, `img` 14, `table` 9, `h2` 9. No `<script>`; 13 `<style>` (small,
  the templates').
- **14 pictures, 61,023 pixels as shown** (each `<img>` has its
  `width` and `height`): the photograph 250 by 188, the logo 121 by
  33 and 110 by 30, a 50 by 39, two 40 by 40, the rest icons of 10 to
  16. Their files are thumbnails already at about that size (the
  `250px-` in the address), PNG for the drawings (Wikipedia renders
  its SVGs), JPEG for the photographs.
- **160 characters outside ASCII** (dashes, quotes, accents): the
  machine's font has 128.
- **Its links are relative to `<base href="//en.wikipedia.org/wiki/">`**:
  `./ML_(programming_language)`; its pictures' addresses start with
  `//`.

So the REST HTML is the one to read: the article without the skin's
navigation (the sidebars, the menus, which without CSS would come
first and fill two screens), the one a page may fetch, and smaller.
Wikipedia is written to be read without its style sheets
(plan_browser.md: "None of the 🟢 ones needs them to be read"), so a
browser with no CSS shows it near what it means.

## 3. Who does what: the machine and the peer

      in the machine (tiny-ml, in tiny-kernel)          the host

      www, a program (TinyBrowser.ml)
          | dial 10.0.0.1 70, the line "www <address>"
          |   or "img <width> <height> <address>"
          | messages: the page's bytes, or a picture's rows
      tiny-kernel, IL ===================== wire ===== TinyMachinePeer.ml
                                                        | [document] the line
                                                        |
                                    in a terminal:  tiny-machine-fetch, a program beside
                                                    (as -net-out runs tiny-machine-socket)
                                    in the page:    the browser's fetch() and a canvas
                                    in the tests:   a file of tiny/tests/www/

The peer already answers port 70 by a line and a document
(`get`, `wiki`); two more kinds of lines are all the wire needs. On
the host, what the peer does with them:

- **`www <address>`**: the page's bytes, unchanged, a message at a
  time (`TinyMachinePeer.messages`), then the connection closed; an
  error is one line of text, shown as the page.
  - `https://en.wikipedia.org/wiki/X` is asked as
    `https://en.wikipedia.org/api/rest_v1/page/html/X`: the one
    rewriting of an address, said in the peer's comment. The page
    needs it (CORS); the terminal does it too so the two show the same.
  - Any other `https://` or `http://` address is fetched as it is,
    redirections followed, gzip and chunks undone.
- **`img <width> <height> <address>`**: the picture decoded, scaled to
  width by height, reduced to the machine's 256 colours (the palette
  `wiki`'s pictures are in), and sent as `wiki`'s are
  (`TinyMachinePeer.picture`): a row a message.
- **In a terminal, by `tiny-machine-fetch`** (`TinyMachine/TinyMachineFetch.ml`,
  new, about 120 lines): a program beside tiny-machine, as `-net-out`
  runs `tiny-machine-socket`, which links what tiny-machine does not:
  lib_networking (DNS, ix's own TLS 1.3, HTTP) and lib_graphics (PNG,
  JPEG, GIF). `-net dir` alone (no `-net-out`): the address's kept
  file in `dir`, as `wiki`'s pictures are; so the tests and the CI,
  which have no Internet, read `tiny/tests/www/OCaml.html` and its
  pictures, kept as rows already.
- **In the page** (`TinyMachineWeb.ml`), by `fetch`, as `wiki` asks
  Wikipedia's API already; a picture drawn on a canvas at its size,
  its pixels read back and reduced as `wiki`'s are.

About 60 lines in `TinyMachine.ml`, 50 in `TinyMachineWeb.ml`, 20 in
`TinyMachinePeer.ml`, and `TinyMachineFetch.ml`. Not counted in the
browser's 2,000: they are the Internet's side of the wire.

**Not done, and why**:

- **TLS on the machine**: X25519, AES-GCM or ChaCha20, SHA-256,
  certificates' ECDSA and RSA, in tiny-ml at 8 million instructions a
  second: thousands of lines (lib_crypto and lib_networking's TLS are
  m-ix's) and, guessed, seconds of a handshake. The author's choice
  (above) is the peer's.
- **JPEG and PNG decoded on the machine**: PNG is inflate (Huffman,
  LZ77) and filters, JPEG a DCT; each hundreds of lines, as much as
  the browser's layout, and the machine's time. The pixels cost more
  on the wire than the files (the photograph: 47 KB of pixels, 15 KB
  of JPEG), about 4 s more for OCaml's pictures; worth the lines kept.
  The book can say what the gateway does there, as it says what TLS
  is.
- **The peer reducing the page** (attributes removed, the HTML made
  simpler): a half of the bytes (section 2), and the reading of HTML
  moved out of the browser, which is the browser. The page's bytes
  are the site's.
- **Plain `http://` straight through `-net-out`** (`get`'s way, port
  80): most of the web answers it by "moved" to `https://`; one path,
  the peer's, for all.

## 4. The idea kept

mini-netscape reads a page into a tree (`browsers/html/`, 1,192
lines), styles it by its sheets (`css/`, 2,283), lays the tree out
into boxes (`engine/`, 4,044), and runs its scripts (`javascript/`,
`webapi/`, 11,416). The tiny one keeps what Mosaic had (1993), and
what makes a page a page:

- **A page is read once, as it arrives, into lines**: the bytes into
  tokens (a tag, its attributes, a text), the tokens straight into the
  lines laid out on the screen. No tree is kept, no style sheet read:
  **a tag's meaning is a row of a table** (block or inline, its
  margins, bold, monospace, a list's bullet, hidden), and the few
  classes of Wikipedia's that change it (`mw-editsection` hidden,
  `infobox`, `reflist`, `navbox`) are rows too.
- **What is kept is what is drawn**: the lines, each a list of runs
  (a text, its column, its look, its link; or a picture's box). The
  HTML is not kept, so a page of 257 KB keeps about its 34 KB of text
  and the runs' records.
- **A picture is a box of the size the page says**, laid out as a
  word is (a 16 by 16 icon in its line of text, the photograph a
  block of its own with its caption under it), and filled when its
  pixels come. A line is as tall as its tallest run. Since `<img>`
  says its `width` and `height`, the box is known before the picture
  is: Netscape's trick (1994) over Mosaic, which waited for each
  picture to know where the words after it went.
- **The text first, the pictures after**: the page's connection read
  to its end, then a connection a picture, in the page's order, the
  ones on the screen first. The wire is the slow part (section 6),
  and the words are what one reads first.
- **A link is a rectangle on the screen with its address**: a click is
  a search of the visible lines. A picture in an `<a>` is a link.
- **The page is drawn as it is laid out**: a line drawn when it is
  complete, if it is on the screen; so the top of a page is shown
  while its bottom is still on the wire.

Tables are the one place where a line cannot be laid out before what
follows it is read: a table's columns are as wide as their widest
cell. A table is kept whole (its cells' runs), laid out at its `</table>`,
then given its lines.

        bytes ──► tokens ──► the tag's row ──► runs in a line ──► lines ──► the screen
        (IL's      (tag,       (block?           (words wrapped      (the        (the visible
        messages)  attrs,      bold? link?        at 80 columns,      page)       ones, drawn)
                   text)       hidden?)           pictures' boxes)                    ▲
                                                      │                               │
                                                    tables: cells kept,     pictures' rows, by
                                                    laid out at </table>    "img w h address",
                                                                            after the page

## 5. The browser's parts, and their lines

One file, `tiny/TinyBrowser.ml` (tiny-ml has no modules; the largest
tiny file is TinyML.ml, 1,607 lines), compiled by `tiny-ml -tm` with
`TinyLibDraw` and `TinyLibStd`, and by dune as a library for the
host's tests (as `TinyWindows`). Its parts in the order of a page's
way, which is the order of the file and of a book's chapters. Guessed:

| part | what | lines |
|---|---|---:|
| the connection | dial, the line, messages read as they come (`u_ready` with the mouse and the keys); a connection for the page, then one a picture | 80 |
| characters | UTF-8 to the font's 128 (a table of the common ones: `é` as `e`, `–` as `-`, `“` as `"`, the rest `?`); the entities (`&amp;`, `&#8211;`, the named ones Wikipedia uses) | 120 |
| tokens | a tokenizer that takes a message at a time and keeps its unfinished tail: tags, attributes, comments, `<style>` and `<script>` skipped whole | 250 |
| the tags' table | each tag's look; Wikipedia's classes; `p`, `li`, `td` closed when the next one opens; the `<head>` and `<link>` dropped | 150 |
| lines | inline runs wrapped into lines of 80 columns (fewer in a window), lines as tall as their tallest run, indentation for lists and blockquotes, `pre` kept as it is, headings, `hr`, margins between blocks | 320 |
| tables | the cells kept, columns' widths from their contents, a cell's text wrapped in its column, `colspan`; the infobox as a table of two columns at its place | 250 |
| pictures | `<img>`'s box (its size, at most the screen's width, scaled down then), a figure and its caption; the queue of pictures to ask for, the visible ones first; a picture's rows into an image of the kernel's (`d_image`, `d_pixels`), drawn from there when it scrolls back into view | 160 |
| drawing | the visible lines, a run its colour (links blue and underlined, headings bold by drawing twice a pixel apart, code on grey), the boxes of pictures not there yet, scrolling as copying the screen and drawing what is new | 160 |
| the user | the mouse on a link, the keys, the address asked, the status line ("reading 120 KB", "picture 3 of 14", the address under the mouse) | 150 |
| addresses | relative to the base or to the page, `//` and `#`, the history (back) | 80 |
| main | arguments, the loop: the wire, the keys, the mouse | 70 |
| **all** | | **1,790** |

So 200 lines are spare under the 2,000, for what the first Wikipedia
pages show is missing (step 7). If they are not enough, the first to
give up its place is the tables' (an infobox as lines of `key: value`).

## 6. What the machine allows, and what it must be given

- **Memory: a process has 1 MB today, its ML heap 256 KB a half.**
  tiny-kernel has 8 partitions of 1 MB (`TinyKernel.ml`: `part`,
  `nslots`, from `0x500000`); an ML program in one has its code below
  `0x60000`, its value stack there, and its heap's two halves of 256
  KB from `0x70000` (`libml/mlsys.c`: `HALF`). OCaml's page kept as
  lines (34 KB of text, some 6,000 runs of about 24 bytes, 150 KB),
  with what is made while it is read, does not fit in 256 KB. The
  author: "why not 10MB?". Ten MB for the browser, then, and the
  machine made bigger to hold it. What that costs, read in the code:
  - **Not 10 MB for every process.** fork copies the whole partition
    (`k_copy`, `entry.tm`: 6 instructions a word, the kernel's hottest
    loop) and exec zeroes it (`k_zero`, 5 a word): today 0.2 s and
    0.16 s of the machine's time for 1 MB; 10 MB slots would make
    every command the shell runs wait some 3.5 s. So **a process's
    size is its program's**: most ask 1 MB as now, `www` asks 10.
    A partition is the room a program asks for, found first-fit
    among the free memory at exec, kept by fork (the child the
    parent's size), given back at exit: OS/360's MVT (1967) and the
    PDP-11 Unix's before paging, which base and bound make easy (a
    window is anywhere). About 30 lines of `TinyKernel.ml` in place
    of `free_slot`, `base` and the size checks.
  - **How a program says its size**: a word at a known place of its
    image (where, in tiny-machine's raw image or in `.tm`'s link, to
    be found at step 0), which `mlsys.c` also reads for its `HALF`
    (the heap's halves as large as the partition allows), so the ML
    runtime is one for all programs. The same for C's programs (their
    stack's top).
  - **The machine from 16 MB to 128 MB** (`TinyMachineDevices.memsize`,
    `1 lsl 27`): the devices are at its top, so their addresses move
    (`0xfffff0` becomes `0x7fffff0`); `TinyMachineDevices` reckons
    them from `memsize` already, but tiny-kernel (`TinyKernel.ml`,
    `runtime.c`), the steps (`TinyKernel/steps/`), TinyLibDraw's and
    TinyKernel's headers and `docs/manuals/t-ix.md` name them as
    numbers (24 files mention such an address; most of them not for
    this). The screen at `0xf00000` can stay where it is. In the
    page, 128 MB of the browser's memory for the machine's (an
    `Uint8Array`): to be looked at on a phone. The images' arena
    (the kernel's, 2 MB from `0xd00000`, the font and the windows'
    images) grows too, for a page's pictures (OCaml's: 61 KB; a page
    of photographs, a few hundred).
  - **Recorded sessions and screens' sums** (`-events`, the tests'
    pictures) do not depend on the memory's size, but a kernel
    that says its partitions at boot (`tiny-kernel: ... 8 partitions of
    1024 KB`) changes its first line: the tests' expected outputs
    updated in the same commit.
- **The wire: about 11 KB a second** (plan_tiny_network.md: 240
  rows of 320 bytes in 6.9 s, the checksum 170 instructions a byte
  the most of it), half of that in a window. So OCaml's 257 KB take
  about 23 s on the screen, 45 s in a window; its lead (the first
  20 KB) 2 s and 4 s; its pictures, 61 KB, 6 s more. Hence the drawing
  as it comes, and the text before the pictures. What would make
  it faster is plan_tiny_network.md's "not done" (a string's byte read
  inline by tiny-ml, an acknowledgement every few messages), which is
  every program's gain; with pictures it is worth doing in this
  plan's time (step 8), measured before and after.
- **The reading**: the tokenizer touches each byte once, at, guessed,
  100 to 200 instructions a byte, about as the checksum: it doubles
  the wire's time rather than adding to it a wait at the end.
- **The screen**: 640 by 480, a byte a pixel; the font 8 by 16, 128
  characters (`TinyKernelGraphics.text`). So 80 columns and 30 lines,
  less the address's line and the status line: 28 lines of a page.
  One size of letters: a heading is bold, with a line under an `h2`
  as Wikipedia draws it. The photograph, 250 by 188, is 31 columns
  and 12 lines of it.
- **Waiting on several things**: `u_ready` (the keys, the mouse, the
  wire's descriptor) is there; **an ML `dial` is not**: C's `dial` is
  `libc/net.c`; ML needs an external in `calls.ml` and `mlsys.c`
  (about 10 lines).

## 7. How a Wikipedia article is shown

From the REST HTML's tags and classes (section 2), what each becomes:

- `<title>`: the address line. `<h1>`, `<h2>`, `<h3>`: bold, a blank
  line before, a rule under `h2`.
- `<p>`, `<div>`, `<section>`: blocks; `<br>`: a line ends.
- `<a href>`: blue, underlined, a link; `<a>` without `href`: text.
- `<b>`, `<strong>`, `<i>`, `<em>`, `<cite>`: bold (italic is not in
  one bitmap font: drawn in another colour).
- `<sup class="mw-ref reference">`: `[1]` kept inline, a link to
  `#cite_note-1` (followed: the page scrolled to the reference).
- `<ul>`, `<ol>`, `<li>`: indented, `*` or the number.
- `<pre>`, `<code>`: monospace is all there is: `pre` keeps its
  spaces and lines, on grey; its many `<span>`s of colours are
  ignored (or, spare lines permitting, `class="k"` as keywords' colour).
- `<img>`: a box of its `width` and `height`, filled when its rows
  come; wider than the column, scaled down (the peer is asked for that
  size). `<figure>` (Parsoid's thumbnails, `typeof="mw:File/Thumb"`):
  a block, the picture then its `<figcaption>`. An icon (both sides
  under 24) in its line of text.
- `<table class="infobox">`: at its place (before the lead), two
  columns, as wide as 80 allows, its logo at its top; other tables the
  same way, a table too wide cut at the screen's right edge.
- Hidden: `<style>`, `<script>`, `<link>`, `<meta>`, `<head>`'s rest,
  `class="mw-editsection"`, `navbox`, `noprint`, `style="display:none"`.
- `<span typeof="mw:...">`, Parsoid's other markers: their text only.

"Not too bad" here means: read top to bottom, the article reads as
it does in lynx (`bin/mini-lynx`, the twin to compare with) for its
words, with bold, colours, links that work, the infobox and tables in
columns, and its pictures where Wikipedia puts them in its column
(not floated to the right, a line of text beside: section 11).

## 8. Steps

Each stands alone, with its tests, and is a commit.

0. **Measure, and find where a program says its size.** An ML program
   of tiny-kernel that keeps 6,000 records of a run's shape and 34 KB
   of strings: what heap it needs, and what a collection costs. A
   tokenizer's loop over 257 KB on tiny-cpu: instructions a byte.
   Where in an image a word for its size can go. The numbers in
   section 6 replaced.
1. **The machine of 128 MB, and partitions of a program's size.**
   `memsize`, the devices' addresses in the kernel and the steps, the
   manual; tiny-kernel's partitions first-fit, fork and exit with
   them, `mlsys.c`'s heap from the size. All of `make test`'s
   tiny-machine tests the same (but the boot's line), tetris and
   tiny-windows included; the page checked by hand.
2. **The reading, on the host.** `TinyBrowser.ml`'s tokens, the
   tags' table, the lines and the tables, built by dune, tested on
   `tiny/tests/www/OCaml.html` (the REST HTML, kept) and on small
   pages of our own (each tag; a table; UTF-8; a tag cut between two
   messages, every place it can be cut). Output: the lines as text,
   compared with an expected file (`tests/TinyBrowser_tests/`), and
   by eye with `mini-lynx`.
3. **The peer's `www`.** The line, the kept files (`-net dir`),
   `tiny-machine-fetch` with `-net-out`, the page's fetch; tested by
   `get`'s way (`tests/TinyMachine_test.sh`): `www OCaml` read by a
   program that prints the bytes.
4. **On tiny-kernel, on the screen.** The ML `dial`; the program
   compiled by tiny-ml, reading from the wire and drawing as it comes,
   scrolling; `-screen`'s picture compared in the tests, as tetris's.
   The pace measured: when the lead is shown, when the page is all
   there.
5. **Links and back.** The mouse, the history, `g` and an address;
   `#` in the page. Tested by a session replayed (`-events`).
6. **Pictures.** The peer's `img` (tiny-machine-fetch decoding,
   the page's canvas, the kept pictures of the tests); the boxes in
   the layout, the queue, the kernel's images, scrolling over them.
   Tested by `-screen` on OCaml's kept page and its 14 pictures.
7. **In a window, and in the page; what Wikipedia shows is missing.**
   In tiny-windows (its descriptors as tetris has them); in
   `t-ix.html`, `www OCaml` in "What to try", checked by hand in
   Firefox and by `TinyMachineWeb_test.py`. Ten articles read (OCaml,
   Plan 9 from Bell Labs, Unix, Alan Turing, Paris, ...), what looks
   wrong listed, the spare lines spent on the worst.
8. **The wire faster.** plan_tiny_network.md's "not done", measured
   by `www OCaml`'s time to its last picture before and after.

## 9. Tests

- `tiny/tests/TinyBrowser_test.sh`, in `make test`: the host's
  library on kept pages (step 2); tiny-machine with `-net
  tiny/tests/www` and `-screen` (steps 4 to 6). No Internet.
- `tiny/tests/www/OCaml.html` and its pictures kept, with their
  date; the other kept pages small. A script to fetch them again, not
  run by the tests.
- By hand: `tiny-machine -window -net tiny/tests/www -net-out tiny-kernel`,
  then `www Plan_9_from_Bell_Labs`.

## 10. Open questions for the author

- **The address rewriting for Wikipedia** (`/wiki/X` to the REST
  API): on the peer (one place, said in its comment) as planned, or
  in the browser (the machine says what it asks for)? The page needs
  CORS either way.
- **128 MB for the machine**, or 64? 10 MB for `www`, a few windows
  of 1 MB, the kernel and the screen fit in 64; 128 leaves room for
  a second browser or a bigger page. The page's memory is the one
  cost (section 6).

## 11. Not in this plan

CSS; JavaScript; forms (Wikipedia's search: `g` and a title is the
search); cookies; pictures floated to the right with text beside them
(Netscape's `align`); animated GIFs; more than one font size; the
book itself.

## Left

What the steps wanted and did not reach, or met on their way (each is
in section 12 where it was found):

- **Step 8, the wire faster**: not done. OCaml's page takes 54 to 57 s
  of the machine's time on the screen and about 93 s in a window, most
  of it the wire's checksum and the reading, each over a hundred
  instructions a byte. plan_tiny_network.md's "Left" has the
  candidates (an acknowledgement every few messages; tiny-ml's code for
  a loop over a string's bytes, measured again since cbc0b9cc). If it
  is done, tiny-prof first, and a general cause rather than one
  function moved to C or assembly.
- **Not checked**:
  - the page (`t-ix.html`), in Firefox or by `TinyMachineWeb_test.py`,
    which needs Python's `websockets`;
  - tiny-machine's own window (`TinyMachineSDL.ml`) seen running: the
    wheel, the trackpad and the hand over links were checked by a
    temporary trace only;
  - mini-mk's build in `tiny/`: tiny-prof is in no mkfile.
- **What pages show wrong**: tables wider than the screen are cut at
  its edge (Paris's climate); Cyrillic, IPA and Thai are `?`; a
  picture the peer could not get stays an empty box with its text.
- **The kept pages**: no script fetches `tiny/tests/www` again
  (section 9 wanted one); they are 2026-10-15's.
- **Memory**: the kernel's unused megabytes below 16 MB could be its
  images' (the paint session's change that seemed to say otherwise
  was its ball's timing).

## 12. Status

### Step 2, the reading (2026-10-15)

`tiny/TinyBrowser.ml` is 671 lines, 529 of them code. It covers the
characters, the tokens, the table of tags, the lines and the tables;
section 5 had guessed 1,090 lines for these parts.

The test is `tiny/tests/TinyBrowser_test.sh`, in `make test`. It reads
`tags.html` and `table.html` at 40 columns and `www/OCaml.html` at 80,
and compares their lines with the expected ones. It reads each page
again in messages of 1, 7 and 1,000 bytes and checks that the lines are
the same. Finally it builds the browser with tiny-ml -tm, runs the
three pages on tiny-cpu, and checks that the lines are the same as
OCaml's.

What we found:

- **Reading as the page arrives.** When a message ends in the middle of
  a tag, an entity or a UTF-8 character, the reader keeps that end for
  the next message. A text is also cut only after a space: the first
  version cut texts anywhere, so a word could become two words and its
  line wrapped differently (the messages of 1,024 bytes showed it).
- **The OCaml article reads well**: 732 lines with the hatnote, the
  infobox in two columns, the lead, the sections with a rule under
  their headings, the code as it is, and the 37 numbered references.
  Its pictures show as `[picture]` until step 6.
- **Memory: the OCaml article fits in heap halves of 360 KB**, inside
  tiny-cpu's 1 MB (`TinyBrowser_tests/heap.c`). So the text of a page
  fits even in today's 1 MB partition. Pictures will be kept as the
  kernel's images, not in the heap.
- **Time: reading the OCaml article (257 KB) takes 447 million
  instructions on tiny-cpu**, about 1,700 per byte, where section 6
  guessed 100 to 200. At tiny-machine's 8 million instructions a second
  that is 56 s, while the wire needs 23 s. We measured it with a
  throwaway profiler (tiny-cpu counting instructions by address, the
  addresses mapped to functions from the `.tm` files). The first version
  took 1.1 billion: tiny-ml's `String.concat` (in TinyLibStd) appends
  each string to everything before it, and `dump` joined the 732 lines
  that way, as `ascii` joined its pieces. The browser now uses `join`,
  which concatenates two by two. Looking a tag up only among the tags
  with the same first letter, rather than comparing it with list after
  list of names (each comparison a call to the runtime), took the host
  time from 15.9 s to 12.8 s.
- **Where the rest goes**: about 40% in the garbage collector (`copy`,
  `collect`, `wosize`), because halves of 360 KB fill up while the
  page's lines stay alive and each collection copies all of them; about
  25% in `s.[i]` (`ml_string_get`, which calls `length` for its bounds
  check, which calls `wosize`); and about a quarter in the browser's own
  code.
- **What would make it faster**, not done yet: bigger heap halves (the
  10 MB for `www` of step 1), so that the collector rarely runs; and
  having tiny-ml -tm read a string's byte inline, which
  plan_tiny_network.md also left undone and which helps every program.
  Our guess for the two together: about 20 s at 8 million instructions
  a second, as long as the wire.
- **Limits of tiny-ml and tiny-cpu we worked around**: tiny-ml does not
  understand the `\x` escape in a string (`"\xe2"` reads as `xe2`), so
  the test pages are files. And a jump reaches only 32K words (`jal` has
  16 bits), so a 25,000-instruction program linked between the start
  and `main` puts `main` out of the start's reach. The test links the
  runtime and `main` first, then the program, then the heap's arrays
  (`heap.c`).

### Step 1, more memory for a process (2026-10-15)

The machine now has 128 MB, and a process's partition is the size its
program asks for. What was built differs from section 6 in a few ways:

- **How a program says its size**: an a.out header, made by
  `tiny-cpu -a n`, of three words: a magic number, the image's size,
  and the memory wanted (n MB). It reuses the header of tiny-os's v6,
  which nothing used any more. A program without a header (all the
  others) gets 1 MB, as before. `fork` gives the child its parent's
  size.
- **Where the partitions are**: above 16 MB, found first-fit when a
  program starts. The kernel's first 16 MB keep their layout. The 8 MB
  where the partitions used to be (from 5 MB) are unused for now: giving
  them to the kernel's images changed the screen of the recorded paint
  session, which we have not looked into yet.
- **The devices** are written in the kernel as negative addresses (-16
  is the console), as t6 already did, since the machine takes addresses
  modulo its memory size; the kernel does not depend on that size.
- **An ML program's heap** is sized from its partition by `mlsys.c`: the
  arguments sit at the top of the partition, so the partition ends at
  the first megabyte boundary above `argv`. In 1 MB the halves are
  256 KB as before; in 10 MB they are about 4.9 MB each.
- **The test**: `bigmem`, a program of tiny-kernel linked with
  `tiny-cpu -a 8`, keeps 3 MB of strings alive and prints so; linked
  without the header it stops with "out of memory". The kernel's check
  runs it. Two recorded sessions (windows, nested) show `ls`'s listing,
  which now has `bigmem` in it: their screens' sums were recorded again
  after a look.

### The reading's speed, after steps 1 and 2 (2026-10-15)

Two changes after step 1, measured on OCaml's page by the throwaway
profiler of section 12:

- **tiny-ml -tm reads a string's length and its bytes inline**, rather
  than calling the runtime's `ml_string_length` and `ml_string_get`. An
  index out of bounds still calls `ml_string_get`, which reports the
  error as before. In tiny-cpu's 1 MB: 447 to 356 million instructions.
- **An ML program's heap uses its whole half from the start**
  (`mlsys.c`). Started at 256 KB, it grew only when a collection left
  it more than half full, so it stayed two or three times the size of
  what was alive and collected often. With halves of 4 MB: 320 million
  instructions when starting small, 243 million at full size (the
  collector from 26% to about 2%), 233 million with the length inline
  too.

So the reading now takes about 233 million instructions, half of the
447 we started with: about 12 s at the 20 million a second of a
window, 5 s at 50. What remains is spread out: `ml_concat` and
`ml_alloc` 11% each, the polymorphic `compare` 9% (string comparisons),
`String.sub` 6%, then the browser's own loops.

### Step 3, the peer's www (2026-10-15)

The line `www address` on port 70 is answered with the page's bytes,
unchanged, then the end of the connection.

- **Where to fetch** is decided in `TinyMachinePeer.www_address`, the
  same in a terminal and in the page: a bare title is an English
  Wikipedia article, a name with a dot is https://, a Wikipedia
  article's /wiki/X becomes its REST HTML, a #fragment is dropped.
- **In a terminal**, with `-net-out`, tiny-machine runs
  `tiny-machine-fetch` (`TinyMachine/TinyMachineFetch.ml`, 15 lines on
  `Http_client`) and waits for it; its output for OCaml is the same
  257,035 bytes as curl's, through ix's own TLS 1.3, in 0.8 s.
  Without `-net-out`, or when the fetch fails, the kept copy
  (`tiny/tests/www/OCaml.html`) answers. Section 3 had planned that
  helper to decode pictures too; that comes with step 6.
- **In the page**, `fetch()`, then the kept copy beside the page.
  Built, not run in a browser (the page's test needs Python's
  websockets, not installed here).
- **Checked** in tiny-kernel with `get` (rc quotes the two words into
  one line): `get 'www OCaml' | wc` gives the 257,035 bytes, the same
  for the full address with a fragment, and an article not kept gives
  one line with its REST address; the kernel's check runs these. Live,
  with `-net-out`: Plan 9 from Bell Labs (496,931 bytes, as curl),
  example.com (577), and a host that does not exist (one `www:` line).

### Step 4, on tiny-kernel's screen (2026-10-15)

`www OCaml` in tiny-kernel asks the wire's other end for the page and
draws it as it arrives: a bar with the title at the top, the page's
lines, and a status line ("reading, 48 KB", then "252 KB, 732 lines").
Space and `-` show the next and the previous screenful, the arrows a
line, `q` quits. In a window of tiny-windows it asks the window's size
as emacs does.

- **The program**: `TinyBrowser.browse` (the screen part of
  TinyBrowser.ml, 896 lines in all, 678 of code), and
  `tiny/TinyKernel/user/www.ml`, which calls it. It is linked as an
  a.out asking for 10 MB (`tiny-cpu -a 10`); its code is 243 KB.
- **`u_dial`** for ML: an external in `calls.ml`, a few lines of C in
  `mlsys.c` over the C library's `dial`, and -1 in the host's
  `TinyCalls.ml`.
- **The looks are colours**: the font has one face 8 pixels wide.
  Drawing bold twice, a pixel apart, filled the gaps of an `m`, so the
  text is a dark grey (68) and bold is black; emphasis is red, links
  blue and underlined, code on light grey.
- **The pace**: OCaml's 257 KB take 54 s of machine time at 8 million
  instructions a second, from the first packet to the last (about
  430 million instructions: the reading's 233, the network and the
  kernel's copies, the drawing). That is about 22 s at a window's 20
  million, 9 s at 50. The first screenful is drawn within the first
  few seconds.
- **The test**: `www.events` in the kernel's check types `www OCaml`,
  presses space when the page is in, and compares the screen. The
  windows and nested sessions show `ls`'s listing, which now has
  `www`; tetris's pieces come from the tick at which it starts, which
  moved with the image's size. Each was looked at and recorded again.
- **Not done yet**: following links (step 5), pictures (step 6), a
  page in tiny-windows checked by a recorded session. And the kernel's
  image is at 2,601,916 bytes of its 2,621,440 (runtime.c's stack of
  values starts above it): the next program, or pictures, will need
  that limit moved.

### Step 5, links (2026-10-15)

- **A click on a link follows it.** Its address is resolved against the
  page's `<base>` (Wikipedia's is `//en.wikipedia.org/wiki/`, its links
  `./ML_(programming_language)`), or against the page's own address.
  A link to a place of the same page (`#cite_note-2`, a reference's
  `[2]`) only scrolls there. The wheel (Plan 9's buttons 8 and 16)
  scrolls.
- **Places in a page**: the reader keeps the line where each element
  with an `id` starts, except Parsoid's own ids (`mw...`), which no
  link names.
- **`b`** (or Backspace) goes back to where the page before was shown:
  only a scroll for the same page, the page asked again otherwise, and
  shown from that line once it has come. **`g`** asks for an address in
  the status line (Enter goes, Escape gives up).
- **`<cite>` is plain text**, no longer emphasis: Wikipedia puts each
  whole citation in one, and the references were all red.
- **tiny-ml's 11 registers**: a record literal of 15 fields could not be
  built (its fields are evaluated on the stack machine's registers), so
  where the browsing is (the connection, the address, the history, the
  place to go, the mouse) is a record of its own, `nav`.
- **The kernel's image** reached 2,618,016 bytes of its 2,621,440: the
  kernel's stack of values, the frames, the packet's place and the heap
  moved up 2 MB (into the space the partitions left), so the image may
  now be 4.5 MB.
- **Tests**, in the kernel's check: `wwwlink` clicks `[2]` and shows
  the references; `wwwback` clicks it, goes back and pages down, and
  must show `www`'s screen exactly; `wwwgo` types `g` then
  `OCaml#History` and shows the History section. By hand, with
  `-net-out`: a click on ML in the infobox loads Wikipedia's "ML
  (programming language)" (125 KB, 279 lines).
- `tiny/TinyBrowser.ml` is 1,075 lines, 807 of code.

### Step 6, pictures (2026-10-15)

- **A picture is a box the size the page says** (`<img>`'s width and
  height, smaller if it is wider than its room): lines whose one run
  is a slice of the picture, 16 pixels high. The text below never
  moves when the pixels come. Icons under 24 pixels are left out, and
  a page's pictures may have 1 MB of pixels in all (the kernel has
  2 MB for its images). A picture in a table cell (the infobox's logo)
  is the same lines inside the cell.
- **After the page**, the pictures are asked for one at a time, those
  on the screen first: the line `img w h address`. Each row that comes
  goes into the picture's image (the kernel's) and is drawn at once
  if its slice is on the screen, so a picture is painted as it
  arrives. Until then its box is grey with its alternative text.
  Scrolling draws a slice from the image.
- **The host decodes**: `tiny-machine-fetch -picture w h source`
  (PNG, JPEG, GIF by lib_graphics), each pixel the average of the
  source's, on white where they are transparent, then the nearest of
  the 256 colours by a table of 32,768. In the page, a canvas does it.
  Kept copies for the tests: OCaml's six pictures, 36 KB, in
  `tiny/tests/www/`.
- **Checked**: OCaml's logo in the infobox, and the photograph of the
  POPL award in the History section (`wwwpicture`, in the kernel's
  check). OCaml's two pictures take 8 s of machine time after the
  page's 57. Live, with `-net-out`: Plan 9 from Bell Labs shows Glenda
  and a screenshot of rio (486 KB, 934 lines). The logo's box moved the
  infobox two rows down, so `wwwlink` and `wwwback` click `[2]` at its
  new place.
- `tiny/TinyBrowser.ml` is now 1,229 lines, 928 of code: the reading,
  the screen, links and pictures, under the 2,000 this plan set.

### Step 7, in a window (2026-10-16)

`wwwwin`, in tiny-kernel's check, starts tiny-windows, sweeps a window
of 560 by 400, and types `www OCaml` in it: the browser asks the window
its size (70 columns, 25 rows) and the page wraps there (791 lines),
with the logo in the infobox. Everything is in at 92.9 s of machine
time, where it is 65 on the bare screen: every drawing goes through
tiny-windows.

### Step 7, ten articles, and scrolling (2026-10-16)

Read at 80 columns by the host's build: Plan 9 from Bell Labs, Unix,
Alan Turing, Paris, Linux, C, Python, the Mandelbrot set and the World
Wide Web (Tetris's fetch failed), with OCaml. What was wrong, and done:

- **Lines past the margin**, 20 to 90 an article: a word made of pieces
  with no space between them (a full stop and a reference's `[15]`, a
  link and its comma) only knew it was too long when its last piece
  came, and a line was only cut at a space. The flow now remembers
  where the word being made started, and carries the whole word to the
  next line (`carry`). Left: tables too wide for the screen (Paris's
  climate, 14 columns of numbers), cut at its edge, and code as it is.
- **A displayed formula** was one word; its TeX now wraps at its spaces.
- **Characters**: Latin Extended-A (the names of Central Europe) as
  their letters, from Unicode's decompositions; `oe`, `EUR`, some Greek
  letters spelled out, a few symbols. Left as `?`: IPA, Thai.
- **Not wrong**: Paris's infobox labels wrap inside their narrow
  column ("Mayor (2026-32)" on two lines).

Then the author: "scrolling is currently very slow; it would be great
to support the mousewheel/trackpad and to have smooth scrolling".

- **The page scrolls by pixels.** A scroll moves what stays on the
  screen by one copy of the screen onto itself, and draws only the
  strip that comes in. Each line is drawn into a one-line image first,
  then copied to the screen cut to the page's area, so a half-shown
  line never spills on the bar or the status line. An arrow scrolls 16
  pixels for about 1.3 million instructions (65 ms at a window's 20
  million a second), where it redrew the screen for about 27 million.
  Space and `-` glide a screenful in steps of 64 pixels: the same
  drawing as a jump, about 27 million instructions, seen moving.
- **The wheel and the trackpad**: the SDL display reports the wheel in
  tiny-machine's mode too (it did only when grabbed, mini-qemu's), and
  tiny-machine's window sends each step as an arrow key; the web page
  does the same with the browser's wheel events, a step every 40
  pixels. A key is queued, where a button pressed and let go between
  two reads of the mouse could be missed.
- **Tests**: `wwwscroll` (ten arrows down) in the kernel's check; ten
  down then ten up gives back exactly the first screen. The other
  sessions were recorded again after the wrapping fix (`wwwback` still
  equals `www`, `wwwgo` equals `wwwpicture`).
- **What is slow now** is drawing text: a screenful is 27 million
  instructions, about 13,000 a character, in the kernel's text drawing.

### A hand over links; the window's own SDL (2026-10-16)

The author: "would be great also to have the cursor change when
hovering a link in www". The mouse's look goes through every layer: a
program writes it with the drawing message `c` (`TinyLibDraw.d_cursor`:
0 the arrow, 1 a hand); the kernel writes it to the machine's mouse
word (a store there was ignored until now); tiny-windows shows the front
window's look while the mouse is in it, the arrow elsewhere; tiny-machine
sends its window a line `C n`, and the page sets the canvas's CSS
cursor. `www` sends the hand when the mouse goes over a link.

The window had linked mini-qemu's SDL display, which needed changes for
the wheel and the cursor. The author preferred tiny-machine to have its
own: `TinyMachine/TinyMachineSDL.ml` (78 lines), and mini-qemu's display
is as it was. Not run: the window itself (SDL needs a screen) and the
page in a browser; a temporary trace showed the hand and the arrow
changing as the mouse moved, on the screen and in a tiny-windows window.

### Faster scrolling: the kernel's text and copies (2026-10-16)

The author: "let's improve the speed of scrolling!". Measured with a
temporary profile of tiny-machine (a count of instructions by mode and
address, mapped to the kernel's and www's functions), on OCaml's page:
eight page downs, and ten arrows.

| what | a page down | ten arrows |
|---|---:|---:|
| before (the host's seconds for 8 / 10) | 3.56 s | 0.21 s |
| a whole text by one call, lines as rectangles | 1.42 s | 0.19 s |
| glyphs a word at a time, copies unrolled, numbers' bytes made once, whole lines on the screen | 0.91 s | 0.13 s |
| the lines in an array for a scroll | 0.93 s | 0.08 s |

A page down is now about 5.4 million instructions (0.27 s at a window's
20 million a second; 1.3 s before), an arrow about 0.4 million.

- **Text** (`TinyKernelGraphics.text`): a draw a character, some 13,000
  instructions, became one call of `glyphs` (draw.tm) for a whole text:
  a character's row is two words, merged with the colour where the
  font's mask is set (the mask's set bytes are now 255, so its words
  are the masks), a row with nothing set skipped. Used when the text is
  all inside its image, in a colour, at a whole word; the old path is
  kept for the rest.
- **Lines** (an underline): a level or upright line is one rectangle,
  where Bresenham's was a draw a pixel.
- **Copies and fills** (`row_copy`, `row_fill`): four words a turn.
- **Messages** (`TinyLibDraw`): the two bytes of each number from 0 to
  1023 made once; a number was two concatenations.
- **www**: a line all inside the page's area is drawn on the screen,
  only one cut by its edge through the strip; the lines are kept in an
  array too, made again when lines came since, so a scroll finds them
  at once.
- **What is left** of a page down: the glide's copies of the page's area
  (a step 64 pixels, about 1.2 million instructions a page: the price
  of seeing it move), and building messages in www (concatenations and
  the collector after them). Making tiny-ml's `String.concat` one call
  of the runtime would halve the second; not done, as TinyLibStd.ml was
  being changed by another session.
- **Found**: the recorded paint session's screen changed with this
  faster kernel, as it did in step 1 when the images were given the
  partitions' old megabytes. It is not a bug: paint's yellow square is
  a ball moved one step at each of the kernel's ticks, so where it is at
  the end depends on how fast the kernel works. (Step 1 took it for a
  palette that did not appear.) Its screen was recorded again; the
  unused megabytes could be the images' after all.

### Tetris, and the plan done (2026-10-16)

Tetris's article, whose fetch had failed among the ten, was fetched
again: 862 KB, three times OCaml's. The host's build reads it into
1,440 lines at 80 columns, none past the margin, and `www Tetris` on
tiny-machine (`-net` a directory with the page alone, no pictures)
fits in its 10 MB and says the same "862 KB, 1440 lines"; its logo is
an empty box, its Russian name `??????`. The plan moved to `done/`,
with "Left".
