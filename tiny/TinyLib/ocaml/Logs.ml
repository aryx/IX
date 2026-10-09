(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Logs.mli: a poor man's logs (Daniel Bünzli's), as xix's; bundled
 * here just for mini-ml (dune's builds take the real library). *)

type level = App | Error | Warning | Info | Debug

type 'a msgf = (('a, out_channel, unit) format -> 'a) -> unit
type 'a log = 'a msgf -> unit
type reporter = { pp_header : out_channel -> level * string option -> unit; dst : out_channel }

let current_level = ref (Some Warning)
let current_reporter : reporter option ref = ref None
let set_level l = current_level := l
let set_reporter r = current_reporter := Some r

let names = [ "app", App; "error", Error; "warning", Warning; "info", Info; "debug", Debug ]
let level_to_string = function None -> "quiet" | Some l -> fst (List.find (fun (_, l') -> l' = l) names)
let level_of_string s =
  if s = "quiet" then Ok None
  else match List.assoc_opt s names with Some l -> Ok (Some l) | None -> Error ("unknown level: " ^ s)

(* the levels are in their order: App < Error < ... < Debug *)
let msg (l : level) (msgf : 'a msgf) =
  match !current_level, !current_reporter with
  | Some max, Some r when compare l max <= 0 ->
      r.pp_header r.dst (l, None);
      msgf (Printf.fprintf r.dst);
      output_char r.dst '\n';
      flush r.dst
  | _ -> ()

let app msgf = msg App msgf
let info msgf = msg Info msgf
let debug msgf = msg Debug msgf
