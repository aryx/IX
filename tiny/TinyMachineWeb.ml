(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* tiny-machine in a web page (plan_web.md, stage 0): TinyLibMachine's
 * machine compiled by js_of_ocaml, its screen a canvas, its console
 * the page's text, its keys and its mouse the page's. TinyMachine.ml is
 * the same machine in a terminal. Not a program of t-ix's own tools:
 * OCaml and js_of_ocaml build it (./tiny-machine -web dir tiny-kernel
 * builds the page's directory; TinyMachineWeb.html is the page).
 *
 * The page gives three elements, by their ids: screen (a canvas, 640
 * by 480), console (the text), status (a line). The kernel's image is
 * fetched: boot.img beside the page, or what the address says
 * (?image=kernel.img&disk=fs.img: tiny-os v6, whose disk's writes last
 * as long as the page), or, before both, what the page says in a
 * variable of its own, tiny_machine = { image: ..., disk: ... }, each
 * an address (docs/t-ix.html, the website's page: its files are in
 * another place, the assets').
 *
 * The keys are of two kinds, as TinyMachine's are with -window, where
 * a person types in the terminal or in the window. With the mouse in
 * the screen they are the machine's, each byte as it is typed (a
 * game's arrows, a window's text, which the window system echoes).
 * Elsewhere they are a terminal's: the line is shown as it is typed,
 * a backspace corrects it, and Enter gives it to the machine; a
 * kernel's console echoes nothing, a terminal does.
 *
 * The loop is the browser's: at each frame (requestAnimationFrame) the
 * instructions the time since the last one is worth, at the machine's
 * speed (TinyLibMachine.rate), and no more than [budget] milliseconds
 * of them, so that a browser too slow for the speed still draws and
 * listens: the machine is then slower, and the status line says by how
 * much. Then the screen, if it changed, and the console's new text.
 *
 * An int has 32 bits here (TinyLibCPU.ult says what that asks). *)

module Js = Js_of_ocaml.Js
module U = Js_of_ocaml.Js.Unsafe

let call o name args = U.meth_call o name args
let str s = U.inject (Js.string s)
let get o name = U.get o (Js.string name)
let document = get U.global "document"
let element id = call document "getElementById" [| str id |]
let listen o name f = ignore (call o "addEventListener" [| str name; U.inject (Js.wrap_callback f) |])
let now () : float = Js.float_of_number (call (get U.global "performance") "now" [||])

(*****************************************************************************)
(* The console: the machine's bytes as the page's text *)
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

(* the line being typed, a terminal's (see the keys), shown after the
 * text with its cursor *)
let line = Buffer.create 80

let show_text () =
  if !text_changed then begin
    text_changed := false;
    let e = element "console" in
    U.set e (Js.string "textContent") (Js.bytestring (Buffer.contents text ^ Buffer.contents line ^ "_"));
    U.set e (Js.string "scrollTop") (get e "scrollHeight")
  end

let status s = U.set (element "status") (Js.string "textContent") (Js.string s)

(*****************************************************************************)
(* The keys and the mouse *)
(*****************************************************************************)

(* a key's byte: the arrows 128 to 131 (up, down, left, right),
 * tiny-machine's choice; control with a letter its control character *)
let key_byte e =
  let key = Js.to_string (get e "key") and ctrl = Js.to_bool (get e "ctrlKey") in
  match key with
  | "Enter" -> Some 10 | "Backspace" -> Some 8 | "Tab" -> Some 9 | "Escape" -> Some 27 | "Delete" -> Some 127
  | "ArrowUp" -> Some 128 | "ArrowDown" -> Some 129 | "ArrowLeft" -> Some 130 | "ArrowRight" -> Some 131
  | _ when String.length key = 1 && Char.code key.[0] < 127 ->
      let c = Char.code key.[0] in
      if Js.to_bool (get e "metaKey") then None else if ctrl then Some (c land 31) else Some c
  | _ -> None

(* whether the mouse is in the screen: the keys are then the machine's *)
let in_screen = ref false

(* a terminal's key: the line edited and echoed, given at Enter; ^C at
 * once, as a terminal's interrupt (tiny-kernel kills the program
 * running) *)
let terminal_key (mc : TinyLibMachine.machine) b =
  (match b with
   | 3 -> TinyLibMachine.console_type mc.cons "\003"
   | 8 | 127 -> if Buffer.length line > 0 then Buffer.truncate line (Buffer.length line - 1)
   | 10 ->
       Buffer.add_char line '\n';
       Buffer.add_buffer text line;
       TinyLibMachine.console_type mc.cons (Buffer.contents line);
       Buffer.clear line
   | b when b >= 32 && b < 127 -> Buffer.add_char line (Char.chr b)
   | _ -> ());
  text_changed := true

let listen_keys (mc : TinyLibMachine.machine) =
  listen document "keydown" (fun e ->
    match key_byte e with
    | Some b ->
        if !in_screen then TinyLibMachine.console_type mc.cons (String.make 1 (Char.chr b)) else terminal_key mc b;
        ignore (call e "preventDefault" [||])
    | None -> ())

(* the place in the canvas's own pixels (the page may show it larger);
 * the browser's buttons are 1 left, 2 right, 4 middle, the machine's 1
 * left, 2 middle, 4 right, as Plan 9's *)
let listen_mouse (mc : TinyLibMachine.machine) canvas =
  let int_of o name : int = truncate (Js.float_of_number (get o name)) in
  let moved e =
    in_screen := true;
    let scaled v shown full = if shown > 0 then v * full / shown else v in
    let x = scaled (int_of e "offsetX") (int_of canvas "clientWidth") TinyLibMachine.width
    and y = scaled (int_of e "offsetY") (int_of canvas "clientHeight") TinyLibMachine.height
    and b = int_of e "buttons" in
    TinyLibMachine.mouse_set mc.mouse x y ((b land 1) lor (if b land 2 <> 0 then 4 else 0) lor (if b land 4 <> 0 then 2 else 0));
    ignore (call e "preventDefault" [||]) in
  List.iter (fun name -> listen canvas name moved) [ "mousemove"; "mousedown"; "mouseup" ];
  listen canvas "mouseleave" (fun _ -> in_screen := false);
  listen canvas "contextmenu" (fun e -> ignore (call e "preventDefault" [||]))

(*****************************************************************************)
(* The screen: a canvas *)
(*****************************************************************************)

(* A canvas's pixel is four bytes, red, green, blue and how opaque: as
 * one word of 32 bits (the browsers' machines being little-endian),
 * the screen's byte is one store, through the table of its 256 colours *)
type screen = { context : U.any; picture : U.any; words : U.any; palette : int array; mutable shown : string }

let screen_open canvas =
  let context = call canvas "getContext" [| str "2d" |] in
  let picture = call context "createImageData" [| U.inject TinyLibMachine.width; U.inject TinyLibMachine.height |] in
  let words = U.new_obj (get U.global "Uint32Array") [| U.inject (get (get picture "data") "buffer") |] in
  let c k = Char.code TinyLibMachine.colours.[k] in
  let palette = Array.init 256 (fun i -> (255 lsl 24) lor (c ((3 * i) + 2) lsl 16) lor (c ((3 * i) + 1) lsl 8) lor c (3 * i)) in
  { context; picture; words; palette; shown = "" }

let screen_show s (m : TinyLibCPU.machine) =
  let n = TinyLibMachine.width * TinyLibMachine.height in
  let pixels = Bytes.sub_string m.mem TinyLibMachine.screen n in
  if pixels <> s.shown then begin
    s.shown <- pixels;
    for i = 0 to n - 1 do U.set s.words i s.palette.(Char.code (String.unsafe_get pixels i)) done;
    ignore (call s.context "putImageData" [| U.inject s.picture; U.inject 0; U.inject 0 |])
  end

(*****************************************************************************)
(* The loop: a frame's instructions, then what is shown *)
(*****************************************************************************)

(* the milliseconds of a frame the machine may take *)
let budget = 12.

let run image disk =
  let on_open (k : TinyLibMachine.console) = k.opened <- true in
  let mc : TinyLibMachine.machine = TinyLibMachine.create ~put ~on_open ~disk ~events:None image in
  let env = TinyLibMachine.env mc in
  let canvas = element "screen" in
  let screen = screen_open canvas in
  listen_keys mc; listen_mouse mc canvas;
  text_changed := true;
  let last = ref (now ()) and running = ref true in
  (* the speed shown: the instructions and the time since it was said *)
  let done_ = ref 0 and since = ref (now ()) in
  let rec frame _ =
    let start = now () in
    (* a quarter of a second at most: a page left and come back to *)
    let due = truncate (TinyLibMachine.rate *. Float.min 0.25 ((start -. !last) /. 1000.)) in
    last := start;
    (try
       let n = ref 0 in
       while !n < due && now () -. start < budget do
         for _ = 1 to min 4096 (due - !n) do TinyLibMachine.tick mc env done;
         n := !n + min 4096 (due - !n)
       done;
       done_ := !done_ + !n
     with
     | TinyLibMachine.Halt code -> running := false; status (Printf.sprintf "the machine halted (%d); reload the page to boot it again" code)
     | TinyLibCPU.Error e -> running := false; status ("tiny-machine: " ^ e));
    screen_show screen mc.cpu; show_text ();
    if !running then begin
      if start -. !since > 1000. then begin
        status (Printf.sprintf "%.1f million instructions a second (the machine's speed: %.0f)"
                  (float_of_int !done_ /. (start -. !since) /. 1000.) (TinyLibMachine.rate /. 1e6));
        done_ := 0; since := start
      end;
      ignore (call U.global "requestAnimationFrame" [| U.inject (Js.wrap_callback frame) |])
    end in
  frame ()

(* a file from beside the page, its bytes; k with None if it is not there *)
let fetch name k =
  let failed _ = k None in
  let bytes buffer = k (Some (Js_of_ocaml.Typed_array.String.of_arrayBuffer buffer)) in
  let got response =
    if Js.to_bool (get response "ok") then ignore (call (call response "arrayBuffer" [||]) "then" [| U.inject (Js.wrap_callback bytes); U.inject (Js.wrap_callback failed) |])
    else failed () in
  ignore (call (call U.global "fetch" [| str name |]) "then" [| U.inject (Js.wrap_callback got); U.inject (Js.wrap_callback failed) |])

let () =
  let search = U.new_obj (get U.global "URLSearchParams") [| U.inject (get (get U.global "location") "search") |] in
  let text v = Js.Opt.to_option (Js.Opt.map (Js.Opt.option (Js.Optdef.to_option v)) Js.to_string) in
  let page = Js.Optdef.to_option (get U.global "tiny_machine") in
  let param name =
    match page with
    | Some o -> text (get o name)
    | None -> Js.Opt.to_option (Js.Opt.map (call search "get" [| str name |]) Js.to_string) in
  let image = Option.value (param "image") ~default:"boot.img" in
  let missing name = status ("tiny-machine: " ^ name ^ " could not be fetched") in
  status ("loading " ^ image);
  fetch image (function
    | None -> missing image
    | Some bytes ->
        match param "disk" with
        | None -> run bytes Bytes.empty
        | Some d -> fetch d (function None -> missing d | Some disk -> run bytes (Bytes.of_string disk)))
