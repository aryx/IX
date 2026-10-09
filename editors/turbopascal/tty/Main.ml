(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* mini-turbopascal in the terminal one types this in (the author's
 * playground's apps/devtools/tty/TinyTurboPascal.ml): Tui_turbo's
 * program run by Tty_unix. The terminal's own colours stand for the
 * PC's, and its font must have the box characters. Its files are its
 * own disk's, in memory. *)

let usage = "usage: mini-turbopascal-tty [-keys script]   (-h: how)"

let help = {|usage: mini-turbopascal-tty [-keys script]
Turbo Pascal's IDE in this terminal, 80 by 24 at least: F9 compiles, Control-F9
runs, F10 the menus, F1 the keys; Control-C ends it. Without F keys: Escape
then a digit (0 for F10), Control and a digit for Control and the F key.
-keys: no terminal; the script's keys given (F9 C-F9 A-c Enter ArrowDown
=text), and the screen they leave printed as text.|}

let main (caps : < Cap.stdin; Cap.stdout; Cap.stderr; .. >) (argv : string array) : Exit.t =
  let script : string option ref = ref None in
  let options = [
    "-keys", Arg.String (fun (s : string) -> script := Some s), " script: no terminal, the screen its keys leave";
    "-h", Arg.Unit (fun () -> raise (Arg.Help "")), " how";
  ] in
  match Arg.parse_argv argv options (fun (a : string) -> raise (Arg.Bad (a ^ ": no argument is expected\n"))) usage with
  | exception Arg.Help _ -> Console.print caps (help ^ "\n"); Exit.OK
  | exception Arg.Bad msg -> Console.eprint caps msg; Exit.Code 1
  | () -> (
      match !script with
      | None -> Tty_unix.run caps Tui_turbo.program; Exit.OK
      | Some s -> (
          match Keys.screen s with
          | Ok rows -> List.iter (fun (r : string) -> Console.print caps (r ^ "\n")) rows; Exit.OK
          | Error w -> Console.eprint caps (w ^ ": no key of that name\n"); Exit.Code 1))

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
