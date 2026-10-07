(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Window.mli *)

type caps = < Cap.draw; Cap.mouse; Cap.keyboard; Cap.fork >

(* a key as Squeak's code: a character's, or an arrow's *)
let key_code (k : string) : int option =
  if k = Keyboard.left then Some 28
  else if k = Keyboard.right then Some 29
  else if k = Keyboard.up then Some 30
  else if k = Keyboard.down then Some 31
  else if k = "\n" then Some 13
  else if String.length k = 1 && (Char.code k.[0] >= 32 || k = "\b" || k = "\t" || k = "\r") && Char.code k.[0] < 127 then Some (Char.code k.[0])
  else None

(* rows loaded at once: a message to the draw device is not long *)
let rows = 8

let run (caps : < caps; .. >) (system : Squeak.system) (transcript : string -> unit) : unit =
  let display = Display.init caps in
  let view = ref (Display.screen display) in
  let w = min Squeak.width (Rectangle.dx !view.r) and h = min Squeak.height (Rectangle.dy !view.r) in
  let mouse = Mouse.init caps and keyboard = Keyboard.init caps in
  (* a tick, so that a pass waits: mini-ml's threads take turns only
   * when one waits, and what the mouse and the keys send is read (by
   * their scheduler) only when none can run. A loop that never waits
   * never hears them. *)
  let tick = Source.timer caps 0.02 in
  (* what the machine reads: the mouse in the Display's coordinates
   * (the buttons: 4 red, 2 yellow, 1 blue), the characters waiting *)
  let at = ref (w / 2, h / 2, 0) and keys : int Queue.t = Queue.create () in
  let interrupt = ref false in
  let t0 = Unix.gettimeofday () in
  let host : St_interp.host =
    { St_boot.quiet_host with
      transcript;
      milliseconds = (fun () -> int_of_float ((Unix.gettimeofday () -. t0) *. 1000.));
      mouse = (fun () -> !at);
      keyboard = (fun () -> Queue.take_opt keys) } in
  let squeak = Squeak.start_sized system host (w, h) in
  (* the Display's bytes as an image of the draw device: red, green,
   * blue, then a byte not looked at ("x8b8g8r8", the low byte first) *)
  let picture = Display.alloc display (Rectangle.v 0 0 w h) "x8b8g8r8" ~repl:false Display.white in
  (* [from]: where the first pixel's red is in the bytes *)
  let show (pw : int) (ph : int) (stride : int) (bytes : Bytes.t) (from : int) : unit =
    let s = Bytes.unsafe_to_string bytes in
    let pw = min pw w and ph = min ph h in
    let y = ref 0 in
    while !y < ph do
      let n = min rows (ph - !y) in
      let b = Buffer.create (4 * pw * n) in
      for j = !y to !y + n - 1 do
        let start = (j * stride) + from in
        let len = min (4 * pw) (String.length s - start) in
        Buffer.add_substring b s start len;
        (* (the last pixel's last byte, when the bytes end before it) *)
        for _i = len to (4 * pw) - 1 do Buffer.add_char b '\255' done
      done;
      Display.load picture (Rectangle.v 0 !y pw (!y + n)) (Buffer.contents b);
      y := !y + n
    done;
    Draw.draw !view (Rectangle.add (Rectangle.v 0 0 pw ph) !view.r.min) picture None Point.zero;
    Display.flush display in
  let redraw = ref true in
  while true do
    (* (a button's change ends the pass's listening to the mouse: the
     * world must see a button down before it sees it up) *)
    let pressed = ref false in
    let moved (m : Mouse.state) : unit =
      if m.resized then begin view := Display.screen display; redraw := true end;
      let b = m.buttons and _, _, was = !at in
      at := (m.pos.x - !view.r.min.x, m.pos.y - !view.r.min.y,
             (if b land 1 <> 0 then 4 else 0) lor (if b land 4 <> 0 then 2 else 0) lor (if b land 2 <> 0 then 1 else 0));
      let _, _, now = !at in
      if now <> was then pressed := true in
    let typed (ks : string list) : unit =
      List.iter (fun (k : string) -> if k = "\003" then interrupt := true else match key_code k with Some c -> Queue.add c keys | None -> ()) ks in
    (* the mouse, the keys or the tick, whichever comes first: waited
     * for; then what else is there already (the ticks a slow pass let
     * gather, too) *)
    Event.select [
      Event.wrap (Mouse.receive mouse) moved;
      Event.wrap (Keyboard.receive keyboard) typed;
      Event.wrap (Event.receive tick) (fun () -> ());
    ];
    let rec more () : unit =
      match (if !pressed then None else Event.poll (Mouse.receive mouse)) with
      | Some m -> moved m; more ()
      | None -> (
          match Event.poll (Keyboard.receive keyboard) with
          | Some ks -> typed ks; more ()
          | None -> (match Event.poll (Event.receive tick) with Some () -> more () | None -> ())) in
    more ();
    Squeak.cycle squeak ~interrupt:!interrupt;
    interrupt := false;
    if Squeak.changed squeak || !redraw then begin
      redraw := false;
      match Squeak.bits32 squeak with
      | Some (pw, ph, stride, bits) -> show pw ph stride bits 1
      | None -> (match Squeak.pixels squeak with Some (pw, ph, px) -> show pw ph (4 * pw) px 0 | None -> ())
    end
  done
