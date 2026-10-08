(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Hid.mli *)

open Usbdesc

type kind = Keyboard | Mouse

let driven i =
  match i.cls, i.sub, i.proto, List.filter (fun e -> e.input && e.kind = 3) i.endpoints with
  | 3, 1, 1, e :: _ -> Some (Keyboard, e)
  | 3, 1, 2, e :: _ -> Some (Mouse, e)
  | _ -> None

let idle = function Keyboard -> 8 | Mouse -> 0

(* a key's scancode, by its number in a report (kb.c's sctab: USB's
 * numbers are their own; 4 is A, whose scancode is 0x1e) *)
let sctab = [|
  0x0; 0x0; 0x0; 0x0; 0x1e; 0x30; 0x2e; 0x20; 0x12; 0x21; 0x22; 0x23; 0x17; 0x24; 0x25; 0x26;
  0x32; 0x31; 0x18; 0x19; 0x10; 0x13; 0x1f; 0x14; 0x16; 0x2f; 0x11; 0x2d; 0x15; 0x2c; 0x2; 0x3;
  0x4; 0x5; 0x6; 0x7; 0x8; 0x9; 0xa; 0xb; 0x1c; 0x1; 0xe; 0xf; 0x39; 0xc; 0xd; 0x1a;
  0x1b; 0x2b; 0x2b; 0x27; 0x28; 0x29; 0x33; 0x34; 0x35; 0x3a; 0x3b; 0x3c; 0x3d; 0x3e; 0x3f; 0x40;
  0x41; 0x42; 0x43; 0x44; 0x57; 0x58; 0x63; 0x46; 0x77; 0x52; 0x47; 0x49; 0x53; 0x4f; 0x51; 0x4d;
  0x4b; 0x50; 0x48; 0x45; 0x35; 0x37; 0x4a; 0x4e; 0x1c; 0x4f; 0x50; 0x51; 0x4b; 0x4c; 0x4d; 0x47;
  0x48; 0x49; 0x52; 0x53; 0x56; 0x7f; 0x74; 0x75; 0x55; 0x59; 0x5a; 0x5b; 0x5c; 0x5d; 0x5e; 0x5f;
  0x78; 0x79; 0x7a; 0x7b |]

let keyup = 0x80

(* a scancode as given: the keys a PC keyboard added later (the
 * arrows, the right Alt) have 0xe0 before theirs *)
(* (0xe0 by its number: the kernel's compiler has no "\x" in a string) *)
let scan esc sc = (if esc then String.make 1 (Char.chr 0xe0) else "") ^ String.make 1 (Char.chr sc)
let key up k =
  let sc = if k < Array.length sctab then sctab.(k) else 0 in
  if sc = 0 then [] else [ scan (sc > 0x47 || sc = 0x38) (if up then sc lor keyup else sc) ]

(* the modifiers' byte: a bit a key (Ctrl 0, Shift 1, Alt 2 at the
 * left; the same from 4 at the right); each bit that changed is a key
 * down or up *)
let modifiers now before =
  let one mask esc sc =
    if now land mask <> 0 && before land mask = 0 then [ scan esc sc ]
    else if now land mask = 0 && before land mask <> 0 then [ scan esc (sc lor keyup) ]
    else [] in
  one 0x11 false 0x1d @ one 0x02 false 0x2a @ one 0x20 false 0x36 @ one 0x04 false 0x38 @ one 0x40 true 0x38

(* what changed between two reports *)
let scancodes report before =
  let keys s = List.filter (fun k -> k <> 0) (List.init 6 (fun i -> Char.code s.[i + 2])) in
  let now = keys report and was = keys before in
  modifiers (Char.code report.[0]) (Char.code before.[0])
  @ List.concat_map (key false) (List.filter (fun k -> not (List.mem k was)) now)
  @ List.concat_map (key true) (List.filter (fun k -> not (List.mem k now)) was)

(* the report before; the key that repeats (its scancode: the last one
 * that went down, until a key goes up); how many reports the same *)
type keyboard = { before : string; held : string option; same : int }

let keyboard = { before = String.make 8 '\000'; held = None; same = 0 }

let typed st report =
  let n = min 8 (String.length report) in
  let report = String.sub report 0 n ^ String.make (8 - n) '\000' in
  (* (too short; or too many keys held: the keyboard says so in all its six places) *)
  if n < 3 || (report.[2] <> '\000' && String.sub report 2 6 = String.make 6 report.[2]) then st, []
  else begin
    let codes = scancodes report st.before in
    let down = List.filter (fun s -> Char.code s.[String.length s - 1] land keyup = 0) codes in
    let keys_changed = String.sub report 2 6 <> String.sub st.before 2 6 in
    let held, same =
      if codes = [] then st.held, st.same + 1
      else if keys_changed && down <> [] then Some (List.nth down (List.length down - 1)), 0
      else if keys_changed then None, 0
      else st.held, 0 in
    { before = report; held = held; same = same },
    (match held with Some s when same >= 5 && codes = [] -> [ s ] | _ -> codes)
  end

let moved report =
  if String.length report < 3 then None
  else begin
    let signed b = if b > 127 then b - 256 else b in
    let b = Char.code report.[0] in
    (* the buttons: USB's are left, right, middle *)
    let buttons = (b land 1) lor ((b land 2) lsl 1) lor ((b land 4) lsr 1)
                  lor (if String.length report > 3 then (match report.[3] with '\001' -> 8 | '\255' -> 16 | _ -> 0) else 0) in
    Some (signed (Char.code report.[1]), signed (Char.code report.[2]), buttons)
  end
