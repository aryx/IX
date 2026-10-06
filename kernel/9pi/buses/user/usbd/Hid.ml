(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Hid.mli *)

type caps = < Usbdev.caps; Cap.fork >

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

(* a scancode as written: the keys a PC keyboard added later (the
 * arrows, the right Alt) have 0xe0 before theirs *)
let scan esc sc = if esc then "\xe0" ^ String.make 1 (Char.chr sc) else String.make 1 (Char.chr sc)
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

let scancodes report before =
  let keys s = List.filter (fun k -> k <> 0) (List.init (String.length s - 2) (fun i -> Char.code s.[i + 2])) in
  let now = keys report and was = keys before in
  modifiers (Char.code report.[0]) (Char.code before.[0])
  @ List.concat_map (key false) (List.filter (fun k -> not (List.mem k was)) now)
  @ List.concat_map (key true) (List.filter (fun k -> not (List.mem k now)) was)

let mouse_line report =
  let signed b = if b > 127 then b - 256 else b in
  let b = Char.code report.[0] in
  (* the buttons: USB's are left, right, middle; Plan 9's left, middle, right; the wheel two more *)
  let buttons = (b land 1) lor ((b land 2) lsl 1) lor ((b land 4) lsr 1)
                lor (if String.length report > 3 then (match report.[3] with '\001' -> 8 | '\255' -> 16 | _ -> 0) else 0) in
  Printf.sprintf "m%11d %11d %11d" (signed (Char.code report.[1])) (signed (Char.code report.[2])) buttons

(* The keyboard's process: a report read, the scancodes written. The
 * keyboard is asked to say its state again every 32 ms (its "idle"
 * time, below), changed or not: so a key held is seen held, and
 * written again after 5 reports the same (160 ms), then at each one:
 * the keys repeat without a clock. (kb.c has a process more for that;
 * it sets the idle time for another reason, the Pi's controller
 * losing reports.) *)
(* (a read asks for the endpoint's largest packet, no more: a report
 * is one packet, and a read of more would wait for a second one) *)
let keyboard fd maxpkt kbin =
  let size = 8 in
  let b = Bytes.create 64 in
  let rec loop before held same =
    let n = try Unix.read fd b 0 (min 64 maxpkt) with Unix.Unix_error _ -> 0 in
    let n = min n size in
    if n <= 0 then ()
    else begin
      let report = Bytes.sub_string b 0 n ^ String.make (max 0 (size - n)) '\000' in
      (* (too many keys held: the keyboard says so in all its six places) *)
      if n < 3 || (report.[2] <> '\000' && String.sub report 2 6 = String.make 6 report.[2]) then loop before held same
      else begin
        let codes = scancodes report before in
        List.iter (fun s -> ignore (Unix.write_substring kbin s 0 (String.length s))) codes;
        (* the key that repeats: the last one that went down, until a key goes up *)
        let down = List.filter (fun s -> Char.code s.[String.length s - 1] land keyup = 0) codes in
        let held, same =
          if codes = [] then held, same + 1
          else if down <> [] && String.sub report 2 6 <> String.sub before 2 6 then Some (List.nth down (List.length down - 1)), 0
          else if String.sub report 2 6 <> String.sub before 2 6 then None, 0
          else held, 0 in
        (match held with
         | Some s when same >= 5 && codes = [] -> ignore (Unix.write_substring kbin s 0 (String.length s))
         | _ -> ());
        loop report held same
      end
    end in
  loop (String.make size '\000') None 0

let mouse fd maxpkt mousein =
  let b = Bytes.create 64 in
  let rec loop () =
    let n = try Unix.read fd b 0 (min 64 maxpkt) with Unix.Unix_error _ -> 0 in
    if n > 0 then begin
      if n >= 3 then begin
        let line = mouse_line (Bytes.sub_string b 0 n) in
        ignore (Unix.write_substring mousein line 0 (String.length line))
      end;
      loop ()
    end in
  loop ()

let start (caps : < caps; .. >) (d : Usbdev.t) (i : Usbdev.interface) =
  match i.cls, i.sub, i.proto, List.filter (fun (e : Usbdev.endpoint) -> e.input && e.kind = 3) i.endpoints with
  | 3, 1, (1 | 2), (e : Usbdev.endpoint) :: _ ->
      let is_keyboard = i.proto = 1 in
      (* the boot protocol (a class's request to the interface: 0x21;
       * SET_PROTOCOL 0x0b, 0), and how often it says its state
       * unasked (SET_IDLE 0x0a, in 4 ms: a keyboard every 32 ms, a
       * mouse only when it changes) *)
      Usbdev.send d 0x21 0x0b 0 i.iface "";
      (try Usbdev.send d 0x21 0x0a ((if is_keyboard then 8 else 0) lsl 8) i.iface "" with Unix.Unix_error _ -> ());
      (* its endpoint: made by a line to the device's ctl, then its own files *)
      Usbdev.ctl d (Printf.sprintf "new %d 3 r" e.number);
      let ep = Usbdev.open_ caps (Printf.sprintf "ep%d.%d" d.id e.number) in
      Usbdev.ctl ep (Printf.sprintf "maxpkt %d" e.maxpkt);
      if e.interval <> 0 then (try Usbdev.ctl ep (Printf.sprintf "pollival %d" e.interval) with Unix.Unix_error _ -> ());
      Usbdev.open_data caps ep 0;
      let fd = Option.get ep.data in
      if CapUnix.fork caps () = 0 then begin
        (if is_keyboard then keyboard fd e.maxpkt (FS.open_rw_fd caps "#Ι/kbin") else mouse fd e.maxpkt (FS.open_rw_fd caps "#m/mousein"));
        Unix._exit 0
      end;
      Usbdev.close ep;
      true
  | _ -> false
