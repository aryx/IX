(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
 *)

(* See Testutil_images.mli *)

let reader : (string -> string) ref = ref (fun (_ : string) -> failwith "Testutil_images.reader is not set")
