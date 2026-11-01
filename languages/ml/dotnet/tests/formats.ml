(* formats as values (stage 3c): a literal format compiled to a
 * function of where its text goes (F#'s way), Printf's and Format's
 * functions over it (lib_core/dotnet/Printf_dotnet.ml, Format_dotnet.ml),
 * Logs' msgf; the lines before Logs as OCaml prints them *)

let show (f : (int -> string -> string, unit, string) format) = Printf.sprintf f 3 "x"
let log fmt = Printf.ksprintf (fun s -> print_endline ("log: " ^ s)) fmt
let () =
  print_endline (show "%d and %s");
  log "%s=%d" "a" 1;
  let p = Printf.printf in
  p "via a value %b\n" true;
  Format.printf "fmt %d@." 5;
  Format.fprintf Format.std_formatter "box @[<v 2>%s@]@." "inside";
  Logs.set_level (Some Logs.Info);
  Logs.set_reporter { Logs.pp_header = (fun ppf (_, _) -> Format.fprintf ppf "[info] "); dst = Format.std_formatter };
  Logs.info (fun m -> m "hello %d %s" 42 "logs");
  Logs.debug (fun m -> m "hidden %d" 0)
