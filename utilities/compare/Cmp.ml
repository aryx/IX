(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-cmp: Plan 9's cmp (principia's utilities/compare/misc/cmp.c):
 * two files' bytes compared; nothing said and all is well when they
 * are the same, else the first byte that differs (counted from 1), or
 * which file ended first. -l: every byte that differs, its number and
 * the two bytes; -L: the line too; -s: nothing said, the status only.
 * After the names, where to start in each, in bytes. *)

type caps = < Cap.open_in; Cap.stdout; Cap.stderr >

exception Usage
(* said (unless -s), and the process's last words *)
exception Ended of string * string

(* as many bytes as asked, or fewer at the file's end *)
let fill fd buf =
  let rec go o = if o = Bytes.length buf then o else match Unix.read fd buf o (Bytes.length buf - o) with 0 -> o | n -> go (o + n) in
  go 0

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  let silent = ref false and every = ref false and lines = ref false in
  try
    let rec options = function
      | "--" :: rest -> rest
      | a :: rest when String.length a > 1 && a.[0] = '-' ->
          String.iteri (fun k c -> if k > 0 then match c with 's' -> silent := true | 'l' -> every := true | 'L' -> lines := true | _ -> raise Usage) a;
          options rest
      | rest -> rest in
    match options (List.tl (Array.to_list argv)) with
    | name1 :: name2 :: offsets when List.length offsets <= 2 ->
        let opened name = try FS.open_in_fd caps name with Unix.Unix_error (e, _, _) -> raise (Ended (Printf.sprintf "%s: %s\n" name (Unix.error_message e), "open")) in
        let f1 = opened name1 in
        let f2 = opened name2 in
        List.iter2 (fun (fd, name) o ->
          let o = match int_of_string_opt o with Some o when o >= 0 -> o | _ -> raise Usage in
          try ignore (Unix.lseek fd o Unix.SEEK_SET)
          with Unix.Unix_error (e, _, _) -> raise (Ended (Printf.sprintf "cmp: %s: seek by %d: %s\n" name o (Unix.error_message e), "seek")))
          (List.filteri (fun k _ -> k < List.length offsets) [ f1, name1; f2, name2 ]) offsets;
        let b1 = Bytes.create 65536 and b2 = Bytes.create 65536 in
        (* [nc]: the bytes compared so far; [line]: the first file's line there *)
        let rec go nc line =
          let n1 = fill f1 b1 and n2 = fill f2 b2 in
          let n = min n1 n2 in
          let line = ref line in
          for i = 0 to n - 1 do
            if Bytes.get b1 i = '\n' then incr line;
            if Bytes.get b1 i <> Bytes.get b2 i then begin
              if !silent then raise (Ended ("", "differ"));
              if not !every then
                raise (Ended (Printf.sprintf "%s %s differ: char %d%s\n" name1 name2 (nc + i + 1) (if !lines then Printf.sprintf " line %d" !line else ""), "differ"));
              Console.print caps (Printf.sprintf "%6d 0x%02x 0x%02x\n" (nc + i + 1) (Char.code (Bytes.get b1 i)) (Char.code (Bytes.get b2 i)))
            end
          done;
          if n1 <> n2 then raise (Ended (Printf.sprintf "EOF on %s after %d bytes\n" (if n1 < n2 then name1 else name2) (nc + n), "EOF"))
          else if n > 0 then go (nc + n) !line in
        go 0 1;
        Exit.OK
    | _ -> raise Usage
  with
  | Usage -> Console.print caps "usage: cmp [-lLs] file1 file2 [offset1 [offset2] ]\n"; Exit.Err "usage"
  | Ended (said, words) ->
      if not !silent then (if words = "open" || words = "seek" then Console.eprint caps said else Console.print caps said);
      Exit.Err words

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
