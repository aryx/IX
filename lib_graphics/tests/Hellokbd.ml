(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* hellokbd: the keys held (lib_graphics's Keyboard.held: /dev/kbd,
 * mini-9pi's and a window of mini-rio's), on the screen: a line for
 * each message, down or up and the keys then down, each by its
 * character or, for a key that has none, its number. q ends (the
 * console's character). kernel/9pi's make check-kbd follows it by its
 * screens: a key pressed and released is two lines, however long it is
 * held (a key that repeats is down already). *)

type event = Message of string | Typed of string list

let name (k : string) : string =
  if k = " " then "space" else if String.length k = 1 && k.[0] > ' ' && k.[0] < '\127' then k else Printf.sprintf "U+%04X" (Utf8.code k)

let main (caps : < Cap.draw; Cap.keyboard; Cap.fork; .. >) : Exit.t =
  let display = Display.init caps in
  let view = Display.screen display and font = Font.default display in
  let keyboard = Keyboard.init caps in
  let black = Display.color display Display.black and white = Display.color display Display.white in
  let show (lines : string list) : unit =
    Draw.fill view view.r white;
    List.iteri (fun (i : int) (l : string) -> ignore (Font.string view (Point.add view.r.min (Point.v 20 (20 + (18 * i)))) black font l))
      ("Hello Kbd: keys, then q." :: List.rev lines);
    Display.flush display in
  match Keyboard.held caps with
  | None -> Exit.Err "hellokbd: no /dev/kbd here"
  | Some held ->
      let rec loop (lines : string list) : unit =
        show lines;
        match Event.select [ Event.wrap (Keyboard.message held) (fun (m : string) -> Message m);
                             Event.wrap (Keyboard.receive keyboard) (fun (k : string list) -> Typed k) ] with
        | Typed k when List.mem "q" k -> ()
        | Typed _ -> loop lines
        | Message m ->
            let what = if String.length m > 0 && m.[0] = 'k' then "down:" else "up:  " in
            loop ((what ^ String.concat "" (List.map (fun (k : string) -> " " ^ name k) (Keyboard.keys m))) :: lines) in
      loop [];
      Exit.OK

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps)))
