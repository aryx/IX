(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Devarch.mli *)

open Types
open Errors

(* the cpu: the Pi1's ARM1176, the Pi4's Cortex-A72 (its programs 32-bit arm's) *)
(* (its speed in MHz the file's last word, measured once, here: 0 under
 * the emulators, 9pi's there) *)
let mhz = Machine.cpu_mhz ()
let files = [ "cputype", (if Arch.name = "pi4" then "ARM Cortex-A72 0\n" else Printf.sprintf "ARM 1176JZF-S %d\n" mhz); "cputemp", "0\n" ]

let root = { path = 0; vers = 0; typ = Qt_dir }

let entries path =
  if path <> 0 then raise (Error enotdir)
  else
    let rec go i l = match l with
      | [] -> []
      | (name, _) :: r ->
          { Dev.dname = name; Dev.dqid = { path = i; vers = 0; typ = Qt_file }; Dev.dlength = 0; Dev.dperm = 0o444 }
          :: go (i + 1) r in
    go 1 files

let init () =
  let d = Dev.default 'P' "arch" in
  Dev.register { d with
    Dev.attach = (fun _ -> Dev.attach 'P' 0 root);
    Dev.walk = Dev.tab_walk entries (fun _ -> root);
    Dev.stat = Dev.tab_stat "#P" entries (fun _ -> root);
    Dev.dirs = Dev.tab_dirs entries;
    Dev.open_ = Dev.tab_open;
    Dev.read = (fun c n off ->
      let s = snd (List.nth files (c.qid.path - 1)) in
      if off >= String.length s then "" else String.sub s off (min n (String.length s - off)));
  }
