(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-gzip: Plan 9's gzip (principia's utilities/archive/gzip/gzip.c):
 * each file compressed into one of the current directory, its name
 * with .gz after (a .tar's: .tgz), the file itself kept; no file, the
 * standard input to the standard output. -c: to the standard output;
 * -v: what is compressed to what, on the standard error; -1 to -9,
 * the level, taken.
 *
 * The file is RFC 1952's, deflate's blocks in an envelope (Zlib.gzip):
 *
 *    1f 8b 08 | flags | mtime (4) | 00 03 | name 00 | blocks | crc32 | length
 *
 * the flags saying whether a name follows (a file's, not the standard
 * input's), the time the file's (the standard input's: now), 03 Unix
 * as the system (gzip.h's GZOSINFERNO), the CRC-32 and the length of
 * the bytes before compression, each four bytes, the low first.
 *
 * wib:
 * The header and the trailer are gzip.c's bytes, the blocks are not:
 * Zlib's deflate writes fixed codes only and ignores the level, where
 * libflate's writes a block's own codes. Any gunzip reads both; ours
 * are bigger (Zlib.mli).
 *
 * cs-history:
 * Jean-loup Gailly wrote gzip in 1992 for the GNU project, to replace
 * Unix's compress, whose LZW was patented; Mark Adler wrote its
 * decompressor. Plan 9's is Russ Cox's, over libflate.
 *
 * References: gzip(1) of Plan 9's manual; P. Deutsch, RFC 1952, "GZIP
 * file format specification version 4.3" (1996). *)

type caps = < Cap.open_in; Cap.open_out; Cap.readdir; Cap.stdin; Cap.stdout; Cap.stderr >

exception Usage

(* a time's two halves of 16 bits: Zlib.gzip's *)
let halves (t : float) = int_of_float (t /. 65536.), int_of_float (Float.rem t 65536.)

(* everything on [fd] *)
let read_all fd =
  let b = Buffer.create 65536 and chunk = Bytes.create 65536 in
  let rec go () = match Unix.read fd chunk 0 65536 with 0 -> Buffer.contents b | n -> Buffer.add_subbytes b chunk 0 n; go () in
  go ()

let write_all fd s = ignore (Unix.write_substring fd s 0 (String.length s))

(* one file; false when it could not be *)
let gzipf (caps : < caps; .. >) ~verbose ~stdout file =
  let fail fmt = Printf.ksprintf (fun s -> Console.eprint caps s; false) fmt in
  match FS.open_in_fd caps file with
  | exception Unix.Unix_error (e, _, _) -> fail "gzip: can't open %s: %s\n" file (Unix.error_message e)
  | ifd ->
      Fun.protect ~finally:(fun () -> Unix.close ifd) (fun () ->
        let d : Sys_plan9.dir = Sys_plan9.dirstat caps file in
        if d.qid_type land Sys_plan9.dmdir <> 0 then fail "gzip: can't compress a directory\n"
        else
          let base = Filename.basename file in
          let ofile =
            if stdout then "<stdout>"
            else if Filename.check_suffix base ".tar" && base <> ".tar" then Filename.chop_suffix base ".tar" ^ ".tgz"
            else base ^ ".gz" in
          match if stdout then Console.stdout_fd caps else FS.open_out_fd caps ofile 0o666 with
          | exception Unix.Unix_error (e, _, _) -> fail "gzip: can't open %s: %s\n" ofile (Unix.error_message e)
          | ofd ->
              if verbose then Console.eprint caps (Printf.sprintf "compressing %s to %s\n" file ofile);
              write_all ofd (Zlib.gzip (Some file) (halves d.mtime) (read_all ifd));
              if not stdout then Unix.close ofd;
              true)

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  let verbose = ref false and stdout = ref false in
  try
    let rec options = function
      | "--" :: rest -> rest
      | a :: rest when String.length a > 1 && a.[0] = '-' ->
          String.iteri (fun k c -> if k > 0 then match c with
            | 'v' -> verbose := true | 'c' -> stdout := true | 'D' | '1' .. '9' -> () | _ -> raise Usage) a;
          options rest
      | rest -> rest in
    match options (List.tl (Array.to_list argv)) with
    | [] ->
        write_all (Console.stdout_fd caps) (Zlib.gzip None (halves (Float.round (Unix.time ()))) (read_all (Console.stdin_fd caps)));
        Exit.OK
    | files ->
        let ok = List.fold_left (fun ok f -> gzipf caps ~verbose:!verbose ~stdout:!stdout f && ok) true files in
        if ok then Exit.OK else Exit.Err "errors"
  with Usage -> Console.eprint caps "usage: gzip [-vcD] [-1-9] [file ...]\n"; Exit.Err "usage"

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
