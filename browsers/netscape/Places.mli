(* Places keeps the pages seen and the pages kept: the browser's memory
   of the web. Places is Firefox's name for the two, which it has kept
   in one database since 2007.

     ~/.config/mini-netscape/
        history          https://en.wikipedia.org/wiki/OCaml<TAB>OCaml - Wikipedia
                         https://news.ycombinator.com/<TAB>Hacker News
        bookmarks.html   <!DOCTYPE NETSCAPE-Bookmark-file-1> ...
                         <DT><A HREF="https://lwn.net/">LWN.net</A>

   The history has the newest page first, and each page once (a page
   seen again comes back to the top); it keeps the last thousand. The
   bookmarks are in the order they were added (with Ctrl+D; the
   toolbar's Bookmarks button shows them). Both are what the Location
   field offers as one types (matches). Both are also pages of the
   browser's own, about:history and about:bookmarks; the latter is the
   file itself, which is HTML already.

   What is typed and is not an address is taken as words to search for
   (destination), on DuckDuckGo's page without scripts.

   cs-history:
   Mosaic kept a "hotlist" and a global history (~/.mosaic-hotlist-
   default, 1993). Netscape's bookmarks were a page of HTML, a <DL> of
   links and folders (bookmarks.html, Navigator 1.1), and that file is
   still how browsers give their bookmarks to one another: Firefox and
   Chrome export and import NETSCAPE-Bookmark-file-1 today. Netscape
   4 (1997) completed an address typed from the history, and sent
   words typed in the Location field to a search (Internet Keywords,
   1998); Chrome's Omnibox (2008) made that the one box.

   Not done: folders and separators (they are read as their links, and
   written flat), removing a bookmark (the file is text, so use an
   editor), and counting or dating visits. *)

type place = { url : string; title : string }
type t = { history : place list; bookmarks : place list }

val empty : t

(* Puts a page visited at the top of the history. *)
val visited : t -> place -> t

(* Adds a page at the end of the bookmarks, unless it is there. *)
val bookmarked : t -> place -> t

(* The texts of the two files, and back. *)
val history_to_string : t -> string
val history_of_string : string -> place list
val bookmarks_to_html : t -> string
val bookmarks_of_html : string -> place list

(* about:history *)
val history_page : t -> string

(* What [typed] may mean: the pages of the bookmarks, then of the
 * history, whose address or title contains it (ignoring case). It
 * returns six pages at most. *)
val matches : t -> string -> place list

(* Where [typed] goes. Words (a text with a space, or with no '.', ':'
 * or '/' and that is not localhost) go to a search; anything else is
 * the address as typed (for Tab.visit). *)
val destination : string -> string
