(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-qemu in a web page (plan_web.md, stage 1): the Pi 1's board
 * (Board) compiled by js_of_ocaml, its framebuffer a canvas, its UART
 * the page's text, a USB keyboard and mouse the page's. Main.ml is the
 * same board in a terminal and an SDL window, by QEMU's command line.
 *
 * The page gives three elements, by their ids: screen (a canvas),
 * console (the text), status (a line). What is booted is fetched: a
 * kernel's image, loaded at 0x8000, and an SD card's; their addresses
 * are the page's own variable, mini_qemu = { kernel: ..., card: ... },
 * or the address's (?kernel=kernel.img&card=card.img.gz), or
 * kernel.img beside the page and no card. A name that ends in .gz is
 * undone by the browser (DecompressionStream). The card stays in
 * memory: what is written to it lasts as long as the page.
 *
 * The keys are the UART's, a byte each (the kernel's console echoes
 * them), unless the screen was clicked: then they are the USB
 * keyboard's, down and up, by where the key is (the event's code: a
 * USB usage is a place on the keyboard too), and the mouse is the USB
 * mouse's, which only knows how far it moved: the click asks the
 * browser to keep the pointer in the screen (Esc gives it back), as
 * mini-qemu's window does (Ctrl-Alt-G there).
 *
 * The loop is the browser's: at each frame the instructions that the
 * time since the last one is worth on the board's clock, and no more
 * than [budget] milliseconds of them. The board's clock goes by its
 * instructions, [ips] to a microsecond: 30 in a terminal, 6 here
 * (?ips=), about what a browser runs, so that a second of the board's
 * is near a second (a kernel that waits skips to its next tick: its
 * clock is then held to the host's). The status line says both: the
 * instructions a second, and the board's seconds for one of ours.
 *
 * An int has 32 bits here (Bits, in machine/, says what that asks). *)

module Js = Js_of_ocaml.Js
module U = Js_of_ocaml.Js.Unsafe

let call o name args = U.meth_call o name args
let str s = U.inject (Js.string s)
let get o name = U.get o (Js.string name)
let set o name v = U.set o (Js.string name) v
let document = get U.global "document"
let element id = call document "getElementById" [| str id |]
let listen o name f = ignore (call o "addEventListener" [| str name; U.inject (Js.wrap_callback f) |])
let now () : float = Js.float_of_number (call (get U.global "performance") "now" [||])
let int_of o name : int = truncate (Js.float_of_number (get o name))

(*****************************************************************************)
(* The console: the UART's bytes as the page's text *)
(*****************************************************************************)

(* the last [kept] bytes; a backspace takes one back *)
let kept = 20000
let text = Buffer.create 1024
let text_changed = ref false

let put ch =
  (match ch with
   | '\b' -> if Buffer.length text > 0 then Buffer.truncate text (Buffer.length text - 1)
   | '\r' -> ()
   | ch -> Buffer.add_char text ch);
  if Buffer.length text > 2 * kept then begin
    let last = Buffer.sub text (Buffer.length text - kept) kept in
    Buffer.clear text; Buffer.add_string text last
  end;
  text_changed := true

(* the cursor: an element of its own (the page's style makes it a block
 * that blinks), put back after the text each time *)
let cursor = lazy (
  let c = call document "createElement" [| str "span" |] in
  set c "id" (Js.string "cursor");
  set c "textContent" (Js.string "\xc2\xa0");
  c)

let show_text () =
  if !text_changed then begin
    text_changed := false;
    let e = element "console" in
    set e "textContent" (Js.bytestring (Buffer.contents text));
    ignore (call e "appendChild" [| U.inject (Lazy.force cursor) |]);
    set e "scrollTop" (get e "scrollHeight")
  end

let status s = set (element "status") "textContent" (Js.string s)

(*****************************************************************************)
(* The keys and the mouse *)
(*****************************************************************************)

(* a key's byte for the UART; control with a letter its control
 * character; Delete is Plan 9's interrupt *)
let key_byte e =
  let key = Js.to_string (get e "key") in
  match key with
  | "Enter" -> Some 10 | "Backspace" -> Some 8 | "Tab" -> Some 9 | "Escape" -> Some 27 | "Delete" -> Some 127
  | _ when String.length key = 1 && Char.code key.[0] < 127 ->
      let c = Char.code key.[0] in
      if Js.to_bool (get e "metaKey") then None else if Js.to_bool (get e "ctrlKey") then Some (c land 31) else Some c
  | _ -> None

(* a key's USB usage (HID's keyboard page), by the event's code *)
let usages = [
  "Enter", 40; "Escape", 41; "Backspace", 42; "Tab", 43; "Space", 44; "Minus", 45; "Equal", 46; "BracketLeft", 47;
  "BracketRight", 48; "Backslash", 49; "Semicolon", 51; "Quote", 52; "Backquote", 53; "Comma", 54; "Period", 55;
  "Slash", 56; "CapsLock", 57; "Insert", 73; "Home", 74; "PageUp", 75; "Delete", 76; "End", 77; "PageDown", 78;
  "ArrowRight", 79; "ArrowLeft", 80; "ArrowDown", 81; "ArrowUp", 82; "ControlLeft", 224; "ShiftLeft", 225;
  "AltLeft", 226; "MetaLeft", 227; "ControlRight", 228; "ShiftRight", 229; "AltRight", 230; "Digit0", 39 ]

let usage code =
  let n = String.length code in
  if n = 4 && String.sub code 0 3 = "Key" then Some (4 + Char.code code.[3] - Char.code 'A')
  else if n = 6 && String.sub code 0 5 = "Digit" && code.[5] <> '0' then Some (30 + Char.code code.[5] - Char.code '1')
  else if n >= 2 && code.[0] = 'F' && int_of_string_opt (String.sub code 1 (n - 1)) <> None then
    Some (57 + int_of_string (String.sub code 1 (n - 1)))
  else List.assoc_opt code usages

let on_screen () = get document "activeElement" == element "screen"

let listen_keys board =
  let key down e =
    if on_screen () then begin
      (match usage (Js.to_string (get e "code")) with
       | Some u -> if not (Js.to_bool (get e "repeat")) then Board.key board u down
       | None -> ());
      ignore (call e "preventDefault" [||])
    end
    else if down then
      match key_byte e with
      | Some b -> Board.input board (Char.chr b); ignore (call e "preventDefault" [||])
      | None -> () in
  listen document "keydown" (key true);
  listen document "keyup" (key false)

(* the mouse: how far it moved since the last frame, as one event (a
 * window's are synced so by QEMU); the browser's buttons are 0 left, 1
 * middle, 2 right, the USB mouse's bits 1 left, 2 right, 4 middle *)
let moved_x = ref 0 and moved_y = ref 0

let listen_mouse board canvas =
  listen canvas "mousemove" (fun e ->
    moved_x := !moved_x + int_of e "movementX"; moved_y := !moved_y + int_of e "movementY");
  let button down e =
    let b = match int_of e "button" with 0 -> 1 | 1 -> 4 | 2 -> 2 | _ -> 0 in
    if b <> 0 then Board.pointer board [ Usb.Button (b, down) ];
    ignore (call e "preventDefault" [||]) in
  listen canvas "mousedown" (fun e ->
    ignore (call canvas "focus" [||]);
    (* (not everywhere: a browser without a screen has none to keep it in) *)
    (try ignore (call canvas "requestPointerLock" [||]) with _ -> ());
    button true e);
  listen canvas "mouseup" (button false);
  listen canvas "contextmenu" (fun e -> ignore (call e "preventDefault" [||]))

let mouse_frame board =
  if !moved_x <> 0 || !moved_y <> 0 then begin
    Board.pointer board [ Usb.Rel_x !moved_x; Usb.Rel_y !moved_y ];
    moved_x := 0; moved_y := 0
  end

(*****************************************************************************)
(* The screen: a canvas *)
(*****************************************************************************)

(* A canvas's pixel is four bytes, red, green, blue and how opaque: one
 * word of 32 bits (the browsers' machines being little-endian). The
 * framebuffer's 16 bits (RGB565, what the kernels ask) through a table
 * of its 65536 colours; 24 and 32 bits byte by byte, red first. *)
type screen = { canvas : U.any; context : U.any; mutable picture : U.any; mutable words : U.any;
                mutable shape : Framebuffer.geometry option; mutable shown : string; colours : int array }

let screen_open canvas =
  let colour v =
    let r = (v lsr 11) land 31 and g = (v lsr 5) land 63 and b = v land 31 in
    (255 lsl 24) lor (((b lsl 3) lor (b lsr 2)) lsl 16) lor (((g lsl 2) lor (g lsr 4)) lsl 8) lor ((r lsl 3) lor (r lsr 2)) in
  { canvas; context = call canvas "getContext" [| str "2d" |]; picture = U.inject 0; words = U.inject 0; shape = None; shown = "";
    colours = Array.init 65536 colour }

let screen_show s board =
  match Board.frame board with
  | None -> ()
  | Some (g, pixels) ->
      if s.shape <> Some g then begin
        set s.canvas "width" g.width; set s.canvas "height" g.height;
        s.picture <- call s.context "createImageData" [| U.inject g.width; U.inject g.height |];
        s.words <- U.new_obj (get U.global "Uint32Array") [| U.inject (get (get s.picture "data") "buffer") |];
        s.shape <- Some g; s.shown <- ""
      end;
      if pixels <> s.shown then begin
        s.shown <- pixels;
        let byte i = Char.code (String.unsafe_get pixels i) in
        for y = 0 to g.height - 1 do
          let row = y * g.pitch and out = y * g.width in
          if g.depth = 16 then
            for x = 0 to g.width - 1 do
              U.set s.words (out + x) (Array.unsafe_get s.colours (byte (row + (2 * x)) lor (byte (row + (2 * x) + 1) lsl 8)))
            done
          else begin
            let n = g.depth / 8 in
            for x = 0 to g.width - 1 do
              let o = row + (n * x) in
              U.set s.words (out + x) ((255 lsl 24) lor (byte (o + 2) lsl 16) lor (byte (o + 1) lsl 8) lor byte o)
            done
          end
        done;
        ignore (call s.context "putImageData" [| U.inject s.picture; U.inject 0; U.inject 0 |])
      end

(*****************************************************************************)
(* The loop: a frame's instructions, then what is shown *)
(*****************************************************************************)

(* the milliseconds of a frame the board may take; the screen every
 * [screen_every] frames (its megabyte is read and compared each time) *)
let budget = 12.
let screen_every = 3

let run ~ips kernel card =
  let sd = Option.map (fun (b : Bytes.t) : Sdhost.storage ->
    { read = (fun off len -> Bytes.sub_string b off len); write = (fun off data -> Bytes.blit_string data 0 b off (String.length data));
      size = Bytes.length b }) card in
  let board = Board.create { ram_size = 512 * 1024 * 1024; ips; log = ignore; usb_devices = [ "usb-kbd"; "usb-mouse" ]; sd;
                             serial0 = put; serial1 = ignore; console = 0 } in
  Board.load_raw board ~addr:0x8000 kernel;
  let canvas = element "screen" in
  let screen = screen_open canvas in
  listen_keys board; listen_mouse board canvas;
  let last = ref (now ()) and frames = ref 0 in
  (* what the status says: the instructions and the board's time since it was said *)
  let ran = ref 0 and since = ref (now ()) and board_since = ref 0 in
  let rec frame _ =
    let start = now () in
    (* the board's microseconds due: a quarter of a second at most (a page left and come back to) *)
    let due = Board.now board + truncate (1000. *. Float.min 250. (start -. !last)) in
    last := start;
    match
      mouse_frame board;
      while Board.now board < due && now () -. start < budget do
        Board.run board ~batch:4096;
        List.iter (fun (c : Status.cpu) -> ran := !ran + c.ran) (Board.where board)
      done
    with
    | exception e -> status ("mini-qemu: " ^ Printexc.to_string e)
    | () ->
        incr frames;
        if !frames mod screen_every = 0 then screen_show screen board;
        show_text ();
        if start -. !since > 1000. then begin
          let s = (start -. !since) /. 1000. in
          status (Printf.sprintf "%.1f million instructions a second; the board's clock: %.2f s for one of ours"
                    (float_of_int !ran /. s /. 1e6) (float_of_int (Board.now board - !board_since) /. 1e6 /. s));
          ran := 0; since := start; board_since := Board.now board
        end;
        ignore (call U.global "requestAnimationFrame" [| U.inject (Js.wrap_callback frame) |]) in
  frame ()

(* a file's bytes, as the buffer the browser read; a .gz undone on the
 * way; k with None if it is not there *)
let fetch name k =
  let failed _ = k None in
  let callback f = U.inject (Js.wrap_callback f) in
  let got response =
    if not (Js.to_bool (get response "ok")) then failed ()
    else begin
      let response =
        if Filename.check_suffix name ".gz" then
          U.new_obj (get U.global "Response") [| U.inject (call (get response "body") "pipeThrough"
            [| U.inject (U.new_obj (get U.global "DecompressionStream") [| str "gzip" |]) |]) |]
        else response in
      ignore (call (call response "arrayBuffer" [||]) "then" [| callback (fun b -> k (Some b)); callback failed |])
    end in
  ignore (call (call U.global "fetch" [| str name |]) "then" [| callback got; callback failed |])

let () =
  let search = U.new_obj (get U.global "URLSearchParams") [| U.inject (get (get U.global "location") "search") |] in
  let text v = Js.Opt.to_option (Js.Opt.map (Js.Opt.option (Js.Optdef.to_option v)) Js.to_string) in
  let page = Js.Optdef.to_option (get U.global "mini_qemu") in
  let of_address name = Js.Opt.to_option (Js.Opt.map (call search "get" [| str name |]) Js.to_string) in
  let param name = match page with Some o -> text (get o name) | None -> of_address name in
  let kernel = Option.value (param "kernel") ~default:"kernel.img" in
  let ips = match Option.bind (of_address "ips") int_of_string_opt with Some n when n > 0 -> n | _ -> 6 in
  let missing name = status ("mini-qemu: " ^ name ^ " could not be fetched") in
  let start kernel card =
    status "starting";
    try run ~ips (Js_of_ocaml.Typed_array.String.of_arrayBuffer kernel) (Option.map Js_of_ocaml.Typed_array.Bytes.of_arrayBuffer card)
    with e -> status ("mini-qemu: " ^ Printexc.to_string e) in
  status ("loading " ^ kernel);
  fetch kernel (function
    | None -> missing kernel
    | Some image ->
        match param "card" with
        | None -> start image None
        | Some c -> status ("loading " ^ c); fetch c (function None -> missing c | Some card -> start image (Some card)))
