(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* TinyLibCore/Sha1.ml's digests, a line each, which TinyLibCore_test.sh
 * compares with sha1sum's: the empty string, "abc", 55, 56 and 64
 * bytes (the padding's edges: one block or two), a long text *)
let () =
  List.iter (fun s -> print_endline (Sha1.to_hex (Sha1.string s)))
    [ ""; "abc"; String.make 55 'a'; String.make 56 'a'; String.make 64 'a';
      String.concat "" (List.init 2000 (fun i -> string_of_int i ^ " lines of the tiny machine\n")) ]
