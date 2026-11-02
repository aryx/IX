(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* desk: the wallpaper and its icons (plan_desktop.md), under all the windows,
 * in a window of rio's desk layer:
 *
 *     window -desk desk
 *
 * Its icons are the lines of /lib/desktop/desk, or of a person's
 * $home/lib/desktop/desk before it: the same form as the start menu's table
 * (Apps), the group always top. A click selects one, a double click
 * opens it. The right button is rio's: a desk does not get it, so its menu
 * stays where it always was.
 *
 * It draws when something changes and waits for the mouse otherwise: there
 * is no clock in it. The wallpaper is made once, in an image of its own, and
 * what an icon uncovers is copied back from there.
 *
 * cs-history:
 * The desktop as a surface with icons on it is the Xerox Star's (1981), and
 * its double click too: one click says which, a second what to do with it.
 * The Star's documents were on it because a person's documents were on a
 * desk; here, as on most since, what is mostly there is programs. *)

type caps = < Cap.draw; Cap.mouse; Cap.fork; Cap.env; Cap.open_in; Cap.open_out >

let read_file (caps : < Cap.open_in; .. >) path =
  try Some (FS.read caps (Fpath.v path)) with Sys_error _ | Unix.Unix_error _ -> None

let ask (caps : < Cap.open_out; .. >) line =
  try
    let fd = FS.open_device_fd caps "/dev/wctl" in
    Fun.protect ~finally:(fun () -> Unix.close fd) (fun () -> ignore (Unix.write_substring fd line 0 (String.length line)))
  with Unix.Unix_error _ | Sys_error _ -> ()

(* the two ends of the wallpaper, from the top down *)
let top = (0x3a, 0x5f, 0x85)
let bottom = (0x14, 0x26, 0x3a)
let bands = 128

let main (caps : < caps; .. >) : Exit.t =
  let home = try CapSys.getenv caps "home" with Not_found -> "" in
  let text =
    match read_file caps (home ^ "/lib/desktop/desk") with
    | Some t -> Some t
    | None -> read_file caps "/lib/desktop/desk" in
  let table = match text with Some t -> Apps.parse t | None -> [] in
  let entries = Array.of_list (List.filter (fun e -> Sys.file_exists ("/bin/" ^ Apps.program e)) table) in
  let display = Display.init caps in
  let font = Font.default display and mouse = Mouse.init caps in
  let white = Display.color display Display.white and black = Display.color display Display.black in
  let marked = Display.color display (Display.rgb 0x33 0x66 0x99) in
  (* each entry's icon at twice its size, with its alpha *)
  let icons = Array.map (fun (e : Apps.entry) ->
      match Option.bind (read_file caps ("/lib/desktop/icons/" ^ e.icon ^ ".txt")) Icon.parse with
      | Some i ->
          let i : Icon.t = Icon.doubled i in
          let r = Rectangle.v 0 0 i.w i.h in
          let image = Display.alloc display r "r8g8b8a8" ~repl:false Display.black in
          Display.load image r i.pixels;
          Some image
      | None -> None) entries in
  (* the wallpaper of a window: colours made and let go here, it is done once *)
  let wallpaper (r : Rectangle.t) =
    let image = Display.alloc display r "x8r8g8b8" ~repl:false Display.black in
    let mix a b k = a + ((b - a) * k / (bands - 1)) in
    let (r0, g0, b0) = top and (r1, g1, b1) = bottom in
    for k = 0 to bands - 1 do
      let c = Display.color display (Display.rgb (mix r0 r1 k) (mix g0 g1 k) (mix b0 b1 k)) in
      let y0 = r.min.y + (Rectangle.dy r * k / bands) and y1 = r.min.y + (Rectangle.dy r * (k + 1) / bands) in
      Draw.fill image (Rectangle.v r.min.x y0 r.max.x y1) c;
      Display.free c
    done;
    image in
  let cell_of (view : Display.image) i : Rectangle.t =
    let (x0, y0, x1, y1) = Apps.desk_cell (view.r.min.x, view.r.min.y, view.r.max.x, view.r.max.y) i in
    Rectangle.v x0 y0 x1 y1 in
  (* one icon, on what is under it *)
  let draw_icon (view : Display.image) (paper : Display.image) i on =
    let r : Rectangle.t = cell_of view i in
    Draw.draw view r paper None r.min;
    let e : Apps.entry = entries.(i) in
    let word = Taskbar.shorten (Font.width font) (Rectangle.dx r - 4) e.name in
    let w = Font.width font word in
    let tx = r.min.x + ((Rectangle.dx r - w) / 2) and ty = r.min.y + 38 in
    (match icons.(i) with
     | Some (image : Display.image) ->
         let x = r.min.x + ((Rectangle.dx r - Rectangle.dx image.r) / 2) in
         Draw.draw view (Rectangle.add image.r (Point.v x (r.min.y + 3))) image None Point.zero
     | None -> ());
    if on then Draw.fill view (Rectangle.v (tx - 2) ty (tx + w + 2) (ty + Font.height font)) marked
    else ignore (Font.string view (Point.v (tx + 1) (ty + 1)) black font word);
    ignore (Font.string view (Point.v tx ty) white font word) in
  let paint (view : Display.image) (paper : Display.image) selected =
    Draw.draw view view.r paper None view.r.min;
    Array.iteri (fun i _ -> draw_icon view paper i (selected = Some i)) entries;
    Display.flush display in
  let at (view : Display.image) (p : Point.t) =
    let rec look i =
      if i >= Array.length entries then None
      else if Rectangle.contains (cell_of view i) p then Some i
      else look (i + 1) in
    look 0 in
  (* [selected]: which is marked; [last]: the last press, on which and when *)
  let rec loop (view : Display.image) paper selected last was =
    let m : Mouse.state = Event.sync (Mouse.receive mouse) in
    if m.resized then begin
      let view = Display.screen display in
      Display.free paper;
      let paper = wallpaper view.r in
      paint view paper selected;
      loop view paper selected last m.buttons
    end
    else if m.buttons land 1 <> 0 && was = 0 then begin
      let hit = at view m.pos in
      if hit <> selected then begin
        Option.iter (fun i -> draw_icon view paper i false) selected;
        Option.iter (fun i -> draw_icon view paper i true) hit;
        Display.flush display
      end;
      (match hit, last with
       | Some i, Some (j, t) when i = j && Apps.double_click t m.msec ->
           ask caps (Apps.open_line entries.(i));
           loop view paper hit None m.buttons
       | Some i, _ -> loop view paper hit (Some (i, m.msec)) m.buttons
       | None, _ -> loop view paper None None m.buttons)
    end
    else loop view paper selected last m.buttons in
  let view = Display.screen display in
  let paper = wallpaper view.r in
  paint view paper None;
  loop view paper None None 0

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps)))
