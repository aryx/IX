(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* TinyLibCore/Sha1.ml's digests, a line each, which TinyLibCore_test.sh
 * compares with sha1sum's: the empty string, "abc", 55, 56 and 64
 * bytes (the padding's edges: one block or two), a long text; each
 * also by Sha1.reads, in pieces of 1, 7, 64 and 100 bytes in turn (a
 * line more when it differs) *)
let pieces s =
  let at = ref 0 and k = ref 0 in
  fun () ->
    let n = min (List.nth [ 1; 7; 64; 100 ] (!k mod 4)) (String.length s - !at) in
    let p = String.sub s !at n in
    at := !at + n; incr k; p

let () =
  List.iter (fun s ->
    let d = Sha1.to_hex (Sha1.string s) in
    print_endline d;
    let r = Sha1.to_hex (Sha1.reads (pieces s)) in
    if r <> d then print_endline ("Sha1.reads: " ^ r))
    [ ""; "abc"; String.make 55 'a'; String.make 56 'a'; String.make 64 'a';
      String.concat ""
        (List.init 2000 (fun i ->
          string_of_int i ^ " lines of the tiny machine\n")) ]
