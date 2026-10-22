(* The text the window system's programs share, copied by one and
 * pasted by another (Plan 9's /dev/snarf, a file of rio's; mini-rio's
 * Dev_wm.snarf): read, it is the last text copied; written, it is
 * that text, the whole of it.
 *
 *     mini-netscape: Ctrl+C       mini-rio's terminal: paste
 *        write "https://..."  ->  /dev/snarf  ->  read
 *
 * Without a window system (no /dev/snarf), nothing is copied and ""
 * is read.
 *
 * terminology:
 * Snarf is Plan 9's word (rio's and acme's menus, after the Blit's
 * and sam's), where other systems say copy; the clipboard is the
 * Macintosh's (1984) and Windows'.
 *
 * References: rio(4) of Plan 9's manual (snarf). *)

(* the text copied last, "" if none *)
val read : < Cap.mouse ; .. > -> string

(* the text copied from now on *)
val write : < Cap.mouse ; .. > -> string -> unit
