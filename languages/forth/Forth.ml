(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Forth.mli *)

exception Error of string

type t = {
  mem : int array;
  mutable here : int;                   (* the dictionary's end *)
  mutable latest : int;                 (* the last word's header; 0: none *)
  ds : int array;                       (* the data stack *)
  mutable sp : int;
  rs : int array;                       (* the return stack *)
  mutable rp : int;
  mutable ip : int;                     (* the cell NEXT takes next *)
  mutable running : bool;
  mutable input : string;               (* the text being interpreted, and where in it *)
  mutable pos : int;
  mutable steps : int;
  mutable prims : (t -> int -> unit) array; (* a code field's number: its code (given W) *)
  mutable trace : bool;
  mutable bye : bool;
  print : string -> unit;
  (* the code fields and the words the compiler itself needs *)
  mutable docol : int;
  mutable dovar : int;
  mutable dodoes : int;
  mutable lit : int;
  mutable quote : int;                  (* as lit, for a word's address: SEE names it *)
  mutable exit : int;
  mutable comma_ : int;
  mutable squote : int;
  mutable dotquote : int;
  mutable abortquote : int;
}

(* the first cells: STATE (0: interpreting), BASE, and the cell a word
 * called from OCaml returns to (it holds the word that stops NEXT) *)
let state : int = 1
let base : int = 2
let stop_cell : int = 3
let first : int = 8
let size : int = 131072

(* where S-quote puts a text outside a definition *)
let pad : int = size - 4096

(* a header: the link, the name's length and the flags, the name; then the code field *)
let immediate : int = 256
let hidden : int = 512

(*****************************************************************************)
(* The stacks, the memory *)
(*****************************************************************************)

let push (m : t) (v : int) : unit =
  if m.sp >= Array.length m.ds then raise (Error "the stack is full");
  m.ds.(m.sp) <- v;
  m.sp <- m.sp + 1

let pop (m : t) : int =
  if m.sp = 0 then raise (Error "the stack is empty");
  m.sp <- m.sp - 1;
  m.ds.(m.sp)

let rpush (m : t) (v : int) : unit =
  if m.rp >= Array.length m.rs then raise (Error "the return stack is full");
  m.rs.(m.rp) <- v;
  m.rp <- m.rp + 1

let rpop (m : t) : int =
  if m.rp = 0 then raise (Error "the return stack is empty");
  m.rp <- m.rp - 1;
  m.rs.(m.rp)

let comma (m : t) (v : int) : unit =
  m.mem.(m.here) <- v;
  m.here <- m.here + 1

let flag (b : bool) : int = if b then -1 else 0

(*****************************************************************************)
(* The dictionary *)
(*****************************************************************************)

let name_at (m : t) (h : int) : string = String.init (m.mem.(h + 1) land 255) (fun (i : int) -> Char.chr (m.mem.(h + 2 + i) land 255))
let cfa (m : t) (h : int) : int = h + 2 + (m.mem.(h + 1) land 255)

let header (m : t) (name : string) : unit =
  if name = "" then raise (Error "a name is wanted");
  let name = String.uppercase_ascii name in
  let h = m.here in
  comma m m.latest;
  comma m (String.length name);
  String.iter (fun (c : char) -> comma m (Char.code c)) name;
  m.latest <- h

(* a word's code field's address (its execution token), and is it immediate? *)
let find (m : t) (name : string) : (int * bool) option =
  let name = String.uppercase_ascii name in
  let rec go (h : int) : (int * bool) option =
    if h = 0 then None
    else if m.mem.(h + 1) land hidden = 0 && name_at m h = name then Some (cfa m h, m.mem.(h + 1) land immediate <> 0)
    else go m.mem.(h) in
  go m.latest

let name_of (m : t) (xt : int) : string =
  let rec go (h : int) : string = if h = 0 then "?" ^ string_of_int xt else if cfa m h = xt then name_at m h else go m.mem.(h) in
  go m.latest

(*****************************************************************************)
(* Numbers *)
(*****************************************************************************)

let digits : string = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"

let to_base (n : int) (b : int) : string =
  let b = if b < 2 || b > 36 then 10 else b in
  let rec go (n : int) (acc : string) : string =
    if n = 0 then acc else go (n / b) (String.make 1 digits.[abs (n mod b)] ^ acc) in
  if n = 0 then "0" else if n < 0 then "-" ^ go n "" else go n ""

(* 42, -7, $FF (hexadecimal), %101, #10, 'a' (its code); else in BASE *)
let number (m : t) (s : string) : int option =
  let n = String.length s in
  if n = 3 && s.[0] = '\'' && s.[2] = '\'' then Some (Char.code s.[1])
  else begin
    let b, i =
      if n > 1 && s.[0] = '$' then (16, 1)
      else if n > 1 && s.[0] = '%' then (2, 1)
      else if n > 1 && s.[0] = '#' then (10, 1)
      else (m.mem.(base), 0) in
    let negative = i < n && s.[i] = '-' in
    let i = if negative then i + 1 else i in
    let rec go (i : int) (acc : int) : int option =
      if i = n then Some (if negative then -acc else acc)
      else
        let c = Char.uppercase_ascii s.[i] in
        let d = if c >= '0' && c <= '9' then Char.code c - 48 else if c >= 'A' && c <= 'Z' then Char.code c - 55 else 99 in
        if d < b then go (i + 1) ((acc * b) + d) else None in
    if i >= n then None else go i 0
  end

(*****************************************************************************)
(* The text *)
(*****************************************************************************)

(* the next word of the text: what is between spaces; "": no more *)
let word (m : t) : string =
  let n = String.length m.input in
  while m.pos < n && m.input.[m.pos] <= ' ' do
    m.pos <- m.pos + 1
  done;
  let start = m.pos in
  while m.pos < n && m.input.[m.pos] > ' ' do
    m.pos <- m.pos + 1
  done;
  let w = String.sub m.input start (m.pos - start) in
  if m.pos < n then m.pos <- m.pos + 1;
  w

(* the text to the next [c], which is passed *)
let upto (m : t) (c : char) : string =
  let n = String.length m.input in
  let start = m.pos in
  while m.pos < n && m.input.[m.pos] <> c do
    m.pos <- m.pos + 1
  done;
  let s = String.sub m.input start (m.pos - start) in
  if m.pos < n then m.pos <- m.pos + 1;
  s

(*****************************************************************************)
(* The inner interpreter *)
(*****************************************************************************)

let execute (m : t) (w : int) : unit = m.prims.(m.mem.(w)) m w

let stack_text (m : t) : string =
  let b = Buffer.create 32 in
  Buffer.add_string b (Printf.sprintf "<%d> " m.sp);
  for i = 0 to m.sp - 1 do
    Buffer.add_string b (to_base m.ds.(i) m.mem.(base) ^ " ")
  done;
  Buffer.contents b

let next (m : t) : unit =
  let w = m.mem.(m.ip) in
  m.ip <- m.ip + 1;
  m.steps <- m.steps + 1;
  if m.trace && m.ip <> stop_cell + 1 then
    m.print (Printf.sprintf "%s%-12s %s\n" (String.make (2 * m.rp) ' ') (name_of m w) (stack_text m));
  execute m w

(* a word run from OCaml, to its end *)
let call (m : t) (xt : int) : unit =
  rpush m m.ip;
  m.ip <- stop_cell;
  if m.trace then m.print (Printf.sprintf "%-12s %s\n" (name_of m xt) (stack_text m));
  execute m xt;
  m.running <- true;
  while m.running do
    next m
  done;
  m.ip <- rpop m

(*****************************************************************************)
(* SEE *)
(*****************************************************************************)

(* a definition as it is in the memory: each cell's address and the word it names *)
let see (m : t) (name : string) : unit =
  match find m name with
  | None -> raise (Error (name ^ " ?"))
  | Some (xt, imm) ->
      let name = String.uppercase_ascii name in
      let code = m.mem.(xt) in
      if code = m.docol then begin
        (* its end: the next word's header *)
        let stop = ref m.here in
        let rec headers (h : int) : unit =
          if h <> 0 then begin
            if h > xt && h < !stop then stop := h;
            headers m.mem.(h)
          end in
        headers m.latest;
        let lines : string list ref = ref [] in
        let a = ref (xt + 1) in
        while !a < !stop do
          let at = !a in
          let w = m.mem.(at) in
          let nm = name_of m w in
          let text =
            if w = m.squote || w = m.dotquote || w = m.abortquote then begin
              let n = m.mem.(!a + 1) in
              let s = String.init n (fun (i : int) -> Char.chr (m.mem.(!a + 2 + i) land 255)) in
              a := !a + 1 + n;
              nm ^ " " ^ s ^ "\""
            end
            else if w = m.quote then begin
              a := !a + 1;
              nm ^ " " ^ name_of m m.mem.(!a)
            end
            else if w = m.lit || (String.length nm > 2 && nm.[0] = '(' && nm <> "(DOES>)") then begin
              (* (LIT) and the jumps: the cell after is theirs *)
              a := !a + 1;
              nm ^ " " ^ string_of_int m.mem.(!a)
            end
            else nm in
          lines := Printf.sprintf "  %d  %s" at text :: !lines;
          a := !a + 1
        done;
        m.print (": " ^ name ^ "\n" ^ String.concat "\n" (List.rev !lines) ^ " ;" ^ (if imm then " IMMEDIATE" else "") ^ "\n")
      end
      else if code = m.dovar || code = m.dodoes then
        m.print
          (Printf.sprintf "CREATE %s  \\ its data at %d%s\n" name (xt + 2)
             (if code = m.dodoes then Printf.sprintf ", DOES> at %d" m.mem.(xt + 1) else ""))
      else m.print (name ^ " is a primitive\n")

(*****************************************************************************)
(* The outer interpreter *)
(*****************************************************************************)

let reset (m : t) : unit =
  m.sp <- 0;
  m.rp <- 0;
  m.ip <- stop_cell;
  m.mem.(state) <- 0;
  (* a definition that was being made is taken out *)
  if m.latest <> 0 && m.mem.(m.latest + 1) land hidden <> 0 then begin
    m.here <- m.latest;
    m.latest <- m.mem.(m.latest)
  end

let interpret (m : t) (line : string) : unit =
  m.input <- line;
  m.pos <- 0;
  let rec go () : unit =
    let w = word m in
    if w <> "" then begin
      (match find m w with
       | Some (xt, imm) -> if imm || m.mem.(state) = 0 then call m xt else comma m xt
       | None -> (
           match number m w with
           | Some n ->
               if m.mem.(state) = 0 then push m n
               else begin
                 comma m m.lit;
                 comma m n
               end
           | None -> raise (Error (w ^ " ?"))));
      go ()
    end in
  try go () with
  | Error msg -> reset m; raise (Error msg)
  | Invalid_argument _ -> reset m; raise (Error "an address outside the memory")

let finished (m : t) : bool = m.bye
let compiling (m : t) : bool = m.mem.(state) <> 0
let steps (m : t) : int = m.steps
let set_trace (m : t) (on : bool) : unit = m.trace <- on

(*****************************************************************************)
(* The primitives *)
(*****************************************************************************)

let create (print : string -> unit) : t =
  let m : t =
    { mem = Array.make size 0; here = first; latest = 0; ds = Array.make 1024 0; sp = 0; rs = Array.make 16384 0; rp = 0;
      ip = stop_cell; running = false; input = ""; pos = 0; steps = 0; prims = [||]; trace = false; bye = false; print;
      docol = 0; dovar = 0; dodoes = 0; lit = 0; quote = 0; exit = 0; comma_ = 0; squote = 0; dotquote = 0; abortquote = 0 } in
  let table : (t -> int -> unit) list ref = ref [] and count = ref 0 in
  (* a code field's number for this code *)
  let code (f : t -> int -> unit) : int =
    table := f :: !table;
    incr count;
    !count - 1 in
  (* a word in OCaml; its execution token *)
  let def (name : string) (f : t -> int -> unit) : int =
    header m name;
    comma m (code f);
    m.here - 1 in
  let def_ (name : string) (f : t -> int -> unit) : unit = ignore (def name f) in
  let imm (name : string) (f : t -> int -> unit) : unit =
    def_ name f;
    m.mem.(m.latest + 1) <- m.mem.(m.latest + 1) lor immediate in
  let op2 (name : string) (f : int -> int -> int) : unit =
    def_ name (fun (m : t) (_ : int) ->
        let b = pop m in
        let a = pop m in
        push m (f a b)) in
  (* a text compiled after the word that will find it: its length, its characters *)
  let compile_text (m : t) (xt : int) (s : string) : unit =
    comma m xt;
    comma m (String.length s);
    String.iter (fun (c : char) -> comma m (Char.code c)) s in
  let text_here (m : t) : string =
    let n = m.mem.(m.ip) in
    let s = String.init n (fun (i : int) -> Char.chr (m.mem.(m.ip + 1 + i) land 255)) in
    m.ip <- m.ip + 1 + n;
    s in
  let tick (m : t) : int = let w = word m in match find m w with Some (xt, _) -> xt | None -> raise (Error (w ^ " ?")) in
  (* what a code field may say: a colon word, CREATE's, DOES>'s *)
  m.docol <- code (fun (m : t) (w : int) -> rpush m m.ip; m.ip <- w + 1);
  m.dovar <- code (fun (m : t) (w : int) -> push m (w + 2));
  m.dodoes <- code (fun (m : t) (w : int) -> push m (w + 2); rpush m m.ip; m.ip <- m.mem.(w + 1));
  (* the inner interpreter's own *)
  m.mem.(stop_cell) <- def "(STOP)" (fun (m : t) (_ : int) -> m.running <- false);
  m.exit <- def "EXIT" (fun (m : t) (_ : int) -> m.ip <- rpop m);
  m.lit <- def "(LIT)" (fun (m : t) (_ : int) -> push m m.mem.(m.ip); m.ip <- m.ip + 1);
  m.quote <- def "(')" (fun (m : t) (_ : int) -> push m m.mem.(m.ip); m.ip <- m.ip + 1);
  def_ "(BRANCH)" (fun (m : t) (_ : int) -> m.ip <- m.mem.(m.ip));
  def_ "(0BRANCH)" (fun (m : t) (_ : int) -> if pop m = 0 then m.ip <- m.mem.(m.ip) else m.ip <- m.ip + 1);
  def_ "EXECUTE" (fun (m : t) (_ : int) -> execute m (pop m));
  (* a counted loop: on the return stack its end, its limit, its index *)
  let enter (m : t) (index : int) (limit : int) : unit =
    rpush m m.mem.(m.ip);
    rpush m limit;
    rpush m index;
    m.ip <- m.ip + 1 in
  def_ "(DO)" (fun (m : t) (_ : int) ->
      let index = pop m in
      enter m index (pop m));
  def_ "(?DO)" (fun (m : t) (_ : int) ->
      let index = pop m in
      let limit = pop m in
      if index = limit then m.ip <- m.mem.(m.ip) else enter m index limit);
  let again (m : t) (step : int) : unit =
    let before = m.rs.(m.rp - 1) - m.rs.(m.rp - 2) in
    let after = before + step in
    m.rs.(m.rp - 1) <- m.rs.(m.rp - 1) + step;
    (* (done when the index crosses the limit) *)
    if before < 0 <> (after < 0) then begin
      m.rp <- m.rp - 3;
      m.ip <- m.ip + 1
    end
    else m.ip <- m.mem.(m.ip) in
  def_ "(LOOP)" (fun (m : t) (_ : int) -> again m 1);
  def_ "(+LOOP)" (fun (m : t) (_ : int) -> again m (pop m));
  def_ "I" (fun (m : t) (_ : int) -> push m m.rs.(m.rp - 1));
  def_ "J" (fun (m : t) (_ : int) -> push m m.rs.(m.rp - 4));
  def_ "UNLOOP" (fun (m : t) (_ : int) -> m.rp <- m.rp - 3);
  def_ "LEAVE" (fun (m : t) (_ : int) -> m.rp <- m.rp - 2; m.ip <- rpop m);
  (* the stacks *)
  def_ "DUP" (fun (m : t) (_ : int) -> let a = pop m in push m a; push m a);
  def_ "DROP" (fun (m : t) (_ : int) -> ignore (pop m));
  def_ "SWAP" (fun (m : t) (_ : int) -> let b = pop m in let a = pop m in push m b; push m a);
  def_ "OVER" (fun (m : t) (_ : int) -> let b = pop m in let a = pop m in push m a; push m b; push m a);
  def_ "ROT" (fun (m : t) (_ : int) -> let c = pop m in let b = pop m in let a = pop m in push m b; push m c; push m a);
  def_ "PICK" (fun (m : t) (_ : int) ->
      let n = pop m in
      if n < 0 || n >= m.sp then raise (Error "the stack is empty");
      push m m.ds.(m.sp - 1 - n));
  def_ "DEPTH" (fun (m : t) (_ : int) -> push m m.sp);
  def_ ">R" (fun (m : t) (_ : int) -> rpush m (pop m));
  def_ "R>" (fun (m : t) (_ : int) -> push m (rpop m));
  def_ "R@" (fun (m : t) (_ : int) -> let a = rpop m in rpush m a; push m a);
  (* arithmetic: a cell is OCaml's integer; / rounds toward zero *)
  op2 "+" (fun (a : int) (b : int) -> a + b);
  op2 "-" (fun (a : int) (b : int) -> a - b);
  op2 "*" (fun (a : int) (b : int) -> a * b);
  (* (asked here: mini-ml's division does not raise) *)
  let nonzero (b : int) : int = if b = 0 then raise (Error "a division by zero") else b in
  op2 "/" (fun (a : int) (b : int) -> a / nonzero b);
  op2 "MOD" (fun (a : int) (b : int) -> a mod nonzero b);
  op2 "AND" (fun (a : int) (b : int) -> a land b);
  op2 "OR" (fun (a : int) (b : int) -> a lor b);
  op2 "XOR" (fun (a : int) (b : int) -> a lxor b);
  op2 "LSHIFT" (fun (a : int) (b : int) -> a lsl b);
  op2 "RSHIFT" (fun (a : int) (b : int) -> a lsr b);
  op2 "=" (fun (a : int) (b : int) -> flag (a = b));
  op2 "<" (fun (a : int) (b : int) -> flag (a < b));
  op2 ">" (fun (a : int) (b : int) -> flag (a > b));
  def_ "INVERT" (fun (m : t) (_ : int) -> push m (lnot (pop m)));
  (* the memory *)
  (* (asked here too: a program's mistake, not OCaml's) *)
  let at (a : int) : int = if a < 0 || a >= size then raise (Error "an address outside the memory") else a in
  def_ "@" (fun (m : t) (_ : int) -> push m m.mem.(at (pop m)));
  def_ "!" (fun (m : t) (_ : int) -> let a = at (pop m) in m.mem.(a) <- pop m);
  def_ "C@" (fun (m : t) (_ : int) -> push m m.mem.(at (pop m)));
  def_ "C!" (fun (m : t) (_ : int) -> let a = at (pop m) in m.mem.(a) <- pop m);
  m.comma_ <- def "," (fun (m : t) (_ : int) -> comma m (pop m));
  def_ "C," (fun (m : t) (_ : int) -> comma m (pop m));
  def_ "HERE" (fun (m : t) (_ : int) -> push m m.here);
  def_ "ALLOT" (fun (m : t) (_ : int) -> m.here <- m.here + pop m);
  def_ "STATE" (fun (m : t) (_ : int) -> push m state);
  def_ "BASE" (fun (m : t) (_ : int) -> push m base);
  def_ ">BODY" (fun (m : t) (_ : int) -> push m (pop m + 2));
  (* what is printed *)
  def_ "EMIT" (fun (m : t) (_ : int) -> m.print (String.make 1 (Char.chr (pop m land 255))));
  def_ "." (fun (m : t) (_ : int) -> m.print (to_base (pop m) m.mem.(base) ^ " "));
  def_ ".S" (fun (m : t) (_ : int) -> m.print (stack_text m));
  (* the texts *)
  m.squote <- def "(S\")" (fun (m : t) (_ : int) -> let n = m.mem.(m.ip) in push m (m.ip + 1); push m n; m.ip <- m.ip + 1 + n);
  m.dotquote <- def "(.\")" (fun (m : t) (_ : int) -> m.print (text_here m));
  m.abortquote <- def "(ABORT\")" (fun (m : t) (_ : int) -> let s = text_here m in if pop m <> 0 then raise (Error s));
  imm "S\"" (fun (m : t) (_ : int) ->
      let s = upto m '"' in
      if m.mem.(state) <> 0 then compile_text m m.squote s
      else begin
        String.iteri (fun (i : int) (c : char) -> m.mem.(pad + i) <- Char.code c) s;
        push m pad;
        push m (String.length s)
      end);
  imm ".\"" (fun (m : t) (_ : int) ->
      let s = upto m '"' in
      if m.mem.(state) <> 0 then compile_text m m.dotquote s else m.print s);
  imm "ABORT\"" (fun (m : t) (_ : int) -> compile_text m m.abortquote (upto m '"'));
  def_ "ABORT" (fun (_ : t) (_ : int) -> raise (Error "ABORT"));
  imm ".(" (fun (m : t) (_ : int) -> m.print (upto m ')'));
  imm "(" (fun (m : t) (_ : int) -> ignore (upto m ')'));
  imm "\\" (fun (m : t) (_ : int) -> m.pos <- String.length m.input);
  let char (m : t) : int = let w = word m in if w = "" then raise (Error "a character is wanted") else Char.code w.[0] in
  def_ "CHAR" (fun (m : t) (_ : int) -> push m (char m));
  imm "[CHAR]" (fun (m : t) (_ : int) -> comma m m.lit; comma m (char m));
  (* the compiler *)
  def_ ":" (fun (m : t) (_ : int) ->
      header m (word m);
      m.mem.(m.latest + 1) <- m.mem.(m.latest + 1) lor hidden;
      comma m m.docol;
      m.mem.(state) <- 1);
  imm ";" (fun (m : t) (_ : int) ->
      comma m m.exit;
      m.mem.(m.latest + 1) <- m.mem.(m.latest + 1) land lnot hidden;
      m.mem.(state) <- 0);
  def_ "IMMEDIATE" (fun (m : t) (_ : int) -> m.mem.(m.latest + 1) <- m.mem.(m.latest + 1) lor immediate);
  imm "[" (fun (m : t) (_ : int) -> m.mem.(state) <- 0);
  def_ "]" (fun (m : t) (_ : int) -> m.mem.(state) <- 1);
  imm "LITERAL" (fun (m : t) (_ : int) -> comma m m.lit; comma m (pop m));
  imm "RECURSE" (fun (m : t) (_ : int) -> comma m (cfa m m.latest));
  def_ "'" (fun (m : t) (_ : int) -> push m (tick m));
  imm "[']" (fun (m : t) (_ : int) -> comma m m.quote; comma m (tick m));
  (* POSTPONE X: what X does when compiling, done later by the word being defined *)
  imm "POSTPONE" (fun (m : t) (_ : int) ->
      let w = word m in
      match find m w with
      | Some (xt, true) -> comma m xt
      | Some (xt, false) -> comma m m.quote; comma m xt; comma m m.comma_
      | None -> raise (Error (w ^ " ?")));
  (* a word whose data follows it: it gives the data's address *)
  def_ "CREATE" (fun (m : t) (_ : int) ->
      header m (word m);
      comma m m.dovar;
      comma m 0);
  (* DOES>'s: the word just made by CREATE will run what follows here, its data's address given *)
  def_ "(DOES>)" (fun (m : t) (_ : int) ->
      let xt = cfa m m.latest in
      m.mem.(xt) <- m.dodoes;
      m.mem.(xt + 1) <- m.ip;
      m.ip <- rpop m);
  def_ "WORDS" (fun (m : t) (_ : int) ->
      let rec go (h : int) : unit =
        if h <> 0 then begin
          if m.mem.(h + 1) land hidden = 0 then m.print (name_at m h ^ " ");
          go m.mem.(h)
        end in
      go m.latest;
      m.print "\n");
  def_ "SEE" (fun (m : t) (_ : int) -> see m (word m));
  def_ "BYE" (fun (m : t) (_ : int) -> m.bye <- true; m.pos <- String.length m.input);
  m.prims <- Array.of_list (List.rev !table);
  m.mem.(base) <- 10;
  List.iter (fun (line : string) -> interpret m line) (String.split_on_char '\n' Forth_prelude.text);
  m.steps <- 0;
  m
