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
 * middle one's menu has snarf, paste, send, and scroll or noscroll
 * (noscroll: a window that is full holds what its program writes until
 * one scrolls: a pager). The text is not edited:
 * what is typed goes at its end (rio's is edited anywhere; the author:
 * "I rarely used that feature of rio").
 *
 * Its modules, as xix's: Wm (the windows, which is in front, what the
 * menu does to one), Mouse_action (a rectangle swept, a window pointed
 * at or dragged), Window (a window's thread) and Terminal (its text),
 * Processes_winshell (its process), Fileserver (its files, each a
 * Device: Virtual_cons, Virtual_mouse, Dev_wm, and Wctl, by which a
 * program does what the menu does), Cursors.
 *
 * Its threads, as rio's (Rob Pike's design: each is a small loop of
 * its own, and they talk by channels):
 * - this one, the window system: the mouse and the keyboard, the menu,
 *   which window is in front; it sends the keys and the mouse to that
 *   window;
 * - the file server (Fileserver.serve): the windows' processes' requests,
 *   each sent to its window;
 * - a thread a window (Window.run).
 * None waits in a read: the mouse, the keyboard and the requests are
 * Sources (a process reads each), so a menu held open stops nothing
 * else. *)

type caps = < Cap.draw; Cap.mouse; Cap.keyboard; Cap.fork; Cap.exec; Cap.mount; Cap.bind; Cap.open_in; Cap.open_out >

type event = Mouse of Mouse.state | Keys of string list | Held of string | Asked of Window.t * Wctl.command

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
  (* the windows' files, posted as rio's (/srv/rio.user.pid there): a
   * window's process mounts them, and whoever is given $wsys *)
  let srv = Printf.sprintf "/srv/rio.%d" (Unix.getpid ()) in
  let mine = P9_server.post caps (Filename.basename srv) in
  ignore (Thread.create (fun () -> Fileserver.serve (Source.reader caps mine 4000) mine) ());
  (* (the keys held, where the kernel says them: for the programs that ask, a window's kbd file) *)
  let kbd = match Keyboard.held caps with Some h -> [ Event.wrap (Keyboard.message h) (fun m -> Held m) ] | None -> [] in
  let next () = Event.select ([ Event.wrap (Mouse.receive mouse) (fun m -> Mouse m); Event.wrap (Keyboard.receive keyboard) (fun k -> Keys k);
                                Event.wrap (Event.receive Wctl.requests) (fun (w, c) -> Asked (w, c)) ] @ kbd) in
  let make = Wm.create caps desk font srv in
  let action = Mouse_action.make caps mouse display desk in
  Window.note := Processes_winshell.note caps;
  (* the buttons at the event before; the window that has the mouse until they are up *)
  let held = ref 0 and selecting : Window.t option ref = ref None in
  let rec loop last =
    Display.flush display;
    match next () with
    | Keys [] -> loop last
    | Keys keys -> Option.iter (fun w -> Window.send w (Window.Keys keys)) (Wm.current ()); loop last
    | Held m -> Option.iter (fun w -> Window.send w (Window.Held m)) (Wm.current ()); loop last
    (* a window's wctl file written: what the menu does, asked by a program *)
    | Asked (w, c) -> Wm.control caps make view.r w c; loop last
    (* the mouse in the front window, when its program reads it, is the program's *)
    | Mouse m when (Window.pointer := m;
                    Mouse_action.hover action m;
                    match !Wm.windows with w :: _ -> w.wants_mouse && not w.hidden && Rectangle.contains w.image.r m.pos && not (Window.on_border w m.pos) | [] -> false) ->
        Window.send (List.hd !Wm.windows) (Window.Moved m); loop last
    (* a button went down in a window's scroll bar, or the left one in its
     * text: the mouse is that window's until the buttons are up (its
     * text scrolls, or is selected) *)
    | Mouse m when !selecting <> None ->
        Option.iter (fun w -> Window.send w (Window.Moved m)) !selecting;
        if m.buttons = 0 then selecting := None;
        held := m.buttons;
        loop last
    (* a button pressed on a window's border: its size, or its place (the
     * mouse is read there until the button is up) *)
    | Mouse m when m.buttons <> 0 && !held = 0 && (match Wm.border m.pos with Some (w, k) -> Mouse_action.grab action w k m; true | None -> false) -> loop last
    (* a button pressed in a window's scroll bar is the window's: it scrolls
     * (once a press: [held] is the buttons at the event before) *)
    | Mouse m when (let fresh = m.buttons <> 0 && !held = 0 in
                    held := m.buttons;
                    fresh && (match Wm.at m.pos with Some w -> Window.in_bar w m.pos | None -> false)) ->
        (match Wm.at m.pos with
         | Some w -> (match !Wm.windows with f :: _ when f == w -> () | _ -> Wm.front w); Window.send w (Window.Moved m); selecting := Some w
         | None -> ());
        loop last
    | Mouse m when m.buttons land 4 <> 0 -> (
        (* (the menu and what follows read the mouse themselves: no button is down after) *)
        held := 0;
        (* rio's menu, and under it the hidden windows, by their labels *)
        let hidden = Wm.hidden () in
        let items = [ "New"; "Resize"; "Move"; "Delete"; "Hide" ] @ List.map (fun (w : Window.t) -> w.label) hidden @ [ "Exit" ] in
        match Menu.hit view font mouse 4 items last m.pos with
        | Some 0 ->
            (* (too small a rectangle, a click: a window of 400 by 240 there) *)
            let r : Rectangle.t = Mouse_action.sweep action in
            ignore (make (if Wm.fits r then r else Rectangle.v r.min.x r.min.y (r.min.x + 400) (r.min.y + 240)) "");
            loop 0
        | Some 1 ->
            (* a window pointed at, then its new rectangle swept out *)
            (match Mouse_action.point action with
             | Some w -> let r = Mouse_action.sweep action in if Wm.fits r then Wm.reshape w r
             | None -> ());
            loop 1
        | Some 2 -> (match Mouse_action.drag action with Some (w, r) -> Wm.reshape w r | None -> ()); loop 2
        | Some 3 -> Option.iter (Wm.delete caps) (Mouse_action.point action); loop 3
        | Some 4 -> Option.iter Wm.hide (Mouse_action.point action); loop 4
        | Some k when k < 5 + List.length hidden -> Wm.show (List.nth hidden (k - 5)); loop last
        | Some _ -> ()
        | None -> loop last)
    (* the middle button in a window: its text's menu (Terminal's); what
     * it gives is typed there *)
    | Mouse m when m.buttons land 2 <> 0 ->
        held := 0;
        (match Wm.at m.pos with
         | Some w ->
             Wm.front w;
             (match Terminal.menu w.text view mouse m.pos with
              | Terminal.Typed text -> if text <> "" then Window.send w (Window.Keys (fst (Utf8.chars text)))
              | Terminal.Scroll on -> Window.send w (Window.Scroll on)
              | Terminal.Nothing -> ())
         | None -> ());
        loop last
    (* the left button on a window: it comes in front, and has the mouse
     * until the button is up *)
    | Mouse m when m.buttons land 1 <> 0 ->
        (match Wm.at m.pos with Some w -> Wm.front w; Window.send w (Window.Moved m); selecting := Some w | None -> ());
        loop last
    | Mouse _ -> loop last in
  loop 0;
  List.iter (Wm.delete caps) !Wm.windows;
  (try FS.remove_any caps srv with Unix.Unix_error _ | Sys_error _ -> ());
  Display.close display;
  Exit.OK

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps)))
