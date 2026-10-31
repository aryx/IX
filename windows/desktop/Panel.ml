(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* panel: the bar along a side of the desktop (plan_desktop.md): the start
 * button, a button for each window, the clock. Under rio, in a window of
 * the panel layer:
 *
 *     window -panel -edge bottom 28 panel
 *
 * -noclock: none (a recorded session's screens must not change with the
 * time). The clock says GMT, as date does: the system has no time zone.
 *
 * It looks at /dev/wsys once a second (Taskbar says what it does with
 * that), and draws only when what it would draw has changed. It waits
 * for the mouse and that second and for nothing else: a program always
 * on the screen must not cost a frame loop's processor. *)

type caps = < Cap.draw; Cap.mouse; Cap.fork; Cap.readdir; Cap.open_in; Cap.open_out >

type event = Mouse of Mouse.state | Tick

let read_file (caps : < Cap.open_in; .. >) path =
  try Some (FS.read caps (Fpath.v path)) with Sys_error _ | Unix.Unix_error _ -> None

(* (a window may go between two reads: it is then not listed) *)
let windows (caps : < Cap.readdir; Cap.open_in; .. >) : Taskbar.window list =
  let names = try Sys_plan9.dirread caps "/dev/wsys" with Sys_error _ | Unix.Unix_error _ -> [] in
  let ids = List.filter_map (fun (d : Sys_plan9.dir) -> int_of_string_opt d.name) names in
  List.filter_map (fun id ->
      let file name = read_file caps (Printf.sprintf "/dev/wsys/%d/%s" id name) in
      match file "wctl", file "label" with
      | Some wctl, Some label -> Taskbar.window_of id label wctl
      | _ -> None)
    (List.sort compare ids)

(* (one write a line: rio takes a command a write) *)
let ask (caps : < Cap.open_out; .. >) line =
  try
    let fd = FS.open_device_fd caps "/dev/wctl" in
    Fun.protect ~finally:(fun () -> Unix.close fd) (fun () -> ignore (Unix.write_substring fd line 0 (String.length line)))
  with Unix.Unix_error _ | Sys_error _ -> ()

let clock () =
  let t : Unix.tm = Unix.gmtime (Unix.time ()) in
  Printf.sprintf "%02d:%02d" t.tm_hour t.tm_min

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  let with_clock = not (Array.exists (fun a -> a = "-noclock") argv) in
  let display = Display.init caps in
  let font = Font.default display and mouse = Mouse.init caps in
  let color r g b = Display.color display (Display.rgb r g b) in
  let bar = color 0x33 0x55 0x77 and raised = color 0xb8 0xcc 0xe0 and front = color 0x33 0x66 0x99 in
  let hidden = color 0x44 0x66 0x88 and black = color 0 0 0 and white = color 0xff 0xff 0xff in
  let clock_width = if with_clock then Font.width font "00:00" + 8 else 0 in
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
        | Task t ->
            Draw.fill view r (if t.hidden then hidden else if t.current then front else raised);
            text view r (if t.hidden || t.current then white else black) t.label
        | Clock -> if with_clock then text view r white now)
      parts;
    Display.flush display in
  (* [shown]: what is on the screen, not drawn again when it would be the same *)
  let rec loop (view : Display.image) ws shown was =
    let now = if with_clock then clock () else "" in
    let tasks = Taskbar.tasks ws in
    let state = (view.r, tasks, now) in
    let parts = Taskbar.layout view.r tasks clock_width in
    if shown <> Some state then draw view parts now;
    match Event.select [ Event.wrap (Mouse.receive mouse) (fun m -> Mouse m); Event.wrap (Event.receive alarm) (fun () -> Tick) ] with
    | Tick -> set_alarm 1.0; loop view (windows caps) (Some state) was
    | Mouse m when m.resized -> loop (Display.screen display) ws None m.buttons
    | Mouse m when m.buttons land 1 <> 0 && was = 0 ->
        let lines, ws = match Taskbar.at parts m.pos with
          | Some part -> Taskbar.press ws part
          | None -> [], ws in
        List.iter (ask caps) lines;
        loop view ws (Some state) m.buttons
    | Mouse m -> loop view ws (Some state) m.buttons in
  set_alarm 1.0;
  (* (it ends when rio does: a note) *)
  loop (Display.screen display) (windows caps) None 0

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
