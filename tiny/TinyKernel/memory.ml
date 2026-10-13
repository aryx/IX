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
(* a string's n bytes from off, to memory at dst (runtime.c's k_blit) *)
external row_bytes : string -> int -> int -> int -> unit = "k_blit"
