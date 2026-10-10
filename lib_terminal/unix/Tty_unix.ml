(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's playground's libs/terminal/unix/Tty_unix.ml (docs/plans/plan_pascal.md) *)

(* See Tty_unix.mli *)

let write (s : string) : unit =
  let rec go i = if i < String.length s then go (i + Unix.write_substring Unix.stdout s i (String.length s - i)) in
  go 0

(* the bytes waiting on stdin, none if none *)
let available () : string =
  let buf = Bytes.create 256 in
  match Unix.read Unix.stdin buf 0 256 with n -> Bytes.sub_string buf 0 n | exception Unix.Unix_error (Unix.EAGAIN, _, _) -> ""

(* ix: the terminal's rows and columns, asked of it: the cursor sent
   far beyond the last cell stops there, and the terminal reports where
   it is (ESC [ 6 n, answered ESC [ rows ; cols R). None from one that
   does not answer in half a second. Keys typed before the answer are
   lost. *)
let size () : (int * int) option =
  write "\x1b[999;999H\x1b[6n";
  let rec answer (got : string) (tries : int) : (int * int) option =
    match String.index_opt got 'R', String.rindex_opt got '[' with
    | Some r, Some b when b < r -> (
        match String.split_on_char ';' (String.sub got (b + 1) (r - b - 1)) |> List.map int_of_string_opt with
        | [ Some rows; Some cols ] -> Some (rows, cols)
        | _ -> None)
    | _ when tries = 0 -> None
    | _ ->
        (match Unix.select [ Unix.stdin ] [] [] 0.1 with _ -> () | exception Unix.Unix_error (Unix.EINTR, _, _) -> ());
        answer (got ^ available ()) (tries - 1) in
  answer "" 5

(* ix: [sized]: the program told the terminal's size before its first screen *)
let run_ (sized : bool) (p : 'model Tui.program) : unit =
  let saved = Unix.tcgetattr Unix.stdin in
  (* raw: keys at once, unechoed, Control-C a key; a read returning
     what is there, maybe nothing *)
  Unix.tcsetattr Unix.stdin Unix.TCSANOW
    { saved with c_icanon = false; c_echo = false; c_isig = false; c_ixon = false; c_icrnl = false; c_vmin = 0; c_vtime = 0 };
  write "\x1b[?1049h";
  Fun.protect
    ~finally:(fun () ->
      write "\x1b[0m\x1b[?25h\x1b[?1049l";
      Unix.tcsetattr Unix.stdin Unix.TCSANOW saved)
    (fun () ->
      let init = match (if sized then size () else None) with Some (rows, cols) -> p.update (Resize (rows, cols)) p.init | None -> p.init in
      let screen = p.view init in
      write (Curses.redraw screen);
      let rec loop (model : 'model) (shown : Curses.t) (last : float) =
        if not (p.over model) then begin
          (match Unix.select [ Unix.stdin ] [] [] 0.05 with _ -> () | exception Unix.Unix_error (Unix.EINTR, _, _) -> ());
          let keys = Line_discipline.split_keys (available ()) in
          (* Control-C: the program's end, in raw mode as without *)
          if List.mem "\x03" keys then ()
          else begin
            let model = List.fold_left (fun m k -> p.update (Key k) m) model keys in
            let now = Unix.gettimeofday () in
            (* a pause (the process stopped, Control-Z) isn't time played *)
            let model = p.update (Tick (Float.min 0.25 (now -. last))) model in
            let next = p.view model in
            write (Curses.refresh ~before:shown next);
            loop model next now
          end
        end
      in
      loop init screen (Unix.gettimeofday ()))

let run (_caps : < Cap.stdin ; Cap.stdout ; .. >) (p : 'model Tui.program) : unit = run_ false p
let run_sized (_caps : < Cap.stdin ; Cap.stdout ; .. >) (p : 'model Tui.program) : unit = run_ true p
