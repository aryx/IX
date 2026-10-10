(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See CLI.mli *)

type caps = < Cap.open_in; Cap.stdin; Cap.stdout; Cap.stderr >

let usage = "usage: mini-node [file.js | -e text]
  file.js  its statements run
  -e       the text's
  nothing: each line of the input run, its value shown"

let main (caps : < caps; .. >) (argv : string array) : int =
  let say (s : string) : unit = Console.print caps (s ^ "\n") in
  let engine = Js_eval.create_with say 1 (fun () -> Unix.gettimeofday () *. 1000.) in
  (* a script whole: what it logs, and its error if it ends by one *)
  let run (text : string) : int =
    match Js_eval.eval engine text with
    | Ok _ -> 0
    | Error e -> Console.eprint caps (Printf.sprintf "line %d: %s\n" e.line e.message); 1
  in
  match List.tl (Array.to_list argv) with
  | [ "-e"; text ] -> run text
  | [ file ] when file.[0] <> '-' -> (
      match FS.read caps (Fpath.v file) with
      | text -> run text
      | exception Sys_error why -> Console.eprint caps ("mini-node: " ^ why ^ "\n"); 1)
  | [] ->
      let prompt = Unix.isatty (Console.stdin_fd caps) in
      let rec go () =
        if prompt then (Console.print caps "> "; flush (Console.stdout caps));
        match In_channel.input_line (Console.stdin caps) with
        | None -> ()
        | Some line ->
            (match Js_eval.eval engine line with
             | Ok v -> say (Js_value.display v)
             | Error e -> say e.message);
            flush (Console.stdout caps);
            go ()
      in
      go ();
      0
  | _ -> Console.eprint caps (usage ^ "\n"); 2
