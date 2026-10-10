(* The profile: what the browser keeps from one run to the next, in a
   directory of the user's.

     ~/.config/mini-netscape/
        preferences     window 1280 900
                        zoom en.wikipedia.org 1.25
                        zoom news.ycombinator.com 1.5
        cookies.txt     .example.com  TRUE   /  FALSE  1791000000  lang  en-US
                        www.example.com  FALSE  /  TRUE  1791000000  SID  31d4...

   Two files of text, a line a thing, so that they can be read, and
   mended, in an editor. [preferences] has the window's size as it
   was last, and the sites zoomed (Browser_zoom). [cookies.txt] has the cookies that have a date (a
   session's are forgotten when the browser closes), seven fields a
   line with a tab between: the domain, TRUE if the hosts under it get
   the cookie too, the path, TRUE if over https:// only, when it ends
   (seconds since 1970), its name, its value. A line whose domain
   starts with "#HttpOnly_" is a cookie the page's scripts do not see;
   another line starting with '#' is a comment.

   The files are read once, when the program starts, and written when
   what they hold has changed, each through a capability: reading asks
   Cap.open_in, writing Cap.open_out, and the directory's place is
   read in the environment (HOME; XDG_CONFIG_HOME if said). profile=DIR
   says another directory, profile=off none: nothing read, nothing
   kept, which is what the tests run with.

   cs-history:
   cookies.txt is Netscape's own file, and this is its format: Lou
   Montulli's cookies (1994) were kept by Navigator in one text file of
   that name in the user's directory, with these seven fields. The
   browsers moved to databases (Firefox's cookies.sqlite, 2008;
   Chrome's Cookies, an SQLite file, its values encrypted), but the
   format outlived the browser as the one tools exchange: curl's
   --cookie-jar writes it and wget's --load-cookies reads it, and
   "#HttpOnly_" is curl's addition to it.

   Not done: bookmarks, the history of the pages seen; the file written under another name first and renamed (a
   write cut short loses the cookies, here). *)

type t = { zooms : Browser_zoom.t; window : (int * int) option }

val empty : t

(* preferences' text, and back; a line not understood is left out *)
val to_string : t -> string
val of_string : string -> t

(* cookies.txt's text: the cookies of [jar] that have a date; and back,
 * without those whose date is past [now] *)
val cookies_to_string : Cookie.jar -> string
val cookies_of_string : now:float -> string -> Cookie.jar

(* the directory when none is said: $XDG_CONFIG_HOME/mini-netscape, or
 * $HOME/.config/mini-netscape; None if the environment says neither *)
val default_dir : < Cap.env; .. > -> string option

(* what [dir] holds: empty, and no cookie, for a file that is not there *)
val load : < Cap.open_in; .. > -> dir:string -> t * Cookie.jar

(* each file written, [dir] made if it is not there; cookies.txt for
 * its owner alone, being what signs in. Error says why not *)
val save : < Cap.open_out; .. > -> dir:string -> t -> (unit, string) result
val save_cookies : < Cap.open_out; .. > -> dir:string -> Cookie.jar -> (unit, string) result
