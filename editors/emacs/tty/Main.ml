(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* mini-emacs in the terminal one types this in: Top_window's program
 * run by Tty_unix. With -keys, no terminal: a session is a line of
 * keys and what it leaves a screen as text, for the tests (as
 * mini-turbopascal-tty's, and its script's words). *)

let usage = "usage: mini-emacs-tty [-keys script] [file]   (-h: how)"

let help = {|usage: mini-emacs-tty [-keys script] [file]
An Emacs in this terminal, on the file (made when saved, if it is not there).
Its keys are Emacs's: C-f C-b C-n C-p and the arrows, C-a C-e, M-f M-b, M-< M->,
C-v M-v, C-l, C-d, C-x C-s saves, C-x C-c ends it. Meta is Alt, or Escape before.
-keys: no terminal; the script's keys given (C-x A-f Enter ArrowDown Escape
=text; 16x60: the screen made 16 rows of 60 columns), and the screen they
leave printed as text.|}

(* a word of a script, as the bytes a terminal sends: =text is its
 * characters, C- and A- Control and Alt before a key of Vt.key's
 * names, or a character *)
let keys (word : string) : string list option =
  let n = String.length word in
  if n > 1 && word.[0] = '=' then Some (fst (Utf8.chars (String.sub word 1 (n - 1))))
  else begin
    let rec modifiers (w : string) (ctrl : bool) (alt : bool) : string * bool * bool =
      if String.length w > 2 && w.[1] = '-' && w.[0] = 'C' then modifiers (String.sub w 2 (String.length w - 2)) true alt
      else if String.length w > 2 && w.[1] = '-' && w.[0] = 'A' then modifiers (String.sub w 2 (String.length w - 2)) ctrl true
      else (w, ctrl, alt) in
    let name, ctrl, alt = modifiers word false false in
    if String.length name = 1 && not ctrl then Some [ (if alt then "\x1b" ^ name else name) ]
    else Option.map (fun (bytes : string) -> [ bytes ]) (Vt.key ~alt ~ctrl name)
  end

(* the screen the script leaves, or its word that is no key. The
 * screen is made after each key, as in a terminal: a frame moves over
 * its text when it is shown (Frame.display) *)
let session (p : Efuns.top_window Tui.program) (script : string) : (Curses.t, string) result =
  let event (e : Tui.event) : unit = ignore (p.update e p.init); ignore (p.view p.init) in
  let rec go (words : string list) : (Curses.t, string) result =
    match words with
    | [] -> Ok (p.view p.init)
    | "" :: rest -> go rest
    | w :: rest -> (
        match String.split_on_char 'x' w |> List.map int_of_string_opt with
        | [ Some rows; Some cols ] -> event (Tui.Resize (rows, cols)); go rest
        | _ -> (
            match keys w with
            | None -> Error w
            | Some ks -> List.iter (fun (k : string) -> event (Tui.Key k)) ks; go rest)) in
  go (String.split_on_char ' ' script)

let main (caps : < Cap.stdin ; Cap.stdout ; Cap.stderr ; Cap.open_in ; Cap.open_out ; .. >) (argv : string array) : Exit.t =
  let script : string option ref = ref None and file : string option ref = ref None in
  let options = [
    "-keys", Arg.String (fun (s : string) -> script := Some s), " script: no terminal, the screen its keys leave";
    "-h", Arg.Unit (fun () -> raise (Arg.Help "")), " how";
  ] in
  match Arg.parse_argv argv options (fun (a : string) -> file := Some a) usage with
  | exception Arg.Help _ -> Console.print caps (help ^ "\n"); Exit.OK
  | exception Arg.Bad msg -> Console.eprint caps msg; Exit.Code 1
  | () -> (
      Config.keys ();
      let buf =
        match !file with
        | Some f -> Ebuffer.read caps f
        | None -> Ebuffer.create "*scratch*" None (Text.create "") in
      let top = Top_window.create (caps :> Efuns.caps) 24 80 buf in
      let p = Top_window.program top in
      match !script with
      | None -> Tty_unix.run_sized caps p; Exit.OK
      | Some s -> (
          match session p s with
          | Ok screen -> List.iter (fun (r : string) -> Console.print caps (r ^ "\n")) (Curses.text screen); Exit.OK
          | Error w -> Console.eprint caps (w ^ ": no key of that name\n"); Exit.Code 1))

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
