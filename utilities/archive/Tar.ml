(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-tar: Plan 9's tar (principia's utilities/archive/tar/tar.c), its
 * archives byte for byte: files and directories, whole trees, in one
 * file, and back.
 *
 *    tar cf a.tar dir file    a new archive of them (c), in a file (f)
 *    tar rf a.tar more        added at the end of one (r)
 *    tar tvf a.tar            what is in it (t), each line long (v)
 *    tar xf a.tar [name...]   taken out (x): all, or what is under names
 *
 * The first argument is the letters, a dash or not; f, u and g take
 * the letters' rest or the next argument (the archive, an owner's
 * number, a group's). No f: the standard input or output. z:
 * compressed by gzip, and when reading, so is a .tgz or .tar.gz. k: a
 * file that is there kept; T: the archive's times and modes given to
 * what is taken out; R: names from / kept as they are (else under the
 * current directory); P: the old format (no owners' names, names of
 * 100 characters at most); s: past a bad header to the next good one;
 * v with c, r or x: the names on the standard error.
 *
 * The archive is blocks of 512 bytes: for each file a header, then
 * its bytes, the last block's rest zeros; two zero blocks end it, and
 * it is written in records of 20 blocks, the last one filled with
 * zeros (a tape's records once):
 *
 *    | f1's header | f1's bytes | sub/'s header | sub/x's | x's bytes | 0 | 0 | 0...
 *
 * A header is text, each number in octal: the name (100 bytes), the
 * mode, the owners' numbers, the length, the time, the checksum (the
 * sum of the header's bytes, its own field counted as spaces), the
 * type (5: a directory, its name ending with /), then POSIX's ustar
 * part: the owners' names, and a prefix of 155 bytes for a longer
 * name, split at a slash.
 *
 * wib:
 * The archive is read and written in memory, whole, where tar.c reads
 * and writes a record at a time: an archive must fit. -z is gzip's
 * only (Zlib's, in the process: tar.c runs gzip, compress or bzip2 in
 * a pipe). tar.c's tv prints its modes by %M, which its main leaves
 * uninstalled (an XXX), and its lines come out garbled: here they are
 * what it meant (mini-ls's modes). -i is taken and does nothing: a
 * read error ends the program.
 *
 * cs-history:
 * tar, the tape archiver, came with Unix's seventh edition (1979),
 * after tp, and its header of 1979 is still the start of every .tar;
 * POSIX (1988) added the ustar part. Plan 9's is Geoff Collyer's.
 *
 * References: tar(1) of Plan 9's manual; IEEE Std 1003.1's pax, the
 * ustar format. *)

type caps = < Cap.open_in; Cap.open_out; Cap.readdir; Cap.stdin; Cap.stdout; Cap.stderr >

exception Usage
(* sysfatal: the words said, and the process's last ones *)
exception Fatal of string
(* past the archive's last record (tar.c's refill's nil) *)
exception End

let tblock = 512
let record = 20 * tblock

type verb = Toc | Xtract | Replace

type options = {
  argv0 : string; say : string -> unit;
  mutable verb : verb option; mutable create : bool; mutable verbose : bool; mutable compress : bool;
  mutable file : string option; mutable keep : bool; mutable settime : bool; mutable posix : bool;
  mutable relative : bool; mutable resync : bool; mutable uid : int; mutable gid : int;
}

let arname o = match o.file with Some f -> f | None -> "archive"

let write_all fd s = ignore (Unix.write_substring fd s 0 (String.length s))

let read_all fd =
  let b = Buffer.create 65536 and chunk = Bytes.create 65536 in
  let rec go () = match Unix.read fd chunk 0 65536 with 0 -> Buffer.contents b | n -> Buffer.add_subbytes b chunk 0 n; go () in
  go ()

(* a number's octal digits; a float: a time is past an int's 31 bits
 * where mini-ml builds for arm *)
let rec digits (v : float) acc =
  let q = Float.trunc (v /. 8.) in
  let acc = string_of_int (int_of_float (v -. (q *. 8.))) ^ acc in
  if q = 0. then acc else digits q acc
(* %wo: [w] characters, spaces before *)
let octal w v = let s = digits v "" in String.make (max 0 (w - String.length s)) ' ' ^ s

(* [n] bytes of [s] from [pos], up to the first NUL *)
let field (s : string) pos n = match String.index_from_opt s pos '\000' with Some k when k < pos + n -> String.sub s pos (k - pos) | _ -> String.sub s pos n

(* strtoul's octal: spaces skipped, then the digits *)
let strtoul (s : string) pos =
  let p = ref pos and v = ref 0. in
  while !p < String.length s && s.[!p] = ' ' do incr p done;
  while !p < String.length s && s.[!p] >= '0' && s.[!p] <= '7' do v := !v *. 8. +. Float.of_int (Char.code s.[!p] - 48); incr p done;
  !v

(* tar.c's hdrotoull: spaces and NULs skipped, then octal; a field
 * without digits said, and [err] *)
let number o (s : string) pos n ~name ~what ~err =
  let p = ref pos in
  while !p < pos + n && (s.[!p] = ' ' || s.[!p] = '\000') do incr p done;
  if !p < pos + n && s.[!p] >= '0' && s.[!p] <= '9' then strtoul s !p
  else begin
    if !p >= pos + n then o.say (Printf.sprintf "%s: %s: empty %s in header\n" o.argv0 name what)
    else o.say (Printf.sprintf "%s: %s: %s: non-numeric %s in header\n" o.argv0 name (field s !p (pos + n - !p)) what);
    err
  end

(* the sum of the header's bytes, its checksum's field as spaces *)
let chksum (h : string) =
  let sum = ref 0 in
  String.iteri (fun k c -> sum := !sum + (if k >= 148 && k < 156 then 32 else Char.code c)) h;
  !sum

(*****************************************************************************)
(* The header *)
(*****************************************************************************)

(* the name, the ustar prefix's before it *)
let name (h : string) =
  let n = field h 0 100 in
  if h.[345] = '\000' || field h 257 6 <> "ustar" then n else field h 345 155 ^ "/" ^ n

let is_dir h =
  let n = name h in
  h.[156] = '5' || (n <> "" && n.[String.length n - 1] = '/') || int_of_float (strtoul h 100) land 0o170000 = 0o40000
let is_link h = h.[156] = '1' || h.[156] = '2' || h.[156] = 's'

(* the length the header says, and the bytes the archive has of it
 * (GNU's lengths in binary read too) *)
let hdrsize o h =
  if h.[124] = '\xff' then (o.say (Printf.sprintf "%s: %s: negative length, which is insane\n" o.argv0 (name h)); 0)
  else if h.[124] = '\x80' then String.fold_left (fun v c -> (v lsl 8) lor Char.code c) 0 (String.sub h 127 8)
  else int_of_float (number o h 124 12 ~name:(name h) ~what:"size" ~err:0.)
let arsize o h = if is_dir h || is_link h then 0 else hdrsize o h
let nblocks bytes = (bytes + tblock - 1) / tblock

(* tar.c's putfullname: the name in its field, or split at the slash
 * that leaves the most to the prefix; false when it cannot fit *)
let put_name o (b : Bytes.t) name =
  let n = String.length name in
  let put pos s = Bytes.blit_string s 0 b pos (String.length s) in
  if n <= 100 then (put 0 name; true)
  else if not o.posix || n > 256 then (o.say (Printf.sprintf "%s: name too long for tar header: %s\n" o.argv0 name); false)
  else
    let rec split k = match String.rindex_from_opt name k '/' with
      | Some s when s <= 155 && n - 1 - s <= 100 -> Some s
      | Some s when s > 0 -> split (s - 1)
      | _ -> None in
    match split (n - 1) with
    | None -> o.say (Printf.sprintf "%s: name can't be split to fit tar header: %s\n" o.argv0 name); false
    | Some s -> put 345 (String.sub name 0 s); put 0 (String.sub name (s + 1) (n - s - 1)); true

(* tar.c's mkhdr: its sprint's fields, each with the NUL after it
 * that the next field overwrites *)
let header o (d : Sys_plan9.dir) file =
  let b = Bytes.make tblock '\000' in
  let put pos s = Bytes.blit_string s 0 b pos (String.length s) in
  let trunc s = if String.length s > 32 then String.sub s 0 32 else s in
  let dir = d.qid_type land Sys_plan9.dmdir <> 0 in
  put 100 (octal 6 (Float.of_int (d.perm land 0o777)) ^ " ");
  put 108 (octal 6 (Float.of_int o.uid) ^ " ");
  put 116 (octal 6 (Float.of_int o.gid) ^ " ");
  put 124 (octal 11 (Float.of_int d.length) ^ " ");
  put 136 (octal 11 d.mtime ^ " ");
  if dir then Bytes.set b 156 '5';
  let ok = put_name o b (if dir then file ^ "/" else file) in
  if o.posix then (put 257 "ustar"; put 263 "00"; put 265 (trunc d.uid); put 297 (trunc d.gid));
  put 148 (octal 6 (Float.of_int (chksum (Bytes.to_string b))) ^ "\000");
  if ok then Some (Bytes.to_string b) else None

(*****************************************************************************)
(* c and r *)
(*****************************************************************************)

(* a file to the archive, a directory with what is under it *)
let rec add (caps : < caps; .. >) o (out : Buffer.t) file =
  let path = if file <> "" && file.[0] = '#' then "./" ^ file else file in
  match Sys_plan9.dirstat caps path with
  | exception Unix.Unix_error (e, _, _) -> o.say (Printf.sprintf "%s: can't open %s: %s\n" o.argv0 file (Unix.error_message e))
  | (d : Sys_plan9.dir) when d.qid_type land Sys_plan9.dmdir <> 0 ->
      Option.iter (fun h ->
        Buffer.add_string out h;
        match Sys_plan9.dirread caps path with
        | entries -> List.iter (fun (e : Sys_plan9.dir) -> add caps o out (file ^ "/" ^ e.name)) entries
        | exception Unix.Unix_error (e, _, _) -> o.say (Printf.sprintf "%s: dirreadall %s: %s\n" o.argv0 file (Unix.error_message e)))
        (header o d file)
  | (d : Sys_plan9.dir) ->
      match FS.open_in_fd caps path with
      | exception Unix.Unix_error (e, _, _) -> o.say (Printf.sprintf "%s: can't open %s: %s\n" o.argv0 file (Unix.error_message e))
      | fd ->
          let data = Fun.protect ~finally:(fun () -> Unix.close fd) (fun () -> read_all fd) in
          Option.iter (fun h ->
            Buffer.add_string out h;
            (* the blocks the length says, what the file is short of them zeros *)
            let bytes = nblocks d.length * tblock in
            let data = if String.length data > bytes then String.sub data 0 bytes else data in
            Buffer.add_string out data;
            Buffer.add_string out (String.make (bytes - String.length data) '\000');
            if o.verbose then o.say (file ^ "\n"))
            (header o d file)

(*****************************************************************************)
(* t and x *)
(*****************************************************************************)

(* the archive's [i]th block: zeros after its end inside its last
 * record, End past that (tar.c's refill, its records of [size]) *)
let block o (s : string) ~size i =
  let off = i * tblock and len = String.length s in
  let start = off / size * size in
  if start >= len then (if len mod size = 0 then raise (Fatal ("unexpected EOF reading archive " ^ arname o)) else raise End)
  else if len - start < size && (len - start) mod tblock <> 0 then raise (Fatal ("partial block read from archive " ^ arname o))
  else if off + tblock <= len then String.sub s off tblock
  else if off >= len then String.make tblock '\000'
  else String.sub s off (len - off) ^ String.make (off + tblock - len) '\000'

(* [name] one of [pats], or under one *)
let matches name pats =
  pats = [] ||
  let name = FS.cleanname name in
  List.exists (fun p -> let p = FS.cleanname p in let n = String.length p in
    String.length name >= n && String.sub name 0 n = p && (String.length name = n || name.[n] = '/')) pats

(* %M: Plan 9's dirmodefmt, of a directory or not (the only bit an
 * archive gives) *)
let mode_string ~dir m =
  let rwx k = let b = (m lsr k) land 7 in (if b land 4 <> 0 then "r" else "-") ^ (if b land 2 <> 0 then "w" else "-") ^ (if b land 1 <> 0 then "x" else "-") in
  (if dir then "d" else "-") ^ "-" ^ rwx 6 ^ rwx 3 ^ rwx 0

(* Plan 9's ctime: GMT here, as mini-date's *)
let ctime (t : float) =
  let tm : Unix.tm = Unix.gmtime t in
  Printf.sprintf "%s %s %2d %02d:%02d:%02d GMT %d\n" (String.sub "SunMonTueWedThuFriSat" (3 * tm.tm_wday) 3)
    (String.sub "JanFebMarAprMayJunJulAugSepOctNovDec" (3 * tm.tm_mon) 3) tm.tm_mday tm.tm_hour tm.tm_min tm.tm_sec (tm.tm_year + 1900)

let exists (caps : < caps; .. >) path = match Sys_plan9.dirstat caps path with _ -> true | exception Unix.Unix_error _ -> false

(* tar.c's openfname: the file (its descriptor) or the directory (None)
 * made, after its parents when they are missing; None when not made *)
let make (caps : < caps; .. >) o h fname ~dir ~mode (said : string option ref) =
  let fname = FS.cleanname fname in
  let cant name err =
    (* a directory said once, and not one under it said already *)
    let under last = last = name || (String.length last > String.length name && String.sub last 0 (String.length name) = name
                                     && last.[String.length name] = '/') in
    if not (dir && (match !said with Some last -> under last | None -> false)) then begin
      if dir then said := Some name;
      o.say (Printf.sprintf "%s: can't create %s: %s\n" o.argv0 name err)
    end in
  (* (a directory that is there: not made, and nothing said) *)
  let create () =
    if dir then (if exists caps fname then None else (FS.mkdir caps fname 0o777; Some None))
    else Some (Some (FS.open_out_fd caps fname mode)) in
  let parents () =
    String.iteri (fun k c -> if c = '/' && k > 0 then
      let p = String.sub fname 0 k in
      if not (exists caps p) then try FS.mkdir caps p 0o777 with Unix.Unix_error (e, _, _) -> cant p (Unix.error_message e)) fname in
  if is_link h then (o.say (Printf.sprintf "%s: can't make (sym)link %s\n" o.argv0 fname); None)
  else if h.[156] = '6' then (o.say (Printf.sprintf "%s: can't make fifo %s\n" o.argv0 fname); None)
  else if o.keep && exists caps fname then None
  else
    let made = try create () with Unix.Unix_error _ ->
      parents ();
      try create () with Unix.Unix_error (e, _, _) -> (if not dir || not (exists caps fname) then cant fname (Unix.error_message e)); None in
    if made <> None && o.verbose then o.say (fname ^ "\n");
    Option.map (fun fd -> fname, fd) made

(* one member: listed, or taken out *)
let extract1 (caps : < caps; .. >) o h fname ~(data : int -> string) said =
  let mtime = number o h 136 12 ~name:fname ~what:"mtime" ~err:0. in
  let bytes = hdrsize o h and dir = is_dir h in
  let mode = int_of_float (number o h 100 8 ~name:fname ~what:"mode" ~err:0.) land 0o777 in
  let mode = if dir then mode lor 0o700 else mode in
  let n = if is_link h || h.[156] = '6' then 0 else nblocks (arsize o h) in
  let fname = if o.relative && fname <> "" && fname.[0] = '/' then "." ^ fname
    else if o.relative && fname <> "" && fname.[0] = '#' then "./" ^ fname else fname in
  let out =
    if o.verb = Some Xtract then make caps o h fname ~dir ~mode said
    else begin
      let t = ctime mtime in
      Console.print caps (if o.verbose then Printf.sprintf "%s %8d %s %s %s\n" (mode_string ~dir mode) bytes (String.sub t 4 12) (String.sub t 24 4) fname
                          else fname ^ "\n");
      flush (Console.stdout caps);
      None
    end in
  let left = ref (if n = 0 then 0 else bytes) in
  for k = 0 to n - 1 do
    let b = data k in
    let w = min tblock !left in
    Option.iter (fun (_, fd) -> Option.iter (fun fd -> write_all fd (String.sub b 0 w)) fd) out;
    left := !left - w
  done;
  Option.iter (fun (path, fd) ->
    Option.iter Unix.close fd;
    if o.settime then try Sys_plan9.set_mtime caps path mtime; Sys_plan9.chmod caps path (if dir then Sys_plan9.dmdir else 0) mode with Unix.Unix_error _ -> ())
    out

let extract (caps : < caps; .. >) o (s : string) ~size pats =
  let block = block o s ~size in
  let said = ref None in
  let checked h = let c = number o h 148 8 ~name:(name h) ~what:"checksum" ~err:(-1.) in c <> -1. && int_of_float c = chksum h in
  let fatal_end what i = try block i with End -> raise (Fatal (Printf.sprintf "unexpected EOF %s %s" what (arname o))) in
  let rec next i =
    let h = fatal_end "instead of archive header in" i in
    if name h <> "" then begin
      let i, h =
        if checked h then i, h
        else if not o.resync then
          let c = number o h 148 8 ~name:(name h) ~what:"checksum" ~err:(-1.) in
          let o_ v = if v = 0. then "0" else "0" ^ digits v "" in
          raise (Fatal (Printf.sprintf "bad archive header checksum in %s: name %s...; expected %s got %s" (arname o) (field h 0 100)
                          (if c = -1. then "037777777777" else o_ c) (o_ (Float.of_int (chksum h)))))
        else begin
          o.say (Printf.sprintf "%s: skipping past archive header with bad checksum in %s..." o.argv0 (arname o));
          let rec find i = let h = fatal_end "looking for archive header in" i in if checked h then i, h else find (i + 1) in
          let i, h = find (i + 1) in
          o.say (Printf.sprintf "found %s\n" (name h));
          i, h
        end in
      let fname = name h in
      let data k = try block (i + 1 + k) with End ->
        raise (Fatal (Printf.sprintf "unexpected EOF on archive extracting %s from %s" fname (arname o))) in
      if matches fname pats then extract1 caps o h fname ~data said
      else for k = 0 to nblocks (arsize o h) - 1 do
          ignore (try block (i + 1 + k) with End -> raise (Fatal (Printf.sprintf "unexpected EOF on archive %s extracting %s" (arname o) fname)))
        done;
      next (i + 1 + nblocks (arsize o h))
    end in
  next 0

(*****************************************************************************)
(* Main *)
(*****************************************************************************)

(* the compressor and decompressor tar.c would run: by the archive's
 * name, or gzip's for z (when compressing, z only) *)
let compression o ~reading = match o.file with
  | Some f when List.exists (Filename.check_suffix f) [ ".tar.gz"; ".tgz" ] && (reading || o.compress) -> Some ("gzip", "gunzip")
  | Some f when List.exists (Filename.check_suffix f) [ ".tar.Z"; ".tz" ] && (reading || o.compress) -> Some ("compress", "uncompress")
  | Some f when List.exists (Filename.check_suffix f) [ ".tar.bz"; ".tbz"; ".tar.bz2"; ".tbz2" ] && (reading || o.compress) -> Some ("bzip2", "bunzip2")
  | _ -> if o.compress then Some ("gzip", "gunzip") else None

let open_archive (caps : < caps; .. >) f ~opening =
  try opening caps f with Unix.Unix_error (e, _, _) -> raise (Fatal (Printf.sprintf "can't open archive %s: %s" f (Unix.error_message e)))

let read_archive (caps : < caps; .. >) o =
  let s = match o.file with
    | Some f -> let fd = open_archive caps f ~opening:FS.open_in_fd in Fun.protect ~finally:(fun () -> Unix.close fd) (fun () -> read_all fd)
    | None -> read_all (Console.stdin_fd caps) in
  match compression o ~reading:true, o.file with
  | Some ("gzip", _), _ -> (try Zlib.gunzip s with Zlib.Corrupt m -> raise (Fatal ("gunzip: " ^ m)))
  | Some (_, cmd), _ -> raise (Fatal (Printf.sprintf "can't exec %s: not in ix" cmd))
  | None, Some _ ->
      (* tar.c's first read sizes the records *)
      let n = min (String.length s) record in
      if n = 0 then raise (Fatal (Printf.sprintf "EOF reading archive %s: " (arname o)));
      if n mod tblock <> 0 then raise (Fatal (Printf.sprintf "%s: archive block size (%d) error" (arname o) n));
      if n <> record then o.say (Printf.sprintf "%s: blocking = %d\n" o.argv0 (n / tblock));
      s
  | None, None -> s

(* r: the archive up to its end, its two zero blocks *)
let before_end o (s : string) =
  let rec go i =
    let off = i * tblock in
    if off + tblock > String.length s then raise (Fatal ("unexpected EOF instead of archive header in " ^ arname o))
    else let h = String.sub s off tblock in if name h = "" then off else go (i + 1 + nblocks (arsize o h)) in
  String.sub s 0 (go 0)

let replace (caps : < caps; .. >) o files =
  (match compression o ~reading:false with Some _ when o.file <> None && not o.create -> raise (Fatal "cannot update compressed archive") | _ -> ());
  (* opened first, as tar.c does: an archive of . has itself, empty *)
  let fd, old = match o.file with
    | Some f when o.create -> open_archive caps f ~opening:(fun caps f -> FS.open_out_fd caps f 0o666), ""
    | Some f -> let fd = open_archive caps f ~opening:FS.open_rw_fd in fd, before_end o (read_all fd)
    | None -> Console.stdout_fd caps, "" in
  let out = Buffer.create 65536 in
  Buffer.add_string out old;
  List.iter (fun arg ->
    let arg = FS.cleanname arg in
    if arg = ".." || (String.length arg >= 3 && String.sub arg 0 3 = "../") then o.say (Printf.sprintf "%s: name starting with .. is a bad idea\n" o.argv0);
    add caps o out arg) files;
  Buffer.add_string out (String.make (2 * tblock) '\000');
  Buffer.add_string out (String.make ((record - Buffer.length out mod record) mod record) '\000');
  let data = match compression o ~reading:false with
    | Some ("gzip", _) -> let t = Float.round (Unix.time ()) in Zlib.gzip None (int_of_float (t /. 65536.), int_of_float (Float.rem t 65536.)) (Buffer.contents out)
    | Some (cmd, _) -> raise (Fatal (Printf.sprintf "can't exec %s: not in ix" cmd))
    | None -> Buffer.contents out in
  if o.file <> None then ignore (Unix.lseek fd 0 Unix.SEEK_SET);
  write_all fd data;
  if o.file <> None then Unix.close fd

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  let o = { argv0 = (if Array.length argv > 0 then argv.(0) else "tar"); say = Console.eprint caps; verb = None; create = false;
            verbose = false; compress = false; file = None; keep = false; settime = false; posix = true; relative = true;
            resync = false; uid = 0; gid = 0 } in
  try
    let args = ref (List.tl (Array.to_list argv)) and errors = ref false in
    (match !args with
     | letters :: rest ->
         args := rest;
         let k = ref 0 in
         (* tar.c's EARGF: the letters' rest, else the next argument *)
         let arg () =
           if !k + 1 < String.length letters then (let a = String.sub letters (!k + 1) (String.length letters - !k - 1) in k := String.length letters; a)
           else match !args with a :: rest -> args := rest; a | [] -> raise Usage in
         let number () = match int_of_string_opt (arg ()) with Some n -> n | None -> 0 in
         while !k < String.length letters do
           (match letters.[!k] with
            | 'c' -> o.create <- true; o.verb <- Some Replace
            | 't' -> o.verb <- Some Toc | 'x' -> o.verb <- Some Xtract | 'r' -> o.verb <- Some Replace
            | 'v' -> o.verbose <- true | 'f' -> o.file <- Some (arg ()) | 'z' -> o.compress <- true
            | 'i' | '-' -> () | 'k' -> o.keep <- true | 'm' -> o.settime <- false | 'T' -> o.settime <- true
            | 'p' -> o.posix <- true | 'P' -> o.posix <- false | 'R' -> o.relative <- false | 's' -> o.resync <- true
            | 'u' -> o.uid <- number () | 'g' -> o.gid <- number ()
            | c -> o.say (Printf.sprintf "tar: unknown letter %c\n" c); errors := true);
           incr k
         done
     | [] -> ());
    if !errors then raise Usage;
    (match o.verb with
     | None -> raise Usage
     | Some (Toc | Xtract) ->
         let s = read_archive caps o in
         extract caps o s ~size:(if o.file <> None && compression o ~reading:true = None then max tblock (min (String.length s) record) else record) !args
     | Some Replace -> replace caps o !args);
    Exit.OK
  with
  | Usage -> o.say (Printf.sprintf "usage: %s {crtx}[PRTfgikmpsuvz] [archive] [file1 file2...]\n" o.argv0); Exit.Err "usage"
  | Fatal m -> flush (Console.stdout caps); o.say (Printf.sprintf "%s: %s\n" o.argv0 m); Exit.Err m

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
