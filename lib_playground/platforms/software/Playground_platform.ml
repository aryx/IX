(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* The platform that computes its pixels, on Plan 9 (mini-9pi; in a
 * window of mini-rio's or on the bare screen): docs/plans/plan_playground.md,
 * stage 2. The playground's software platform, SDL's window become the
 * draw device's.
 *
 * A frame is drawn by the program, in its own memory
 * (Shape_render_software, in a Framebuffer: lib_graphics/software), and
 * given to the device as a picture: the bytes loaded into an image of
 * the kernel's (Display.load), which is then drawn on the window
 * (Draw.draw) and shown (Display.flush). The device draws nothing but
 * that: the other platform (../draw) asks it for each shape.
 *
 * Not the whole picture each time: the parts of it that changed since
 * the frame before (Redraw). A whole frame of 480 by 480 is a second
 * under QEMU (the shapes 0.6 s, the load 0.2), and a key waited for it.
 *
 * The picture is a square, the playground's 1000 units on the smaller
 * of the window's sides, in its middle.
 *
 * The clock. A program's Tick is a sixtieth of a second of its world,
 * whatever the machine (a piece of Tetris falls by ticks): so the ticks
 * due since the start are counted on the system's clock and all given,
 * then one frame is drawn. A machine that draws 5 frames a second plays
 * the same game as one that draws 60, less smoothly.
 *
 * The keys. Plan 9's console gives characters, as they are typed, and
 * no key's release: a key is down from its character to the next tick,
 * which a program that asks for presses (Sub.on_key_down) is content
 * with; one that asks whether a key is held is not, yet (the plan's
 * stage 4). Ctrl-Q ends the program, as on the playground's platforms,
 * and so does Delete.
 *
 * usage: game [-frames n [-script script] [-fixed-time seconds]] [name=value]...
 *   redraw=all  (a flag) each frame drawn whole, not what changed only:
 *               to see what Redraw saves
 *   -frames n   n frames at once, the script's keys in them, then the
 *               picture stays: a session that is the same each time,
 *               for a test to compare its screen (Session.mli) *)

type input = Mouse of Mouse.state | Keys of string list | Tick

(* a character of Plan 9's keyboard, as the playground names its key (a
 * browser's names; a letter is its own) *)
let key_name (k : string) : string =
  if k = Keyboard.up then "ArrowUp"
  else if k = Keyboard.down then "ArrowDown"
  else if k = Keyboard.left then "ArrowLeft"
  else if k = Keyboard.right then "ArrowRight"
  else match k with " " -> "space" | "\n" -> "Enter" | "\b" -> "Backspace" | "\t" -> "Tab" | "\027" -> "Escape" | k -> k

(* what ends the program: Ctrl-Q, the playground's platforms' key, and
 * Delete, Plan 9's own for it *)
let quits (keys : string list) : bool = List.mem "\017" keys || List.mem "\127" keys

(* where the program draws: the window, the picture's square in it, the
 * kernel's image the program's pixels are loaded into, and what was
 * drawn last (Redraw: a frame is the parts that changed) *)
type window = { view : Display.image; at : Rectangle.t; image : Display.image; redraw : Redraw.t; size : int; scale : float }

let window (display : Display.t) : window =
  let view = Display.screen display in
  let w = Rectangle.dx view.r and h = Rectangle.dy view.r in
  let n = max 1 (min w h) in
  let x = view.r.min.x + ((w - n) / 2) and y = view.r.min.y + ((h - n) / 2) in
  let white = Display.color display Display.white in
  Draw.fill view view.r white;
  Display.free white;
  let scale = float n /. Playground.default_width in
  let options = { Shape_render_software.default_options with antialiasing = Playground.default_rendering.antialiasing } in
  { view; at = Rectangle.v x y (x + n) (y + n); size = n; scale;
    image = Display.alloc display (Rectangle.v 0 0 n n) "x8r8g8b8" ~repl:false Display.white;
    redraw = Redraw.create ~width:n ~height:n ~scale options }

(* a frame: its parts that changed drawn here, each loaded into the
 * kernel's image where it goes, and that rectangle of the image drawn
 * on the window *)
let show (display : Display.t) (win : window) (shapes : Playground.shape list) (fps : int) : unit =
  let counter = Session.fps_counter ~width:win.size ~height:win.size ~scale:win.scale fps in
  let parts = Redraw.frame win.redraw (shapes @ [ counter ]) in
  List.iter
    (fun (((x0, y0, x1, _), fb) : (int * int * int * int) * Framebuffer.t) ->
      let w = x1 - x0 in
      (* (one message, one write, whatever its size: the first version
       * gave the rows 60,000 bytes at a time, a copy made of each) *)
      Display.load_sub win.image (Rectangle.v x0 y0 x1 (y0 + fb.height)) fb.pixels 0 (4 * w * fb.height);
      let corner : Point.t = Point.v (win.at.min.x + x0) (win.at.min.y + y0) in
      Draw.draw win.view (Rectangle.v corner.x corner.y (corner.x + w) (corner.y + fb.height)) win.image None (Point.v x0 y0))
    parts;
  if parts <> [] then Display.flush display

let flags (caps : < Cap.argv ; .. >) : Playground.flags = Playground.flags_of_strings (Session.parse (CapSys.argv caps)).args

(* the ticks given at once, at most: a program stopped a while (its
 * window hidden, the machine busy) does not run them all when it is back *)
let most = 30

let run_app (caps : < Cap.argv ; Cap.draw ; Cap.mouse ; Cap.keyboard ; Cap.fork ; Cap.open_out ; .. >) (flags : Playground.flags)
    (app : ('model, 'msg) Playground.app) : unit =
  let cli = Session.parse (CapSys.argv caps) in
  (* (the flag redraw=all: each frame the whole picture, the simple way) *)
  if List.assoc_opt "redraw" flags = Some "all" then Redraw.enabled := false;
  let display = Display.init caps in
  let win = ref (window display) in
  let mouse = Mouse.init caps and keyboard = Keyboard.init caps in
  let run = Session.start app flags in
  (* the mouse: its place in the playground's units (the middle of the
   * picture is 0, 0, up is more), a button by its change *)
  let buttons = ref 0 in
  let on_mouse (m : Mouse.state) : unit =
    let at = !win.at in
    let k = Playground.default_width /. float (Rectangle.dx at) in
    let x = float (m.pos.x - at.min.x) -. (float (Rectangle.dx at) /. 2.) and y = (float (Rectangle.dy at) /. 2.) -. float (m.pos.y - at.min.y) in
    Session.event run (Sub.EMouseMove (int_of_float (x *. k), int_of_float (y *. k)));
    let changed (bit : int) : bool option = if m.buttons land bit <> !buttons land bit then Some (m.buttons land bit <> 0) else None in
    (match changed 1 with Some down -> Session.event run (Sub.EMouseButton down) | None -> ());
    (match changed 2 with Some down -> Session.event run (Sub.EMiddleMouseButton down) | None -> ());
    (match changed 4 with Some down -> Session.event run (Sub.ERightMouseButton down) | None -> ());
    buttons := m.buttons in
  (* the keys down until the next tick *)
  let held = ref [] in
  let on_keys (keys : string list) : unit =
    List.iter
      (fun (k : string) ->
        let name = key_name k in
        Session.event run (Sub.EKeyChanged (true, name));
        held := name :: !held;
        if String.length k > 0 && k.[0] >= ' ' && k <> Keyboard.up && k <> Keyboard.down && k <> Keyboard.left && k <> Keyboard.right then
          Session.event run (Sub.ETyped k))
      keys in
  let release () : unit =
    List.iter (fun (name : string) -> Session.event run (Sub.EKeyChanged (false, name))) (List.rev !held);
    held := [] in
  let resized () : unit =
    Display.free !win.image;
    win := window display;
    Session.event run (Sub.EResized (int_of_float Playground.default_width, int_of_float Playground.default_height)) in
  if cli.frames > 0 then begin
    (* a session played at once, then its picture, until Ctrl-Q *)
    for n = 1 to cli.frames do
      Session.frame run cli.script n (Session.time_of_frame cli n)
    done;
    show display !win (Session.view run) 0;
    let rec wait () : unit =
      match Event.select [ Event.wrap (Mouse.receive mouse) (fun (m : Mouse.state) -> Mouse m); Event.wrap (Keyboard.receive keyboard) (fun (k : string list) -> Keys k) ] with
      | Keys k when quits k -> ()
      | Mouse m when m.resized -> resized (); show display !win (Session.view run) 0; wait ()
      | Keys _ | Mouse _ | Tick -> wait () in
    wait ()
  end
  else begin
    (* What wakes the loop: a process that sleeps and says so (Plan 9
     * has no other way to wait for a time or a key, whichever is first).
     * It sleeps a hundredth of a second, the kernel's own tick, not a
     * sixtieth: a sleep is counted in the kernel's ticks, so one of 16
     * ms was 20 or more, and the frames 43 to 46 a second. Each time it
     * wakes, the clock says whether a frame is due. *)
    let ticks = Source.timer caps 0.01 in
    let start = Unix.gettimeofday () in
    (* the ticks given so far; the frames drawn in the second that began at [since], and in the one before it *)
    let given = ref 0 and since = ref start and drawn = ref 0 and fps = ref 0 in
    let mice = Event.wrap (Mouse.receive mouse) (fun (m : Mouse.state) -> Mouse m)
    and keys = Event.wrap (Keyboard.receive keyboard) (fun (k : string list) -> Keys k)
    and clock = Event.wrap (Event.receive ticks) (fun () -> Tick) in
    let quit = ref false in
    let input (i : input) : unit =
      match i with
      | Keys k when quits k -> quit := true
      | Keys k -> on_keys k
      | Mouse m ->
          if m.resized then resized ();
          on_mouse m
      | Tick -> () in
    (* what waits, taken without waiting: the keys and the mouse before a
     * frame is drawn (a key is not kept behind the frames owed), and the
     * ticks that came while the last one was (they are one look at the
     * clock, which says how many are due) *)
    let rec pending (e : input Event.event) : unit =
      match Event.poll e with Some i -> input i; pending e | None -> () in
    let rec loop () : unit =
      let first = Event.select [ mice; keys; clock ] in
      input first;
      pending keys;
      pending mice;
      pending clock;
      if first = Tick && not !quit then begin
        let now = Unix.gettimeofday () in
        let due = int_of_float ((now -. start) *. 60.) - !given in
        (* (more than [most]: the others are not owed any more) *)
        if due > most then given := !given + (due - most);
        let due = min due most in
        for tick = 1 to due do
          ignore tick;
          incr given;
          Session.frame run None !given now;
          release ()
        done;
        if due > 0 then begin
          show display !win (Session.view run) !fps;
          incr drawn;
          if now -. !since >= 1. then (fps := !drawn; drawn := 0; since := now)
        end
      end;
      if not !quit then loop () in
    loop ()
  end
