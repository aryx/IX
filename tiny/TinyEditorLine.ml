(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyEditorLine.mli *)

(* Common's, here too: this file links nothing of lib_core *)
let ( ||| ) a b = match a with Some x -> x | None -> b

(* the regular expressions: compile, search, search_back *)
open TinyLibRegex

(* -h: the commands by example, each one as it runs (a string between
 * quotes, not {| |}: tiny-ml builds this file too) *)
let help = "usage: tiny-editor [file]: sam's command language, without the screen,
the commands on standard input, one a line, each on dot, a range of the text:
  ,p  3p  3,5p  $p  #10,#20p  all, line 3, lines 3 to 5, the last, chars 10 to 20
  /main/p  /main/;/^}/d      the next match; from it to a } starting a line
  =  =#                      where dot is, in lines, in characters
  a/text/ i/text/ c/text/    after dot, before it, instead (a alone: lines to .)
  d  s/old/new/g             dot deleted; each old in it new (& \\1: match, group)
  m 5  t 5                   dot moved, copied, after line 5
  ,x/o/c/0/                  every o made 0 (x: a loop on matches; y: between)
  ,x/.*\\n/g/TODO/p           the lines with a TODO (g: if dot matches; v: not)
  { ... }                    several commands, a line each, on the same dot
  u  u-1  w  q               undo, redo, write, quit (r e f: read, edit, name)
  newline                    the next line printed
"

(*****************************************************************************)
(* Regular expressions *)
(*****************************************************************************)

exception Error of string

(*****************************************************************************)
(* Commands *)
(*****************************************************************************)

(* #n n /re/ ?re? . $ *)
type simple = Chars of int | Line of int | Search of dir * string | Dot | Dollar
and dir = Fwd | Back

(* a first simple address, then steps each relative to the one before
 * in its direction; a step without an address is a line: 3+/re/-, -2 *)
type chain = { first : simple option; steps : (dir * simple option) list }

(* a,b and a;b (b from a), right to left: a,b,c is a,(b,c) *)
(* old: sam's C list, simple addresses and Rel markers in one list, a +
 * inserted between two addresses by the parser (under a guard), the
 * direction an int carried along, and a look ahead in the evaluator to
 * know if a sign stood alone; , and ; were chars, compared twice *)
type addr = Chain of chain | Range of sep * chain option * addr option
and sep = Comma | Semi

type cmd = { addr : addr option; op : op }

and op =
  | Text of where * string         (* a i c *)
  | Delete
  | Subst of int * string * string * bool
  | Print
  | Eq of bool                     (* =, =# *)
  | Move of bool * chain          (* m, or t *)
  | Loop of loop * cmd
  | Block of cmd list
  | File of file * string
  | Quit
  | Newline
  | Undo of int                    (* u n, and u-n to redo *)

(* where a, i and c put their text: after, before or instead of dot *)
and where = After | Before | Instead

(* x alone (each line), x/re/ (each match), y/re/ (between them), g/re/
 * and v/re/ (if dot matches, or not) *)
(* old: Loop of char * string option * cmd: a y without a pattern could
 * be built, and ran as x does, where sam refuses it *)
and loop = Lines | Matches of string | Between of string | If of bool * string

(* r w e f *)
(* old: File of char * string, whose last case, a catch-all, stood for f *)
and file = Read | Write | Edit | Name

(* the input, one character of pushback; read a line at a time, when
 * the parser is at its end, so that a command typed at a terminal runs
 * once its line is complete (a text, a line more until ".") *)
(* old: all of standard input read first: at a terminal, nothing ran
 * until ^D *)
let input = ref "" and ip = ref 0
(* standard input's next line: main's, which has the capability (the
 * parser's functions, which all come here, do not pass it along) *)
let next_line : (unit -> string option) ref = ref (fun () -> None)
let refill () =
  if !ip >= String.length !input then
    match !next_line () with
    | Some l -> input := l ^ "\n"; ip := 0
    | None -> ()
let peekc () = refill (); if !ip < String.length !input then (!input).[!ip] else '\000'
let getc () = let c = peekc () in incr ip; c
(* s without the blanks at its ends *)
let trim s =
  let blank c = c = ' ' || c = '\t' || c = '\n' || c = '\r' in
  let n = String.length s and i = ref 0 in
  while !i < n && blank s.[!i] do incr i done;
  let j = ref n in
  while !j > !i && blank s.[!j - 1] do decr j done;
  String.sub s !i (!j - !i)

let skipbl () = while peekc () = ' ' || peekc () = '\t' do incr ip done; peekc ()
let atnl () = if skipbl () <> '\n' && peekc () <> '\000' then raise (Error "newline expected") else incr ip
let num () = let s = !ip in while peekc () >= '0' && peekc () <= '9' do incr ip done; if !ip = s then 1 else Option.get (int_of_string_opt (String.sub !input s (!ip - s)))

let lastpat = ref ""

(* a /re/, up to the delimiter or the end of the line; empty: the last *)
let regexp delim =
  let b = Buffer.create 16 in
  let rec go () =
    match getc () with
    | '\\' when peekc () = delim -> Buffer.add_char b (getc ()); go ()
    | '\\' -> Buffer.add_char b '\\'; Buffer.add_char b (getc ()); go ()
    | c when c = delim -> ()
    | '\n' | '\000' -> decr ip
    | c -> Buffer.add_char b c; go ()
  in
  go ();
  if Buffer.length b > 0 then lastpat := Buffer.contents b;
  if !lastpat = "" then raise (Error "no pattern");
  !lastpat

(* a replacement or a text: \n is a newline, \ then the delimiter the
 * delimiter; s keeps its other \s, for \1 *)
let rhs delim s =
  let b = Buffer.create 16 in
  let rec go () =
    match getc () with
    | '\\' ->
        (match getc () with
         | 'n' -> Buffer.add_char b '\n'
         | c when c = delim -> Buffer.add_char b c
         | c -> if s || c <> '\\' then Buffer.add_char b '\\'; Buffer.add_char b c);
        go ()
    | c when c = delim || c = '\n' || c = '\000' -> decr ip
    | c -> Buffer.add_char b c; go ()
  in
  go ();
  Buffer.contents b

let simple () : simple option =
  match skipbl () with
  | '#' -> incr ip; Some (Chars (num ()))
  | c when c >= '0' && c <= '9' -> Some (Line (num ()))
  | ('/' | '?') as c -> incr ip; Some (Search ((if c = '/' then Fwd else Back), regexp c))
  | '.' -> incr ip; Some Dot
  | '$' -> incr ip; Some Dollar
  | _ -> None

let chain () : chain option =
  (* . and $ only first *)
  let later s = match s with Some (Dot | Dollar) -> raise (Error "address") | _ -> s in
  let first = simple () in
  let rec steps () =
    match skipbl () with
    | '+' -> incr ip; let s = later (simple ()) in (Fwd, s) :: steps ()
    | '-' -> incr ip; let s = later (simple ()) in (Back, s) :: steps ()
    (* 3/re/ is 3+/re/: the + is implied *)
    | _ -> (match later (simple ()) with Some s -> (Fwd, Some s) :: steps () | None -> [])
  in
  match first, steps () with
  | None, [] -> None
  | first, steps -> Some { first; steps }

let rec compound () : addr option =
  let left = chain () in
  match skipbl () with
  | ',' -> incr ip; Some (Range (Comma, left, compound ()))
  | ';' -> incr ip; Some (Range (Semi, left, compound ()))
  | _ -> (match left with Some c -> Some (Chain c) | None -> None)

let rec parse () : cmd option =
  let addr = compound () in
  if skipbl () = '\000' then None
  else
    let c = getc () in
    let delim () =
      match skipbl () with
      | '\n' | '\000' -> raise (Error "no pattern")
      | c when (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') -> raise (Error ("bad delimiter `" ^ String.make 1 c ^ "'"))
      | _ -> getc ()
    in
    let text () =
      if skipbl () = '\n' then begin
        (* lines until "." *)
        incr ip;
        let b = Buffer.create 64 in
        let rec lines () =
          refill ();
          let e = match String.index_from_opt !input !ip '\n' with Some e -> e | None -> String.length !input in
          let l = String.sub !input !ip (e - !ip) in
          ip := e + 1;
          if l <> "." && !ip <= String.length !input + 1 && e < String.length !input then (Buffer.add_string b l; Buffer.add_char b '\n'; lines ())
        in
        lines ();
        Buffer.contents b
      end
      else (let d = getc () in let t = rhs d false in if peekc () = d then incr ip; atnl (); t)
    in
    let word () = ignore (skipbl ()); let s = !ip in while peekc () <> '\n' && peekc () <> '\000' do incr ip done; let w = String.sub !input s (!ip - s) in atnl (); trim w in
    let sub () = match skipbl () with '\n' -> incr ip; { addr = None; op = Print } | _ -> Option.get (parse ()) in
    let op =
      match c with
      | 'a' -> Text (After, text ())
      | 'i' -> Text (Before, text ())
      | 'c' -> Text (Instead, text ())
      | 'd' -> atnl (); Delete
      | 's' ->
          let n = num () in
          let d = delim () in
          let re = regexp d in
          let t = rhs d true in
          let g = if peekc () = d then (incr ip; if peekc () = 'g' then (incr ip; true) else false) else false in
          atnl ();
          Subst (n, re, t, g)
      | 'p' -> atnl (); Print
      | '=' -> let chars = peekc () = '#' in if chars then incr ip; atnl (); Eq chars
      | 'm' | 't' -> (match chain () with Some a -> atnl (); Move (c = 'm', a) | None -> raise (Error "address"))
      | 'x' when (let n = peekc () in n = ' ' || n = '\t' || n = '\n') -> Loop (Lines, sub ())
      | 'x' | 'y' | 'g' | 'v' ->
          let re = regexp (delim ()) in
          let loop = match c with 'x' -> Matches re | 'y' -> Between re | _ -> If (c = 'g', re) in
          Loop (loop, sub ())
      | '{' ->
          let rec cmds acc =
            if skipbl () = '\n' then incr ip;
            if skipbl () = '}' then (incr ip; atnl (); List.rev acc)
            else match parse () with Some c -> cmds (c :: acc) | None -> raise (Error "missing }")
          in
          Block (cmds [])
      | 'r' -> File (Read, word ())
      | 'w' -> File (Write, word ())
      | 'e' -> File (Edit, word ())
      | 'f' -> File (Name, word ())
      | 'q' -> atnl (); Quit
      | 'u' ->
          let redo = skipbl () = '-' in
          if redo then incr ip;
          let n = num () in
          atnl ();
          Undo (if redo then -n else n)
      | '\n' -> Newline
      | c -> raise (Error ("unknown command `" ^ String.make 1 c ^ "'"))
    in
    Some { addr; op }

(*****************************************************************************)
(* The buffer, and changes made in parallel *)
(*****************************************************************************)

let text = ref "" and dot = ref (0, 0) and file = ref "" and modified = ref false and warned = ref false
let changes : (int * int * string) list ref = ref []   (* reversed *)
let hi = ref 0      (* the changes so far end here: the next must not start before *)

let change p0 p1 s =
  if p0 < !hi then raise (Error "changes not in sequence");
  if p0 < p1 || s <> "" then changes := (p0, p1, s) :: !changes;
  hi := p1

(* the changes applied, and their inverse: in the new text, each
 * change's range replaced by the text it replaced, in order too *)
let commit () =
  let cs = List.rev !changes in
  let b = Buffer.create (String.length !text) and at = ref 0 and delta = ref 0 in
  let inverse = List.map (fun (p0, p1, s) ->
    Buffer.add_string b (String.sub !text !at (p0 - !at));
    Buffer.add_string b s;
    at := p1;
    let q = p0 + !delta in
    delta := !delta + String.length s - (p1 - p0);
    (q, q + String.length s, String.sub !text p0 (p1 - p0))) cs in
  if cs <> [] then begin
    Buffer.add_string b (String.sub !text !at (String.length !text - !at));
    text := Buffer.contents b;
    modified := true;
    warned := false
  end;
  changes := [];
  hi := 0;
  inverse

(* a command's inverse, with what it changed besides the text, as it
 * was before it: sam's undo puts them back too. Dot is the one before
 * the command (sam's, the one when its first change was made: after an
 * x, the first match); a w makes every other state modified (sam's
 * menu says unmodified after an undo past a w) *)
type record = { edits : (int * int * string) list; rdot : int * int; rmodified : bool; rfile : string }
let undos : record list ref = ref [] and redos : record list ref = ref []
let before = ref { edits = []; rdot = (0, 0); rmodified = false; rfile = "" }
let now edits = { edits; rdot = !dot; rmodified = !modified; rfile = !file }

let apply () =
  match commit () with
  | [] -> ()
  | edits -> undos := { !before with edits } :: !undos; redos := []

(* u n: n records committed from one list, their inverses pushed on
 * the other, so that a redo is an undo undone *)
let undo n =
  if !changes <> [] then raise (Error "u after a change");
  let from, onto = if n > 0 then undos, redos else redos, undos in
  for _i = 1 to abs n do
    match !from with
    | [] -> ()
    | r :: rest ->
        from := rest;
        let saved = now [] in
        changes := List.rev r.edits;
        onto := { saved with edits = commit () } :: !onto;
        dot := r.rdot; modified := r.rmodified; file := r.rfile
  done

(* where old position p is after the changes before it *)
let shift p = List.fold_left (fun q (p0, p1, s) -> if p1 <= p then q + String.length s - (p1 - p0) else q) p !changes

(* the library's errors, as this file's *)
let compile p = try compile p with Failure m -> raise (Error m)

(*****************************************************************************)
(* Addresses *)
(*****************************************************************************)

let len () = String.length !text

(* address.c's lineaddr: line n, relative to (q0, q1) in direction sign *)
let lineaddr n (q0, q1) sign =
  let t = !text and nc = len () in
  if sign >= 0 then begin
    if n = 0 && (sign = 0 || q1 = 0) then (0, 0)
    else begin
      let p = ref 0 and start = ref 0 in
      if n = 0 then (start := q1; p := q1 - 1)
      else begin
        let k = ref 1 in
        if not (sign = 0 || q1 = 0) then (p := q1 - 1; k := (if t.[!p] = '\n' then 1 else 0); incr p);
        while !k < n do
          if !p >= nc then raise (Error "address range");
          if t.[!p] = '\n' then incr k;
          incr p
        done;
        start := !p
      end;
      (* to the end of that line, its newline included *)
      while !p < nc && (let c = t.[!p] in incr p; c <> '\n') do () done;
      (!start, !p)
    end
  end
  else begin
    let p = ref q0 and e = ref q0 in
    if n > 0 then begin
      let k = ref 0 in
      while !k < n do
        if !p = 0 then (incr k; if !k <> n then raise (Error "address range"))
        else if t.[!p - 1] <> '\n' || (incr k; !k <> n) then decr p
      done;
      e := !p;
      if !p > 0 then decr p
    end;
    while !p > 0 && t.[!p - 1] <> '\n' do decr p done;
    (!p, !e)
  end

(* nextmatch: a search from p, wrapping; an empty match right at p is
 * skipped *)
let next_match pat (q0, q1) forward =
  let re = compile pat in
  let t = !text in
  if forward then begin
    let find p = match search re t p (len ()) with Some c -> Some c | None -> search re t 0 (len ()) in
    match find q1 with
    | None -> raise (Error "search")
    | Some c when c.(0) = c.(1) && c.(0) = q1 -> (match find (if q1 + 1 > len () then 0 else q1 + 1) with Some c -> (c.(0), c.(1)) | None -> raise (Error "search"))
    | Some c -> (c.(0), c.(1))
  end
  else begin
    let find p = match search_back re t p with Some c -> Some c | None -> search_back re t (len ()) in
    match find q0 with
    | None -> raise (Error "search")
    | Some c when c.(0) = c.(1) && c.(1) = q0 -> (match find (if q0 - 1 < 0 then len () else q0 - 1) with Some c -> (c.(0), c.(1)) | None -> raise (Error "search"))
    | Some c -> (c.(0), c.(1))
  end

(* address.c's address(): a simple address, absolute (sign 0) or
 * relative to a in a direction (1 or -1) *)
let simple_address (s : simple) (a : int * int) (sign : int) : int * int =
  match s with
  | Chars n ->
      let q0, q1 = a in
      let r = if sign = 0 then (n, n) else if sign < 0 then (q0 - n, q0 - n) else (q1 + n, q1 + n) in
      if fst r < 0 || snd r > len () then raise (Error "address range");
      r
  | Line n -> lineaddr n a sign
  | Search (d, pat) -> next_match pat a (if d = Fwd then sign >= 0 else sign < 0)
  | Dot -> !dot
  | Dollar -> (len (), len ())

let chain_address (c : chain) (a : int * int) : int * int =
  let a = match c.first with Some s -> simple_address s a 0 | None -> a in
  List.fold_left (fun a (d, s) ->
    let sign = if d = Fwd then 1 else -1 in
    match s with Some s -> simple_address s a sign | None -> lineaddr 1 a sign) a c.steps

let rec address (ad : addr) (a : int * int) : int * int =
  match ad with
  | Chain c -> chain_address c a
  | Range (sep, l, r) ->
      let a1 = match l with Some l -> chain_address l a | None -> (0, 0) in
      if sep = Semi then dot := a1;
      let a2 = match r with Some r -> address r (if sep = Semi then a1 else a) | None -> (len (), len ()) in
      if snd a2 < fst a1 then raise (Error "address order");
      (fst a1, snd a2)

(*****************************************************************************)
(* Running commands *)
(*****************************************************************************)

let out = Buffer.create 4096
let flush (caps : < Cap.stdout; .. >) = TinyLibSystem.print caps (Buffer.contents out); Buffer.clear out; TinyLibSystem.flush ()

let print_posn (q0, q1) chars =
  let t = !text in
  let count a b = let n = ref 0 in for i = a to b - 1 do if t.[i] = '\n' then incr n done; !n in
  if not chars then begin
    let l1 = 1 + count 0 q0 in
    let l2 = l1 + count q0 q1 - (if q1 > q0 && t.[q1 - 1] = '\n' then 1 else 0) in
    Buffer.add_string out (if l2 <> l1 then string_of_int l1 ^ "," ^ string_of_int l2 ^ "; " else string_of_int l1 ^ "; ")
  end;
  Buffer.add_string out (if q1 <> q0 then "#" ^ string_of_int q0 ^ ",#" ^ string_of_int q1 ^ "\n" else "#" ^ string_of_int q0 ^ "\n")

(* the file's line in sam's menu: ' when modified *)
let menu name = (if !modified then "'" else " ") ^ "-. " ^ name ^ "\n"

let read_file (caps : < Cap.open_in; .. >) name =
  if name = "" then None else try Some (TinyLibSystem.read_file caps name) with Failure _ -> None

let rec exec (caps : < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr; .. >) (c : cmd) : unit =
  let a = match c.addr, c.op with None, File (Write, _) -> (0, len ()) | None, _ -> !dot | Some ad, _ -> address ad !dot in
  let q0, q1 = a in
  match c.op with
  | Text (w, s) ->
      (* the range the text replaces *)
      let p0, p1 = match w with After -> q1, q1 | Before -> q0, q0 | Instead -> q0, q1 in
      change p0 p1 s;
      dot := (p0, p0 + String.length s)
  | Delete -> change q0 q1 ""; dot := (q0, q0)
  | Subst (n, pat, rep, g) ->
      let re = compile pat in
      let n = ref n and p = ref q0 and op = ref (-1) and did = ref false and delta = ref 0 in
      (try
         while !p <= q1 do
           match search re !text !p q1 with
           | None -> raise Exit
           | Some m ->
               let s, e = m.(0), m.(1) in
               if s = e && s = !op then incr p
               else begin
                 p := if s = e then e + 1 else e;
                 op := e;
                 decr n;
                 if !n <= 0 then begin
                   let b = Buffer.create 16 in
                   let i = ref 0 in
                   while !i < String.length rep do
                     (match rep.[!i] with
                      | '\\' when !i + 1 < String.length rep ->
                          incr i;
                          (match rep.[!i] with
                           | d when d >= '1' && d <= '9' ->
                               let g = Char.code d - 48 in
                               if m.(2 * g) >= 0 && m.((2 * g) + 1) >= 0 then Buffer.add_string b (String.sub !text m.(2 * g) (m.((2 * g) + 1) - m.(2 * g)))
                           | c -> Buffer.add_char b c)
                      | '&' -> Buffer.add_string b (String.sub !text s (e - s))
                      | c -> Buffer.add_char b c);
                     incr i
                   done;
                   change s e (Buffer.contents b);
                   delta := !delta + Buffer.length b - (e - s);
                   did := true;
                   if not g then raise Exit
                 end
               end
         done
       with Exit -> ());
      if not !did then raise (Error "substitution");
      dot := (q0, q1 + !delta)
  | Print -> Buffer.add_string out (String.sub !text q0 (q1 - q0)); dot := a
  | Eq chars -> print_posn a chars
  | Move (m, dest) ->
      let d = chain_address dest !dot in
      let s = String.sub !text q0 (q1 - q0) in
      let p = snd d in
      if m then begin
        (* claude: as sam's move: after the range, or before it (its
         * start included: 2m1 is allowed) *)
        if q1 <= p then (change q0 q1 ""; change p p s)
        else if q0 >= p then (change p p s; change q0 q1 "")
        else raise (Error "addresses overlap");
        dot := (shift p - (if p >= q1 then q1 - q0 else 0), shift p - (if p >= q1 then q1 - q0 else 0) + String.length s)
      end
      else (change p p s; dot := (p, p + String.length s))
  | Loop (If (g, pat), sub) ->
      let found = search (compile pat) !text q0 q1 <> None in
      if found = g then (dot := a; exec caps sub)
  | Loop (Lines, sub) ->
      let p = ref q0 in
      while !p < q1 do
        let e = match String.index_from_opt !text !p '\n' with Some e when e < q1 -> e + 1 | _ -> q1 in
        dot := (!p, e);
        exec caps sub;
        p := e
      done
  | Loop (k, sub) ->
      (* looper(): x on each match, y on the text between (the two
       * other loops are the cases above; tiny-ml has no or-pattern
       * that binds a name, (Matches pat | Between pat)) *)
      let x, pat = match k with Matches p -> true, p | Between p -> false, p | _ -> raise (Error "loop") in
      let re = compile pat in
      let p = ref q0 and op = ref (if x then -1 else q0) in
      (try
         while !p <= q1 do
           match search re !text !p q1 with
           | None ->
               if x || !op > q1 then raise Exit;
               dot := (!op, q1);
               p := q1 + 1;
               exec caps sub
           | Some m ->
               let s, e = m.(0), m.(1) in
               if s = e && s = !op then incr p
               else begin
                 p := if s = e then e + 1 else e;
                 dot := if x then (s, e) else (!op, s);
                 op := e;
                 exec caps sub
               end
         done
       with Exit -> ())
  | Block cmds -> List.iter (fun c -> dot := a; exec caps c) cmds
  | File (Read, name) -> (
      match read_file caps name with
      | Some s -> change q0 q1 s; dot := (q0, q0 + String.length s); Buffer.add_string out ("#" ^ string_of_int (String.length s) ^ "\n")
      | None -> raise (Error ("can't open " ^ name)))
  | File (Write, name) ->
      let name = if name = "" then !file else name in
      if name = "" then raise (Error "no file name");
      let fd = TinyLibSystem.open_out caps name in
      TinyLibSystem.write fd (String.sub !text q0 (q1 - q0));
      TinyLibSystem.close fd;
      if name = !file && q0 = 0 && q1 = len () then begin
        modified := false;
        let differ r = { r with rmodified = true } in
        undos := List.map differ !undos; redos := List.map differ !redos
      end;
      if !file = "" then file := name;
      Buffer.add_string out (name ^ ": ");
      if q1 > q0 && (!text).[q1 - 1] <> '\n' then (flush caps; TinyLibSystem.eprint caps "?warning: last char not newline\n");
      Buffer.add_string out ("#" ^ string_of_int (q1 - q0) ^ "\n")
  | File (Edit, name) ->
      let name = if name = "" then !file else name in
      (match read_file caps name with
       | Some s -> change 0 (len ()) s; apply (); file := name; dot := (0, 0); modified := false
       | None -> raise (Error ("can't open " ^ name)));
      Buffer.add_string out (menu name)
  | File (Name, name) -> if name <> "" then file := name; Buffer.add_string out (menu !file)
  | Quit ->
      if !modified && not !warned then (warned := true; raise (Error "changed files"));
      flush caps;
      TinyLibSystem.exit 0
  | Undo n -> undo n
  | Newline -> (
      (* the next line, or the line dot is in if it is not one *)
      match c.addr with
      | Some _ -> Buffer.add_string out (String.sub !text q0 (q1 - q0)); dot := a
      | None ->
          let b0, _ = lineaddr 0 !dot (-1) and _, b1 = lineaddr 0 !dot 1 in
          let r = if (b0, b1) = !dot then lineaddr 1 !dot 1 else (b0, b1) in
          Buffer.add_string out (String.sub !text (fst r) (snd r - fst r));
          dot := r)

let main (caps : Cap.all_caps) : int =
  next_line := (fun () -> TinyLibSystem.read_line caps);
  match TinyLibSystem.argv caps with
  | [ _; ("-h" | "--help") ] -> TinyLibSystem.print caps help; TinyLibSystem.flush (); 0
  | argv ->
      (match argv with
       | [ _; name ] ->
           file := name;
           text := read_file caps name ||| "";
           Buffer.add_string out (menu name)
       | _ -> ());
      let rec loop () =
        (* a command, None at the end; or an error while it is read
         * (its message said, the rest of the line thrown away): None *)
        let read =
          try Some (parse ())
          with Error m ->
            flush caps;
            TinyLibSystem.eprint caps ("?" ^ m ^ "\n");
            while peekc () <> '\n' && peekc () <> '\000' do incr ip done;
            if peekc () = '\n' then incr ip;
            None in
        match read with
        | Some None -> ()
        | Some (Some c) ->
            (* an error while it runs: its changes are dropped *)
            before := now [];
            (try exec caps c; apply ()
             with Error m ->
               changes := [];
               hi := 0;
               flush caps;
               TinyLibSystem.eprint caps ("?" ^ m ^ "\n"));
            flush caps;
            loop ()
        | None -> loop () in
      loop ();
      if !modified && not !warned then (flush caps; TinyLibSystem.eprint caps "?changed files\n");
      flush caps;
      0

let () = TinyLibSystem.main "tiny-editor" main
