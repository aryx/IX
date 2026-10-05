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
 * The right button's menu: New (then a rectangle swept out with that
 * button, the cursor a cross, the rectangle shown as it grows: a
 * window, rc in it), Delete (then a window pointed at, the cursor a
 * sight), Exit. The left button on a window gives it the keyboard.
 *
 * One loop, which chooses between the mouse, the keyboard and the
 * windows' file requests (Event.select; each is a Source, a process
 * that reads): so nothing here waits in a read, and a console's read
 * is answered later, when its line is typed (P9_server.Later). *)

type caps = < Cap.draw; Cap.mouse; Cap.keyboard; Cap.fork; Cap.exec; Cap.mount; Cap.open_out >

type event = Mouse of Mouse.state | Keys of string | Request of bytes

(* the windows, the one in front first; the first has the keyboard *)
let windows : Window.t list ref = ref []

let front (w : Window.t) =
  (match !windows with old :: _ when old != w -> Window.border old ~current:false | _ -> ());
  windows := w :: List.filter (fun x -> x != w) !windows;
  Display.top w.image;
  Window.border w ~current:true

let at (p : Point.t) = List.find_opt (fun (w : Window.t) -> Rectangle.contains w.image.r p) !windows

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

(* a window's processes told to end (their note group's file), its image freed *)
let delete (caps : < Cap.open_out; .. >) (w : Window.t) =
  (try Fpath.v (Printf.sprintf "/proc/%d/notepg" w.pid) |> FS.with_open_out caps (fun (chan : Chan.o) -> output_string chan.oc "hangup") with Sys_error _ -> ());
  windows := List.filter (fun x -> x != w) !windows;
  Display.free w.image;
  (match !windows with next :: _ -> front next | [] -> ())

let main (caps : < caps; .. >) : Exit.t =
  let display = Display.init caps in
  let view = Display.whole display and font = Font.default display in
  let mouse = Mouse.init caps and keyboard = Keyboard.init caps in
  (* the desktop: grey where no window is *)
  let grey = Display.color display (Display.rgb 0x77 0x77 0x77) in
  let desk = Display.desktop view grey in
  Draw.fill view view.r grey;
  Display.flush display;
  (* the file server: a pipe, one end served here (its requests a
   * Source's messages, cut into 9P's by their sizes), the other
   * mounted by each window's process *)
  let mine, served = Unix.pipe ~cloexec:false () in
  let requests = Source.reader caps mine 4000 in
  let server = P9_server.make (Fileserver.fs (fun id -> List.find_opt (fun (w : Window.t) -> w.id = id) !windows))
      (fun bytes -> ignore (Unix.write_substring mine bytes 0 (String.length bytes))) in
  let pending = Buffer.create 8192 in
  let request bytes =
    Buffer.add_bytes pending bytes;
    let all = Buffer.contents pending in
    let size o = Char.code all.[o] lor (Char.code all.[o + 1] lsl 8) lor (Char.code all.[o + 2] lsl 16) in
    let rec each o = if o + 4 <= String.length all && o + size o <= String.length all then begin P9_server.request server (String.sub all o (size o)); each (o + size o) end else o in
    let rest = each 0 in
    Buffer.clear pending;
    Buffer.add_substring pending all rest (String.length all - rest) in
  let next () = Event.select [ Event.wrap (Mouse.receive mouse) (fun m -> Mouse m); Event.wrap (Keyboard.receive keyboard) (fun k -> Keys k);
                               Event.wrap (Event.receive requests) (fun r -> Request r) ] in
  (* the mouse followed until the right button is as wanted: where *)
  let rec button down = let m : Mouse.state = Event.sync (Mouse.receive mouse) in if (m.buttons land 4 <> 0) = down then m.pos else button down in
  (* a rectangle swept out with the right button, the cursor a cross:
   * from where the button goes down to where it comes up, shown as it
   * grows (rio's: a pale window with a red border, made anew at each move) *)
  let sweep () : Rectangle.t =
    Cursor.set caps (Some Cursors.cross);
    let p0 = button true in
    let rect (p : Point.t) = Rectangle.v (min p0.x p.x) (min p0.y p.y) (max p0.x p.x) (max p0.y p.y) in
    let red = Display.color display (Display.rgb 0xdd 0x00 0x00) in
    let rec drag shown =
      let m : Mouse.state = Event.sync (Mouse.receive mouse) in
      Option.iter Display.free shown;
      let r = rect m.pos in
      if m.buttons land 4 = 0 then r
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
    Cursor.set caps None;
    r in
  let ids = ref 0 in
  let rec loop last =
    Display.flush display;
    match next () with
    | Request bytes -> request bytes; loop last
    | Keys keys -> (match !windows with w :: _ -> Window.typed w keys | [] -> ()); loop last
    (* the mouse in the front window, when its program reads it, is the program's *)
    | Mouse m when (Fileserver.pointer := m;
                    match !windows with w :: _ -> w.mouse_open && Rectangle.contains w.image.r m.pos | [] -> false) ->
        Window.mouse (List.hd !windows) m; loop last
    | Mouse m when m.buttons land 4 <> 0 -> (
        match Menu.hit view font mouse 4 [ "New"; "Delete"; "Exit" ] last m.pos with
        | Some 0 ->
            let r : Rectangle.t = sweep () in
            let r = if Rectangle.dx r < 100 || Rectangle.dy r < 50 then Rectangle.v r.min.x r.min.y (r.min.x + 400) (r.min.y + 240) else r in
            incr ids;
            let w = Window.make desk !ids r font in
            front w;
            start caps w served;
            loop 0
        | Some 1 ->
            Cursor.set caps (Some Cursors.sight);
            let p = button true in
            ignore (button false);
            Cursor.set caps None;
            (match at p with Some w -> delete caps w | None -> ());
            loop 1
        | Some _ -> ()
        | None -> loop last)
    | Mouse m when m.buttons land 1 <> 0 -> (match at m.pos with Some w -> front w | None -> ()); loop last
    | Mouse _ -> loop last in
  loop 0;
  List.iter (delete caps) !windows;
  Display.close display;
  Exit.OK

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps)))
