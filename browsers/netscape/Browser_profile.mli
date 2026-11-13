(* The profile is what the browser keeps from one run to the next, in a
   directory of the user's.

     ~/.config/mini-netscape/
        preferences     window 1280 900
                        zoom en.wikipedia.org 1.25
                        zoom news.ycombinator.com 1.5
        cookies.txt     .example.com  TRUE   /  FALSE  1791000000  lang  en-US
                        www.example.com  FALSE  /  TRUE  1791000000  SID  31d4...
        history         (Places)
        bookmarks.html

   There are two files of text, with one thing on each line, so that
   they can be read, and mended, in an editor. [preferences] has the
   window's last size and the sites zoomed (Browser_zoom). [cookies.txt]
   has the cookies that have an expiry date (a session's cookies are
   forgotten when the browser closes). Each of its lines has seven
   fields, with a tab between them:
   - the domain;
   - TRUE if the hosts under it get the cookie too;
   - the path;
   - TRUE if the cookie goes over https:// only;
   - when it expires (in seconds since 1970);
   - its name;
   - its value.
   A line whose domain starts with "#HttpOnly_" is a cookie that the
   page's scripts do not see; any other line starting with '#' is a
   comment.

   The files are read once, when the program starts, and written when
   what they hold has changed, each through a capability: reading needs
   Cap.open_in, and writing needs Cap.open_out. The directory's place is
   read from the environment (HOME, or XDG_CONFIG_HOME if it is set).
   profile=DIR names another directory, and profile=off names none:
   nothing is read and nothing is kept, which is how the tests run.

   cs-history:
   cookies.txt is Netscape's own file, and this is its format: Navigator
   kept Lou Montulli's cookies (1994) in one text file of that name in
   the user's directory, with these seven fields. The browsers moved to
   databases (Firefox's cookies.sqlite in 2008; Chrome's Cookies, an
   SQLite file whose values are encrypted), but the format outlived the
   browser as the one that tools exchange: curl's --cookie-jar writes
   it, and wget's --load-cookies reads it. "#HttpOnly_" is curl's
   addition to it.

   The profile also has the history and the bookmarks, in history and
   bookmarks.html (Places). Not done: writing a file under another name
   first and then renaming it (here, a write cut short loses the
   cookies). *)

(* The sites zoomed, the window's size, and the helper programs that the
 * user wrote by hand (a line such as "helper youtube.com/watch mpv %u":
 * see Helpers). *)
type t = { zooms : Browser_zoom.t; window : (int * int) option; helpers : Helpers.rule list }

val empty : t

(* The text of preferences, and back. A line that is not understood is
 * left out. *)
val to_string : t -> string
val of_string : string -> t

(* The text of cookies.txt, which has the cookies of [jar] that have an
 * expiry date; and back, without the cookies that expired before
 * [now]. *)
val cookies_to_string : Cookie.jar -> string
val cookies_of_string : now:float -> string -> Cookie.jar

(* The directory used when none is named: $XDG_CONFIG_HOME/mini-netscape,
 * or $HOME/.config/mini-netscape. None if the environment has neither. *)
val default_dir : < Cap.env; .. > -> string option

(* What [dir] holds. A file that is not there gives an empty profile,
 * or no cookies. *)
val load : < Cap.open_in; Cap.clock; .. > -> dir:string -> t * Cookie.jar

(* Writes preferences, making [dir] if it is not there. Error says why
 * it could not be written. *)
val save : < Cap.open_out; .. > -> dir:string -> t -> (unit, string) result
(* The history and the bookmarks (Places). Each file is written only if
 * it changed since [was]. The history is readable by its owner alone,
 * because it says where one went. *)
val load_places : < Cap.open_in; .. > -> dir:string -> Places.t
val save_places : < Cap.open_out; .. > -> dir:string -> was:Places.t -> Places.t -> (unit, string) result
(* Writes cookies.txt, readable by its owner alone, because it is what
 * signs one in. *)
val save_cookies : < Cap.open_out; .. > -> dir:string -> Cookie.jar -> (unit, string) result
