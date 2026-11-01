(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Printf_dotnet.mli *)

(* (the format a function: the compiler's representation of one) *)
external fn : ('a, 'b, 'c, 'd) format4 -> (string -> 'd) -> 'a = "%identity"
let apply (f : ('a, 'b, 'c, 'd) format4) (k : string -> 'd) : 'a = let g = fn f in g k

let ksprintf (k : string -> 'd) (f : ('a, unit, string, 'd) format4) : 'a = apply f k
let sprintf (f : ('a, unit, string) format) : 'a = apply f (fun (s : string) -> s)
let printf (f : ('a, out_channel, unit) format) : 'a = apply f (fun (s : string) -> print_string s)
let eprintf (f : ('a, out_channel, unit) format) : 'a = apply f (fun (s : string) -> prerr_string s)

let fprintf (oc : out_channel) (f : ('a, out_channel, unit) format) : 'a =
  apply f (fun (s : string) -> output_string oc s)

let bprintf (b : Buffer.t) (f : ('a, Buffer.t, unit) format) : 'a =
  apply f (fun (s : string) -> Buffer.add_string b s)

(* %a's and %t's text, a format being compiled (Il_exprs.format_value):
 * sprintf's printer's own string, bprintf's on a buffer *)
let capture (p : unit -> 'x -> string) (x : 'x) : string = p () x
let capture_t (p : unit -> string) : string = p ()

let capture_buffer (p : Buffer.t -> 'x -> unit) (x : 'x) : string =
  let b = Buffer.create 16 in
  p b x;
  Buffer.contents b

let capture_buffer_t (p : Buffer.t -> unit) : string =
  let b = Buffer.create 16 in
  p b;
  Buffer.contents b
