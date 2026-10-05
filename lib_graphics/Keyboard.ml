(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Keyboard.mli *)

type t = { reads : bytes Event.channel; ctl : Unix.file_descr }

(* (consctl stays open: the console is raw while it is) *)
let init (caps : < Cap.keyboard; Cap.fork; .. >) =
  let ctl = Unix.openfile "/dev/consctl" [ Unix.O_WRONLY ] 0 in
  ignore (Unix.write_substring ctl "rawon" 0 5);
  { reads = Source.reader caps (Unix.openfile "/dev/cons" [ Unix.O_RDONLY ] 0) 64; ctl }

let receive (k : t) = ignore k.ctl; Event.wrap (Event.receive k.reads) Bytes.to_string
