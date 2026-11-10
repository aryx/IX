(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* www, tiny-kernel's web browser: ../TinyBrowser.ml's browse, on the
 * address given (its words joined, so that www Plan 9 from Bell Labs
 * needs no quotes). It is linked as an a.out that asks for 10 MB
 * (tiny-linker -a 10): a page's lines live in the heap. OCaml
 * compiles it too, for the host (tiny-www, sdl/): its system
 * TinyLibSystem's, a window's and the host's network.
 *
 *     www OCaml *)
module TSys = TinyLibSystem
open TinyBrowser

let () =
  TSys.main "www" (fun caps argv ->
    if Array.length argv < 2 then begin
      TSys.eprint caps "usage: www address\n";
      Exit.Code 1
    end
    else begin
      browse caps
        (String.concat " " (Array.to_list (Array.sub argv 1 (Array.length argv - 1))));
      Exit.OK
    end)
