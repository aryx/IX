(* Names, channels and the namespace (principia's chan.c, pgrp.c, and
 * sysfile.c's fd functions). A path is walked from the process's root
 * ("/": the path is cleaned first, and ".." is lexical, as with Plan
 * 9's cleanname), from its current directory, or from a device
 * ("#c/cons"). At each step, a mount point (in the process's Pgrp) is
 * replaced by what is bound there: a union, whose members are tried in
 * order. Binding adds to a union (MREPL, MBEFORE, MAFTER; MCREATE says
 * where create goes). The file descriptors are here too.
 *
 * A name space is a list of mount points, each with its union. Here is
 * the boot process's, after Main's binds and boot.rc's first lines:
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
 * Here is a name's walk, for open("/dev/cons"):
 *
 *     "/"      the process's root: a channel on '#/'s root
 *     "dev"    '#/' is asked (Dev's walk) and gives its dev directory;
 *              that channel is a mount point, so it is replaced by the
 *              first member's, the whole union remembered in it (umh)
 *     "cons"   each member is asked in turn: '#/'s dev has no cons,
 *              #c has one: a channel of the device 'c', the result
 *
 * The same union is why ls /dev lists the files of six devices
 * ([dirs]), and why a file created in /env is #e's and no one else's.
 * A name that starts with # goes to a device directly and crosses no
 * mount point: that is how a name space is built from nothing, and
 * what a sandbox must forbid.
 *
 * The union is found by the mount point's identity (its device, its
 * instance and its qid: [same]), not by its name, so /dev reached by
 * another path is the same mount point.
 *
 * A mount is a bind whose new is a server's root: Sysfile's sysmount
 * asks Devmnt for it (with an attach on the connection) and binds it.
 * The name space does not know the difference.
 *
 * plan9-is-cleaner:
 * The name space belongs to a process, not to the machine. In Unix
 * there is one mount table, and changing it changes every program's
 * view, so only root may change it: a user's removable disk, a network
 * file system and a private /tmp all needed a privileged helper. Here
 * anyone may bind and mount, because these change only the caller's
 * view (and its children's, until one asks for a copy with rfork's
 * RFNAMEG). Much then needs no mechanism of its own: $path is /bin
 * alone, a union of the directories a user wants; a window system
 * gives each window its own /dev/cons by a mount; another machine's
 * network is used by mounting its /net.
 *
 * comeback:
 * Linux took per-process mount tables in 2002 (the mount name space,
 * the first of several kinds) and union directories in 2014 (overlayfs,
 * after years of others outside the kernel's tree). Together they are
 * what a container's file system is made of: an image's layers are a
 * union's members, and the top one gets the creates. Mounting still
 * required root there, until user name spaces (2013) let anyone have a
 * root of their own.
 *
 * design:
 * Dot-dot is taken off the name, not asked of the file. A directory in
 * a union, or bound in two places, has no single parent to answer
 * with. So a channel remembers the name it was reached by (cname), and
 * ".." walks that name's parent again from the root. cd /bin; cd .. is
 * then always /, whatever /bin is made of.
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

(* an open's mode, from its bits (openmode; Error on unknown bits) *)
val mode_of_int : int -> mode

(* [clone c] makes a copy of a channel, which is a file of its own (for
 * devmnt, a new fid). [clunk c] drops an unopened channel that no one
 * holds (devmnt clunks its fid). *)
val clone : chan -> chan
val clunk : chan -> unit

(* whether two channels are the same file (eqchan: the same device,
 * instance and qid path) *)
val same : chan -> chan -> bool

(* [namec p path] is the channel of [path], walked through the mount
 * points. The last element's mount point is crossed too, except with
 * [nomount], which gives the mount point itself (bind's and mount's
 * target). It raises Error "'path' error" when an element is missing,
 * with the path up to that element. *)
val namec : proc -> string -> chan
val namec_nomount : proc -> string -> chan

(* [named path f] runs f and names its error with the whole path, as
 * namec does, for an error after the walk (an open's, a create's),
 * unless the path has no names *)
val named : string -> (unit -> 'a) -> 'a

(* [create p path mode perm] creates the file (in the directory's
 * union, in its first MCREATE member) and opens it. An existing file is
 * opened and truncated (Error eexist with OEXCL). *)
val create : proc -> string -> mode -> int -> chan

(* [open_] opens a channel by its device (the result may be another
 * channel); [incref] adds one holder; [close] removes one (the device
 * closes the channel at the last) *)
val open_ : chan -> mode -> chan
val incref : chan -> unit
val close : chan -> unit

(* a directory's entries, over all its union *)
val dirs : chan -> dir list

(* [bind pg newc old flag] adds newc to the union at old (cmount). It
 * raises Error "inconsistent mount", Plan 9's Emount, when one is a
 * directory and the other is not. [unmount pg newc old] takes newc out
 * of it (None takes all of old's union). *)
val bind : pgrp -> chan -> chan -> int -> unit
val unmount : pgrp -> chan option -> chan -> unit

(* a copy of a namespace (RFNAMEG: pgrpcpy) *)
val pgrp_copy : pgrp -> pgrp

(* [fdalloc] gives the channel a free descriptor (Error enofd).
 * [fdalloc_at] gives it that descriptor (dup's second argument), and
 * closes the channel that was there. *)
val fdalloc : proc -> chan -> int
val fdalloc_at : proc -> int -> chan -> unit

(* [fdtochan p fd access] is the descriptor's channel, which must be
 * open for [access] (None accepts any; Error ebadfd, ebadusefd) *)
val fdtochan : proc -> int -> access option -> chan

(* tables of descriptors: [fgrp_copy] makes a copy (RFFDG: dupfgrp),
 * [fgrp_new] a new empty one (RFCFDG), and [fgrp_close] releases one
 * (closefgrp: its last process closes its channels) *)
val fgrp_copy : fgrp -> fgrp
val fgrp_new : unit -> fgrp
val fgrp_close : fgrp -> unit
val nfd : int

(* the last element of a path *)
val basename : string -> string
