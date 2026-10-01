(* the stdlib's String, what ix's own (lib_core/base) adds to
 * ocaml-light's: OCaml's later functions, with OCaml's answers *)

let line s = print_string s; print_newline ()
let show = string_of_int
let opt = function Some n -> show n | None -> "none"

let () =
  let s = "hello, world" in
  line (string_of_bool (String.contains s 'w') ^ " " ^ string_of_bool (String.contains s 'z') ^ " " ^ string_of_bool (String.contains "" 'a'));
  line (opt (String.index_opt s 'o') ^ " " ^ opt (String.rindex_opt s 'o') ^ " " ^ opt (String.index_opt s 'z') ^ " " ^ opt (String.rindex_opt "" 'o'));
  line (opt (String.index_from_opt s 5 'o') ^ " " ^ opt (String.index_from_opt s 9 'o') ^ " " ^ opt (String.index_from_opt s 12 'o'));
  (try line (opt (String.index_from_opt s 13 'o')) with Invalid_argument m -> line ("Invalid_argument " ^ m));
  String.iter (fun c -> print_char (Char.chr (Char.code c - 32))) "abc";
  String.iteri (fun i c -> print_string (show i); print_char c) "xyz";
  print_newline ();
  let digit c = c >= '0' && c <= '9' in
  line (string_of_bool (String.for_all digit "2026") ^ " " ^ string_of_bool (String.for_all digit "20x6") ^ " " ^ string_of_bool (String.for_all digit "")
        ^ " " ^ string_of_bool (String.exists digit "ab3") ^ " " ^ string_of_bool (String.exists digit "abc") ^ " " ^ string_of_bool (String.exists digit ""));
  line (String.init 5 (fun i -> Char.chr (Char.code 'a' + (2 * i))) ^ "|" ^ String.init 0 (fun _ -> 'x') ^ "|");
  (* the labels *)
  line (string_of_bool (String.starts_with ~prefix:"hel" s) ^ " " ^ string_of_bool (String.starts_with s ~prefix:"help") ^ " "
        ^ string_of_bool (String.ends_with ~suffix:"world" s) ^ " " ^ string_of_bool (String.ends_with ~suffix:"" s)
        ^ " " ^ show (List.length (List.filter (String.starts_with ~prefix:"a") [ "ab"; "ba"; "a" ])));
  (* a binary format's fields *)
  let b = "\x01\x02\x03\x84\xf5\xf6\xf7\xf8\x7f" in
  line (show (String.get_uint16_le b 0) ^ " " ^ show (String.get_uint16_be b 0) ^ " " ^ show (String.get_uint16_le b 3));
  line (Int32.to_string (String.get_int32_le b 0) ^ " " ^ Int32.to_string (String.get_int32_be b 0) ^ " " ^ Int32.to_string (String.get_int32_be b 3));
  line (Int64.to_string (String.get_int64_le b 0) ^ " " ^ Int64.to_string (String.get_int64_be b 0) ^ " " ^ Int64.format "%x" (String.get_int64_be b 1));
  line (show (Int32.to_int (String.get_int32_le b 0) land 0xffff))
