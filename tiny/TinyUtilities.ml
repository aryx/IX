(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
 *
 * testing:
 * The test (tests/TinyUtilities_test.sh) runs each utility and its
 * twin, mini-wc, mini-xd..., on the same arguments, and compares what
 * they print and their exit status: the twins' output is kept where it
 * costs nothing.
 *)
module TSys = TinyLibSystem
open TinyLibRegex (* (grep's patterns: compile, matches) *)
open Common (* (|||: an option's value, or a default) *)
(* a path's text (Fpath_.Operators' !!, not opened: its / would hide the
 * division) *)
let ( !! ) = Fpath.to_string

(*****************************************************************************)
(* Types *)
(*****************************************************************************)

type caps =
  < Cap.open_in; Cap.open_out; Cap.readdir; Cap.stdin; Cap.stdout; Cap.stderr;
    Cap.kill; Cap.clock; Cap.exit; Cap.env >

(* what each utility asks, said by it: the table says what each may do
 * (one that only prints, < Cap.stdout; .. >; one that changes files,
 * < Cap.stderr; Cap.open_out; .. >, said only when it fails). A
 * filter's: its files read, or the standard input, printed, and what
 * failed said *)
type filter = < Cap.open_in; Cap.stdin; Cap.stdout; Cap.stderr >

(* a utility's exit status: 0 when it went well (a number, not an
 * Exit.t: test's answer is one) *)
type status = int

(* raised by a utility given arguments it does not take: the driver
 * then prints the utility's usage *)
exception Usage

(*****************************************************************************)
(* Helpers *)
(*****************************************************************************)

let print caps s = TSys.print caps s
let complain caps tool s = TSys.eprint caps (tool ^ ": " ^ s ^ "\n")

(* the operands as files' paths, made as a utility reads its
 * arguments, printed as Fpath.to_string says them (a//b as a/b): the
 * empty word a Failure, the utility's (old: kept as typed, a string
 * to the system's door, to say each as typed and '' as one file's
 * error among the others; compatibility, which tiny/ does not keep) *)
let path (w : string) : Fpath.t =
  if w = "" then failwith "no file name" else Fpath.v w
let paths_of ws = List.map path ws

(* what follows the last slash of a path *)
let last_part path =
  match String.rindex_opt path '/' with
  | Some i -> String.sub path (i + 1) (String.length path - i - 1)
  | None -> path

(* a name as rc reads it back: between quotes, a quote doubled, when it
 * is empty or has a space, a control character or a quote *)
let quote name =
  if name <> "" && not (String.exists (fun c -> c <= ' ' || c = '\'') name)
  then name
  else "'" ^ String.concat "''" (String.split_on_char '\'' name) ^ "'"

(* [options letters args]: the letters of the options in front of args,
 * each of which must be one of letters, and the arguments after them.
 * "--" ends the options, and "-" alone is an argument *)
let options letters args =
  let rec go acc args =
    match args with
    | "--" :: rest -> acc, rest
    | a :: rest when String.length a > 1 && a.[0] = '-' ->
        let given = List.init (String.length a - 1) (fun i -> a.[i + 1]) in
        if List.for_all (fun c -> String.contains letters c) given
        then go (acc @ given) rest
        else raise Usage
    | _ -> acc, args in
  go [] args

(*****************************************************************************)
(* Filters, each_input() *)
(*****************************************************************************)

(* [piece c n]: what the channel gives next, up to n bytes, without
 * waiting for more ("" at the end); [pieces c f]: f on each piece, as
 * soon as it is read, until the end (old: a descriptor's, the files
 * opened and closed by hand) *)
let piece (c : Chan.i) n =
  let b = Bytes.make n ' ' in
  Bytes.sub_string b 0 (In_channel.input c.ic b 0 n)
let pieces (c : Chan.i) f =
  let b = Bytes.make 8192 ' ' in
  let rec go () =
    let n = In_channel.input c.ic b 0 8192 in
    if n > 0 then begin f (Bytes.sub_string b 0 n); go () end in
  go ()

(* [lines c f]: f on each line of c, without its newline, as soon as
 * it is whole, and whether a newline ended it: the last one may have
 * none *)
let lines (c : Chan.i) f =
  let rest = ref "" in
  pieces c (fun s ->
    let s = !rest ^ s in
    let rec go i =
      match String.index_from_opt s i '\n' with
      | Some j -> f (String.sub s i (j - i)) true; go (j + 1)
      | None -> rest := String.sub s i (String.length s - i) in
    go 0);
  if !rest <> "" then f !rest false

(* [named name g]: g's Failure said after the name *)
let named name g = try g () with Failure m -> failwith (name ^ ": " ^ m)

(* [each_input caps tool files f]: f on each file's channel, or on the
 * standard input's when there is none; one that fails is said, "name:
 * reason" (an open's already names its file), and the status is then
 * 1. A channel says where it reads (name_of) *)
let each_input caps tool (files : Fpath.t list) (f : Chan.i -> unit)
    : status =
  let one status run =
    try run (); status with Failure m -> complain caps tool m; 1 in
  if files = [] then
    one 0 (fun () -> named "stdin" (fun () -> f (TSys.stdin caps)))
  else
    List.fold_left (fun status file ->
      one status (fun () ->
        TSys.with_open_in caps
          (fun c -> named !!file (fun () -> f c)) file)) 0 files

(* the file a channel reads, None for the standard input *)
let name_of (c : Chan.i) : Fpath.t option =
  match c.origin with Chan.File p -> Some p | _ -> None

(*****************************************************************************)
(* cat, wc *)
(*****************************************************************************)

let cat (caps : < filter; .. >) args =
  let _, files = options "" args in
  each_input caps "cat" (paths_of files) (fun c ->
    pieces c (fun s -> print caps s; TSys.flush caps))

(* the counts so far, and whether the last byte counted was inside a
 * word: a word can be cut in two by the end of a piece *)
type counts = {
  mutable lines : int;
  mutable words : int;
  mutable bytes : int;
  mutable inword : bool;
}

let counts () = { lines = 0; words = 0; bytes = 0; inword = false }

let count c s =
  for i = 0 to String.length s - 1 do
    let k = Char.code s.[i] in
    if k = 10 then c.lines <- c.lines + 1;
    if k = 32 || (k >= 9 && k <= 13) then c.inword <- false
    else if not c.inword then begin c.words <- c.words + 1; c.inword <- true end
  done;
  c.bytes <- c.bytes + String.length s

let wc (caps : < filter; .. >) args =
  let asked, files = options "lwc" args in
  let asked = if asked = [] then [ 'l'; 'w'; 'c' ] else asked in
  let report c name =
    let columns =
      List.filter (fun (letter, _) -> List.mem letter asked)
        [ 'l', c.lines; 'w', c.words; 'c', c.bytes ] in
    let columns = List.map (fun (_, n) -> Printf.sprintf "%7d" n) columns in
    print caps
      (String.concat " " (columns @ Option.to_list name)
       ^ "\n") in
  let total = counts () and files_counted = ref 0 in
  let status =
    each_input caps "wc" (paths_of files) (fun chan ->
      let c = counts () in
      pieces chan (count c);
      report c (Option.map Fpath.to_string (name_of chan));
      incr files_counted;
      total.lines <- total.lines + c.lines;
      total.words <- total.words + c.words;
      total.bytes <- total.bytes + c.bytes) in
  if !files_counted > 1 then report total (Some "total");
  status

(*****************************************************************************)
(* tail, tee, xd *)
(*****************************************************************************)

(* the text from its nth line from the end, or from its nth line (+n).
 * tail is the one filter that reads all its input first: until the
 * end, it cannot know which lines are the last *)
let lines_of from_end n s =
  let len = String.length s in
  let start =
    if from_end then begin
      (* back from the end over n newlines, the one that ends the text
       * not counted *)
      let rec back i k =
        if i < 0 then 0
        else if s.[i] = '\n' then
          (if k = n then i + 1 else back (i - 1) (k + 1))
        else back (i - 1) k in
      if n = 0 then len
      else back (if len > 0 && s.[len - 1] = '\n' then len - 2 else len - 1) 1
    end
    else begin
      let rec skip i k =
        if k <= 1 || i >= len then i
        else if s.[i] = '\n' then skip (i + 1) (k - 1)
        else skip (i + 1) k in
      skip 0 n
    end in
  String.sub s start (len - start)

let tail (caps : < filter; .. >) args =
  let from_end, n, files =
    match args with
    | "-n" :: n :: rest -> true, n, rest
    | a :: rest when String.length a > 1 && (a.[0] = '-' || a.[0] = '+') ->
        a.[0] = '-', String.sub a 1 (String.length a - 1), rest
    | _ -> true, "10", args in
  match int_of_string_opt n, files with
  | Some n, ([] | [ _ ]) when n >= 0 ->
      each_input caps "tail" (paths_of files) (fun (c : Chan.i) ->
        print caps (lines_of from_end n (In_channel.input_all c.ic)))
  | _ -> raise Usage

let tee (caps : < Cap.stdout; Cap.stderr; Cap.stdin; Cap.open_out; .. >) args =
  let _, files = options "" args in
  let status = ref 0 in
  let fds =
    List.concat_map (fun file ->
      try [ TSys.open_out caps file ]
      with Failure m ->
        complain caps "tee" (!!file ^ ": " ^ m); status := 1; [])
      (paths_of files) in
  (* (the files written as the input comes, several at once: their
   * descriptors) *)
  pieces (TSys.stdin caps) (fun s ->
    print caps s;
    TSys.flush caps;
    List.iter (fun fd -> TSys.write fd s) fds);
  List.iter TSys.close fds;
  !status

(* a byte as xd -c shows it, in three columns *)
let character c =
  let k = Char.code c in
  if k = 9 then " \\t"
  else if k = 13 then " \\r"
  else if k = 10 then " \\n"
  else if k = 8 then " \\b"
  else if k < 32 || k >= 127 then Printf.sprintf " %02x" k
  else "  " ^ String.make 1 c

(* xd: 16 bytes a line after their address, as numbers of 4 bytes (the
 * last one filled with zeros), or each byte (-b), or each character
 * (-c). The bytes of a line not yet complete are kept from one piece to
 * the next *)
let xd (caps : < filter; .. >) args =
  let flags, files = options "bc" args in
  let size, show =
    if List.mem 'c' flags then 1, (fun g -> character g.[0])
    else if List.mem 'b' flags then
      1, (fun g -> Printf.sprintf " %02x" (Char.code g.[0]))
    else
      4, (fun g ->
        " " ^ String.concat "" (List.init 4 (fun i ->
          if i < String.length g then Printf.sprintf "%02x" (Char.code g.[i])
          else "00"))) in
  let address a = Printf.sprintf "%07x " a in
  each_input caps "xd" (paths_of files) (fun c ->
    let pending = ref "" and addr = ref 0 in
    let line s =
      let groups =
        List.init ((String.length s + size - 1) / size) (fun j ->
          show
            (String.sub s (j * size) (min size (String.length s - (j * size)))))
      in
      print caps (address !addr ^ String.concat "" groups ^ "\n") in
    let rec whole_lines () =
      if String.length !pending >= 16 then begin
        line (String.sub !pending 0 16);
        addr := !addr + 16;
        pending := String.sub !pending 16 (String.length !pending - 16);
        whole_lines ()
      end in
    pieces c (fun s -> pending := !pending ^ s; whole_lines ());
    (* the end: the line that is shorter than 16, empty after a text of
     * whole lines, then the address alone *)
    line !pending;
    print caps (address (!addr + String.length !pending) ^ "\n"))

(*****************************************************************************)
(* grep, sort *)
(*****************************************************************************)

(* the lines that match; -v: that do not; -i: whatever the letters'
 * case; -n: with their numbers; -c: how many; -l: the files' names.
 * The status is 0 when a line was found *)
let grep (caps : < filter; .. >) args =
  let flags, rest = options "vincl" args in
  match rest with
  | [] -> raise Usage
  | pattern :: files ->
      let fold s = if List.mem 'i' flags then String.lowercase_ascii s else s in
      let re = compile (fold pattern) in
      let named name = if List.length files > 1 then name ^ ":" else "" in
      let found = ref false in
      let status =
        each_input caps "grep" (paths_of files) (fun c ->
          let name = Option.map Fpath.to_string (name_of c) ||| "" in
          let count = ref 0 and number = ref 0 in
          lines c (fun line ended ->
            incr number;
            if matches re (fold line) <> List.mem 'v' flags then begin
              incr count;
              found := true;
              if not (List.mem 'c' flags || List.mem 'l' flags) then
                print caps
                  (named name
                   ^ (if List.mem 'n' flags then string_of_int !number ^ ": "
                      else "")
                   ^ line ^ (if ended then "\n" else ""))
            end);
          if List.mem 'c' flags then
            print caps (named name ^ string_of_int !count ^ "\n");
          if List.mem 'l' flags && !count > 0 then print caps (name ^ "\n")) in
      if status <> 0 then status else if !found then 0 else 1

(* the number a text starts with, after blanks: a sign and digits; 0
 * when there is none *)
let number_of text =
  let n = String.length text in
  let rec blanks i =
    if i < n && (text.[i] = ' ' || text.[i] = '\t') then blanks (i + 1)
    else i in
  let i = blanks 0 in
  let negative = i < n && text.[i] = '-' in
  let rec digits i acc =
    if i < n && text.[i] >= '0' && text.[i] <= '9' then
      digits (i + 1) ((acc * 10) + Char.code text.[i] - 48)
    else acc in
  let v = digits (if negative then i + 1 else i) 0 in
  if negative then - v else v

(* a line from its field k on: k times, blanks then what is not *)
let from_field k line =
  let n = String.length line in
  let rec skip i k =
    if k = 0 then i
    else begin
      let rec over p i = if i < n && p line.[i] then over p (i + 1) else i in
      let blank c = c = ' ' || c = '\t' in
      skip (over (fun c -> not (blank c)) (over blank i)) (k - 1)
    end in
  let i = skip 0 k in
  String.sub line i (n - i)

(* the lines of all the inputs, in order: by their bytes, or -n by the
 * number they start with; +k: from their field k (the first is 0); -r:
 * reversed; -u: one of the lines the order says equal. A line's key is
 * made once, as a pair the sort compares (the line itself after, so
 * that lines the key says equal are in the order of their bytes) *)
let sort (caps : < filter; .. >) args =
  let flags, rest = options "nru" args in
  let field, files =
    match rest with
    | a :: l when String.length a > 1 && a.[0] = '+' -> begin
        match int_of_string_opt (String.sub a 1 (String.length a - 1)) with
        | Some k when k >= 0 -> k, l
        | _ -> raise Usage
      end
    | _ -> 0, rest in
  let all = ref [] in
  let status =
    each_input caps "sort" (paths_of files) (fun c ->
      lines c (fun line _ -> all := line :: !all)) in
  let key line =
    let text = from_field field line in
    if List.mem 'n' flags then (number_of text, "") else (0, text) in
  let keyed = List.map (fun line -> key line, line) !all in
  let order a b = if List.mem 'r' flags then compare b a else compare a b in
  let sorted = List.sort order keyed in
  (* -u: a line whose key is the one before's is left out *)
  let rec unique = function
    | (k1, l1) :: (k2, _) :: rest when k1 = k2 -> unique ((k1, l1) :: rest)
    | x :: rest -> x :: unique rest
    | [] -> [] in
  List.iter (fun (_, line) -> print caps (line ^ "\n"))
    (if List.mem 'u' flags then unique sorted else sorted);
  status

(*****************************************************************************)
(* Walkers, fold (), each_path() *)
(*****************************************************************************)

(* a directory's entries, their names sorted; the current directory's
 * as paths: alone, as ls and walk say them (a, not ./a) *)
let entries caps (dir : Fpath.t) : string list =
  List.sort compare (TSys.readdir caps dir)
let here caps : Fpath.t list = List.map Fpath.v (entries caps (Fpath.v "."))

let rec fold caps (p : Fpath.t) f =
  let (st : TSys.stat) = TSys.stat caps p in
  let is_dir = st.st_dir and size = st.st_size in
  f p is_dir size (fun () ->
    if is_dir then
      List.map (fun e -> fold caps (Fpath.add_seg p e) f) (entries caps p)
    else [])

(* [each_path caps tool paths f]: f on each path; one that fails is
 * reported, and the status is then 1 *)
let each_path caps tool (paths : Fpath.t list) f : status =
  List.fold_left (fun status p ->
    try f p; status
    with Failure m -> complain caps tool (!!p ^ ": " ^ m); 1) 0 paths

(*****************************************************************************)
(* ls, walk, du *)
(*****************************************************************************)

(* a directory's entries, or a file's name; all of them sorted together,
 * and quoted for rc. -l: each with its kind (d for a directory), its
 * links (how many names it has: more than one, and the others are the
 * same file) and its size *)
let ls (caps : < Cap.stdout; Cap.stderr; Cap.open_in; Cap.readdir; .. >) args =
  let flags, paths = options "l" args in
  let names = ref [] in
  let status =
    if paths = [] then begin names := here caps; 0 end
    else
      each_path caps "ls" (paths_of paths) (fun p ->
        let (st : TSys.stat) = TSys.stat caps p in
        names :=
          (if st.st_dir then List.map (Fpath.add_seg p) (entries caps p)
           else [ p ])
          @ !names) in
  let long name =
    if not (List.mem 'l' flags) then ""
    else begin
      let (st : TSys.stat) = TSys.stat caps name in
      (if st.st_dir then "d" else "-")
      ^ Printf.sprintf "%4d%9d " (TSys.links caps name) st.st_size
    end in
  List.iter (fun name -> print caps (long name ^ quote !!name ^ "\n"))
    (List.sort compare !names);
  status

(* every path under a directory (under the current one, without "./",
 * when none is named), a directory before what it has *)
let walk
    (caps : < Cap.stdout; Cap.stderr; Cap.open_in; Cap.readdir; .. >) args =
  let _, paths = options "" args in
  let pre p _ _ entries = print caps (!!p ^ "\n"); ignore (entries ()) in
  if paths = [] then begin
    List.iter (fun e -> fold caps e pre) (here caps); 0
  end
  else
    each_path caps "walk" (paths_of paths) (fun p ->
      let (st : TSys.stat) = TSys.stat caps p in
      if st.st_dir then
        List.iter (fun e -> fold caps (Fpath.add_seg p e) pre) (entries caps p)
      else print caps (!!p ^ "\n"))

(* the kilobytes under each directory, after what it has; -a: each file
 * too *)
let du (caps : < Cap.stdout; Cap.stderr; Cap.open_in; Cap.readdir; .. >) args =
  let flags, paths = options "a" args in
  let paths = if paths = [] then [ Fpath.v "." ] else paths_of paths in
  each_path caps "du" paths (fun root ->
    ignore
      (fold caps root (fun p is_dir size entries ->
         let k =
           List.fold_left (fun a b -> a + b)
             (if is_dir then 0 else (size + 1023) / 1024) (entries ()) in
         if is_dir || p = root || List.mem 'a' flags then
           print caps (string_of_int k ^ "\t" ^ quote !!p ^ "\n");
         k)))

(*****************************************************************************)
(* rm, mkdir, cp, mv, ln, touch *)
(*****************************************************************************)

(* -r: a directory with what it has, its entries first *)
let rm
    (caps : < Cap.stderr; Cap.open_in; Cap.readdir; Cap.open_out; .. >) args =
  let flags, paths = options "r" args in
  if paths = [] then raise Usage;
  each_path caps "rm" (paths_of paths) (fun root ->
    if List.mem 'r' flags then
      fold caps root (fun p _ _ entries ->
        ignore (entries ()); TSys.remove caps p)
    else TSys.remove caps root)

(* -p: the directories above it too, and no complaint when it is there *)
let mkdir (caps : < Cap.stderr; Cap.readdir; Cap.open_out; .. >) args =
  let flags, dirs = options "p" args in
  if dirs = [] then raise Usage;
  each_path caps "mkdir" (paths_of dirs) (fun dir ->
    if List.mem 'p' flags then begin
      (* each part of the path up to a slash, then the whole *)
      let dir = !!dir in
      let rec make i =
        if i <= String.length dir then begin
          if i = String.length dir || dir.[i] = '/' then begin
            let d = String.sub dir 0 i in
            if not (TSys.is_directory caps (path d)) then
              TSys.mkdir caps (path d)
          end;
          make (i + 1)
        end in
      make 1
    end
    else TSys.mkdir caps dir)

(* [into_last caps tool paths f]: f from dest for each path but the last,
 * dest being the last path, or the source's name in it when the last
 * is a directory; several sources need a directory *)
let into_last caps tool (paths : Fpath.t list) f : status =
  match List.rev paths with
  | dest :: sources when sources <> [] ->
      let into = TSys.is_directory caps dest in
      if List.length sources > 1 && not into then begin
        complain caps tool (!!dest ^ ": not a directory"); 1
      end
      else
        each_path caps tool (List.rev sources) (fun from ->
          f from (if into then Fpath.add_seg dest (last_part !!from) else dest))
  | _ -> raise Usage

(* a path's names from the root: the current directory's first when it
 * is relative, "." dropped and ".." resolved by the text *)
let resolved caps (p : Fpath.t) =
  let p = !!p in
  let p =
    if p <> "" && p.[0] = '/' then p
    else !!(TSys.getcwd caps) ^ "/" ^ p in
  List.fold_left (fun acc n ->
      if n = "" || n = "." then acc
      else if n = ".." then (match acc with [] -> [] | _ :: r -> r)
      else n :: acc)
    [] (String.split_on_char '/' p)

(* The copy is written a piece at a time as the file is read, so a file
 * of any size is copied in a little memory. A file copied onto itself
 * is refused, as Plan 9's cp does: opening the copy would empty the file
 * before it is read. Only the same path is seen; two names of one file
 * (ln) are not. *)
let cp
    (caps : < Cap.stderr; Cap.open_in; Cap.open_out; Cap.readdir; Cap.env; .. >)
    args =
  let _, paths = options "" args in
  into_last caps "cp" (paths_of paths) (fun from dest ->
    let (st : TSys.stat) = TSys.stat caps from in
    if st.st_dir then failwith "is a directory";
    if resolved caps from = resolved caps dest then failwith "the same file";
    (* (descriptors: each_path says a failure after the source's name,
     * where a channel's open would say its own file again) *)
    let src = TSys.open_in caps from in
    let fd =
      (try TSys.open_out caps dest
       with Failure m -> TSys.close src; failwith m) in
    let rec copy () =
      let s = TSys.read src 8192 in
      if s <> "" then begin TSys.write fd s; copy () end in
    copy ();
    TSys.close fd;
    TSys.close src)

let mv (caps : < Cap.stderr; Cap.readdir; Cap.open_out; .. >) args =
  let _, paths = options "" args in
  into_last caps "mv" (paths_of paths) (fun from dest ->
    TSys.rename caps from dest)

(* a second name for a file: its bytes are not copied, and a change by
 * one name is seen by the other *)
let ln (caps : < Cap.stderr; Cap.readdir; Cap.open_out; .. >) args =
  let _, paths = options "" args in
  into_last caps "ln" (paths_of paths) (fun from dest ->
    TSys.link caps from dest)

let touch (caps : < Cap.stderr; Cap.open_in; Cap.open_out; .. >) args =
  let _, files = options "" args in
  if files = [] then raise Usage;
  each_path caps "touch" (paths_of files) (fun file ->
    TSys.touch caps file)

(*****************************************************************************)
(* Processes, ps, kill *)
(*****************************************************************************)

(* the processes, a line each in /dev/ps (or the file given, a copy of
 * it): its pid, its parent's, its state, its memory in KB, its command
 * line, in the scheduler's order; printed by pid, in columns under
 * their names, the numbers to the right, a program by its name alone
 * (-a: its whole command line, as Plan 9's ps -a) *)
let ps (caps : < filter; .. >) args =
  let flags, files = options "a" args in
  let file =
    match files with
    | [] -> Fpath.v "/dev/ps" | [ f ] -> path f | _ -> raise Usage in
  let rows = ref [] in
  let status =
    each_input caps "ps" [ file ] (fun c ->
      lines c (fun line _ ->
        match String.split_on_char ' ' line with
        | pid :: parent :: state :: kb :: cmd ->
            let cmd =
              if List.mem 'a' flags then String.concat " " cmd
              else match cmd with c :: _ -> last_part c | [] -> "" in
            rows := (pid, parent, state, kb, cmd) :: !rows
        | _ -> ())) in
  let pid (p, _, _, _, _) =
    int_of_string_opt p ||| 0 in
  let all =
    ("PID", "PARENT", "STATE", "KB", "CMD")
    :: List.sort (fun a b -> compare (pid a) (pid b)) !rows in
  let width column =
    List.fold_left (fun w row -> max w (String.length (column row))) 0 all in
  let wpid = width (fun (p, _, _, _, _) -> p)
  and wparent = width (fun (_, p, _, _, _) -> p)
  and wstate = width (fun (_, _, s, _, _) -> s)
  and wkb = width (fun (_, _, _, k, _) -> k) in
  let right w s = String.make (w - String.length s) ' ' ^ s in
  if status = 0 then List.iter (fun (pid, parent, state, kb, cmd) ->
    print caps (right wpid pid ^ " " ^ right wparent parent ^ " " ^ state
                ^ String.make (wstate - String.length state + 1) ' '
                ^ right wkb kb ^ " " ^ cmd ^ "\n")) all;
  status

(* each process named by its pid ended, as a fault ends one *)
let kill (caps : < Cap.stderr; Cap.kill; .. >) args =
  if args = [] then raise Usage;
  List.fold_left (fun status a ->
    match int_of_string_opt a with
    | Some pid when TSys.kill caps pid -> status
    | _ -> complain caps "kill" (a ^ ": no such process"); 1) 0 args

(*****************************************************************************)
(* The rest *)
(*****************************************************************************)

let pwd (caps : < Cap.stdout; Cap.env; .. >) args =
  if args <> [] then raise Usage;
  print caps (!!(TSys.getcwd caps) ^ "\n");
  0

(* seconds, and thousandths after a point: sleep .5 *)
let sleep (caps : < Cap.clock; .. >) args =
  match args with
  | [ a ] ->
      let point = String.index_opt a '.' ||| String.length a in
      let thousandths =
        String.sub
          (String.sub a (min (point + 1) (String.length a))
             (String.length a - min (point + 1) (String.length a))
           ^ "000") 0 3 in
      (match
         int_of_string_opt ("0" ^ String.sub a 0 point),
         int_of_string_opt thousandths
       with
       | Some s, Some ms when ms >= 0 ->
           TSys.sleep caps ((s * 1000) + ms); 0
       | _ -> raise Usage)
  | _ -> raise Usage

(* the date as Plan 9's date writes it, in GMT: now, or the seconds
 * given, since 2000-01-01 as the system counts them (TSys.time:
 * Unix's minus 946,684,800); -n: the seconds *)
let day_names = [ "Sun"; "Mon"; "Tue"; "Wed"; "Thu"; "Fri"; "Sat" ]
let month_names =
  [ "Jan"; "Feb"; "Mar"; "Apr"; "May"; "Jun";
    "Jul"; "Aug"; "Sep"; "Oct"; "Nov"; "Dec" ]

let date (caps : < Cap.stdout; Cap.clock; .. >) args =
  let flags, rest = options "n" args in
  let t =
    match rest with
    | [] -> TSys.time caps
    | [ a ] ->
        (match int_of_string_opt a with
         | Some t when t >= 0 -> t
         | _ -> raise Usage)
    | _ -> raise Usage in
  if List.mem 'n' flags then print caps (string_of_int t ^ "\n")
  else begin
    let days = t / 86400 and secs = t mod 86400 in
    let leap y = (y mod 4 = 0 && y mod 100 <> 0) || y mod 400 = 0 in
    (* the year, then the month, each taken off the days while they last *)
    let rec year y d =
      let n = if leap y then 366 else 365 in
      if d < n then y, d else year (y + 1) (d - n) in
    let y, d = year 2000 days in
    let rec month m d lengths =
      match lengths with
      | n :: rest when d >= n -> month (m + 1) (d - n) rest
      | _ -> m, d in
    let m, d =
      month 0 d
        [ 31; (if leap y then 29 else 28); 31; 30; 31; 30;
          31; 31; 30; 31; 30; 31 ] in
    let two n = (if n < 10 then "0" else "") ^ string_of_int n in
    (* (2000-01-01 was a Saturday) *)
    print caps
      (List.nth day_names ((days + 6) mod 7) ^ " " ^ List.nth month_names m
       ^ " " ^ (if d < 9 then " " else "") ^ string_of_int (d + 1) ^ " "
       ^ two (secs / 3600) ^ ":" ^ two (secs / 60 mod 60) ^ ":"
       ^ two (secs mod 60) ^ " GMT " ^ string_of_int y ^ "\n")
  end;
  0

(* test: a question about files, strings or numbers, answered by the
 * status alone. Its arguments are an expression, read by recursive
 * descent, -o binding less than -a, which binds less than !:
 *
 *     either   := both [-o either]
 *     both     := negation [-a both]
 *     negation := ! negation | primary
 *     primary  := ( either ) | -e f | -f f | -d f | -s f | -n s | -z s
 *               | s = s | s != s | n -eq n (-ne -gt -lt -ge -le) | s
 *
 * The questions kept are those tiny-kernel can answer: it has no
 * permissions and no times *)
let test (caps : < Cap.open_in; .. >) args =
  let rest = ref args in
  let peek () = match !rest with a :: _ -> Some a | [] -> None in
  let next () = match !rest with a :: l -> rest := l; a | [] -> raise Usage in
  let file f : TSys.stat option =
    try Some (TSys.stat caps (path f)) with Failure _ -> None in
  let number s =
    match int_of_string_opt s with Some n -> n | None -> raise Usage in
  let rec either () =
    let p = both () in
    if peek () = Some "-o" then begin
      ignore (next ()); let q = either () in p || q
    end
    else p
  and both () =
    let p = negation () in
    if peek () = Some "-a" then begin
      ignore (next ()); let q = both () in p && q
    end
    else p
  and negation () =
    if peek () = Some "!" then begin ignore (next ()); not (negation ()) end
    else primary ()
  and primary () =
    match next () with
    | "(" -> let p = either () in if next () <> ")" then raise Usage; p
    | "-e" -> file (next ()) <> None
    | "-f" ->
        (match file (next ()) with
         | Some st -> not st.st_dir
         | None -> false)
    | "-d" ->
        (match file (next ()) with Some st -> st.st_dir | None -> false)
    | "-s" ->
        (match file (next ()) with Some st -> st.st_size > 0 | None -> false)
    | "-n" -> next () <> ""
    | "-z" -> next () = ""
    | a -> begin
        match peek () with
        | Some "=" -> ignore (next ()); a = next ()
        | Some "!=" -> ignore (next ()); a <> next ()
        | Some op
          when List.mem op [ "-eq"; "-ne"; "-gt"; "-lt"; "-ge"; "-le" ] ->
            ignore (next ());
            let m = number a and n = number (next ()) in
            if op = "-eq" then m = n
            else if op = "-ne" then m <> n
            else if op = "-gt" then m > n
            else if op = "-lt" then m < n
            else if op = "-ge" then m >= n
            else m <= n
        | _ -> a <> ""
      end in
  if args = [] then 1
  else begin
    let p = either () in
    if !rest <> [] then raise Usage;
    if p then 0 else 1
  end

(* test, run as [ expression ] *)
let bracket (caps : < Cap.open_in; .. >) args =
  match List.rev args with
  | "]" :: l -> test caps (List.rev l)
  | _ -> raise Usage

let echo (caps : < Cap.stdout; .. >) args =
  let newline, words =
    match args with "-n" :: rest -> false, rest | _ -> true, args in
  print caps (String.concat " " words ^ (if newline then "\n" else ""));
  0

let seq (caps : < Cap.stdout; .. >) args =
  let numbers =
    List.map (fun a ->
      match int_of_string_opt a with Some n -> n | None -> raise Usage) args in
  let first, step, last =
    match numbers with
    | [ l ] -> 1, 1, l
    | [ f; l ] -> f, 1, l
    | [ f; s; l ] -> f, s, l
    | _ -> raise Usage in
  if step = 0 then raise Usage;
  let rec go i =
    if (step > 0 && i <= last) || (step < 0 && i >= last) then begin
      print caps (string_of_int i ^ "\n"); go (i + step)
    end in
  go first;
  0

(* the last part of a path, without the suffix; -d: all but the last part *)
let basename (caps : < Cap.stdout; .. >) args =
  let dir, args =
    match args with "-d" :: rest -> true, rest | _ -> false, args in
  let name, suffix =
    match args with [ n ] -> n, "" | [ n; s ] -> n, s | _ -> raise Usage in
  let last = last_part name in
  print caps
    ((if dir then
        (match String.rindex_opt name '/' with
         | Some i -> String.sub name 0 i
         | None -> ".")
      else if suffix <> "" && Filename.check_suffix last suffix then
        String.sub last 0 (String.length last - String.length suffix)
      else last) ^ "\n");
  0

(* the first byte where two files differ, or the one that ends first;
 * -s: only the status. Read a piece at a time, side by side (old: each
 * file whole: a compiler's output was more than a program's 1 MB on
 * tiny-kernel) *)
type compared = Same_bytes | Differ_at of int | Ends_first of string * int

let cmp (caps : < Cap.stdout; Cap.stderr; Cap.open_in; .. >) args =
  let flags, files = options "s" args in
  match files with
  | [ f1; f2 ] -> begin
      let f1 = path f1 and f2 = path f2 in
      (* pos bytes the same so far; sa and sb what is read past them *)
      let compare fa fb =
        let rec go pos sa sb =
          let sa = if sa = "" then piece fa 4096 else sa
          and sb = if sb = "" then piece fb 4096 else sb in
          let n = min (String.length sa) (String.length sb) in
          let rec first i =
            if i < n && sa.[i] = sb.[i] then first (i + 1) else i in
          let i = first 0 in
          if i < n then Differ_at (pos + i)
          else if n = 0 then
            (if sa = "" && sb = "" then Same_bytes
             else Ends_first (!!(if sa = "" then f1 else f2), pos))
          else
            go (pos + n) (String.sub sa n (String.length sa - n))
              (String.sub sb n (String.length sb - n)) in
        go 0 "" "" in
      (* (an open's failure names its file: "cmp: f1: reason") *)
      match
        (try
           Some
             (TSys.with_open_in caps (fun fa ->
                TSys.with_open_in caps (compare fa) f2)
                f1)
         with Failure m -> complain caps "cmp" m; None)
      with
      | None -> 1
      | Some r ->
          let say s = if not (List.mem 's' flags) then print caps (s ^ "\n") in
          match r with
          | Same_bytes -> 0
          | Differ_at i ->
              say (!!f1 ^ " " ^ !!f2 ^ " differ: char "
                   ^ string_of_int (i + 1));
              1
          | Ends_first (f, n) ->
              say ("EOF on " ^ f ^ " after " ^ string_of_int n ^ " bytes"); 1
    end
  | _ -> raise Usage

(*****************************************************************************)
(* The driver *)
(*****************************************************************************)

(* a utility: its name, its arguments, what it does, and itself *)
type utility = {
  name : string;
  usage : string;
  what : string;
  run : caps -> string list -> status;
}

let utility name usage what run = { name; usage; what; run }

let utilities =
  [ utility "basename" "[-d] name [suffix]" "the last part of a path" basename;
    utility "cat" "[file ...]" "the files, one after the other" cat;
    utility "[" "expression ]" "test" bracket;
    utility "cmp" "[-s] file1 file2" "where two files differ" cmp;
    utility "cp" "from to | from ... dir" "files copied" cp;
    utility "date" "[-n] [seconds]"
      "the date, now or of seconds since 2000" date;
    utility "du" "[-a] [path ...]" "the kilobytes under each directory" du;
    utility "echo" "[-n] [word ...]" "the words" echo;
    utility "grep" "[-vincl] pattern [file ...]" "the lines that match" grep;
    utility "kill" "pid ..." "processes ended" kill;
    utility "ln" "old new | old ... dir" "second names for files" ln;
    utility "ls" "[-l] [path ...]" "a directory's entries, sorted" ls;
    utility "mkdir" "[-p] dir ..." "new directories" mkdir;
    utility "mv" "from to | from ... dir" "files renamed" mv;
    utility "ps" "[-a] [file]" "the processes, from /dev/ps" ps;
    utility "pwd" "" "the directory the process is in" pwd;
    utility "rm" "[-r] path ..." "files removed" rm;
    utility "seq" "[first [step]] last" "the numbers from first to last" seq;
    utility "sleep" "seconds[.thousandths]" "nothing, for that long" sleep;
    utility "sort" "[-nru] [+field] [file ...]" "the lines in order" sort;
    utility "tail" "[-n N | -N | +N] [file]"
      "the last lines, or from line N" tail;
    utility "tee" "[file ...]" "the input, to the files too" tee;
    utility "test" "expression" "whether it is true, by the status" test;
    utility "touch" "file ..." "files written now, or made" touch;
    utility "walk" "[path ...]" "every path under a directory" walk;
    utility "wc" "[-lwc] [file ...]" "the lines, words and bytes" wc;
    utility "xd" "[-b | -c] [file ...]" "the bytes, in hexadecimal" xd ]

let find name = List.find_opt (fun u -> u.name = name) utilities

let help () =
  "usage: tiny-utils name [arg ...], or name [arg ...] by a link named after it\n"
  ^ String.concat "" (List.map (fun u ->
      let line = u.name ^ " " ^ u.usage in
      "  " ^ line ^ String.make (max 1 (32 - String.length line)) ' ' ^ u.what
      ^ "\n")
      utilities)

(* (each utility's status a number: test's answer is one) *)
let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  let status =
    match Array.to_list argv with
    | [] -> 1
    | arg0 :: args -> begin
        (* the utility is the name the program was run by, else its first
         * argument *)
        let called = last_part arg0 in
        let name, args =
          match find called, args with
          | Some _, _ -> called, args
          | None, n :: rest -> n, rest
          | None, [] -> "", [] in
        match find name with
        | Some u -> begin
            try u.run (caps :> caps) args with
            | Usage ->
                TSys.eprint caps ("usage: " ^ u.name ^ " " ^ u.usage ^ "\n");
                1
            | Failure m -> complain caps u.name m; 1
          end
        | None when name = "-h" || name = "--help" ->
            TSys.print caps (help ()); 0
        | None -> TSys.eprint caps (help ()); 1
      end in
  TSys.flush caps;
  match status with 0 -> Exit.OK | n -> Exit.Code n

let () = TSys.main "tiny-utils" main
