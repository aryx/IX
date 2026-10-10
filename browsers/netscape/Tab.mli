(* Tab: a page being looked at, and the pages before it. Written for
 * ix after the author's mini-chrome's Browser_tab (its first version),
 * without what that one carries: sounds and videos, the developer
 * tools' lists.
 *
 * No threads and nothing on its way (plan_browser.md, decision 6): a
 * page asked for ([go]) is fetched by [step], which the window calls
 * between two frames while the tab is [busy]: first the page and its
 * style sheets one after the other (and theirs, @import), laid out
 * and shown; then its scripts' files, a call each, all run by one
 * more (browsers/webapi's Browser_script: the page's tree as they left
 * it laid out again); then a picture a call (PNG, JPEG, GIF, SVG:
 * Browser_picture), the page laid out with them after the last. What
 * a script asks for later (XMLHttpRequest, fetch; a picture it added)
 * is a piece too, answered by a call; a page it goes to, or a form it
 * sends, is asked for as a link's is. The window is still during a
 * piece, and says between two what is being done.
 *
 * A PDF file is shown as a page of the browser's (Pdf_viewer): its
 * pages are pictures, drawn when [go] or [scrolled] brings them into
 * view, a window's height before and after too, and let go when they
 * are out of it.
 *
 * An address is http://, https:// (Http_client: ix's own TLS), file://
 * or a file's path, data:, or about:name, a page of the browser's
 * own.
 *
 * A browser is two things: its chrome (the toolbar, the Location
 * field: Netscape, each browser's own) and what it shows, a tab: the
 * page (on its way, or shown and scrolled), the history behind and
 * ahead (Browser_history's two stacks; a page come back to is fetched
 * again, and scrolled to where it was), the style sheets and the
 * pictures had and still to fetch, the form's field that has the
 * keys, and the page's script world (Browser_script, a JavaScript
 * realm a page). mini-netscape has one; a browser's tabs are a list
 * of these.
 *
 * What is left to do is a list, and [step] does its first:
 *
 *   go "http://host/"         [Page]
 *   step   the page and its   [Script_file a.js; Script_file b.js;
 *          sheets: shown       Run]
 *   step, step                [Run]
 *   step   the scripts run,   [Picture logo.png; Picture x.gif;
 *          the tree theirs     Pictures_in]
 *   step, step                [Pictures_in]
 *   step   laid out with      []        busy is false
 *          the pictures
 *   a timer's fetch("/n")     [Request /n]
 *   step   answered, the      []
 *          page laid out again if its scripts changed it
 *
 * Asking for another page meanwhile replaces the list: what was on
 * its way for the page before is dropped, which is all Stop would
 * be. After each task of the scripts (their run, a click's handlers,
 * a timer, an answer) the tab takes what they left for the browser:
 * the requests they made, an alert's words, a tree that changed (the
 * page laid out again from it, once, the field in focus found again
 * by its place in the tree), an address they went to.
 *
 * A click is the meeting of the two: the point is turned into an
 * element by the layout (Hit), the element's click is the scripts'
 * first (Browser_script.click: it bubbles), and only if no handler
 * prevented it is it the browser's own: a link followed, a form's
 * control pressed (Browser_forms).
 *
 * wib:
 * One thing at a time, and the window still meanwhile. A browser has
 * a thread (now a process) for the network and one for each page's
 * scripts, so that its window answers while a page comes; here a
 * fetch is a call that returns with the bytes (Http_client), and the
 * list above is what keeps the window alive between two of them:
 * each piece is short enough, and what is said between two ("Loading
 * pictures: 3 left") is what a progress bar is. The cost: a server
 * that does not answer stops the window until the connection gives
 * up, and a page of forty pictures makes forty connections one after
 * the other, a TLS handshake each.
 *
 * others:
 * The pictures one after the other is Mosaic's way. Netscape opened
 * several connections at once (four by default) and showed each
 * picture as it came, which is much of why it felt faster on a
 * modem; mini-chrome's Browser_tab does the same, laying the page
 * out at each. HTTP/1.1's kept connection (1997) and HTTP/2's many
 * requests on one (2015) are the later answers to the same wait.
 *
 * cs-history:
 * Tabs are older than they look. A window per page was the rule from
 * Mosaic on; several pages in one window appeared in InternetWorks
 * (BookLink, 1994), then NetCaptor (1997) and Opera, and reached most
 * people through Mozilla (2001) and Firefox (2004); Internet Explorer
 * took them in 2006. Chrome (2008) made two changes that stayed: the
 * tabs above the address, which belongs to the page and not to the
 * window, and each tab's page in a process of its own, so that one
 * page's crash or busy script is that tab's alone (told as a comic,
 * drawn by Scott McCloud, the day it shipped). Here a tab is a
 * value, and the window holds one. *)

type t

(* a tab with no page, [width] wide; [about name]: the browser's own
 * page of that name (about:name), its HTML *)
val empty : float -> (string -> string option) -> t

(* the page shown, if one came; its address; what the last load said
 * (the status bar's) *)
val page : t -> Browser_page.t option
val url : t -> string
val said : t -> string

(* how far down the page the window's top is *)
val scroll : t -> float

(* [scrolled by ~visible tab]: moved by [by] (down: positive), kept
 * within the page, [visible] of it seen at once *)
val scrolled : float -> visible:float -> t -> t

(* how wide the page is laid out; [resized width tab]: laid out again
 * at another width (the window's, divided by the zoom) *)
val width : t -> float
val resized : float -> t -> t

(* the field that takes the keys, if one does *)
val focus : t -> Dom.element option

(* The four below ask for a page and return at once: [step] fetches
 * it, a piece a call, so that the window says what is on its way
 * between two pieces. *)

(* [go tab address]: a link followed: the address, against the page's,
 * asked for, the page before kept behind it; an address of the page
 * shown with another #fragment only scrolls *)
val go : t -> string -> t

(* [visit tab typed]: an address as one types it: whole, or a file's
 * path, or a host's name (example.com is http://example.com) *)
val visit : t -> string -> t

val back : t -> t
val forward : t -> t
val reload : t -> t

(* is something left to fetch? Then [url] is the address asked for,
 * and [said] what is being done ("Loading http://... ...", "Loading
 * pictures: 3 of 19") *)
val busy : t -> bool

(* a piece of it done: the page with its style sheets, read and laid
 * out, shown without its pictures; then a script's file a call, the
 * scripts run after the last; then a picture a call, and after the
 * last the page laid out again with them all *)
val step : < Cap.network; Cap.open_in; .. > -> t -> t

(* the link at a point of the page, its address whole *)
val link_at : t -> x:float -> y:float -> string option

(* what is at a point of the page, for the cursor: a link (its address
 * whole), a field one types in, a button or a box to click *)
type under = Nothing | Link of string | Field | Button

val under : t -> x:float -> y:float -> under

(* a click at a point of the page: the page's scripts' handlers first
 * (it bubbles from the element there); then, unless one prevented it,
 * a link followed, a field given the keys, a button's form sent *)
val click : t -> x:float -> y:float -> t

(* text typed, and a key ("enter", "backspace"), for the field that has
 * the keys *)
val typed : t -> string -> t
val key : t -> string -> t

(* Scripts. A page's scripts run unless [with_scripts false] said not
 * to (before the page is asked for). *)
val with_scripts : bool -> t -> t

(* [advance ms tab]: the page's clock moved on, its timers due run
 * (setTimeout, setInterval); the window calls it at each frame *)
val advance : float -> t -> t

(* what the page's scripts printed, the oldest first: console.log's
 * lines, and their errors *)
val console : t -> string list
