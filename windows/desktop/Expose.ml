(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* expose: all the windows at once, shrunk side by side, live; a click on
 * one brings it to the front, and on none, back as before
 * (plan_desktop.md). Started by the panel's button, in a window of rio's
 * popup layer as large as what the screen has for windows:
 *
 *     window -popup -max -label expose expose
 *
 * How it can be a program and not rio's: mini-9pi's draw device keeps each
 * window's pixels whole, covered or not, hidden or not (Memlayer: "its
 * content is always whole"), and each window's image has a name rio gives
 * in its winname file. So a program can open another's image by that name
 * and copy from it, as a compositor would: one draw message more, 'Z',
 * k times smaller (Draw.shrink). Plan 9's memlayer kept only a window's
 * hidden parts apart, and could not have shown a covered window.
 *
 * Live: the thumbnails made again twice a second, in an image of its own
 * first and then all at once (no flicker), the windows' list read again
 * each time (one made or gone meanwhile has its place or loses it).
 *
 * history:
 * Exposé is Apple's (Mac OS X 10.3, 2003), the first that a compositor
 * made cheap: each window was already drawn off the screen, into a buffer
 * of its own, so showing them small was copying. Windows Vista's Flip 3D
 * (2007), GNOME's Activities (2011) are the same idea. *)

type caps = < Cap.draw; Cap.mouse; Cap.fork; Cap.readdir; Cap.open_in; Cap.open_out >

type event = Mouse of Mouse.state | Tick

let main (caps : < caps; .. >) : Exit.t =
  let display = Display.init caps in
  let font = Font.default display and mouse = Mouse.init caps in
  let ticks = Source.timer caps 0.5 in
  let color c = Display.color display (Display.rgb ((c lsr 16) land 255) ((c lsr 8) land 255) (c land 255)) in
  let back = color 0x1b2838 and frame = color 0x7fa6c9 and over = color 0xffd060 in
  let white = color 0xffffff and grey = color 0x8899aa and empty = color 0x445566 in
  (* the windows' images by their names: kept while the name is, freed when
   * the window has another (made another size) or is gone *)
  let images : (string, Display.image option) Hashtbl.t = Hashtbl.create 16 in
  let image_of name =
    match Hashtbl.find_opt images name with
    | Some i -> i
    | None ->
        let i = try Some (Display.named display (String.trim name)) with _ -> None in
        Hashtbl.replace images name i; i in
  let forget_others (names : string list) =
    let gone = Hashtbl.fold (fun n _ acc -> if List.mem n names then acc else n :: acc) images [] in
    List.iter (fun n -> Option.iter Display.free (Hashtbl.find images n); Hashtbl.remove images n) gone in
  (* the windows now, each with its image if it can be had *)
  let look () =
    let ws = Taskbar.tasks (Wsys.windows caps) in
    let named = List.map (fun (w : Taskbar.window) ->
        let name = Wsys.winname caps w.id in
        (w, Option.bind name image_of, name)) ws in
    forget_others (List.filter_map (fun (_, _, n) -> n) named);
    List.map (fun (w, i, _) -> (w, i)) named in
  let shrinks = ref None in
  (* a frame: drawn in [buffer], then on the window *)
  let draw (view : Display.image) (buffer : Display.image) (tiles : ((Taskbar.window * Display.image option) * (Rectangle.t * Rectangle.t * int)) list) hover =
    Draw.fill buffer buffer.r back;
    List.iteri (fun n (((w : Taskbar.window), image), ((cell : Rectangle.t), (thumb : Rectangle.t), k)) ->
        (match image with
         | Some (i : Display.image) ->
             let can = match !shrinks with
               | Some c -> c
               | None -> let c = Draw.can_shrink buffer i in shrinks := Some c; c in
             if can then Draw.shrink buffer thumb i i.r.min k else Draw.fill buffer thumb empty
         | None -> Draw.fill buffer thumb empty);
        let on = hover = Some n in
        Draw.border buffer (Rectangle.inset thumb (if on then -3 else -1)) (if on then 3 else 1) (if on then over else frame);
        let label = if w.hidden then w.label ^ " (hidden)" else w.label in
        let label = Taskbar.shorten (Font.width font) (Rectangle.dx cell - 8) label in
        let x = cell.min.x + ((Rectangle.dx cell - Font.width font label) / 2) in
        ignore (Font.string buffer (Point.v x (thumb.max.y + 6)) (if w.hidden then grey else white) font label))
      tiles;
    Draw.draw view view.r buffer None view.r.min;
    Display.flush display in
  let place (view : Display.image) ws =
    let sizes = List.map (fun ((_ : Taskbar.window), image) ->
        match image with
        | Some (i : Display.image) -> (Rectangle.dx i.r, Rectangle.dy i.r)
        | None -> (400, 300)) ws in
    List.combine ws (Tiles.layout (Rectangle.inset view.r 8) sizes) in
  let hit tiles (p : Point.t) =
    let rec go n = function
      | [] -> None
      | (_, ((cell : Rectangle.t), _, _)) :: more -> if Rectangle.contains cell p then Some n else go (n + 1) more in
    go 0 tiles in
  let new_buffer (view : Display.image) = Display.alloc display view.r (Display.format display) ~repl:false Display.black in
  let rec loop (view : Display.image) buffer tiles hover was =
    match Event.select [ Event.wrap (Mouse.receive mouse) (fun m -> Mouse m); Event.wrap (Event.receive ticks) (fun () -> Tick) ] with
    | Tick ->
        let tiles = place view (look ()) in
        draw view buffer tiles hover;
        loop view buffer tiles hover was
    | Mouse m when m.resized ->
        let view = Display.screen display in
        Display.free buffer;
        let buffer = new_buffer view in
        let tiles = place view (look ()) in
        draw view buffer tiles None;
        loop view buffer tiles None m.buttons
    | Mouse m when m.buttons land 1 <> 0 && was = 0 ->
        (match hit tiles m.pos with
         | Some n ->
             let ((w : Taskbar.window), _), _ = List.nth tiles n in
             if w.hidden then Wsys.ask caps (Printf.sprintf "unhide -id %d" w.id);
             Wsys.ask caps (Printf.sprintf "current -id %d" w.id)
         | None -> ());
        Exit.OK
    | Mouse m ->
        let h = hit tiles m.pos in
        if h <> hover then draw view buffer tiles h;
        loop view buffer tiles h m.buttons in
  let view = Display.screen display in
  let buffer = new_buffer view in
  let tiles = place view (look ()) in
  draw view buffer tiles None;
  loop view buffer tiles None 0

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps)))
