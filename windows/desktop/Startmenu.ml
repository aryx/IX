(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* startmenu: what the start button shows (plan_desktop.md): the programs of
 * /lib/desktop/apps by their groups (Apps says why a table), each with its
 * icon. In a window of rio's popup layer, started hidden with the session:
 *
 *     window -popup -hide -label startmenu startmenu
 *
 *     +--------------+----------------+
 *     | Terminal     | [] Tetris      |
 *     | Apps       > | [] Doom        |
 *     | Games      > | [] Quake       |
 *     | Internet   > |                |
 *     | Exit         |                |
 *     +--------------+----------------+
 *
 * The mouse on a group opens it, in the same window: a second window for a
 * submenu would be one more thing to keep above the panel. A press on a
 * program opens it and hides this window; a press elsewhere is rio's, which
 * hides it. So the click is a wctl's line and no program loaded from the
 * card, and a window hidden draws as before and comes back at once.
 *
 * Why a window and not rio's Menu: a menu on the screen's own image would be
 * drawn over by a game running below it, and then copied back wrong; a
 * window is a layer of the kernel's.
 *
 * It takes the size its table needs, at the bottom left of what the screen
 * has for windows, and asks rio for it. A program that is not on the card
 * is not listed.
 *
 * startmenu -try seconds [group]: no menu; each program of the table, or
 * of that group, opened as the menu opens it, left that long, and deleted:
 * all of them looked at once (plan_desktop.md's shakedown), from rio -i or
 * a window. *)

type caps = < Cap.draw; Cap.mouse; Cap.fork; Cap.readdir; Cap.open_in; Cap.open_out >

let read_file (caps : < Cap.open_in; .. >) path =
  try Some (FS.read caps (Fpath.v path)) with Sys_error _ | Unix.Unix_error _ -> None

let ask (caps : < Cap.open_out; .. >) line =
  try
    let fd = FS.open_device_fd caps "/dev/wctl" in
    Fun.protect ~finally:(fun () -> Unix.close fd) (fun () -> ignore (Unix.write_substring fd line 0 (String.length line)))
  with Unix.Unix_error _ | Sys_error _ -> ()

(* the newest window: the largest number in /dev/wsys *)
let newest (caps : < Cap.readdir; .. >) =
  let names = try Sys_plan9.dirread caps "/dev/wsys" with Sys_error _ | Unix.Unix_error _ -> [] in
  List.fold_left (fun n (d : Sys_plan9.dir) -> match int_of_string_opt d.name with Some k -> max n k | None -> n) 0 names

let try_all caps (entries : Apps.entry list) seconds =
  List.iter (fun (e : Apps.entry) ->
      let before = newest caps in
      ask caps (Apps.open_line e);
      Unix.sleepf (float seconds);
      let id = newest caps in
      if id > before then ask caps (Printf.sprintf "delete -id %d" id)) entries

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  let table = match read_file caps "/lib/desktop/apps" with Some t -> Apps.parse t | None -> [] in
  let entries = List.filter (fun e -> Sys.file_exists ("/bin/" ^ Apps.program e)) table in
  if Array.length argv >= 3 && argv.(1) = "-try" then begin
    let group = if Array.length argv >= 4 then Some argv.(3) else None in
    let chosen = List.filter (fun (e : Apps.entry) -> match group with Some g -> e.group = g | None -> e.group <> "top") entries in
    try_all caps chosen (match int_of_string_opt argv.(2) with Some n -> n | None -> 30);
    Exit.OK
  end
  else
  let display = Display.init caps in
  let font = Font.default display and mouse = Mouse.init caps in
  let color r g b = Display.color display (Display.rgb r g b) in
  let paper = color 0xee 0xf2 0xf6 and side = color 0xd8 0xe2 0xec and shown = color 0x33 0x66 0x99 in
  let black = color 0 0 0 and white = color 0xff 0xff 0xff and line = color 0x33 0x55 0x77 in
  (* the icons, once: an image with its alpha *)
  let icons : (string, Display.image) Hashtbl.t = Hashtbl.create 32 in
  let load_icon name =
    if not (Hashtbl.mem icons name) then
      match Option.bind (read_file caps ("/lib/desktop/icons/" ^ name ^ ".txt")) Icon.parse with
      | Some (i : Icon.t) ->
          let r = Rectangle.v 0 0 i.w i.h in
          let image = Display.alloc display r "r8g8b8a8" ~repl:false Display.black in
          Display.load image r i.pixels;
          Hashtbl.replace icons name image
      | None -> () in
  List.iter (fun (e : Apps.entry) -> load_icon e.icon) entries;
  let w, h = Apps.size_of entries in
  ask caps (Printf.sprintf "resize -at sw %d %d" w h);
  let left = Apps.left entries in
  let draw_item (view : Display.image) (r : Rectangle.t) on item =
    if on then Draw.fill view r shown;
    let ink = if on then white else black in
    let y = r.min.y + ((Rectangle.dy r - Font.height font) / 2) in
    let word s x = ignore (Font.string view (Point.v x y) ink font s) in
    match (item : Apps.item) with
    | Run e ->
        (match Hashtbl.find_opt icons e.icon with
         | Some i ->
             let at = Point.v (r.min.x + 4) (r.min.y + ((Rectangle.dy r - Rectangle.dy i.r) / 2)) in
             Draw.draw view (Rectangle.add i.r at) i None Point.zero
         | None -> ());
        word e.name (r.min.x + 26)
    | Group (_, name) ->
        word name (r.min.x + 26);
        word ">" (r.max.x - 14)
    | Exit -> word "Exit" (r.min.x + 26) in
  (* [opened]: the group shown; [over]: the item the mouse is on, by its
   * column and row *)
  let draw (view : Display.image) opened over =
    let top = view.r.min.y + 4 in
    let cut = view.r.min.x + Apps.left_w in
    Draw.fill view (Rectangle.v view.r.min.x view.r.min.y cut view.r.max.y) side;
    Draw.fill view (Rectangle.v cut view.r.min.y view.r.max.x view.r.max.y) paper;
    let column x0 x1 items col =
      List.iteri (fun i item ->
          let y = top + (i * Apps.row_h) in
          draw_item view (Rectangle.v x0 y x1 (y + Apps.row_h)) (over = Some (col, i)) item) items in
    column (view.r.min.x + 2) cut left 0;
    (match opened with
     | Some g -> column cut (view.r.max.x - 2) (Apps.right entries g) 1
     | None -> ());
    Draw.border view view.r 1 line;
    Display.flush display in
  (* where the mouse is: the column and the row of an item there *)
  let locate (view : Display.image) opened (p : Point.t) =
    let row = Apps.row_at (view.r.min.y + 4) p.y in
    let col = if p.x < view.r.min.x + Apps.left_w then 0 else 1 in
    let items = if col = 0 then left else match opened with Some g -> Apps.right entries g | None -> [] in
    match List.nth_opt items (max row 0) with
    | Some item when row >= 0 && Rectangle.contains view.r p -> Some (col, row, item)
    | _ -> None in
  let rec loop (view : Display.image) opened over was =
    let m : Mouse.state = Event.sync (Mouse.receive mouse) in
    if m.resized then begin
      (* (shown anew, or another size: as it was at first) *)
      let view = Display.screen display in
      draw view None None;
      loop view None None m.buttons
    end
    else begin
      let found = locate view opened m.pos in
      let opened' = match found with
        | Some (_, _, Apps.Group (g, _)) -> Some g
        | Some (0, _, _) -> None
        | _ -> opened in
      let over' = match found with Some (c, r, _) -> Some (c, r) | None -> None in
      if opened' <> opened || over' <> over then draw view opened' over';
      let press = m.buttons land 1 <> 0 && was = 0 in
      match found with
      | Some (_, _, Apps.Run e) when press ->
          ask caps (Apps.open_line e);
          ask caps "hide";
          loop view opened' over' m.buttons
      | Some (_, _, Apps.Exit) when press -> ask caps "exit"; loop view opened' over' m.buttons
      | _ -> loop view opened' over' m.buttons
    end in
  let view = Display.screen display in
  draw view None None;
  loop view None None 0

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
