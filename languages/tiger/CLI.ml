(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See CLI.mli *)

type caps = < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

let usage = "usage: mini-tiger [-o file.dll] file.tig"

let compile (caps : < caps; .. >) (file : string) (out : string) : (unit, string) result =
  match FS.path file with
  | Error e -> Error e
  | Ok p ->
      let text = FS.read caps p in
      let lexbuf = Lexing.from_string text in
      let at (l, c) = Printf.sprintf "%s:%d.%d: " file l c in
      let at_pos (p : Lexing.position) = at (p.pos_lnum, p.pos_cnum - p.pos_bol + 1) in
      match Tiger_parser.program Tiger_lexer.token lexbuf with
      | exception Tiger_lexer.Error (msg, p) -> Error (at_pos p ^ msg)
      | exception Parsing.Parse_error -> Error (at_pos lexbuf.Lexing.lex_start_p ^ "a syntax error")
      | ast ->
          match Tiger_semant.program ast with
          | exception Tiger_semant.Error (msg, p) -> Error (at p ^ msg)
          | prog ->
              let name = Filename.remove_extension (Filename.basename out) in
              let bytes = Tiger_emit.program name prog in
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
           | exception Sys_error msg -> Console.eprint caps ("mini-tiger: " ^ msg ^ "\n"); 1)
      | _ -> Console.eprint caps (usage ^ "\n"); 1
