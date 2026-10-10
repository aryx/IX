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

(* The keys that edit a text, which the console gives as characters
 * too. With a /dev/kbd they are taken from the console all the same,
 * a key down from its character to the next tick: the console's
 * characters and the kbd's messages are two files, read by two
 * processes, and nothing says which of two things came first when one
 * is in each. A line typed at mini-drscheme's prompt in a window of
 * mini-rio's under mini-qemu, a frame there some seconds: the kbd's
 * messages of the whole line were here, its Enter with them, before the
 * line's last nine characters, which rio gives one a read; the line was
 * broken where Enter found it, and not run. In the console's
 * characters, Enter is after the line. (A letter is not a matter: what
 * is typed is the console's already. The arrows stay the kbd's: a game
 * holds them.) *)
let edits = [ "Enter"; "Backspace"; "Tab"; "Escape" ]

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
  (* A game makes much at each frame and keeps little (a float is a
   * block for mini-ml): the heap is let to be eight times what is
   * alive, where twice is mini-ml's runtime's rule, and its collector,
   * which copies all that is alive each time, runs a quarter as often.
   * It was a fifth of TinyWolfenstein's instructions
   * (docs/plans/plan_playground_speed.md). OCaml's own name for it. *)
  (* Not for a program that says heap=modest among its flags (or is
   * told so on its command line): one that keeps much, a document's
   * page drawn, a file read. Eight times megabytes alive is the
   * collector's two halves at their largest at once, 128 MB of a
   * board of 512 for one program (mini-page on a file of 12 KB:
   * docs/plans/bugs/ix.md, 2026-10-10). old: set for every program *)
  if List.assoc_opt "heap" flags <> Some "modest" then
  Gc.set { (Gc.get ()) with Gc.space_overhead = 700 };
  let display = Display.init caps in
  let win = ref (w.make display) in
  let show (shapes : Playground.shape list) (fps : int) : bool = w.show display !win shapes fps in
  let mouse = Mouse.init caps and keyboard = Keyboard.init caps in
  (* the keys held, where the system says them (None: only what is typed).
   * Here, before the program starts: each of these is a process
   * forked to read a file, and a fork copies the memory touched so far
   * (the kernel shares none of it). old: asked after Session.start,
   * that is after the program's init: mini-page's draws its first
   * page, tens of megabytes touched by then, copied for a process that
   * reads /dev/kbd: the two no longer fit in mini-9pi's 192 MB, and
   * the program was ended for want of a page (2026-10-10:
   * docs/plans/bugs/ix.md) *)
  let kbd = Keyboard.held caps in
  (* (and the clock's, which the loop below asks: the fourth) *)
  let alarm = Source.alarm caps in
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
  let said = List.assoc_opt "keys" (Playground.flags_of_strings cli.args) = Some "on" in
  let down = ref [] in
  (* the keys that went down since the last tick; those whose release
   * waits for the next one (without a kbd: every key typed) *)
  let fresh = ref [] and held = ref [] in
  let on_held (m : string) : unit =
    (* old: let now = List.map key_name (Keyboard.keys m) in *)
    let now = List.filter (fun (k : string) -> not (List.mem k edits)) (List.map key_name (Keyboard.keys m)) in
    (* (the flag keys=on: each message's keys on the standard error, for
     * kernels/9pi/tests/perf/held.py, which looks for a release lost) *)
    if said then (prerr_string ("keys: " ^ String.concat "," now ^ "\n"); flush stderr);
    (* A key that went down since the last tick and is up already (a
     * tap shorter than a frame: a tenth of a second, when a frame is
     * that long) stays down until a tick has seen it: a program that
     * asks at each tick which keys are down (Playground.game) would
     * never know it was pressed. Its release is kept for after that
     * tick ([held], [release]). *)
    List.iter
      (fun (k : string) ->
        if not (List.mem k now) then
          if List.mem k !fresh then held := k :: !held else Session.event run (Sub.EKeyChanged (false, k)))
      !down;
    List.iter
      (fun (k : string) ->
        if not (List.mem k !down) then begin
          (* (down again before its release was given: it never came up) *)
          if List.mem k !held then held := List.filter (fun (h : string) -> h <> k) !held
          else Session.event run (Sub.EKeyChanged (true, k));
          fresh := k :: !fresh
        end)
      now;
    down := now in
  (* A key that edits is a tick's only key. A program asks at each
   * tick what was typed and which keys went down, and takes one of the
   * two (TinyOffice's text: what was typed, else Enter, else
   * Backspace), a key down being one press however many times it was
   * struck: right where a tick has one event, a person's hands and a
   * frame of a sixtieth of a second, wrong where the keys of some
   * frames come at once, a slow frame or a session typed by a program.
   * "Typed on mini-9pi." and Enter, on mini-9pi under QEMU: the Enter
   * in the tick of the full stop, and no line broken. So the tick is
   * given first ([tick], the loop's), when the keys since the last one
   * are a character before an edit, or an edit before anything. *)
  let typed = ref false and edited = ref false in
  let tick : (unit -> unit) ref = ref (fun () -> ()) in
  let on_keys (keys : string list) : unit =
    List.iter
      (fun (k : string) ->
        let name = key_name k in
        let edit = List.mem name edits in
        if !edited || (edit && !typed) then !tick ();
        if kbd = None || edit then begin
          Session.event run (Sub.EKeyChanged (true, name));
          held := name :: !held
        end;
        if edit then edited := true;
        if String.length k > 0 && k.[0] >= ' ' && k <> Keyboard.up && k <> Keyboard.down && k <> Keyboard.left && k <> Keyboard.right then begin
          Session.event run (Sub.ETyped k);
          typed := true
        end)
      keys in
  let release () : unit =
    List.iter (fun (name : string) -> Session.event run (Sub.EKeyChanged (false, name))) (List.rev !held);
    held := [];
    fresh := [];
    typed := false;
    edited := false in
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
    (* What wakes the loop for a frame: a process that sleeps and says so
     * (Plan 9 has no other way to wait for a time or a key, whichever
     * is first). It is asked each time, for the next tick's time
     * (Source.alarm), and not left to say so a hundred times a second:
     * a frame may take a tenth of a second, the wakings piled up before
     * the loop, and a key typed meanwhile waited behind them all (the
     * author, playing: "sometimes nothing is sent and then it's
     * buffered or something and send; for a game it does not feel
     * right").
     * old: let ticks = Source.timer caps 0.01 in *)
    let ask, ticks = alarm in
    let start = Unix.gettimeofday () in
    (* the ticks given so far; the frames drawn in the second that began at [since], and in the one before it *)
    let given = ref 0 and since = ref start and drawn = ref 0 and fps = ref 0 in
    (* (a sleep is counted in the kernel's ticks, a hundredth of a second,
     * and rounded up: asked a tick short of the time. A tick already
     * due, the frame having taken longer than a sixtieth of a second, is
     * not slept for: a sleep of no time gives the processor to who waits
     * for it and comes back, where the shortest sleep waited for the
     * kernel's next tick, 5 ms of each frame of a game that is late.
     * old: ask (if left > 0.010 then left -. 0.010 else 0.001)) *)
    let wake () : unit =
      let left = start +. (float (!given + 1) /. 60.) -. Unix.gettimeofday () in
      ask (if left > 0.010 then left -. 0.010 else if left > 0. then 0.001 else 0.) in
    let mice = Event.wrap (Mouse.receive mouse) (fun (m : Mouse.state) -> Mouse m)
    and keys = Event.wrap (Keyboard.receive keyboard) (fun (k : string list) -> Keys k)
    and clock = Event.wrap (Event.receive ticks) (fun () -> Tick) in
    let holds = match kbd with Some h -> [ Event.wrap (Keyboard.message h) (fun (m : string) -> Held m) ] | None -> [] in
    let quit = ref false and ticked = ref false in
    (* The meter (the flag stats=on): every 40 frames drawn, what one
     * cost, on the standard error: the program's ticks (its update), its
     * view made, the frame shown (the platform says more of that part). *)
    (* (the command line's flags, not the ones the program chose to pass on) *)
    let stats = List.assoc_opt "stats" (Playground.flags_of_strings cli.args) = Some "on" in
    let m_update = ref 0. and m_view = ref 0. and m_show = ref 0. and m_ticks = ref 0 and m_frames = ref 0 and m_since = ref start in
    let meter (update : float) (view : float) (shown : float) (ticks : int) : unit =
      m_update := !m_update +. update; m_view := !m_view +. view; m_show := !m_show +. shown; m_ticks := !m_ticks + ticks;
      incr m_frames;
      if !m_frames = 40 then begin
        let t = Unix.gettimeofday () in
        prerr_string
          (Printf.sprintf "40 frames in %.1f s, %d ticks: update %.0f ms, view %.0f ms, show %.0f ms each\n" (t -. !m_since) !m_ticks
             (!m_update *. 25.) (!m_view *. 25.) (!m_show *. 25.));
        flush stderr;
        m_update := 0.; m_view := 0.; m_show := 0.; m_ticks := 0; m_frames := 0; m_since := t
      end in
    let input (i : input) : unit =
      match i with
      | Keys k when quits k -> quit := true
      | Keys k -> on_keys k
      | Held m -> on_held m
      | Mouse m ->
          if m.resized then resized ();
          on_mouse m
      | Tick -> ticked := true in
    (* What waits, taken without waiting: the keys and the mouse, before
     * a frame is drawn. The threads are cooperative: what a source has
     * read is given by its thread, which runs when this one lets it
     * (yield); only then is there something to take. *)
    let rec pending (e : input Event.event) : unit =
      Thread.yield ();
      match Event.poll e with Some i -> input i; pending e | None -> () in
    (* (a tick before its time, for [on_keys]: the next is not given
     * sooner for it, the ticks due being counted from [given]) *)
    tick := (fun () -> incr given; Session.frame run None !given (start +. (float !given /. 60.)); release ());
    wake ();
    let rec loop () : unit =
      input (Event.select ([ mice; keys; clock ] @ holds));
      pending keys;
      List.iter pending holds;
      pending mice;
      if !ticked && not !quit then begin
        ticked := false;
        let now = Unix.gettimeofday () in
        let due = int_of_float ((now -. start) *. 60.) - !given in
        (* (more than [most]: the others are not owed any more) *)
        if due > most then given := !given + (due - most);
        let due = min due most in
        for tick = 1 to due do
          ignore tick;
          incr given;
          (* A tick's time is its own, a sixtieth of a second after the
           * one before, not the time the ticks due were all given at:
           * what is given at once is several updates, and the Gui
           * knows one from the next by its time (a click is one
           * update's: a menu opened by the first was closed by the
           * second, mini-office's on mini-9pi and on Linux).
           * old: Session.frame run None !given now *)
          Session.frame run None !given (start +. (float !given /. 60.));
          release ()
        done;
        if due > 0 then begin
          (* (a frame like the one before is not drawn, but counted: the
           * frames a second say how fast the game goes, and a game whose
           * picture stays most of the time, Tetris between two falls of
           * its piece, said 4 where it was making 60 (the author: "tetris
           * still display 4 fps"); the meter has the drawn ones only.
           * old: if did then incr drawn) *)
          let t1 = if stats then Unix.gettimeofday () else 0. in
          let shapes = Session.view run in
          let t2 = if stats then Unix.gettimeofday () else 0. in
          let did = show shapes !fps in
          incr drawn;
          if stats && did then meter (t1 -. now) (t2 -. t1) (Unix.gettimeofday () -. t2) due;
          if now -. !since >= 1. then (fps := !drawn; drawn := 0; since := now)
        end;
        wake ()
      end;
      if not !quit then loop () in
    loop ()
  end
