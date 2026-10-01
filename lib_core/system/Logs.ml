(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* See Logs.mli: a poor man's logs (Daniel Bünzli's), as xix's; bundled
 * here just for mini-ml (dune's builds take the real library). *)

type level = App | Error | Warning | Info | Debug

type 'a msgf = (('a, Format.formatter, unit) format -> 'a) -> unit
type 'a log = 'a msgf -> unit
type reporter = { pp_header : Format.formatter -> level * string option -> unit; dst : Format.formatter }

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
      msgf (Format.fprintf r.dst);
      Format.pp_print_newline r.dst ()
  | _ -> ()

let app msgf = msg App msgf
let err msgf = msg Error msgf
let warn msgf = msg Warning msgf
let info msgf = msg Info msgf
let debug msgf = msg Debug msgf
