(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* mini-emacs in the terminal one types this in: Top_window's program
 * run by Tty_unix. With -keys, no terminal: a session is a line of
 * keys and what it leaves a screen as text, for the tests (as
 * mini-turbopascal-tty's, and its script's words). *)

let usage = "usage: mini-emacs-tty [-q] [-keys script [-colors]] [file]   (-h: how)"

let help = {|usage: mini-emacs-tty [-q] [-keys script [-colors]] [file]
An Emacs in this terminal, on the file (made when saved, if it is not there).
Its keys are Emacs's: C-f C-b C-n C-p and the arrows, C-a C-e, M-f M-b, M-< M->,
C-v M-v, C-l; C-d, C-k, C-w, M-w, C-y, M-y, C-_ undoes; C-s and C-r search, M-%
replaces; C-x C-f a file, C-x b a buffer, C-x 2, C-x 3, C-x o, C-x 0, C-x 1 the
windows; C-x C-b the buffers; a directory opened is a list of its files (RET
opens one); M-u M-l M-c a word's case, C-t, M-q fills a paragraph, M-g a line by
its number; C-x ( C-x ) C-x e a keyboard macro; M-x a command by its name; C-x
C-s saves, C-x C-c ends it. Meta is Alt, or Escape before.
-keys: no terminal; the script's keys given (C-x A-f Enter ArrowDown Escape Space
=text; 16x60: the screen made 16 rows of 60 columns), and the screen they
leave printed as text; with -colors, under each row how its cells are shown
(r, g, y, b, m, c: a color; a capital: bold; #: reverse).
A file's colors are its language's, by its name: .ml .c .h .s .st .scm .pas;
there TAB indents (but in C and assembly), C-j is a new line indented.
The configuration is the author's (Config_pad: his colors on a dark ground, a
directory's files colored, M-g a line's number, y for yes); -q: without it.|}

(* a word of a script, as the bytes a terminal sends: =text is its
 * characters, C- and A- Control and Alt before a key of Vt.key's
 * names, a character, or Space *)
let keys (word : string) : string list option =
  let n = String.length word in
  if n > 1 && word.[0] = '=' then Some (fst (Utf8.chars (String.sub word 1 (n - 1))))
  else begin
    let rec modifiers (w : string) (ctrl : bool) (alt : bool) : string * bool * bool =
      if String.length w > 2 && w.[1] = '-' && w.[0] = 'C' then modifiers (String.sub w 2 (String.length w - 2)) true alt
      else if String.length w > 2 && w.[1] = '-' && w.[0] = 'A' then modifiers (String.sub w 2 (String.length w - 2)) ctrl true
      else (w, ctrl, alt) in
    let name, ctrl, alt = modifiers word false false in
    let name = if name = "Space" && not ctrl then " " else name in
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

(* the terminal's color nearest one said by its red, green and blue *)
let nearest ((r, g, b) : int * int * int) : char =
  let basic = [ 'k', (0, 0, 0); 'r', (205, 0, 0); 'g', (0, 205, 0); 'y', (205, 205, 0); 'b', (0, 0, 238); 'm', (205, 0, 205);
                'c', (0, 205, 205); 'w', (229, 229, 229);
                (* and some between them: orange, pink, lime, sky blue, gray *)
                'o', (255, 165, 0); 'p', (255, 181, 197); 'l', (127, 255, 0); 's', (135, 206, 255); 'a', (190, 190, 190) ] in
  let far ((_, (r', g', b')) : char * (int * int * int)) : int = ((r - r') * (r - r')) + ((g - g') * (g - g')) + ((b - b') * (b - b')) in
  fst (List.fold_left (fun (best : char * (int * int * int)) (c : char * (int * int * int)) -> if far c < far best then c else best)
         (List.hd basic) basic)

(* a screen's rows as text, and under each row that is not all plain
 * (the editor's plain) how its cells are shown: a color's first letter
 * (r, g, y, b, m, c; k for black, w for white; for a color said by its
 * red, green and blue, the nearest of them and of o, p, l, s, a: orange,
 * pink, lime, sky blue, gray), a capital for bold, # for reverse *)
let colors (screen : Curses.t) : string list =
  List.concat (List.mapi (fun (r : int) (row : string) ->
    let marks = String.init (Curses.cols screen) (fun (c : int) ->
      let a = (Curses.cell screen r c).attrs in
      let letter = (match a.fg with
        | Red -> 'r' | Green -> 'g' | Yellow -> 'y' | Blue -> 'b' | Magenta -> 'm' | Cyan -> 'c'
        | Default | Black | White -> ' '
        | Rgb (r, g, b) -> nearest (r, g, b)) in
      if a.reverse then '#' else if a = Globals.editor.edt_plain then ' ' else if a.bold then Char.uppercase_ascii letter else letter) in
    if String.trim marks = "" then [ row ] else [ row; marks ]) (Curses.text screen))

let main (caps : < Cap.stdin ; Cap.stdout ; Cap.stderr ; Cap.open_in ; Cap.open_out ; .. >) (argv : string array) : Exit.t =
  let script : string option ref = ref None and file : string option ref = ref None and marks = ref false and pad = ref true in
  let options = [
    "-keys", Arg.String (fun (s : string) -> script := Some s), " script: no terminal, the screen its keys leave";
    "-q", Arg.Clear pad, " without the author's configuration (Config_pad): Emacs's keys, a terminal's eight colors";
    "-whole", Arg.Set Ebuffer.whole, " the colors of the whole text asked at each change (Ebuffer.colors)";
    "-colors", Arg.Set marks, " with -keys: under each row, how its cells are shown";
    "-h", Arg.Unit (fun () -> raise (Arg.Help "")), " how";
  ] in
  match Arg.parse_argv argv options (fun (a : string) -> file := Some a) usage with
  | exception Arg.Help _ -> Console.print caps (help ^ "\n"); Exit.OK
  | exception Arg.Bad msg -> Console.eprint caps msg; Exit.Code 1
  | () -> (
      Config.keys ();
      Config.modes ();
      if !pad then Config_pad.config ();
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
          | Ok screen ->
              List.iter (fun (r : string) -> Console.print caps (r ^ "\n")) (if !marks then colors screen else Curses.text screen);
              Exit.OK
          | Error w -> Console.eprint caps (w ^ ": no key of that name\n"); Exit.Code 1))

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
