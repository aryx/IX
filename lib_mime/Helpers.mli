(* Helpers: what a program does not show itself is given to a program
   that does. These are Mosaic's and Netscape's "helper applications".
   They get what mini-netscape does not show, and all that mini-files
   is asked to open (by the file's content type, from File_kind).

   A rule is a site or a content type, and a command:

     youtube.com/watch   mpv %u         a link to a YouTube film
     application/pdf     mini-page %s   a PDF file
     mailto:             mini-pim write=%u
                                        a link to write to someone

   A rule for a **site** (a host, and what the path begins with; it also
   covers the host's subdomains, such as www.youtube.com) is taken when
   a link to it is clicked. The program is given the address (%u) and
   is run beside the browser, and the page stays where it is. A rule
   for a **content type** (type/subtype, or type/* ) is taken when a
   document of that type arrives. Its bytes are written to a file, the
   program is given the file (%s), and the page says so.

   The rules come, in this order, from:
   - the profile's preferences, one line each ("helper
     youtube.com/watch mpv %u", "helper application/pdf gv %s");
   - ~/.mailcap (RFC 1524, metamail's file, which Netscape on Unix
     read: "video/mp4; mpv %s");
   - the built-in rules. YouTube's films go to mpv (which plays a
     YouTube address with yt-dlp), a PDF file to mini-page (ix's page),
     and a mailto: link to mini-pim's composer. A site ending in ':' is
     a scheme's. Netscape 2 had its own mail window, Messenger; here the
     suite's mail is the one place where mail is written and sent. Then
     come the rules for what else ix's programs read: PNG and JPEG
     pictures go to mini-page; sounds, videos, GIF pictures and ABC
     tunes to mini-play; HTML to mini-netscape; and text to mini-emacs.
   A rule whose program is not on the PATH is left out (Netscape.ml
   does this with [available]). So on ix, without mpv, a link to
   YouTube is followed like any other.

   cs-history:
   NCSA Mosaic (1993) showed HTML, GIF and XBM itself and nothing else:
   a PostScript file went to ghostview, a sound to the audio player,
   an MPEG film to mpeg_play, by the "mailcap" file of metamail
   (Nathaniel Borenstein, Bellcore, 1991), written for MIME's
   multimedia mail. Netscape kept the file, called the programs helper
   applications, and added plug-ins (1995), programs that run inside
   the page, which is how Flash and Acrobat came to be shown. Browsers
   then drew PDF and played films themselves (Chrome's PDF viewer,
   2010; HTML5's <video>), and the helper became the download bar's
   "Open with".
   Here the helper is back, for what this browser does not do. *)

type rule = { site : string option; kind : string option; run : string list }

(* the built-in rules *)
val defaults : rule list

(* the "helper" lines of the profile's preferences *)
val of_preferences : string -> rule list
val to_preferences : rule list -> string

(* a mailcap file's rules, one per line as "type/subtype; command %s".
   A line starting with '#' is a comment, and what follows a second ';'
   is not read. *)
val of_mailcap : string -> rule list

(* the rules of ~/.mailcap, or none if it is not there *)
val mailcap : < Cap.env; Cap.open_in; .. > -> rule list

(* the first rule for a link's address, and the first rule for a
   content type *)
val for_url : rule list -> string -> rule option
val for_type : rule list -> string -> rule option

(* the program's name, as shown in the status bar *)
val name : rule -> string

(* the command, where %u becomes the address and %s the file (if there
   is one) *)
val command : rule -> url:string -> file:string option -> string list

(* the rules whose program is on the PATH *)
val available : < Cap.env; .. > -> rule list -> rule list

(* the rules of ~/.mailcap, then the built-in ones, keeping those on the
   PATH. This is what a program with no preferences of its own asks for
   (mini-open, mini-files). *)
val rules : < Cap.env; Cap.open_in; .. > -> rule list

(* whether a program started can have a screen of its own. It cannot on
   mini-9pi's bare screen, without mini-rio. *)
val windows : unit -> bool

(* [run caps command] starts the program beside this one, without
   waiting for it (the programs that have ended are waited for when the
   next one starts). Under mini-rio, it starts the program in a new
   window, through /dev/wctl, so the command must have whole paths:
   the program's directory is rio's. *)
val run : < Cap.exec; Cap.wait; Cap.open_out; .. > -> string list -> unit
