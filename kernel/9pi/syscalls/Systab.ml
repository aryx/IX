(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Systab.mli *)

open Types
open Errors
open Usermem

type call =
  | Nop | Rfork | Exec | Exits | Await | Brk | Open | Close | Dup | Fd2path | Pread | Pwrite | Seek
  | Create | Remove | Chdir | Stat | Fstat | Wstat | Fwstat | Bind | Mount | Unmount | Sleep | Alarm
  | Notify | Noted | Pipe | Segattach | Segdetach | Segfree | Segflush | Segbrk
  | Rendezvous | Semacquire | Semrelease | Tsemacquire | Fversion | Fauth | Errstr

let calls = [|
  Nop, "Nop"; Rfork, "Rfork"; Exec, "Exec"; Exits, "Exits"; Await, "Await"; Brk, "Brk";
  Open, "Open"; Close, "Close"; Dup, "Dup"; Fd2path, "Fd2path"; Pread, "Pread"; Pwrite, "Pwrite";
  Seek, "Seek"; Create, "Create"; Remove, "Remove"; Chdir, "Chdir"; Stat, "Stat"; Fstat, "Fstat";
  Wstat, "Wstat"; Fwstat, "Fwstat"; Bind, "Bind"; Mount, "Mount"; Unmount, "Unmount";
  Sleep, "Sleep"; Alarm, "Alarm"; Notify, "Notify"; Noted, "Noted"; Pipe, "Pipe";
  Segattach, "Segattach"; Segdetach, "Segdetach"; Segfree, "Segfree"; Segflush, "Segflush";
  Segbrk, "Segbrk"; Rendezvous, "Rendez"; Semacquire, "Semacquire"; Semrelease, "Semrelease";
  Tsemacquire, "Tsemacquire"; Fversion, "Fversion"; Fauth, "Fauth"; Errstr, "Errstr" |]

(* a permission argument: its rwx bits, DMDIR (bit 31, past the Pi1's
 * ints) as the int's sign (P9.perm) *)
let perm_arg words i =
  let b k = Char.code words.[(4 * i) + k] in
  (b 0 lor (b 1 lsl 8) lor (b 2 lsl 16) lor ((b 3 land 0x3f) lsl 24)) lor (if b 3 land 0x80 <> 0 then min_int else 0)

(* (the arguments' expressions as they were: OCaml evaluates them right
 * to left, which a bad one's error depends on) *)
let call (p : proc) c a words =
  let str i = user_string p a.(i) maxpath in
  match c with
  | Nop -> 0
  | Rfork -> Sysproc.sysrfork p a.(0)
  | Exec -> let name = str 0 in Sysproc.sysexec p name a.(1)
  | Exits -> Sysproc.sysexits p a.(0)
  | Await -> Sysproc.sysawait p a.(0) a.(1)
  | Brk -> Sysproc.sysbrk p a.(0)
  | Open -> Sysfile.sysopen p (str 0) a.(1)
  | Close -> Sysfile.sysclose p a.(0)
  | Dup -> Sysfile.sysdup p a.(0) a.(1)
  | Fd2path -> Sysfile.sysfd2path p a.(0) a.(1) a.(2)
  | Pread -> Sysfile.syspread p a.(0) a.(1) a.(2) (offset a.(3) a.(4))
  | Pwrite -> Sysfile.syspwrite p a.(0) a.(1) a.(2) (offset a.(3) a.(4))
  | Seek -> Sysfile.sysseek p a.(0) a.(1) a.(2) a.(3) a.(4)
  | Create -> Sysfile.syscreate p (str 0) a.(1) (perm_arg words 2)
  | Remove -> Sysfile.sysremove p (str 0)
  | Chdir -> Sysfile.syschdir p (str 0)
  | Stat -> Sysfile.sysstat p (str 0) a.(1) a.(2)
  | Fstat -> Sysfile.sysfstat p a.(0) a.(1) a.(2)
  | Wstat -> Sysfile.syswstat p (str 0) a.(1) a.(2)
  | Fwstat -> Sysfile.sysfwstat p a.(0) a.(1) a.(2)
  | Bind -> Sysfile.sysbind p (str 0) (str 1) a.(2)
  | Unmount -> Sysfile.sysunmount p a.(0) (str 1)
  | Mount -> Sysfile.sysmount p a.(0) (str 2) a.(3) (if a.(4) = 0 then "" else str 4)
  | Fauth -> Auth.sysfauth p a.(0) (if a.(1) = 0 then "" else str 1)
  | Fversion -> Auth.sysfversion p a.(0) a.(1) a.(2) a.(3)
  | Sleep -> Sysproc.syssleep p a.(0)
  | Alarm -> Sysproc.sysalarm p a.(0)
  | Notify -> Sysproc.sysnotify p a.(0)
  | Noted -> Sysproc.sysnoted p a.(0)
  | Rendezvous -> Sysproc.sysrendezvous p a.(0) a.(1)
  | Semacquire -> Syssema.syssemacquire p a.(0) (a.(1) <> 0)
  | Tsemacquire -> Syssema.systsemacquire p a.(0) a.(1)
  | Semrelease -> Syssema.syssemrelease p a.(0) a.(1)
  | Pipe -> Sysfile.syspipe p a.(0)
  | Errstr -> Sysproc.syserrstr p a.(0) a.(1)
  | _ -> raise (Error "not yet")
