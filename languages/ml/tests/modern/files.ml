(* files: the runtime's sys_open with its flags, Sys's primitives,
 * In_channel and Out_channel; OCaml's output by mini-ml *)

let dir = "/tmp/mini-ml-files-test"
let ( / ) = Filename.concat
let read f = In_channel.with_open_bin f In_channel.input_all
(* not %S: mini-ml's Printf doesn't have it yet *)
let q s = "\"" ^ String.escaped s ^ "\""
let write f s = Out_channel.with_open_bin f (fun oc -> output_string oc s)

let () =
  (* Sys.command, its status *)
  Printf.printf "%d %d\n" (Sys.command ("rm -rf " ^ Filename.quote dir)) (Sys.command "exit 3");
  Printf.printf "%b\n" (Sys.file_exists dir);
  Sys.mkdir dir 0o755;
  Printf.printf "%b %b\n" (Sys.file_exists dir) (Sys.is_directory dir);

  (* written, read back; written again: emptied first *)
  let f = dir / "a.txt" in
  write f "one\ntwo\n";
  Printf.printf "%b %b %s\n" (Sys.file_exists f) (Sys.is_directory f) (q (read f));
  write f "1\n";
  Printf.printf "%s\n" (q (read f));

  (* appended; not emptied without Open_trunc; refused with Open_excl *)
  Out_channel.with_open_gen [ Open_wronly; Open_append; Open_creat ] 0o644 f (fun oc -> output_string oc "2\n3");
  Printf.printf "%s\n" (q (read f));
  Out_channel.with_open_gen [ Open_wronly; Open_creat ] 0o644 f (fun oc -> output_string oc "X");
  Printf.printf "%s\n" (q (read f));
  Printf.printf "%b\n"
    (try Out_channel.with_open_gen [ Open_wronly; Open_creat; Open_excl ] 0o644 f (fun _ -> false)
     with Sys_error _ -> true);
  Out_channel.with_open_gen [ Open_wronly; Open_creat; Open_excl ] 0o644 (dir / "b.txt") (fun oc -> output_string oc "b");

  (* by lines, the last without its newline; a file larger than a buffer *)
  In_channel.with_open_text f (fun ic ->
    let rec go n = match In_channel.input_line ic with Some l -> Printf.printf "[%s]" l; go (n + 1) | None -> n in
    Printf.printf " %d\n" (go 0));
  let big = String.init 10000 (fun i -> Char.chr (32 + (i mod 90))) in
  write (dir / "big") big;
  Printf.printf "%b\n" (read (dir / "big") = big);

  (* a channel's length and position; sought; an int in 4 bytes *)
  let oc = open_out_bin (dir / "seek") in
  output_string oc "0123456789";
  output_binary_int oc (-2);
  output_binary_int oc 0x12345678;
  Printf.printf "%d %d" (pos_out oc) (out_channel_length oc);
  seek_out oc 3; output_string oc "XY"; close_out oc;
  let ic = open_in_bin (dir / "seek") in
  Printf.printf " %d %c" (in_channel_length ic) (input_char ic);
  Printf.printf " %d %d" (pos_in ic) (in_channel_length ic);
  seek_in ic 2;
  Printf.printf " %s" (really_input_string ic 4);
  seek_in ic 10;
  let a = input_binary_int ic in
  let b = input_binary_int ic in
  Printf.printf " %d %x %b\n" a b (try ignore (input_binary_int ic); false with End_of_file -> true);
  close_in ic;
  Printf.printf "%b\n" (try ignore (in_channel_length stdin); false with Sys_error _ -> true);

  (* no such file *)
  Printf.printf "%b %b\n" (try ignore (read (dir / "none")); false with Sys_error _ -> true)
    (try ignore (Sys.is_directory (dir / "none")); false with Sys_error _ -> true);

  (* a directory's names; rename; remove *)
  let names d = let a = Sys.readdir d in Array.sort compare a; String.concat " " (Array.to_list a) in
  print_endline (names dir);
  Sys.rename f (dir / "c.txt");
  Printf.printf "%s %b %s\n" (names dir) (Sys.file_exists f) (q (read (dir / "c.txt")));
  let tmp = Filename.temp_file "mini-ml" ".tmp" in
  Printf.printf "%b\n" (Sys.file_exists tmp);
  Sys.remove tmp;
  Printf.printf "%b\n" (Sys.file_exists tmp);
  Array.iter (fun n -> Sys.remove (dir / n)) (Sys.readdir dir);
  Printf.printf "%d\n" (Array.length (Sys.readdir dir));
  Sys.rmdir dir;
  Printf.printf "%b %b\n" (Sys.file_exists dir) (Sys.getcwd () <> "")

(* the directory changed, and the processor's time *)
let () =
  let here = Sys.getcwd () in
  Sys.chdir "/tmp";
  Printf.printf "%s %b\n" (Sys.getcwd ()) (try Sys.chdir "/tmp/none/such"; false with Sys_error _ -> true);
  Sys.chdir here;
  let t = Sys.time () in
  let n = ref 0 in
  for i = 1 to 3_000_000 do n := !n + i land 3 done;
  Printf.printf "%b %b %b\n" (Sys.getcwd () = here) (t >= 0.0 && t < 5.0) (Sys.time () > t)

(* Open_append alone: a file written (OCaml's flag is O_APPEND | O_WRONLY) *)
let () =
  let f = "/tmp/mini-ml-appended" in
  (try Sys.remove f with Sys_error _ -> ());
  let add s = let oc = open_out_gen [ Open_append; Open_creat; Open_binary ] 0o644 f in Printf.fprintf oc "%s %d\n%s" s (String.length s) "x\000y"; close_out oc in
  add "one"; add "two";
  print_endline (q (read f));
  Sys.remove f
