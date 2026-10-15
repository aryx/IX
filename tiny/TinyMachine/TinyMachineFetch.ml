(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyMachineFetch.mli *)

let main (caps : < Cap.network; Cap.open_in; Cap.stdout; Cap.argv; .. >) =
  match Array.to_list (CapSys.argv caps) with
  | [ _; url ] -> (
      match Http_client.get caps url with
      | Ok (r : Http.response) -> Console.print caps r.body; 0
      | Error why -> Console.print caps ("www: " ^ url ^ ": " ^ why ^ "\n"); 1)
  | _ -> Console.print caps "www: usage: tiny-machine-fetch url\n"; 2

let () = Cap.main (fun caps -> CapStdlib.exit caps (main caps))
