(* Line_mode: a page as the Line Mode Browser showed it -- text, and a
   number after each link.

   The CERN Line Mode Browser ("www", Nicola Pellow, 1991) was the web
   for any terminal: no fonts, no pictures, no mouse. It printed the
   page as lines of text, a heading centred, a list item behind a "*",
   each link followed by its number in brackets, and the reader typed
   the number to follow it:

     <h1>Menu</h1>
     <p>Soup of the day. See the <a href="recipes.html">recipes</a>
     or go back <a href="/">home</a>.

                                     Menu

     Soup of the day. See the recipes[1] or go back home[2].

     links: 1 = recipes.html, 2 = /

   It is layout with the hard part left out: a character per cell, so
   a line breaks after a count, not a measure. Which makes it the first
   thing to write once a tree exists, and a way to see the tree read as
   a document: blocks on lines of their own (a blank line before a
   paragraph or a heading), the inline elements flowing into them, the
   head, scripts and styles not shown at all.

   The rules, the tests':
     - text: its runs of spaces and newlines are one space (outside
       <pre>), and it is broken greedily into lines of [width]
       characters, a word longer than a line on a line of its own;
     - h1 to h6: centred, a blank line before;
     - p, pre, ul, ol, dl, blockquote, address, and hr: a blank line
       before; <br> ends a line;
     - li: "* " in a <ul> (or <dir>, <menu>), "1. ", "2. " in an <ol>,
       the lines after its first indented under its text; a list is
       indented two more than its parent;
     - dt at the list's indent, dd four more; blockquote four more;
     - pre: its lines as they are, never broken;
     - a with an href: "[n]" right after its text, n counting from 1;
     - img: its alt text, else "[IMAGE]" (the 1991 browser's word);
     - hr: a line of dashes;
     - what came after 1991 (for mini-lynx, on today's pages): div,
       section, article, header, footer, nav, main, form, table and a
       table's row are lines of their own, with no blank line; a row's
       cells are words apart; template and svg are not shown.

   In the system: mini-lynx (Lynx) is this module with a prompt, the
   shortest path through a browser: bytes (Http_client), text
   (Charset), a tree (Html_tree), lines. Html_layout is the same walk
   of the same tree where a word has a width in pixels, and Box_layout
   the same again where the blocks are CSS's and not this list.

   cs-history:
   It was the second browser, and for two years the web most people
   saw. The first, Tim Berners-Lee's WorldWideWeb (1990), ran on the
   NeXT machines of a few physicists, and edited pages as well as
   showing them. Nicola Pellow, a student on a placement at CERN,
   wrote this one in portable C so that the web could be reached from
   anything -- a terminal on a mainframe, or a telnet to info.cern.ch
   from anywhere. Lynx (Lou Montulli, Michael Grobe and Charles
   Rezac, University of Kansas, 1992) took the idea to a full screen
   with the links highlighted; Mosaic (1993) ended the terminal's web.

   Reference: the Line Mode Browser's source (libwww's LineMode, CERN,
   1991-1996) and its restoration, line-mode.cern.ch (2013);
   notes_browser.md section 8. *)

type t = {
  lines : string list; (* UTF-8, each at most [width] characters but a long word or a <pre> line *)
  links : string list; (* the href of link 1, 2, ... *)
}

(* the page's body as lines of [width] characters (80) *)
val render : int -> Dom.element -> t
