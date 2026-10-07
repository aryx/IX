(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* mini-sort: Plan 9's sort (principia's utilities/text/misc/sort.c):
 * the lines of the files, or of the standard input, in order.
 *
 *   sort [-cmu] [-bdfinrw] [-t c] [-o file] [+pos1 [-pos2]] ... [file ...]
 *
 * Without an option the order is the bytes' (so the characters', in
 * UTF-8). -n: by the number a line starts with (its sign, its digits,
 * a point; -g: an exponent too); -f: capitals and small letters the
 * same; -d: only letters, digits and blanks count; -i: only the
 * visible ASCII; -w: blanks do not count; -b: nor the blanks at a
 * key's start; -r: the order reversed.
 * +pos1 -pos2: a key, from field pos1 to before field pos2 (the first
 * is 0; f.c: c characters into it), with its own letters of the above
 * after (+1n: the second field as a number); several keys, the first
 * decides. A field ends at blanks, or at the character of -t. Lines
 * that the keys do not part are then compared whole.
 * -u: of the lines the keys say equal, one; -c: nothing written, a
 * status that says whether the input is in order; -o file: written
 * there (which may be an input); -k is POSIX's way to say a key
 * (-k 2,3: from 1); -m, -T dir, -l n are taken and mean nothing here.
 * Not sort.c's -M (months).
 *
 * As sort.c: a line's key is made of bytes, once, such that the keys'
 * order as bytes is the lines' (a number's digits after its sign and
 * its exponent, a reversed key's bytes complemented), and the keys are
 * sorted. Not its temporary files: all is in memory. *)

type caps = < Cap.open_in; Cap.open_out; Cap.stdin; Cap.stdout; Cap.stderr >

(* sort.c's done: said, and the status *)
exception Done of string * string

type field = {
  mutable beg1 : int; mutable beg2 : int; mutable end1 : int; mutable end2 : int;   (* fields and characters; -1: none *)
  mutable flags : char list;      (* of b d f g i n r w; B: b for the start *)
}

let has (f : field) c = List.mem c f.flags

(* where a key starts or ends in a line: after n1 fields and n2
 * characters, the blanks there skipped when [blanks]; None when the
 * line ends before (sort.c's skip: a line's end is its newline) *)
let skip line tab n1 n2 blanks ending : int option =
  let len = String.length line in
  let at i = if i < len then line.[i] else '\n' in
  let blank c = c = ' ' || c = '\t' in
  if ending && n1 < 0 then None
  else begin
    let i = ref 0 and gone = ref false in
    (match tab with
     | Some tc ->
         for k = n1 downto 1 do
           while not !gone && at !i <> tc do if at !i = '\n' then gone := true else incr i done;
           if not !gone && not (ending && k = 1) then incr i
         done
     | None ->
         for _k = n1 downto 1 do
           while blank (at !i) do incr i done;
           while not !gone && not (blank (at !i)) do if at !i = '\n' then gone := true else incr i done
         done);
    if blanks then while blank (at !i) do incr i done;
    for _k = n2 downto 1 do
      if not !gone then (if at !i = '\n' then gone := true else i := !i + snd (Utf8.decode line !i))
    done;
    if !gone then None else Some !i
  end

(* a key of text: each character as the letters say (0: not in the key) *)
let text_key (f : field) b line from upto =
  let rev = has f 'r' in
  let put c = Buffer.add_char b (Char.chr (if rev then lnot c land 0xff else c)) in
  let i = ref from in
  while !i < upto do
    let c = Char.code line.[!i] in
    if c < 128 then begin
      incr i;
      let blank = c = 32 || c = 9 in
      let letter = (c >= 97 && c <= 122) || (c >= 65 && c <= 90) || (c >= 48 && c <= 57) in
      let dropped = c = 0 || (has f 'i' && (c < 0o40 || c > 0o176)) || (has f 'w' && blank) || (has f 'd' && not (blank || letter)) in
      if not dropped then put (if has f 'f' && c >= 97 && c <= 122 then c - 32 else c)
    end
    else begin
      (* past ASCII: as it is, unless only ASCII counts (sort.c folds
       * and classes these by Unicode's tables: not here) *)
      let _, w = Utf8.decode line !i in
      if not (has f 'i') then for k = !i to min (upto - 1) (!i + w - 1) do put (Char.code line.[k]) done;
      i := !i + w
    end
  done;
  Buffer.add_char b (if rev then '\255' else '\000')

(* a key of a number (sort.c's dokey_gn): a byte for its sign, two for
 * where its point is, then its digits without the zeros at their end;
 * a negative one's are complemented, so that more is less *)
(* how a key is made *)
type kind = Plain | Number | Text

type state = Start | Sign | Zero | Zerofract | Point | Digit | Fract | Exp | Expsign | Expdigit

let number_key (f : field) b line from upto =
  let digits = Buffer.create 16 in
  let rev = ref (has f 'r') and state = ref Start in
  let nzero = ref 0 and exp = ref 0 and expsign = ref false and dp = ref 0x4040 in
  let digit c = Buffer.add_char digits (Char.chr (if !rev then lnot (Char.code c) land 0xff else Char.code c)) in
  let rec go i =
    if i < upto then begin
      let c = line.[i] in
      (* true: the character was the number's, the next one *)
      let more =
        match c, !state with
        | (' ' | '\t'), (Start | Sign) -> true
        | '-', Start -> state := Sign; rev := not !rev; true
        | '+', Start -> state := Sign; true
        | '-', Exp -> state := Expsign; expsign := true; true
        | '+', Exp -> state := Expsign; true
        | '0', Digit -> digit c; incr nzero; incr dp; true
        | '0', Fract -> digit c; incr nzero; true
        | '0', (Start | Sign | Zero) -> state := Zero; true
        | '0', (Zerofract | Point) -> decr dp; state := Zerofract; true
        | '0' .. '9', (Expsign | Exp | Expdigit) -> exp := (!exp * 10) + Char.code c - 48; state := Expdigit; true
        | '1' .. '9', (Zero | Start | Sign | Digit) -> digit c; nzero := 0; incr dp; state := Digit; true
        | '1' .. '9', (Zerofract | Point | Fract) -> digit c; nzero := 0; state := Fract; true
        | '.', (Start | Sign) -> state := Point; true
        | '.', Zero -> state := Zerofract; true
        | '.', Digit -> state := Fract; true
        | ('e' | 'E'), (Digit | Fract) when has f 'g' -> state := Exp; true
        | _ -> false in
      if more then go (i + 1)
    end in
  go from;
  match !state with
  | Start | Sign | Zero | Zerofract | Point -> Buffer.add_string b " \000"      (* zero: between the negative and the positive *)
  | _ ->
      (match !state with Exp | Expsign | Expdigit -> dp := !dp + (if !expsign then - !exp else !exp) | _ -> ());
      let dp = (if !rev then lnot !dp else !dp) land 0xffff in
      Buffer.add_char b (if !rev then '\016' else '0');
      Buffer.add_char b (Char.chr (dp lsr 8)); Buffer.add_char b (Char.chr (dp land 0xff));
      Buffer.add_string b (Buffer.sub digits 0 (Buffer.length digits - !nzero));
      Buffer.add_char b (if !rev then '\255' else '\000')

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  let said msg = Console.eprint caps ("sort: " ^ msg ^ "\n") in
  try
    let global = { beg1 = -1; beg2 = -1; end1 = -1; end2 = -1; flags = [] } in
    let fields = ref [] and tab = ref None and check = ref false and unique = ref false and output = ref None and files = ref [] in
    let new_field () = let f = { beg1 = -1; beg2 = -1; end1 = -1; end2 = -1; flags = [] } in fields := !fields @ [ f ]; f in
    let current () = match List.rev !fields with f :: _ -> f | [] -> global in
    let set (f : field) c =
      if not (String.contains "bdfginrw" c) then raise (Done (Printf.sprintf "unknown option: field.%c" c, "option"));
      if not (has f c) then f.flags <- c :: f.flags in
    (* a position, f.c, and the letters after it: the fields, the characters *)
    let position s (f : field) off1 off2 =
      let n = String.length s in
      let rec digits k = if k < n && s.[k] >= '0' && s.[k] <= '9' then digits (k + 1) else k in
      let k = digits 0 in
      let n1 = if k > 0 then (let v = int_of_string (String.sub s 0 k) - off1 in if v < 0 then raise (Done ("field offset must be positive", "option")); Some v) else None in
      let n2, k =
        if k < n && s.[k] = '.' then begin
          let j = digits (k + 1) in
          (if j > k + 1 then (let v = int_of_string (String.sub s (k + 1) (j - k - 1)) - off2 in if v < 0 then raise (Done ("character offset must be positive", "option")); Some v) else None), j
        end
        else None, k in
      String.iter (set f) (String.sub s k (n - k));
      n1, n2 in
    (* b said with a key's start is for its start (B) *)
    let start_blanks (f : field) = if has f 'b' then f.flags <- 'B' :: List.filter (fun c -> c <> 'b') f.flags in
    let had_plus = ref false in
    let rec arguments = function
      | [] -> ()
      | "-" :: rest -> files := !files @ rest
      | a :: rest when a.[0] = '-' && String.length a > 1 && (a.[1] = '.' || (a.[1] >= '0' && a.[1] <= '9')) ->
          let f = if !had_plus then current () else new_field () in
          let n1, n2 = position (String.sub a 1 (String.length a - 1)) f 0 0 in
          (match n1 with Some v -> f.end1 <- v | None -> ());
          (match n2 with Some v -> f.end2 <- v | None -> ());
          had_plus := false;
          arguments rest
      | a :: rest when a.[0] = '-' && String.length a > 1 ->
          (* letters; one that takes a value has the rest of the argument, or the next *)
          let rec letters k rest =
            if k >= String.length a then arguments rest
            else begin
              let value () =
                if k + 1 < String.length a then Some (String.sub a (k + 1) (String.length a - k - 1)), rest
                else match rest with v :: rest -> Some v, rest | [] -> None, [] in
              match a.[k] with
              | '-' -> files := !files @ rest
              | 'T' | 'l' -> let _, rest = value () in arguments rest
              | 'o' -> let v, rest = value () in output := v; arguments rest
              | 'k' ->
                  let v, rest = value () in
                  (match v with
                   | None -> ()
                   | Some p ->
                       let f = new_field () in
                       let first, second = match String.index_opt p ',' with
                         | Some j -> String.sub p 0 j, Some (String.sub p (j + 1) (String.length p - j - 1))
                         | None -> p, None in
                       let n1, n2 = position first f 1 1 in
                       (match n1 with Some v -> f.beg1 <- v | None -> ());
                       (match n2 with Some v -> f.beg2 <- v | None -> ());
                       start_blanks f;
                       (match second with
                        | Some q ->
                            let n1, n2 = position q f 1 0 in
                            (match n1 with Some v -> f.end1 <- v | None -> ());
                            (match n2 with Some v -> f.end2 <- v | None -> ());
                            if f.end2 <= 0 then f.end1 <- f.end1 + 1
                        | None -> ()));
                  had_plus := false;
                  arguments rest
              | 't' ->
                  let v, rest = value () in
                  (match v with
                   | Some v when v <> "" -> if v.[0] = '\n' then begin Console.eprint caps "aw come on, rob\n"; raise (Done ("", "rob")) end; tab := Some v.[0]
                   | _ -> ());
                  arguments rest
              | 'c' -> check := true; letters (k + 1) rest
              | 'u' -> unique := true; letters (k + 1) rest
              | 'v' | 'm' -> letters (k + 1) rest
              | ('b' | 'd' | 'f' | 'g' | 'i' | 'n' | 'r' | 'w') as c ->
                  if !fields <> [] then said "global field set after -k";
                  set global c; letters (k + 1) rest
              | c -> raise (Done (Printf.sprintf "unknown option: -%c" c, "option"))
            end in
          letters 1 rest
      | a :: rest when a.[0] = '+' ->
          if String.length a > 1 && (a.[1] = '.' || (a.[1] >= '0' && a.[1] <= '9')) then begin
            let f = new_field () in
            let n1, n2 = position (String.sub a 1 (String.length a - 1)) f 0 0 in
            (match n1 with Some v -> f.beg1 <- v | None -> ());
            (match n2 with Some v -> f.beg2 <- v | None -> ());
            start_blanks f;
            had_plus := true;
            arguments rest
          end
          else raise (Done (Printf.sprintf "unknown option: +%s" (if String.length a > 1 then String.make 1 a.[1] else ""), "option"))
      | a :: rest -> files := !files @ [ a ]; arguments rest in
    arguments (List.filter (fun a -> a <> "") (List.tl (Array.to_list argv)));
    (* a key without letters has the ones said for all *)
    List.iter (fun (f : field) -> if f.flags = [] then begin f.flags <- global.flags; if has global 'b' then f.flags <- 'B' :: f.flags end) !fields;
    let kind (f : field) =
      match List.sort compare (List.filter (fun c -> c <> 'b' && c <> 'B') f.flags) with
      | [] | [ 'r' ] -> Plain
      | l when List.for_all (fun c -> c = 'g' || c = 'n' || c = 'r') l -> Number
      | l when List.for_all (fun c -> c <> 'g' && c <> 'n') l -> Text
      | _ ->
          (* (said with sort.c's own number for the letters: a bit each) *)
          let bit c = match c with 'b' -> 1 | 'B' -> 2 | 'd' -> 4 | 'f' -> 8 | 'g' -> 16 | 'i' -> 32 | 'n' -> 128 | 'r' -> 256 | 'w' -> 512 | _ -> 0 in
          raise (Done (Printf.sprintf "illegal combination of flags: %x" (List.fold_left (fun a c -> a lor bit c) 0 f.flags), "option")) in
    List.iter (fun f -> ignore (kind f)) (global :: !fields);
    if List.length !files > 1 && !check then raise (Done ("-c can have at most one input file", "option"));
    (* a line's key: its fields', then the whole line's unless -u has fields to go by *)
    let key line =
      let b = Buffer.create (String.length line + 8) and len = String.length line in
      let add (f : field) from upto =
        match kind f with
        | Number -> number_key f b line from upto
        | Plain | Text -> text_key f b line from (max from upto) in
      List.iter (fun (f : field) ->
        let from = match skip line !tab f.beg1 f.beg2 (has f 'B') false with Some i -> i | None -> len in
        let upto = match skip line !tab f.end1 f.end2 (has f 'b') true with Some i -> i | None -> len in
        add f from upto) !fields;
      if not (!unique && !fields <> []) then add global 0 len;
      Buffer.contents b in
    (* the files' lines; a last one without its newline is said, and is one *)
    let lines = ref [] in
    let read fd =
      let all = Buffer.create 8192 and buf = Bytes.create 8192 in
      let rec go () = match Unix.read fd buf 0 8192 with 0 -> () | n -> Buffer.add_subbytes all buf 0 n; go () | exception Unix.Unix_error _ -> () in
      go ();
      let text = Buffer.contents all in
      let l = String.split_on_char '\n' text in
      if text <> "" && text.[String.length text - 1] <> '\n' then begin said "newline added"; lines := List.rev_append l !lines end
      else lines := List.rev_append (List.filteri (fun k _ -> k < List.length l - 1) l) !lines in
    (match !files with
     | [] -> read (Console.stdin_fd caps)
     | files ->
         List.iter (fun name ->
           if name = "-" then read (Console.stdin_fd caps)
           else match FS.open_in_fd caps name with
             | fd -> read fd; Unix.close fd
             | exception Unix.Unix_error (e, _, _) -> raise (Done (Printf.sprintf "open %s: %s" name (Unix.error_message e), "open"))) files);
    let keyed = List.rev_map (fun l -> key l, l) !lines in
    if !check then begin
      let rec ordered = function
        | (k1, _) :: ((k2, _) :: _ as rest) -> if compare k1 k2 > 0 || (k1 = k2 && !unique) then raise (Done ("-c file not in sort", "order")) else ordered rest
        | _ -> () in
      ordered keyed;
      Exit.OK
    end
    else begin
      let sorted = List.stable_sort (fun (k1, _) (k2, _) -> compare (k1 : string) k2) keyed in
      let out = Buffer.create 8192 in
      let rec write before = function
        | (k, l) :: rest -> if not (!unique && before = Some k) then begin Buffer.add_string out l; Buffer.add_char out '\n' end; write (Some k) rest
        | [] -> () in
      write None sorted;
      let text = Buffer.contents out in
      (match !output with
       | Some name ->
           let fd = try FS.open_out_fd caps name 0o666 with Unix.Unix_error (e, _, _) -> raise (Done (Printf.sprintf "create %s: %s" name (Unix.error_message e), "create")) in
           ignore (Unix.write_substring fd text 0 (String.length text)); Unix.close fd
       | None -> Console.print caps text);
      Exit.OK
    end
  with Done (msg, status) -> if msg <> "" then said msg; Exit.Err status

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
