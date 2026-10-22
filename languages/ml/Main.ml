(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-ml, the ix ML compiler: see CLI.mli *)

(* OPTIMIZATION (the heap): a heap three times what is alive, not
 * twice (Gc's space_overhead, 100 by default): a compile keeps every
 * interface it read alive, and the copying collector copied it all at
 * each collection, 30% of a compile (mini-prof, Typing.ml on arm).
 * 200: 45 collections to 28, 10% fewer instructions, the same heap
 * (the runtime's halves double: they were already past it); 400: 16%,
 * but halves of 64 MB, mini-9pi's most, four compiles at once beyond
 * its memory (variants/ssa.md)
 * old: nothing (100) *)
let () = Gc.set { (Gc.get ()) with Gc.space_overhead = 200 }

let () = Cap.main (fun caps -> Logging.setup caps ~name:"mini-ml"; CapStdlib.exit caps (CLI.main caps (CapSys.argv caps)))
