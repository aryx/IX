(* packages: logs,logs.fmt,fmt,fpath *)
(* Logs: mini-ml's poor man's (lib_core/system) against the library's,
 * as ix's Logging sets it up; all on stderr *)

let setup name level =
  Logs.set_level level;
  let pp_header ppf (l, _) = Fmt.pf ppf "%s: [%s] " name (String.uppercase_ascii (Logs.level_to_string (Some l))) in
  Logs.set_reporter (Logs_fmt.reporter ~pp_header ~dst:Fmt.stderr ())

let all () =
  Logs.app (fun m -> m "app %d" 1);
  Logs.err (fun m -> m "an error: %s" "bad");
  Logs.warn (fun m -> m "a warning");
  Logs.info (fun m -> m "from a library: %a, for %s" Fpath.pp (Fpath.v "lib/libc.a") "main");
  Logs.debug (fun m -> m "read %a (%d bytes)" Fpath.pp (Fpath.v "a/b.c") 42)

let () =
  (* before a reporter is set: nothing *)
  all ();
  List.iter (fun s ->
    let level = match Logs.level_of_string s with Ok l -> l | Error _ -> Some Logs.Warning in
    setup ("prog-" ^ s) level;
    (* a message not reported is not formatted *)
    Logs.debug (fun m -> if level <> Some Logs.Debug then prerr_endline "formatted!"; m "level %s" (Logs.level_to_string level));
    all ()) [ "warning"; "debug"; "info"; "error"; "app"; "quiet"; "nonsense" ]
