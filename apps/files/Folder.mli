(* Folder: a directory as mini-files shows it: its entries, in an order,
   their sizes and days in words, and the parents of a path.

       /home/pad/docs --list--> entries --sort--> folders first, then
                                 (Sys_plan9's      files, by name, size
                                  dirread)         or day

   cs-history:
   The folder as a window of icons is the Xerox Star's (1981): a
   document is a picture on a desktop, opened by pointing, what it holds
   decides what opens it, and there is no program to name. The
   Macintosh's Finder (1984) took it to where people could buy it, one
   window a folder, each remembering its place. Norton Commander (Peter
   Norton's, John Socha's, 1986) went the other way on the same machines
   as DOS's command line: two panes of lists, the keys F5 and F6 copying
   and moving from one to the other, for those who knew what a file is.
   Windows Explorer (1995), and a list with a tree beside it, is what
   most people have used since.

   plan9-is-cleaner:
   Plan 9, which had rio, had no file manager, and did not want one:
   any window can show a directory (ls, lc), a name on the screen can be
   pointed at to open it, by the plumber (2002), which is rules over
   text and not over a file's kind. Acme's directory window is a list
   one clicks in, and it is the nearest thing. That answer is for someone
   who lives in the shell; this program is for someone who does not. *)

type entry = {
  name : string;
  is_dir : bool;
  size : int; (* bytes *)
  mtime : float; (* seconds *)
}

type order = By_name | By_size | By_day

(* what the directory holds, unsorted, "." and ".." not among them;
   Unix_error if it cannot be read *)
val list : < Cap.readdir ; .. > -> string -> entry list

(* folders first; in the order given, the other way when [reversed] *)
val sort : order -> reversed:bool -> entry list -> entry list

(* "1.2 MB", "31 KB", "120 bytes" *)
val size_text : int -> string

(* "2026-10-30", the day in UTC as ls's *)
val day_text : float -> string

(* the path and each of its parents to [root], the outermost first, each
   with the name to show: [parents ~root:"/" "/a/b"] is
   [("/", "/"); ("a", "/a"); ("b", "/a/b")]; [root] itself is shown "/" *)
val parents : root:string -> string -> (string * string) list

(* the directory above, not above [root] *)
val parent : root:string -> string -> string

(* [join dir name]: without a second '/' in the root *)
val join : string -> string -> string

(* Changing files. Nothing here overwrites: a name that is taken is
   [Refused], where Linux's rename would have replaced it. The window waits
   while a big tree is copied.

   Moving to another folder is a copy and then a removal, as mv's on
   Plan 9, whose rename stays in its directory: the source goes only once
   the copy is whole; a copy that fails halfway removes what it made.

   A symbolic link (Linux's) is not followed: removed, it is the link
   that goes; in a copy it is [Refused], the folder it may point to, even
   a parent, not being part of the tree. A pipe or a device is refused
   too: reading one may never end. *)

(* said in words, for the status line; also Unix_error from the system *)
exception Refused of string

type caps = < Cap.readdir ; Cap.open_in ; Cap.open_out >

val exists : < caps ; .. > -> string -> bool

(* a name in one folder: no '/', not "." nor ".." *)
val good_name : string -> bool

(* "copy of a", then "copy 2 of a", for a copy in its own folder *)
val copy_name : taken:(string -> bool) -> string -> string

(* [copy caps from dest], [move caps from dest]: whole paths, a tree or a
   file; [dest] not in [from] itself *)
val copy : < caps ; .. > -> string -> string -> unit
val move : < caps ; .. > -> string -> string -> unit

(* [rename caps path name]: in the folder it is in *)
val rename : < caps ; .. > -> string -> string -> unit

(* a file, or a folder with all it holds *)
val remove : < caps ; .. > -> string -> unit

val make_folder : < caps ; .. > -> string -> unit
