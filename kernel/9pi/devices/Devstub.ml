(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Devstub.mli *)

open Types
open Errors

let root = { path = 0; vers = 0; typ = Qt_dir }

let stub dc name attached =
  let entries path = if path = 0 then [] else raise (Error enotdir) in
  let d = Dev.default dc name in
  Dev.register { d with
    Dev.attach = (fun _ -> attached (); Dev.attach dc 0 root);
    Dev.walk = Dev.tab_walk entries (fun _ -> root);
    Dev.stat = Dev.tab_stat ("#" ^ String.make 1 dc) entries (fun _ -> root);
    Dev.dirs = Dev.tab_dirs entries;
    Dev.open_ = Dev.tab_open;
  }


(* kbmap's letter a rune, κ (U+03BA): a private byte *)
let kbmap () = let d = Char.chr 0xba in stub d "kbmap" (fun () -> ()); Dev.set_rune d 0x3ba
let uart () = stub 't' "uart" (fun () -> ())
