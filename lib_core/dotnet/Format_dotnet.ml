(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Format_dotnet.mli *)

(* (the format a function: the compiler's representation of one) *)
external fn : ('a, 'b, 'c, 'd) format4 -> (string -> 'd) -> 'a = "%identity"
let apply (f : ('a, 'b, 'c, 'd) format4) (k : string -> 'd) : 'a = let g = fn f in g k

let fprintf (ppf : Format.formatter) (f : ('a, Format.formatter, unit) format) : 'a =
  apply f (fun (s : string) -> Format.pp_print_string ppf s)

let printf (f : ('a, Format.formatter, unit) format) : 'a = fprintf Format.std_formatter f
