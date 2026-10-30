(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-open: a file given to the program that reads it, whichever that
 * is, as macOS's open (2001) and Linux's xdg-open (2006):
 *
 *     mini-open song.mp3
 *
 * The same dispatch as mini-files', for the terminal (lib_mime's
 * File_kind then Helpers: ~/.mailcap's rules, the built-in ones).
 *
 * References: RFC 1524, the mailcap file. *)

type caps = < Cap.env; Cap.open_in; Cap.open_out; Cap.readdir; Cap.exec; Cap.wait; Cap.stdout; Cap.stderr >

let usage = "usage: mini-open [-n] file
  the file given to the program for its kind (~/.mailcap, the built-in rules)
  -n: only say its kind and the command"

let fail (caps : < caps; .. >) (why : string) : Exit.t = Console.eprint caps ("mini-open: " ^ why ^ "\n"); Exit.Err why

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  let said, args = match List.tl (Array.to_list argv) with "-n" :: rest -> (true, rest) | args -> (false, args) in
  match args with
  | [ file ] -> (
      match FS.path file with
      | Error why -> fail caps why
      | Ok path -> (
          match File_kind.of_path caps path with
          | exception Sys_error why -> fail caps why
          | kind -> (
              match Helpers.for_type (Helpers.rules caps) kind with
              | None -> fail caps (Printf.sprintf "%s: no program for %s" file kind)
              | Some rule ->
                  (* (whole: a window of mini-rio's has another directory) *)
                  let file = if Sys.os_type = "Plan9" && Filename.is_relative file then Filename.concat (FS.getcwd caps ()) file else file in
                  let command = Helpers.command rule ~url:file ~file:(Some file) in
                  if said then Console.print caps (kind ^ ": " ^ String.concat " " command ^ "\n")
                  else Helpers.run caps command;
                  Exit.OK)))
  | _ -> Console.eprint caps (usage ^ "\n"); Exit.Err "usage"

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
