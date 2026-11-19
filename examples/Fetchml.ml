(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* fetchml: a document of another machine's by HTTP, on the standard
 * output, with lib_networking: Http_client.get cuts the URL, finds the
 * name's address (Dns), connects (Tcp, which on mini-9pi is /net's
 * files and on Linux sockets), writes the request and reads the
 * answer; for https:// the connection is inside ix's own TLS.
 * networking/Curl.ml is the whole program of this kind, mini-curl. The
 * mkfile beside it builds it, with lib_networking and the two
 * libraries under it, lib_crypto and lib_compression:
 *
 *     cd /src/examples; mk
 *     ../_mk/5-plan9/examples/fetchml http://example.com/
 *)

type caps = < Cap.network; Cap.open_in; Cap.clock; Cap.stdout; Cap.stderr >

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  if Array.length argv <> 2 then begin
    Console.eprint caps "usage: fetchml url\n";
    Exit.Code 1
  end
  else
    match Http_client.get caps argv.(1) with
    | Ok (response : Http.response) ->
        Console.eprint caps
          (Printf.sprintf "fetchml: %d %s, %d bytes\n" response.status
             response.reason (String.length response.body));
        Console.print caps response.body;
        Exit.OK
    | Error why ->
        Console.eprint caps (Printf.sprintf "fetchml: %s\n" why);
        Exit.Code 1

let () =
  Cap.main (fun caps ->
      Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
