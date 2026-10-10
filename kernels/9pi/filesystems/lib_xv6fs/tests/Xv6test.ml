(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* Xv6fs on the host, for xv6fs.sh: an image's file system changed by
 * one command (xv6test IMAGE format BLOCKS BSIZE | ls|cat|create|mkdir|write|trunc|rm|mv|touch|mtime PATH...). *)
let () =
  let image = Sys.argv.(1) in
  let fd = Unix.openfile image [ Unix.O_RDWR; Unix.O_CREAT ] 0o644 in
  let read at n = ignore (Unix.lseek fd at Unix.SEEK_SET); let b = Bytes.create n in
    let rec go o = if o = n then o else match Unix.read fd b o (n - o) with 0 -> o | k -> go (o + k) in Bytes.sub_string b 0 (go 0) in
  let write at s = ignore (Unix.lseek fd at Unix.SEEK_SET); ignore (Unix.write_substring fd s 0 (String.length s)) in
  let args = Array.to_list Sys.argv |> List.tl |> List.tl in
  match args with
  | [ "format"; blocks; bsize ] -> ignore (Xv6fs.format read write (int_of_string blocks) (int_of_string bsize) 200)
  | _ ->
    let t = Xv6fs.make read (Some write) in
    let path p = List.filter (fun s -> s <> "") (String.split_on_char '/' p) in
    let find l = List.fold_left (fun d n -> match Xv6fs.lookup t d n with Some i -> i | None -> failwith (n ^ ": does not exist")) Xv6fs.root l in
    let parent p = let l = path p in find (List.rev (List.tl (List.rev l))), List.nth l (List.length l - 1) in
    match args with
    | [ "ls"; p ] -> let d = find (path p) in List.iter (fun (n, i) -> Printf.printf "%s%s %d\n" n (if Xv6fs.kind t i = Xv6fs.Dir then "/" else "") (Xv6fs.size t i)) (Xv6fs.entries t d)
    | [ "cat"; p ] -> let i = find (path p) in print_string (Xv6fs.read t i 0 (Xv6fs.size t i))
    | [ "create"; p ] -> let d, n = parent p in ignore (Xv6fs.create t d n Xv6fs.File)
    | [ "mkdir"; p ] -> let d, n = parent p in ignore (Xv6fs.create t d n Xv6fs.Dir)
    | [ "write"; p; off; file ] ->
        let i = find (path p) in
        let data = In_channel.with_open_bin file In_channel.input_all in
        let rec go o = if o < String.length data then (let n = min 8192 (String.length data - o) in Xv6fs.write t i (int_of_string off + o) (String.sub data o n); go (o + n)) in go 0
    | [ "trunc"; p ] -> Xv6fs.truncate t (find (path p))
    | [ "rm"; p ] -> let d, n = parent p in Xv6fs.remove t d n
    | [ "mv"; p; name ] -> let d, n = parent p in Xv6fs.rename t d n name
    | [ "touch"; p; secs ] -> Xv6fs.set_mtime t (find (path p)) (int_of_string secs)
    | [ "mtime"; p ] -> Printf.printf "%d\n" (Xv6fs.mtime t (find (path p)))
    | _ -> prerr_endline "usage"; exit 2
