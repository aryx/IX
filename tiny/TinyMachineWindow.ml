(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* tiny-machine's window (tiny-machine -window runs it; TinyMachine.ml
 * says why it is a program apart: this one links SDL, by mini-qemu's
 * Sdl_display, and that one nothing of C's). It knows nothing of the
 * machine: it shows the pictures it reads on its standard input, each
 * a PPM (P6: a header's three lines, then red, green and blue bytes),
 * and writes what is done in the window on its standard output, an
 * event a line:
 *
 *     m x y buttons    the mouse's place, and its buttons (1 left, 2
 *                      middle, 4 right, as Plan 9's)
 *     k \ddd           a key typed, its byte
 *
 * Its input's end, or its window closed, is its end. *)

(* a key's byte, by its USB usage (a US keyboard's), with shift and
 * control; the arrows 128 to 131 (up, down, left, right), tiny-machine's
 * choice *)
let key_byte usage ~shift ~ctrl =
  let plain = "abcdefghijklmnopqrstuvwxyz1234567890\n\027\b\t -=[]\\\000;'`,./"
  and shifted = "ABCDEFGHIJKLMNOPQRSTUVWXYZ!@#$%^&*()\n\027\b\t _+{}|\000:\"~<>?" in
  if usage >= 4 && usage <= 56 then
    if ctrl && usage <= 29 then Some (usage - 3)
    else (match Char.code (if shift then shifted else plain).[usage - 4] with 0 -> None | c -> Some c)
  else match usage with 82 -> Some 128 | 81 -> Some 129 | 80 -> Some 130 | 79 -> Some 131 | 76 -> Some 127 | _ -> None

(* a picture: its width, its height, its bytes; None at the input's end *)
let read_ppm ic =
  match input_line ic with
  | exception End_of_file -> None
  | _p6 ->
      let width, height = Scanf.sscanf (input_line ic) "%d %d" (fun w h -> w, h) in
      ignore (input_line ic);
      Some (width, height, really_input_string ic (3 * width * height))

let () =
  let display = Sdl_display.create ~absolute:true ~title:"tiny-machine" () in
  let x = ref 0 and y = ref 0 and buttons = ref 0 and shift = ref false and ctrl = ref false in
  (* the key held (its usage, its byte), and when it is typed again: a
   * keyboard's repeat, done here (the display says a key's press once,
   * what a kernel's USB driver wants; a game wants its arrows held) *)
  let held = ref None and again = ref 0. in
  set_binary_mode_in stdin true;
  try
    while true do
      (* a picture when one is there; the window's events meanwhile *)
      (match Unix.select [ Unix.stdin ] [] [] 0.01 with
       | [], _, _ -> ()
       | _ -> (
           match read_ppm stdin with
           | None -> exit 0
           | Some (width, height, pixels) ->
               display.present { Framebuffer.width; height; depth = 24; pitch = 3 * width; base = 0 } pixels)
       | exception Unix.Unix_error (Unix.EINTR, _, _) -> ());
      let mouse = !x, !y, !buttons in
      List.iter (function
        | Display.Quit -> exit 0
        | Display.At (ax, ay) -> x := ax; y := ay
        | Display.Button (b, down) ->
            (* the display's 2 is the right button, 4 the middle one *)
            let b = match b with 2 -> 4 | 4 -> 2 | b -> b in
            buttons := if down then !buttons lor b else !buttons land lnot b
        | Display.Key ((225 | 229), down) -> shift := down
        | Display.Key ((224 | 228), down) -> ctrl := down
        | Display.Key (usage, true) ->
            Option.iter (fun byte ->
              Printf.printf "k \\%03d\n" byte;
              held := Some (usage, byte);
              again := Unix.gettimeofday () +. 0.3) (key_byte usage ~shift:!shift ~ctrl:!ctrl)
        | Display.Key (usage, false) -> (match !held with Some (u, _) when u = usage -> held := None | _ -> ())
        | _ -> ()) (display.poll ());
      (match !held with
       | Some (_, byte) when Unix.gettimeofday () >= !again -> Printf.printf "k \\%03d\n" byte; again := Unix.gettimeofday () +. 0.05
       | _ -> ());
      if (!x, !y, !buttons) <> mouse then Printf.printf "m %d %d %d\n" !x !y !buttons;
      flush stdout
    done
  with End_of_file -> ()
