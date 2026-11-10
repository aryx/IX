(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* TinyLibSystem on tiny-machine: what a tool asks of the system (the
 * shell, the utilities, the compilers, the assembler and the linker,
 * the build system, the editor...; ../host/TinyLibSystem.mli says each
 * function), over tiny-kernel's calls (mlsys.c's, beside this file;
 * TinyCalls.ml names them).
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
 * - more than 63 arguments for a program, its name one of them: said
 *   (old: 15; a linker's line names 30 objects)
 * - a signal, a terminal to ask about, a reason for a call that
 *   failed: nothing, yes, "cannot" (old: a file written at its end,
 *   >>, refused, before the kernel's seek)
 * - a stat: a file's kind and size are read from its entry in the
 *   directory it is in, found by its path cleaned as the kernel cleans
 *   it (the current directory first, "." and ".." taken away)
 * - a rename: a copy and a remove, as 9P's mv does, and so not for a
 *   directory
 * - a file's time: touch makes a file that is not there, and does
 *   nothing to one that is
 * - a file's modes: no file is a program to run (x)
 *)

open TinyCalls

type Cap.all_caps = < >

(* the host's .mli's names (TinyLibSystem.mli) *)
type pid = int
type fd = int
type status = string
type stat = { st_dir : bool; st_size : int }
type seconds = int
type milliseconds = int

let main name f =
  let said m = u_flush (); ignore (u_write 2 (name ^ ": " ^ m ^ "\n")); 1 in
  (* Logs' messages said as an error is *)
  Logs.set_reporter (fun _ m -> ignore (said m));
  exit
    (try
       match f () (Array.init (u_argc ()) u_arg) with
       | Exit.OK -> 0
       | Exit.Err m -> said m
       | Exit.Code n -> n
     with
     | Failure m -> said m
     | Exit.ExitCode n -> n)

let logging args =
  List.filter (fun a ->
    match a with
    | "-v" -> Logs.set_level (Some Logs.Info); false
    | "-debug" -> Logs.set_level (Some Logs.Debug); false
    | "-quiet" -> Logs.set_level None; false
    | _ -> true) args

let environment caps = [ "PATH", "/bin" ]
let getpid _caps = u_getpid ()

(*****************************************************************************)
(* The terminal *)
(*****************************************************************************)

let print caps s = print_string s
let eprint caps s = ignore (u_write 2 s)
let flush _caps = u_flush ()

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
let ignore_interrupt _caps = ()

(*****************************************************************************)
(* Files *)
(*****************************************************************************)

(* the descriptors made here, which a program run is not to have *)
let private_fds = ref []
let keep fd = private_fds := fd :: !private_fds; fd

(* a path for the kernel's calls, which take strings (not !!: / is
 * the integers' division in this file) *)
let str = Fpath.to_string

(* to read, to write anew, and to write then a seek to the end
 * (TinyCalls' flags) *)
let open_in caps file =
  let fd = u_open (str file) o_read in
  if fd < 0 then failwith "cannot open" else fd
let open_out caps file =
  let fd = u_open (str file) o_anew in
  if fd < 0 then failwith "cannot create" else fd
let open_append caps file =
  let fd = u_open (str file) o_write in
  if fd < 0 then failwith "cannot create"
  else if u_seek fd 0 2 < 0 then (ignore (u_close fd); failwith "cannot seek")
  else fd
(* to read and write, made when it is not there; seek's whence 0 the
 * start, 2 the end *)
let open_rw caps file =
  let fd = u_open (str file) o_read_write in
  if fd < 0 then failwith "cannot open" else fd
let seek fd off = if u_seek fd off 0 < 0 then failwith "cannot seek"
let seek_end fd =
  let off = u_seek fd 0 2 in
  if off < 0 then failwith "cannot seek" else off
let close fd =
  ignore (u_close fd);
  private_fds := List.filter (fun d -> d <> fd) !private_fds

(* (the pieces joined at the end; old: acc ^ s at each, the file copied
 * again at each 4 KB) *)
let read_all fd =
  let rec go acc =
    let s = u_read fd 4096 in
    if s = "" then String.concat "" (List.rev acc) else go (s :: acc)
  in
  go []
let read_file caps file =
  let fd = open_in caps file in
  let s = read_all fd in
  close fd;
  s

(* (a channel is the descriptor: TinyLibCore's Stdlib.ml) *)
external in_channel_of_descr : int -> in_channel = "%identity"
(* the file named in an open's failure, as the host's Sys_error names it
 * ("f: cannot open"; old: "cannot open", the file said by no one) *)
let named file g =
  try g () with Failure m -> failwith (str file ^ ": " ^ m)
let with_open_in caps f file =
  let fd = named file (fun () -> open_in caps file) in
  let chan : Chan.i = { ic = in_channel_of_descr fd; origin = File file } in
  let r = try f chan with e -> close fd; raise e in
  close fd;
  r

external out_channel_of_descr : int -> out_channel = "%identity"
(* f on a file opened by opener to write, closed after (old: written
 * twice, the opener the only difference) *)
let with_out opener caps f file =
  let fd = named file (fun () -> opener caps file) in
  let chan : Chan.o = { oc = out_channel_of_descr fd; dest = OutFile file } in
  let r = try f chan with e -> close fd; raise e in
  close fd;
  r
let with_open_out caps f file = with_out open_out caps f file
let with_open_append caps f file = with_out open_append caps f file
let stdin _caps : Chan.i = { ic = in_channel_of_descr 0; origin = Stdin }

(* A directory entry, 80 bytes (user.h's dirent): a name of 64 bytes
 * ended by a 0 when shorter, its type (1 for a directory), its links,
 * its size and its date, a word each, the low bytes first. A directory
 * is read as a file of them; the kernel's stat gives one. *)
type dirent = { e_dir : bool; e_links : int; e_size : int; e_mtime : int }

(* the word at i of s *)
let word s i =
  String.get_uint16_le s i + (String.get_uint16_le s (i + 2) lsl 16)

(* the entry at i of s, but its name (old: a 4-tuple, taken apart with
 * _ by its readers) *)
let dirent s i =
  { e_dir = Char.code s.[i + 64] = 1; e_links = word s (i + 68);
    e_size = word s (i + 72); e_mtime = word s (i + 76) }

(* the names in a directory (old: its entries decoded whole, then all
 * but their names dropped) *)
let names dir =
  let fd = u_open dir o_read in
  if fd < 0 then []
  else begin
    let s = read_all fd in
    ignore (u_close fd);
    let name i =
      let e = i + 64 in
      String.sub s i
        ((match String.index_from_opt s i '\000' with
          | Some j when j < e -> j
          | _ -> e)
         - i)
    in
    List.init (String.length s / 80) (fun k -> name (k * 80))
  end

let readdir _caps dir = names (str dir)

(* a path's names from the root, as the kernel finds them *)
let path_names file =
  let start = if String.length file > 0 && file.[0] = '/' then "" else u_getcwd () in
  let clean acc n =
    if n = "" || n = "." then acc
    else if n = ".." then (match acc with [] -> [] | _ :: r -> r)
    else n :: acc
  in
  List.rev (List.fold_left clean [] (String.split_on_char '/' (start ^ "/" ^ file)))

(* the file's entry, the kernel's stat (old: its directory read whole
 * for it) *)
let entry file : dirent =
  let s = u_stat (str file) in
  if s = "" then failwith "not there" else dirent s 0

let stat _caps file =
  let e = entry file in { st_dir = e.e_dir; st_size = e.e_size }
let links _caps file = (entry file).e_links
let mtime _caps file = (entry file).e_mtime

let is_directory caps file = try (stat caps file).st_dir with Failure _ -> false

let read fd max = u_read fd max
let write fd s = if u_write fd s < 0 then failwith "cannot write"
let write_file caps file s =
  let fd = open_out caps file in
  write fd s;
  close fd
let mkdir caps dir = if u_mkdir (str dir) < 0 then failwith "cannot"
let remove caps file = if u_unlink (str file) < 0 then failwith "cannot"
let link caps a b = if u_link (str a) (str b) < 0 then failwith "cannot"

let rename caps a b =
  if path_names (str a) <> path_names (str b) then begin
    if (stat caps a).st_dir then failwith "a directory, which tiny-kernel cannot move";
    (* (a piece at a time, as cp: a big file does not fit in the heap) *)
    let src = open_in caps a in
    let fd = open_out caps b in
    let rec go () =
      let s = u_read src 4096 in
      if s <> "" then begin write fd s; go () end
    in
    go ();
    close fd;
    close src;
    remove caps a
  end

let is_executable _caps file = false
let set_executable caps file x = ()

let touch caps file =
  if not (try ignore (stat caps file); true with Failure _ -> false) then
    close (open_out caps file)

let getcwd caps = Fpath.v (u_getcwd ())

let time _caps = u_time ()

(* the milliseconds, from the ticks, 400 a second (a tick is 2.5 ms);
 * a sleep is a ready on no descriptor, until a tick *)
let millis _caps = u_ticks () * 5 / 2
let sleep _caps ms =
  if ms > 0 then
    ignore (u_ready (Array.make 0 0) 0 (u_ticks () + ((ms * 2) + 4) / 5))

let chdir caps dir = if u_chdir (str dir) < 0 then failwith "cannot"

(*****************************************************************************)
(* Descriptors *)
(*****************************************************************************)

let save n = let d = u_dup n in if d < 0 then None else Some (keep d)

let dup2 a b =
  if a <> b then begin
    ignore (u_close b);
    let rec go others =
      let d = u_dup a in
      if d = b || d < 0 then List.iter (fun o -> ignore (u_close o)) others
      else go (d :: others)
    in
    go []
  end

(* u_pipe's two ends in a number: where to read, and 256 times where to write *)
let pipe _caps =
  let p = u_pipe () in
  if p < 0 then failwith "no pipe" else keep (p mod 256), keep (p / 256)

(*****************************************************************************)
(* Processes *)
(*****************************************************************************)

(* (u_fork's -1: the kernel's processes all taken, which rc says "try
 * again") *)
let fork caps =
  match u_fork () with
  | -1 -> failwith "try again"
  | 0 -> None
  | p -> Some p

let kill caps pid = u_kill pid >= 0

let exec caps file argv env =
  List.iter (fun d -> ignore (u_close d)) !private_fds;
  private_fds := [];
  if List.length argv > 63 then "more than 63 arguments"
  else if u_exec (str file) argv < 0 then "not found" else ""

(* the children that ended while another was waited for: pid, status *)
let ended = ref []

(* a status's low byte as rc's; a process the kernel ended (a fault, a
 * kill) has -1 *)
let status st =
  if st = 0 then "" else if st = 255 then "signal: kill" else string_of_int st

(* u_waits's number: the child's pid, and 256 times it, its status's
 * low byte *)
let rec wait caps pid =
  match List.assoc_opt pid !ended with
  | Some st -> ended := List.filter (fun (p, _) -> p <> pid) !ended; status st
  | None ->
      let r = u_waits () in
      if r < 0 then "" else (ended := (r / 256, r mod 256) :: !ended; wait caps pid)

let wait_any caps =
  match !ended with
  | (p, st) :: rest -> ended := rest; Some (p, status st)
  | [] ->
      let r = u_waits () in
      if r < 0 then None else Some (r / 256, status (r mod 256))

(* rc's words quoted, '' a quote inside *)
let quote w = "'" ^ String.concat "''" (String.split_on_char '\'' w) ^ "'"

(* the scripts written, for their files' names *)
let scripts = ref 0

(* The script in a file that removes itself, run by rc in a child made
 * by spawn: nothing of this process copied, where a fork copied it
 * whole (tiny-build's 16 MB at each recipe) for rc's exec to drop it.
 * Its pid, or None (old: -1; older: u_fork, and the child wrote the
 * file, named by its pid, and exec'ed rc) *)
let shell caps vars script =
  u_flush ();
  incr scripts;
  let file =
    ".shell" ^ string_of_int (u_getpid ()) ^ "." ^ string_of_int !scripts in
  write_file caps (Fpath.v file)
    ("rm " ^ file ^ "\n"
     ^ String.concat ""
         (List.map
            (fun (k, v) ->
              k ^ "=(" ^ String.concat " " (List.map quote v) ^ ")\n")
            vars)
     ^ script ^ "\n");
  let pid = u_spawn "/bin/rc" [ "rc"; "-e"; file ] in
  if pid < 0 then (ignore (u_unlink file); None) else Some pid

let exit _caps e =
  exit
    (match e with
     | Exit.OK -> 0
     | Exit.Err m -> ignore (u_write 2 (m ^ "\n")); 1
     | Exit.Code n -> n)
