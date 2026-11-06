(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Fpath_.mli *)

let of_strings strings = List.map Fpath.v strings
let to_strings paths = List.map Fpath.to_string paths

module Operators = struct
  let ( / ) = Fpath.add_seg
  let ( // ) = Fpath.append
  let ( !! ) = Fpath.to_string
end
