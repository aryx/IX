(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyUtilities.mli *)

(* (grep's patterns: compile, matches) *)
open TinyLibRegex

type caps = < Cap.open_in; Cap.open_out; Cap.readdir; Cap.stdin; Cap.stdout; Cap.stderr >

(* raised by a utility given arguments it does not take: the driver
 * then prints the utility's usage *)
exception Usage

(*****************************************************************************)
(* Helpers *)
(*****************************************************************************)

let print caps s = TinyLibSystem.print caps s
let complain caps tool s = TinyLibSystem.eprint caps (tool ^ ": " ^ s ^ "\n")

(* s with spaces in front, so that it is at least w characters wide *)
let pad w s = String.make (max 0 (w - String.length s)) ' ' ^ s

let digits = "0123456789abcdef"

(* n in hexadecimal, with exactly w digits *)
let hex w n =
  let rec go w n acc = if w = 0 then acc else go (w - 1) (n / 16) (String.make 1 digits.[n mod 16] ^ acc) in
  go w n ""

(* the index of the last c in s at or before i, or -1 *)
let rec rindex s c i = if i < 0 || s.[i] = c then i else rindex s c (i - 1)

(* what follows the last slash of a path *)
let last_part path =
  let slash = rindex path '/' (String.length path - 1) in
  String.sub path (slash + 1) (String.length path - slash - 1)

(* a name as rc reads it back: between quotes, a quote doubled, when it
 * is empty or has a space, a control character or a quote *)
let quote name =
  if name <> "" && not (String.exists (fun c -> c <= ' ' || c = '\'') name) then name
  else "'" ^ String.concat "''" (String.split_on_char '\'' name) ^ "'"

let ends_with s suffix =
  let n = String.length s and m = String.length suffix in
  n >= m && String.sub s (n - m) m = suffix

(* [options letters args]: the letters of the options in front of args,
 * each of which must be one of letters, and the arguments after them.
 * "--" ends the options, and "-" alone is an argument *)
let options letters args =
  let rec go acc args =
    match args with
    | "--" :: rest -> acc, rest
    | a :: rest when String.length a > 1 && a.[0] = '-' ->
        let given = List.init (String.length a - 1) (fun i -> a.[i + 1]) in
        if List.for_all (fun c -> String.contains letters c) given then go (acc @ given) rest else raise Usage
    | _ -> acc, args in
  go [] args

(*****************************************************************************)
(* Filters *)
(*****************************************************************************)

(* [pieces fd f]: f on each piece of what fd gives, as soon as it is
 * read, until the end *)
let rec pieces fd f =
  let s = TinyLibSystem.read fd 8192 in
  if s <> "" then begin f s; pieces fd f end

(* [lines fd f]: f on each line of fd, without its newline, as soon as
 * it is whole, and whether a newline ended it: the last one may have
 * none *)
let lines fd f =
  let rest = ref "" in
  pieces fd (fun s ->
    let s = !rest ^ s in
    let rec go i =
      match String.index_from_opt s i '\n' with
      | Some j -> f (String.sub s i (j - i)) true; go (j + 1)
      | None -> rest := String.sub s i (String.length s - i) in
    go 0);
  if !rest <> "" then f !rest false

let each_input caps tool files f =
  let one status name fd =
    try f name fd; status with Failure m -> complain caps tool ((if name = "" then "stdin" else name) ^ ": " ^ m); 1 in
  if files = [] then one 0 "" 0
  else
    List.fold_left (fun status file ->
      match (try Some (TinyLibSystem.open_in caps file) with Failure m -> complain caps tool (file ^ ": " ^ m); None) with
      | None -> 1
      | Some fd -> let status = one status file fd in TinyLibSystem.close fd; status) 0 files

let cat caps args =
  let _, files = options "" args in
  each_input caps "cat" files (fun _ fd -> pieces fd (fun s -> print caps s; TinyLibSystem.flush ()))

(* the counts so far, and whether the last byte counted was inside a
 * word: a word can be cut in two by the end of a piece *)
type counts = { mutable lines : int; mutable words : int; mutable bytes : int; mutable inword : bool }

let counts () = { lines = 0; words = 0; bytes = 0; inword = false }

let count c s =
  for i = 0 to String.length s - 1 do
    let k = Char.code s.[i] in
    if k = 10 then c.lines <- c.lines + 1;
    if k = 32 || (k >= 9 && k <= 13) then c.inword <- false
    else if not c.inword then begin c.words <- c.words + 1; c.inword <- true end
  done;
  c.bytes <- c.bytes + String.length s

let wc caps args =
  let asked, files = options "lwc" args in
  let asked = if asked = [] then [ 'l'; 'w'; 'c' ] else asked in
  let report c name =
    let columns = List.filter (fun (letter, _) -> List.mem letter asked) [ 'l', c.lines; 'w', c.words; 'c', c.bytes ] in
    let columns = List.map (fun (_, n) -> pad 7 (string_of_int n)) columns in
    print caps (String.concat " " (columns @ (if name = "" then [] else [ name ])) ^ "\n") in
  let total = counts () and files_counted = ref 0 in
  let status =
    each_input caps "wc" files (fun name fd ->
      let c = counts () in
      pieces fd (count c);
      report c name;
      incr files_counted;
      total.lines <- total.lines + c.lines;
      total.words <- total.words + c.words;
      total.bytes <- total.bytes + c.bytes) in
  if !files_counted > 1 then report total "total";
  status

(* the text from its nth line from the end, or from its nth line (+n).
 * tail is the one filter that reads all its input first: until the
 * end, it cannot know which lines are the last *)
let lines_of from_end n s =
  let len = String.length s in
  let start =
    if from_end then begin
      (* back from the end over n newlines, the one that ends the text
       * not counted *)
      let rec back i k = if i < 0 then 0 else if s.[i] = '\n' then (if k = n then i + 1 else back (i - 1) (k + 1)) else back (i - 1) k in
      if n = 0 then len else back (if len > 0 && s.[len - 1] = '\n' then len - 2 else len - 1) 1
    end
    else begin
      let rec skip i k = if k <= 1 || i >= len then i else if s.[i] = '\n' then skip (i + 1) (k - 1) else skip (i + 1) k in
      skip 0 n
    end in
  String.sub s start (len - start)

let tail caps args =
  let from_end, n, files =
    match args with
    | "-n" :: n :: rest -> true, n, rest
    | a :: rest when String.length a > 1 && (a.[0] = '-' || a.[0] = '+') -> a.[0] = '-', String.sub a 1 (String.length a - 1), rest
    | _ -> true, "10", args in
  match int_of_string_opt n, files with
  | Some n, ([] | [ _ ]) when n >= 0 ->
      each_input caps "tail" files (fun _ fd -> print caps (lines_of from_end n (TinyLibSystem.read_all fd)))
  | _ -> raise Usage

let tee caps args =
  let _, files = options "" args in
  let status = ref 0 in
  let fds =
    List.concat_map (fun file ->
      try [ TinyLibSystem.open_out caps file ] with Failure m -> complain caps "tee" (file ^ ": " ^ m); status := 1; []) files in
  pieces 0 (fun s -> print caps s; TinyLibSystem.flush (); List.iter (fun fd -> TinyLibSystem.write fd s) fds);
  List.iter TinyLibSystem.close fds;
  !status

(* a byte as xd -c shows it, in three columns *)
let character c =
  let k = Char.code c in
  if k = 9 then " \\t" else if k = 13 then " \\r" else if k = 10 then " \\n" else if k = 8 then " \\b"
  else if k < 32 || k >= 127 then " " ^ hex 2 k
  else "  " ^ String.make 1 c

(* xd: 16 bytes a line after their address, as numbers of 4 bytes (the
 * last one filled with zeros), or each byte (-b), or each character
 * (-c). The bytes of a line not yet complete are kept from one piece to
 * the next *)
let xd caps args =
  let flags, files = options "bc" args in
  let size, show =
    if List.mem 'c' flags then 1, (fun g -> character g.[0])
    else if List.mem 'b' flags then 1, (fun g -> " " ^ hex 2 (Char.code g.[0]))
    else 4, (fun g -> " " ^ String.concat "" (List.init 4 (fun i -> if i < String.length g then hex 2 (Char.code g.[i]) else "00"))) in
  let address a = hex 7 a ^ " " in
  each_input caps "xd" files (fun _ fd ->
    let pending = ref "" and addr = ref 0 in
    let line s =
      let groups = List.init ((String.length s + size - 1) / size) (fun j -> show (String.sub s (j * size) (min size (String.length s - (j * size))))) in
      print caps (address !addr ^ String.concat "" groups ^ "\n") in
    let rec whole_lines () =
      if String.length !pending >= 16 then begin
        line (String.sub !pending 0 16);
        addr := !addr + 16;
        pending := String.sub !pending 16 (String.length !pending - 16);
        whole_lines ()
      end in
    pieces fd (fun s -> pending := !pending ^ s; whole_lines ());
    (* the end: the line that is shorter than 16, empty after a text of
     * whole lines, then the address alone *)
    line !pending;
    print caps (address (!addr + String.length !pending) ^ "\n"))

(* the bytes of s, the capitals made small *)
let lowercase s =
  String.concat "" (List.init (String.length s) (fun i ->
    let c = s.[i] in String.make 1 (if c >= 'A' && c <= 'Z' then Char.chr (Char.code c + 32) else c)))

(* the lines that match; -v: that do not; -i: whatever the letters'
 * case; -n: with their numbers; -c: how many; -l: the files' names.
 * The status is 0 when a line was found *)
let grep caps args =
  let flags, rest = options "vincl" args in
  match rest with
  | [] -> raise Usage
  | pattern :: files ->
      let fold s = if List.mem 'i' flags then lowercase s else s in
      let re = compile (fold pattern) in
      let named name = if List.length files > 1 then name ^ ":" else "" in
      let found = ref false in
      let status =
        each_input caps "grep" files (fun name fd ->
          let count = ref 0 and number = ref 0 in
          lines fd (fun line ended ->
            incr number;
            if matches re (fold line) <> List.mem 'v' flags then begin
              incr count;
              found := true;
              if not (List.mem 'c' flags || List.mem 'l' flags) then
                print caps (named name ^ (if List.mem 'n' flags then string_of_int !number ^ ": " else "") ^ line ^ (if ended then "\n" else ""))
            end);
          if List.mem 'c' flags then print caps (named name ^ string_of_int !count ^ "\n");
          if List.mem 'l' flags && !count > 0 then print caps (name ^ "\n")) in
      if status <> 0 then status else if !found then 0 else 1

(* the number a text starts with, after blanks: a sign and digits; 0
 * when there is none *)
let number_of text =
  let n = String.length text in
  let rec blanks i = if i < n && (text.[i] = ' ' || text.[i] = '\t') then blanks (i + 1) else i in
  let i = blanks 0 in
  let negative = i < n && text.[i] = '-' in
  let rec digits i acc = if i < n && text.[i] >= '0' && text.[i] <= '9' then digits (i + 1) ((acc * 10) + Char.code text.[i] - 48) else acc in
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
let sort caps args =
  let flags, rest = options "nru" args in
  let field, files =
    match rest with
    | a :: l when String.length a > 1 && a.[0] = '+' -> begin
        match int_of_string_opt (String.sub a 1 (String.length a - 1)) with Some k when k >= 0 -> k, l | _ -> raise Usage
      end
    | _ -> 0, rest in
  let all = ref [] in
  let status = each_input caps "sort" files (fun _ fd -> lines fd (fun line _ -> all := line :: !all)) in
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
  List.iter (fun (_, line) -> print caps (line ^ "\n")) (if List.mem 'u' flags then unique sorted else sorted);
  status

(*****************************************************************************)
(* Walkers *)
(*****************************************************************************)

let join dir name = if dir <> "" && dir.[String.length dir - 1] = '/' then dir ^ name else dir ^ "/" ^ name
let entries dir = List.sort compare (TinyLibSystem.readdir dir)

let rec fold path f =
  let is_dir, size = TinyLibSystem.stat path in
  f path is_dir size (fun () -> if is_dir then List.map (fun e -> fold (join path e) f) (entries path) else [])

(* [each_path caps tool paths f]: f on each path; one that fails is
 * reported, and the status is then 1 *)
let each_path caps tool paths f =
  List.fold_left (fun status p -> try f p; status with Failure m -> complain caps tool (p ^ ": " ^ m); 1) 0 paths

(* a directory's entries, or a file's name; all of them sorted together,
 * and quoted for rc. -l: each with its kind (d for a directory), its
 * links (how many names it has: more than one, and the others are the
 * same file) and its size *)
let ls caps args =
  let flags, paths = options "l" args in
  let names = ref [] in
  let status =
    if paths = [] then begin names := entries "."; 0 end
    else
      each_path caps "ls" paths (fun p ->
        let is_dir, _ = TinyLibSystem.stat p in
        names := (if is_dir then List.map (join p) (entries p) else [ p ]) @ !names) in
  let long name =
    if not (List.mem 'l' flags) then ""
    else begin
      let is_dir, size = TinyLibSystem.stat name in
      (if is_dir then "d" else "-") ^ pad 4 (string_of_int (TinyLibSystem.links name)) ^ pad 9 (string_of_int size) ^ " "
    end in
  List.iter (fun name -> print caps (long name ^ quote name ^ "\n")) (List.sort compare !names);
  status

(* every path under a directory (under the current one, without "./",
 * when none is named), a directory before what it has *)
let walk caps args =
  let _, paths = options "" args in
  let pre p _ _ entries = print caps (p ^ "\n"); ignore (entries ()) in
  if paths = [] then begin List.iter (fun e -> fold e pre) (entries "."); 0 end
  else
    each_path caps "walk" paths (fun p ->
      let is_dir, _ = TinyLibSystem.stat p in
      if is_dir then List.iter (fun e -> fold (join p e) pre) (entries p) else print caps (p ^ "\n"))

(* the kilobytes under each directory, after what it has; -a: each file
 * too *)
let du caps args =
  let flags, paths = options "a" args in
  let paths = if paths = [] then [ "." ] else paths in
  each_path caps "du" paths (fun root ->
    ignore
      (fold root (fun p is_dir size entries ->
         let k = List.fold_left (fun a b -> a + b) (if is_dir then 0 else (size + 1023) / 1024) (entries ()) in
         if is_dir || p = root || List.mem 'a' flags then print caps (string_of_int k ^ "\t" ^ quote p ^ "\n");
         k)))

(* -r: a directory with what it has, its entries first *)
let rm caps args =
  let flags, paths = options "r" args in
  if paths = [] then raise Usage;
  each_path caps "rm" paths (fun root ->
    if List.mem 'r' flags then fold root (fun p _ _ entries -> ignore (entries ()); TinyLibSystem.remove caps p)
    else TinyLibSystem.remove caps root)

(* -p: the directories above it too, and no complaint when it is there *)
let mkdir caps args =
  let flags, dirs = options "p" args in
  if dirs = [] then raise Usage;
  each_path caps "mkdir" dirs (fun dir ->
    if List.mem 'p' flags then begin
      (* each part of the path up to a slash, then the whole *)
      let rec make i =
        if i <= String.length dir then begin
          if i = String.length dir || dir.[i] = '/' then begin
            let d = String.sub dir 0 i in
            if not (TinyLibSystem.is_directory d) then TinyLibSystem.mkdir caps d
          end;
          make (i + 1)
        end in
      make 1
    end
    else TinyLibSystem.mkdir caps dir)

(* [into_last caps tool paths f]: f from dest for each path but the last,
 * dest being the last path, or the source's name in it when the last
 * is a directory; several sources need a directory *)
let into_last caps tool paths f =
  match List.rev paths with
  | dest :: sources when sources <> [] ->
      let into = TinyLibSystem.is_directory dest in
      if List.length sources > 1 && not into then begin complain caps tool (dest ^ ": not a directory"); 1 end
      else each_path caps tool (List.rev sources) (fun from -> f from (if into then join dest (last_part from) else dest))
  | _ -> raise Usage

(* the whole file is read before the copy is opened, so a file copied
 * onto itself is not lost, with no question of which file is which *)
let cp caps args =
  let _, paths = options "" args in
  into_last caps "cp" paths (fun from dest ->
    if fst (TinyLibSystem.stat from) then failwith "is a directory";
    let text = TinyLibSystem.read_file caps from in
    let fd = TinyLibSystem.open_out caps dest in
    TinyLibSystem.write fd text;
    TinyLibSystem.close fd)

let mv caps args =
  let _, paths = options "" args in
  into_last caps "mv" paths (fun from dest -> TinyLibSystem.rename caps from dest)

(* a second name for a file: its bytes are not copied, and a change by
 * one name is seen by the other *)
let ln caps args =
  let _, paths = options "" args in
  into_last caps "ln" paths (fun from dest -> TinyLibSystem.link caps from dest)

let touch caps args =
  let _, files = options "" args in
  if files = [] then raise Usage;
  each_path caps "touch" files (fun file -> TinyLibSystem.touch caps file)

(*****************************************************************************)
(* The rest *)
(*****************************************************************************)

let pwd caps args =
  if args <> [] then raise Usage;
  print caps (TinyLibSystem.getcwd caps ^ "\n");
  0

(* seconds, and thousandths after a point: sleep .5 *)
let sleep _caps args =
  match args with
  | [ a ] ->
      let point = match String.index_opt a '.' with Some i -> i | None -> String.length a in
      let thousandths = String.sub (String.sub a (min (point + 1) (String.length a)) (String.length a - min (point + 1) (String.length a)) ^ "000") 0 3 in
      (match int_of_string_opt ("0" ^ String.sub a 0 point), int_of_string_opt thousandths with
       | Some s, Some ms when ms >= 0 -> TinyLibSystem.sleep ((s * 1000) + ms); 0
       | _ -> raise Usage)
  | _ -> raise Usage

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
let test _caps args =
  let rest = ref args in
  let peek () = match !rest with a :: _ -> Some a | [] -> None in
  let next () = match !rest with a :: l -> rest := l; a | [] -> raise Usage in
  let file f = try Some (TinyLibSystem.stat f) with Failure _ -> None in
  let number s = match int_of_string_opt s with Some n -> n | None -> raise Usage in
  let rec either () =
    let p = both () in
    if peek () = Some "-o" then begin ignore (next ()); let q = either () in p || q end else p
  and both () =
    let p = negation () in
    if peek () = Some "-a" then begin ignore (next ()); let q = both () in p && q end else p
  and negation () = if peek () = Some "!" then begin ignore (next ()); not (negation ()) end else primary ()
  and primary () =
    match next () with
    | "(" -> let p = either () in if next () <> ")" then raise Usage; p
    | "-e" -> file (next ()) <> None
    | "-f" -> (match file (next ()) with Some (is_dir, _) -> not is_dir | None -> false)
    | "-d" -> (match file (next ()) with Some (is_dir, _) -> is_dir | None -> false)
    | "-s" -> (match file (next ()) with Some (_, size) -> size > 0 | None -> false)
    | "-n" -> next () <> ""
    | "-z" -> next () = ""
    | a -> begin
        match peek () with
        | Some "=" -> ignore (next ()); a = next ()
        | Some "!=" -> ignore (next ()); a <> next ()
        | Some op when List.mem op [ "-eq"; "-ne"; "-gt"; "-lt"; "-ge"; "-le" ] ->
            ignore (next ());
            let m = number a and n = number (next ()) in
            if op = "-eq" then m = n else if op = "-ne" then m <> n else if op = "-gt" then m > n
            else if op = "-lt" then m < n else if op = "-ge" then m >= n else m <= n
        | _ -> a <> ""
      end in
  if args = [] then 1
  else begin
    let p = either () in
    if !rest <> [] then raise Usage;
    if p then 0 else 1
  end

(* test, run as [ expression ] *)
let bracket caps args =
  match List.rev args with
  | "]" :: l -> test caps (List.rev l)
  | _ -> raise Usage

let echo caps args =
  let newline, words = match args with "-n" :: rest -> false, rest | _ -> true, args in
  print caps (String.concat " " words ^ (if newline then "\n" else ""));
  0

let seq caps args =
  let numbers = List.map (fun a -> match int_of_string_opt a with Some n -> n | None -> raise Usage) args in
  let first, step, last = match numbers with [ l ] -> 1, 1, l | [ f; l ] -> f, 1, l | [ f; s; l ] -> f, s, l | _ -> raise Usage in
  if step = 0 then raise Usage;
  let rec go i = if (step > 0 && i <= last) || (step < 0 && i >= last) then begin print caps (string_of_int i ^ "\n"); go (i + step) end in
  go first;
  0

(* the last part of a path, without the suffix; -d: all but the last part *)
let basename caps args =
  let dir, args = match args with "-d" :: rest -> true, rest | _ -> false, args in
  let name, suffix = match args with [ n ] -> n, "" | [ n; s ] -> n, s | _ -> raise Usage in
  let slash = rindex name '/' (String.length name - 1) and last = last_part name in
  print caps
    ((if dir then (if slash < 0 then "." else String.sub name 0 slash)
      else if suffix <> "" && ends_with last suffix then String.sub last 0 (String.length last - String.length suffix)
      else last) ^ "\n");
  0

(* the first byte where two files differ, or the one that ends first;
 * -s: only the status *)
let cmp caps args =
  let flags, files = options "s" args in
  match files with
  | [ f1; f2 ] -> begin
      match (try Some (TinyLibSystem.read_file caps f1, TinyLibSystem.read_file caps f2) with Failure m -> complain caps "cmp" m; None) with
      | None -> 1
      | Some (a, b) ->
          let n = min (String.length a) (String.length b) in
          let rec first i = if i < n && a.[i] = b.[i] then first (i + 1) else i in
          let i = first 0 in
          let say s = if not (List.mem 's' flags) then print caps (s ^ "\n") in
          if i < n then begin say (f1 ^ " " ^ f2 ^ " differ: char " ^ string_of_int (i + 1)); 1 end
          else if String.length a <> String.length b then begin
            say ("EOF on " ^ (if String.length a < String.length b then f1 else f2) ^ " after " ^ string_of_int n ^ " bytes");
            1
          end
          else 0
    end
  | _ -> raise Usage

(*****************************************************************************)
(* The driver *)
(*****************************************************************************)

(* each utility: its name, its arguments, what it does, and itself *)
let utilities =
  [ "basename", "[-d] name [suffix]", "the last part of a path", basename;
    "cat", "[file ...]", "the files, one after the other", cat;
    "[", "expression ]", "test", bracket;
    "cmp", "[-s] file1 file2", "where two files differ", cmp;
    "cp", "from to | from ... dir", "files copied", cp;
    "du", "[-a] [path ...]", "the kilobytes under each directory", du;
    "echo", "[-n] [word ...]", "the words", echo;
    "grep", "[-vincl] pattern [file ...]", "the lines that match", grep;
    "ln", "old new | old ... dir", "second names for files", ln;
    "ls", "[-l] [path ...]", "a directory's entries, sorted", ls;
    "mkdir", "[-p] dir ...", "new directories", mkdir;
    "mv", "from to | from ... dir", "files renamed", mv;
    "pwd", "", "the directory the process is in", pwd;
    "rm", "[-r] path ...", "files removed", rm;
    "seq", "[first [step]] last", "the numbers from first to last", seq;
    "sleep", "seconds[.thousandths]", "nothing, for that long", sleep;
    "sort", "[-nru] [+field] [file ...]", "the lines in order", sort;
    "tail", "[-n N | -N | +N] [file]", "the last lines, or from line N", tail;
    "tee", "[file ...]", "the input, to the files too", tee;
    "test", "expression", "whether it is true, by the status", test;
    "touch", "file ...", "files written now, or made", touch;
    "walk", "[path ...]", "every path under a directory", walk;
    "wc", "[-lwc] [file ...]", "the lines, words and bytes", wc;
    "xd", "[-b | -c] [file ...]", "the bytes, in hexadecimal", xd ]

let rec find name = function
  | [] -> None
  | (n, usage, _, f) :: rest -> if n = name then Some (n, usage, f) else find name rest

let help () =
  "usage: tiny-utils name [arg ...], or name [arg ...] by a link named after it\n"
  ^ String.concat "" (List.map (fun (n, usage, what, _) -> let u = n ^ " " ^ usage in "  " ^ u ^ String.make (max 1 (32 - String.length u)) ' ' ^ what ^ "\n") utilities)

let main (caps : Cap.all_caps) : int =
  let status =
    match TinyLibSystem.argv caps with
    | [] -> 1
    | arg0 :: args -> begin
        (* the utility is the name the program was run by, else its first argument *)
        let called = last_part arg0 in
        let name, args = match find called utilities, args with Some _, _ -> called, args | None, n :: rest -> n, rest | None, [] -> "", [] in
        match find name utilities with
        | Some (n, usage, f) -> begin
            try f (caps :> caps) args with
            | Usage -> TinyLibSystem.eprint caps ("usage: " ^ n ^ " " ^ usage ^ "\n"); 1
            | Failure m -> complain caps n m; 1
          end
        | None when name = "-h" || name = "--help" -> TinyLibSystem.print caps (help ()); 0
        | None -> TinyLibSystem.eprint caps (help ()); 1
      end in
  TinyLibSystem.flush ();
  status

let () = TinyLibSystem.main "tiny-utils" main
