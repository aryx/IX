(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* panel: the bar along a side of the desktop (plan_desktop.md): the start
 * button, a button for each window, the clock. Under rio, in a window of
 * the panel layer:
 *
 *     window -panel -edge bottom 28 panel
 *
 * -noclock: none (a recorded session's screens must not change with the
 * time). The clock says GMT, as date does: the system has no time zone. The
 * settings (settings, Prefs) say its form, 24 or 12 hours or none, and the
 * side the panel is on: it asks rio to move it when that changes.
 *
 * It looks at /dev/wsys once a second (Taskbar says what it does with
 * that), and draws only when what it would draw has changed. It waits
 * for the mouse and that second and for nothing else: a program always
 * on the screen must not cost a frame loop's processor. *)

type caps = < Cap.draw; Cap.mouse; Cap.fork; Cap.env; Cap.readdir; Cap.open_in; Cap.open_out >

type event = Mouse of Mouse.state | Tick

let read_file (caps : < Cap.open_in; .. >) path =
  try Some (FS.read caps (Fpath.v path)) with Sys_error _ | Unix.Unix_error _ -> None

let windows = Wsys.windows
let ask = Wsys.ask

let clock (caps : < Cap.clock; .. >) (p : Prefs.t) =
  let t : Unix.tm = Unix.gmtime (CapUnix.time caps ()) in
  Prefs.clock_text p t.tm_hour t.tm_min

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  let with_clock = not (Array.exists (fun a -> a = "-noclock") argv) in
  (* the settings (Prefs), looked at again at each second: the clock's
   * form, the side the panel is on *)
  let home = try CapSys.getenv caps "home" with Not_found -> "" in
  let prefs () = match read_file caps (Prefs.path home) with Some t -> Prefs.parse t | None -> Prefs.default in
  let display = Display.init caps in
  let font = Font.default display and mouse = Mouse.init caps in
  let color r g b = Display.color display (Display.rgb r g b) in
  let bar = color 0x33 0x55 0x77 and raised = color 0xb8 0xcc 0xe0 and front = color 0x33 0x66 0x99 in
  let hidden = color 0x44 0x66 0x88 and black = color 0 0 0 and white = color 0xff 0xff 0xff in
  let clock_width = if with_clock then Font.width font "12:00 pm" + 8 else 0 in
  let set_alarm, alarm = Source.alarm caps in
  let text (view : Display.image) (r : Rectangle.t) ink s =
    let s = Taskbar.shorten (Font.width font) (Rectangle.dx r - 8) s in
    let y = r.min.y + ((Rectangle.dy r - Font.height font) / 2) in
    ignore (Font.string view (Point.v (r.min.x + 4) y) ink font s) in
  let draw (view : Display.image) parts now =
    Draw.fill view view.r bar;
    List.iter (fun (part, (r : Rectangle.t)) ->
        match (part : Taskbar.part) with
        | Start -> Draw.fill view r raised; text view r black "Start"
        | Overview ->
            (* (four small windows: all of them at once) *)
            Draw.fill view r raised;
            let w = (Rectangle.dx r - 12) / 2 and h = (Rectangle.dy r - 10) / 2 in
            List.iter (fun (i, j) ->
                let x = r.min.x + 4 + (i * (w + 4)) and y = r.min.y + 3 + (j * (h + 4)) in
                Draw.fill view (Rectangle.v x y (x + w) (y + h)) front) [ (0, 0); (1, 0); (0, 1); (1, 1) ]
        | Task t ->
            Draw.fill view r (if t.hidden then hidden else if t.current then front else raised);
            text view r (if t.hidden || t.current then white else black) t.label
        | Clock -> if with_clock then text view r white now)
      parts;
    Display.flush display in
  (* [shown]: what is on the screen, not drawn again when it would be the same *)
  (* [edge]: the side asked of rio last, so that it is asked once *)
  let rec loop (view : Display.image) ws shown was edge =
    let p = prefs () in
    let edge =
      if p.edge <> edge then begin ask caps (Printf.sprintf "resize -edge %s %d" p.edge (Rectangle.dy view.r)); p.edge end
      else edge in
    let now = if with_clock then clock caps p else "" in
    let tasks = Taskbar.tasks ws in
    let state = (view.r, tasks, now) in
    let parts = Taskbar.layout view.r tasks clock_width in
    if shown <> Some state then draw view parts now;
    match Event.select [ Event.wrap (Mouse.receive mouse) (fun m -> Mouse m); Event.wrap (Event.receive alarm) (fun () -> Tick) ] with
    | Tick -> set_alarm 1.0; loop view (windows caps) (Some state) was edge
    | Mouse m when m.resized -> loop (Display.screen display) ws None m.buttons edge
    | Mouse m when m.buttons land 1 <> 0 && was = 0 ->
        let lines, ws = match Taskbar.at parts m.pos with
          | Some part -> Taskbar.press ws part
          | None -> [], ws in
        List.iter (ask caps) lines;
        loop view ws (Some state) m.buttons edge
    | Mouse m -> loop view ws (Some state) m.buttons edge in
  set_alarm 1.0;
  (* (it ends when rio does: a note) *)
  loop (Display.screen display) (windows caps) None 0 "bottom"

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
