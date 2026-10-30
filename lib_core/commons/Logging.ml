(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Logging.mli *)

let setup (caps : < Cap.env; Cap.stderr; .. >) ~name =
  let level =
    match CapSys.getenv caps "IX_LOG" with
    | s -> (match Logs.level_of_string s with Ok l -> l | Error _ -> Some Logs.Warning)
    | exception Not_found -> Some Logs.Warning
  in
  Logs.set_level level;
  let pp_header ppf (l, _) = Format.fprintf ppf "%s: [%s] " name (String.uppercase_ascii (Logs.level_to_string (Some l))) in
  Logs.set_reporter (Logs_fmt.reporter ~pp_header ~dst:Format.err_formatter ())

let flags =
  [ ("-v", Arg.Unit (fun () -> Logs.set_level (Some Logs.Info)), " what it does said on the standard error (common(1))");
    ("-debug", Arg.Unit (fun () -> Logs.set_level (Some Logs.Debug)), " -v's and more: the details (common(1))");
    ("-quiet", Arg.Unit (fun () -> Logs.set_level None), " not even the warnings (common(1))") ]
