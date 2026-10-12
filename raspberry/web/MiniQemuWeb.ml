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
 * kernel.img beside the page and no card. A name that ends in .gz
 * (before a ?v=1, if any) is undone by the browser (DecompressionStream). The card stays in
 * memory: what is written to it lasts as long as the page.
 *
 * The keys are the UART's, a byte each (the kernel's console echoes
 * them), unless the screen was clicked: then they are a keyboard's,
 * down and up, by where the key is (the event's code: a USB usage is a
 * place on the keyboard too). The keyboard and the mouse are the
 * page's own, for a kernel built for a page ([usb] says how, and the
 * way of a Pi's kernel, ?input=usb: a USB keyboard and mouse on the
 * board).
 *
 * The board runs in turns of some milliseconds, one after the other
 * while it is behind its clock ([run]); a frame of the browser's shows
 * what changed on the screen. The board's clock goes by its
 * instructions, [ips] to a microsecond: 30 in a terminal; here what
 * the browser is measured to run ([paced]), from 6, or ?ips=N. The
 * status line says both: the instructions a second, and the board's
 * seconds for one of ours.
 *
 * What makes it fast enough to use, each a switch here and each apart
 * from the board's simple way: the instructions run often translated
 * to JavaScript (Jit, ?jit=0), memdraw's general loop run by the host
 * for a kernel that asks (Hostdraw, ?draw=kernel), the screen's rows
 * that changed and not all of it (?screen=whole), the turns
 * (?run=frames), the pace (?ips=N).
 *
 * All that the page's address may say, after a ? and with & between
 * them ([start] reads them):
 *
 *   kernel=URL     the kernel's image (default: the page's variable,
 *                  then kernel.img); card=URL the SD card's (none)
 *   jit=0          no translation: every instruction by the interpreter
 *   hot=N          a block is translated once run N times (200)
 *   draw=kernel    the kernel's own drawing loop, the host's not offered
 *   input=usb      a USB keyboard and mouse on the board, as a Pi's
 *                  (the kernel's cursor, drawn by it); what a kernel
 *                  not built for a page needs
 *   screen=whole   the whole screen drawn at each frame
 *   show=N         the screen shown each N frames of the browser's (3)
 *   run=frames     the board run inside the browser's frames, a slice
 *                  each, and not in turns between them
 *   ips=N          N instructions to the board's microsecond, fixed
 *                  (the pace measured otherwise, from 6)
 *
 * So ?jit=0&draw=kernel&input=usb&run=frames&screen=whole&ips=6 is the
 * page of before these, with the Pi's kernel by kernel=.
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

(* How the keys and the mouse reach the kernel. [usb] off, the way of a
 * kernel built for a page (Board.host_key, host_pointer; mini-9pi's
 * Kweb): the keys as they are pressed, the mouse where it is on the
 * canvas, and the cursor is the browser's own, in the shape the kernel
 * gives ([cursor_show]): it follows the hand whatever the board's
 * speed. (old, and [usb] on, ?input=usb, for a kernel of the Pi: a USB
 * keyboard and mouse on the board, the mouse's moves relative and kept
 * in the canvas, the cursor drawn by the kernel in the framebuffer: a
 * mouse that moved took 5 of the 6 million instructions of a second.) *)
let usb = ref false

let on_screen () = get document "activeElement" == element "screen"

let listen_keys board =
  let key down e =
    if on_screen () then begin
      (match usage (Js.to_string (get e "code")) with
       | Some u -> if not (Js.to_bool (get e "repeat")) then (if !usb then Board.key board u down else Board.host_key u down)
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

(* the page's way: where the mouse is on the framebuffer (the canvas
 * may be shown smaller than its pixels) and its buttons (the browser's
 * bits are 1 left, 2 right, 4 middle; Plan 9's 1 left, 2 middle, 4
 * right). A button's change is given at once; a move waits for a frame
 * ([mouse_frame]) *)
let at_x = ref 0 and at_y = ref 0 and at_buttons = ref 0 and at_moved = ref false

let mouse_at canvas e =
  let scale v shown real = if shown <= 0 then v else v * real / shown in
  at_x := scale (int_of e "offsetX") (int_of canvas "clientWidth") (int_of canvas "width");
  at_y := scale (int_of e "offsetY") (int_of canvas "clientHeight") (int_of canvas "height");
  let b = int_of e "buttons" in
  at_buttons := (b land 1) lor (if b land 4 <> 0 then 2 else 0) lor (if b land 2 <> 0 then 4 else 0)

let listen_mouse board canvas =
  listen canvas "mousemove" (fun e ->
    if !usb then (moved_x := !moved_x + int_of e "movementX"; moved_y := !moved_y + int_of e "movementY")
    else (mouse_at canvas e; at_moved := true));
  let button down e =
    if !usb then begin
      let b = match int_of e "button" with 0 -> 1 | 1 -> 4 | 2 -> 2 | _ -> 0 in
      if b <> 0 then Board.pointer board [ Usb.Button (b, down) ]
    end
    else (mouse_at canvas e; at_moved := false; Board.host_pointer !at_x !at_y !at_buttons);
    ignore (call e "preventDefault" [||]) in
  listen canvas "mousedown" (fun e ->
    ignore (call canvas "focus" [||]);
    (* (not everywhere: a browser without a screen has none to keep it in) *)
    if !usb then (try ignore (call canvas "requestPointerLock" [||]) with _ -> ());
    button true e);
  listen canvas "mouseup" (button false);
  listen canvas "contextmenu" (fun e -> ignore (call e "preventDefault" [||]))

(* The page's way: a move is given every [move_every] frames, 15 times
 * a second, and 30 while a button is down (a window swept, a menu): the
 * cursor does not wait for the kernel, and each move given is a
 * window system's work (mini-rio's: 60,000 instructions) *)
let move_every = 4

let mouse_frame board frames =
  if not !usb then begin
    if !at_moved && frames mod (if !at_buttons <> 0 then move_every / 2 else move_every) = 0 then begin
      at_moved := false; Board.host_pointer !at_x !at_y !at_buttons
    end
  end
  else if !moved_x <> 0 || !moved_y <> 0 then begin
    Board.pointer board [ Usb.Rel_x !moved_x; Usb.Rel_y !moved_y ];
    moved_x := 0; moved_y := 0
  end

(*****************************************************************************)
(* The screen: a canvas *)
(*****************************************************************************)

(* A canvas's pixel is four bytes, red, green, blue and how opaque: one
 * word of 32 bits (the browsers' machines being little-endian). The
 * framebuffer's 16 bits (RGB565, what the kernels ask) through a table
 * of its 65536 colours; 24 and 32 bits byte by byte, red first.
 *
 * The pixels are read where they are, in the board's RAM (a bytes of
 * OCaml is an array of bytes of JavaScript's here: no copy), as words
 * of 16 bits when that is their depth. (old: Board.frame's string of
 * them, compared with the last one shown: making a megabyte's string
 * 20 times a second was a quarter of the page's time, by Chrome's
 * profile; [copied] is that way still, also for a framebuffer at an
 * odd address.) *)
let copied = ref false

type screen = { canvas : U.any; context : U.any; mutable picture : U.any; mutable words : U.any;
                mutable shape : Framebuffer.geometry option; mutable shown : string; colours : U.any }

let screen_open canvas =
  let colour v =
    let r = (v lsr 11) land 31 and g = (v lsr 5) land 63 and b = v land 31 in
    (255 lsl 24) lor (((b lsl 3) lor (b lsr 2)) lsl 16) lor (((g lsl 2) lor (g lsr 4)) lsl 8) lor ((r lsl 3) lor (r lsr 2)) in
  let colours = U.new_obj (get U.global "Uint32Array") [| U.inject 65536 |] in
  for v = 0 to 65535 do U.set colours v (colour v) done;
  { canvas; context = call canvas "getContext" [| str "2d" |]; picture = U.inject 0; words = U.inject 0; shape = None; shown = ""; colours }

let screen_shape s (g : Framebuffer.geometry) =
  if s.shape <> Some g then begin
    set s.canvas "width" g.width; set s.canvas "height" g.height;
    s.picture <- call s.context "createImageData" [| U.inject g.width; U.inject g.height |];
    s.words <- U.new_obj (get U.global "Uint32Array") [| U.inject (get (get s.picture "data") "buffer") |];
    s.shape <- Some g; s.shown <- ""
  end

let screen_put s = ignore (call s.context "putImageData" [| U.inject s.picture; U.inject 0; U.inject 0 |])

(* by a copy *)
let screen_show_copied s board =
  match Board.frame board with
  | None -> ()
  | Some (g, pixels) ->
      screen_shape s g;
      if pixels <> s.shown then begin
        s.shown <- pixels;
        let byte i = Char.code (String.unsafe_get pixels i) in
        for y = 0 to g.height - 1 do
          let row = y * g.pitch and out = y * g.width in
          if g.depth = 16 then
            for x = 0 to g.width - 1 do
              U.set s.words (out + x) (U.get s.colours (byte (row + (2 * x)) lor (byte (row + (2 * x) + 1) lsl 8)))
            done
          else begin
            let n = g.depth / 8 in
            for x = 0 to g.width - 1 do
              let o = row + (n * x) in
              U.set s.words (out + x) ((255 lsl 24) lor (byte (o + 2) lsl 16) lor (byte (o + 1) lsl 8) lor byte o)
            done
          end
        done;
        screen_put s
      end

(* Only the rows written since the last time, when the board knows them
 * (Board.host_rows: a kernel built for a page writes its pixels by the
 * board's moves), and all of the screen every [whole_every] times (a
 * kernel also writes there by itself: its console's text before the
 * draw device). (old, and [whole] always: the megabyte converted and
 * put on the canvas 20 times a second, a screen that waits too.) *)
let whole = ref false
let whole_every = 10
let shows = ref 0

let screen_show s board =
  match Board.frame_direct board with
  | Some (g, bytes, at) when not !copied && g.depth = 16 && at land 1 = 0 ->
      let reshaped = s.shape <> Some g in
      screen_shape s g;
      Board.host_watch ~base:at ~pitch:g.pitch ~rows:g.height;
      incr shows;
      let rows =
        match Board.host_rows () with
        | _ when !whole || reshaped || !shows mod whole_every = 0 -> Some (0, g.height)
        | r -> r in
      (match rows with
       | None -> ()
       | Some (y0, y1) ->
           let ram = Js_of_ocaml.Typed_array.Bytes.to_uint8Array bytes in
           let pixels = U.new_obj (get U.global "Uint16Array")
               [| U.inject (get ram "buffer"); U.inject (int_of ram "byteOffset" + at); U.inject (g.pitch * g.height / 2) |] in
           let half = g.pitch / 2 and words = s.words and colours = s.colours in
           for y = y0 to y1 - 1 do
             let row = y * half and out = y * g.width in
             for x = 0 to g.width - 1 do
               U.set words (out + x) (U.get colours (U.get pixels (row + x)))
             done
           done;
           ignore (call s.context "putImageData"
                     [| U.inject s.picture; U.inject 0; U.inject 0; U.inject 0; U.inject y0; U.inject g.width; U.inject (y1 - y0) |]))
  | _ -> screen_show_copied s board

(* The cursor the kernel gave (Board.host_shape: its offset, then 16 by
 * 16 bits twice, clr and set), as the canvas's own: white where clr,
 * black where set, through a small canvas and its picture's address *)
let cursor_shown = ref 0

let cursor_show canvas =
  let n, shape = !Board.host_shape in
  if n <> !cursor_shown && String.length shape = 66 then begin
    cursor_shown := n;
    let signed i = let v = Char.code shape.[i] in if v >= 128 then v - 256 else v in
    let small = call document "createElement" [| str "canvas" |] in
    set small "width" 16; set small "height" 16;
    let context = call small "getContext" [| str "2d" |] in
    let picture = call context "createImageData" [| U.inject 16; U.inject 16 |] in
    let data = get picture "data" in
    for k = 0 to 255 do
      let bit at = Char.code shape.[at + (k / 8)] land (0x80 lsr (k land 7)) <> 0 in
      let clr = bit 2 and black = bit 34 in
      let v = if black then 0 else 255 in
      U.set data (4 * k) v; U.set data ((4 * k) + 1) v; U.set data ((4 * k) + 2) v;
      U.set data ((4 * k) + 3) (if clr || black then 255 else 0)
    done;
    ignore (call context "putImageData" [| U.inject picture; U.inject 0; U.inject 0 |]);
    let url = Js.to_string (call small "toDataURL" [||]) in
    let spot v = max 0 (min 15 (- v)) in
    set (get canvas "style") "cursor" (Js.string (Printf.sprintf "url(%s) %d %d, crosshair" url (spot (signed 0)) (spot (signed 1))))
  end

(*****************************************************************************)
(* The loop: a frame's instructions, then what is shown *)
(*****************************************************************************)

(* the milliseconds of a frame the board may take (of 16.7 at 60 frames
 * a second: the rest is the screen's and the browser's; old: 12, which
 * left a sixth of the time idle by Chrome's profile); the screen every
 * [screen_every] frames (its megabyte is converted each time) *)
let budget = 14.
let screen_every = ref 3
(* a turn of the board, milliseconds (the loop: [run]) *)
let turn = 8.
let by_frames = ref false

let translated = ref true

(* The board's pace follows the browser ([paced]; ?ips=N: N, fixed).
 * The board's second is so many instructions, and a second of ours
 * should be about one of the board's: fewer than the browser runs, and
 * a game has fewer frames than it could; more, and the board's clock
 * is slow, a game in slow motion. What the browser runs is measured
 * over the frames that used all of their time ([busy]), and the pace
 * moved a third of the way to a tenth over it each second (over: the
 * faster the pace, the fewer of the kernel's ticks an instruction, and
 * the more the browser runs; a board's clock a little slow is the
 * better trade); when no frame did and the board ran all its pace
 * allowed, the pace is tried a quarter higher. It is 4
 * million a second when the interpreter runs cold code, 13 when a
 * game's loop is translated (Chrome, 2026-10-11). *)
let paced = ref true

let run ~ips kernel card =
  let sd = Option.map (fun (b : Bytes.t) : Sdhost.storage ->
    { read = (fun off len -> Bytes.sub_string b off len); write = (fun off data -> Bytes.blit_string data 0 b off (String.length data));
      size = Bytes.length b }) card in
  let board = Board.create { pi2 = false; ram_size = 512 * 1024 * 1024; ips; log = ignore; usb_devices = (if !usb then [ "usb-kbd"; "usb-mouse" ] else []); sd;
                             serial0 = put; serial1 = ignore; console = 0 } in
  Board.load_raw board ~addr:0x8000 kernel;
  (* the instructions run often translated to JavaScript (?jit=0: all by the interpreter) *)
  if !translated then Jit.attach board;
  let canvas = element "screen" in
  let screen = screen_open canvas in
  listen_keys board; listen_mouse board canvas;
  let last = ref (now ()) and frames = ref 0 in
  let pace = ref ips and busy_ms = ref 0. and busy_ran = ref 0 in
  (* what the status says: the instructions and the board's time since it was said *)
  let ran = ref 0 and since = ref (now ()) and board_since = ref 0 in
  (* The board runs in turns of [turn] milliseconds, one after the other
   * while it is behind its clock (a message to the page itself between
   * two: the browser draws and hears the keys there), every few
   * milliseconds when it waits. What is shown is a frame's
   * ([frame]). (old, and [by_frames], ?run=frames: the board run in
   * the frame's function, [budget] milliseconds of each 16.7; a frame
   * that long made Chrome draw every other one, and the board then ran
   * 14 ms of every 33: 4 parts in 10 of the time were nobody's.) *)
  let stopped = ref false and owed = ref 0. in
  let turn_of ms =
    let start = now () in
    (* the board's microseconds due: a quarter of a second at most (a page left and come back to) *)
    (* (old: until Board.now board is due, an address of time: under
     * js_of_ocaml the board's microseconds wrap after 35 minutes, and
     * the page then stopped. Now a count of them from this turn's
     * first.) *)
    (* ([owed]: what the board's clock is behind ours, less what it went
     * ahead: a board that waits skips to its next tick, 10 ms at once,
     * and with a turn every 4 ms its clock went twice as fast as ours) *)
    owed := Float.min 250_000. (!owed +. (1000. *. (start -. !last)));
    let due = truncate !owed and from = Board.now board and before = !ran in
    last := start;
    match
      while Board.now board - from < due && now () -. start < ms do
        Board.run board ~batch:4096;
        List.iter (fun (c : Status.cpu) -> ran := !ran + c.ran) (Board.where board)
      done;
      owed := !owed -. float_of_int (Board.now board - from);
      (* (a turn that used its time: what the browser can do) *)
      let took = now () -. start in
      if took >= ms then (busy_ms := !busy_ms +. took; busy_ran := !busy_ran + (!ran - before); true) else false
    with
    | exception e -> stopped := true; status ("mini-qemu: " ^ Printexc.to_string e); false
    | busy -> busy in
  let channel = U.new_obj (get U.global "MessageChannel") [||] in
  let again () = ignore (call (get channel "port2") "postMessage" [| U.inject 0 |]) in
  let rec turns _ =
    if not !stopped then begin
      if turn_of turn then again ()
      else ignore (call U.global "setTimeout" [| U.inject (Js.wrap_callback turns); U.inject 4 |])
    end in
  set (get channel "port1") "onmessage" (U.inject (Js.wrap_callback turns));
  let rec frame _ =
    let start = now () in
    if !by_frames then ignore (turn_of budget);
    if not !stopped then begin
        mouse_frame board !frames;
        incr frames;
        if !frames mod !screen_every = 0 then screen_show screen board;
        show_text ();
        if not !usb then cursor_show canvas;
        if start -. !since > 1000. then begin
          let s = (start -. !since) /. 1000. in
          status (Printf.sprintf "%.1f million instructions a second; the board's clock: %.2f s for one of ours"
                    (float_of_int !ran /. s /. 1e6) (float_of_int (Board.now board - !board_since) /. 1e6 /. s));
          if !paced then begin
            (* (most of the second: a few slow turns, a block translated,
             * the collector, are not the browser's speed) *)
            if !busy_ms > 500. *. s then begin
              let can = float_of_int !busy_ran /. !busy_ms /. 1000. *. (if !by_frames then budget /. 16.7 else 0.9) in
              pace := max 3 (min 60 (truncate (((2. *. float_of_int !pace) +. (1.1 *. can)) /. 3. +. 0.5)))
            end
            (* (the browser kept up, and the board ran nearly all its
             * pace allows: it may be able to run more) *)
            else if float_of_int !ran >= 0.85 *. float_of_int !pace *. 1e6 *. s then pace := min 60 (!pace + max 1 (!pace / 4));
            Board.set_ips board !pace
          end;
          busy_ms := 0.; busy_ran := 0;
          ran := 0; since := start; board_since := Board.now board
        end;
        ignore (call U.global "requestAnimationFrame" [| U.inject (Js.wrap_callback frame) |])
    end in
  if not !by_frames then turns ();
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
        (* (the name before a ?v=1, which a page adds so that a new file is fetched) *)
        if Filename.check_suffix (List.hd (String.split_on_char '?' name)) ".gz" then
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
  let ips = match Option.bind (of_address "ips") int_of_string_opt with Some n when n > 0 -> paced := false; n | _ -> 6 in
  usb := of_address "input" = Some "usb";
  translated := of_address "jit" <> Some "0";
  (match Option.bind (of_address "hot") int_of_string_opt with Some n when n > 0 -> Jit.threshold := n | _ -> ());
  whole := of_address "screen" = Some "whole";
  by_frames := of_address "run" = Some "frames";
  (match Option.bind (of_address "show") int_of_string_opt with Some n when n > 0 -> screen_every := n | _ -> ());
  Board.host_cursor := not !usb;
  (* memdraw's general loop by the host, for a kernel that asks (?draw=kernel: not) *)
  if of_address "draw" <> Some "kernel" then Hostdraw.install ();
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
