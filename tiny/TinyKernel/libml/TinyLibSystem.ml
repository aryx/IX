(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* TinyLibSystem on tiny-machine: what a tool asks of the system
 * (tiny-shell; ../host/TinyLibSystem.mli says each function), over
 * tiny-kernel's calls (mlsys.c's, beside this file; TinyCalls.ml names
 * them), in tiny-ml's ML. A module after TinyCalls, before the tool's:
 *
 *   tiny-ml -o rc.tm libml/TinyCalls.ml libml/TinyLibSystem.ml TinyShell.ml
 *
 * Not in tiny/ with the other TinyLibXxx.ml: the host's file has the
 * same name, as it must (TinyShell.ml names one module), and mini-ml
 * looks for a module beside the file it compiles before anywhere else.
 *
 * A module, as the host's: the tool writes TinyLibSystem.fork for
 * both (old: a name with a dot, one name, when tiny-ml had no
 * modules). The capabilities are read and forgotten: a function's caps is a
 * value like another, that nothing looks at. Not OCaml's to compile.
 *
 * What tiny-kernel has not, and what is done about it here:
 * - an environment: a PATH only, the root, where the programs are
 * - a dup2: the descriptor closed, then copies made until the kernel
 *   gives its number (it gives the lowest free one)
 * - descriptors closed when a program is run: the ones made here
 *   (save, pipe) are remembered, and closed before the exec. Not all
 *   above 2: a window's program has its drawing at 3 and its mouse at 4
 * - a wait for one child: the kernel says the next that ended, so the
 *   others' ends are kept until asked for
 * - more than 15 arguments for a program, its name one of them: said
 * - a file written at its end (>>), a signal, a terminal to ask about,
 *   a reason for a call that failed: refused, nothing, yes, "cannot"
 * - a stat: a file's kind and size are read from its entry in the
 *   directory it is in, found by its path cleaned as the kernel cleans
 *   it (the current directory first, "." and ".." taken away)
 * - a rename: a copy and a remove, as 9P's mv does, and so not for a
 *   directory
 * - a file's time: touch makes a file that is not there, and does
 *   nothing to one that is
 *)

open Common
open TinyCalls

type Cap.all_caps = < >

let main name f = exit (f ())
let argv caps = List.init (u_argc ()) u_arg
let environment caps = [ "PATH", "/bin" ]
let getpid () = u_getpid ()

(*****************************************************************************)
(* The terminal *)
(*****************************************************************************)

let print caps s = print_string s
let eprint caps s = ignore (u_write 2 s)
let flush () = u_flush ()

(* what was read of the input and is not yet a line given *)
let pending = ref ""

let rec read_line caps =
  match String.index_opt !pending '\n' with
  | Some i ->
      let line = String.sub !pending 0 i in
      pending := String.sub !pending (i + 1) (String.length !pending - i - 1);
      Some line
  | None ->
      let s = u_read 0 4096 in
      if s <> "" then (pending := !pending ^ s; read_line caps)
      else if !pending = "" then None
      else (let line = !pending in pending := ""; Some line)

let isatty n = true
let ignore_interrupt () = ()

(*****************************************************************************)
(* Files *)
(*****************************************************************************)

(* the descriptors made here, which a program run is not to have *)
let private_fds = ref []
let keep fd = private_fds := fd :: !private_fds; fd

(* user.h's O_RDONLY, and O_WRONLY | O_CREATE | O_TRUNC *)
let open_in caps file = let fd = u_open file 0 in if fd < 0 then failwith "cannot open" else fd
let open_out caps file = let fd = u_open file 0x601 in if fd < 0 then failwith "cannot create" else fd
let open_append caps file = failwith "tiny-kernel has no >>"
let close fd = ignore (u_close fd); private_fds := List.filter (fun d -> d <> fd) !private_fds

let read_all fd = let rec go acc = let s = u_read fd 4096 in if s = "" then acc else go (acc ^ s) in go ""
let read_file caps file =
  let fd = open_in caps file in
  let s = read_all fd in
  close fd;
  s

(* a directory is read as a file of entries of 32 bytes (user.h's
 * dirent): a name of 20 bytes ended by a 0, its type (1 for a
 * directory), its links, and its size *)
let entries dir =
  let fd = u_open (if dir = "" then "." else dir) 0 in
  if fd < 0 then []
  else begin
    let s = read_all fd in
    ignore (u_close fd);
    let name i = String.sub s i ((String.index_from_opt s i '\000' ||| (i + 20)) - i) in
    let word i = Char.code s.[i] + (Char.code s.[i + 1] lsl 8) + (Char.code s.[i + 2] lsl 16) + (Char.code s.[i + 3] lsl 24) in
    List.init (String.length s / 32) (fun k -> name (k * 32), (Char.code s.[k * 32 + 20] = 1, word (k * 32 + 28), word (k * 32 + 24)))
  end

let readdir dir = List.map fst (entries dir)

(* a path's names from the root, as the kernel finds them *)
let path_names file =
  let start = if String.length file > 0 && file.[0] = '/' then "" else u_getcwd () in
  let clean acc n = if n = "" || n = "." then acc else if n = ".." then (match acc with [] -> [] | _ :: r -> r) else n :: acc in
  List.rev (List.fold_left clean [] (String.split_on_char '/' (start ^ "/" ^ file)))

(* the file's entry in its directory: whether it is one, its size, its
 * links (the root has no entry: a directory with one name) *)
let entry file =
  match List.rev (path_names file) with
  | [] -> true, 0, 1
  | last :: up ->
      let dir = List.fold_left (fun acc n -> "/" ^ n ^ acc) "" up in
      (match List.assoc_opt last (entries (if dir = "" then "/" else dir)) with
       | Some e -> e
       | None -> failwith "not there")

let stat file = let is_dir, size, _ = entry file in is_dir, size
let links file = let _, _, n = entry file in n

let is_directory file = try fst (stat file) with Failure _ -> false

let read fd max = u_read fd max
let write fd s = if u_write fd s < 0 then failwith "cannot write"
let mkdir caps dir = if u_mkdir dir < 0 then failwith "cannot"
let remove caps file = if u_unlink file < 0 then failwith "cannot"
let link caps a b = if u_link a b < 0 then failwith "cannot"

let rename caps a b =
  if path_names a <> path_names b then begin
    if fst (stat a) then failwith "a directory, which tiny-kernel cannot move";
    (* (a piece at a time, as cp: a big file does not fit in the heap) *)
    let src = open_in caps a in
    let fd = open_out caps b in
    let rec go () = let s = u_read src 4096 in if s <> "" then begin write fd s; go () end in
    go ();
    close fd;
    close src;
    remove caps a
  end

let touch caps file =
  if not (try ignore (stat file); true with Failure _ -> false) then close (open_out caps file)

let getcwd caps = u_getcwd ()

(* a tick is 2.5 ms; ready on no descriptor until a tick is a sleep *)
let sleep ms = if ms > 0 then ignore (u_ready (Array.make 0 0) 0 (u_ticks () + ((ms * 2) + 4) / 5))

let chdir caps dir = if u_chdir dir < 0 then failwith "cannot"

(*****************************************************************************)
(* Descriptors *)
(*****************************************************************************)

let save n = let d = u_dup n in if d < 0 then None else Some (keep d)

let dup2 a b =
  if a <> b then begin
    ignore (u_close b);
    let rec go others =
      let d = u_dup a in
      if d = b || d < 0 then List.iter (fun o -> ignore (u_close o)) others else go (d :: others) in
    go []
  end

(* u_pipe's two ends in a number: where to read, and 256 times where to write *)
let pipe () =
  let p = u_pipe () in
  if p < 0 then failwith "no pipe" else keep (p mod 256), keep (p / 256)

(*****************************************************************************)
(* Processes *)
(*****************************************************************************)

let fork caps = u_fork ()

let exec caps file argv env =
  List.iter (fun d -> ignore (u_close d)) !private_fds;
  private_fds := [];
  if List.length argv > 15 then "more than 15 arguments"
  else if u_exec file argv < 0 then "not found" else ""

(* the children that ended while another was waited for: pid, status *)
let ended = ref []

(* u_waits's number: the child's pid, and 256 times it, its status's
 * low byte; a process the kernel ended (a fault, a kill) has -1 *)
let rec wait caps pid =
  match List.assoc_opt pid !ended with
  | Some status ->
      ended := List.filter (fun (p, _) -> p <> pid) !ended;
      if status = 0 then "" else if status = 255 then "signal: kill" else string_of_int status
  | None ->
      let r = u_waits () in
      if r < 0 then "" else (ended := (r / 256, r mod 256) :: !ended; wait caps pid)

let exit n = exit n
