(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* dune's programs' manifests: see Dune_manifest.mli *)

let () =
  Cap.main (fun caps ->
      CapStdlib.exit caps (Dune_manifest.main caps (CapSys.argv caps)))
