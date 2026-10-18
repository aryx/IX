(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyMachineWindow.mli *)

(* what tiny-machine writes: a screen as a PPM, or a line "C n", the
 * mouse's look (0 the arrow, 1 a hand), which a program of the machine
 * chose by writing the mouse's word, or a line "A n" and n bytes, the
 * speaker's samples *)
type input = Screen of int * int * string | Cursor of int | Samples of string

let read_ppm ic =
  match input_line ic with
  | exception End_of_file -> None
  | line when String.length line > 2 && line.[0] = 'C' -> Some (Cursor (int_of_string (String.sub line 2 (String.length line - 2))))
  | line when String.length line > 2 && line.[0] = 'A' -> Some (Samples (really_input_string ic (int_of_string (String.sub line 2 (String.length line - 2)))))
  | _p6 ->
      let width, height = Scanf.sscanf (input_line ic) "%d %d" (fun w h -> w, h) in
      ignore (input_line ic);
      Some (Screen (width, height, really_input_string ic (3 * width * height)))

let () =
  let display = TinyMachineSDL.create ~title:"tiny-machine" in
  let x = ref 0 and y = ref 0 and buttons = ref 0 and shift = ref false and ctrl = ref false and alt = ref false in
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
           | Some (Cursor n) -> display.cursor n
           | Some (Samples s) -> display.play s
           | Some (Screen (width, height, pixels)) ->
               display.present width height pixels)
       | exception Unix.Unix_error (Unix.EINTR, _, _) -> ());
      let mouse = !x, !y, !buttons in
      List.iter (function
        | TinyMachineSDL.Quit -> exit 0
        | TinyMachineSDL.At (ax, ay) -> x := ax; y := ay
        | TinyMachineSDL.Button (b, down) -> buttons := if down then !buttons lor b else !buttons land lnot b
        | TinyMachineSDL.Key ((225 | 229), down) -> shift := down
        | TinyMachineSDL.Key ((224 | 228), down) -> ctrl := down
        | TinyMachineSDL.Key ((226 | 230), down) -> alt := down
        | TinyMachineSDL.Key (usage, true) ->
            Option.iter (fun byte ->
              (* Alt with a key is Escape then the key: Emacs's Meta, M-x *)
              if !alt then Printf.printf "k \\%03d\n" 27;
              Printf.printf "k \\%03d\n" byte;
              held := Some (usage, byte);
              again := Unix.gettimeofday () +. 0.3) (TinyMachineSDL.key_byte usage ~shift:!shift ~ctrl:!ctrl)
        | TinyMachineSDL.Key (usage, false) -> (match !held with Some (u, _) when u = usage -> held := None | _ -> ())
        (* A step of the wheel (or of two fingers on a trackpad) is an
         * arrow key, up or down, a step each: a key is queued, where a
         * button pressed and let go between two reads of the mouse could
         * be missed. A program scrolls by its arrows (www, emacs). *)
        | TinyMachineSDL.Wheel v when v <> 0 ->
            for _i = 1 to min 8 (abs v) do Printf.printf "k \\%03d\n" (if v < 0 then 128 else 129) done
        | _ -> ()) (display.poll ());
      (match !held with
       | Some (_, byte) when Unix.gettimeofday () >= !again -> Printf.printf "k \\%03d\n" byte; again := Unix.gettimeofday () +. 0.05
       | _ -> ());
      if (!x, !y, !buttons) <> mouse then Printf.printf "m %d %d %d\n" !x !y !buttons;
      flush stdout
    done
  with End_of_file -> ()
