(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-gunzip: Plan 9's gunzip (principia's
 * utilities/archive/gzip/gunzip.c): each file uncompressed into one of
 * the current directory, its name without its .gz (a .tgz's: .tar);
 * no file, the standard input to the standard output. -c: to the
 * standard output; -t: nothing written, the names of what is inside
 * listed (-v: with each one's length and time); -v otherwise: what is
 * uncompressed to what; -T: the output given the time in the header.
 *
 * A file may be several gzip files end to end (cat a.gz b.gz), each
 * with its header and its trailer (Gzip's), all uncompressed in turn
 * into the one output. What follows the last one and is not one is
 * said and ignored: the bytes before it are good. When the first one
 * is bad, the output is removed.
 *
 * References: gzip(1) of Plan 9's manual; RFC 1952. *)

type caps = < Cap.open_in; Cap.open_out; Cap.readdir; Cap.stdin; Cap.stdout; Cap.stderr >

exception Usage
(* the message of a member that cannot be read *)
exception Bad of string

(* Plan 9's ctime: GMT here, as mini-date's *)
let ctime (t : float) =
  let tm : Unix.tm = Unix.gmtime t in
  Printf.sprintf "%s %s %2d %02d:%02d:%02d GMT %d\n" (String.sub "SunMonTueWedThuFriSat" (3 * tm.tm_wday) 3)
    (String.sub "JanFebMarAprMayJunJulAugSepOctNovDec" (3 * tm.tm_mon) 3) tm.tm_mday tm.tm_hour tm.tm_min tm.tm_sec (tm.tm_year + 1900)

(* a member: its name, its time, its bytes, and where the next one starts *)
let member (s : string) (pos : int) =
  let p = ref pos in
  let get1 () = if !p >= String.length s then raise (Bad "unexpected eof reading file information") else (incr p; Char.code s.[!p - 1]) in
  (* (hi, lo): an int has 31 bits where mini-ml builds for arm *)
  let get4 () = let a = get1 () in let b = get1 () in let c = get1 () in let d = get1 () in (d lsl 8) lor c, (b lsl 8) lor a in
  if get1 () <> 0x1f || get1 () <> 0x8b then raise (Bad "bad gzip file magic");
  if get1 () <> 8 then raise (Bad "unknown compression type");
  let flag = get1 () in
  let reserved = flag land lnot 0x1f <> 0 in
  let hi, lo = get4 () in
  let mtime = float_of_int hi *. 65536. +. float_of_int lo in
  ignore (get1 ()); ignore (get1 ());
  if flag land 4 <> 0 then for _i = 1 to get1 () do ignore (get1 ()) done;
  let zstring () = let b = Buffer.create 32 in let rec go () = match get1 () with 0 -> Buffer.contents b | c -> Buffer.add_char b (Char.chr c); go () in go () in
  let name = if flag land 8 <> 0 then zstring () else "<unnamed file>" in
  if flag land 16 <> 0 then ignore (zstring ());
  if flag land 2 <> 0 then (ignore (get1 ()); ignore (get1 ()));
  let data, next = try Zlib.inflate_blocks_at !p s with Zlib.Corrupt m | Invalid_argument m -> raise (Bad ("inflate failed: " ^ m)) in
  p := next;
  if get4 () <> Zlib.crc32_halves data ~pos:0 ~len:(String.length data) then raise (Bad "crc mismatch");
  let hi, lo = get4 () in
  (* (the length's low 32 bits, as the file has them) *)
  let n = String.length data in
  if (hi, lo) <> ((n lsr 16) land 0xffff, n land 0xffff) then
    raise (Bad (Printf.sprintf "bad output length: expected %d got %.0f" n (float_of_int hi *. 65536. +. float_of_int lo)));
  reserved, name, mtime, data, !p

let read_all fd =
  let b = Buffer.create 65536 and chunk = Bytes.create 65536 in
  let rec go () = match Unix.read fd chunk 0 65536 with 0 -> Buffer.contents b | n -> Buffer.add_subbytes b chunk 0 n; go () in
  go ()

type options = { verbose : bool; table : bool; settimes : bool }

(* the members of [s] one after the other into [ofd] (None: -t); false
 * at a bad one. [delfile]: the output to remove when the first is bad *)
let gunzip (caps : < caps; .. >) o ~infile ~ofile ~delfile (ofd : Unix.file_descr option) (s : string) =
  let rec go pos =
    if pos >= String.length s then true
    else match member s pos with
      | exception Bad m ->
          if pos > 0 then Console.eprint caps (Printf.sprintf "gunzip: %s: corrupted data after byte %d ignored\n" infile pos)
          else begin
            Console.eprint caps (Printf.sprintf "gunzip: %s: %s\n" infile m);
            Option.iter (fun f -> Console.eprint caps (Printf.sprintf "gunzip: removing output file %s\n" f); FS.remove_any caps f) delfile
          end;
          false
      | reserved, name, mtime, data, next ->
          if reserved then Console.eprint caps "gunzip: reserved flags set, data may not be decompressed correctly\n";
          if not o.table && o.verbose then Console.eprint caps (Printf.sprintf "extracting %s to %s\n" name ofile);
          Option.iter (fun fd -> ignore (Unix.write_substring fd data 0 (String.length data))) ofd;
          if o.table then
            Console.print caps (if o.verbose then Printf.sprintf "%-32s %10d %s" name (String.length data) (ctime mtime) else name ^ "\n")
          else if o.settimes && mtime <> 0. && delfile <> None then Sys_plan9.set_mtime caps ofile mtime;
          go next in
  go 0

(* one file; false when it could not be *)
let gunzipf (caps : < caps; .. >) o ~stdout file =
  let fail fmt = Printf.ksprintf (fun s -> Console.eprint caps s; false) fmt in
  match FS.open_in_fd caps file with
  | exception Unix.Unix_error (e, _, _) -> fail "gunzip: can't open %s: %s\n" file (Unix.error_message e)
  | ifd ->
      let s = Fun.protect ~finally:(fun () -> Unix.close ifd) (fun () -> read_all ifd) in
      if String.length s < 3 || String.sub s 0 3 <> "\x1f\x8b\x08" then fail "gunzip: %s is not a gzip deflate file\n" file
      else if o.table then gunzip caps o ~infile:file ~ofile:"" ~delfile:None None s
      else if stdout then gunzip caps o ~infile:file ~ofile:"<stdout>" ~delfile:None (Some (Console.stdout_fd caps)) s
      else
        let base = Filename.basename file in
        let ofile =
          if Filename.check_suffix base ".gz" && base <> ".gz" then Some (Filename.chop_suffix base ".gz")
          else if Filename.check_suffix base ".tgz" then Some (Filename.chop_suffix base ".tgz" ^ ".tar")
          else if base = file then None
          else Some base in
        match ofile with
        | None -> fail "gunzip: can't overwrite %s\n" file
        | Some ofile ->
            match FS.open_out_fd caps ofile 0o666 with
            | exception Unix.Unix_error (e, _, _) -> fail "gunzip: can't create %s: %s\n" ofile (Unix.error_message e)
            | ofd -> Fun.protect ~finally:(fun () -> Unix.close ofd) (fun () ->
                gunzip caps o ~infile:file ~ofile ~delfile:(Some ofile) (Some ofd) s)

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  let verbose = ref false and table = ref false and settimes = ref false and stdout = ref false in
  try
    let rec options = function
      | "--" :: rest -> rest
      | a :: rest when String.length a > 1 && a.[0] = '-' ->
          String.iteri (fun k c -> if k > 0 then match c with
            | 'v' -> verbose := true | 'c' -> stdout := true | 't' -> table := true | 'T' -> settimes := true | 'D' -> ()
            | _ -> raise Usage) a;
          options rest
      | rest -> rest in
    let ok = match options (List.tl (Array.to_list argv)) with
      | [] ->
          let o = { verbose = !verbose; table = !table; settimes = false } in
          gunzip caps o ~infile:"<stdin>" ~ofile:"<stdout>" ~delfile:None
            (if !table then None else Some (Console.stdout_fd caps)) (read_all (Console.stdin_fd caps))
      | files ->
          let o = { verbose = !verbose; table = !table; settimes = !settimes && not !stdout } in
          List.fold_left (fun ok f -> gunzipf caps o ~stdout:!stdout f && ok) true files in
    if ok then Exit.OK else Exit.Err "errors"
  with Usage -> Console.eprint caps "usage: gunzip [-ctvTD] [file ....]\n"; Exit.Err "usage"

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
