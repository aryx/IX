(* Browser_helpers: what the browser does not show itself, given to a
   program that does -- Mosaic's and Netscape's "helper applications".

   A rule is a site or a content type, and a command:

     youtube.com/watch   mpv %u         a link to a film of YouTube's
     application/pdf     mini-page %s   a PDF file

   A rule for a **site** (a host, and what the path begins with; the
   host's own subdomains too: www.youtube.com) is taken when a link to
   it is clicked: the program is given the address (%u) and run beside
   the browser, the page staying where it is. A rule for a **content
   type** (type/subtype, or type/* ) is taken when a document of that
   type arrives: its bytes are written to a file, the program given
   the file (%s), and the page says so.

   The rules: the profile's preferences, a line each ("helper
   youtube.com/watch mpv %u", "helper application/pdf gv %s"), then
   ~/.mailcap's (RFC 1524, metamail's, which Netscape on Unix read:
   "video/mp4; mpv %s"), then the built-in ones: YouTube's films to
   mpv (which plays a YouTube address by yt-dlp), a PDF file to
   mini-page, ix's page. A rule whose program is not on the PATH is
   left out (Netscape: [available]): on ix, without mpv, a link to
   YouTube is followed as any other.

   cs-history:
   NCSA Mosaic (1993) showed HTML, GIF and XBM itself and nothing else:
   a PostScript file went to ghostview, a sound to the audio player,
   an MPEG film to mpeg_play, by the "mailcap" file of metamail
   (Nathaniel Borenstein, Bellcore, 1991), written for MIME's
   multimedia mail. Netscape kept it, called them helper
   applications, and added plug-ins (1995: a program inside the page,
   which became Flash's and Acrobat's); browsers then drew PDF and
   played films themselves (Chrome's PDF viewer, 2010; HTML5's
   <video>), and the helper became the download bar's "Open with".
   Here the helper is back, for what this browser does not do. *)

type rule = { site : string option; kind : string option; run : string list }

(* the built-in rules *)
val defaults : rule list

(* the "helper" lines of the profile's preferences *)
val of_preferences : string -> rule list
val to_preferences : rule list -> string

(* a mailcap file's rules: "type/subtype; command %s", a line each,
   '#' a comment, what follows a second ';' not read *)
val of_mailcap : string -> rule list

(* the first rule for a link's address, for a content type *)
val for_url : rule list -> string -> rule option
val for_type : rule list -> string -> rule option

(* the program's name, as said in the status bar *)
val name : rule -> string

(* the command: %u the address, %s the file (if any) *)
val command : rule -> url:string -> file:string option -> string list

(* the rules whose program is on the PATH *)
val available : < Cap.env; .. > -> rule list -> rule list

(* [run caps command]: the program started beside the browser, not
   waited for (the ones ended are, when the next one starts) *)
val run : < Cap.fork; Cap.exec; Cap.wait; .. > -> string list -> unit
