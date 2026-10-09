(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Window.mli *)

type caps = < Cap.draw; Cap.mouse; Cap.keyboard; Cap.fork >

(* an F key's number (1 to 12), of Plan 9's rune for it (0xF001...) *)
let f_key (k : string) : int option =
  let c = Utf8.code k in
  if c >= 0xF001 && c <= 0xF00C then Some (c - 0xF000) else None

(* a character of the console as Vt.key's name for it, or itself *)
let key_name (k : string) : string =
  match Utf8.code k with
  | 0x0A -> "Enter"
  | 0x08 -> "Backspace"
  | 0x7F -> "Delete"
  | 0x1B -> "Escape"
  | 0x09 -> "Tab"
  | 0xF00D -> "Home"
  | 0xF00E -> "ArrowUp"
  | 0xF00F -> "PageUp"
  | 0xF011 -> "ArrowLeft"
  | 0xF012 -> "ArrowRight"
  | 0xF013 -> "PageDown"
  | 0xF014 -> "Insert"
  | 0xF018 -> "End"
  | 0xF800 -> "ArrowDown"
  | _ -> k

let run (caps : < caps; .. >) (p : 'model Tui.program) : unit =
  let display = Display.init caps in
  let font = Font.default display in
  let cw = Font.width font " " and ch = Font.height font in
  let view = ref (Display.screen display) in
  let mouse = Mouse.init caps and keyboard = Keyboard.init caps in
  let held = Keyboard.held caps in
  (* a tick, for a program that runs (and so that a pass waits: mini-ml's
   * threads take turns only when one waits) *)
  let tick = Source.timer caps 0.05 in
  (* the colours asked so far, each an image of the device's *)
  let colors : (Cells.rgb * Display.image) list ref = ref [] in
  let color (c : Cells.rgb) : Display.image =
    match List.assoc_opt c !colors with
    | Some i -> i
    | None ->
        let r, g, b = c in
        let i = Display.color display (Display.rgb r g b) in
        colors := (c, i) :: !colors;
        i in
  (* the window's cells, from its corner *)
  let surface : Cells.surface =
    { Cells.w = cw; h = ch;
      fill = (fun ((x0, y0, x1, y1) : int * int * int * int) (c : Cells.rgb) ->
        Draw.fill !view (Rectangle.add (Rectangle.v x0 y0 x1 y1) !view.r.min) (color c));
      glyph = (fun (x : int) (y : int) (c : Cells.rgb) (g : string) ->
        ignore (Font.string !view (Point.add !view.r.min (Point.v x y)) (color c) font g)) } in
  let size () : int * int = (max 1 (Rectangle.dy !view.r / ch), max 1 (Rectangle.dx !view.r / cw)) in
  let rows, cols = size () in
  let model = ref (p.update (Tui.Resize (rows, cols)) p.init) in
  (* the screen the window has: None, all of it is to paint *)
  let screen : Curses.t option ref = ref None in
  let drawn = ref None in
  (* the keys down, as /dev/kbd last said *)
  let down : string list ref = ref [] in
  let key (alt : bool) (ctrl : bool) (name : string) : unit =
    match Keys.key alt ctrl name with Some bytes -> model := p.update (Tui.Key bytes) !model | None -> () in
  let typed (ks : string list) : unit =
    List.iter (fun (k : string) ->
      match f_key k with
      (* (with /dev/kbd, an F key is its message's) *)
      | Some n -> if held = None then key false false ("F" ^ string_of_int n)
      | None ->
          let name = key_name k in
          (* a control character is its own bytes: Control-Y, 0x19 *)
          if String.length name = 1 && Char.code name.[0] < 32 then model := p.update (Tui.Key name) !model
          else if String.length name > 1 || Char.code name.[0] < 127 then key false false name) ks in
  (* a message of /dev/kbd: an F key that just went down, with Control or not *)
  let pressed (m : string) : unit =
    let now = Keyboard.keys m in
    (if String.length m > 0 && m.[0] = 'k' then
       List.iter (fun (k : string) ->
         match f_key k with
         | Some n when not (List.mem k !down) -> key false (List.mem Keyboard.ctrl now) ("F" ^ string_of_int n)
         | _ -> ()) now);
    down := now in
  let moved (m : Mouse.state) : unit =
    if m.resized then begin
      view := Display.screen display;
      let rows, cols = size () in
      model := p.update (Tui.Resize (rows, cols)) !model;
      screen := None
    end in
  while not (p.over !model) do
    (* a pass: what changed since the last one, painted *)
    if !drawn != Some !model then begin
      let next = p.view !model in
      (* (all of it: the window first, black past its last cell) *)
      if !screen = None then Draw.fill !view !view.r (color (0, 0, 0));
      Cells.show surface !screen next;
      Display.flush display;
      screen := Some next;
      drawn := Some !model
    end;
    let events = [
      Event.wrap (Mouse.receive mouse) moved;
      Event.wrap (Keyboard.receive keyboard) typed;
      Event.wrap (Event.receive tick) (fun () -> model := p.update (Tui.Tick 0.05) !model);
    ] in
    Event.select (match held with Some h -> Event.wrap (Keyboard.message h) pressed :: events | None -> events)
  done;
  Display.close display
