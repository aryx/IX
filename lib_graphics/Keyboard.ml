(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Keyboard.mli *)

type t = { reads : bytes Event.channel; ctl : Unix.file_descr; mutable part : string }

(* (consctl stays open: the console is raw while it is) *)
let init (caps : < Cap.keyboard; Cap.fork; .. >) =
  let ctl = Unix.openfile "/dev/consctl" [ Unix.O_WRONLY ] 0 in
  ignore (Unix.write_substring ctl "rawon" 0 5);
  { reads = Source.reader caps (Unix.openfile "/dev/cons" [ Unix.O_RDONLY ] 0) 64; ctl; part = "" }

(* a read may end in the middle of a character (an arrow is three
 * bytes): its start is kept for the next read *)
let receive (k : t) =
  ignore k.ctl;
  Event.wrap (Event.receive k.reads) (fun b ->
    let whole, part = Utf8.chars (k.part ^ Bytes.to_string b) in
    k.part <- part;
    whole)

let up = "\xef\x80\x8e" and down = "\xef\xa0\x80"
let left = "\xef\x80\x91" and right = "\xef\x80\x92"

(* /dev/kbd: a read is a message, k or K, the keys down (each its
 * character's bytes), a zero byte *)
type held = { messages : bytes Event.channel }
let held (caps : < Cap.keyboard; Cap.fork; .. >) =
  match Unix.openfile "/dev/kbd" [ Unix.O_RDONLY ] 0 with
  | fd -> Some { messages = Source.reader caps fd 256 }
  | exception Unix.Unix_error _ -> None
let message (h : held) = Event.wrap (Event.receive h.messages) Bytes.to_string
let keys (m : string) =
  let n = match String.index_opt m '\000' with Some i -> i | None -> String.length m in
  if n < 1 then [] else fst (Utf8.chars (String.sub m 1 (n - 1)))
let shift = "\xef\xa1\xa0" and ctrl = "\xef\xa1\xa2" and alt = "\xef\xa1\xa3"
