(* Archives: a library as a target, and lib.a(foo.o) as the name of
 * one of its members.
 *
 * mk can depend on the members of an archive, which is how Plan 9's
 * mklib prototype rebuilds a library one object at a time:
 *
 *     $LIB: ${OFILES:%=$LIB(%)}          lib.a(a.8) lib.a(b.8) ...
 *         ar vu $LIB $newmember          only the members that changed
 *     $LIB(%.8):N: %.8                   a member comes from its .8
 *
 * The date stamp of lib.a(foo.o) is foo.o's date in the archive's
 * header, not a file's time. A member that is not in the archive (or
 * when there is no archive at all) has time 0, and is out of date. The
 * format is the same on Plan 9 and Unix:
 *
 *     "!<arch>\n"                                  8 bytes
 *     name[16] date[12] uid[6] gid[6] mode[8] size[10] "`\n"
 *                                                  60 bytes, then size
 *                                                  bytes, padded to even
 *
 * Two corrections from archive.c are kept: a member dated after its
 * archive was written gets the archive's time minus 1 ("new things in
 * old archives confuses mk"), and a date of 0 becomes 1. System V's
 * trailing '/' after a name is dropped. Long names (GNU ar's "//"
 * table) are not read, because only 2 of the 472 mkfiles use archives
 * at all, and they use Plan 9's short names.
 *
 * References: principia's archive.c (atimeof, atimes, atouch) and
 * include/ar.h; ar(6). *)

(* "lib.a(foo.o)" -> Some ("lib.a", "foo.o") *)
val split : string -> (string * string) option

(* do these contents start with the archive magic? *)
val is_archive : string -> bool

type t

(* [create ~read ~mtime]: [read file] gives the archive's contents
 * (None if it is missing), and [mtime file] gives its time. *)
val create : read:(string -> string option) -> mtime:(string -> float) -> t

(* the date stamp of "lib.a(foo.o)". The archive is read again only
 * when it has changed, or with [~force:true]. *)
val time : force:bool -> t -> string -> float

(* [touch_date ~now contents member] returns the archive's contents
 * with the date of [member] set to [now], for mk -t (archive.c's
 * atouch). *)
val touch_date : now:float -> string -> string -> string
