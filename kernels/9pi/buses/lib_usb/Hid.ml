(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Hid.mli *)

open Usbdesc

(* a field of a report: after which byte (the report's number, if it
 * has one), from which bit, how many, signed or not *)
type field = { at : int; bits : int; signed : bool }

type layout = {
  id : int;
  x : field;
  y : field;
  wheel : field option;
  buttons : (int * field) list;
}

type mouse = Boot | Report of layout
type kind = Keyboard | Mouse of mouse

let driven i =
  match
    ( i.cls,
      i.sub,
      i.proto,
      List.filter (fun e -> e.input && e.kind = 3) i.endpoints )
  with
  | 3, 1, 1, e :: _ -> Some (Keyboard, e)
  | 3, 1, 2, e :: _ -> Some (Mouse Boot, e)
  | _ -> None

let idle = function Keyboard -> 8 | Mouse _ -> 0

(* the length of an interface's report descriptor, as its HID
 * descriptor (type 0x21) in the configuration's says: 0 if none *)
let report_length conf iface =
  let rec go i current =
    if i + 1 >= String.length conf || Char.code conf.[i] = 0 then 0
    else begin
      let len = Char.code conf.[i] and typ = Char.code conf.[i + 1] in
      if typ = 4 && i + 2 < String.length conf then
        go (i + len) (Char.code conf.[i + 2])
      else if typ = 0x21 && current = iface && i + 8 < String.length conf then
        le16 conf (i + 7)
      else go (i + len) current
    end
  in
  go 0 (-1)

(* A report descriptor read (HID's section 6.2.2): items of a byte, its
 * size (0, 1, 2 or 4 bytes after it), its type (main, global, local)
 * and its tag. The globals stay until changed (the usage page, a
 * field's size, how many, the report's number, the least value); the
 * locals are the next main item's (its usages); a main Input item is
 * that many fields of the report, one after the other. What a mouse
 * needs: the generic desktop's X (page 1, usage 0x30), Y (0x31) and
 * wheel (0x38), and the buttons (page 9, usages 1 to 3), all in the
 * report that has X. None if it has no X and Y. *)
let layout desc =
  let page = ref 0
  and size = ref 0
  and count = ref 0
  and id = ref 0
  and least = ref 0 in
  let usages = ref [] and umin = ref (-1) and umax = ref (-1) in
  (* the fields found: (page, usage, report's number, field) *)
  let found = ref [] in
  (* each report's bits so far, by its number *)
  let offsets = ref [] in
  let offset n = try List.assoc n !offsets with Not_found -> 0 in
  let n = String.length desc in
  let rec go i =
    if i < n then begin
      let b = Char.code desc.[i] in
      if b = 0xfe then
        go (i + 3 + if i + 1 < n then Char.code desc.[i + 1] else 0)
      else begin
        let sz = match b land 3 with 3 -> 4 | k -> k in
        let rec value k acc =
          if k < 0 then acc
          else
            value (k - 1)
              ((acc lsl 8)
              lor if i + 1 + k < n then Char.code desc.[i + 1 + k] else 0)
        in
        let v = value (sz - 1) 0 in
        let signed =
          if sz > 0 && sz < 4 && v land (1 lsl ((8 * sz) - 1)) <> 0 then
            v - (1 lsl (8 * sz))
          else v
        in
        (match ((b lsr 2) land 3, b lsr 4) with
        | 1, 0 -> page := v
        | 1, 1 -> least := signed
        | 1, 7 -> size := v
        | 1, 8 -> id := v
        | 1, 9 -> count := v
        | 2, 0 -> usages := !usages @ [ v ]
        | 2, 1 -> umin := v
        | 2, 2 -> umax := v
        | 0, 8 ->
            (* an Input: count fields, the constant ones (bit 0) padding *)
            let start = offset !id in
            if v land 1 = 0 then
              for k = 0 to !count - 1 do
                let usage =
                  if !usages <> [] then
                    List.nth !usages (min k (List.length !usages - 1))
                  else if !umin >= 0 then !umin + k
                  else -1
                in
                let pg, u =
                  if usage > 0xffff then (usage lsr 16, usage land 0xffff)
                  else (!page, usage)
                in
                found :=
                  ( pg,
                    u,
                    !id,
                    {
                      at = start + (k * !size);
                      bits = !size;
                      signed = !least < 0;
                    } )
                  :: !found
              done;
            offsets :=
              (!id, start + (!count * !size))
              :: List.filter (fun (k, _) -> k <> !id) !offsets
        | _ -> ());
        (* (a main item: the locals are spent) *)
        if (b lsr 2) land 3 = 0 then begin
          usages := [];
          umin := -1;
          umax := -1
        end;
        go (i + 1 + sz)
      end
    end
  in
  go 0;
  let find pg u =
    List.filter (fun (p, us, _, _) -> p = pg && us = u) (List.rev !found)
  in
  match find 1 0x30 with
  | (_, _, rid, x) :: _ -> (
      let one pg u =
        match List.filter (fun (_, _, r, _) -> r = rid) (find pg u) with
        | (_, _, _, f) :: _ -> Some f
        | [] -> None
      in
      match one 1 0x31 with
      | Some y ->
          let buttons =
            List.concat
              (List.map
                 (fun u ->
                   match one 9 u with Some f -> [ (u, f) ] | None -> [])
                 [ 1; 2; 3 ])
          in
          Some { id = rid; x; y; wheel = one 1 0x38; buttons }
      | None -> None)
  | [] -> None

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
(* (from 0x47, Home's: kb.c's hasesc1 says > 0x47, and Home came
 * without its 0xe0, the keypad's 7, which Kbd does not make Home; the
 * keypad's 7 is Home now, as its 8 was Up already.
 * old: sc > 0x47 || sc = 0x38) *)
let key up k =
  let sc = if k < Array.length sctab then sctab.(k) else 0 in
  if sc = 0 then [] else [ scan (sc >= 0x47 || sc = 0x38) (if up then sc lor keyup else sc) ]

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

(* the wheel's notches as Plan 9's buttons: away from you (more than
 * 0) 8, towards you 16 *)
let wheel v = if v > 0 then 8 else if v < 0 then 16 else 0

(* a field's value: its bits, the lowest first, from after the byte
 * [skip] *)
let get report skip f =
  let rec bits k acc =
    if k < 0 then acc
    else begin
      let at = f.at + k in
      let byte = skip + (at / 8) in
      let bit =
        if byte < String.length report then
          (Char.code report.[byte] lsr (at mod 8)) land 1
        else 0
      in
      bits (k - 1) ((acc lsl 1) lor bit)
    end
  in
  let v = bits (f.bits - 1) 0 in
  if f.signed && f.bits > 0 && v land (1 lsl (f.bits - 1)) <> 0 then
    v - (1 lsl f.bits)
  else v

let moved mouse report =
  match mouse with
  | Boot ->
      if String.length report < 3 then None
      else begin
        let signed b = if b > 127 then b - 256 else b in
        let b = Char.code report.[0] in
        (* the buttons: USB's are left, right, middle; a 4th byte, the
         * wheel, which a mouse may send in the boot protocol too *)
        let buttons =
          b land 1
          lor ((b land 2) lsl 1)
          lor ((b land 4) lsr 1)
          lor
          if String.length report > 3 then wheel (signed (Char.code report.[3]))
          else 0
        in
        Some
          (signed (Char.code report.[1]), signed (Char.code report.[2]), buttons)
      end
  | Report l ->
      let skip = if l.id > 0 then 1 else 0 in
      if String.length report < 1 || (l.id > 0 && Char.code report.[0] <> l.id)
      then None
      else begin
        (* (USB's buttons 1, 2, 3: left, right, middle; Plan 9's 1, 4, 2) *)
        let plan9 u = match u with 1 -> 1 | 2 -> 4 | _ -> 2 in
        let buttons =
          List.fold_left
            (fun acc (u, f) ->
              if get report skip f <> 0 then acc lor plan9 u else acc)
            0 l.buttons
        in
        let buttons =
          buttons
          lor
          match l.wheel with
          | Some f -> wheel (get report skip f)
          | None -> 0
        in
        Some (get report skip l.x, get report skip l.y, buttons)
      end
