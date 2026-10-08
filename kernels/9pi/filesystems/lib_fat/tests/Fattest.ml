(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* Fat on the host, for fat.sh: an image's file system changed by one
 * command (fattest IMAGE ls|cat|create|mkdir|write|trunc|rm|mv|touch|chmod PATH...). *)
let () =
  let image = Sys.argv.(1) in
  let fd = Unix.openfile image [ Unix.O_RDWR ] 0 in
  let read at n = ignore (Unix.lseek fd at Unix.SEEK_SET); let b = Bytes.create n in
    let rec go o = if o = n then o else match Unix.read fd b o (n - o) with 0 -> o | k -> go (o + k) in Bytes.sub_string b 0 (go 0) in
  let write at s = ignore (Unix.lseek fd at Unix.SEEK_SET); ignore (Unix.write_substring fd s 0 (String.length s)) in
  Fat.clock := Unix.time;
  let t = Fat.make read (Some write) in
  let rec find (d : Fat.entry) = function
    | [] -> d
    | name :: more -> find (List.find (fun (e : Fat.entry) -> String.lowercase_ascii e.name = String.lowercase_ascii name) (Fat.entries t d)) more in
  let path p = List.filter (fun s -> s <> "") (String.split_on_char '/' p) in
  let parent p = let l = path p in find (Fat.root t) (List.rev (List.tl (List.rev l))), List.nth l (List.length l - 1) in
  match Array.to_list Sys.argv |> List.tl |> List.tl with
  | [ "ls"; p ] -> List.iter (fun (e : Fat.entry) -> Printf.printf "%s%s %d\n" e.name (if e.is_dir then "/" else "") e.size) (Fat.entries t (find (Fat.root t) (path p)))
  | [ "cat"; p ] -> let e = find (Fat.root t) (path p) in print_string (Fat.read t e 0 e.size)
  | [ "create"; p ] -> let d, n = parent p in ignore (Fat.create t d n false)
  | [ "mkdir"; p ] -> let d, n = parent p in ignore (Fat.create t d n true)
  | [ "write"; p; off; file ] -> let e = find (Fat.root t) (path p) in
      let data = In_channel.with_open_bin file In_channel.input_all in
      (* in pieces, as a server's writes come *)
      let rec go e o = if o < String.length data then (let n = min 8192 (String.length data - o) in go (Fat.write t e (int_of_string off + o) (String.sub data o n)) (o + n)) in go e 0
  | [ "trunc"; p ] -> ignore (Fat.truncate t (find (Fat.root t) (path p)))
  | [ "rm"; p ] -> Fat.remove t (find (Fat.root t) (path p))
  | [ "mv"; p; name ] -> let d, _ = parent p in ignore (Fat.rename t d (find (Fat.root t) (path p)) name)
  | [ "touch"; p; secs ] -> ignore (Fat.set_mtime t (find (Fat.root t) (path p)) (float_of_string secs))
  | [ "chmod"; p; ro ] -> ignore (Fat.set_read_only t (find (Fat.root t) (path p)) (ro = "ro"))
  | _ -> prerr_endline "usage"; exit 2
