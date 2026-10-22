(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Snarf.mli. The capability is the mouse's, as Cursor's: the file
 * is the window system's, beside /dev/mouse and /dev/cursor *)

let read (_ : < Cap.mouse ; .. >) : string =
  try
    let fd = Unix.openfile "/dev/snarf" [ Unix.O_RDONLY ] 0 in
    let buf = Buffer.create 256 and chunk = Bytes.create 4096 in
    let rec loop () =
      let n = Unix.read fd chunk 0 4096 in
      if n > 0 then (Buffer.add_subbytes buf chunk 0 n; loop ())
    in
    loop ();
    Unix.close fd;
    Buffer.contents buf
  with Unix.Unix_error _ -> ""

let write (_ : < Cap.mouse ; .. >) (s : string) : unit =
  try
    let fd = Unix.openfile "/dev/snarf" [ Unix.O_WRONLY; Unix.O_TRUNC ] 0 in
    ignore (Unix.write_substring fd s 0 (String.length s));
    Unix.close fd
  with Unix.Unix_error _ -> ()
