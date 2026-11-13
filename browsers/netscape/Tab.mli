(* A tab is a page being looked at, and the pages before it. It was
 * written for ix after Browser_tab in the author's mini-chrome (its
 * first version), without what that one carries: sounds and videos,
 * and the developer tools' lists.
 *
 * There are no threads here, and nothing is fetched in the background
 * (plan_browser.md, decision 6). A page asked for ([go]) is fetched by
 * [step], which the window calls between two frames while the tab is
 * [busy]. First come the page and its style sheets, one after the
 * other (and the sheets' own, by @import), and the page is laid out
 * and shown. Then come its scripts' files, one in each call, and one
 * more call runs them all (browsers/webapi's Browser_script); the
 * page's tree, as they left it, is laid out again. Then come the
 * pictures, one in each call (PNG, JPEG, GIF and SVG, by
 * Browser_picture), and after the last one the page is laid out with
 * them. What a script asks for later (XMLHttpRequest, fetch, or a
 * picture it added) is a piece too, answered by a call; a page it goes
 * to, or a form it sends, is asked for as a link's page is. The window
 * is still during a piece, and between two pieces it says what is
 * being done.
 *
 * What the tab does not show, such as a PDF file or a film, it gives to
 * a program (Helpers). A click on a link to a site that has a program,
 * or the arrival of a document of a type that has one, is a [job] for
 * the window to run. In the first case the page stays; in the second,
 * the page says where the document went.
 *
 * An address is http:// or https:// (Http_client, with ix's own TLS),
 * file:// or a file's path, data:, or about:name, which is a page of
 * the browser's own.
 *
 * Under a browser's chrome (the toolbar and the Location field, which
 * are each browser's own; here they are in Netscape) is what it shows:
 * a tab. A tab has:
 * - the page, on its way, or shown and scrolled;
 * - the history behind and ahead (Browser_history's two stacks). A
 *   page one comes back to is shown as it was left, laid out and with
 *   its scripts' engine as they left it, if it was whole and is one of
 *   the three nearest; otherwise it is fetched again. Either way it is
 *   scrolled to where it was;
 * - the style sheets and the pictures, those it has and those still to
 *   fetch;
 * - the form's field that has the keys;
 * - the page's script world (Browser_script, one JavaScript realm for
 *   each page).
 * A browser's tabs are a list of these (in Netscape).
 *
 * What is left to do is a list, and [step] does its first item:
 *
 *   go "http://host/"         [Page]
 *   step   the page fetched   [Read]
 *   step   read, laid out     [Sheet a.css; Styled]
 *   step   its sheet fetched  [Styled]
 *   step   laid out with it:  [Script_file a.js; Script_file b.js;
 *          shown               Run]
 *   step, step                [Run]
 *   step   the scripts run,   [Picture logo.png; Picture x.gif;
 *          their tree taken    Pictures_in]
 *   step, step                [Pictures_in]
 *   step   laid out with      []        busy is false
 *          the pictures
 *   a timer's fetch("/n")     [Request /n]
 *   step   answered, the      []
 *          page laid out again if its scripts changed it
 *
 * Asking for another page meanwhile replaces the list: what was on its
 * way for the page before is dropped, and that is all Stop would do.
 * After each task of the scripts (their first run, a click's handlers,
 * a timer, an answer), the tab takes what they left for the browser:
 * - the requests they made;
 * - an alert's words;
 * - a tree that changed: the page is laid out again from it, once, and
 *   the field in focus is found again by its place in the tree;
 * - an address they went to.
 *
 * A click is where the two meet. The layout turns the point into an
 * element (Hit). The scripts get the element's click first
 * (Browser_script.click, where it bubbles), and only if no handler
 * prevented it does the browser act on it: it follows a link, or
 * presses a form's control (Browser_forms).
 *
 * wib:
 * One thing is done at a time. A browser has a thread (now a process)
 * for the network and one for each page's scripts, so that its window
 * answers while a page comes. Here a fetch is a call that returns with
 * the bytes (Http_client), and the list above cuts a page's work into
 * pieces: what is said between two pieces ("Loading pictures: 3 left")
 * plays the part of a progress bar, and Tab_worker does each piece
 * beside the window, so that the window still answers. The cost is
 * that the pieces come one after the other: a page of forty pictures
 * fetches them one at a time, though over https:// they share one kept
 * connection ([keeps]), with one TLS handshake.
 *
 * others:
 * Fetching the pictures one after the other is Mosaic's way. Netscape
 * opened several connections at once (four by default) and showed each
 * picture as it came, which is much of why it felt faster on a modem;
 * mini-chrome's Browser_tab does the same, laying the page out again
 * at each picture. HTTP/1.1's kept connection (1997) and HTTP/2's many
 * requests on one connection (2015) are the later answers to the same
 * wait.
 *
 * cs-history:
 * Tabs are older than they look. A window per page was the rule from
 * Mosaic on; several pages in one window appeared in InternetWorks
 * (BookLink, 1994), then NetCaptor (1997) and Opera, and reached most
 * people through Mozilla (2001) and Firefox (2004); Internet Explorer
 * took them in 2006. Chrome (2008) made two changes that stayed: it put
 * the tabs above the address, which belongs to the page and not to the
 * window, and it put each tab's page in a process of its own, so that
 * one page's crash or busy script affects that tab alone (this was
 * told in a comic, drawn by Scott McCloud, the day before it shipped).
 * Here a tab is a value, and the window holds one. *)

type t

(* A tab with no page, [width] wide. [about name] gives the HTML of the
 * browser's own page of that name (about:name). *)
val empty : float -> (string -> string option) -> t

(* The page shown, if one came; its address; and what the last load said
 * (for the status bar). *)
val page : t -> Browser_page.t option
val url : t -> string
val said : t -> string

(* how far down the page the window's top is *)
val scroll : t -> float

(* [scrolled by ~visible tab] is the tab moved by [by] (positive is
 * down) and kept within the page, when [visible] of the page is seen
 * at once. *)
val scrolled : float -> visible:float -> t -> t

(* How wide the page is laid out. [resized width tab] lays it out again
 * at another width (the window's, divided by the zoom). *)
val width : t -> float
val resized : float -> t -> t

(* how long the page is laid out *)
val height : t -> float

(* the field that takes the keys, if one does *)
val focus : t -> Dom.element option

(* The five below ask for a page and return at once. [step] fetches it,
 * one piece in each call, so that the window can say what is on its way
 * between two pieces. *)

(* [go tab address] follows a link: it asks for the address, resolved
 * against the page's, and keeps the page before behind it. An address
 * of the page shown with another #fragment only scrolls. *)
val go : t -> string -> t

(* [visit tab typed] asks for an address as one types it: whole, or a
 * file's path, or a host's name (example.com is http://example.com). *)
val visit : t -> string -> t

val back : t -> t
val forward : t -> t
val reload : t -> t

(* Stop: drops what is left to fetch, and keeps the page as it came so
 * far. *)
val stop : t -> t

(* is something left to fetch? Then [url] is the address asked for, and
 * [said] says what is being done ("Loading http://... ...", "Loading
 * pictures: 3 of 19"). *)
val busy : t -> bool

(* How far along it is: the pieces done since the page was asked for,
 * and the pieces known, done or not. A page's pictures are known only
 * once it is read, so the second number may grow. *)
val pieces : t -> int * int

(* Does one piece of it. First comes the page with its style sheets,
 * read, laid out, and shown without its pictures. Then each call
 * fetches one script's file, and the scripts run after the last. Then
 * each call fetches one picture, and after the last the page is laid
 * out again with them all. *)
val step : < Cap.network; Cap.clock; Cap.open_in; .. > -> t -> t

(* [merged ~window r] is [r], what [step] made of a copy of the tab (on
 * the window's worker), with what the window did meanwhile to [window],
 * its own copy: the width, the clock, and the scroll if the page is the
 * same. *)
val merged : window:t -> t -> t

(* The link at a point of the page, with its address whole. *)
val link_at : t -> x:float -> y:float -> string option

(* What is at a point of the page, for the cursor: a link (with its
 * address whole), a field one types in, or a button or a box to
 * click. *)
type under = Nothing | Link of string | Field | Button

val under : t -> x:float -> y:float -> under

(* A click at a point of the page. The handlers of the page's scripts
 * get it first (it bubbles up from the element there). Then, unless
 * one of them prevented it, a link is followed, a field is given the
 * keys, or a button's form is sent. *)
val click : t -> x:float -> y:float -> t

(* A key for the field that has the keys: "enter" sends its form (or
 * makes a new line in a textarea), and "escape" gives up the keys. *)
val key : t -> string -> t

(* [editing tab] is the field that has the keys, if it is one that is
 * typed in (a text field, a password, a textarea), as it is edited:
 * its text, caret and selection (a textarea's caret is at its end).
 * [edited tab edit] makes the edit (one of Text_field's: a text typed,
 * a key, Ctrl and a letter), and tells the page's scripts of a changed
 * text (an input event). [pointed tab ~x ~select] puts the caret at [x]
 * of the page, and keeps the selection from the anchor if [select] (a
 * drag). A click that gives a field the keys puts its caret there
 * too. *)
val editing : t -> Text_field.t option
val edited : t -> (Text_field.t -> Text_field.t) -> t
val pointed : t -> x:float -> select:bool -> t

(* is a point of the page on the field that has the keys? *)
val on_field : t -> x:float -> y:float -> bool

(* Is an https:// connection kept for the next file from its host
 * (Keep_alive)? It starts true; the switch is there for measuring. *)
val keeps : bool ref

(* Is the layout that a script's change asks for owed, and made once
 * when the page's work is done, rather than after each of the scripts'
 * tasks? It starts true; it is a switch. *)
val settles : bool ref

(* Scripts. A page's scripts run unless [with_scripts false] said not
 * to (before the page is asked for). *)
val with_scripts : bool -> t -> t

(* The cookie jar that the tab's requests take their cookies from and
 * keep their answers' cookies in, and that a page's document.cookie
 * reads. It is the window's jar, which the window keeps in the profile;
 * without it, the tab has an empty jar of its own. *)
val with_jar : Cookie_jar.t -> t -> t

(* the helper programs the window can run (those on the PATH) *)
val with_helpers : Helpers.rule list -> t -> t

(* What is to be given to a program, if anything, and the tab without
 * it. The job is the rule, the address, and the document's bytes if the
 * program is given them (as a file to write). *)
val take_job : t -> (Helpers.rule * string * string option) option * t

(* [at ms tab] sets the time it is, in ms since 1970. The Date of a
 * page read from then on starts there. *)
val at : float -> t -> t

(* [advance ms tab] moves the page's clock on and runs the timers that
 * are due (setTimeout, setInterval). The window calls it at each
 * frame. *)
val advance : float -> t -> t

(* What the page's scripts printed, the oldest first: console.log's
 * lines and their errors. *)
val console : t -> string list
