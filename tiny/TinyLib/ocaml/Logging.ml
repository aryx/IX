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
  let pp_header ppf (l, _) = Printf.fprintf ppf "%s: [%s] " name (String.uppercase_ascii (Logs.level_to_string (Some l))) in
  Logs.set_reporter (Logs_fmt.reporter ~pp_header ~dst:stderr ())
