(* Names, channels and the namespace (principia's chan.c, pgrp.c,
 * sysfile.c's fd functions). A path is walked from the process's root
 * ("/": cleaned first, ".." lexical, as Plan 9's cleanname), its current
 * directory, or a device ("#c/cons"); at each step, a mount point (the
 * process's Pgrp) is replaced by what is bound there: a union, whose
 * members are tried in order. Binding adds to a union (MREPL, MBEFORE,
 * MAFTER; MCREATE: where create goes). The file descriptors too.
 *
 * A name space is a list of mount points, each with its union. The
 * boot process's, after Main's binds and boot.rc's first lines:
 *
 *     mount point    its union, in order           made by
 *     /dev           its own, #c, #P, #S, #i, #m   bind -a '#P' /dev ...
 *     /env           #e (create), #ec              bind -c '#e' /env
 *     /srv           #s (create)                   bind -c '#s' /srv
 *     /bin           its own, /boot                bind -a /boot /bin
 *     /proc          #p                            bind '#p' /proc
 *     /mnt/fat       a server's root (#M)          mount /srv/dos /mnt/fat
 *
 *     bind new old       old is now new       (MREPL)
 *     bind -b new old    new first, then what old was    (MBEFORE)
 *     bind -a new old    what old was, then new          (MAFTER)
 *     -c                 and files created in old go to new (MCREATE)
 *
 * A name's walk, open("/dev/cons"):
 *
 *     "/"      the process's root: a channel on '#/'s root
 *     "dev"    '#/' is asked (Dev's walk): its dev directory
 *              that channel is a mount point: replaced by the first
 *              member's, the whole union remembered in it (umh)
 *     "cons"   each member is asked in turn: '#/'s dev has no cons,
 *              #c has: a channel of the device 'c', the walk's result
 *
 * and the same union is why ls /dev lists the files of six devices
 * ([dirs]), and why a file created in /env is #e's and no one
 * else's. A name that starts with # goes to a device directly and
 * crosses no mount point: that is how a name space is built from
 * nothing, and what a sandbox must forbid.
 *
 * The union is found by the mount point's identity (its device, its
 * instance, its qid: [same]), not by its name: /dev reached by another
 * path is the same mount point.
 *
 * A mount is a bind whose new is a server's root: Sysfile's sysmount
 * asks Devmnt for it (an attach on the connection) and binds it. The
 * name space does not know the difference.
 *
 * plan9-is-cleaner:
 * The name space is a process's, not the machine's. In Unix there is
 * one mount table, changing it changes every program's view, and so
 * only root may: a user's removable disk, a network file system, a
 * private /tmp all needed a privileged helper. Here bind and mount
 * are anyone's, because they change the caller's view only (and its
 * children's, until one asks for a copy: rfork's RFNAMEG). Much then
 * needs no mechanism of its own: $path is /bin alone, a union of the
 * directories a user wants; a window system gives each window its
 * own /dev/cons by a mount; another machine's network is used by
 * mounting its /net.
 *
 * comeback:
 * Linux took per-process mount tables in 2002 (the mount name space,
 * the first of several kinds) and union directories in 2014 (overlayfs,
 * after years of others outside the kernel's tree). Together they
 * are what a container's file system is made of: an image's layers
 * are a union's members, the top one the create's. Mounting still
 * asked for root there, until user name spaces (2013) made a root of
 * one's own.
 *
 * design:
 * Dot-dot is taken off the name, not asked of the file. A directory
 * in a union, or bound in two places, has no single parent to
 * answer; so a channel remembers the name it was reached by (cname),
 * and ".." walks that name's parent again from the root. cd /bin; cd
 * .. is then always /, whatever /bin is made of.
 *
 * References: Rob Pike, Dave Presotto, Ken Thompson, Howard Trickey
 * and Phil Winterbottom, "The Use of Name Spaces in Plan 9" (1992;
 * Operating Systems Review, 1993): the paper for this file. Rob
 * Pike, "Lexical File Names in Plan 9, or, Getting Dot-Dot Right"
 * (USENIX, 2000). bind(1), bind(2) and namespace(4) in the Plan 9
 * manual. principia's Kernel.nw (chan.c's namec and walk, pgrp.c's
 * cmount). *)

open Types
open Errors

(* the flags of bind and mount *)
val mrepl : int
val mbefore : int
val mafter : int
val mcreate : int

(* an open's mode from its bits (openmode: Error on unknown bits) *)
val mode_of_int : int -> mode

(* a copy of a channel, a file of its own (devmnt's: a new fid); an
 * unopened channel no one holds dropped (devmnt: its fid clunked) *)
val clone : chan -> chan
val clunk : chan -> unit

(* the same file (eqchan: its device, instance, qid path) *)
val same : chan -> chan -> bool

(* [namec p path]: the channel of [path], through the mount points; the
 * last element's too unless [nomount] (a mount point itself: bind's
 * and mount's target). Error "'path' error" when an element is missing
 * (the path up to that element). *)
val namec : proc -> string -> chan
val namec_nomount : proc -> string -> chan

(* [named path f]: f's error named with the whole path (namec's, after
 * the walk: an open's, a create's), unless the path has no names *)
val named : string -> (unit -> 'a) -> 'a

(* [create p path mode perm]: the file created (in the directory's
 * union: its first MCREATE member) and opened; an existing one opened
 * and truncated (Error eexist with OEXCL) *)
val create : proc -> string -> mode -> int -> chan

(* a channel opened, by its device (possibly another channel); one more
 * holder; one less (the device's close at the last) *)
val open_ : chan -> mode -> chan
val incref : chan -> unit
val close : chan -> unit

(* a directory's entries, over its union *)
val dirs : chan -> dir list

(* [bind pg newc old flag]: newc added to the union at old (cmount:
 * Error emount when one is a directory and not the other); [unmount
 * pg newc old] (None: all of old's union) *)
val bind : pgrp -> chan -> chan -> int -> unit
val unmount : pgrp -> chan option -> chan -> unit

(* a namespace's copy (RFNAMEG: pgrpcpy) *)
val pgrp_copy : pgrp -> pgrp

(* a free descriptor given the channel (Error enofd); [fdalloc_at]:
 * that one (dup's second argument), its channel closed *)
val fdalloc : proc -> chan -> int
val fdalloc_at : proc -> int -> chan -> unit

(* [fdtochan p fd access]: the descriptor's channel, open for [access]
 * (None: any; Error ebadfd, ebadusefd) *)
val fdtochan : proc -> int -> access option -> chan

(* descriptors' tables: a copy (RFFDG: dupfgrp), a new empty one
 * (RFCFDG), one released (closefgrp: its channels closed by its last
 * process) *)
val fgrp_copy : fgrp -> fgrp
val fgrp_new : unit -> fgrp
val fgrp_close : fgrp -> unit
val nfd : int

(* the last element of a path *)
val basename : string -> string
