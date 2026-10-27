(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyKernelFiles.mli *)
open TinyMemory
open TinyKernelGraphics
open TinyKernelNetwork
open TinyKernelFS
open TinyKernelMachine

(*****************************************************************************)
(* The files: a tree of ML values *)
(*****************************************************************************)

(* a directory is a list of names in the order they were made; the
 * console is a node too, /dev/console, and the screen, the mouse and
 * the speaker, /dev/draw, /dev/mouse and /dev/audio (the programs are
 * in /bin, examples to look at in /examples). A file of the image is
 * read where the image has it (its address, its size) until it is
 * written: the programs, a megabyte of them, are then not the
 * collector's to copy at each collection (old: each a string, Data; a
 * collection was 3 million instructions).
 * A file or a directory on the disk (TinyKernelFS.ml) is a tree and an
 * inode's number: tree 0 is the live one, the others are the snapshots.
 * A union is several directories seen as one, as Plan 9's bind -a makes:
 * a name is looked up in each in turn, and what is made goes in the
 * first. A file written in memory is its bytes and its size, the bytes
 * doubled when a write goes past them (old: a string, made again at
 * each write: a database that grows by appends took a second for each
 * statement, tiny-db's) *)
type node =
  | Dir of (string * node) list ref
  | Data of data
  | Rom of int * int
  | Tty
  | Screen
  | Pointer
  | Speaker
  | Disk of int * int
  | Union of node list
and data = { mutable dbytes : bytes; mutable dsize : int; mutable dtime : int }

let data s =
  let b = Bytes.make (String.length s) ' ' in
  Bytes.blit_string s 0 b 0 (String.length s);
  { dbytes = b; dsize = String.length s; dtime = 0 }
let text d = Bytes.sub_string d.dbytes 0 d.dsize

(* a pipe: the bytes written not yet read (512 at most), its readers'
 * and its writers' descriptors (a read of an empty pipe with no writer
 * left is its end) *)
type pipe =
  { mutable buf : string; mutable readers : int; mutable writers : int }

(* an open file: a node (its offset, whether it is written), a pipe's
 * end, the console, a connection to the screen, a box's end. The
 * collector frees them; only pipes count their ends, as a reader must
 * learn that no writer is left, and a connection its descriptors, as
 * its images are not the collector's *)
type file =
  | Open of opened
  | Reader of pipe
  | Writer of pipe
  | Console
  | Draw of drawing
  | Peek of box
  | Post of box
  | Link of link
  | Call of call
  | Voice of voice
  | Trace of trace
(* (listing: a directory's entries, made at its read from the start,
 * and the reads after take theirs from it) *)
and opened = { node : node; mutable off : int; writes : bool;
               mutable listing : string option }
and drawing = { conn : conn; mutable refs : int }

(* a box: a pipe that keeps only what was last written, and whether it
 * was read since (the mouse is a place, not its history: a reader that
 * is late finds where it is, and a writer never waits). Peek reads it,
 * Post writes it; the kernel's own is the mouse, a window system's are
 * its windows' mice *)
and box = { mutable last : string; mutable fresh : bool; mutable posters : int }

(* a link to another machine (plan_tiny_network.md): so far an echo's.
 * What is written is sent there as a question, and a read gives an
 * answer's bytes, whole, in the order they came; a link has a number,
 * which its questions carry and their answers bring back *)
and link = {
  peer : string;
  lid : int;
  mutable asked : int;
  mutable heard : string list;
  mutable holders : int;
}

(* a connection to a program of another machine (TinyKernelNetwork.ml's IL):
 * a write is a message, which arrives once and in order or is sent
 * again; a read gives one whole, 0 when the other end is done; and its
 * descriptors, the last one's close saying the end *)
and call = { il : il; mutable callers : int }

(* a voice of the speaker (an open of /dev/audio): where in the samples its
 * next one goes *)
and voice = { mutable ahead : int }

(* a process traced by another, its tracer (debug: plan_tiny_debugger.md):
 * their pids, the breakpoints (an address and the word that was there),
 * what is said to the tracer and not yet read, and the tracer's
 * descriptors on it; whether it stops at its calls (trace), the call
 * it is stopped before or let in (-1: none), the call whose end it
 * waits for, to stop then (-1: none); whether it runs one instruction
 * and stops (a step), and the breakpoint it runs the word of, the 0
 * written again after (-1: none); whether its children are traced too
 * (trace -f) *)
and trace = {
  tpid : int;
  tracer : int;
  mutable stops : (int * int) list;
  mutable said : string list;
  mutable watchers : int;
  mutable calls : bool;
  mutable call : int;
  mutable ret : int;
  mutable step : bool;
  mutable over : int;
  mutable follow : bool;
}

(* The image's files (and /dev), and the tree a path starts from. They
 * are the same when there is no disk. With a disk, the boot makes the
 * top a union, Plan 9's way: the disk's root first, then /boot (the
 * image's files alone) and /dump, then the image's files again, so
 * that /bin is the disk's /bin and /boot/bin together *)
let root = Dir (ref [])
let top = ref root

(* a path's names from the root: the current directory's first unless
 * it starts with /, "." dropped, ".." the name before it removed (by
 * the text, as Plan 9's cleanname: no ".." in a directory) *)
let names cwd path =
  let start =
    if String.length path > 0 && path.[0] = '/' then [] else List.rev cwd in
  List.rev (List.fold_left (fun acc n ->
    if n = "" || n = "." then acc
    else if n = ".." then (match acc with [] -> [] | _ :: r -> r)
    else n :: acc)
    start (String.split_on_char '/' path))

let is_dir node =
  match node with
  | Dir _ | Union _ -> true
  | Disk (r, i) -> fs_is_dir r i
  | _ -> false

(* In a union, the name is looked up in each directory. The first one
 * found is the answer, unless it is a directory found in several: then
 * the answer is their union (/bin, in the disk and in the image) *)
let rec walk node ns =
  match ns, node with
  | [], _ -> Some node
  | n :: rest, Dir d ->
      (match List.assoc_opt n !d with Some c -> walk c rest | None -> None)
  | n :: rest, Disk (r, i) when fs_is_dir r i ->
      (match fs_lookup r i n with 0 -> None | j -> walk (Disk (r, j)) rest)
  | n :: rest, Union l ->
      (match List.fold_left (fun acc m ->
         match walk m [ n ] with Some c -> acc @ [ c ] | None -> acc) [] l with
       | [] -> None
       | [ c ] -> walk c rest
       | c :: more ->
           walk (if is_dir c then Union (List.filter is_dir (c :: more)) else c)
             rest)
  | _ -> None

(* a directory's names and what they are (in a union, a name once: the
 * first) *)
let rec children node =
  match node with
  | Dir d -> !d
  | Disk (r, i) ->
      List.map (fun (name, j) -> name, Disk (r, j)) (fs_entries r i)
  | Union l ->
      List.fold_left (fun acc m ->
        acc @ List.filter (fun (name, _) ->
          not (List.exists (fun (k, _) -> k = name) acc)) (children m)) [] l
  | _ -> []

(* where a directory's new names go: a union's first *)
let rec home node = match node with Union (m :: _) -> home m | _ -> node

(* the directory a path's last name is in (where it would be made: a
 * Dir, or a directory on the disk), and that name *)
let dir_of ns =
  match List.rev ns with
  | [] -> None
  | last :: r ->
      (match walk !top (List.rev r) with
       | Some n when is_dir n -> Some (home n, last)
       | _ -> None)

(* a directory read as a file: an entry of 80 bytes per name, t6's (its
 * name, its type, a first block, its size), which ls reads, but for
 * the name's 64 bytes, the disk's, and the date of the last write after
 * the size (old: t6's 20 bytes of name: the sources'
 * TinyAppTemperature.mli could not be listed, its .tmi not made; then
 * 28, and no date). The first block, which this kernel has no use for,
 * says the file's links instead: how many names it has. *)
let word n = String.init 4 (fun k -> Char.chr ((n lsr (8 * k)) land 255))

(* a node's names: the entries in the whole tree that hold the same
 * value (==), the file itself and not a copy of it *)
let links node =
  let rec count d =
    List.fold_left (fun acc (_, n) ->
      acc + (if n == node then 1 else 0)
      + (match n with Dir e -> count e | _ -> 0)) 0 !d in
  match root with Dir d -> count d | _ -> 0

(* an entry: a name, a type, the links, a size, a date; a disk's file
 * says its own (its type is 1 or 2 as here); the image's files have the
 * date 0, 2000-01-01, a directory in memory too *)
let entry name n =
  let t, size, l = match n with
    | Dir _ -> 1, 0, links n
    | Data d -> 2, d.dsize, links n
    | Rom (_, k) -> 2, k, links n
    | Disk (r, i) -> fs_kind r i
    | Union _ -> 1, 0, 1
    | _ -> 3, 0, links n in
  let date =
    match n with Data d -> d.dtime | Disk (r, i) -> fs_date r i | _ -> 0 in
  name ^ String.make (64 - String.length name) '\000'
  ^ word t ^ word l ^ word size ^ word date

let contents node =
  match node with
  | Data d -> text d
  | Rom (at, n) -> k_string at n
  | Tty | Screen | Pointer | Speaker -> ""
  | Disk (r, i) when not (fs_is_dir r i) -> fs_contents r i
  (* (made once: old, acc ^ entry, the listing copied again at each name,
   * quadratic: ls -l of /bin, 55 names each listing it twice, took 7
   * minutes when the entries went from 40 bytes to 80) *)
  | _ ->
      String.concat "" (List.map (fun (name, n) -> entry name n) (children node))

(* [place d name node]: node under name in d; a name with a slash,
 * examples/wc.c, in its directory, which is made the first time *)
let rec place d name node =
  match String.index_opt name '/' with
  | None -> d := !d @ [ name, node ]
  | Some i ->
      let dir = String.sub name 0 i
      and rest = String.sub name (i + 1) (String.length name - i - 1) in
      (match List.assoc_opt dir !d with
       | Some (Dir sub) -> place sub rest node
       | _ ->
           let sub = ref [] in
           d := !d @ [ dir, Dir sub ];
           place sub rest node)

(* the files the image carries after the kernel (TinyKernel/Makefile's): a
 * path, a line; its size, a line; its bytes; an empty path at the end.
 * A line "link" and another file's path, in place of the size, makes a
 * hard link, as link() does: the same node under a second name, with
 * no bytes (bin/utils, under the name of each of its utilities:
 * bin/cat, bin/ls...) *)
let rec load a =
  let rec line a acc =
    let c = peekb a in
    if c = 10 then acc, a + 1
    else line (a + 1) (acc ^ String.make 1 (Char.chr c)) in
  let name, a = line a "" in
  if name <> "" then begin
    let size, a = line a "" in
    match root with
    | Dir d when String.length size > 5 && String.sub size 0 5 = "link " ->
        (match walk root (names [] (String.sub size 5 (String.length size - 5)))
         with
         | Some node -> place d name node
         | None -> ());
        load a
    | Dir d ->
        let n = Option.get (int_of_string_opt size) in
        place d name (Rom (a, n));
        load (a + n)
    | _ -> ()
  end
