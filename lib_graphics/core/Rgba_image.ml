(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's playground's libs/graphics/images/rgba/Rgba_image.ml (docs/plans/plan_playground.md) *)

(* See Rgba_image.mli *)

(* ix: the bytes a Bytes, not a Bigarray (mini-ml has none) *)
type t = { width : int; height : int; rgba : Bytes.t }

let create ~(width : int) ~(height : int) : t = { width; height; rgba = Bytes.make (width * height * 4) '\000' }
