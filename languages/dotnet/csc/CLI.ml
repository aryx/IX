(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See CLI.mli *)

type caps = < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

let usage = "usage: mini-csc [-o file.dll] file.cs"

let compile (caps : < caps; .. >) (file : string) (out : string) : (unit, string) result =
  match FS.path file with
  | Error e -> Error e
  | Ok p ->
      let text = FS.read caps p in
      let at line = Printf.sprintf "%s:%d: " file line in
      match Csc_parser.program text with
      | exception Csc_lexer.Error (msg, l) -> Error (at l ^ msg)
      | exception Csc_parser.Error (msg, l) -> Error (at l ^ msg)
      | ast ->
          let name = Filename.remove_extension (Filename.basename out) in
          match Csc_compile.program name ast with
          | exception Csc_types.Error (msg, l) -> Error (at l ^ msg)
          | bytes ->
              (match FS.path out, FS.path (Filename.remove_extension out ^ ".runtimeconfig.json") with
               | Ok o, Ok cfg -> FS.write caps o bytes; FS.write caps cfg Writer.runtime_config; Ok ()
               | Error e, _ | _, Error e -> Error e)

let main (caps : < caps; .. >) (argv : string array) : int =
  let out = ref "" and files = ref [] in
  let options = [ ("-o", Arg.Set_string out, " the assembly written (file.dll, here, by default)") ] in
  match Arg.parse_argv argv options (fun (f : string) -> files := f :: !files) usage with
  | exception Arg.Help _ -> Console.print caps (usage ^ "\n"); 0
  | exception Arg.Bad msg -> Console.eprint caps msg; 1
  | () ->
      match !files with
      | [ f ] ->
          let out = if !out = "" then Filename.remove_extension (Filename.basename f) ^ ".dll" else !out in
          (match compile caps f out with
           | Ok () -> 0
           | Error msg -> Console.eprint caps (msg ^ "\n"); 1
           | exception Sys_error msg -> Console.eprint caps ("mini-csc: " ^ msg ^ "\n"); 1)
      | _ -> Console.eprint caps (usage ^ "\n"); 1
