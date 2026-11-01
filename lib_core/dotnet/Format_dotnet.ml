(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Format_dotnet.mli *)

(* (the format a function: the compiler's representation of one) *)
external fn : ('a, 'b, 'c, 'd) format4 -> (string -> 'd) -> 'a = "%identity"
let apply (f : ('a, 'b, 'c, 'd) format4) (k : string -> 'd) : 'a = let g = fn f in g k

(* (flushed when the text has a newline: @. flushes, and it is a
 * newline in the text, the format compiled; more flushes than Format's,
 * an output's order the program's) *)
let fprintf (ppf : Format.formatter) (f : ('a, Format.formatter, unit) format) : 'a =
  apply f (fun (s : string) ->
      Format.pp_print_string ppf s;
      if String.contains s '\n' then Format.pp_print_flush ppf ())

let printf (f : ('a, Format.formatter, unit) format) : 'a = fprintf Format.std_formatter f

(* %a's and %t's text, a format being compiled (Il_exprs.format_value):
 * the printer's on a formatter over a buffer *)
let capture (p : Format.formatter -> 'x -> unit) (x : 'x) : string =
  let b = Buffer.create 16 in
  let ppf = Format.formatter_of_buffer b in
  p ppf x;
  Format.pp_print_flush ppf ();
  Buffer.contents b

let capture_t (p : Format.formatter -> unit) : string =
  let b = Buffer.create 16 in
  let ppf = Format.formatter_of_buffer b in
  p ppf;
  Format.pp_print_flush ppf ();
  Buffer.contents b
