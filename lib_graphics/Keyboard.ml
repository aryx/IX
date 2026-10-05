(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Keyboard.mli *)

type t = { reads : bytes Event.channel; ctl : Unix.file_descr; mutable part : string }

(* (consctl stays open: the console is raw while it is) *)
let init (caps : < Cap.keyboard; Cap.fork; .. >) =
  let ctl = Unix.openfile "/dev/consctl" [ Unix.O_WRONLY ] 0 in
  ignore (Unix.write_substring ctl "rawon" 0 5);
  { reads = Source.reader caps (Unix.openfile "/dev/cons" [ Unix.O_RDONLY ] 0) 64; ctl; part = "" }

(* a character's bytes, by its first one (UTF-8) *)
let length c = if c < '\xc0' then 1 else if c < '\xe0' then 2 else if c < '\xf0' then 3 else 4

(* a string's characters, each its bytes; and the bytes of a last one that is not whole *)
let chars s =
  let rec go o acc =
    if o >= String.length s then List.rev acc, ""
    else let n = length s.[o] in
      if o + n > String.length s then List.rev acc, String.sub s o (String.length s - o)
      else go (o + n) (String.sub s o n :: acc) in
  go 0 []

(* a read may end in the middle of a character (an arrow is three
 * bytes): its start is kept for the next read *)
let receive (k : t) =
  ignore k.ctl;
  Event.wrap (Event.receive k.reads) (fun b ->
    let whole, part = chars (k.part ^ Bytes.to_string b) in
    k.part <- part;
    whole)

let up = "\xef\x80\x8e" and down = "\xef\xa0\x80"
