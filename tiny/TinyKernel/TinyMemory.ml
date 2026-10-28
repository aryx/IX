(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* TinyMemory's names on tiny-machine, for TinyKernelGraphics.ml: runtime.c's
 * bytes and draw.tm's rows. Given to tiny-ml before it (host/TinyMemory.ml
 * is the host's). *)
external peekb : int -> int = "peekb"
external pokeb : int -> int -> unit = "pokeb"
external row_copy : int -> int -> int -> unit = "row_copy"
external row_fill : int -> int -> int -> unit = "row_fill"
external row_mask : int -> int -> int -> int -> unit = "row_mask"
external glyphs : int -> int -> int -> int -> string -> int -> unit = "glyphs"
external row_mix : int -> int -> int -> int -> unit = "row_mix"
external glyphs_mixed : int -> int -> int -> int -> string -> int -> unit
  = "glyphs_mixed"
external mix_table : int -> int -> int -> unit = "mix_table"
(* a string's n bytes from off, to memory at dst (runtime.c's k_blit);
 * memory's n bytes at a, as a string (its k_string) *)
external row_bytes : string -> int -> int -> int -> unit = "k_blit"
external row_string : int -> int -> string = "k_string"
