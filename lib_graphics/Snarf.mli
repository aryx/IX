(* The text that the window system's programs share, copied by one and
 * pasted by another (Plan 9's /dev/snarf, a file of rio's; mini-rio's
 * Dev_wm.snarf). When read, the file gives the last text copied; when
 * written, it takes that text, the whole of it.
 *
 *     mini-netscape: Ctrl+C       mini-rio's terminal: paste
 *        write "https://..."  ->  /dev/snarf  ->  read
 *
 * Without a window system (no /dev/snarf), nothing is copied and ""
 * is read.
 *
 * terminology:
 * Snarf is Plan 9's word (in rio's and acme's menus, after the Blit's
 * and sam's), where other systems say copy; the clipboard is the
 * Macintosh's word (1984) and Windows'.
 *
 * References: rio(4) of Plan 9's manual (snarf). *)

(* returns the text copied last, or "" if there is none *)
val read : < Cap.mouse ; .. > -> string

(* sets the text copied from now on *)
val write : < Cap.mouse ; .. > -> string -> unit
