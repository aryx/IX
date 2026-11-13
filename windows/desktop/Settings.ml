(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* settings: the desktop's settings in a window (plan_desktop.md): the
 * wallpaper, the clock, the panel's side, the mouse, the volume, and what
 * the machine is. Each change is written at once to
 * $home/lib/desktop/settings (Prefs), which the panel and the desk look at
 * again; the mouse and the volume are also written to their devices.
 *
 *     settings          opens the window
 *     settings -apply   tells the kernel the file's mouse and volume, then
 *                       ends; desktop's start runs it first
 *
 *     Wallpaper  [#] [#] [#] [#] [#]
 *     Picture    [/usr/pad/lib/sea.jpg_____]  [Use]
 *     Clock      (24 h) (12 h) (none)
 *     Panel      (bottom) (top)
 *     Mouse      [x] buttons swapped  [ ] faster
 *     Volume     [-]  70  [+]
 *     ----------------------------------------
 *     memory 512 MB, 21% of the programs' taken; 1 core; screen 1024x768
 *
 * There is no toolkit: there is a row of boxes, each one a rectangle and
 * what a press on it does, drawn with lib_graphics as the panel is. It
 * waits for the mouse and the keys. *)

type caps = < Cap.draw; Cap.mouse; Cap.keyboard; Cap.fork; Cap.env; Cap.open_in; Cap.open_out >

let read_file (caps : < Cap.open_in; .. >) path =
  try Some (FS.read caps (Fpath.v path)) with Sys_error _ | Unix.Unix_error _ -> None

(* a device's control file written, a line a write; what refuses, said nothing *)
let tell (caps : < Cap.open_out; .. >) path line =
  try
    let fd = FS.open_device_fd caps path in
    Fun.protect ~finally:(fun () -> Unix.close fd) (fun () -> ignore (Unix.write_substring fd line 0 (String.length line)))
  with Unix.Unix_error _ | Sys_error _ -> ()

let apply_devices caps (p : Prefs.t) =
  List.iter (tell caps "/dev/mousectl") (Prefs.mouse_lines p);
  Option.iter (fun v -> tell caps "/dev/volume" (Printf.sprintf "audio out %d" v)) p.volume

let save (caps : < Cap.open_out; .. >) home (p : Prefs.t) =
  (try FS.mkdir caps (home ^ "/lib") 0o775 with Unix.Unix_error _ | Sys_error _ -> ());
  (try FS.mkdir caps (home ^ "/lib/desktop") 0o775 with Unix.Unix_error _ | Sys_error _ -> ());
  try FS.write caps (Fpath.v (Prefs.path home)) (Prefs.print p) with Unix.Unix_error _ | Sys_error _ -> ()

(* the volume the kernel says now, if it has a /dev/volume *)
let volume_now caps =
  match read_file caps "/dev/volume" with
  | Some t ->
      List.find_map (fun l ->
          match List.filter (fun w -> w <> "") (String.split_on_char ' ' l) with
          | [ "audio"; "out"; v ] -> int_of_string_opt v
          | _ -> None) (String.split_on_char '\n' t)
  | None -> None

(* what the machine is, a line *)
let about caps (screen : Rectangle.t) =
  let memory = match read_file caps "/dev/swap" with
    | Some t ->
        let first = List.hd (String.split_on_char '\n' t) in
        let bytes = match String.split_on_char ' ' first with n :: _ -> int_of_string_opt n | [] -> None in
        let taken =
          List.find_map (fun l ->
              match String.split_on_char ' ' (String.trim l) with
              | [ pair; "user" ] -> (
                  match String.split_on_char '/' pair with
                  | [ u; a ] -> (match int_of_string_opt u, int_of_string_opt a with
                      | Some u, Some a when a > 0 -> Some (Printf.sprintf ", %d%% of the programs' taken" (u * 100 / a))
                      | _ -> None)
                  | _ -> None)
              | _ -> None) (String.split_on_char '\n' t) in
        let taken = match taken with Some s -> s | None -> "" in
        (match bytes with Some b -> Printf.sprintf "memory %d MB%s; " (b / 1048576) taken | None -> "")
    | None -> "" in
  let cores = match read_file caps "/dev/sysstat" with
    | Some t -> let n = List.length (List.filter (fun l -> String.trim l <> "") (String.split_on_char '\n' t)) in Printf.sprintf "%d core%s; " n (if n = 1 then "" else "s")
    | None -> "" in
  Printf.sprintf "%s%sscreen %dx%d" memory cores (Rectangle.dx screen) (Rectangle.dy screen)

type event = Mouse of Mouse.state | Keys of string list

type action = Wall of int | Field | Use | Clock of string | Edge of string | Swap | Faster | Volume of int

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  let home = try CapSys.getenv caps "home" with Not_found -> "/usr/pad" in
  let prefs = ref (match read_file caps (Prefs.path home) with Some t -> Prefs.parse t | None -> Prefs.default) in
  if Array.length argv > 1 && argv.(1) = "-apply" then begin apply_devices caps !prefs; Exit.OK end
  else begin
  if !prefs.volume = None then prefs := { !prefs with volume = volume_now caps };
  let display = Display.init caps in
  let font = Font.default display and mouse = Mouse.init caps and keyboard = Keyboard.init caps in
  let color c = Display.color display (Display.rgb ((c lsr 16) land 255) ((c lsr 8) land 255) (c land 255)) in
  let paper = color 0xf5f8fb and black = color 0 and white = color 0xffffff and line = color 0x335577 in
  let shown = color 0x336699 and pale = color 0xd8e2ec and grey = color 0x667788 in
  let swatches = List.map (fun (_, c) -> (c, color c)) Prefs.colours in
  let field = ref (match !prefs.wallpaper with Prefs.Picture p -> p | Prefs.Colour _ -> "") and typing = ref false in
  let changed p =
    prefs := p;
    save caps home p;
    apply_devices caps p in
  let text_at (view : Display.image) x y ink s = ignore (Font.string view (Point.v x y) ink font s) in
  (* a button: its box, pale or the colour of what is chosen, and its word *)
  let button (view : Display.image) (r : Rectangle.t) on word =
    Draw.fill view r (if on then shown else pale);
    Draw.border view r 1 line;
    text_at view (r.min.x + 6) (r.min.y + ((Rectangle.dy r - Font.height font) / 2)) (if on then white else black) word in
  (* everything, and the boxes a press means something in *)
  let draw (view : Display.image) : (Rectangle.t * action) list =
    let p = !prefs in
    Draw.fill view view.r paper;
    let x0 = view.r.min.x + 12 and y0 = view.r.min.y + 12 and row_h = 36 in
    let cx = x0 + 100 in
    let row i = y0 + (i * row_h) in
    let label i s = text_at view x0 (row i + 6) black s in
    let boxes = ref [] in
    let add r a = boxes := (r, a) :: !boxes in
    let words i (choices : (string * action * bool) list) =
      ignore (List.fold_left (fun x (w, a, on) ->
          let r = Rectangle.v x (row i) (x + Font.width font w + 14) (row i + 26) in
          button view r on w; add r a; r.max.x + 8) cx choices) in
    label 0 "Wallpaper";
    List.iteri (fun k (c, img) ->
        let r = Rectangle.v (cx + (k * 40)) (row 0) (cx + (k * 40) + 32) (row 0 + 26) in
        Draw.fill view r img;
        let on = p.wallpaper = Prefs.Colour c in
        Draw.border view r (if on then 3 else 1) (if on then black else line);
        add r (Wall c)) swatches;
    label 1 "Picture";
    let fr = Rectangle.v cx (row 1) (view.r.max.x - 70) (row 1 + 26) in
    Draw.fill view fr white;
    Draw.border view fr (if !typing then 2 else 1) (if !typing then shown else line);
    text_at view (fr.min.x + 4) (fr.min.y + 6) black
      (Taskbar.shorten (Font.width font) (Rectangle.dx fr - 8) (!field ^ if !typing then "_" else ""));
    add fr Field;
    let ur = Rectangle.v (fr.max.x + 8) (row 1) (view.r.max.x - 12) (row 1 + 26) in
    button view ur (match p.wallpaper with Prefs.Picture _ -> true | Prefs.Colour _ -> false) "Use"; add ur Use;
    label 2 "Clock";
    words 2 [ ("24 h", Clock "24", p.clock = "24"); ("12 h", Clock "12", p.clock = "12"); ("none", Clock "off", p.clock = "off") ];
    label 3 "Panel";
    words 3 [ ("bottom", Edge "bottom", p.edge = "bottom"); ("top", Edge "top", p.edge = "top") ];
    label 4 "Mouse";
    words 4 [ ((if p.swap then "[x]" else "[ ]") ^ " buttons swapped", Swap, false);
              ((if p.accelerated then "[x]" else "[ ]") ^ " faster", Faster, false) ];
    label 5 "Volume";
    (match p.volume with
     | Some v -> words 5 [ ("-", Volume (max 0 (v - 10)), false); (Printf.sprintf "%3d" v, Volume v, false); ("+", Volume (min 100 (v + 10)), false) ]
     | None -> text_at view cx (row 5 + 6) grey "no sound device");
    Draw.fill view (Rectangle.v x0 (row 6 + 4) (view.r.max.x - 12) (row 6 + 5)) line;
    text_at view x0 (row 6 + 14) grey (Taskbar.shorten (Font.width font) (Rectangle.dx view.r - 24) (about caps (Display.whole display).r));
    Display.flush display;
    !boxes in
  let act (a : action) =
    let p = !prefs in
    match a with
    | Wall c -> typing := false; changed { p with wallpaper = Prefs.Colour c }
    | Field -> typing := true
    | Use -> typing := false; if !field <> "" then changed { p with wallpaper = Prefs.Picture !field }
    | Clock c -> changed { p with clock = c }
    | Edge e -> changed { p with edge = e }
    | Swap -> changed { p with swap = not p.swap }
    | Faster -> changed { p with accelerated = not p.accelerated }
    | Volume v -> changed { p with volume = Some v } in
  let rec loop (view : Display.image) boxes was =
    match Event.select [ Event.wrap (Mouse.receive mouse) (fun m -> Mouse m); Event.wrap (Keyboard.receive keyboard) (fun k -> Keys k) ] with
    | Mouse m when m.resized -> let view = Display.screen display in loop view (draw view) m.buttons
    | Mouse m when m.buttons land 1 <> 0 && was = 0 ->
        (match List.find_opt (fun ((r : Rectangle.t), _) -> Rectangle.contains r m.pos) boxes with
         | Some (_, a) -> act a
         | None -> typing := false);
        loop view (draw view) m.buttons
    | Mouse m -> loop view boxes m.buttons
    | Keys keys when !typing ->
        List.iter (fun k ->
            if k = "\n" then act Use
            else if k = "\b" then (if !field <> "" then field := Utf8.sub !field 0 (Utf8.length !field - 1))
            else if String.length k > 0 && k.[0] >= ' ' && Utf8.code k < 0xF000 then field := !field ^ k) keys;
        loop view (draw view) was
    | Keys keys -> if List.mem "q" keys then Exit.OK else loop view boxes was in
  let view = Display.screen display in
  loop view (draw view) 0
  end

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
