(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-cat: Plan 9's cat (principia's utilities/files/cat.c; xix's
 * utilities/files/cat.ml is the author's in OCaml). Each file, or the
 * standard input when there is none, copied to the standard output,
 * 8 KB at a time. No option. Its errors are cat.c's words, with the
 * system's reason: so descriptors (FS.open_in_fd), not channels.
 *
 * cs-history:
 * cat is in the first edition of the Unix manual (1971): it reads
 * each file in sequence and writes it on the standard output, which
 * is concatenating them, hence the name. Its common use, one file on
 * the terminal, is the degenerate case.
 *
 * wib:
 * No option. Berkeley gave cat a -v to show the characters that do
 * not print, and -n to number the lines, -s, -e, -t. Rob Pike's talk
 * of 1983, "UNIX Style, or cat -v Considered Harmful", and his paper
 * with Brian Kernighan took it as the example of a tool that stops
 * doing one thing: showing odd characters is another program's work
 * (it would serve every program's output, not only a file's), and
 * numbering lines is one more. Plan 9's cat is the first edition's
 * again, some thirty lines of C; the cost is that someone must know the
 * other program's name.
 *
 * References: cat(1); Rob Pike and Brian Kernighan, "Program Design
 * in the UNIX Environment" (AT&T Bell Laboratories Technical Journal,
 * 1984). *)

type caps = < Cap.open_in; Cap.stdin; Cap.stdout; Cap.stderr >

(* cat.c's sysfatal: the message, which is also the process's last words *)
exception Fatal of string

let cat (caps : < Cap.stdout; .. >) (fd : Unix.file_descr) origin =
  let out = Console.stdout_fd caps and buf = Bytes.create 8192 in
  let rec copy () =
    match Unix.read fd buf 0 8192 with
    | 0 -> ()
    | n ->
        (match Unix.write out buf 0 n with
         | m when m = n -> copy ()
         | _ -> raise (Fatal (Printf.sprintf "write error copying %s: short write" origin))
         | exception Unix.Unix_error (e, _, _) -> raise (Fatal (Printf.sprintf "write error copying %s: %s" origin (Unix.error_message e))))
    | exception Unix.Unix_error (e, _, _) -> raise (Fatal (Printf.sprintf "error reading %s: %s" origin (Unix.error_message e))) in
  copy ()

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  try
    (match List.tl (Array.to_list argv) with
     | [] -> cat caps (Console.stdin_fd caps) "<stdin>"
     | files ->
         List.iter (fun file ->
           match FS.open_in_fd caps file with
           | fd -> Fun.protect ~finally:(fun () -> Unix.close fd) (fun () -> cat caps fd file)
           | exception Unix.Unix_error (e, _, _) -> raise (Fatal (Printf.sprintf "can't open %s: %s" file (Unix.error_message e)))) files);
    Exit.OK
  with Fatal msg -> Console.eprint caps ("cat: " ^ msg ^ "\n"); Exit.Err msg

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
