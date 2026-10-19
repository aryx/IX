(* Places: the pages seen and the pages kept, the browser's memory of
   the web (Firefox's name for the two, one database since 2007).

     ~/.config/mini-netscape/
        history          https://en.wikipedia.org/wiki/OCaml<TAB>OCaml - Wikipedia
                         https://news.ycombinator.com/<TAB>Hacker News
        bookmarks.html   <!DOCTYPE NETSCAPE-Bookmark-file-1> ...
                         <DT><A HREF="https://lwn.net/">LWN.net</A>

   The history, the newest first, a page once (seen again, it comes
   back to the top), the last thousand; the bookmarks in the order they
   were added (Ctrl+D, the toolbar's Bookmarks shows them). Both are
   what the Location field offers as one types (matches), and two pages
   of the browser's own, about:history and about:bookmarks -- the
   latter the file itself, which is HTML already.

   What is typed and is not an address is words, searched
   (destination): DuckDuckGo's page without scripts.

   cs-history:
   Mosaic kept a "hotlist" and a global history (~/.mosaic-hotlist-
   default, 1993). Netscape's bookmarks were a page of HTML, a <DL> of
   links and folders (bookmarks.html, Navigator 1.1), and that file is
   still how browsers give their bookmarks to one another: Firefox and
   Chrome export and import NETSCAPE-Bookmark-file-1 today. Netscape
   4 (1997) completed an address typed from the history, and sent
   words typed in the Location field to a search (Internet Keywords,
   1998); Chrome's Omnibox (2008) made that the one box.

   Not done: folders and separators (read as their links, written
   flat), a bookmark removed (the file is text: an editor), visits
   counted or dated. *)

type place = { url : string; title : string }
type t = { history : place list; bookmarks : place list }

val empty : t

(* a page come: at the history's top *)
val visited : t -> place -> t

(* a page kept: at the bookmarks' end, unless it is there *)
val bookmarked : t -> place -> t

(* the files' texts, and back *)
val history_to_string : t -> string
val history_of_string : string -> place list
val bookmarks_to_html : t -> string
val bookmarks_of_html : string -> place list

(* about:history *)
val history_page : t -> string

(* what [typed] may mean: the bookmarks, then the history, whose
 * address or title has it (case aside), six at most *)
val matches : t -> string -> place list

(* where [typed] goes: words (a space, or no '.', ':' or '/', and not
 * localhost) searched, else the address as typed (Tab.visit) *)
val destination : string -> string
