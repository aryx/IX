(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-9pi's data (plan_9pi.md): Plan 9's kernel structures as records
 * and variants: the files (qids, directory entries, channels), the
 * namespace (mount points and their unions), the environment, the
 * processes and their segments; each group a process may share with
 * others (Plan 9's Pgrp, Egrp, Fgrp) a record the processes point to.
 *
 * How they hold together, from a process down (an arrow is a field;
 * what two processes may point to together is marked shared):
 *
 *     proc --- fgrp ----- fds: 0 1 2 3 ...    each a chan     (shared)
 *      |-- pgrp ----- mnt: mhead, mhead, ...                  (shared)
 *      |                    |-- mpt: chan     the mount point
 *      |                    '-- members: mount, mount, ...  its union
 *      |                                     '-- mchan: chan
 *      |-- egrp ----- vars: evar, evar, ...   #e's files      (shared)
 *      |-- rgrp ----- rend: the procs waiting in rendezvous   (shared)
 *      |-- slash, dot: chan                  where a name starts
 *      '-- segs: segment (Text) ---- pages: address -> page   (shared)
 *                segment (Data)  '-- image: chan, the program's file
 *                segment (Bss)
 *                segment (Stack)
 *
 *     chan: dev 'c', devno, qid       which file, of which device
 *           offset, opened            where a read is at, how opened
 *           fid                       a server's file: its number in 9P
 *
 * So everything a process has is a channel or a page, and a channel
 * is only a name for a file its device knows: the letter is looked up
 * in Dev's table at each use, and the device finds the rest by the
 * qid. rfork's flags (Sysproc) say, group by group, whether the child
 * gets the parent's record, a copy of it, or a new one: that is all a
 * thread, a process and a sandbox differ by.
 *
 * Read first by whoever reads the kernel: Kchan fills and walks the
 * name space, Proc the processes' states, Fault the segments' pages,
 * and each device (Dev) the channels that are its own.
 *
 * terminology:
 * A channel is not a pipe, nor another language's channel: Plan 9's
 * Chan is the kernel's handle on a file, what Unix splits between an
 * entry of the file table (the offset, the mode) and an inode or a
 * vnode (which file). A qid is to a server what an inode's number is
 * to a Unix file system: two channels are the same file when their
 * device, instance and qid path are the same (Kchan.same). And Pgrp,
 * a process group, is here the group of processes with one name
 * space; what Unix calls a process group, the processes a signal
 * from the terminal goes to, is Plan 9's note group (noteid). *)

(* (No Types.mli: the module is its types; the errors are Errors.) *)

(*****************************************************************************)
(* Files: qids, directory entries, open modes, channels *)
(*****************************************************************************)

(* a file's identity on its server (Plan 9's Qid): its path, unique on
 * the server, its version, whether a directory (QTDIR) or append-only,
 * exclusive (QTAPPEND, QTEXCL: the bits of the type byte) *)
type qid_type = Qt_dir | Qt_file

type qid = { path : int; vers : int; typ : qid_type }

(* a directory entry (Plan 9's Dir, as stat gives it): its mode's rwx
 * bits (DMDIR from the qid's type: 1 lsl 31 is past the Pi1's ints);
 * its length, d_lenhi 2^30s and d_length (below 2^30: a Pi1 int; an SD
 * card's 1GB partition is 2^30) *)
type dir = {
  d_name : string;
  d_qid : qid;
  d_perm : int;
  d_length : int;
  d_lenhi : int;
  d_atime : int;
  d_mtime : int;
  d_uid : string;
  d_gid : string;
  d_muid : string;
  d_type : char;
  d_dev : int;
}

(* an open's access (OREAD 0, OWRITE 1, ORDWR 2, OEXEC 3) and its flags
 * (OTRUNC 16, OCEXEC 32: closed by exec, ORCLOSE 64: removed by close) *)
type access = Oread | Owrite | Ordwr | Oexec

type mode = { access : access; trunc : bool; cexec : bool; rclose : bool }

(* a channel (Plan 9's Chan): a file of a device (its letter: '/' the
 * root, 'c' the console...; its instance: #ec's env, a pipe, a mount),
 * where it is, open or not; its name as the process named it (fd2path,
 * errors); a union directory's members when it was reached through a
 * mount point (its reads and creates go over them: Plan 9's umh); the
 * entry a directory's reading is at (dri) and its entries, taken at
 * the first read (snap); how many descriptors (and
 * other holders) have it (its device closes it at the last close); a
 * mounted file's 9P fid (devmnt's) *)
type chan = {
  dev : char;
  devno : int;
  mutable qid : qid;
  mutable offset : int;
  mutable opened : mode option;
  mutable cname : string;
  mutable umh : mount list;
  mutable dri : int;
  mutable snap : dir list;
  mutable cref : int;
  mutable fid : int;
}

(*****************************************************************************)
(* The namespace *)
(*****************************************************************************)

(* a union's member: the channel bound or mounted there; whether create
 * goes to it (MCREATE) *)
and mount = { mchan : chan; mcreate : bool }

(* a mount point and its union, in order (bind -b before, -a after, or
 * alone) *)
type mhead = { mpt : chan; mutable members : mount list }

(* a namespace (Plan 9's Pgrp): shared by rfork, copied by RFNAMEG *)
type pgrp = { mutable mnt : mhead list }

(* the environment (Egrp, #e's files): shared by rfork, copied by
 * RFENVG; its variables in devenv's order, the last qid path given; a
 * variable's qid path, its version *)
type evar = { ename : string; mutable evalue : string; epath : int; mutable evers : int }

type egrp = { mutable vars : evar list; mutable last_path : int }

(* the file descriptors (Fgrp): shared by rfork, copied by RFFDG; how
 * many processes share it *)
type fgrp = { fds : chan option array; mutable fref : int }

(*****************************************************************************)
(* Processes *)
(*****************************************************************************)

(* a segment of a process's memory, [base, top): its pages (by address:
 * their physical address), each given at its first touch (a fault):
 * from the program's file (text and data: its channel, the segment's
 * bytes' offset and length there) or zero (bss, stack). A segment may be
 * shared (text always, data and bss by rfork's RFMEM: how many
 * processes have it); the processes' tables map its pages as they
 * touch them. *)
type seg_kind = Text | Data | Bss | Stack

type segment = {
  kind : seg_kind;
  base : int;
  mutable top : int;
  image : chan option;
  fstart : int;
  flen : int;
  pages : (int, int) Hashtbl.t;
  mutable sref : int;
}

(* what a sleeping process waits for: a line typed, a child's exit (the
 * process's own pid), a pipe's data or room (its number), the clock, a
 * mount's 9P reply (its number), a rendezvous's partner (the process's
 * pid), a semaphore (its physical address), the mouse's next state, a
 * draw client's refresh (its id), a frame for an ether connection (its
 * number), an IP connection's data or state (its key) *)
type wait_chan =
  | Console_input | Kbd_input | Child_exit of int | Pipe_data of int | Pipe_room of int | Ticks | Mnt_reply of int
  | Rendez of int | Semaphore of int | Mouse_change | Draw_refresh of int | Ether_data of int | Ip_conv of int

(* a note's kind: sent by a process (NUser), one that ends the process
 * (NExit: a kill), a trap's (NDebug) *)
type note_flag = Nuser | Nexit | Ndebug

type state = Runnable | Running | Sleeping of wait_chan | Zombie

(* a child's end, as await gives it: its pid, its time (ms), its message
 * ("text pid: status", or "") *)
type waitmsg = { wpid : int; wtime : int; wmsg : string }

type proc = {
  pid : int;
  slot : int;
  mutable state : state;
  (* the parent (0: none, the boot process or RFNOWAIT), the children
   * to wait for, their ends (the last first, as pexit pushes them) *)
  mutable parent : int;
  mutable nchild : int;
  mutable waitq : waitmsg list;
  (* the memory: its table, its segments *)
  mutable pgdir : int;
  mutable segs : segment list;
  (* the files: the descriptors, the namespace, the environment, the
   * root and the current directory *)
  mutable fgrp : fgrp;
  mutable pgrp : pgrp;
  mutable egrp : egrp;
  mutable slash : chan;
  mutable dot : chan;
  (* notes: the handler (notify: 0 none), the note group *)
  mutable notify : int;
  mutable noteid : int;
  (* the last error (errstr), the program's name, when it started (the
   * ticks) *)
  mutable errstr : string;
  mutable text : string;
  mutable start : int;
  (* the system call it is in (/proc/n/status: "Pread"...), its
   * arguments' first bytes (/proc/n/args), NUL-separated, or a name it
   * gave itself (setargs: libthread's threadsetname) *)
  mutable psstate : string;
  mutable args : string;
  mutable setargs : bool;
  (* the notes posted, not yet delivered (NNOTE at most); one pending
   * (a sleep interrupted); in a handler (notified), the frame it runs
   * on (the user's NFrame, 0: none), the last one delivered *)
  mutable notes : (string * note_flag) list;
  mutable notepending : bool;
  mutable notified : bool;
  mutable ureg : int;
  mutable lastnote : string * note_flag;
  (* the alarm (its tick, 0: none) *)
  mutable alarm : int;
  (* the rendezvous group, the tag waited on and the value exchanged *)
  mutable rgrp : rgrp;
  mutable rendtag : int;
  mutable rendval : int;
}

(* a rendezvous group (Rgrp): its processes waiting, the last first *)
and rgrp = { mutable rend : proc list }
