(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Plan9_loop.mli *)

type input = Mouse of Mouse.state | Keys of string list | Held of string | Tick

(* a character of Plan 9's keyboard, as the playground names its key (a
 * browser's names; a letter is its own) *)
let key_name (k : string) : string =
  if k = Keyboard.up then "ArrowUp"
  else if k = Keyboard.down then "ArrowDown"
  else if k = Keyboard.left then "ArrowLeft"
  else if k = Keyboard.right then "ArrowRight"
  else if k = Keyboard.shift then "Shift"
  else if k = Keyboard.ctrl then "Control"
  else if k = Keyboard.alt then "Alt"
  else match k with " " -> "space" | "\n" -> "Enter" | "\b" -> "Backspace" | "\t" -> "Tab" | "\027" -> "Escape" | "\127" -> "Delete" | k -> k

(* what ends the program: Ctrl-Q, the playground's platforms' key, and
 * Delete, Plan 9's own for it *)
let quits (keys : string list) : bool = List.mem "\017" keys || List.mem "\127" keys

type 'w window = {
  make : Display.t -> 'w;
  at : 'w -> Rectangle.t;
  show : Display.t -> 'w -> Playground.shape list -> int -> bool;
  free : 'w -> unit;
}

let flags (caps : < Cap.argv ; .. >) : Playground.flags = Playground.flags_of_strings (Session.parse (CapSys.argv caps)).args

(* the ticks given at once, at most: a program stopped a while (its
 * window hidden, the machine busy) does not run them all when it is back *)
let most = 30

let run_app (w : 'w window) (caps : < Cap.argv ; Cap.draw ; Cap.mouse ; Cap.keyboard ; Cap.fork ; Cap.open_out ; .. >)
    (flags : Playground.flags) (app : ('model, 'msg) Playground.app) : unit =
  let cli = Session.parse (CapSys.argv caps) in
  let display = Display.init caps in
  let win = ref (w.make display) in
  let show (shapes : Playground.shape list) (fps : int) : bool = w.show display !win shapes fps in
  let mouse = Mouse.init caps and keyboard = Keyboard.init caps in
  let run = Session.start app flags in
  (* the mouse: its place in the playground's units (the middle of the
   * picture is 0, 0, up is more), a button by its change *)
  let buttons = ref 0 in
  let on_mouse (m : Mouse.state) : unit =
    let at = w.at !win in
    let k = Playground.default_width /. float (Rectangle.dx at) in
    let x = float (m.pos.x - at.min.x) -. (float (Rectangle.dx at) /. 2.) and y = (float (Rectangle.dy at) /. 2.) -. float (m.pos.y - at.min.y) in
    Session.event run (Sub.EMouseMove (int_of_float (x *. k), int_of_float (y *. k)));
    let changed (bit : int) : bool option = if m.buttons land bit <> !buttons land bit then Some (m.buttons land bit <> 0) else None in
    (match changed 1 with Some down -> Session.event run (Sub.EMouseButton down) | None -> ());
    (match changed 2 with Some down -> Session.event run (Sub.EMiddleMouseButton down) | None -> ());
    (match changed 4 with Some down -> Session.event run (Sub.ERightMouseButton down) | None -> ());
    buttons := m.buttons in
  (* the keys held, where the system says them (None: only what is typed) *)
  let kbd = Keyboard.held caps in
  let down = ref [] in
  let on_held (m : string) : unit =
    let now = List.map key_name (Keyboard.keys m) in
    List.iter (fun (k : string) -> if not (List.mem k now) then Session.event run (Sub.EKeyChanged (false, k))) !down;
    List.iter (fun (k : string) -> if not (List.mem k !down) then Session.event run (Sub.EKeyChanged (true, k))) now;
    down := now in
  (* (without it: the keys down until the next tick) *)
  let held = ref [] in
  let on_keys (keys : string list) : unit =
    List.iter
      (fun (k : string) ->
        let name = key_name k in
        if kbd = None then begin
          Session.event run (Sub.EKeyChanged (true, name));
          held := name :: !held
        end;
        if String.length k > 0 && k.[0] >= ' ' && k <> Keyboard.up && k <> Keyboard.down && k <> Keyboard.left && k <> Keyboard.right then
          Session.event run (Sub.ETyped k))
      keys in
  let release () : unit =
    List.iter (fun (name : string) -> Session.event run (Sub.EKeyChanged (false, name))) (List.rev !held);
    held := [] in
  let resized () : unit =
    w.free !win;
    win := w.make display;
    Session.event run (Sub.EResized (int_of_float Playground.default_width, int_of_float Playground.default_height)) in
  if cli.frames > 0 then begin
    (* a session played at once, then its picture, until Ctrl-Q *)
    for n = 1 to cli.frames do
      Session.frame run cli.script n (Session.time_of_frame cli n)
    done;
    ignore (show (Session.view run) 0);
    let rec wait () : unit =
      match Event.select [ Event.wrap (Mouse.receive mouse) (fun (m : Mouse.state) -> Mouse m); Event.wrap (Keyboard.receive keyboard) (fun (k : string list) -> Keys k) ] with
      | Keys k when quits k -> ()
      | Mouse m when m.resized -> resized (); ignore (show (Session.view run) 0); wait ()
      | Keys _ | Mouse _ | Held _ | Tick -> wait () in
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
    let holds = match kbd with Some h -> [ Event.wrap (Keyboard.message h) (fun (m : string) -> Held m) ] | None -> [] in
    let quit = ref false in
    let input (i : input) : unit =
      match i with
      | Keys k when quits k -> quit := true
      | Keys k -> on_keys k
      | Held m -> on_held m
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
      let first = Event.select ([ mice; keys; clock ] @ holds) in
      input first;
      pending keys;
      List.iter pending holds;
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
          (* (a frame like the one before is not drawn, and not counted) *)
          if show (Session.view run) !fps then incr drawn;
          if now -. !since >= 1. then (fps := !drawn; drawn := 0; since := now)
        end
      end;
      if not !quit then loop () in
    loop ()
  end
