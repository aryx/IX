(* Digest: MD5 of strings (RFC 1321's, and at the padding's edges), of
 * a file and of a channel's part; OCaml's output by mini-ml *)

let () =
  let hex s = Digest.to_hex (Digest.string s) in
  List.iter (fun s -> print_endline (hex s))
    [ ""; "a"; "abc"; "message digest"; "abcdefghijklmnopqrstuvwxyz";
      "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
      "12345678901234567890123456789012345678901234567890123456789012345678901234567890" ];
  List.iter (fun n -> Printf.printf "%d %s\n" n (hex (String.make n 'x'))) [ 55; 56; 57; 63; 64; 65; 119; 120; 1000; 100000 ];
  print_endline (hex (String.init 256 Char.chr));
  print_endline (Digest.to_hex (Digest.substring "..abc.." 2 3));
  Printf.printf "%d %b\n" (String.length (Digest.string "abc")) (Digest.string "abc" = Digest.string "abc");
  let file = Filename.temp_file "digest" ".txt" in
  Out_channel.with_open_bin file (fun oc -> output_string oc (String.make 10000 'y' ^ "abc"));
  print_endline (Digest.to_hex (Digest.file file));
  Printf.printf "%b\n" (Digest.file file = Digest.string (String.make 10000 'y' ^ "abc"));
  In_channel.with_open_bin file (fun ic ->
    Printf.printf "%b" (Digest.channel ic 10000 = Digest.string (String.make 10000 'y'));
    Printf.printf " %s" (Digest.to_hex (Digest.channel ic 3));
    Printf.printf " %b\n" (try ignore (Digest.channel ic 1); false with End_of_file -> true));
  Sys.remove file
