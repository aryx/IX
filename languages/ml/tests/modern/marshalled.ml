(* Marshal: a value's bytes are OCaml's (the same lines by OCaml and by
 * mini-ml: the bytes are printed), and a value read back is the value *)

type shape = Point | Circle of int | Rect of int * int | Named of string * shape
type rec_ = { id : int; name : string; tags : string list; mutable next : rec_ option }

let hex s = String.concat "" (List.map (fun c -> Printf.sprintf "%02x" (Char.code c)) (List.init (String.length s) (String.get s)))
let bytes v = let s = Marshal.to_string v [] in Printf.sprintf "%d %s" (String.length s) (hex s)
let back (v : 'a) : 'a = Marshal.from_string (Marshal.to_string v []) 0

let () =
  (* integers by their sizes, strings by theirs *)
  List.iter (fun n -> print_endline (bytes n)) [ 0; 63; 64; -1; 127; -128; 128; 32767; -32769; 1 lsl 30; -(1 lsl 30); 1 lsl 40; min_int ];
  List.iter (fun s -> print_endline (bytes s)) [ ""; "a"; String.make 31 'x'; String.make 32 'y'; String.make 300 'z' ];
  print_endline (bytes (1, "two", [ 3; 4 ], Some 5, None, (), true, 'c'));
  print_endline (bytes [ Point; Circle 1; Rect (2, 3); Named ("n", Circle 4) ]);
  print_endline (bytes [| 1; 2; 3; 4; 5; 6; 7; 8; 9 |]);
  print_endline (bytes ([||] : int array));
  print_endline (bytes (3.5, -0.0, 1e300));
  print_endline (bytes (1L, -1L, 0x1234_5678_9abc_def0L, 7l, -7l));
  (* what is shared is written once; a cycle ends *)
  let s = String.make 3 's' in
  let l = [ s; s ] in
  print_endline (bytes (l, l, s));
  let a = { id = 1; name = "a"; tags = [ "x"; "y" ]; next = None } in
  let b = { id = 2; name = "b"; tags = a.tags; next = Some a } in
  a.next <- Some b;
  print_endline (bytes a);
  let a' = back a in
  (match a'.next with
   | Some b' -> Printf.printf "%d %s %b %b %b\n" b'.id b'.name (b'.tags == a'.tags) (match b'.next with Some x -> x == a' | None -> false) (a' != a)
   | None -> ());
  (* read back: equal, by structure *)
  let v = ([ Point; Named ("deep", Named ("er", Rect (-5, 1 lsl 20))) ], [| "one"; "two" |], (2.5, 0x7fff_ffff_ffff_ffffL, -3l), String.make 1000 'q') in
  Printf.printf "%b %b %b\n" (back v = v) (back 42 = 42) (back "str" = "str");
  let big = List.init 200000 (fun i -> i * 7) in
  let s = Marshal.to_string big [] in
  Printf.printf "%d %d %d %b\n" (String.length s) (Marshal.data_size (Bytes.of_string s) 0) (Marshal.total_size (Bytes.of_string s) 0) ((Marshal.from_string s 0 : int list) = big);
  (* many strings: the heap grows for them *)
  let words = List.init 50000 (fun i -> string_of_int i ^ "-word") in
  Printf.printf "%b %b\n" (back words = words) ((Marshal.from_bytes (Marshal.to_bytes words []) 0 : string list) = words);
  (* a channel: two values, then the end *)
  let file = Filename.temp_file "marshal" ".bin" in
  let oc = open_out_bin file in
  output_value oc v;
  Marshal.to_channel oc (a, [ 1; 2 ]) [];
  close_out oc;
  let ic = open_in_bin file in
  let v' = input_value ic in
  let (a'' : rec_), (l : int list) = Marshal.from_channel ic in
  Printf.printf "%b %s %d %b\n" (v' = v) a''.name (List.length l) (try ignore (input_value ic); false with End_of_file -> true);
  close_in ic;
  Sys.remove file;
  (* in a buffer, at an offset; a function is refused *)
  let buf = Bytes.make 64 '.' in
  let n = Marshal.to_buffer buf 4 60 (1, "x") [] in
  Printf.printf "%d %b %b\n" n ((Marshal.from_bytes buf 4 : int * string) = (1, "x"))
    (try ignore (Marshal.to_string (fun x -> x + n) []); false with Invalid_argument _ -> true)
