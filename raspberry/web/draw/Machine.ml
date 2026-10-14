(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Machine.mli *)

module Imag = struct
  let alloc n = Bytes.make n '\000'
  let free (_ : Bytes.t) = ()
  let quiet () = ()
  let flush (_ : Bytes.t) (_ : int array) = invalid_arg "Hostdraw: no screen to flush"
end
