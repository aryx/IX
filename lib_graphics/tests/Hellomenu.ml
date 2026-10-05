(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* hellomenu: lib_graphics's mouse, keyboard and menu (plan_rio.md,
 * stage 7b), on mini-9pi's bare screen: a colour and a line of text;
 * the right button gives a menu of colours and "exit"; a key typed is
 * shown, q ends too. One thread, which chooses between the mouse and
 * the keyboard (Event.select): each is a Source, a process that reads
 * the device. kernel/9pi's make check-menu follows it by its screens. *)

type caps = < Cap.draw; Cap.mouse; Cap.keyboard; Cap.fork >

type event = Mouse of Mouse.state | Keys of string

let main (caps : < caps; .. >) : Exit.t =
  let display = Display.init caps in
  let view = Display.screen display and font = Font.default display in
  let mouse = Mouse.init caps and keyboard = Keyboard.init caps in
  let black = Display.color display Display.black in
  let colors = [ "red", Display.rgb 0xcc 0x44 0x44; "green", Display.rgb 0x44 0xaa 0x44; "blue", Display.rgb 0x44 0x66 0xcc ] in
  let redraw (c : Display.color) note =
    let bg = Display.color display c in
    Draw.fill view view.r bg;
    Display.free bg;
    ignore (Font.string view (Point.v 40 40) black font ("Hello Menu: the right button, or q. " ^ note));
    Display.flush display in
  let rec loop color last =
    match Event.select [ Event.wrap (Mouse.receive mouse) (fun m -> Mouse m); Event.wrap (Keyboard.receive keyboard) (fun k -> Keys k) ] with
    | Keys k when String.contains k 'q' -> ()
    | Keys k -> redraw color ("typed: " ^ String.escaped k); loop color last
    | Mouse m when m.buttons land 4 <> 0 -> (
        match Menu.hit view font mouse 4 (List.map fst colors @ [ "exit" ]) last m.pos with
        | Some k when k < List.length colors ->
            let name, c = List.nth colors k in
            redraw c ("chosen: " ^ name);
            loop c k
        | Some _ -> ()
        | None -> loop color last)
    | Mouse _ -> loop color last in
  let grey = Display.rgb 0xcc 0xcc 0xcc in
  redraw grey "";
  loop grey 0;
  redraw Display.white "bye";
  Exit.OK

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps)))
