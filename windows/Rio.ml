(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* mini-rio: a window system, Plan 9's rio in small (principia's
 * windows/rio, 8,170 lines of C; xix's windows/, the author's in
 * OCaml, are the models; plan_rio.md). It takes the screen, the mouse
 * and the keyboard, and gives each window what looks like a machine of
 * its own: a process started in a window has its own /dev/cons, which
 * is the window. The trick is Plan 9's: rio is a file server, and the
 * window's process has rio's files mounted before /dev.
 *
 * The right button's menu, rio's: New (then a rectangle swept out with
 * that button, the cursor a cross, the rectangle shown as it grows: a
 * window, rc in it), Resize (a window pointed at, the cursor a sight,
 * then its new rectangle swept), Move (a window dragged, its outline
 * shown), Delete (a window pointed at), Hide (the same: it is then a
 * name in the menu, which brings it back), and Exit. The left button
 * on a window gives it the keyboard; Delete typed in one interrupts
 * its processes. A window's border is a handle (the cursor says so
 * when the mouse is on it): the left or the middle button there pulls
 * that corner or side (its size), the right one the window (its place). In a window's scroll bar the buttons scroll its text
 * (the arrows too); in its text the left button selects, and the
 * middle one's menu has snarf, paste and send.
 *
 * Its threads, as rio's (Rob Pike's design: each is a small loop of
 * its own, and they talk by channels):
 * - this one, the window system: the mouse and the keyboard, the menu,
 *   which window is in front; it sends the keys and the mouse to that
 *   window;
 * - the file server (serve, below): the windows' processes' requests,
 *   each sent to its window;
 * - a thread a window (Window.run).
 * None waits in a read: the mouse, the keyboard and the requests are
 * Sources (a process reads each), so a menu held open stops nothing
 * else. *)

type caps = < Cap.draw; Cap.mouse; Cap.keyboard; Cap.fork; Cap.exec; Cap.mount; Cap.open_out >

type event = Mouse of Mouse.state | Keys of string list | Held of string

(* the windows, the one in front first; the first has the keyboard *)
let windows : Window.t list ref = ref []

let front (w : Window.t) =
  (match !windows with old :: _ when old != w -> Window.send old (Window.Front false) | _ -> ());
  windows := w :: List.filter (fun x -> x != w) !windows;
  Display.top w.image;
  Window.send w (Window.Front true)

let at (p : Point.t) = List.find_opt (fun (w : Window.t) -> not w.hidden && Rectangle.contains w.image.r p) !windows

(* the process of a window: its own namespace, where the window's
 * files are before /dev's; its console the three descriptors; rc *)
let start (caps : < caps; .. >) (w : Window.t) served =
  let flags = Sys_plan9.(rfproc lor rffdg lor rfnameg lor rfenvg lor rfnoteg lor rfnowait) in
  match Sys_plan9.rfork caps flags with
  | 0 ->
      (try
         Sys_plan9.mount caps served "/dev" Sys_plan9.mbefore (string_of_int w.id);
         let cons = Unix.openfile "/dev/cons" [ Unix.O_RDWR ] 0 in
         List.iter (Unix.dup2 cons) [ Unix.stdin; Unix.stdout; Unix.stderr ];
         for fd = 3 to 63 do (try Unix.close (Obj.magic fd : Unix.file_descr) with Unix.Unix_error _ -> ()) done;
         List.iter (fun rc -> try CapUnix.execv caps rc [| "rc"; "-i" |] with Unix.Unix_error _ -> ()) [ "/bin/rc"; "/boot/rc" ]
       with Unix.Unix_error (e, fn, _) -> prerr_string ("rio: a window's process: " ^ fn ^ ": " ^ Unix.error_message e ^ "\n"));
      Unix._exit 1
  | pid -> w.pid <- pid

(* a note for a window's processes: their note group's file *)
let note (caps : < Cap.open_out; .. >) (w : Window.t) text =
  try Fpath.v (Printf.sprintf "/proc/%d/notepg" w.pid) |> FS.with_open_out caps (fun (chan : Chan.o) -> output_string chan.oc text) with Sys_error _ -> ()

(* a window's processes told to end, its thread too *)
let delete (caps : < Cap.open_out; .. >) (w : Window.t) =
  note caps w "hangup";
  windows := List.filter (fun x -> x != w) !windows;
  Window.quit w;
  (match !windows with next :: _ -> front next | [] -> ())

(* The file server's thread: a pipe's end served (the other is mounted
 * by each window's process); its requests are a Source's messages, cut
 * into 9P's by their sizes. *)
let serve (requests : bytes Event.channel) mine =
  let server = P9_server.make (Fileserver.fs (fun id -> List.find_opt (fun (w : Window.t) -> w.id = id) !windows))
      (fun bytes -> ignore (Unix.write_substring mine bytes 0 (String.length bytes))) in
  let pending = Buffer.create 8192 in
  let rec loop () =
    Buffer.add_bytes pending (Event.sync (Event.receive requests));
    let all = Buffer.contents pending in
    let size o = Char.code all.[o] lor (Char.code all.[o + 1] lsl 8) lor (Char.code all.[o + 2] lsl 16) in
    let rec each o = if o + 4 <= String.length all && o + size o <= String.length all then begin P9_server.request server (String.sub all o (size o)); each (o + size o) end else o in
    let rest = each 0 in
    Buffer.clear pending;
    Buffer.add_substring pending all rest (String.length all - rest);
    loop () in
  loop ()

let main (caps : < caps; .. >) : Exit.t =
  let display = Display.init caps in
  let view = Display.whole display and font = Font.default display in
  let mouse = Mouse.init caps and keyboard = Keyboard.init caps in
  (* the desktop: a grey blue where no window is (ix's colours: rio's
   * desktop is grey, its borders and menus green; one sees which it is) *)
  let grey = Display.color display (Display.rgb 0x66 0x77 0x88) in
  let desk = Display.desktop view grey in
  Draw.fill view view.r grey;
  Display.flush display;
  let mine, served = Unix.pipe ~cloexec:false () in
  ignore (Thread.create (fun () -> serve (Source.reader caps mine 4000) mine) ());
  (* (the keys held, where the kernel says them: for the programs that ask, a window's kbd file) *)
  let kbd = match Keyboard.held caps with Some h -> [ Event.wrap (Keyboard.message h) (fun m -> Held m) ] | None -> [] in
  let next () = Event.select ([ Event.wrap (Mouse.receive mouse) (fun m -> Mouse m); Event.wrap (Keyboard.receive keyboard) (fun k -> Keys k) ] @ kbd) in
  (* the mouse followed until the right button is as wanted: where *)
  let rec button down = let m : Mouse.state = Event.sync (Mouse.receive mouse) in if (m.buttons land 4 <> 0) = down then m.pos else button down in
  (* the cursor shown: the kernel is told when it is another (the mouse
   * on a border says its cursor at each move) *)
  let cursor : Cursor.t option ref = ref None in
  let show (c : Cursor.t option) =
    let same = match c, !cursor with Some a, Some b -> a == b | None, None -> true | _ -> false in
    if not same then begin cursor := c; Cursor.set caps c end in
  (* a rectangle that follows the mouse while a button is down, shown as
   * it changes (rio's: a pale window with a red border, made anew at
   * each move): what it is when the button comes up *)
  let band but (rect : Point.t -> Rectangle.t) : Rectangle.t =
    let red = Display.color display (Display.rgb 0xdd 0x00 0x00) in
    let rec drag shown =
      let m : Mouse.state = Event.sync (Mouse.receive mouse) in
      Option.iter Display.free shown;
      let r = rect m.pos in
      if m.buttons land but = 0 then r
      else begin
        let shown = if Rectangle.dx r > 8 && Rectangle.dy r > 8 then begin
            let i = Display.window desk r (Display.rgb 0xee 0xee 0xee) in
            Draw.border i r 4 red;
            Some i
          end else None in
        Display.flush display;
        drag shown
      end in
    let r = drag None in
    Display.free red;
    r in
  (* a rectangle swept out with the right button, the cursor a cross:
   * from where the button goes down to where it comes up *)
  let sweep () : Rectangle.t =
    show (Some Cursors.cross);
    let p0 = button true in
    let r = band 4 (fun (p : Point.t) -> Rectangle.v (min p0.x p.x) (min p0.y p.y) (max p0.x p.x) (max p0.y p.y)) in
    show None;
    r in
  (* a window pointed at with the right button, the cursor a sight *)
  let point () =
    show (Some Cursors.sight);
    let p = button true in
    ignore (button false);
    show None;
    at p in
  (* a window dragged with the right button: its outline follows the
   * mouse from where the button goes down; where it is let go *)
  let drag_window () : (Window.t * Rectangle.t) option =
    show (Some Cursors.sight);
    let p0 = button true in
    let result = match at p0 with
      | None -> ignore (button false); None
      | Some w -> Some (w, band 4 (fun p -> Rectangle.add w.image.r (Point.sub p p0))) in
    show None;
    result in
  (* the window whose border a point is on, and which of its corners and
   * sides, three by three from the top left (rio's whichcorner: a
   * corner is the 20 pixels at a side's end) *)
  let border (p : Point.t) : (Window.t * int) option =
    match at p with
    | Some w when Window.on_border w p ->
        let part x lo hi = if x < lo + 20 then 0 else if x > hi - 20 then 2 else 1 in
        let r = w.image.r in
        Some (w, 3 * part p.y r.min.y r.max.y + part p.x r.min.x r.max.x)
    | _ -> None in
  (* the mouse on a border, no button down: the cursor of that corner or side *)
  let hover (m : Mouse.state) =
    if m.buttons = 0 then show (match border m.pos with Some (_, k) -> Some Cursors.corners.(k) | None -> None) in
  (* a button pressed on a window's border (rio's bandsize and drag): the
   * left or the middle one, and that corner or side follows the mouse,
   * the others staying where they are; the right one, and the window
   * follows it, the cursor a box. Too small, it stays as it was *)
  let grab (w : Window.t) which (m : Mouse.state) =
    front w;
    let r0 = w.image.r in
    (* (a side's two ends: the one held is the mouse's, from where it was pressed) *)
    let side k p from lo hi = if k = 0 then (min (lo + p - from) hi, max (lo + p - from) hi) else if k = 2 then (min lo (hi + p - from), max lo (hi + p - from)) else (lo, hi) in
    let r : Rectangle.t =
      if m.buttons land 4 <> 0 then begin show (Some Cursors.box); band 4 (fun p -> Rectangle.add r0 (Point.sub p m.pos)) end
      else band (m.buttons land 3) (fun (p : Point.t) ->
          let x0, x1 = side (which mod 3) p.x m.pos.x r0.min.x r0.max.x and y0, y1 = side (which / 3) p.y m.pos.y r0.min.y r0.max.y in
          Rectangle.v x0 y0 x1 y1) in
    show None;
    if r <> r0 && Rectangle.dx r >= 100 && Rectangle.dy r >= 50 then Window.send w (Window.Reshape r) in
  Window.note := note caps;
  let ids = ref 0 and held = ref 0 in
  let selecting : Window.t option ref = ref None in
  let rec loop last =
    Display.flush display;
    match next () with
    | Keys [] -> loop last
    | Keys keys -> (match !windows with w :: _ when not w.hidden -> Window.send w (Window.Keys keys) | _ -> ()); loop last
    | Held m -> (match !windows with w :: _ when not w.hidden -> Window.send w (Window.Held m) | _ -> ()); loop last
    (* the mouse in the front window, when its program reads it, is the program's *)
    | Mouse m when (Window.pointer := m;
                    hover m;
                    match !windows with w :: _ -> w.wants_mouse && not w.hidden && Rectangle.contains w.image.r m.pos && not (Window.on_border w m.pos) | [] -> false) ->
        Window.send (List.hd !windows) (Window.Moved m); loop last
    (* a button went down in a window's scroll bar, or the left one in its
     * text: the mouse is that window's until the buttons are up (its
     * text scrolls, or is selected) *)
    | Mouse m when !selecting <> None ->
        (match !selecting with Some w -> Window.send w (Window.Moved m) | None -> ());
        if m.buttons = 0 then selecting := None;
        held := m.buttons;
        loop last
    (* a button pressed on a window's border: its size, or its place (the
     * mouse is read there until the button is up) *)
    | Mouse m when m.buttons <> 0 && !held = 0 && (match border m.pos with Some (w, k) -> grab w k m; true | None -> false) -> loop last
    (* a button pressed in a window's scroll bar is the window's: it scrolls
     * (once a press: [held] is the buttons at the event before) *)
    | Mouse m when (let fresh = m.buttons <> 0 && !held = 0 in
                    held := m.buttons;
                    fresh && (match at m.pos with Some w -> Window.in_bar w m.pos | None -> false)) ->
        (match at m.pos with
         | Some w -> (match !windows with f :: _ when f == w -> () | _ -> front w); Window.send w (Window.Moved m); selecting := Some w
         | None -> ());
        loop last
    | Mouse m when m.buttons land 4 <> 0 -> (
        (* (the menu and what follows read the mouse themselves: no button is down after) *)
        held := 0;
        (* rio's menu, and under it the hidden windows, by their names *)
        let hidden = List.filter (fun (w : Window.t) -> w.hidden) !windows in
        let items = [ "New"; "Resize"; "Move"; "Delete"; "Hide" ] @ List.map Window.label hidden @ [ "Exit" ] in
        match Menu.hit view font mouse 4 items last m.pos with
        | Some 0 ->
            let r : Rectangle.t = sweep () in
            let r = if Rectangle.dx r < 100 || Rectangle.dy r < 50 then Rectangle.v r.min.x r.min.y (r.min.x + 400) (r.min.y + 240) else r in
            incr ids;
            (match Window.make desk !ids r font with
             | w -> front w; start caps w served
             | exception Failure m -> prerr_string ("rio: no new window: " ^ m ^ "\n"));
            loop 0
        | Some 1 ->
            (* a window pointed at, then its new rectangle swept out *)
            (match point () with
             | Some w -> let r : Rectangle.t = sweep () in if Rectangle.dx r >= 100 && Rectangle.dy r >= 50 then begin front w; Window.send w (Window.Reshape r) end
             | None -> ());
            loop 1
        | Some 2 -> (match drag_window () with Some (w, r) -> front w; Window.send w (Window.Reshape r) | None -> ()); loop 2
        | Some 3 -> (match point () with Some w -> delete caps w | None -> ()); loop 3
        | Some 4 ->
            (match point () with
             | Some w ->
                 Window.send w (Window.Hide true);
                 (* (the keyboard to the next one that shows) *)
                 windows := List.filter (fun x -> x != w) !windows @ [ w ];
                 (match !windows with next :: _ when not next.hidden -> front next | _ -> ())
             | None -> ());
            loop 4
        | Some k when k < 5 + List.length hidden -> let w = List.nth hidden (k - 5) in Window.send w (Window.Hide false); front w; loop last
        | Some _ -> ()
        | None -> loop last)
    (* the middle button in a window: its text's menu (Terminal's); what
     * it gives is typed there *)
    | Mouse m when m.buttons land 2 <> 0 ->
        held := 0;
        (match at m.pos with
         | Some w ->
             front w;
             let text = Terminal.menu w.text view mouse m.pos in
             if text <> "" then Window.send w (Window.Keys (fst (Utf8.chars text)))
         | None -> ());
        loop last
    (* the left button on a window: it comes in front, and has the mouse
     * until the button is up *)
    | Mouse m when m.buttons land 1 <> 0 ->
        (match at m.pos with Some w -> front w; Window.send w (Window.Moved m); selecting := Some w | None -> ());
        loop last
    | Mouse _ -> loop last in
  loop 0;
  List.iter (delete caps) !windows;
  Display.close display;
  Exit.OK

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps)))
