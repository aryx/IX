(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* Picture.ml on tiny-machine, by tiny-ml -tm (after it, as one
 * program): the picture drawn with the font start.tm has, then the
 * machine halted (exit: runtime.c's, after the lines are written),
 * whose screen tiny-machine -screen writes. *)
open Picture

external font_bits : unit -> int = "font_bits"
let () = picture (font_bits ()); exit 0
