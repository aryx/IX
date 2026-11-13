(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* desk: the wallpaper and its icons (plan_desktop.md), under all the windows,
 * in a window of rio's desk layer:
 *
 *     window -desk desk
 *
 * Its icons are the lines of a person's $home/lib/desktop/desk, or, when
 * there is none, of /lib/desktop/desk. The lines have the same form as the
 * start menu's table (Apps), with the group always top. A click selects
 * an icon, and a double click opens it. The right button is rio's: a desk
 * does not get it, so rio's menu stays where it always was.
 *
 * It draws when something changes and waits for the mouse otherwise. It
 * looks at the settings (Prefs) every two seconds for their wallpaper, a
 * colour or a picture. The wallpaper is made once, in an image of its own,
 * and what an icon uncovers is copied back from there.
 *
 * cs-history:
 * The desktop as a surface with icons on it is the Xerox Star's (1981), and
 * so is its double click: one click says which icon, and a second one says
 * what to do with it. The Star's documents were on it because a person's
 * documents were on a desk; here, as on most desktops since, what is mostly
 * there is programs. *)

type caps = < Cap.draw; Cap.mouse; Cap.fork; Cap.env; Cap.open_in; Cap.open_out >

let read_file (caps : < Cap.open_in; .. >) path =
  try Some (FS.read caps (Fpath.v path)) with Sys_error _ | Unix.Unix_error _ -> None

let ask (caps : < Cap.open_out; .. >) line =
  try
    let fd = FS.open_device_fd caps "/dev/wctl" in
    Fun.protect ~finally:(fun () -> Unix.close fd) (fun () -> ignore (Unix.write_substring fd line 0 (String.length line)))
  with Unix.Unix_error _ | Sys_error _ -> ()

let bands = 128
(* the panel's depth, desktop's start's (window -panel -edge bottom 28) *)
let panel_h = 28

type event = Mouse of Mouse.state | Look

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
  let prefs () = match read_file caps (Prefs.path home) with Some t -> Prefs.parse t | None -> Prefs.default in
  (* the wallpaper of a window, made once: the settings' colour made bands
   * (Paper), or their picture covering it; a picture that cannot be read,
   * the colour's place taken by the default one *)
  let wallpaper (r : Rectangle.t) (p : Prefs.t) =
    let image = Display.alloc display r "x8r8g8b8" ~repl:false Display.black in
    let gradient c =
      List.iteri (fun k c ->
          let ink = Display.color display (Display.rgb ((c lsr 16) land 255) ((c lsr 8) land 255) (c land 255)) in
          let y0 = r.min.y + (Rectangle.dy r * k / bands) and y1 = r.min.y + (Rectangle.dy r * (k + 1) / bands) in
          Draw.fill image (Rectangle.v r.min.x y0 r.max.x y1) ink;
          Display.free ink) (Paper.bands bands c) in
    (match p.wallpaper with
     | Prefs.Colour c -> gradient c
     | Prefs.Picture file -> (
         let decoded = match read_file caps file with
           | Some bytes -> (try Some (Image_file.decode bytes) with _ -> None)
           | None -> None in
         match decoded with
         | Some (pic : Rgba_image.t) ->
             Display.load image r (Paper.cover pic.width pic.height pic.rgba (Rectangle.dx r) (Rectangle.dy r))
         | None -> (match Prefs.default.wallpaper with Prefs.Colour c -> gradient c | Prefs.Picture _ -> ())));
    image in
  (* the icons out of the panel's way: its side, the settings' (the panel
   * itself says no more than that to anyone) *)
  let edge = ref (prefs ()).edge in
  let cell_of (view : Display.image) i : Rectangle.t =
    let r = view.r in
    let y0 = if !edge = "top" then r.min.y + panel_h else r.min.y
    and y1 = if !edge = "top" then r.max.y else r.max.y - panel_h in
    let (x0, y0, x1, y1) = Apps.desk_cell (r.min.x, y0, r.max.x, y1) i in
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
  (* the settings looked at every two seconds: the wallpaper made again when
   * they say another *)
  let looks = Source.timer caps 2.0 in
  let rec loop (view : Display.image) paper (wall : Prefs.wallpaper) selected last was =
    match Event.select [ Event.wrap (Mouse.receive mouse) (fun m -> Mouse m); Event.wrap (Event.receive looks) (fun () -> Look) ] with
    | Look ->
        let p = prefs () in
        if p.wallpaper = wall && p.edge = !edge then loop view paper wall selected last was
        else begin
          let paper = if p.wallpaper = wall then paper else begin Display.free paper; wallpaper view.r p end in
          edge := p.edge;
          paint view paper selected;
          loop view paper p.wallpaper selected last was
        end
    | Mouse m ->
    if m.resized then begin
      let view = Display.screen display in
      Display.free paper;
      let p = prefs () in
      let paper = wallpaper view.r p in
      paint view paper selected;
      loop view paper p.wallpaper selected last m.buttons
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
           loop view paper wall hit None m.buttons
       | Some i, _ -> loop view paper wall hit (Some (i, m.msec)) m.buttons
       | None, _ -> loop view paper wall None None m.buttons)
    end
    else loop view paper wall selected last m.buttons in
  let view = Display.screen display in
  let p = prefs () in
  let paper = wallpaper view.r p in
  paint view paper None;
  loop view paper p.wallpaper None None 0

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps)))
